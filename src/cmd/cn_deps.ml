(** cn_deps.ml — Package manifest, lockfile, and package restore.

    Handles .cn/deps.json (manifest) and .cn/deps.lock.json (lockfile).

    First-party packages are distributed as versioned tarball artifacts
    published to GitHub releases. The package index (packages/index.json)
    maps name+version to URL+SHA-256. The lockfile pins name+version
    +sha256 per package; hosting can move without rewriting locks.

    Restore: lockfile -> index lookup -> HTTPS download -> SHA-256
    verify -> tar -xzf into .cn/vendor/packages/<name>@<version>/
    -> validate cn.package.json. When running inside a cnos checkout,
    first-party packages are copied from the local source tree instead,
    after a freshness check against src/agent/. *)

(* === Constants === *)

(** Stable URL for the package index (raw GitHub view of main).
    Derived from cnos_repo so a fork or rename does not break it. *)
let package_index_url () =
  Printf.sprintf
    "https://raw.githubusercontent.com/%s/main/packages/index.json"
    Cn_lib.cnos_repo

(* === Types === *)

(** Manifest entry: what the operator wants. *)
type manifest_dep = {
  name : string;
  version : string;
}

(** Lockfile entry: name + version + tarball sha256. *)
type locked_dep = {
  name : string;
  version : string;
  sha256 : string;
}

type manifest = {
  schema : string;
  profile : string;
  packages : manifest_dep list;
}

type lockfile = {
  schema : string;
  packages : locked_dep list;
}

(** Package index entry. *)
type index_entry = {
  ie_url : string;
  ie_sha256 : string;
}

(** Parsed package index: (name, version) -> entry. *)
type package_index = {
  index_schema : string;
  index_entries : ((string * string) * index_entry) list;
}

(* === Paths === *)

let manifest_path hub_path = Cn_ffi.Path.join hub_path ".cn/deps.json"
let lockfile_path hub_path = Cn_ffi.Path.join hub_path ".cn/deps.lock.json"

(* === JSON: manifest === *)

let manifest_dep_to_json (d : manifest_dep) =
  Cn_json.Object [
    "name", Cn_json.String d.name;
    "version", Cn_json.String d.version;
  ]

let parse_manifest_dep json =
  match Cn_json.get_string "name" json, Cn_json.get_string "version" json with
  | Some name, Some version -> Some { name; version }
  | _ -> None

let read_manifest ~hub_path =
  let path = manifest_path hub_path in
  if not (Cn_ffi.Fs.exists path) then None
  else
    match Cn_ffi.Fs.read path |> Cn_json.parse with
    | Error _ -> None
    | Ok json ->
        let schema = Cn_json.get_string "schema" json
          |> Option.value ~default:"cn.deps.v1" in
        let profile = Cn_json.get_string "profile" json
          |> Option.value ~default:"engineer" in
        let packages = match Cn_json.get "packages" json with
          | Some (Cn_json.Array items) -> List.filter_map parse_manifest_dep items
          | _ -> []
        in
        Some { schema; profile; packages }

let write_manifest ~hub_path (m : manifest) =
  let json = Cn_json.Object [
    "schema", Cn_json.String m.schema;
    "profile", Cn_json.String m.profile;
    "packages", Cn_json.Array (List.map manifest_dep_to_json m.packages);
  ] in
  Cn_ffi.Fs.write (manifest_path hub_path) (Cn_json.to_string json ^ "\n")

(* === JSON: lockfile === *)

let locked_dep_to_json (d : locked_dep) =
  Cn_json.Object [
    "name", Cn_json.String d.name;
    "version", Cn_json.String d.version;
    "sha256", Cn_json.String d.sha256;
  ]

let parse_locked_dep json =
  match Cn_json.get_string "name" json,
        Cn_json.get_string "version" json,
        Cn_json.get_string "sha256" json with
  | Some name, Some version, Some sha256 -> Some { name; version; sha256 }
  | _ -> None

let read_lockfile ~hub_path =
  let path = lockfile_path hub_path in
  if not (Cn_ffi.Fs.exists path) then None
  else
    match Cn_ffi.Fs.read path |> Cn_json.parse with
    | Error _ -> None
    | Ok json ->
        let schema = Cn_json.get_string "schema" json
          |> Option.value ~default:"cn.lock.v2" in
        let packages = match Cn_json.get "packages" json with
          | Some (Cn_json.Array items) -> List.filter_map parse_locked_dep items
          | _ -> []
        in
        Some { schema; packages }

