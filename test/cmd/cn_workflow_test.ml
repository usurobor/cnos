(** cn_workflow_test: ppx_expect tests for the orchestrator IR runtime.

    Module under test: [Cn_workflow]. The module implements the
    [cn.orchestrator.v1] IR specified in ORCHESTRATORS.md §7-8 as
    types + parser + validator + discovery + executor.

    Naming note: the existing [Cn_orchestrator] module is the N-pass
    LLM bind-loop orchestrator. [Cn_workflow] is the mechanical
    workflow runtime. Two different concerns, two different modules.

    Stages (per PLAN-174-orchestrator-runtime.md):
      F* / V* / D* — Stage A (parser, validator, discovery)
      X*          — Stage B (execution)
      S*          — Stage C (shipped orchestrator) *)

(* === Temp dir + file helpers === *)

let mk_temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  Random.self_init ();
  let rec attempt k =
    if k = 0 then failwith "mk_temp_dir: exhausted";
    let dir = Filename.concat base
      (Printf.sprintf "%s-%d-%06d" prefix (Unix.getpid ()) (Random.int 1_000_000)) in
    try Unix.mkdir dir 0o700; dir
    with Unix.Unix_error (Unix.EEXIST, _, _) -> attempt (k - 1)
  in
  attempt 50

let rec rm_tree path =
  if Sys.file_exists path then begin
    if Sys.is_directory path then begin
      Sys.readdir path |> Array.iter (fun e ->
        rm_tree (Filename.concat path e));
      Unix.rmdir path
    end else
      Sys.remove path
  end

let ensure_dir path =
  let rec mk p =
    if not (Sys.file_exists p) then begin
      mk (Filename.dirname p);
      try Unix.mkdir p 0o755
      with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
    end
  in
  mk path

let write_file path content =
  ensure_dir (Filename.dirname path);
  let oc = open_out path in
  output_string oc content;
  close_out oc

let with_test_hub f =
  let hub = mk_temp_dir "cn-wf-test" in
  Fun.protect ~finally:(fun () ->
    try rm_tree hub
    with exn ->
      Printf.eprintf "test cleanup: %s: %s\n" hub (Printexc.to_string exn))
    (fun () -> f hub)

(** Install a vendored package declaring one orchestrator. The
    orchestrator JSON content is supplied by the caller so
    tests can construct malformed cases. *)
let install_orch ~hub ~pkg_name ~pkg_version ~orch_id ~content =
  let pkg_dir = Filename.concat hub
    (Printf.sprintf ".cn/vendor/packages/%s@%s" pkg_name pkg_version) in
  ensure_dir pkg_dir;
  let manifest = Printf.sprintf
    "{\"schema\":\"cn.package.v1\",\"name\":\"%s\",\"version\":\"%s\",\
     \"sources\":{\"orchestrators\":[\"%s\"]}}"
    pkg_name pkg_version orch_id in
  write_file (Filename.concat pkg_dir "cn.package.json") manifest;
  let path = Filename.concat pkg_dir
    (Printf.sprintf "orchestrators/%s/orchestrator.json" orch_id) in
  write_file path content;
  pkg_dir

let minimal_json =
  {|{
    "kind": "cn.orchestrator.v1",
    "name": "sample",
    "trigger": { "kind": "command", "name": "sample" },
    "permissions": { "llm": false, "ops": ["fs_read"], "external_effects": false },
    "steps": [
      { "id": "read", "kind": "op", "op": "fs_read",
        "args": { "path": "README.md" }, "bind": "body" },
      { "id": "done", "kind": "return", "value": { "artifact": "README.md" } }
    ]
  }|}

let has_substring s sub =
  let sl = String.length s and bl = String.length sub in
  let rec check i =
    if i > sl - bl then false
    else if String.sub s i bl = sub then true
    else check (i + 1)
  in bl <= sl && check 0

let ok_exn = function
  | Ok v -> v
  | Error msg -> failwith ("expected Ok, got Error: " ^ msg)

