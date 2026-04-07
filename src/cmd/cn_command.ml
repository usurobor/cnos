(** cn_command.ml — Discovery and dispatch for external CLI commands.

    External commands live in two places:
    - Repo-local: .cn/commands/cn-<name> (executable file inside the hub)
    - Vendored package: commands/<entrypoint> declared under the `commands`
      object of a package's cn.package.json

    Precedence (for a given command name):
      1. Built-in (handled in src/cli/cn.ml — not here)
      2. Repo-local (.cn/commands/cn-<name>)
      3. Vendored package command

    When more than one external command at the *same* layer claims the
    same name, that is a doctor error. Dispatch honours the first match
    in precedence order; doctor reports conflicts. *)

type source =
  | Repo_local
  | Package of string  (** package name, e.g. "cnos.core" *)

type external_cmd = {
  name : string;
  source : source;
  entrypoint_path : string;  (** absolute path on disk *)
  summary : string;
}

let source_label = function
  | Repo_local -> "repo-local"
  | Package pkg -> "package:" ^ pkg

(* === Repo-local discovery === *)

(** Discover executables at .cn/commands/cn-<name>.
    A file must exist and its basename must start with "cn-". *)
let discover_repo_local ~hub_path =
  let dir = Cn_ffi.Path.join hub_path ".cn/commands" in
  if not (Cn_ffi.Fs.exists dir) then []
  else
    try
      Cn_ffi.Fs.readdir dir
      |> List.filter_map (fun entry ->
        if String.length entry > 3 && String.sub entry 0 3 = "cn-" then
          let name = String.sub entry 3 (String.length entry - 3) in
          let path = Cn_ffi.Path.join dir entry in
          if Sys.file_exists path && not (Sys.is_directory path) then
            Some { name;
                   source = Repo_local;
                   entrypoint_path = path;
                   summary = Printf.sprintf "repo-local: %s" entry }
          else None
        else None)
      |> List.sort (fun a b -> compare a.name b.name)
    with _ -> []

(* === Package command discovery === *)

(** Parse the commands object from a package manifest.
    Returns the list of (name, entrypoint, summary). *)
let parse_package_commands manifest_json =
  match Cn_json.get "sources" manifest_json with
  | None -> []
  | Some sources ->
      match Cn_json.get "commands" sources with
      | Some (Cn_json.Object fields) ->
          fields |> List.filter_map (fun (name, entry) ->
            match Cn_json.get_string "entrypoint" entry,
                  Cn_json.get_string "summary" entry with
            | Some ep, Some sm -> Some (name, ep, sm)
            | _ -> None)
      | _ -> []

(** Discover package commands by walking .cn/vendor/packages/<name>@<ver>/
    manifests. *)
let discover_package ~hub_path =
  let pkg_root = Cn_ffi.Path.join hub_path ".cn/vendor/packages" in
  if not (Cn_ffi.Fs.exists pkg_root) then []
  else
    try
      Cn_ffi.Fs.readdir pkg_root
      |> List.sort String.compare
      |> List.concat_map (fun dir_name ->
        let pkg_dir = Cn_ffi.Path.join pkg_root dir_name in
        if not (Sys.is_directory pkg_dir) then []
        else
          let meta = Cn_ffi.Path.join pkg_dir "cn.package.json" in
          if not (Cn_ffi.Fs.exists meta) then []
          else
            match Cn_json.parse (Cn_ffi.Fs.read meta) with
            | Error _ -> []
            | Ok json ->
                let pkg_name = Cn_json.get_string "name" json
                  |> Option.value ~default:dir_name in
                parse_package_commands json
                |> List.map (fun (name, entrypoint, summary) ->
                  { name;
                    source = Package pkg_name;
                    entrypoint_path = Cn_ffi.Path.join pkg_dir entrypoint;
                    summary }))
    with _ -> []

(* === Unified view === *)

(** All external commands, in precedence order: repo-local first, then
    package commands. Does not deduplicate — doctor reports collisions. *)
let discover ~hub_path =
  discover_repo_local ~hub_path @ discover_package ~hub_path

(** Find the first external command matching `name` in precedence order.
    Returns None if nothing matches. *)
let find ~hub_path name =
  List.find_opt (fun c -> c.name = name) (discover ~hub_path)

(* === Dispatch === *)

(** Execute an external command with argv-style args. Inherits stdio.
    Returns the child exit status. Exits the parent with that status
    on success; on spawn failure prints an error and returns non-zero. *)