let write_lockfile ~hub_path (l : lockfile) =
  let json = Cn_json.Object [
    "schema", Cn_json.String l.schema;
    "packages", Cn_json.Array (List.map locked_dep_to_json l.packages);
  ] in
  Cn_ffi.Fs.write (lockfile_path hub_path) (Cn_json.to_string json ^ "\n")

let empty_lockfile = { schema = "cn.lock.v2"; packages = [] }

(* === Package index === *)

(** Parse a cn.package-index.v1 JSON document. *)
let parse_package_index json =
  let schema = Cn_json.get_string "schema" json
    |> Option.value ~default:"cn.package-index.v1" in
  let entries = match Cn_json.get "packages" json with
    | Some (Cn_json.Object pkgs) ->
        pkgs |> List.concat_map (fun (name, versions_json) ->
          match versions_json with
          | Cn_json.Object versions ->
              versions |> List.filter_map (fun (version, entry_json) ->
                match Cn_json.get_string "url" entry_json,
                      Cn_json.get_string "sha256" entry_json with
                | Some url, Some sha256 ->
                    Some ((name, version), { ie_url = url; ie_sha256 = sha256 })
                | _ -> None)
          | _ -> [])
    | _ -> []
  in
  { index_schema = schema; index_entries = entries }

let lookup_index (idx : package_index) ~name ~version =
  List.assoc_opt (name, version) idx.index_entries

(** Walk up from cwd looking for a packages/index.json (development mode). *)
let find_local_index_path () =
  let rec walk dir =
    let candidate = Cn_ffi.Path.join dir "packages/index.json" in
    if Cn_ffi.Fs.exists candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else walk parent
  in
  walk (Cn_ffi.Process.cwd ())

(** Load the package index. Prefers a local checkout's packages/index.json
    if we're inside the cnos repo; otherwise downloads from the stable URL.
    Returns Error msg if both paths fail. *)
let load_package_index () =
  let from_json text =
    match Cn_json.parse text with
    | Ok json -> Ok (parse_package_index json)
    | Error msg -> Error (Printf.sprintf "package index parse error: %s" msg)
  in
  match find_local_index_path () with
  | Some path -> from_json (Cn_ffi.Fs.read path)
  | None ->
      let url = package_index_url () in
      (match Cn_ffi.Http.get ~url ~headers:[] with
       | Ok body -> from_json body
       | Error msg ->
           Error (Printf.sprintf "could not fetch package index from %s: %s"
             url msg))

(* === Filesystem helpers === *)

(** Recursive copy: src_dir -> dst_dir, preserving structure. Used by
    development local-source restore and exposed for tests. *)
let rec copy_tree src_dir dst_dir =
  if Cn_ffi.Fs.exists src_dir then begin
    Cn_ffi.Fs.ensure_dir dst_dir;
    try
      Cn_ffi.Fs.readdir src_dir
      |> List.iter (fun entry ->
        let src = Cn_ffi.Path.join src_dir entry in
        let dst = Cn_ffi.Path.join dst_dir entry in
        if Sys.is_directory src then
          copy_tree src dst
        else
          Cn_ffi.Fs.write dst (Cn_ffi.Fs.read src))
    with exn ->
      Printf.eprintf "cn: warning: cannot copy tree %s: %s\n"
        src_dir (Printexc.to_string exn)
  end

let rm_tree path =
  if Cn_ffi.Fs.exists path then
    ignore (Cn_ffi.Process.exec_args ~prog:"rm" ~args:["-rf"; path] ())

(* === First-party local source resolution (development) === *)

let is_first_party name =
  String.length name >= 5 && String.sub name 0 5 = "cnos."

let find_local_package_source pkg_name =
  let rec walk dir =
    let candidate = Cn_ffi.Path.join dir
      (Printf.sprintf "packages/%s/cn.package.json" pkg_name) in
    if Cn_ffi.Fs.exists candidate then
      Ok (Cn_ffi.Path.join dir (Printf.sprintf "packages/%s" pkg_name))
    else
      let parent = Filename.dirname dir in
      if parent = dir then Error "not found locally"
      else walk parent
  in
  walk (Cn_ffi.Process.cwd ())

(* === HTTP download + extract === *)

(** Download a binary blob to a file using `curl --output`. curl writes
    directly to disk so binary content never passes through an OCaml
    string buffer. *)
