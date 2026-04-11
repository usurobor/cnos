(** cn_package.ml — Pure package manifest, lockfile, and index
    types + JSON serialization + lookup helpers.

    This module is the canonical authority for the shape of:
    - [.cn/deps.json] (manifest) — what the operator wants
    - [.cn/deps.lock.json] (lockfile) — what was pinned
    - [packages/index.json] (package index) — name+version → URL+sha256

    It was extracted from [src/cmd/cn_deps.ml] in v3.38.0 as the
    first slice of Move 2 of the #182 core refactor: pure-model
    gravity into [src/lib/]. The [Cn_deps] module in [src/cmd/]
    re-exports each type via OCaml type-equality syntax so
    existing callers compile without edits; [Cn_deps] retains only
    the IO-side functions (read/write, download, extract, restore,
    doctor, lockfile_for_manifest).

    Discipline (CORE-REFACTOR.md §7): this module may import only
    stdlib and [Cn_json]. No [Cn_ffi], no [Cn_executor], no HTTP,
    no process exec, no filesystem, no git, no LLM. Verified by
    grep in the cycle's self-coherence. *)

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

(* === JSON: manifest_dep === *)

let manifest_dep_to_json (d : manifest_dep) : Cn_json.t =
  Cn_json.Object [
    "name", Cn_json.String d.name;
    "version", Cn_json.String d.version;
  ]

let parse_manifest_dep json : manifest_dep option =
  match Cn_json.get_string "name" json,
        Cn_json.get_string "version" json with
  | Some name, Some version -> Some { name; version }
  | _ -> None

(* === JSON: locked_dep === *)

let locked_dep_to_json (d : locked_dep) : Cn_json.t =
  Cn_json.Object [
    "name", Cn_json.String d.name;
    "version", Cn_json.String d.version;
    "sha256", Cn_json.String d.sha256;
  ]

let parse_locked_dep json : locked_dep option =
  match Cn_json.get_string "name" json,
        Cn_json.get_string "version" json,
        Cn_json.get_string "sha256" json with
  | Some name, Some version, Some sha256 ->
      Some { name; version; sha256 }
  | _ -> None

(* === JSON: package_index === *)

(** Parse a [cn.package-index.v1] JSON document. Malformed version
    entries (missing url or sha256) are silently dropped. *)
let parse_package_index json : package_index =
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
                    Some ((name, version),
                          { ie_url = url; ie_sha256 = sha256 })
                | _ -> None)
          | _ -> [])
    | _ -> []
  in
  { index_schema = schema; index_entries = entries }

(** Look up an index entry by name+version. Returns [None] if the
    pair is not in the index. *)
let lookup_index (idx : package_index) ~name ~version : index_entry option =
  List.assoc_opt (name, version) idx.index_entries

(* === First-party name check === *)

(** True iff [name] is a first-party cnos package name — i.e.,
    starts with the literal prefix ["cnos."]. Semantics preserved
    exactly from the pre-extraction [Cn_deps.is_first_party]. *)
let is_first_party name =
  String.length name >= 5
  && String.sub name 0 5 = "cnos."