(* === Stage A: parser === *)

let%expect_test "F1 parse minimal orchestrator" =
  let json = Cn_json.parse minimal_json |> ok_exn in
  let o = Cn_workflow.parse json |> ok_exn in
  Printf.printf "kind=%s\n" o.kind;
  Printf.printf "name=%s\n" o.name;
  Printf.printf "steps=%d\n" (List.length o.steps);
  Printf.printf "llm_permitted=%b\n" o.permissions.llm;
  Printf.printf "ops_permitted=%s\n" (String.concat "," o.permissions.ops);
  [%expect {|
    kind=cn.orchestrator.v1
    name=sample
    steps=2
    llm_permitted=false
    ops_permitted=fs_read |}]

let%expect_test "F2 parse rejects missing name" =
  let bad = {|{"kind":"cn.orchestrator.v1","steps":[]}|} in
  let json = Cn_json.parse bad |> ok_exn in
  (match Cn_workflow.parse json with
   | Ok _ -> print_endline "UNEXPECTED ok"
   | Error msg ->
     Printf.printf "mentions_name=%b\n" (has_substring msg "name"));
  [%expect {| mentions_name=true |}]

let%expect_test "F3 parse rejects unknown step kind" =
  let bad = {|{
    "kind":"cn.orchestrator.v1","name":"x",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":[{"id":"a","kind":"telepathy"}]
  }|} in
  let json = Cn_json.parse bad |> ok_exn in
  (match Cn_workflow.parse json with
   | Ok _ -> print_endline "UNEXPECTED ok"
   | Error msg ->
     Printf.printf "mentions_telepathy=%b\n" (has_substring msg "telepathy"));
  [%expect {| mentions_telepathy=true |}]

let%expect_test "F4 parse rejects non-array steps" =
  let bad = {|{
    "kind":"cn.orchestrator.v1","name":"x",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":"not an array"
  }|} in
  let json = Cn_json.parse bad |> ok_exn in
  (match Cn_workflow.parse json with
   | Ok _ -> print_endline "UNEXPECTED ok"
   | Error _ -> print_endline "rejected");
  [%expect {| rejected |}]

let%expect_test "F5 parse accepts llm + if + match + fail step shapes" =
  let src = {|{
    "kind":"cn.orchestrator.v1","name":"all",
    "trigger":{"kind":"command","name":"all"},
    "permissions":{"llm":true,"ops":[],"external_effects":false},
    "steps":[
      {"id":"ask","kind":"llm","prompt":"demo","inputs":["today"],"bind":"a"},
      {"id":"branch","kind":"if","cond":"a","then":"done","else":"err"},
      {"id":"pick","kind":"match","input":"a","cases":{"one":"done","two":"err"},"default":"err"},
      {"id":"done","kind":"return","value":{"ok":true}},
      {"id":"err","kind":"fail","message":"boom"}
    ]
  }|} in
  let json = Cn_json.parse src |> ok_exn in
  let o = Cn_workflow.parse json |> ok_exn in
  let kinds = o.steps |> List.map (function
    | Cn_workflow.Op_step _ -> "op"
    | Cn_workflow.Llm_step _ -> "llm"
    | Cn_workflow.If_step _ -> "if"
    | Cn_workflow.Match_step _ -> "match"
    | Cn_workflow.Return_step _ -> "return"
    | Cn_workflow.Fail_step _ -> "fail") in
  Printf.printf "kinds=%s\n" (String.concat "," kinds);
  [%expect {| kinds=llm,if,match,return,fail |}]

(* === Stage A: validator === *)

let parse_or_fail src =
  Cn_workflow.parse (Cn_json.parse src |> ok_exn) |> ok_exn

let any_issue ~kind (issues : Cn_workflow.issue list) =
  List.exists (fun (i : Cn_workflow.issue) -> i.issue_kind = kind) issues

