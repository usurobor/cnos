(** cn_runtime_contract_test: ppx_expect tests for Runtime Contract v2

    Tests the vertical self-model contract per RUNTIME-CONTRACT-v2.md:
    - gather produces correct four-layer contract from hub state
    - render_markdown produces deterministic output with all four layers
    - to_json produces valid v2 structured JSON
    - Zone classification covers expected paths
    - No absolute paths in rendered output *)

(* === Temp hub setup === *)

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

let with_test_hub f =
  let hub = mk_temp_dir "cn-contract-test" in
  let v = Cn_lib.version in
  let dirs = ["src"; "docs"; "spec"; "state"; "logs"; "agent";
              "threads/reflections/daily"; "threads/reflections/weekly";
              "threads/outbox";
              Printf.sprintf ".cn/vendor/packages/cnos.core@%s/doctrine" v;
              Printf.sprintf ".cn/vendor/packages/cnos.core@%s/mindsets" v;
              Printf.sprintf ".cn/vendor/packages/cnos.eng@%s/skills/eng/review" v] in
  List.iter (fun d ->
    Cn_ffi.Fs.ensure_dir (Filename.concat hub d)
  ) dirs;
  let touch path content =
    let full = Filename.concat hub path in
    Cn_ffi.Fs.ensure_dir (Filename.dirname full);
    let oc = open_out full in
    output_string oc content;
    close_out oc
  in
  touch "spec/SOUL.md" "# Identity";
  touch "spec/USER.md" "# User";
  let core = Printf.sprintf ".cn/vendor/packages/cnos.core@%s" v in
  let eng = Printf.sprintf ".cn/vendor/packages/cnos.eng@%s" v in
  (* Core doctrine files *)
  touch (core ^ "/doctrine/FOUNDATIONS.md") "# FOUNDATIONS";
  touch (core ^ "/doctrine/COHERENCE.md") "# COHERENCE";
  touch (core ^ "/doctrine/CAP.md") "# CAP";
  touch (core ^ "/doctrine/CA-CONDUCT.md") "# CA-CONDUCT";
  touch (core ^ "/doctrine/CBP.md") "# CBP";
  touch (core ^ "/doctrine/AGENT-OPS.md") "# AGENT-OPS";
  (* Core mindsets *)
  touch (core ^ "/mindsets/ENGINEERING.md") "# ENGINEERING";
  touch (core ^ "/mindsets/WRITING.md") "# WRITING";
  (* Eng package skill *)
  touch (eng ^ "/skills/eng/review/SKILL.md") "# Review Skill";
  Fun.protect ~finally:(fun () ->
    let rec rm path =
      if Sys.is_directory path then begin
        Sys.readdir path |> Array.iter (fun entry ->
          rm (Filename.concat path entry)
        );
        Unix.rmdir path
      end else
        Sys.remove path
    in
    (try rm hub with _ -> ())
  ) (fun () -> f hub)

let default_shell_config = {
  Cn_shell.n_pass = "auto";
  apply_mode = "branch";
  exec_enabled = false;
  exec_allowlist = [];
  max_observe_ops = 10;
  max_artifact_bytes = 65536;
  max_artifact_bytes_per_op = 16384;
  max_passes = 5;
  max_total_artifact_bytes = 131072;
  max_total_ops = 32;
}

(* ============================================================ *)
(* === GATHER                                                === *)
(* ============================================================ *)

let%expect_test "gather: produces contract with four layers" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:["sigma"] () in
    Printf.printf "cn_version_matches: %b\n" (c.identity.cn_version = Cn_lib.version);
    Printf.printf "hub_name_present: %b\n" (c.identity.hub_name <> "");
    Printf.printf "profile: %s\n" c.identity.profile;
    Printf.printf "packages: %d\n" (List.length c.cognition.packages);
    Printf.printf "peers: %d\n" (List.length c.body.peers);
    Printf.printf "zones: %d\n" (List.length c.medium));
  [%expect {|
    cn_version_matches: true
    hub_name_present: true
    profile: engineer
    packages: 2
    peers: 1
    zones: 11 |}]

