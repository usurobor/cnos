(** cn_placement.ml — Hub placement models (#156)

    Resolves hub_root and workspace_root from placement manifest.
    Supports standalone (hub_root = workspace_root) and attached
    (hub_root != workspace_root) placement modes.

    Discovery: check .cn/placement.json → if present, parse and resolve
    explicit roots. If absent, fall back to standalone behavior. *)

(* === Types === *)

type backend_kind = Nested_clone | Submodule

type backend = {
  kind : backend_kind;
  remote : string;
}

type mode = Standalone | Attached

type placement = {
  mode : mode;
  hub_root : string;
  workspace_root : string;
  backend : backend option;
}

(* === Parsing === *)

(** Parse a placement manifest JSON string.
    Returns None if parsing fails or required fields are missing. *)
let parse_manifest json_str =
  match Cn_json.parse json_str with
  | Error _ -> None
  | Ok json ->
      let schema = Cn_json.get_string "schema" json in
      match schema with
      | Some "cn.hub_placement.v1" ->
          let mode_str = Cn_json.get_string "mode" json in
          let hub_root = Cn_json.get_string "hub_root" json in
          let workspace_root = Cn_json.get_string "workspace_root" json in
          (match mode_str, hub_root, workspace_root with
           | Some "standalone", _, _ ->
               Some { mode = Standalone; hub_root = "."; workspace_root = ".";
                      backend = None }
           | Some "attached", Some hr, Some wr ->
               let backend = match Cn_json.get "backend" json with
                 | Some bk ->
                     let kind = match Cn_json.get_string "kind" bk with
                       | Some "nested_clone" -> Some Nested_clone
                       | Some "submodule" -> Some Submodule
                       | _ -> None
                     in
                     let remote = Cn_json.get_string "remote" bk in
                     (match kind, remote with
                      | Some k, Some r -> Some { kind = k; remote = r }
                      | _ -> None)
                 | None -> None
               in
               Some { mode = Attached; hub_root = hr; workspace_root = wr;
                      backend }
           | _ -> None)
      | _ -> None

(* === Resolution === *)

(** Resolve a placement manifest relative to a discovery root.
    Takes the directory containing .cn/ and returns absolute paths. *)
let resolve ~discovery_root placement =
  let abs path =
    if Filename.is_relative path then
      Cn_ffi.Path.join discovery_root path
    else path
  in
  { placement with
    hub_root = abs placement.hub_root;
    workspace_root = abs placement.workspace_root }

(** Find placement from a directory.
    Checks for .cn/placement.json. If found, parses and resolves.
    If not found, returns None (caller should use standalone fallback). *)
let find_placement dir =
  let manifest_path = Cn_ffi.Path.join dir ".cn/placement.json" in
  if Cn_ffi.Fs.exists manifest_path then
    match Cn_ffi.Fs.read manifest_path |> parse_manifest with
    | Some p -> Some (resolve ~discovery_root:dir p)
    | None ->
        Printf.eprintf "[placement] Warning: .cn/placement.json exists but is invalid — ignoring\n%!";
        None
  else
    None

(** Make a standalone placement for a given hub path.
    Used when no placement manifest exists (backward compat). *)
let standalone hub_path =
  { mode = Standalone;
    hub_root = hub_path;
    workspace_root = hub_path;
    backend = None }

(* === Accessors === *)

let is_attached p = p.mode = Attached

let backend_kind_to_string = function
  | Nested_clone -> "nested_clone"
  | Submodule -> "submodule"

let mode_to_string = function
  | Standalone -> "standalone"
  | Attached -> "attached"
