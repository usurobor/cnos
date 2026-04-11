(** cn_activation.ml — Skill activation index built from installed
    packages (IO plane).

    Each installed package's [cn.package.json] declares which skills it
    exposes via [sources.skills]. For every exposed skill, this module
    reads [<pkg_dir>/skills/<skill_id>/SKILL.md], parses its YAML
    frontmatter, and extracts the [name], [description], and [triggers]
    fields. The result is a flat list of activation entries that the
    runtime contract can render as cognition state.

    v3.41.0 (#182 Move 2 slice 4 — final slice) note: the pure
    frontmatter parser and activation validation types that used to
    live in this module were extracted into [src/lib/cn_frontmatter.ml].
    [Cn_frontmatter] is now the canonical authority for:
    - [frontmatter] record + [empty_frontmatter]
    - Line-level YAML-subset helpers: [split_lines], [extract_block],
      [parse_key_value], [is_list_item], [list_item_value]
    - [parse_frontmatter] (the main parser)
    - [manifest_skill_ids]
    - [issue_kind] (3-variant) + [issue] + [issue_kind_label]

    This module re-exports each type below via OCaml type-equality
    syntax and delegates each pure function as a one-line let-binding
    so existing callers ([cn_doctor.ml], [test/cmd/cn_activation_test.ml])
    compile unchanged. [Cn_activation] retains the IO-side functions:
    [read_skill_frontmatter], [build_index], [validate].

    The [activation_entry] re-export chain from Move 2 slice 2 (v3.39.0)
    stays untouched: [activation_entry] lives in [Cn_contract] as
    canonical, and this module re-exports it via type-equality.

    Slice 4 closes Move 2. Every pure type and parser in the codebase
    now lives in [src/lib/]; every IO function lives in [src/cmd/]. *)

(* === Types (re-exported from Cn_frontmatter for caller compatibility) === *)

type frontmatter = Cn_frontmatter.frontmatter = {
  fm_name : string option;
  fm_description : string option;
  fm_triggers : string list;
}

type issue_kind = Cn_frontmatter.issue_kind =
  | Missing_skill
  | Empty_triggers
  | Trigger_conflict

type issue = Cn_frontmatter.issue = {
  kind : issue_kind;
  message : string;
}

(* === Pure helpers delegated to Cn_frontmatter === *)

let empty_frontmatter = Cn_frontmatter.empty_frontmatter
let split_lines = Cn_frontmatter.split_lines
let extract_block = Cn_frontmatter.extract_block
let parse_key_value = Cn_frontmatter.parse_key_value
let is_list_item = Cn_frontmatter.is_list_item
let list_item_value = Cn_frontmatter.list_item_value
let parse_frontmatter = Cn_frontmatter.parse_frontmatter
let manifest_skill_ids = Cn_frontmatter.manifest_skill_ids
let issue_kind_label = Cn_frontmatter.issue_kind_label

(* === activation_entry re-export from slice 2 (unchanged) ===
    v3.39.0 (#182 Move 2 slice 2): the [activation_entry] type was
    extracted into [src/lib/cn_contract.ml] as a transitive dependency
    of the runtime-contract pure model (the [cognition] record's
    [activation_index] field references it). The canonical definition
    lives in [Cn_contract.activation_entry]; this is a type-equality
    re-export so existing callers of [Cn_activation.activation_entry]
    compile unchanged. *)
type activation_entry = Cn_contract.activation_entry = {
  skill_id : string;
  package : string;
  summary : string;
  triggers : string list;
}

(* === IO-side: read_skill_frontmatter === *)

(** Read a SKILL.md file from disk and parse its frontmatter. Returns
    [None] if the file is missing or unreadable. *)
let read_skill_frontmatter path =
  if not (Cn_ffi.Fs.exists path) then None
  else
    try Some (parse_frontmatter (Cn_ffi.Fs.read path))
    with exn ->
      Printf.eprintf "cn: activation: cannot read %s: %s\n"
        path (Printexc.to_string exn);
      None

(* === IO-side: build_index === *)

(** Walk every installed package and emit one [activation_entry] per
    declared skill that has a SKILL.md on disk. Skills declared in the
    manifest but missing on disk are silently skipped (validate surfaces
    them). Skills present on disk but not declared are excluded. *)
let build_index ~hub_path =
  Cn_assets.list_installed_packages hub_path
  |> List.concat_map (fun (pkg_name, pkg_dir) ->
    let manifest_path = Cn_ffi.Path.join pkg_dir "cn.package.json" in
    if not (Cn_ffi.Fs.exists manifest_path) then []
    else
      match Cn_json.parse (Cn_ffi.Fs.read manifest_path) with
      | Error msg ->
          Printf.eprintf
            "cn: activation: package %s: cannot parse %s: %s\n"
            pkg_name manifest_path msg;
          []
      | Ok json ->
          manifest_skill_ids ~pkg_name json
          |> List.filter_map (fun skill_id ->
            let skill_md = Cn_ffi.Path.join pkg_dir
              (Printf.sprintf "skills/%s/SKILL.md" skill_id) in
            match read_skill_frontmatter skill_md with
            | None -> None
            | Some fm ->
                Some {
                  skill_id;
                  package = pkg_name;
                  summary = Option.value fm.fm_description ~default:"";
                  triggers = fm.fm_triggers;
                }))

(* === IO-side: validate (doctor) === *)

(** Doctor sweep across the activation surface. Returns one [issue] per
    distinct problem found:
    - declared skill with no SKILL.md → [Missing_skill]
    - SKILL.md present but [triggers:] absent or empty → [Empty_triggers]
    - same trigger keyword claimed by two distinct skill ids →
      [Trigger_conflict] (one issue per shared keyword) *)
let validate ~hub_path =
  let issues = ref [] in
  let add kind message =
    issues := { kind; message } :: !issues
  in

  (* Per-package walk for missing/empty issues, accumulating
     (trigger, skill_id) pairs for the conflict pass. *)
  let trigger_pairs = ref [] in
  Cn_assets.list_installed_packages hub_path
  |> List.iter (fun (pkg_name, pkg_dir) ->
    let manifest_path = Cn_ffi.Path.join pkg_dir "cn.package.json" in
    if Cn_ffi.Fs.exists manifest_path then
      match Cn_json.parse (Cn_ffi.Fs.read manifest_path) with
      | Error msg ->
          (* cn_deps doctor is the canonical surface for malformed
             manifests; here we only log for activation-debug context
             so the validate pass doesn't double-report. *)
          Printf.eprintf
            "cn: activation: package %s: cannot parse %s: %s\n"
            pkg_name manifest_path msg
      | Ok json ->
          manifest_skill_ids ~pkg_name json |> List.iter (fun skill_id ->
            let skill_md = Cn_ffi.Path.join pkg_dir
              (Printf.sprintf "skills/%s/SKILL.md" skill_id) in
            if not (Cn_ffi.Fs.exists skill_md) then
              add Missing_skill (Printf.sprintf
                "package %s: declared skill %s missing SKILL.md (%s)"
                pkg_name skill_id skill_md)
            else
              match read_skill_frontmatter skill_md with
              | None ->
                  add Missing_skill (Printf.sprintf
                    "package %s: skill %s has unreadable SKILL.md"
                    pkg_name skill_id)
              | Some fm ->
                  if fm.fm_triggers = [] then
                    add Empty_triggers (Printf.sprintf
                      "package %s: skill %s has no triggers"
                      pkg_name skill_id)
                  else
                    fm.fm_triggers |> List.iter (fun t ->
                      trigger_pairs := (t, skill_id) :: !trigger_pairs)));

  (* Conflict pass: group by trigger; flag any trigger claimed by more
     than one distinct skill_id. *)
  let by_trigger = Hashtbl.create 32 in
  !trigger_pairs |> List.iter (fun (t, sid) ->
    let prev = try Hashtbl.find by_trigger t with Not_found -> [] in
    if not (List.mem sid prev) then
      Hashtbl.replace by_trigger t (sid :: prev));
  Hashtbl.iter (fun t sids ->
    if List.length sids > 1 then
      add Trigger_conflict (Printf.sprintf
        "trigger %s claimed by: %s"
        t (String.concat ", " (List.sort compare sids)))
  ) by_trigger;

  List.rev !issues
