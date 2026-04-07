(** cn_deps_test: ppx_expect tests for package restore and lockfile.

    Invariants tested:
    I1 — copy_tree preserves full directory structure (restore primitive)
    I2 — lockfile_for_manifest rejects third-party packages explicitly
    I3 — lockfile read/write round-trips name+version+sha256 *)

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

(** Collect all files under a directory, sorted, relative to root. *)
let rec collect_files root dir =
  let full = Filename.concat root dir in
  if not (Sys.file_exists full) then []
  else if Sys.is_directory full then
    Sys.readdir full |> Array.to_list
    |> List.concat_map (fun entry ->
      collect_files root (Filename.concat dir entry))
  else [dir]

(* === I1: copy_tree preserves full directory structure === *)

(* copy_tree is the shared primitive used by both local and remote restore paths.
   Both do: copy_tree source_root pkg_dir. Testing copy_tree proves both paths. *)
let%expect_test "copy_tree preserves full package structure (I1)" =
  let src = mk_temp_dir "cn-deps-src" in
  let dst = mk_temp_dir "cn-deps-dst" in
  Fun.protect ~finally:(fun () -> rm_tree src; rm_tree dst) (fun () ->
    (* Create a realistic package tree with all content categories *)
    touch (Filename.concat src "doctrine") "CORE.md" "# Core";
    touch (Filename.concat src "mindsets") "ENG.md" "# Engineering";
    touch (Filename.concat src "skills/agent/hello") "SKILL.md" "# Hello";
    touch (Filename.concat src "extensions/net.http") "cn.extension.json" "{}";
    touch src "cn.package.json" "{\"name\":\"test\"}";
    (* copy_tree — same call both restore paths use *)
    Cn_deps.copy_tree src dst;
    let files = collect_files dst "." |> List.sort String.compare in
    List.iter print_endline files);
  [%expect {|
    ./cn.package.json
    ./doctrine/CORE.md
    ./extensions/net.http/cn.extension.json
    ./mindsets/ENG.md
    ./skills/agent/hello/SKILL.md
  |}]

(* Invariant: copy_tree copies file content, not just structure *)
let%expect_test "copy_tree preserves file content (I1)" =
  let src = mk_temp_dir "cn-deps-content-src" in
  let dst = mk_temp_dir "cn-deps-content-dst" in
  Fun.protect ~finally:(fun () -> rm_tree src; rm_tree dst) (fun () ->
    touch (Filename.concat src "doctrine") "CORE.md" "# Core doctrine content";
    Cn_deps.copy_tree src dst;
    let content = Cn_ffi.Fs.read (Filename.concat dst "doctrine/CORE.md") in
    print_endline content);
  [%expect {| # Core doctrine content |}]

(* === I2: lockfile_for_manifest rejects third-party packages === *)

let%expect_test "lockfile_for_manifest rejects third-party packages (I2)" =
  let manifest : Cn_deps.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "cnos.core"; version = Cn_lib.version };
      { name = "external.pkg"; version = "1.0.0" };
    ];
  } in
  (match Cn_deps.lockfile_for_manifest manifest with
   | Ok _ -> print_endline "ERROR: should have rejected"
   | Error msg ->
     (* Only the third-party rejection prefix is asserted; an index lookup
        miss would be a different message starting with "Cannot build". *)
     let has_sub s sub =
       let slen = String.length s and sublen = String.length sub in
       let rec check i =
         if i > slen - sublen then false
         else if String.sub s i sublen = sub then true
         else check (i + 1)
       in sublen <= slen && check 0
     in
     Printf.printf "third_party_rejected: %b\n"
       (has_sub msg "Third-party packages not supported"));
  [%expect {| third_party_rejected: true |}]

(* === I3: lockfile read/write round-trips name+version+sha256 === *)

let%expect_test "lockfile read/write round-trip (I3)" =
  let hub = mk_temp_dir "cn-deps-lock" in
  Fun.protect ~finally:(fun () -> rm_tree hub) (fun () ->
    Cn_ffi.Fs.ensure_dir (Filename.concat hub ".cn");
    let lock : Cn_deps.lockfile = {
      schema = "cn.lock.v2";
      packages = [
        { name = "cnos.core"; version = "9.9.9"; sha256 = "abc123" };
        { name = "cnos.eng";  version = "9.9.9"; sha256 = "def456" };
      ];
    } in
    Cn_deps.write_lockfile ~hub_path:hub lock;
    match Cn_deps.read_lockfile ~hub_path:hub with
    | None -> print_endline "ERROR: could not read"
    | Some lf ->
      Printf.printf "schema=%s\n" lf.schema;
      Printf.printf "count=%d\n" (List.length lf.packages);
      List.iter (fun (d : Cn_deps.locked_dep) ->
        Printf.printf "%s@%s sha256=%s\n" d.name d.version d.sha256
      ) lf.packages);
  [%expect {|
    schema=cn.lock.v2
    count=2
    cnos.core@9.9.9 sha256=abc123
    cnos.eng@9.9.9 sha256=def456
  |}]