let download_to_file ~url ~dest =
  let dir = Filename.dirname dest in
  Cn_ffi.Fs.ensure_dir dir;
  let (code, output) = Cn_ffi.Process.exec_args
    ~prog:"curl"
    ~args:[
      "--silent"; "--show-error"; "--fail";
      "--location";
      "--connect-timeout"; "10";
      "--max-time"; "300";
      "--output"; dest;
      url;
    ] ()
  in
  if code = 0 then Ok ()
  else Error (Printf.sprintf "curl exit %d: %s" code (String.trim output))

(** Compute SHA-256 of a file using the stdlib path: read fully, hash. *)
let sha256_of_file path =
  let content = Cn_ffi.Fs.read path in
  Cn_sha256.hash content

(** Extract a .tar.gz into dest_dir using `tar -xzf`. dest_dir must exist. *)
let extract_tarball ~tarball ~dest_dir =
  Cn_ffi.Fs.ensure_dir dest_dir;
  let (code, output) = Cn_ffi.Process.exec_args
    ~prog:"tar"
    ~args:["-xzf"; tarball; "-C"; dest_dir]
    ()
  in
  if code = 0 then Ok ()
  else Error (Printf.sprintf "tar exit %d: %s" code (String.trim output))

(** Validate the cn.package.json file inside an extracted package directory:
    must exist, be parseable, and declare a name matching the lock entry. *)
let validate_extracted ~pkg_dir ~expected_name =
  let meta = Cn_ffi.Path.join pkg_dir "cn.package.json" in
  if not (Cn_ffi.Fs.exists meta) then
    Error "missing cn.package.json after extraction"
  else
    match Cn_json.parse (Cn_ffi.Fs.read meta) with
    | Error msg -> Error (Printf.sprintf "invalid cn.package.json: %s" msg)
    | Ok json ->
        match Cn_json.get_string "name" json with
        | None -> Error "cn.package.json missing 'name' field"
        | Some n when n <> expected_name ->
            Error (Printf.sprintf
              "cn.package.json name '%s' does not match expected '%s'"
              n expected_name)
        | Some _ -> Ok ()

(* === Restore === *)

(** Install one package from its lock entry via HTTP tarball.
    Returns None on success, Some err on failure. *)
let restore_one_http ~hub_path ~index (dep : locked_dep) =
  let pkg_root = Cn_assets.vendor_packages_path hub_path in
  let pkg_dir = Cn_ffi.Path.join pkg_root
    (Printf.sprintf "%s@%s" dep.name dep.version) in
  if Cn_ffi.Fs.exists pkg_dir then
    (* Already materialised. The lockfile sha256 is an on-the-wire
       check and cannot be recomputed from the extracted tree. *)
    None
  else
    match lookup_index index ~name:dep.name ~version:dep.version with
    | None ->
        Some (Printf.sprintf "Package %s@%s not in index" dep.name dep.version)
    | Some entry ->
        let tmp_tar = Cn_ffi.Path.join hub_path
          (Printf.sprintf ".cn/tmp/%s-%s.tar.gz" dep.name dep.version) in
        (match download_to_file ~url:entry.ie_url ~dest:tmp_tar with
         | Error msg ->
             Some (Printf.sprintf "Failed to download %s@%s from %s: %s"
               dep.name dep.version entry.ie_url msg)
         | Ok () ->
             let actual = sha256_of_file tmp_tar in
             if actual <> dep.sha256 then begin
               (try Sys.remove tmp_tar with _ -> ());
               Some (Printf.sprintf
                 "SHA-256 mismatch for %s@%s: expected %s, got %s"
                 dep.name dep.version dep.sha256 actual)
             end else begin
               Cn_ffi.Fs.ensure_dir pkg_dir;
               let result = extract_tarball ~tarball:tmp_tar ~dest_dir:pkg_dir in
               (try Sys.remove tmp_tar with _ -> ());
               match result with
               | Error msg ->
                   rm_tree pkg_dir;
                   Some (Printf.sprintf "Failed to extract %s@%s: %s"
                     dep.name dep.version msg)
               | Ok () ->
                   match validate_extracted ~pkg_dir ~expected_name:dep.name with
                   | Ok () -> None
                   | Error msg ->
                       rm_tree pkg_dir;
                       Some (Printf.sprintf "Package %s@%s: %s"
                         dep.name dep.version msg)
             end)

(** Try local first-party install (development mode). Returns:
    - Some (Ok ())  : installed from local checkout
    - Some (Error m): tried, failed (e.g. stale build)
    - None          : not applicable (no local source) *)
