(** cn_activation.ml — Skill activation index built from installed
    packages.

    Each installed package's [cn.package.json] declares which skills it
    exposes via [sources.skills]. For every exposed skill, this module
    reads [<pkg_dir>/skills/<skill_id>/SKILL.md], parses its YAML
    frontmatter, and extracts the [name], [description], and [triggers]
    fields. The result is a flat list of activation entries that the
    runtime contract can render as cognition state.

    The frontmatter parser is a small line-based YAML subset:
      - [---] markers delimit the frontmatter block
      - [key: value] sets a scalar
      - [key:] followed by indented [- item] lines builds a block list
      - inline lists ([key: \[a, b\]]) are NOT supported in v1
    Anything malformed is logged once on stderr and skipped; the parser
    never raises. *)

(* === Frontmatter === *)

type frontmatter = {
  fm_name : string option;
  fm_description : string option;
  fm_triggers : string list;
}

let empty_frontmatter = {
  fm_name = None;
  fm_description = None;
  fm_triggers = [];
}

let split_lines s = String.split_on_char '\n' s

(** Take the lines that lie between the first and second [---] marker.
    Returns [None] if either marker is missing. The marker lines must
    appear on their own (after trimming). *)
let extract_block lines =
  let is_marker l = String.trim l = "---" in
  match lines with
  | first :: rest when is_marker first ->
      let rec take acc = function
        | [] -> None  (* unterminated *)
        | l :: _ when is_marker l -> Some (List.rev acc)
        | l :: tl -> take (l :: acc) tl
      in
      take [] rest
  | _ -> None  (* no leading "---": file has no frontmatter — not an error *)

(** Split a "key: value" line. Returns [None] if there is no colon at
    the head of an unindented line. *)
let parse_key_value line =
  match String.index_opt line ':' with
  | None -> None
  | Some i ->
      let key = String.sub line 0 i |> String.trim in
      let value =
        let rest = String.sub line (i + 1) (String.length line - i - 1) in
        String.trim rest
      in
      if key = "" then None else Some (key, value)

(** True iff a line is an indented YAML list item ("  - item"). *)
let is_list_item line =
  let trimmed = String.trim line in
  String.length trimmed >= 2
  && String.sub trimmed 0 2 = "- "

let list_item_value line =
  let trimmed = String.trim line in
  String.sub trimmed 2 (String.length trimmed - 2) |> String.trim

(** Parse a SKILL.md frontmatter into a [frontmatter] record. Always
    succeeds; missing or malformed input yields [empty_frontmatter] or
    a partially populated record. *)
let parse_frontmatter content =
  match extract_block (split_lines content) with
  | None -> empty_frontmatter
  | Some block ->
      let fm = ref empty_frontmatter in
      let pending_list_key = ref None in
      let triggers_acc = ref [] in
      let flush_list () =
        match !pending_list_key with
        | Some "triggers" ->
            fm := { !fm with fm_triggers = List.rev !triggers_acc }
        | Some _ | None -> ()
        ; pending_list_key := None
        ; triggers_acc := []
      in
      List.iter (fun line ->
        if String.trim line = "" then ()
        else if is_list_item line && !pending_list_key <> None then
          triggers_acc := list_item_value line :: !triggers_acc
        else begin
          flush_list ();
          match parse_key_value line with
          | None ->
              Printf.eprintf "cn: activation: skipping malformed line: %s\n" line
          | Some (key, value) ->
              if value = "" then
                pending_list_key := Some key
              else begin
                (match key with
                 | "name" -> fm := { !fm with fm_name = Some value }
                 | "description" -> fm := { !fm with fm_description = Some value }
                 | "triggers" ->
                     (* Inline form not supported; warn and ignore. *)
                     Printf.eprintf
                       "cn: activation: inline triggers list not supported, \
                        use block list: %s\n" value
                 | _ ->
                     (* Unrecognised frontmatter key (artifact_class,
                        kata_surface, governing_question, ...) —
                        intentionally ignored; this parser only
                        consumes name / description / triggers. *)
                     ())
              end
        end
      ) block;
      flush_list ();
      !fm

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

(* === Activation index === *)

type activation_entry = {
  skill_id : string;
  package : string;
  summary : string;
  triggers : string list;
}

(** Read the [sources.skills] string array from a parsed manifest. *)
let manifest_skill_ids ~pkg_name json =
  match Cn_json.get "sources" json with
  | None -> []
  | Some sources ->
      match Cn_json.get "skills" sources with
      | None -> []
      | Some (Cn_json.Array items) ->
          items |> List.filter_map (function
            | Cn_json.String s -> Some s
            | other ->
                Printf.eprintf
                  "cn: activation: package %s: sources.skills entry is not a \
                   string (%s), skipping\n"
                  pkg_name (Cn_json.to_string other);
                None)
      | Some _ ->
          Printf.eprintf
            "cn: activation: package %s: sources.skills is not an array, ignoring\n"
            pkg_name;
          []

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

(* === Doctor validation === *)

type issue_kind =
  | Missing_skill
  | Empty_triggers
  | Trigger_conflict

type issue = {
  kind : issue_kind;
  message : string;
}

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

let issue_kind_label = function
  | Missing_skill -> "missing"
  | Empty_triggers -> "empty"
  | Trigger_conflict -> "conflict"
