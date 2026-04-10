(** cn_frontmatter_test: ppx_expect tests for the pure activation
    frontmatter parser + validation types extracted from
    cn_activation.ml in v3.41.0 (#182 Move 2 slice 4 — final slice).

    The module under test (`Cn_frontmatter`) owns the canonical:
    - 3 types: frontmatter, issue_kind (3-variant), issue
    - 1 constant: empty_frontmatter
    - 6 line-level parsers: split_lines, extract_block,
      parse_key_value, is_list_item, list_item_value, parse_frontmatter
    - 2 helpers: manifest_skill_ids, issue_kind_label

    Coverage map:
    F1   frontmatter record construction + field read (empty)
    F2   empty_frontmatter constant

    E1   extract_block happy path (well-formed block)
    E2   extract_block missing leading marker returns None
    E3   extract_block unterminated (no closing marker) returns None
    E4   extract_block empty block (consecutive markers) returns Some []

    K1   parse_key_value happy path
    K2   parse_key_value no colon returns None
    K3   parse_key_value empty key returns None

    L1   is_list_item on indented "- item" returns true
    L2   is_list_item on non-list line returns false
    L3   list_item_value strips "- " prefix

    P1   parse_frontmatter full happy path (name + description + triggers)
    P2   parse_frontmatter missing markers yields empty_frontmatter
    P3   parse_frontmatter scalar-only (no block list) yields scalars set, triggers empty
    P4   parse_frontmatter ignores unrecognised keys

    M1   manifest_skill_ids happy path
    M2   manifest_skill_ids missing sources
    M3   manifest_skill_ids malformed orchestrators field (wrong type)

    IK1  issue_kind_label exhaustive over all 3 variants

    I1   issue record construction with each of the 3 issue_kind variants *)

(* === F1, F2: frontmatter record + empty_frontmatter === *)

let%expect_test "F1 frontmatter record construction + field read" =
  let fm : Cn_frontmatter.frontmatter = {
    fm_name = Some "cdd";
    fm_description = Some "Apply Coherence-Driven Development";
    fm_triggers = ["cdd"; "coherence"];
  } in
  Printf.printf "name=%s description=%s triggers=%s\n"
    (Option.value fm.fm_name ~default:"(none)")
    (Option.value fm.fm_description ~default:"(none)")
    (String.concat "," fm.fm_triggers);
  [%expect {| name=cdd description=Apply Coherence-Driven Development triggers=cdd,coherence |}]

let%expect_test "F2 empty_frontmatter constant" =
  let fm = Cn_frontmatter.empty_frontmatter in
  Printf.printf "name_is_none=%b description_is_none=%b triggers_is_empty=%b\n"
    (fm.fm_name = None) (fm.fm_description = None) (fm.fm_triggers = []);
  [%expect {| name_is_none=true description_is_none=true triggers_is_empty=true |}]

(* === E1–E4: extract_block === *)

let%expect_test "E1 extract_block happy path" =
  let lines = ["---"; "name: cdd"; "description: test"; "---"; "# body"] in
  (match Cn_frontmatter.extract_block lines with
   | None -> print_endline "unexpectedly None"
   | Some block ->
       Printf.printf "block_length=%d\n" (List.length block);
       List.iter (fun l -> Printf.printf "  - %s\n" l) block);
  [%expect {|
    block_length=2
      - name: cdd
      - description: test |}]

let%expect_test "E2 extract_block no leading marker returns None" =
  let lines = ["name: cdd"; "description: test"; "---"] in
  (match Cn_frontmatter.extract_block lines with
   | None -> print_endline "None"
   | Some _ -> print_endline "unexpectedly Some");
  [%expect {| None |}]

let%expect_test "E3 extract_block unterminated returns None" =
  let lines = ["---"; "name: cdd"; "description: test"] in
  (match Cn_frontmatter.extract_block lines with
   | None -> print_endline "None"
   | Some _ -> print_endline "unexpectedly Some");
  [%expect {| None |}]

let%expect_test "E4 extract_block empty block returns Some []" =
  let lines = ["---"; "---"; "# body"] in
  (match Cn_frontmatter.extract_block lines with
   | None -> print_endline "unexpectedly None"
   | Some block -> Printf.printf "length=%d\n" (List.length block));
  [%expect {| length=0 |}]

(* === K1–K3: parse_key_value === *)

let%expect_test "K1 parse_key_value happy path" =
  (match Cn_frontmatter.parse_key_value "name: cdd" with
   | None -> print_endline "None"
   | Some (k, v) -> Printf.printf "key=%s value=%s\n" k v);
  [%expect {| key=name value=cdd |}]

let%expect_test "K2 parse_key_value no colon returns None" =
  (match Cn_frontmatter.parse_key_value "just a line" with
   | None -> print_endline "None"
   | Some _ -> print_endline "unexpectedly Some");
  [%expect {| None |}]

let%expect_test "K3 parse_key_value empty key returns None" =
  (match Cn_frontmatter.parse_key_value ": orphan value" with
   | None -> print_endline "None"
   | Some _ -> print_endline "unexpectedly Some");
  [%expect {| None |}]

(* === L1–L3: is_list_item + list_item_value === *)

let%expect_test "L1 is_list_item on indented list item" =
  Printf.printf "indented=%b at_root=%b with_tab=%b\n"
    (Cn_frontmatter.is_list_item "  - item")
    (Cn_frontmatter.is_list_item "- item")
    (Cn_frontmatter.is_list_item "\t- item");
  [%expect {| indented=true at_root=true with_tab=true |}]

let%expect_test "L2 is_list_item on non-list line returns false" =
  Printf.printf "scalar=%b empty=%b dash_only=%b\n"
    (Cn_frontmatter.is_list_item "name: cdd")
    (Cn_frontmatter.is_list_item "")
    (Cn_frontmatter.is_list_item "-no-space");
  [%expect {| scalar=false empty=false dash_only=false |}]

let%expect_test "L3 list_item_value strips prefix" =
  print_endline (Cn_frontmatter.list_item_value "  - hello");
  print_endline (Cn_frontmatter.list_item_value "- world");
  [%expect {|
    hello
    world |}]

(* === P1: parse_frontmatter full happy path === *)

let%expect_test "P1 parse_frontmatter full happy path" =
  let content =
    "---\n\
     name: cdd\n\
     description: Apply Coherence-Driven Development\n\
     triggers:\n\
     \  - cdd\n\
     \  - coherence\n\
     \  - cycle\n\
     ---\n\
     # Body content here\n"
  in
  let fm = Cn_frontmatter.parse_frontmatter content in
  Printf.printf "name=%s description=%s triggers_count=%d triggers=%s\n"
    (Option.value fm.fm_name ~default:"(none)")
    (Option.value fm.fm_description ~default:"(none)")
    (List.length fm.fm_triggers)
    (String.concat "," fm.fm_triggers);
  [%expect {| name=cdd description=Apply Coherence-Driven Development triggers_count=3 triggers=cdd,coherence,cycle |}]

(* === P2: parse_frontmatter missing markers yields empty === *)

let%expect_test "P2 parse_frontmatter no frontmatter yields empty" =
  let content = "# Just body content, no frontmatter\n\nparagraph.\n" in
  let fm = Cn_frontmatter.parse_frontmatter content in
  Printf.printf "is_empty=%b\n"
    (fm = Cn_frontmatter.empty_frontmatter);
  [%expect {| is_empty=true |}]

(* === P3: parse_frontmatter scalar-only (no triggers block) === *)

let%expect_test "P3 parse_frontmatter scalar-only no triggers block" =
  let content =
    "---\n\
     name: scalar-only\n\
     description: has no triggers list\n\
     ---\n\
     body\n"
  in
  let fm = Cn_frontmatter.parse_frontmatter content in
  Printf.printf "name=%s description=%s triggers_count=%d\n"
    (Option.value fm.fm_name ~default:"(none)")
    (Option.value fm.fm_description ~default:"(none)")
    (List.length fm.fm_triggers);
  [%expect {| name=scalar-only description=has no triggers list triggers_count=0 |}]

(* === P4: parse_frontmatter ignores unrecognised keys === *)

let%expect_test "P4 parse_frontmatter ignores unrecognised keys" =
  let content =
    "---\n\
     name: cdd\n\
     artifact_class: skill\n\
     kata_surface: embedded\n\
     governing_question: how does X?\n\
     description: has extras\n\
     ---\n"
  in
  let fm = Cn_frontmatter.parse_frontmatter content in
  Printf.printf "name=%s description=%s\n"
    (Option.value fm.fm_name ~default:"(none)")
    (Option.value fm.fm_description ~default:"(none)");
  [%expect {| name=cdd description=has extras |}]

(* === M1–M3: manifest_skill_ids === *)

let%expect_test "M1 manifest_skill_ids happy path" =
  let src = {|{
    "name": "cnos.core",
    "sources": { "skills": ["cdd", "cdd/design", "cdd/review"] }
  }|} in
  let json = match Cn_json.parse src with
    | Ok j -> j | Error _ -> failwith "json" in
  let ids = Cn_frontmatter.manifest_skill_ids ~pkg_name:"cnos.core" json in
  Printf.printf "count=%d ids=%s\n"
    (List.length ids) (String.concat "," ids);
  [%expect {| count=3 ids=cdd,cdd/design,cdd/review |}]

let%expect_test "M2 manifest_skill_ids missing sources field" =
  let src = {|{ "name": "cnos.core" }|} in
  let json = match Cn_json.parse src with
    | Ok j -> j | Error _ -> failwith "json" in
  let ids = Cn_frontmatter.manifest_skill_ids ~pkg_name:"cnos.core" json in
  Printf.printf "count=%d\n" (List.length ids);
  [%expect {| count=0 |}]

let%expect_test "M3 manifest_skill_ids missing skills subkey" =
  let src = {|{ "name": "cnos.core", "sources": {} }|} in
  let json = match Cn_json.parse src with
    | Ok j -> j | Error _ -> failwith "json" in
  let ids = Cn_frontmatter.manifest_skill_ids ~pkg_name:"cnos.core" json in
  Printf.printf "count=%d\n" (List.length ids);
  [%expect {| count=0 |}]

(* === IK1: issue_kind_label exhaustive === *)

let%expect_test "IK1 issue_kind_label exhaustive 3 variants" =
  List.iter (fun k ->
    Printf.printf "%s\n" (Cn_frontmatter.issue_kind_label k))
    [ Cn_frontmatter.Missing_skill
    ; Cn_frontmatter.Empty_triggers
    ; Cn_frontmatter.Trigger_conflict
    ];
  [%expect {|
    missing
    empty
    conflict |}]

(* === I1: issue record construction over each issue_kind variant === *)

let%expect_test "I1 issue record construction with each issue_kind variant" =
  let issues : Cn_frontmatter.issue list = [
    { kind = Missing_skill;
      message = "package cnos.core: declared skill foo missing SKILL.md" };
    { kind = Empty_triggers;
      message = "package cnos.core: skill bar has no triggers" };
    { kind = Trigger_conflict;
      message = "trigger review claimed by: cdd/review, eng/review" };
  ] in
  List.iter (fun (i : Cn_frontmatter.issue) ->
    Printf.printf "[%s] %s\n" (Cn_frontmatter.issue_kind_label i.kind) i.message)
    issues;
  [%expect {|
    [missing] package cnos.core: declared skill foo missing SKILL.md
    [empty] package cnos.core: skill bar has no triggers
    [conflict] trigger review claimed by: cdd/review, eng/review |}]
