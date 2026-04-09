(** cn_frontmatter.ml — Pure SKILL.md frontmatter parser + activation
    validation types.

    This module is the canonical authority for the pure surface of
    activation-index construction:

    - [frontmatter] record type (3 fields: name, description, triggers)
    - [empty_frontmatter] constant
    - Line-level YAML-subset helpers: [split_lines], [extract_block],
      [parse_key_value], [is_list_item], [list_item_value]
    - [parse_frontmatter] — the main parser, line-based YAML subset:
      * [---] markers delimit the frontmatter block
      * [key: value] sets a scalar
      * [key:] followed by indented [- item] lines builds a block list
      * inline lists ([key: \[a, b\]]) are NOT supported in v1
      Anything malformed is logged once on stderr and skipped; the
      parser never raises.
    - [manifest_skill_ids] — reads the [sources.skills] string array
      from a parsed [cn.package.json]
    - [issue_kind] + [issue] + [issue_kind_label] — the activation
      validator's 3-category issue types (distinct from the workflow IR
      validator's 7-category types in [Cn_workflow_ir]; different
      domains, different module paths, no collision)

    It was extracted from [src/cmd/cn_activation.ml] in v3.41.0 as the
    fourth and final slice of Move 2 of the #182 core refactor:
    pure-model gravity into [src/lib/]. With this slice, every pure
    type and parser in the codebase lives in [src/lib/] and every IO
    function lives in [src/cmd/]. The [Cn_activation] module in
    [src/cmd/] re-exports each type via OCaml type-equality syntax
    and delegates each pure function via a one-line let-binding so
    existing callers ([cn_doctor.ml], [test/cmd/cn_activation_test.ml])
    compile without edits. [Cn_activation] retains the IO-side
    functions ([read_skill_frontmatter], [build_index], [validate])
    and the [activation_entry] re-export chain from slice 2 (which
    lives in [Cn_contract] as canonical).

    Discipline (CORE-REFACTOR.md §7): this module may import only
    stdlib and [Cn_json]. No [Cn_ffi], no [Cn_executor], no
    [Cn_contract] (allowed by the issue but not needed this cycle),
    no HTTP, no process exec, no filesystem, no git, no LLM.
    [Printf.eprintf] for discovery-time warnings on malformed data
    is permitted per the stderr precedent established in v3.40.0 and
    documented in CORE-REFACTOR.md §7 — not a process effect in the
    forbidden sense. Verified by grep in the cycle's self-coherence. *)

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

(* === Manifest skill-id reader === *)

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

(* === Doctor validation types ===
   NOTE: these are the activation validator's issue types (3 categories:
   missing skill, empty triggers, trigger conflict). They are distinct
   from [Cn_workflow_ir.issue_kind] (7 categories for workflow IR
   validation) — different domains, different module paths, no
   collision. The field name [kind] (not [issue_kind] like in
   Cn_workflow_ir.issue) is deliberately preserved from the
   pre-extraction definition to avoid caller-side churn. *)

type issue_kind =
  | Missing_skill
  | Empty_triggers
  | Trigger_conflict

type issue = {
  kind : issue_kind;
  message : string;
}

let issue_kind_label = function
  | Missing_skill -> "missing"
  | Empty_triggers -> "empty"
  | Trigger_conflict -> "conflict"
