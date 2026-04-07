(** cn_activation_test: ppx_expect tests for SKILL.md frontmatter parsing,
    activation index building, and doctor validation.

    Tests:
    F1 — frontmatter parser: happy path with name + description + triggers
    F2 — frontmatter parser: missing leading ---
    F3 — frontmatter parser: missing closing ---
    F4 — frontmatter parser: triggers field absent
    F5 — frontmatter parser: malformed list lines
    B1 — build_index from a temp package tree (one skill with triggers, one without)
    B2 — build_index excludes skills declared in manifest but missing on disk
    B3 — build_index excludes SKILL.md files not declared in sources.skills
    V1 — validate flags missing SKILL.md
    V2 — validate flags empty triggers
    V3 — validate flags conflicting triggers across packages *)

(* === Helpers === *)

let mk_temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  Random.self_init ();
  let rec attempt k =
    if k = 0 then failwith "mk_temp_dir: exhausted";
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

let with_test_hub f =
  let hub = mk_temp_dir "cn-activation-test" in
  Fun.protect ~finally:(fun () ->
    try rm_tree hub
    with exn ->
      Printf.eprintf "test cleanup: %s: %s\n" hub (Printexc.to_string exn))
    (fun () -> f hub)

(** Install a vendored package that declares a list of skills with optional
    triggers. Each [skills] entry is (skill_id, optional_triggers). When
    [optional_triggers] is None, the SKILL.md is created without a frontmatter
    triggers field; when Some [], it is created with `triggers:` and no items;
    when Some xs, it is created with a YAML block list of those triggers. *)
let install_package ~hub ~name ~version ~skills =
  let pkg_dir = Filename.concat hub
    (Printf.sprintf ".cn/vendor/packages/%s@%s" name version) in
  ensure_dir pkg_dir;
  let skills_array =
    skills
    |> List.map (fun (id, _) -> Printf.sprintf "      \"%s\"" id)
    |> String.concat ",\n"
  in
  let manifest = Printf.sprintf
    "{\n\
    \  \"schema\": \"cn.package.v1\",\n\
    \  \"name\": \"%s\",\n\
    \  \"version\": \"%s\",\n\
    \  \"sources\": {\n\
    \    \"skills\": [\n%s\n    ]\n\
    \  }\n\
    }\n" name version skills_array
  in
  write_file (Filename.concat pkg_dir "cn.package.json") manifest;
  skills |> List.iter (fun (id, triggers_opt) ->
    let skill_md = Filename.concat pkg_dir
      (Printf.sprintf "skills/%s/SKILL.md" id) in
    let body = match triggers_opt with
      | None ->
          "---\nname: " ^ id ^
          "\ndescription: A skill without triggers\n---\n# Body\n"
      | Some [] ->
          "---\nname: " ^ id ^
          "\ndescription: empty triggers\ntriggers:\n---\n# Body\n"
      | Some ts ->
          let list = ts |> List.map (fun t -> "  - " ^ t) |> String.concat "\n" in
          "---\nname: " ^ id ^
          "\ndescription: A useful skill\ntriggers:\n" ^ list ^ "\n---\n# Body\n"
    in
    write_file skill_md body);
  pkg_dir

(* === F1 === *)

let%expect_test "F1 frontmatter happy path" =
  let fm = Cn_activation.parse_frontmatter
    "---\n\
     name: cdd\n\
     description: Coherence-Driven Development\n\
     triggers:\n\
    \  - review\n\
    \  - release\n\
    \  - design\n\
     ---\n\
     # Body\n"
  in
  Printf.printf "name=%s\n" (Option.value ~default:"_" fm.fm_name);
  Printf.printf "description=%s\n" (Option.value ~default:"_" fm.fm_description);
  Printf.printf "triggers=%s\n" (String.concat "," fm.fm_triggers);
  [%expect {|
    name=cdd
    description=Coherence-Driven Development
    triggers=review,release,design |}]

(* === F2 === *)

let%expect_test "F2 frontmatter missing leading ---" =
  let fm = Cn_activation.parse_frontmatter
    "name: cdd\ndescription: bare\n# Body\n"
  in
  Printf.printf "name=%s\n" (Option.value ~default:"none" fm.fm_name);
  Printf.printf "triggers_count=%d\n" (List.length fm.fm_triggers);
  [%expect {|
    name=none
    triggers_count=0 |}]

(* === F3 === *)

let%expect_test "F3 frontmatter missing closing ---" =
  let fm = Cn_activation.parse_frontmatter
    "---\nname: cdd\ndescription: never closes\n# but no second marker"
  in
  Printf.printf "name=%s\n" (Option.value ~default:"none" fm.fm_name);
  Printf.printf "triggers_count=%d\n" (List.length fm.fm_triggers);
  [%expect {|
    name=none
    triggers_count=0 |}]

(* === F4 === *)

let%expect_test "F4 frontmatter triggers absent" =
  let fm = Cn_activation.parse_frontmatter
    "---\nname: cdd\ndescription: no trigger field\n---\n# Body\n"
  in
  Printf.printf "name=%s\n" (Option.value ~default:"_" fm.fm_name);
  Printf.printf "triggers_count=%d\n" (List.length fm.fm_triggers);
  [%expect {|
    name=cdd
    triggers_count=0 |}]

(* === F5 === *)

