(** cn_command_test: ppx_expect tests for external CLI command discovery,
    dispatch precedence, and doctor validation.

    Tests:
    T1 — repo-local discovery picks up .cn/commands/cn-<name> executables
    T2 — package command discovery picks up entries in cn.package.json
    T3 — repo-local takes precedence over package commands of the same name
    T4 — validate flags missing entrypoints
    T5 — validate flags non-executable entrypoints
    T6 — validate flags duplicate names across packages
    T7 — empty hub yields empty discovery and no crash *)

(* === Helpers === *)

let mk_temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  Random.self_init ();
  let rec attempt k =
    if k = 0 then failwith "mk_temp_dir: exhausted attempts";
    let dir = Filename.concat base
      (Printf.sprintf "%s-%d-%06d" prefix (Unix.getpid ()) (Random.int 1_000_000))
    in
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

(** Write a file and chmod 0o755. *)
let write_executable path content =
  write_file path content;
  Unix.chmod path 0o755

let with_test_hub f =
  let hub = mk_temp_dir "cn-cmd-test" in
  Fun.protect ~finally:(fun () ->
    try rm_tree hub
    with exn ->
      Printf.eprintf "test cleanup: %s: %s\n" hub (Printexc.to_string exn))
    (fun () -> f hub)

(** Install a vendored package with a manifest declaring the given commands.
    Each command entry in [cmds] is (name, entrypoint_relpath, summary).
    Each entrypoint file is created and made executable. *)
let install_package ~hub ~name ~version ~cmds =
  let pkg_dir = Filename.concat hub
    (Printf.sprintf ".cn/vendor/packages/%s@%s" name version) in
  ensure_dir pkg_dir;
  let cmds_json =
    cmds |> List.map (fun (cmd_name, entrypoint, summary) ->
      Printf.sprintf
        "    \"%s\": { \"entrypoint\": \"%s\", \"summary\": \"%s\" }"
        cmd_name entrypoint summary)
    |> String.concat ",\n"
  in
  let manifest = Printf.sprintf
    "{\n\
    \  \"schema\": \"cn.package.v1\",\n\
    \  \"name\": \"%s\",\n\
    \  \"version\": \"%s\",\n\
    \  \"sources\": {\n\
    \    \"commands\": {\n%s\n    }\n\
    \  }\n\
    }\n" name version cmds_json
  in
  write_file (Filename.concat pkg_dir "cn.package.json") manifest;
  cmds |> List.iter (fun (_, ep, _) ->
    write_executable (Filename.concat pkg_dir ep) "#!/bin/sh\necho ok\n");
  pkg_dir

(* === T1: repo-local discovery === *)

let%expect_test "T1 repo-local discovery" =
  with_test_hub (fun hub ->
    write_executable
      (Filename.concat hub ".cn/commands/cn-foo")
      "#!/bin/sh\necho foo\n";
    let cmds = Cn_command.discover_repo_local ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length cmds);
    cmds |> List.iter (fun (c : Cn_command.external_cmd) ->
      let src = match c.source with
        | Cn_command.Repo_local -> "repo-local"
        | Cn_command.Package _ -> "package"
      in
      Printf.printf "name=%s source=%s\n" c.name src));
  [%expect {|
    count=1
    name=foo source=repo-local |}]

(* === T2: package command discovery === *)

let%expect_test "T2 package command discovery" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.demo" ~version:"1.0.0"
      ~cmds:[("hello", "commands/cn-hello", "Greet the operator")] in
    let cmds = Cn_command.discover_package ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length cmds);
    cmds |> List.iter (fun (c : Cn_command.external_cmd) ->
      let src = match c.source with
        | Cn_command.Package p -> Printf.sprintf "package:%s" p
        | Cn_command.Repo_local -> "repo-local"
      in
      Printf.printf "name=%s source=%s summary=%s\n" c.name src c.summary));
  [%expect {|
    count=1
    name=hello source=package:cnos.demo summary=Greet the operator |}]

(* === T3: precedence — repo-local wins over package === *)