let dispatch (cmd : external_cmd) ~hub_path ~args =
  if not (Sys.file_exists cmd.entrypoint_path) then begin
    Printf.eprintf "cn: command %s: entrypoint missing: %s\n"
      cmd.name cmd.entrypoint_path;
    2
  end else begin
    (* Unix.access checks X_OK; fall through on failure with a clearer msg. *)
    (try Unix.access cmd.entrypoint_path [Unix.X_OK]
     with Unix.Unix_error (_, _, _) ->
       Printf.eprintf "cn: command %s: entrypoint not executable: %s\n\
                       hint: chmod +x %s\n"
         cmd.name cmd.entrypoint_path cmd.entrypoint_path);
    let pkg_root = match cmd.source with
      | Package _ -> Filename.dirname cmd.entrypoint_path
      | Repo_local -> hub_path
    in
    let env = Array.append (Unix.environment ()) [|
      "CN_HUB_PATH=" ^ hub_path;
      "CN_PACKAGE_ROOT=" ^ pkg_root;
      "CN_COMMAND_NAME=" ^ cmd.name;
    |] in
    let argv = Array.of_list (cmd.entrypoint_path :: args) in
    try
      let pid = Unix.create_process_env
        cmd.entrypoint_path argv env
        Unix.stdin Unix.stdout Unix.stderr in
      let _, status = Unix.waitpid [] pid in
      (match status with
       | Unix.WEXITED c -> c
       | Unix.WSIGNALED s -> 128 + s
       | Unix.WSTOPPED s -> 128 + s)
    with
    | Unix.Unix_error (e, fn, _) ->
        Printf.eprintf "cn: command %s: %s failed: %s\n"
          cmd.name fn (Unix.error_message e);
        2
  end

(* === Doctor validation === *)

(** Collect integrity issues in external command discovery for cn doctor.
    Returns a list of issue strings (empty = healthy). *)
let validate ~hub_path =
  let issues = ref [] in
  let add msg = issues := msg :: !issues in

  (* Repo-local commands: each discovered file must be executable. *)
  discover_repo_local ~hub_path |> List.iter (fun cmd ->
    if Sys.file_exists cmd.entrypoint_path then
      (try Unix.access cmd.entrypoint_path [Unix.X_OK]
       with Unix.Unix_error _ ->
         add (Printf.sprintf
           "repo-local command %s: not executable (%s)"
           cmd.name cmd.entrypoint_path))
    else
      add (Printf.sprintf
        "repo-local command %s: missing entrypoint %s"
        cmd.name cmd.entrypoint_path));

  (* Package commands: manifest metadata, entrypoint presence, exec bit. *)
  let pkg_root = Cn_ffi.Path.join hub_path ".cn/vendor/packages" in
  if Cn_ffi.Fs.exists pkg_root then begin
    (try
       Cn_ffi.Fs.readdir pkg_root |> List.iter (fun dir_name ->
         let pkg_dir = Cn_ffi.Path.join pkg_root dir_name in
         if Sys.is_directory pkg_dir then
           let meta = Cn_ffi.Path.join pkg_dir "cn.package.json" in
           if Cn_ffi.Fs.exists meta then
             match Cn_json.parse (Cn_ffi.Fs.read meta) with
             | Error _ -> ()  (* reported by cn_deps doctor *)
             | Ok json ->
                 let pkg_name = Cn_json.get_string "name" json
                   |> Option.value ~default:dir_name in
                 (match Cn_json.get "sources" json with
                  | None -> ()
                  | Some sources ->
                      match Cn_json.get "commands" sources with
                      | None -> ()
                      | Some (Cn_json.Object fields) ->
                          fields |> List.iter (fun (cmd_name, entry_json) ->
                            match Cn_json.get_string "entrypoint" entry_json,
                                  Cn_json.get_string "summary" entry_json with
                            | None, _ ->
                                add (Printf.sprintf
                                  "package %s: command %s missing entrypoint field"
                                  pkg_name cmd_name)
                            | _, None ->
                                add (Printf.sprintf
                                  "package %s: command %s missing summary field"
                                  pkg_name cmd_name)
                            | Some ep, Some _ ->
                                let full = Cn_ffi.Path.join pkg_dir ep in
                                if not (Sys.file_exists full) then
                                  add (Printf.sprintf
                                    "package %s: command %s entrypoint missing: %s"
                                    pkg_name cmd_name ep)
                                else
                                  (try Unix.access full [Unix.X_OK]
                                   with Unix.Unix_error _ ->
                                     add (Printf.sprintf
                                       "package %s: command %s not executable: %s"
                                       pkg_name cmd_name ep)))
                      | Some _ ->
                          add (Printf.sprintf
                            "package %s: commands field is not an object"
                            pkg_name)))
     with _ -> ())
  end;

  (* Duplicates within the same precedence layer. Repo-local is a flat
     dir so the FS enforces uniqueness. Across packages, two packages
     declaring the same command name collide. *)
  let pkg_cmds = discover_package ~hub_path in
  let rec find_dups acc = function
    | [] -> List.rev acc
    | c :: rest ->
        let dups = List.filter (fun c' -> c'.name = c.name) rest in
        if dups <> [] then find_dups (c.name :: acc)
          (List.filter (fun c' -> c'.name <> c.name) rest)
        else find_dups acc rest
  in
  find_dups [] pkg_cmds |> List.iter (fun name ->
    let owners = pkg_cmds
      |> List.filter (fun c -> c.name = name)
      |> List.map (fun c -> source_label c.source)
      |> String.concat ", " in
    add (Printf.sprintf
      "duplicate package command %s declared by: %s" name owners));

  List.rev !issues