let%expect_test "F5 frontmatter malformed list lines tolerated" =
  let fm = Cn_activation.parse_frontmatter
    "---\n\
     name: cdd\n\
     triggers:\n\
    \  - review\n\
    \  garbage line without dash\n\
    \  - release\n\
     ---\n"
  in
  Printf.printf "triggers=%s\n" (String.concat "," fm.fm_triggers);
  [%expect {| triggers=review,release |}]

(* === B1 === *)

let%expect_test "B1 build_index returns declared skills with their triggers" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.demo" ~version:"1.0.0"
      ~skills:[
        ("with-triggers", Some ["alpha"; "beta"]);
        ("no-triggers", None);
      ] in
    let entries = Cn_activation.build_index ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length entries);
    entries
    |> List.sort (fun (a : Cn_activation.activation_entry) b ->
        compare a.skill_id b.skill_id)
    |> List.iter (fun (e : Cn_activation.activation_entry) ->
      Printf.printf "%s pkg=%s triggers=[%s]\n"
        e.skill_id e.package (String.concat "," e.triggers)));
  [%expect {|
    count=2
    no-triggers pkg=cnos.demo triggers=[]
    with-triggers pkg=cnos.demo triggers=[alpha,beta] |}]

(* === B2 === *)

let%expect_test "B2 build_index excludes declared-but-missing skills" =
  with_test_hub (fun hub ->
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    ensure_dir pkg_dir;
    write_file (Filename.concat pkg_dir "cn.package.json")
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.demo\",\"version\":\"1.0.0\",\
       \"sources\":{\"skills\":[\"ghost\"]}}";
    (* No skills/ghost/SKILL.md created. *)
    let entries = Cn_activation.build_index ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length entries));
  [%expect {| count=0 |}]

(* === B3 === *)

let%expect_test "B3 build_index excludes SKILL.md not declared in manifest" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.demo" ~version:"1.0.0"
      ~skills:[("declared", Some ["x"])] in
    (* Add an undeclared skill on disk *)
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    write_file (Filename.concat pkg_dir "skills/sneaky/SKILL.md")
      "---\nname: sneaky\ntriggers:\n  - sneak\n---\n";
    let entries = Cn_activation.build_index ~hub_path:hub in
    let names = entries
      |> List.map (fun (e : Cn_activation.activation_entry) -> e.skill_id)
      |> List.sort compare in
    Printf.printf "ids=%s\n" (String.concat "," names));
  [%expect {| ids=declared |}]

(* === V1 === *)

let%expect_test "V1 validate flags declared skill with no SKILL.md" =
  with_test_hub (fun hub ->
    let pkg_dir = Filename.concat hub
      ".cn/vendor/packages/cnos.demo@1.0.0" in
    ensure_dir pkg_dir;
    write_file (Filename.concat pkg_dir "cn.package.json")
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.demo\",\"version\":\"1.0.0\",\
       \"sources\":{\"skills\":[\"ghost\"]}}";
    let issues = Cn_activation.validate ~hub_path:hub in
    Printf.printf "count=%d\n" (List.length issues);
    issues |> List.iter (fun (i : Cn_activation.issue) ->
      let kind = match i.kind with
        | Cn_activation.Missing_skill -> "missing"
        | Cn_activation.Empty_triggers -> "empty"
        | Cn_activation.Trigger_conflict -> "conflict"
      in
      Printf.printf "kind=%s\n" kind));
  [%expect {|
    count=1
    kind=missing |}]

(* === V2 === *)

let%expect_test "V2 validate flags empty triggers" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.demo" ~version:"1.0.0"
      ~skills:[("plain", None)] in
    let issues = Cn_activation.validate ~hub_path:hub in
    let kinds = issues
      |> List.map (fun (i : Cn_activation.issue) ->
        match i.kind with
        | Cn_activation.Missing_skill -> "missing"
        | Cn_activation.Empty_triggers -> "empty"
        | Cn_activation.Trigger_conflict -> "conflict")
      |> List.sort compare in
    Printf.printf "kinds=%s\n" (String.concat "," kinds));
  [%expect {| kinds=empty |}]

(* === V3 === *)

let%expect_test "V3 validate flags conflicting triggers across skills" =
  with_test_hub (fun hub ->
    let _ = install_package ~hub ~name:"cnos.alpha" ~version:"1.0.0"
      ~skills:[("first",  Some ["shared"; "uniq-a"])] in
    let _ = install_package ~hub ~name:"cnos.beta" ~version:"1.0.0"
      ~skills:[("second", Some ["shared"; "uniq-b"])] in
    let issues = Cn_activation.validate ~hub_path:hub in
    let conflicts = issues |> List.filter (fun (i : Cn_activation.issue) ->
      i.kind = Cn_activation.Trigger_conflict) in
    Printf.printf "conflict_count=%d\n" (List.length conflicts);
    let mentions s sub =
      let sl = String.length s and bl = String.length sub in
      let rec check i =
        if i > sl - bl then false
        else if String.sub s i bl = sub then true
        else check (i + 1)
      in bl <= sl && check 0
    in
    conflicts |> List.iter (fun (i : Cn_activation.issue) ->
      Printf.printf "mentions_shared=%b\n" (mentions i.message "shared")));
  [%expect {|
    conflict_count=1
    mentions_shared=true |}]