let%expect_test "T3 repo-local precedence over package" =
  with_test_hub (fun hub ->
    write_executable
      (Filename.concat hub ".cn/commands/cn-shared")
      "#!/bin/sh\necho local\n";
    let _ = install_package ~hub ~name:"cnos.demo" ~version:"1.0.0"
      ~cmds:[("shared", "commands/cn-shared", "from package")] in
    match Cn_command.find ~hub_path:hub "shared" with
    | None -> print_endline "ERROR: not found"
    | Some c ->
      let src = match c.source with
        | Cn_command.Repo_local -> "repo-local"
        | Cn_command.Package p -> Printf.sprintf "package:%s" p
      in
      Printf.printf "winner=%s\n" src);
  [%expect {| winner=repo-local |}]

(* === T4: validate flags missing entrypoint === *)

let%expect_test "T4 validate missing entrypoint" =
  with_test_hub (fun hub ->
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    ensure_dir pkg_dir;
    write_file (Filename.concat pkg_dir "cn.package.json")
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.demo\",\"version\":\"1.0.0\",\
       \"sources\":{\"commands\":{\
       \"ghost\":{\"entrypoint\":\"commands/cn-ghost\",\"summary\":\"missing\"}}}}";
    let issues = Cn_command.validate ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length issues);
    let mentions s sub =
      let sl = String.length s and bl = String.length sub in
      let rec check i =
        if i > sl - bl then false
        else if String.sub s i bl = sub then true
        else check (i + 1)
      in bl <= sl && check 0
    in
    issues |> List.iter (fun msg ->
      Printf.printf "mentions_missing=%b\n" (mentions msg "entrypoint missing")));
  [%expect {|
    count=1
    mentions_missing=true |}]

(* === T5: validate flags non-executable file === *)

let%expect_test "T5 validate non-executable" =
  with_test_hub (fun hub ->
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    ensure_dir pkg_dir;
    write_file (Filename.concat pkg_dir "cn.package.json")
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.demo\",\"version\":\"1.0.0\",\
       \"sources\":{\"commands\":{\
       \"plain\":{\"entrypoint\":\"commands/cn-plain\",\"summary\":\"not exec\"}}}}";
    write_file (Filename.concat pkg_dir "commands/cn-plain") "#!/bin/sh\n";
    Unix.chmod (Filename.concat pkg_dir "commands/cn-plain") 0o644;
    let issues = Cn_command.validate ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length issues);
    let mentions s sub =
      let sl = String.length s and bl = String.length sub in
      let rec check i =
        if i > sl - bl then false
        else if String.sub s i bl = sub then true
        else check (i + 1)
      in bl <= sl && check 0
    in
    issues |> List.iter (fun msg ->
      Printf.printf "mentions_not_exec=%b\n" (mentions msg "not executable")));
  [%expect {|
    count=1
    mentions_not_exec=true |}]

(* === T6: validate flags duplicate command names across packages === *)

let%expect_test "T6 validate duplicate command names across packages" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.alpha" ~version:"1.0.0"
      ~cmds:[("clash", "commands/cn-clash", "from alpha")] in
    let _ = install_package ~hub ~name:"cnos.beta" ~version:"1.0.0"
      ~cmds:[("clash", "commands/cn-clash", "from beta")] in
    let issues = Cn_command.validate ~hub_path:hub in
    let mentions s sub =
      let sl = String.length s and bl = String.length sub in
      let rec check i =
        if i > sl - bl then false
        else if String.sub s i bl = sub then true
        else check (i + 1)
      in bl <= sl && check 0
    in
    let dup = List.exists (fun m -> mentions m "duplicate") issues in
    Printf.printf "has_duplicate_issue=%b\n" dup);
  [%expect {| has_duplicate_issue=true |}]

(* === T7: empty hub returns empty discovery and validates clean === *)

let%expect_test "T7 empty hub" =
  with_test_hub (fun hub ->
    Printf.printf "discover=%d\n" (List.length (Cn_command.discover ~hub_path:hub));
    Printf.printf "validate=%d\n" (List.length (Cn_command.validate ~hub_path:hub));
    Printf.printf "find=%b\n"
      (Cn_command.find ~hub_path:hub "anything" <> None));
  [%expect {|
    discover=0
    validate=0
    find=false |}]
