(** cn_runtime_contract.ml — Runtime Contract v2 (Issue #62)

    Emits a vertical self-model at every wake so the agent can
    determine its identity, cognition, body, and medium from
    packed context alone.

    Four layers (RUNTIME-CONTRACT-v2.md):
    - identity: who the agent is (version, hub, profile)
    - cognition: what shapes its thinking (packages, overrides)
    - body: what the runtime can do (capabilities, peers)
    - medium: what world it inhabits (zone-classified paths)

    Body scanning for self-knowledge becomes a contract bug, not normal. *)

(* === Types === *)

type package_info = {
  name : string;
  version : string;
  sha256 : string option;
  doctrine_count : int;
  mindset_count : int;
  skill_count : int;
}

type override_info = {
  doctrine : string list;
  mindsets : string list;
  skills : string list;
}

type zone =
  | Constitutive_self
  | Memory
  | Private_body
  | Work_medium
  | Projection_surface

type zone_entry = {
  path : string;
  zone : zone;
}

type identity = {
  cn_version : string;
  hub_name : string;
  profile : string;
}

type extension_contract_info = {
  ext_name : string;
  ext_version : string;
  ext_package : string;
  ext_backend : string;
  ext_state : string;
  ext_ops : string list;
}

type command_entry = {
  cmd_name : string;
  cmd_source : string;          (** "repo-local" | "package" *)
  cmd_package : string option;
  cmd_summary : string;
}

type orchestrator_entry = {
  orch_name : string;
  orch_source : string;         (** always "package" in v1 *)
  orch_package : string;
  orch_trigger_kinds : string list;
}

type cognition = {
  packages : package_info list;
  overrides : override_info;
  extensions_installed : extension_contract_info list;
  activation_index : Cn_activation.activation_entry list;
}

type body_contract = {
  capabilities_text : string;
  peers : string list;
  extensions_active : extension_contract_info list;
  commands : command_entry list;
  orchestrators : orchestrator_entry list;
}

type runtime_contract = {
  identity : identity;
  cognition : cognition;
  body : body_contract;
  medium : zone_entry list;
}

(* === Zone helpers === *)

let zone_to_string = function
  | Constitutive_self -> "constitutive_self"
  | Memory -> "memory"
  | Private_body -> "private_body"
  | Work_medium -> "work_medium"
  | Projection_surface -> "projection_surface"

(** Canonical zone classification.
    Each hub-relative path gets a semantic zone based on its relation
    to the agent's self. Paths that don't exist are excluded. *)
let classify_zones ~hub_path =
  let exists rel = Cn_ffi.Fs.exists (Cn_ffi.Path.join hub_path rel) in
  let entries = [
    (* Constitutive self — identity substrate *)
    "spec/SOUL.md", Constitutive_self;
    "spec/USER.md", Constitutive_self;
    ".cn/vendor/packages/", Constitutive_self;
    (* Memory — temporal record *)
    "threads/reflections/", Memory;
    "state/conversation.json", Memory;
    (* Private body — runtime internals *)
    ".cn/", Private_body;
    "state/", Private_body;
    "logs/", Private_body;
    (* Work medium — legitimate work surfaces *)
    "src/", Work_medium;
    "docs/", Work_medium;
    "agent/", Work_medium;
    (* Projection surface — communication channels *)
    "threads/outbox/", Projection_surface;
  ] in
  entries |> List.filter_map (fun (path, zone) ->
    if exists path then Some { path; zone } else None)

(* === Gather === *)

(** List .md files in a directory, returning hub-relative paths. *)
let list_md_relative ~hub_path dir =
  let full = Cn_ffi.Path.join hub_path dir in
  if not (Cn_ffi.Fs.exists full) then []
  else
    try
      Cn_ffi.Fs.readdir full
      |> List.filter (fun f -> Filename.check_suffix f ".md")
      |> List.sort String.compare
      |> List.map (fun f -> dir ^ "/" ^ f)
    with exn ->
      Printf.eprintf "cn: runtime_contract: cannot read %s: %s\n"
        full (Printexc.to_string exn);
      []

(** List SKILL.md overrides under a directory, returning hub-relative paths. *)
let list_skill_overrides ~hub_path dir =
  let full = Cn_ffi.Path.join hub_path dir in
  if not (Cn_ffi.Fs.exists full) then []
  else
    Cn_assets.walk_skills full
    |> List.map (fun (rel, _content) -> dir ^ "/" ^ rel ^ "/SKILL.md")

(** Build extension contract info from registry entries. *)
let extensions_from_registry registry =
  Cn_extension.all_entries registry
  |> List.map (fun (entry : Cn_extension.extension_entry) ->
    {
      ext_name = entry.manifest.name;
      ext_version = entry.manifest.version;
      ext_package = entry.package_name;
      ext_backend = entry.manifest.backend.backend_kind;
      ext_state = Cn_extension.string_of_lifecycle_state entry.state;
      ext_ops = List.map (fun op -> op.Cn_extension.op_kind) entry.manifest.ops;
    })

(** Project Cn_command discoveries to runtime-contract command entries. *)
let build_command_registry ~hub_path =
  Cn_command.discover ~hub_path
  |> List.map (fun (c : Cn_command.external_cmd) ->
    let cmd_source, cmd_package = match c.source with
      | Cn_command.Repo_local -> "repo-local", None
      | Cn_command.Package p  -> "package", Some p
    in
    {
      cmd_name = c.name;
      cmd_source;
      cmd_package;
      cmd_summary = c.summary;
    })

(** Read [sources.orchestrators] from each installed package's manifest.
    The schema for an entry is
      { "name": "...", "trigger_kinds": ["command", "schedule", ...] }
    Entries that don't parse are skipped silently; doctor surfaces them
    via cn_deps validation if the manifest is malformed. *)
let build_orchestrator_registry ~hub_path =
  Cn_assets.list_installed_packages hub_path
  |> List.concat_map (fun (pkg_name, pkg_dir) ->
    let manifest_path = Cn_ffi.Path.join pkg_dir "cn.package.json" in
    if not (Cn_ffi.Fs.exists manifest_path) then []
    else
      match Cn_json.parse (Cn_ffi.Fs.read manifest_path) with
      | Error _ -> []
      | Ok json ->
          match Cn_json.get "sources" json with
          | None -> []
          | Some sources ->
              match Cn_json.get "orchestrators" sources with
              | Some (Cn_json.Array items) ->
                  items |> List.filter_map (function
                    | Cn_json.Object _ as entry ->
                        (match Cn_json.get_string "name" entry with
                         | None -> None
                         | Some name ->
                             let trigger_kinds = match Cn_json.get "trigger_kinds" entry with
                               | Some (Cn_json.Array xs) ->
                                   xs |> List.filter_map (function
                                     | Cn_json.String s -> Some s
                                     | _ -> None)
                               | _ -> []
                             in
                             Some {
                               orch_name = name;
                               orch_source = "package";
                               orch_package = pkg_name;
                               orch_trigger_kinds = trigger_kinds;
                             })
                    | _ -> None)
              | _ -> [])

(** Build the runtime contract from current hub state. *)
let gather ~hub_path ~(shell_config : Cn_shell.shell_config)
      ~(assets : Cn_assets.asset_summary) ~peers
      ?(ext_registry = Cn_extension.empty_registry ()) () =
  let hub_name = Filename.basename hub_path in

  (* Read lockfile for package provenance (source, rev, integrity) *)
  let lockfile = Cn_deps.read_lockfile ~hub_path in

  (* Package info: walk installed packages for detail *)
  let packages =
    Cn_assets.list_installed_packages hub_path
    |> List.map (fun (pkg_name, pkg_path) ->
      (* Extract version from directory name (e.g. cnos.core@3.15.0) *)
      let dir_name = Filename.basename pkg_path in
      let pkg_version = match String.index_opt dir_name '@' with
        | Some i -> String.sub dir_name (i + 1) (String.length dir_name - i - 1)
        | None -> "unknown"
      in
      (* Look up lock entry for provenance *)
      let lock_entry = match lockfile with
        | None -> None
        | Some lf ->
          List.find_opt (fun (d : Cn_deps.locked_dep) ->
            d.name = pkg_name && d.version = pkg_version) lf.packages
      in
      let sha256 = match lock_entry with
        | Some d -> Some d.sha256 | None -> None in
      let count_md dir =
        if not (Cn_ffi.Fs.exists dir) then 0
        else
          try
            Cn_ffi.Fs.readdir dir
            |> List.filter (fun f -> Filename.check_suffix f ".md")
            |> List.length
          with exn ->
            Printf.eprintf "cn: runtime_contract: cannot read %s: %s\n"
              dir (Printexc.to_string exn);
            0
      in
      let doctrine_dir = Cn_ffi.Path.join pkg_path "doctrine" in
      let doctrine_count = count_md doctrine_dir in
      let mindsets_dir = Cn_ffi.Path.join pkg_path "mindsets" in
      let mindset_count = count_md mindsets_dir in
      let skills_dir = Cn_ffi.Path.join pkg_path "skills" in
      let skill_count = List.length (Cn_assets.walk_skills skills_dir) in
      { name = pkg_name; version = pkg_version;
        sha256;
        doctrine_count; mindset_count; skill_count })
  in

  (* Override info: scan agent/ directories *)
  let doctrine_overrides =
    Cn_assets.list_installed_packages hub_path
    |> List.concat_map (fun (pkg_name, _) ->
      list_md_relative ~hub_path
        (Printf.sprintf "agent/doctrine/%s" pkg_name))
  in
  let mindset_overrides =
    Cn_assets.list_installed_packages hub_path
    |> List.concat_map (fun (pkg_name, _) ->
      list_md_relative ~hub_path
        (Printf.sprintf "agent/mindsets/%s" pkg_name))
  in
  let skill_overrides =
    Cn_assets.list_installed_packages hub_path
    |> List.concat_map (fun (pkg_name, _) ->
      list_skill_overrides ~hub_path
        (Printf.sprintf "agent/skills/%s" pkg_name))
  in

  let profile = match assets.profile with
    | Some p -> p | None -> "engineer"
  in

  let capabilities_text =
    Cn_capabilities.render ~assets ~peers ~ext_registry shell_config
  in

  let all_ext_info = extensions_from_registry ext_registry in
  let active_ext_info = List.filter (fun e ->
    e.ext_state = "enabled") all_ext_info in

  let medium = classify_zones ~hub_path in
  let activation_index = Cn_activation.build_index ~hub_path in
  let commands = build_command_registry ~hub_path in
  let orchestrators = build_orchestrator_registry ~hub_path in

  {
    identity = {
      cn_version = Cn_lib.version;
      hub_name;
      profile;
    };
    cognition = {
      packages;
      overrides = {
        doctrine = doctrine_overrides;
        mindsets = mindset_overrides;
        skills = skill_overrides;
      };
      extensions_installed = all_ext_info;
      activation_index;
    };
    body = {
      capabilities_text;
      peers;
      extensions_active = active_ext_info;
      commands;
      orchestrators;
    };
    medium;
  }

(* === Render markdown for packed context === *)

(** Render the contract as a markdown section for the LLM system prompt.
    Four-layer vertical self-model. Deterministic field ordering
    for prompt-cache stability. *)
let render_markdown (c : runtime_contract) =
  let buf = Buffer.create 2048 in
  Buffer.add_string buf "## Runtime Contract\n\n";

  (* Authority declaration — issue #63: conversation history must not
     override the current contract. This preamble is the agent-facing
     instruction that closes the stale-history gap. *)
  Buffer.add_string buf "**Authority:** This contract is the authoritative source for identity, \
cognition, body, and medium. It is emitted fresh at every wake. \
If conversation history contains contradictory claims (e.g. a directory that \
was absent in a prior session), this contract supersedes them. \
Do not read cn.json or any manifest file to determine your own version — \
use the cn_version field below. \
The runtime structurally enforces this: reading cn.json or package manifests \
returns a contract_redirect, not file content.\n\n";

  (* Identity — who am I? *)
  Buffer.add_string buf "### Identity\n";
  Buffer.add_string buf (Printf.sprintf "cn_version: %s\n" c.identity.cn_version);
  Buffer.add_string buf (Printf.sprintf "hub_name: %s\n" c.identity.hub_name);
  Buffer.add_string buf (Printf.sprintf "profile: %s\n" c.identity.profile);

  (* Cognition — what shapes my thinking? *)
  Buffer.add_string buf "\n### Cognition\n";
  Buffer.add_string buf "installed_packages:";
  if c.cognition.packages = [] then Buffer.add_string buf " (none)\n"
  else begin
    Buffer.add_char buf '\n';
    List.iter (fun (p : package_info) ->
      let sha_str = match p.sha256 with
        | Some h -> Printf.sprintf ", sha256=%s" h
        | None -> ""
      in
      Buffer.add_string buf (Printf.sprintf
        "  - %s@%s (%d doctrine, %d mindsets, %d skills%s)\n"
        p.name p.version p.doctrine_count p.mindset_count p.skill_count
        sha_str)
    ) c.cognition.packages
  end;

  (* Extensions installed *)
  if c.cognition.extensions_installed <> [] then begin
    Buffer.add_string buf "extensions_installed:\n";
    List.iter (fun e ->
      Buffer.add_string buf (Printf.sprintf "  - %s@%s (%s, %s, ops: %s)\n"
        e.ext_name e.ext_version e.ext_backend e.ext_state
        (String.concat ", " e.ext_ops))
    ) c.cognition.extensions_installed
  end;

  (* Activation index — exposed skills with declarative triggers *)
  if c.cognition.activation_index <> [] then begin
    Buffer.add_string buf "Skills:\n";
    c.cognition.activation_index
    |> List.iter (fun (a : Cn_activation.activation_entry) ->
      let triggers_str = match a.triggers with
        | [] -> "(no triggers)"
        | xs -> String.concat ", " xs
      in
      Buffer.add_string buf (Printf.sprintf
        "  %s [%s] triggers: %s\n" a.skill_id a.package triggers_str))
  end;

  let ov = c.cognition.overrides in
  let total_overrides = List.length ov.doctrine
    + List.length ov.mindsets
    + List.length ov.skills in
  Buffer.add_string buf (Printf.sprintf "active_overrides: %d" total_overrides);
  if total_overrides > 0 then begin
    Buffer.add_char buf '\n';
    List.iter (fun p ->
      Buffer.add_string buf (Printf.sprintf "  - %s\n" p)
    ) (ov.doctrine @ ov.mindsets @ ov.skills)
  end else
    Buffer.add_string buf " (none)\n";

  (* Body — what can my body do? *)
  Buffer.add_string buf "\n### Body\n";
  Buffer.add_string buf c.body.capabilities_text;
  if c.body.peers <> [] then
    Buffer.add_string buf (Printf.sprintf "peers: %s\n"
      (String.concat ", " c.body.peers));
  if c.body.commands <> [] then begin
    Buffer.add_string buf "commands:\n";
    c.body.commands |> List.iter (fun (cmd : command_entry) ->
      let owner = match cmd.cmd_package with
        | Some p -> Printf.sprintf "[%s]" p
        | None -> "[repo-local]"
      in
      let summary = if cmd.cmd_summary = "" then ""
                    else " — " ^ cmd.cmd_summary in
      Buffer.add_string buf (Printf.sprintf
        "  %s %s%s\n" cmd.cmd_name owner summary))
  end;
  if c.body.orchestrators <> [] then begin
    Buffer.add_string buf "orchestrators:\n";
    c.body.orchestrators |> List.iter (fun (o : orchestrator_entry) ->
      Buffer.add_string buf (Printf.sprintf
        "  %s [%s] trigger_kinds: %s\n"
        o.orch_name o.orch_package
        (String.concat ", " o.orch_trigger_kinds)))
  end;

  (* Medium — what world do I inhabit? *)
  Buffer.add_string buf "\n### Medium\n";
  let by_zone zone =
    c.medium
    |> List.filter (fun e -> e.zone = zone)
    |> List.map (fun e -> e.path)
  in
  let render_zone zone_name zone =
    let paths = by_zone zone in
    if paths <> [] then
      Buffer.add_string buf (Printf.sprintf "%s: %s\n"
        zone_name (String.concat ", " paths))
  in
  render_zone "constitutive_self" Constitutive_self;
  render_zone "memory" Memory;
  render_zone "private_body" Private_body;
  render_zone "work_medium" Work_medium;
  render_zone "projection_surface" Projection_surface;

  Buffer.contents buf

(* === JSON persistence === *)

(** Convert the contract to JSON for state/runtime-contract.json.
    v2 schema: four layers (identity, cognition, body, medium).
    Capabilities read from Cn_capabilities (single source of truth, §4.5.2). *)
let to_json ~(shell_config : Cn_shell.shell_config) (c : runtime_contract) =
  let effects_enabled = shell_config.apply_mode <> "off" in
  let effective_exec = effects_enabled && shell_config.exec_enabled in
  let effect_kinds =
    if not effects_enabled then []
    else if effective_exec then Cn_capabilities.effect_kinds_base @ ["exec"]
    else Cn_capabilities.effect_kinds_base
  in
  let str s = Cn_json.String s in
  Cn_json.Object [
    "schema", str "cn.runtime_contract.v2";
    "identity", Cn_json.Object [
      "cn_version", str c.identity.cn_version;
      "hub_name", str c.identity.hub_name;
      "profile", str c.identity.profile;
    ];
    "cognition", Cn_json.Object [
      "installed_packages", Cn_json.Array (List.map (fun (p : package_info) ->
        let base = [
          "name", str p.name;
          "version", str p.version;
          "doctrine_count", Cn_json.Int p.doctrine_count;
          "mindset_count", Cn_json.Int p.mindset_count;
          "skill_count", Cn_json.Int p.skill_count;
        ] in
        let base = match p.sha256 with
          | Some h -> base @ ["sha256", str h]
          | None -> base
        in
        Cn_json.Object base) c.cognition.packages);
      "active_overrides", Cn_json.Object [
        "doctrine", Cn_json.Array (List.map str c.cognition.overrides.doctrine);
        "mindsets", Cn_json.Array (List.map str c.cognition.overrides.mindsets);
        "skills", Cn_json.Array (List.map str c.cognition.overrides.skills);
      ];
      "extensions_installed", Cn_json.Array (List.map (fun e ->
        Cn_json.Object [
          "name", str e.ext_name;
          "version", str e.ext_version;
          "package", str e.ext_package;
          "backend", str e.ext_backend;
          "state", str e.ext_state;
          "ops", Cn_json.Array (List.map str e.ext_ops);
        ]) c.cognition.extensions_installed);
      "activation_index", Cn_json.Object [
        "skills", Cn_json.Array (List.map
          (fun (a : Cn_activation.activation_entry) ->
            Cn_json.Object [
              "id", str a.skill_id;
              "package", str a.package;
              "summary", str a.summary;
              "triggers", Cn_json.Array (List.map str a.triggers);
            ]) c.cognition.activation_index);
      ];
    ];
    "body", Cn_json.Object ([
      "capabilities", Cn_json.Object ([
        "observe", Cn_json.Array (List.map str Cn_capabilities.observe_kinds);
        "effect", Cn_json.Array (List.map str effect_kinds);
        "apply_mode", str shell_config.apply_mode;
        "exec_enabled", Cn_json.Bool effective_exec;
        "max_passes", Cn_json.Int shell_config.max_passes;
        "budgets", Cn_json.Object [
          "max_artifact_bytes", Cn_json.Int shell_config.max_artifact_bytes;
          "max_artifact_bytes_per_op", Cn_json.Int shell_config.max_artifact_bytes_per_op;
          "max_observe_ops", Cn_json.Int shell_config.max_observe_ops;
          "max_total_artifact_bytes", Cn_json.Int shell_config.max_total_artifact_bytes;
          "max_total_ops", Cn_json.Int shell_config.max_total_ops;
        ];
      ] @ (if effective_exec && shell_config.exec_allowlist <> [] then
        ["exec_allowlist", Cn_json.Array (List.map str shell_config.exec_allowlist)]
      else []));
      "peers", Cn_json.Array (List.map str c.body.peers);
      "extensions_active", Cn_json.Array (List.map (fun e ->
        Cn_json.Object [
          "name", str e.ext_name;
          "ops", Cn_json.Array (List.map str e.ext_ops);
        ]) c.body.extensions_active);
      "commands", Cn_json.Array (List.map (fun (cmd : command_entry) ->
        let pkg_field = match cmd.cmd_package with
          | Some p -> [("package", str p)]
          | None -> []
        in
        Cn_json.Object ([
          "name", str cmd.cmd_name;
          "source", str cmd.cmd_source;
          "summary", str cmd.cmd_summary;
        ] @ pkg_field)) c.body.commands);
      "orchestrators", Cn_json.Array (List.map
        (fun (o : orchestrator_entry) ->
          Cn_json.Object [
            "name", str o.orch_name;
            "source", str o.orch_source;
            "package", str o.orch_package;
            "trigger_kinds", Cn_json.Array (List.map str o.orch_trigger_kinds);
          ]) c.body.orchestrators);
    ]);
    "medium", Cn_json.Object [
      "zones", Cn_json.Array (List.map (fun (e : zone_entry) ->
        Cn_json.Object [
          "path", str e.path;
          "zone", str (zone_to_string e.zone);
        ]) c.medium);
    ];
  ]

(** Write the contract to state/runtime-contract.json. *)
let write ~hub_path ~shell_config (c : runtime_contract) =
  let path = Cn_ffi.Path.join hub_path "state/runtime-contract.json" in
  Cn_ffi.Fs.ensure_dir (Filename.dirname path);
  Cn_ffi.Fs.write path (Cn_json.to_string (to_json ~shell_config c))