let try_restore_local ~hub_path (dep : locked_dep) =
  if not (is_first_party dep.name) then None
  else
    match find_local_package_source dep.name with
    | Error _ -> None
    | Ok local_path ->
        match Cn_build.check_package dep.name with
        | Error msg -> Some (Error msg)
        | Ok () ->
            let pkg_root = Cn_assets.vendor_packages_path hub_path in
            let pkg_dir = Cn_ffi.Path.join pkg_root
              (Printf.sprintf "%s@%s" dep.name dep.version) in
            Cn_ffi.Fs.ensure_dir pkg_dir;
            copy_tree local_path pkg_dir;
            Some (Ok ())

(** Install one package: prefer local first-party source if running inside
    a cnos checkout, otherwise HTTP artifact restore. *)
let restore_one ~hub_path ~index (dep : locked_dep) =
  let pkg_root = Cn_assets.vendor_packages_path hub_path in
  let pkg_dir = Cn_ffi.Path.join pkg_root
    (Printf.sprintf "%s@%s" dep.name dep.version) in
  if Cn_ffi.Fs.exists pkg_dir then None
  else
    match try_restore_local ~hub_path dep with
    | Some (Ok ()) -> None
    | Some (Error msg) -> Some (Printf.sprintf "Package %s@%s: %s"
                            dep.name dep.version msg)
    | None -> restore_one_http ~hub_path ~index dep

(** Install every package declared in the lockfile into
    .cn/vendor/packages/. *)
let restore ~hub_path =
  match read_lockfile ~hub_path with
  | None -> Ok ()
  | Some lock when lock.packages = [] -> Ok ()
  | Some lock ->
      (match load_package_index () with
       | Error msg ->
           (* No index: fall back to local-source restore for any
              first-party package found in a cnos checkout. *)
           let errors = lock.packages |> List.filter_map (fun dep ->
             match try_restore_local ~hub_path dep with
             | Some (Ok ()) -> None
             | Some (Error m) ->
                 Some (Printf.sprintf "Package %s@%s: %s"
                   dep.name dep.version m)
             | None ->
                 Some (Printf.sprintf "Package %s@%s: %s"
                   dep.name dep.version msg))
           in
           (match errors with
            | [] -> Ok ()
            | es -> Error (String.concat "\n" es))
       | Ok index ->
           let errors = lock.packages |> List.filter_map (fun dep ->
             restore_one ~hub_path ~index dep
           ) in
           (match errors with
            | [] -> Ok ()
            | es -> Error (String.concat "\n" es)))

(* === List installed === *)

let list_installed ~hub_path =
  let pkg_root = Cn_assets.vendor_packages_path hub_path in
  if not (Cn_ffi.Fs.exists pkg_root) then []
  else
    try
      Cn_ffi.Fs.readdir pkg_root
      |> List.sort String.compare
      |> List.filter_map (fun dir_name ->
        match String.index_opt dir_name '@' with
        | Some i ->
            let name = String.sub dir_name 0 i in
            let version = String.sub dir_name (i + 1)
              (String.length dir_name - i - 1) in
            Some (name, version)
        | None -> Some (dir_name, "unknown"))
    with _ -> []

(* === Doctor === *)

let is_valid_vendored_package pkg_dir =
  if not (Cn_ffi.Fs.exists pkg_dir) then false
  else
    let meta = Cn_ffi.Path.join pkg_dir "cn.package.json" in
    if not (Cn_ffi.Fs.exists meta) then false
    else
      match Cn_json.parse (Cn_ffi.Fs.read meta) with
      | Ok json -> Cn_json.get_string "name" json <> None
      | Error _ -> false

(** Verify installed packages match lockfile. Returns Ok () or Error
    with the list of issues found. *)