let%expect_test "V1 validate flags duplicate step ids" =
  let o = parse_or_fail {|{
    "kind":"cn.orchestrator.v1","name":"dup",
    "trigger":{"kind":"command","name":"dup"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":[
      {"id":"same","kind":"return","value":{}},
      {"id":"same","kind":"fail","message":"never"}
    ]
  }|} in
  let issues = Cn_workflow.validate o in
  let has = List.exists (fun (i : Cn_workflow.issue) ->
    match i.issue_kind with
    | Cn_workflow.Duplicate_step_id _ -> true
    | _ -> false) issues in
  Printf.printf "duplicate_reported=%b\n" has;
  [%expect {| duplicate_reported=true |}]

let%expect_test "V2 validate flags if-step pointing at nonexistent step" =
  let o = parse_or_fail {|{
    "kind":"cn.orchestrator.v1","name":"badref",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":[
      {"id":"choose","kind":"if","cond":"flag","then":"ghost","else":"done"},
      {"id":"done","kind":"return","value":{}}
    ]
  }|} in
  let issues = Cn_workflow.validate o in
  let has = List.exists (fun (i : Cn_workflow.issue) ->
    match i.issue_kind with
    | Cn_workflow.Invalid_step_ref _ -> true
    | _ -> false) issues in
  Printf.printf "invalid_ref_reported=%b\n" has;
  [%expect {| invalid_ref_reported=true |}]

let%expect_test "V3 validate flags op not in permissions.ops" =
  let o = parse_or_fail {|{
    "kind":"cn.orchestrator.v1","name":"permgap",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":["fs_read"],"external_effects":false},
    "steps":[
      {"id":"write","kind":"op","op":"fs_write","args":{"path":"x","content":"y"}},
      {"id":"done","kind":"return","value":{}}
    ]
  }|} in
  let issues = Cn_workflow.validate o in
  let has = List.exists (fun (i : Cn_workflow.issue) ->
    match i.issue_kind with
    | Cn_workflow.Permission_gap _ -> true
    | _ -> false) issues in
  Printf.printf "perm_gap_reported=%b\n" has;
  [%expect {| perm_gap_reported=true |}]

let%expect_test "V4 validate flags llm step when permissions.llm=false" =
  let o = parse_or_fail {|{
    "kind":"cn.orchestrator.v1","name":"llmgap",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":[
      {"id":"ask","kind":"llm","prompt":"p","inputs":[],"bind":"a"},
      {"id":"done","kind":"return","value":{}}
    ]
  }|} in
  let issues = Cn_workflow.validate o in
  let has = any_issue ~kind:Cn_workflow.Llm_without_permission issues in
  Printf.printf "llm_perm_reported=%b\n" has;
  [%expect {| llm_perm_reported=true |}]

let%expect_test "V5 validate flags empty steps list" =
  let o = parse_or_fail {|{
    "kind":"cn.orchestrator.v1","name":"empty",
    "trigger":{"kind":"command","name":"x"},
    "permissions":{"llm":false,"ops":[],"external_effects":false},
    "steps":[]
  }|} in
  let issues = Cn_workflow.validate o in
  let has = any_issue ~kind:Cn_workflow.Empty_steps issues in
  Printf.printf "empty_reported=%b\n" has;
  [%expect {| empty_reported=true |}]

(* === Stage A: discovery === *)

let%expect_test "D1 discover reads orchestrator from vendored package" =
  with_test_hub (fun hub ->
    let _ = install_orch
      ~hub ~pkg_name:"cnos.demo" ~pkg_version:"1.0.0"
      ~orch_id:"sample" ~content:minimal_json in
    let items = Cn_workflow.discover ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length items);
    items |> List.iter (fun (i : Cn_workflow.installed) ->
      let loaded = match i.outcome with
        | Cn_workflow.Loaded _ -> true | _ -> false in
      Printf.printf "%s/%s loaded=%b\n" i.package i.id loaded));
  [%expect {|
    count=1
    cnos.demo/sample loaded=true |}]