let%expect_test "gather: package info has correct counts" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    List.iter (fun (p : Cn_runtime_contract.package_info) ->
      Printf.printf "%s: %d doctrine, %d mindsets, %d skills\n"
        p.name p.doctrine_count p.mindset_count p.skill_count
    ) c.cognition.packages);
  [%expect {|
    cnos.core: 6 doctrine, 2 mindsets, 0 skills
    cnos.eng: 0 doctrine, 0 mindsets, 1 skills |}]

let%expect_test "gather: zone classification covers all five types" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let has_zone z = List.exists (fun (e : Cn_runtime_contract.zone_entry) ->
      e.zone = z) c.medium in
    Printf.printf "constitutive_self: %b\n" (has_zone Constitutive_self);
    Printf.printf "memory: %b\n" (has_zone Memory);
    Printf.printf "private_body: %b\n" (has_zone Private_body);
    Printf.printf "work_medium: %b\n" (has_zone Work_medium);
    Printf.printf "projection_surface: %b\n" (has_zone Projection_surface));
  [%expect {|
    constitutive_self: true
    memory: true
    private_body: true
    work_medium: true
    projection_surface: true |}]

(* ============================================================ *)
(* === RENDER MARKDOWN                                       === *)
(* ============================================================ *)

let%expect_test "render_markdown: contains all four layers" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:["sigma"] () in
    let md = Cn_runtime_contract.render_markdown c in
    let has sec = if Cn_orchestrator.contains_sub md sec then "yes" else "no" in
    Printf.printf "Runtime Contract: %s\n" (has "## Runtime Contract");
    Printf.printf "Identity: %s\n" (has "### Identity");
    Printf.printf "Cognition: %s\n" (has "### Cognition");
    Printf.printf "Body: %s\n" (has "### Body");
    Printf.printf "Medium: %s\n" (has "### Medium");
    Printf.printf "Capabilities: %s\n" (has "## CN Shell Capabilities"));
  [%expect {|
    Runtime Contract: yes
    Identity: yes
    Cognition: yes
    Body: yes
    Medium: yes
    Capabilities: yes |}]

let%expect_test "render_markdown: medium shows zone classifications" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let md = Cn_runtime_contract.render_markdown c in
    let has sec = if Cn_orchestrator.contains_sub md sec then "yes" else "no" in
    Printf.printf "constitutive_self: %s\n" (has "constitutive_self:");
    Printf.printf "memory: %s\n" (has "memory:");
    Printf.printf "private_body: %s\n" (has "private_body:");
    Printf.printf "work_medium: %s\n" (has "work_medium:");
    Printf.printf "projection_surface: %s\n" (has "projection_surface:"));
  [%expect {|
    constitutive_self: yes
    memory: yes
    private_body: yes
    work_medium: yes
    projection_surface: yes |}]

let%expect_test "render_markdown: no absolute paths" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let md = Cn_runtime_contract.render_markdown c in
    let has_abs = Cn_orchestrator.contains_sub md hub in
    Printf.printf "contains_absolute_path: %b\n" has_abs);
  [%expect {| contains_absolute_path: false |}]

let%expect_test "render_markdown: contains authority preamble (issue #63)" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let md = Cn_runtime_contract.render_markdown c in
    let has s = if Cn_orchestrator.contains_sub md s then "yes" else "no" in
    Printf.printf "Authority: %s\n" (has "**Authority:**");
    Printf.printf "authoritative: %s\n" (has "authoritative source");
    Printf.printf "supersedes: %s\n" (has "this contract supersedes"));
  [%expect {|
    Authority: yes
    authoritative: yes
    supersedes: yes |}]

