(** cn_contract_test: ppx_expect tests for the pure runtime-contract
    model extracted from cn_runtime_contract.ml + activation_entry
    extracted from cn_activation.ml in v3.39.0 (#182 Move 2 slice 2).

    The module under test (`Cn_contract`) owns the canonical type
    definitions for:
    - 11 runtime-contract types (package_info, override_info, zone,
      zone_entry, identity, extension_contract_info, command_entry,
      orchestrator_entry, cognition, body_contract, runtime_contract)
    - activation_entry (pulled through the type-equality chain so
      cognition can reference it without depending on cn_activation.ml
      which is IO-touching)
    plus the pure `zone_to_string` helper. No IO.

    Tests:
    P1   package_info record construction + field read
    O1   override_info record construction + field read
    Z1   zone variant + zone_to_string exhaustive mapping (5 cases)
    ZE1  zone_entry record construction + field read
    I1   identity record construction + field read
    E1   extension_contract_info record construction + field read
    C1   command_entry record construction (repo-local: cmd_package=None)
    C2   command_entry record construction (package-owned: cmd_package=Some)
    OR1  orchestrator_entry record construction + field read
    A1   activation_entry record construction + field read
    CG1  cognition record construction + field read (tests that activation_index
         is a list of activation_entry, closing the Cn_activation dependency)
    B1   body_contract record construction + field read
    RC1  runtime_contract record construction + four-layer composition
*)

(* === P1: package_info === *)

let%expect_test "P1 package_info record construction + field read" =
  let p : Cn_contract.package_info = {
    name = "cnos.core";
    version = "3.39.0";
    sha256 = Some "abc123";
    doctrine_count = 7;
    mindset_count = 3;
    skill_count = 24;
  } in
  Printf.printf "name=%s version=%s sha256=%s doctrine=%d mindsets=%d skills=%d\n"
    p.name p.version
    (match p.sha256 with Some h -> h | None -> "none")
    p.doctrine_count p.mindset_count p.skill_count;
  [%expect {| name=cnos.core version=3.39.0 sha256=abc123 doctrine=7 mindsets=3 skills=24 |}]

let%expect_test "P1b package_info with sha256=None" =
  let p : Cn_contract.package_info = {
    name = "cnos.eng";
    version = "3.39.0";
    sha256 = None;
    doctrine_count = 0;
    mindset_count = 0;
    skill_count = 5;
  } in
  Printf.printf "sha256_is_none=%b\n" (p.sha256 = None);
  [%expect {| sha256_is_none=true |}]

(* === O1: override_info === *)

let%expect_test "O1 override_info record construction + field read" =
  let o : Cn_contract.override_info = {
    doctrine = ["agent/doctrine/cnos.core/extra.md"];
    mindsets = ["agent/mindsets/cnos.core/override.md"];
    skills = ["agent/skills/cnos.core/cdd/local/SKILL.md"];
  } in
  Printf.printf "doctrine_count=%d mindsets_count=%d skills_count=%d\n"
    (List.length o.doctrine) (List.length o.mindsets) (List.length o.skills);
  Printf.printf "first_doctrine=%s\n" (List.hd o.doctrine);
  [%expect {|
    doctrine_count=1 mindsets_count=1 skills_count=1
    first_doctrine=agent/doctrine/cnos.core/extra.md |}]

(* === Z1: zone variant + zone_to_string exhaustive mapping === *)

let%expect_test "Z1 zone_to_string exhaustive 5 cases" =
  List.iter (fun z ->
    Printf.printf "%s\n" (Cn_contract.zone_to_string z))
    [ Cn_contract.Constitutive_self
    ; Cn_contract.Memory
    ; Cn_contract.Private_body
    ; Cn_contract.Work_medium
    ; Cn_contract.Projection_surface
    ];
  [%expect {|
    constitutive_self
    memory
    private_body
    work_medium
    projection_surface |}]

(* === ZE1: zone_entry === *)

let%expect_test "ZE1 zone_entry record construction + field read" =
  let e : Cn_contract.zone_entry = {
    path = "spec/SOUL.md";
    zone = Cn_contract.Constitutive_self;
  } in
  Printf.printf "path=%s zone=%s\n" e.path (Cn_contract.zone_to_string e.zone);
  [%expect {| path=spec/SOUL.md zone=constitutive_self |}]

(* === I1: identity === *)

let%expect_test "I1 identity record construction + field read" =
  let i : Cn_contract.identity = {
    cn_version = "3.39.0";
    hub_name = "test-hub";
    profile = "engineer";
  } in
  Printf.printf "cn_version=%s hub_name=%s profile=%s\n"
    i.cn_version i.hub_name i.profile;
  [%expect {| cn_version=3.39.0 hub_name=test-hub profile=engineer |}]

(* === E1: extension_contract_info === *)

let%expect_test "E1 extension_contract_info record construction" =
  let e : Cn_contract.extension_contract_info = {
    ext_name = "cnos.net.http";
    ext_version = "1.0.0";
    ext_package = "cnos.net.http";
    ext_backend = "subprocess";
    ext_state = "enabled";
    ext_ops = ["http_get"; "http_post"];
  } in
  Printf.printf "name=%s version=%s package=%s backend=%s state=%s ops=%s\n"
    e.ext_name e.ext_version e.ext_package e.ext_backend e.ext_state
    (String.concat "," e.ext_ops);
  [%expect {|
    name=cnos.net.http version=1.0.0 package=cnos.net.http backend=subprocess state=enabled ops=http_get,http_post |}]

(* === C1 / C2: command_entry (both repo-local and package-owned) === *)

let%expect_test "C1 command_entry repo-local (cmd_package=None)" =
  let c : Cn_contract.command_entry = {
    cmd_name = "daily";
    cmd_source = "repo-local";
    cmd_package = None;
    cmd_summary = "Create or show the daily reflection thread";
  } in
  Printf.printf "name=%s source=%s package=%s summary=%s\n"
    c.cmd_name c.cmd_source
    (match c.cmd_package with Some p -> p | None -> "(none)")
    c.cmd_summary;
  [%expect {|
    name=daily source=repo-local package=(none) summary=Create or show the daily reflection thread |}]

let%expect_test "C2 command_entry package-owned (cmd_package=Some)" =
  let c : Cn_contract.command_entry = {
    cmd_name = "save";
    cmd_source = "package";
    cmd_package = Some "cnos.core";
    cmd_summary = "Commit and push working-tree changes";
  } in
  Printf.printf "name=%s source=%s package=%s summary=%s\n"
    c.cmd_name c.cmd_source
    (match c.cmd_package with Some p -> p | None -> "(none)")
    c.cmd_summary;
  [%expect {|
    name=save source=package package=cnos.core summary=Commit and push working-tree changes |}]

(* === OR1: orchestrator_entry === *)

let%expect_test "OR1 orchestrator_entry record construction" =
  let o : Cn_contract.orchestrator_entry = {
    orch_name = "daily-review";
    orch_source = "package";
    orch_package = "cnos.core";
    orch_trigger_kinds = ["command"];
  } in
  Printf.printf "name=%s source=%s package=%s trigger_kinds=%s\n"
    o.orch_name o.orch_source o.orch_package
    (String.concat "," o.orch_trigger_kinds);
  [%expect {|
    name=daily-review source=package package=cnos.core trigger_kinds=command |}]

(* === A1: activation_entry === *)

let%expect_test "A1 activation_entry record construction + field read" =
  let a : Cn_contract.activation_entry = {
    skill_id = "cdd/review";
    package = "cnos.eng";
    summary = "Review a change against its declared contract";
    triggers = ["review"; "pr"; "diff"];
  } in
  Printf.printf "skill_id=%s package=%s summary=%s triggers=%s\n"
    a.skill_id a.package a.summary (String.concat "," a.triggers);
  [%expect {|
    skill_id=cdd/review package=cnos.eng summary=Review a change against its declared contract triggers=review,pr,diff |}]

(* === CG1: cognition references activation_entry === *)

let%expect_test "CG1 cognition constructs and reads activation_index" =
  let cg : Cn_contract.cognition = {
    packages = [
      { name = "cnos.core"; version = "3.39.0"; sha256 = Some "h1";
        doctrine_count = 7; mindset_count = 3; skill_count = 24 };
    ];
    overrides = {
      doctrine = []; mindsets = []; skills = [];
    };
    extensions_installed = [];
    activation_index = [
      { skill_id = "cdd/review"; package = "cnos.eng";
        summary = "Review"; triggers = ["review"] };
      { skill_id = "cdd/design"; package = "cnos.eng";
        summary = "Design"; triggers = ["design"] };
    ];
  } in
  Printf.printf "package_count=%d activation_count=%d\n"
    (List.length cg.packages) (List.length cg.activation_index);
  List.iter (fun (a : Cn_contract.activation_entry) ->
    Printf.printf "  - %s [%s]\n" a.skill_id a.package)
    cg.activation_index;
  [%expect {|
    package_count=1 activation_count=2
      - cdd/review [cnos.eng]
      - cdd/design [cnos.eng] |}]

(* === B1: body_contract === *)

let%expect_test "B1 body_contract record construction + field read" =
  let b : Cn_contract.body_contract = {
    capabilities_text = "## CN Shell Capabilities\n...";
    peers = ["sigma"; "omega"];
    extensions_active = [];
    commands = [
      { cmd_name = "daily"; cmd_source = "package";
        cmd_package = Some "cnos.core";
        cmd_summary = "Daily reflection" };
    ];
    orchestrators = [
      { orch_name = "daily-review"; orch_source = "package";
        orch_package = "cnos.core";
        orch_trigger_kinds = ["command"] };
    ];
  } in
  Printf.printf "peer_count=%d cmd_count=%d orch_count=%d\n"
    (List.length b.peers) (List.length b.commands) (List.length b.orchestrators);
  Printf.printf "first_peer=%s\n" (List.hd b.peers);
  [%expect {|
    peer_count=2 cmd_count=1 orch_count=1
    first_peer=sigma |}]

(* === RC1: runtime_contract four-layer composition === *)

let%expect_test "RC1 runtime_contract composes identity/cognition/body/medium" =
  let rc : Cn_contract.runtime_contract = {
    identity = {
      cn_version = "3.39.0";
      hub_name = "test-hub";
      profile = "engineer";
    };
    cognition = {
      packages = [];
      overrides = { doctrine = []; mindsets = []; skills = [] };
      extensions_installed = [];
      activation_index = [];
    };
    body = {
      capabilities_text = "";
      peers = [];
      extensions_active = [];
      commands = [];
      orchestrators = [];
    };
    medium = [
      { path = "spec/SOUL.md"; zone = Constitutive_self };
      { path = "threads/reflections/"; zone = Memory };
      { path = "src/"; zone = Work_medium };
    ];
  } in
  Printf.printf "identity_version=%s hub=%s profile=%s\n"
    rc.identity.cn_version rc.identity.hub_name rc.identity.profile;
  Printf.printf "medium_entries=%d\n" (List.length rc.medium);
  List.iter (fun (e : Cn_contract.zone_entry) ->
    Printf.printf "  - %s [%s]\n" e.path (Cn_contract.zone_to_string e.zone))
    rc.medium;
  [%expect {|
    identity_version=3.39.0 hub=test-hub profile=engineer
    medium_entries=3
      - spec/SOUL.md [constitutive_self]
      - threads/reflections/ [memory]
      - src/ [work_medium] |}]