let%expect_test "D2 discover surfaces parse error per orchestrator" =
  with_test_hub (fun hub ->
    let _ = install_orch
      ~hub ~pkg_name:"cnos.demo" ~pkg_version:"1.0.0"
      ~orch_id:"broken" ~content:"{ not json" in
    let items = Cn_workflow.discover ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length items);
    items |> List.iter (fun (i : Cn_workflow.installed) ->
      let failed = match i.outcome with
        | Cn_workflow.Load_error _ -> true | _ -> false in
      Printf.printf "%s/%s failed=%b\n" i.package i.id failed));
  [%expect {|
    count=1
    cnos.demo/broken failed=true |}]

let%expect_test "D3 discover surfaces missing orchestrator file" =
  with_test_hub (fun hub ->
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    ensure_dir pkg_dir;
    write_file (Filename.concat pkg_dir "cn.package.json")
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.demo\",\"version\":\"1.0.0\",\
       \"sources\":{\"orchestrators\":[\"ghost\"]}}";
    (* No orchestrators/ghost/orchestrator.json created. *)
    let items = Cn_workflow.discover ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length items);
    items |> List.iter (fun (i : Cn_workflow.installed) ->
      let is_missing = match i.outcome with
        | Cn_workflow.Load_error msg -> has_substring msg "missing"
        | _ -> false in
      Printf.printf "missing_reported=%b\n" is_missing));
  [%expect {|
    count=1
    missing_reported=true |}]

(* === Stage B: executor === *)

let%expect_test "X1 execute: op step reads a file and binds the result" =
  with_test_hub (fun hub ->
    write_file (Filename.concat hub "hello.txt") "hi there\n";
    let src = Printf.sprintf {|{
      "kind":"cn.orchestrator.v1","name":"read-hello",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":["fs_read"],"external_effects":false},
      "steps":[
        {"id":"load","kind":"op","op":"fs_read","args":{"path":"hello.txt"},"bind":"body"},
        {"id":"done","kind":"return","value":{"bound":"body"}}
      ]
    }|} in
    let _ = src in
    let o = parse_or_fail src in
    let outcome = Cn_workflow.execute ~hub_path:hub o in
    match outcome with
    | Cn_workflow.Completed _ -> print_endline "completed"
    | Cn_workflow.Failed msg -> Printf.printf "failed: %s\n" msg);
  [%expect {| completed |}]

let%expect_test "X2 execute: return step emits its value" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"just-return",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":[],"external_effects":false},
      "steps":[
        {"id":"done","kind":"return","value":{"k":"v"}}
      ]
    }|} in
    match Cn_workflow.execute ~hub_path:hub o with
    | Cn_workflow.Completed v ->
      (match Cn_json.get_string "k" v with
       | Some s -> Printf.printf "k=%s\n" s
       | None -> print_endline "no k")
    | Cn_workflow.Failed msg -> Printf.printf "failed: %s\n" msg);
  [%expect {| k=v |}]

let%expect_test "X3 execute: fail step → Failed outcome" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"just-fail",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":[],"external_effects":false},
      "steps":[
        {"id":"boom","kind":"fail","message":"intentional"}
      ]
    }|} in
    match Cn_workflow.execute ~hub_path:hub o with
    | Cn_workflow.Completed _ -> print_endline "UNEXPECTED completed"
    | Cn_workflow.Failed msg ->
      Printf.printf "mentions_intentional=%b\n" (has_substring msg "intentional"));
  [%expect {| mentions_intentional=true |}]

let%expect_test "X4 execute: permission gap — op not in permissions.ops" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"sneaky",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":["fs_read"],"external_effects":false},
      "steps":[
        {"id":"write","kind":"op","op":"fs_write",
         "args":{"path":"evil.txt","content":"oops"}},
        {"id":"done","kind":"return","value":{}}
      ]
    }|} in
    (* The validator should already flag this; but execute() must
       also refuse to dispatch the op — defence-in-depth. *)
    match Cn_workflow.execute ~hub_path:hub o with
    | Cn_workflow.Completed _ -> print_endline "UNEXPECTED completed"
    | Cn_workflow.Failed msg ->
      Printf.printf "mentions_permission=%b\n" (has_substring msg "permission"));
  [%expect {| mentions_permission=true |}]