let%expect_test "render_markdown: deterministic (two calls identical)" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let md1 = Cn_runtime_contract.render_markdown c in
    let md2 = Cn_runtime_contract.render_markdown c in
    Printf.printf "deterministic: %b\n" (md1 = md2));
  [%expect {| deterministic: true |}]

(* ============================================================ *)
(* === TO_JSON                                               === *)
(* ============================================================ *)

let%expect_test "to_json: v2 schema with four layers" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:["sigma"] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    let has key = Cn_json.get key json <> None in
    Printf.printf "schema: %b\n" (has "schema");
    Printf.printf "identity: %b\n" (has "identity");
    Printf.printf "cognition: %b\n" (has "cognition");
    Printf.printf "body: %b\n" (has "body");
    Printf.printf "medium: %b\n" (has "medium");
    (* Verify schema version *)
    match Cn_json.get_string "schema" json with
    | Some s -> Printf.printf "schema_version: %s\n" s
    | None -> ());
  [%expect {|
    schema: true
    identity: true
    cognition: true
    body: true
    medium: true
    schema_version: cn.runtime_contract.v2 |}]

let%expect_test "to_json: identity has version" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "identity" json with
    | None -> print_endline "missing identity"
    | Some id ->
      let ver = Cn_json.get_string "cn_version" id in
      let hub = Cn_json.get_string "hub_name" id in
      Printf.printf "cn_version_matches: %b\n" (ver = Some Cn_lib.version);
      Printf.printf "hub_name_present: %b\n" (hub <> None));
  [%expect {|
    cn_version_matches: true
    hub_name_present: true |}]

let%expect_test "to_json: body.capabilities match Cn_capabilities (single source of truth)" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "body" json with
    | None -> print_endline "missing body"
    | Some body ->
      match Cn_json.get "capabilities" body with
      | None -> print_endline "missing capabilities"
      | Some caps ->
        let observe = match Cn_json.get "observe" caps with
          | Some (Cn_json.Array items) ->
            List.map (function Cn_json.String s -> s | _ -> "?") items
          | _ -> []
        in
        let observe_match = observe = Cn_capabilities.observe_kinds in
        Printf.printf "observe_matches_canonical: %b\n" observe_match;
        let effect = match Cn_json.get "effect" caps with
          | Some (Cn_json.Array items) ->
            List.map (function Cn_json.String s -> s | _ -> "?") items
          | _ -> []
        in
        let effect_match = effect = Cn_capabilities.effect_kinds_base in
        Printf.printf "effect_matches_canonical: %b\n" effect_match;
        Printf.printf "apply_mode: %b\n" (Cn_json.get "apply_mode" caps <> None);
        Printf.printf "exec_enabled: %b\n" (Cn_json.get "exec_enabled" caps <> None);
        Printf.printf "budgets: %b\n" (Cn_json.get "budgets" caps <> None));
  [%expect {|
    observe_matches_canonical: true
    effect_matches_canonical: true
    apply_mode: true
    exec_enabled: true
    budgets: true |}]

let%expect_test "to_json: medium contains zone entries" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "medium" json with
    | None -> print_endline "missing medium"
    | Some med ->
      match Cn_json.get "zones" med with
      | Some (Cn_json.Array zones) ->
        Printf.printf "zone_count: %d\n" (List.length zones);
        let has_zone_type z = List.exists (fun entry ->
          Cn_json.get_string "zone" entry = Some z) zones in
        Printf.printf "constitutive_self: %b\n" (has_zone_type "constitutive_self");
        Printf.printf "memory: %b\n" (has_zone_type "memory");
        Printf.printf "private_body: %b\n" (has_zone_type "private_body");
        Printf.printf "work_medium: %b\n" (has_zone_type "work_medium");
        Printf.printf "projection_surface: %b\n" (has_zone_type "projection_surface")
      | _ -> print_endline "zones not array");
  [%expect {|
    zone_count: 11
    constitutive_self: true
    memory: true
    private_body: true
    work_medium: true
    projection_surface: true |}]