let doctor ~hub_path =
  let issues = ref [] in
  let add msg = issues := msg :: !issues in

  (match Cn_assets.validate_packages ~hub_path with
   | Ok () -> ()
   | Error msg -> add msg);

  let manifest_opt =
    if not (Cn_ffi.Fs.exists (manifest_path hub_path)) then begin
      add "Missing .cn/deps.json — run 'cn setup'"; None
    end else
      match read_manifest ~hub_path with
      | None -> add "Cannot parse .cn/deps.json"; None
      | Some m -> Some m
  in

  if not (Cn_ffi.Fs.exists (lockfile_path hub_path)) then
    add "Missing .cn/deps.lock.json — run 'cn setup'"
  else begin
    match read_lockfile ~hub_path with
    | None -> add "Cannot parse .cn/deps.lock.json"
    | Some lock ->
        let pkg_root = Cn_assets.vendor_packages_path hub_path in

        (match manifest_opt with
         | Some manifest ->
           manifest.packages |> List.iter (fun (dep : manifest_dep) ->
             let in_lock = lock.packages |> List.exists
               (fun (ld : locked_dep) -> ld.name = dep.name) in
             if not in_lock then
               add (Printf.sprintf
                 "Package %s in manifest but not in lockfile — run 'cn deps update'"
                 dep.name))
         | None -> ());

        lock.packages |> List.iter (fun (dep : locked_dep) ->
          let pkg_dir = Cn_ffi.Path.join pkg_root
            (Printf.sprintf "%s@%s" dep.name dep.version) in
          if not (Cn_ffi.Fs.exists pkg_dir) then
            add (Printf.sprintf
              "Package %s@%s declared in lockfile but not installed"
              dep.name dep.version)
          else begin
            let meta_path = Cn_ffi.Path.join pkg_dir "cn.package.json" in
            if not (Cn_ffi.Fs.exists meta_path) then
              add (Printf.sprintf "Package %s@%s missing cn.package.json"
                dep.name dep.version)
            else begin
              let content = Cn_ffi.Fs.read meta_path in
              match Cn_json.parse content with
              | Error _ ->
                add (Printf.sprintf "Package %s@%s has invalid cn.package.json"
                  dep.name dep.version)
              | Ok json ->
                (match Cn_json.get_string "name" json with
                 | Some n when n <> dep.name ->
                   add (Printf.sprintf
                     "Package %s@%s metadata name mismatch: cn.package.json says %s"
                     dep.name dep.version n)
                 | _ -> ())
            end
          end);

        if Cn_ffi.Fs.exists pkg_root then begin
          try
            Cn_ffi.Fs.readdir pkg_root |> List.iter (fun dir_name ->
              match String.index_opt dir_name '@' with
              | Some i ->
                let name = String.sub dir_name 0 i in
                let version = String.sub dir_name (i + 1)
                  (String.length dir_name - i - 1) in
                let in_lock = lock.packages |> List.exists
                  (fun (ld : locked_dep) ->
                    ld.name = name && ld.version = version) in
                if not in_lock then begin
                  let pkg_dir = Cn_ffi.Path.join pkg_root dir_name in
                  if not (is_valid_vendored_package pkg_dir) then
                    add (Printf.sprintf
                      "Package %s@%s installed but not in lockfile (stale install?)"
                      name version)
                end
              | None -> ())
          with _ -> ()
        end
  end;

  match !issues with
  | [] -> Ok ()
  | is -> Error (List.rev is)

(* === Default manifest + lockfile generation === *)

let default_manifest_for_profile profile =
  let ver = Cn_lib.version in
  let packages = [
    { name = "cnos.core"; version = ver };
    { name = "cnos.eng"; version = ver };
  ] in
  { schema = "cn.deps.v1"; profile; packages }

(** Build a lockfile from the manifest by resolving each package
    against the package index. Third-party packages are rejected. *)
let lockfile_for_manifest (m : manifest) =
  let third_party = m.packages
    |> List.filter (fun (d : manifest_dep) -> not (is_first_party d.name)) in
  if third_party <> [] then
    let names = third_party
      |> List.map (fun (d : manifest_dep) -> d.name)
      |> String.concat ", " in
    Error (Printf.sprintf
      "Third-party packages not supported (no registry): %s" names)
  else
    match load_package_index () with
    | Error msg ->
        Error (Printf.sprintf
          "Cannot build lockfile: %s. Run 'scripts/build-packages.sh' \
           inside the cnos repo to generate packages/index.json." msg)
    | Ok index ->
        let rec collect acc = function
          | [] -> Ok (List.rev acc)
          | (d : manifest_dep) :: rest ->
              (match lookup_index index ~name:d.name ~version:d.version with
               | None ->
                   Error (Printf.sprintf
                     "Package %s@%s not found in package index"
                     d.name d.version)
               | Some entry ->
                   let lock_entry = {
                     name = d.name;
                     version = d.version;
                     sha256 = entry.ie_sha256;
                   } in
                   collect (lock_entry :: acc) rest)
        in
        match collect [] m.packages with
        | Error e -> Error e
        | Ok packages -> Ok { schema = "cn.lock.v2"; packages }

(* === CLI entry points === *)