let%expect_test "X5 execute: llm step — deferred, emits 'not implemented' failure" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"llm-demo",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":true,"ops":[],"external_effects":false},
      "steps":[
        {"id":"ask","kind":"llm","prompt":"demo","inputs":[],"bind":"a"},
        {"id":"done","kind":"return","value":{}}
      ]
    }|} in
    match Cn_workflow.execute ~hub_path:hub o with
    | Cn_workflow.Completed _ -> print_endline "UNEXPECTED completed"
    | Cn_workflow.Failed msg ->
      Printf.printf "mentions_not_implemented=%b\n"
        (has_substring msg "not yet implemented"));
  [%expect {| mentions_not_implemented=true |}]

let%expect_test "X6 execute: match step selects a case by bound scalar" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"match-case",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":[],"external_effects":false},
      "steps":[
        {"id":"pick","kind":"match","input":"flavor",
         "cases":{"vanilla":"v","chocolate":"c"},"default":"d"},
        {"id":"v","kind":"return","value":{"chose":"vanilla"}},
        {"id":"c","kind":"return","value":{"chose":"chocolate"}},
        {"id":"d","kind":"return","value":{"chose":"default"}}
      ]
    }|} in
    match Cn_workflow.execute ~hub_path:hub
            ~env:[("flavor", Cn_json.String "vanilla")] o with
    | Cn_workflow.Failed msg -> Printf.printf "failed: %s\n" msg
    | Cn_workflow.Completed v ->
      Printf.printf "chose=%s\n"
        (Cn_json.get_string "chose" v |> Option.value ~default:"?"));
  [%expect {| chose=vanilla |}]

let%expect_test "X7 execute: match step falls back to default when no case matches" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"match-default",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":[],"external_effects":false},
      "steps":[
        {"id":"pick","kind":"match","input":"flavor",
         "cases":{"vanilla":"v","chocolate":"c"},"default":"d"},
        {"id":"v","kind":"return","value":{"chose":"vanilla"}},
        {"id":"c","kind":"return","value":{"chose":"chocolate"}},
        {"id":"d","kind":"return","value":{"chose":"default"}}
      ]
    }|} in
    match Cn_workflow.execute ~hub_path:hub
            ~env:[("flavor", Cn_json.String "strawberry")] o with
    | Cn_workflow.Failed msg -> Printf.printf "failed: %s\n" msg
    | Cn_workflow.Completed v ->
      Printf.printf "chose=%s\n"
        (Cn_json.get_string "chose" v |> Option.value ~default:"?"));
  [%expect {| chose=default |}]

let%expect_test "X8 execute: if step branches on bound bool" =
  with_test_hub (fun hub ->
    let o = parse_or_fail {|{
      "kind":"cn.orchestrator.v1","name":"if-branch",
      "trigger":{"kind":"command","name":"x"},
      "permissions":{"llm":false,"ops":[],"external_effects":false},
      "steps":[
        {"id":"choose","kind":"if","cond":"flag","then":"t","else":"f"},
        {"id":"t","kind":"return","value":{"branch":"then"}},
        {"id":"f","kind":"return","value":{"branch":"else"}}
      ]
    }|} in
    let true_outcome = Cn_workflow.execute ~hub_path:hub
      ~env:[("flag", Cn_json.Bool true)] o in
    let false_outcome = Cn_workflow.execute ~hub_path:hub
      ~env:[("flag", Cn_json.Bool false)] o in
    let show outcome =
      match outcome with
      | Cn_workflow.Failed msg -> "fail:" ^ msg
      | Cn_workflow.Completed v ->
        Cn_json.get_string "branch" v |> Option.value ~default:"?"
    in
    Printf.printf "true=%s false=%s\n" (show true_outcome) (show false_outcome));
  [%expect {| true=then false=else |}]