(* ============================================================ *)
(* === PACKAGE PROVENANCE (AC7, Issue #113)                  === *)
(* ============================================================ *)

let%expect_test "gather: package info includes sha256 from lockfile" =
  with_test_hub (fun hub ->
    (* Create a lockfile so gather can read package sha256 *)
    let v = Cn_lib.version in
    let lock : Cn_deps.lockfile = {
      schema = "cn.lock.v2";
      packages = [
        { name = "cnos.core"; version = v; sha256 = "deadbeef" };
        { name = "cnos.eng";  version = v; sha256 = "cafef00d" };
      ];
    } in
    Cn_deps.write_lockfile ~hub_path:hub lock;
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    List.iter (fun (p : Cn_runtime_contract.package_info) ->
      Printf.printf "%s: sha256=%s\n"
        p.name (match p.sha256 with Some h -> h | None -> "none")
    ) c.cognition.packages);
  [%expect {|
    cnos.core: sha256=deadbeef
    cnos.eng: sha256=cafef00d |}]

let%expect_test "to_json: package entries include sha256" =
  with_test_hub (fun hub ->
    let v = Cn_lib.version in
    let lock : Cn_deps.lockfile = {
      schema = "cn.lock.v2";
      packages = [
        { name = "cnos.core"; version = v; sha256 = "test123" };
      ];
    } in
    Cn_deps.write_lockfile ~hub_path:hub lock;
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "cognition" json with
    | None -> print_endline "missing cognition"
    | Some cog ->
      match Cn_json.get "installed_packages" cog with
      | Some (Cn_json.Array pkgs) ->
        List.iter (fun pkg ->
          let name = Cn_json.get_string "name" pkg in
          let has_sha = Cn_json.get_string "sha256" pkg <> None in
          Printf.printf "%s: sha256=%b\n"
            (Option.value ~default:"?" name) has_sha
        ) pkgs
      | _ -> print_endline "packages not array");
  [%expect {|
    cnos.core: sha256=true
    cnos.eng: sha256=false |}]

let%expect_test "to_json: exec_enabled reflects shell_config" =
  with_test_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let exec_config = { default_shell_config with
      exec_enabled = true;
      exec_allowlist = ["make"; "dune"] } in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:exec_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:exec_config c in
    match Cn_json.get "body" json with
    | None -> print_endline "missing body"
    | Some body ->
      match Cn_json.get "capabilities" body with
      | None -> print_endline "missing capabilities"
      | Some caps ->
        let effect = match Cn_json.get "effect" caps with
          | Some (Cn_json.Array items) ->
            List.map (function Cn_json.String s -> s | _ -> "?") items
          | _ -> []
        in
        let has_exec = List.mem "exec" effect in
        Printf.printf "has_exec: %b\n" has_exec;
        Printf.printf "has_exec_allowlist: %b\n" (Cn_json.get "exec_allowlist" caps <> None));
  [%expect {|
    has_exec: true
    has_exec_allowlist: true |}]

(* ============================================================ *)
(* === ACTIVATION INDEX + REGISTRIES (#173)                  === *)
(* ============================================================ *)

(** Augment the with_test_hub fixture: declare commands + skills with
    triggers + one orchestrator in the cnos.core manifest, and create
    the backing SKILL.md / command script / orchestrator.json so the
    activation index, command registry, and orchestrator registry are
    each non-empty. *)
let with_activation_hub f =
  with_test_hub (fun hub ->
    let v = Cn_lib.version in
    let core = Printf.sprintf ".cn/vendor/packages/cnos.core@%s" v in
    let core_dir = Filename.concat hub core in
    (* New-schema manifest: orchestrators is a string array of ids;
       the per-id metadata lives in orchestrators/<id>/orchestrator.json. *)
    let manifest = Printf.sprintf
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.core\",\"version\":\"%s\",\
       \"sources\":{\
       \"skills\":[\"reflect\"],\
       \"commands\":{\"daily\":{\"entrypoint\":\"commands/cn-daily\",\"summary\":\"daily\"}},\
       \"orchestrators\":[\"daily-review\"]}}"
      v in
    let oc = open_out (Filename.concat core_dir "cn.package.json") in
    output_string oc manifest;
    close_out oc;
    Cn_ffi.Fs.ensure_dir (Filename.concat core_dir "skills/reflect");
    let oc = open_out (Filename.concat core_dir "skills/reflect/SKILL.md") in
    output_string oc
      "---\nname: reflect\ndescription: reflective practice\ntriggers:\n  - reflect\n  - introspect\n---\n# Body\n";
    close_out oc;
    Cn_ffi.Fs.ensure_dir (Filename.concat core_dir "commands");
    let oc = open_out (Filename.concat core_dir "commands/cn-daily") in
    output_string oc "#!/bin/sh\necho daily\n";
    close_out oc;
    Unix.chmod (Filename.concat core_dir "commands/cn-daily") 0o755;
    Cn_ffi.Fs.ensure_dir
      (Filename.concat core_dir "orchestrators/daily-review");
    let oc = open_out
      (Filename.concat core_dir "orchestrators/daily-review/orchestrator.json") in
    output_string oc
      "{\"kind\":\"cn.orchestrator.v1\",\"name\":\"daily-review\",\
       \"trigger\":{\"kind\":\"command\",\"name\":\"daily\"},\
       \"permissions\":{\"llm\":false,\"ops\":[],\"external_effects\":false},\
       \"steps\":[{\"id\":\"done\",\"kind\":\"return\",\"value\":{\"ok\":true}}]}";
    close_out oc;
    f hub)

let%expect_test "to_json: cognition.activation_index includes exposed skills (#173)" =
  with_activation_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "cognition" json with
    | None -> print_endline "no cognition"
    | Some cog ->
      match Cn_json.get "activation_index" cog with
      | None -> print_endline "no activation_index"
      | Some idx ->
        match Cn_json.get "skills" idx with
        | Some (Cn_json.Array items) ->
          Printf.printf "count=%d\n" (List.length items);
          items |> List.iter (fun pkg ->
            let id = Cn_json.get_string "id" pkg in
            let p  = Cn_json.get_string "package" pkg in
            let trig_count = match Cn_json.get "triggers" pkg with
              | Some (Cn_json.Array xs) -> List.length xs
              | _ -> 0
            in
            Printf.printf "id=%s pkg=%s triggers=%d\n"
              (Option.value ~default:"?" id)
              (Option.value ~default:"?" p)
              trig_count)
        | _ -> print_endline "skills not array");
  [%expect {|
    count=1
    id=reflect pkg=cnos.core triggers=2 |}]

let%expect_test "to_json: body.commands and body.orchestrators present (#173)" =
  with_activation_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "body" json with
    | None -> print_endline "no body"
    | Some body ->
      let cmds = match Cn_json.get "commands" body with
        | Some (Cn_json.Array xs) -> List.length xs | _ -> -1 in
      let orchs = match Cn_json.get "orchestrators" body with
        | Some (Cn_json.Array xs) -> List.length xs | _ -> -1 in
      Printf.printf "commands=%d orchestrators=%d\n" cmds orchs);
  [%expect {| commands=1 orchestrators=1 |}]

let%expect_test "render_markdown: activation_index nests under skills header (#173, F3 parity)" =
  with_activation_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let md = Cn_runtime_contract.render_markdown c in
    let mentions s sub =
      let sl = String.length s and bl = String.length sub in
      let rec check i =
        if i > sl - bl then false
        else if String.sub s i bl = sub then true
        else check (i + 1)
      in bl <= sl && check 0
    in
    (* Parity with JSON: activation_index > skills. F3. *)
    Printf.printf "has_activation_header=%b\n"
      (mentions md "activation_index:");
    Printf.printf "has_skills_subkey=%b\n"
      (mentions md "  skills:");
    Printf.printf "has_reflect=%b\n" (mentions md "reflect");
    Printf.printf "has_trigger=%b\n" (mentions md "introspect"));
  [%expect {|
    has_activation_header=true
    has_skills_subkey=true
    has_reflect=true
    has_trigger=true |}]