let run_list ~hub_path =
  let installed = list_installed ~hub_path in
  if installed = [] then
    print_endline (Cn_fmt.dim "No packages installed")
  else begin
    print_endline (Cn_fmt.info "Installed packages:");
    installed |> List.iter (fun (name, version) ->
      print_endline (Printf.sprintf "  %s@%s" name version))
  end;
  match Cn_assets.validate_packages ~hub_path with
  | Ok () -> print_endline (Cn_fmt.ok "Core doctrine: present")
  | Error _ -> print_endline (Cn_fmt.warn "Core doctrine: missing (run 'cn deps restore')")

let run_restore ~hub_path =
  match restore ~hub_path with
  | Ok () ->
      let summary = Cn_assets.summarize ~hub_path in
      let pkg_count = List.length summary.packages in
      let total_skills = List.fold_left (fun acc (_, c) -> acc + c) 0 summary.packages in
      print_endline (Cn_fmt.ok (Printf.sprintf
        "Restored: %d packages, %d doctrine files, %d mindsets, %d skills"
        pkg_count summary.doctrine_count summary.mindset_count total_skills))
  | Error msg ->
      print_endline (Cn_fmt.fail msg);
      Cn_ffi.Process.exit 1

let run_doctor ~hub_path =
  match doctor ~hub_path with
  | Ok () -> print_endline (Cn_fmt.ok "All dependencies verified")
  | Error msgs ->
      msgs |> List.iter (fun m -> print_endline (Cn_fmt.warn m));
      Cn_ffi.Process.exit 1

let run_add ~hub_path pkg_spec =
  let name, version = match String.index_opt pkg_spec '@' with
    | Some i ->
        (String.sub pkg_spec 0 i,
         String.sub pkg_spec (i + 1) (String.length pkg_spec - i - 1))
    | None -> (pkg_spec, "*")
  in
  let manifest = match read_manifest ~hub_path with
    | Some m -> m
    | None -> default_manifest_for_profile "engineer"
  in
  if List.exists (fun (d : manifest_dep) -> d.name = name) manifest.packages then
    print_endline (Cn_fmt.warn (Printf.sprintf "%s already in deps" name))
  else begin
    let manifest = { manifest with
      packages = manifest.packages @ [{ name; version }] } in
    write_manifest ~hub_path manifest;
    print_endline (Cn_fmt.ok (Printf.sprintf "Added %s@%s to .cn/deps.json" name version));
    print_endline (Cn_fmt.dim "Run 'cn deps update' to resolve and 'cn deps restore' to install")
  end

let run_remove ~hub_path pkg_name =
  match read_manifest ~hub_path with
  | None ->
      print_endline (Cn_fmt.fail "No .cn/deps.json found")
  | Some manifest ->
      let packages = manifest.packages
        |> List.filter (fun (d : manifest_dep) -> d.name <> pkg_name) in
      if List.length packages = List.length manifest.packages then
        print_endline (Cn_fmt.warn (Printf.sprintf "%s not found in deps" pkg_name))
      else begin
        write_manifest ~hub_path { manifest with packages };
        print_endline (Cn_fmt.ok (Printf.sprintf "Removed %s from .cn/deps.json" pkg_name))
      end

let run_vendor ~hub_path =
  let pkg_root = Cn_assets.vendor_packages_path hub_path in
  let all_present =
    match read_lockfile ~hub_path with
    | None -> false
    | Some lock when lock.packages = [] -> false
    | Some lock ->
      lock.packages |> List.for_all (fun (dep : locked_dep) ->
        let pkg_dir = Cn_ffi.Path.join pkg_root
          (Printf.sprintf "%s@%s" dep.name dep.version) in
        is_valid_vendored_package pkg_dir)
  in
  if all_present then
    print_endline (Cn_fmt.dim
      "Vendor tree already populated — skipping fetch (offline-first)")
  else
    (match restore ~hub_path with
     | Ok () -> ()
     | Error msg ->
         print_endline (Cn_fmt.fail msg);
         Cn_ffi.Process.exit 1);
  let gitignore = Cn_ffi.Path.join hub_path ".gitignore" in
  if Cn_ffi.Fs.exists gitignore then begin
    let content = Cn_ffi.Fs.read gitignore in
    let lines = String.split_on_char '\n' content in
    let filtered = lines |> List.filter (fun l ->
      let t = String.trim l in
      t <> ".cn/vendor/" && t <> ".cn/vendor") in
    Cn_ffi.Fs.write gitignore (String.concat "\n" filtered)
  end;
  print_endline (Cn_fmt.ok "Vendor tree ready for commit");
  print_endline (Cn_fmt.dim "Run 'git add .cn/vendor/' to stage")
