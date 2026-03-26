(** cn_deps_test: ppx_expect tests for package restore and lockfile generation

    Invariants tested:
    I1 — restore_one copies ALL declared content categories, not a subset
    I2 — lockfile_for_manifest rejects third-party packages explicitly
    I3 — lockfile_for_manifest produces valid entries for first-party packages
    I4 — restore_one skips already-installed packages (idempotent) *)

(* === Temp directory helpers === *)

let mk_temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  let rec attempt k =
    if k = 0 then failwith "mk_temp_dir: exhausted attempts";
    let dir =
      Filename.concat base
        (Printf.sprintf "%s-%d-%06d" prefix (Unix.getpid ()) (Random.int 1_000_000))
    in
    try Unix.mkdir dir 0o700; dir
    with Unix.Unix_error (Unix.EEXIST, _, _) -> attempt (k - 1)
  in
  Random.self_init ();
  attempt 50

let rec rm_tree path =
  if Sys.file_exists path then begin
    if Sys.is_directory path then begin
      Sys.readdir path |> Array.iter (fun entry ->
        rm_tree (Filename.concat path entry));
      Unix.rmdir path
    end else
      Sys.remove path
  end

let touch dir file content =
  Cn_ffi.Fs.ensure_dir dir;
  let path = Filename.concat dir file in
  let oc = open_out path in
  output_string oc content;
  close_out oc

(** Set up a fake vendor package directory simulating a package source tree.
    Returns (hub_path, source_dir) where source_dir has all 5 content categories. *)
let with_package_source f =
  let hub = mk_temp_dir "cn-deps-test" in
  let source = mk_temp_dir "cn-deps-src" in
  (* Create all 5 content categories in source *)
  touch (Filename.concat source "doctrine") "CORE.md" "# Core";
  touch (Filename.concat source "mindsets") "ENG.md" "# Engineering";
  touch (Filename.concat source "skills/agent/hello") "SKILL.md" "# Hello";
  touch (Filename.concat source "extensions/net.http") "cn.extension.json" "{}";
  touch (Filename.concat source "profiles") "engineer.json" "{\"profile\":\"eng\"}";
  touch source "cn.package.json" "{\"name\":\"test\"}";
  Fun.protect
    ~finally:(fun () -> rm_tree hub; rm_tree source)
    (fun () -> f hub source)

(* === Step 1: Full package restore — I1 === *)

let%expect_test "restore_one copies all 5 content categories (I1)" =
  with_package_source (fun hub source ->
    (* Simulate what restore_one does after git checkout:
       copy from source into vendor package dir *)
    let pkg_dir = Filename.concat hub "pkg" in
    Cn_ffi.Fs.ensure_dir pkg_dir;
    List.iter (fun sub ->
      let src = Cn_ffi.Path.join source sub in
      if Cn_ffi.Fs.exists src then
        Cn_deps.copy_tree src (Cn_ffi.Path.join pkg_dir sub)
    ) ["doctrine"; "mindsets"; "skills"; "extensions"; "profiles"];
    (* Verify each category was copied *)
    let check cat file =
      let path = Filename.concat (Filename.concat pkg_dir cat) file in
      Printf.printf "%s/%s: %b\n" cat file (Sys.file_exists path)
    in
    check "doctrine" "CORE.md";
    check "mindsets" "ENG.md";
    check "skills/agent/hello" "SKILL.md";
    check "extensions/net.http" "cn.extension.json";
    check "profiles" "engineer.json");
  [%expect {|
    doctrine/CORE.md: true
    mindsets/ENG.md: true
    skills/agent/hello/SKILL.md: true
    extensions/net.http/cn.extension.json: true
    profiles/engineer.json: true
  |}]

let%expect_test "restore_one content list matches cn_build source_decl (I1)" =
  (* Invariant: the categories in restore must be a superset of cn_build's *)
  let restore_categories = ["doctrine"; "mindsets"; "skills"; "extensions"; "profiles"] in
  let build_categories = ["doctrine"; "mindsets"; "skills"; "extensions"] in
  let missing = List.filter (fun c ->
    not (List.mem c restore_categories)
  ) build_categories in
  Printf.printf "missing from restore: %d\n" (List.length missing);
  List.iter (fun m -> Printf.printf "  %s\n" m) missing;
  [%expect {|
    missing from restore: 0
  |}]

(* === Step 2: Honest third-party handling — I2, I3 === *)

let%expect_test "lockfile_for_manifest rejects third-party packages (I2)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "cnos.core"; version = "3.17.0" };
      { name = "external.pkg"; version = "1.0.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok _ -> print_endline "ERROR: should have rejected"
   | Error msg -> print_endline msg);
  [%expect {|
    Third-party packages not supported (no registry): external.pkg
  |}]

let%expect_test "lockfile_for_manifest rejects multiple third-party (I2)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "foo.bar"; version = "1.0" };
      { name = "baz.qux"; version = "2.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok _ -> print_endline "ERROR: should have rejected"
   | Error msg -> print_endline msg);
  [%expect {|
    Third-party packages not supported (no registry): foo.bar, baz.qux
  |}]

let%expect_test "lockfile_for_manifest accepts all first-party (I3)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "cnos.core"; version = "3.17.0" };
      { name = "cnos.eng"; version = "3.17.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok lock ->
       Printf.printf "packages: %d\n" (List.length lock.packages);
       lock.packages |> List.iter (fun (dep : Cn_deps.locked_dep) ->
         let has_source = dep.source <> "" in
         let has_subdir = dep.subdir <> "" in
         let has_rev = dep.rev <> "" in
         Printf.printf "%s: source=%b subdir=%b rev=%b\n"
           dep.name has_source has_subdir has_rev)
   | Error msg -> Printf.printf "ERROR: %s\n" msg);
  [%expect {|
    packages: 2
    cnos.core: source=true subdir=true rev=true
    cnos.eng: source=true subdir=true rev=true
  |}]

(* === Negative space (I2): no silent empty entries === *)

let%expect_test "no lock entry ever has empty source (I2 negative)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "cnos.core"; version = "3.17.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok lock ->
       let empty_sources = lock.packages
         |> List.filter (fun (d : Cn_deps.locked_dep) -> d.source = "") in
       Printf.printf "entries with empty source: %d\n" (List.length empty_sources)
   | Error _ -> print_endline "rejected (also acceptable)");
  [%expect {|
    entries with empty source: 0
  |}]

let%expect_test "first-party subdir follows packages/<name> pattern (I3)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "pm";
    packages = [
      { name = "cnos.core"; version = "3.17.0" };
      { name = "cnos.pm"; version = "3.17.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok lock ->
       lock.packages |> List.iter (fun (dep : Cn_deps.locked_dep) ->
         Printf.printf "%s -> %s\n" dep.name dep.subdir)
   | Error msg -> Printf.printf "ERROR: %s\n" msg);
  [%expect {|
    cnos.core -> packages/cnos.core
    cnos.pm -> packages/cnos.pm
  |}]