let%expect_test "to_json: orchestrators populated from Cn_workflow.discover (#174)" =
  (* with_activation_hub installs a one-step daily-review orchestrator
     that parses and validates cleanly. Registry should carry one entry
     with trigger_kinds derived from the orchestrator's trigger.kind. *)
  with_activation_hub (fun hub ->
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "body" json with
    | None -> print_endline "no body"
    | Some body ->
      match Cn_json.get "orchestrators" body with
      | Some (Cn_json.Array items) ->
        Printf.printf "count=%d\n" (List.length items);
        items |> List.iter (fun entry ->
          let name = Cn_json.get_string "name" entry
            |> Option.value ~default:"?" in
          let pkg  = Cn_json.get_string "package" entry
            |> Option.value ~default:"?" in
          let tks = match Cn_json.get "trigger_kinds" entry with
            | Some (Cn_json.Array xs) ->
              xs |> List.filter_map (function
                | Cn_json.String s -> Some s | _ -> None)
            | _ -> []
          in
          Printf.printf "name=%s pkg=%s trigger_kinds=[%s]\n"
            name pkg (String.concat "," tks))
      | _ -> print_endline "orchestrators not array");
  [%expect {|
    count=1
    name=daily-review pkg=cnos.core trigger_kinds=[command] |}]

let%expect_test "to_json: orchestrators empty when sources.orchestrators absent (#174)" =
  with_test_hub (fun hub ->
    let v = Cn_lib.version in
    let core_dir = Filename.concat hub
      (Printf.sprintf ".cn/vendor/packages/cnos.core@%s" v) in
    let manifest = Printf.sprintf
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.core\",\"version\":\"%s\",\
       \"sources\":{}}" v in
    let oc = open_out (Filename.concat core_dir "cn.package.json") in
    output_string oc manifest;
    close_out oc;
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "body" json with
    | Some body ->
      (match Cn_json.get "orchestrators" body with
       | Some (Cn_json.Array xs) ->
         Printf.printf "count=%d\n" (List.length xs)
       | _ -> print_endline "orchestrators not array")
    | None -> print_endline "no body");
  [%expect {| count=0 |}]

let%expect_test "to_json: orchestrator load failures omitted from registry (#174)" =
  (* A declared orchestrator with a missing orchestrator.json must
     not crash the registry build; it is simply omitted (doctor
     surfaces the gap separately). *)
  with_test_hub (fun hub ->
    let v = Cn_lib.version in
    let core_dir = Filename.concat hub
      (Printf.sprintf ".cn/vendor/packages/cnos.core@%s" v) in
    let manifest = Printf.sprintf
      "{\"schema\":\"cn.package.v1\",\"name\":\"cnos.core\",\"version\":\"%s\",\
       \"sources\":{\"orchestrators\":[\"ghost\"]}}" v in
    let oc = open_out (Filename.concat core_dir "cn.package.json") in
    output_string oc manifest;
    close_out oc;
    (* No orchestrators/ghost/orchestrator.json on disk. *)
    let assets = Cn_assets.summarize ~hub_path:hub in
    let c = Cn_runtime_contract.gather ~hub_path:hub
              ~shell_config:default_shell_config ~assets ~peers:[] () in
    let json = Cn_runtime_contract.to_json ~shell_config:default_shell_config c in
    match Cn_json.get "body" json with
    | Some body ->
      (match Cn_json.get "orchestrators" body with
       | Some (Cn_json.Array xs) ->
         Printf.printf "count=%d\n" (List.length xs)
       | _ -> print_endline "orchestrators not array")
    | None -> print_endline "no body");
  [%expect {| count=0 |}]
