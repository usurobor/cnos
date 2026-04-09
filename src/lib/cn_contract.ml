(** cn_contract.ml — Pure runtime-contract types + activation_entry.

    This module is the canonical authority for the shape of the
    runtime contract that the agent emits at every wake:

    - 11 runtime-contract types (identity, cognition, body, medium)
    - [activation_entry] pulled through the same module so
      [cognition.activation_index] can reference it without
      depending on [cn_activation.ml] which is IO-touching.

    It was extracted from [src/cmd/cn_runtime_contract.ml] (types +
    [zone_to_string]) and [src/cmd/cn_activation.ml] ([activation_entry])
    in v3.39.0 as the second slice of Move 2 of the #182 core refactor:
    pure-model gravity into [src/lib/]. The [Cn_runtime_contract]
    module in [src/cmd/] re-exports each type via OCaml type-equality
    syntax so existing callers compile without edits; [Cn_activation]
    does the same for [activation_entry]. The IO-side of both modules
    is unchanged.

    Discipline (CORE-REFACTOR.md §7): this module may import only
    stdlib and other [src/lib/] modules. No [Cn_ffi], no [Cn_executor],
    no [Cn_cmd], no HTTP, no process exec, no filesystem, no git, no
    LLM. Verified by grep in the cycle's self-coherence. *)

(* === Activation entry (extracted from cn_activation.ml — pure 4-field
   record with no IO references; [build_index] and the frontmatter
   parser stay in cn_activation.ml) === *)

type activation_entry = {
  skill_id : string;
  package : string;
  summary : string;
  triggers : string list;
}

(* === Package info === *)

(** A single installed package's summary as the runtime contract
    sees it. [sha256] is [None] for packages that exist on disk
    without a lockfile entry (e.g. manually vendored). *)
type package_info = {
  name : string;
  version : string;
  sha256 : string option;
  doctrine_count : int;
  mindset_count : int;
  skill_count : int;
}

(* === Override info === *)

(** Per-package override paths (hub-relative) for each of the three
    override-bearing content classes. *)
type override_info = {
  doctrine : string list;
  mindsets : string list;
  skills : string list;
}

(* === Zone + zone entry === *)

(** Semantic classification of hub-relative paths.
    The runtime contract projects each observed path into one of
    five zones so the agent can reason about "what kind of thing
    is at this path" from the contract alone. *)
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

(** Canonical string form of a zone, used in the JSON and markdown
    projections of the runtime contract. Five total mappings. *)
let zone_to_string = function
  | Constitutive_self -> "constitutive_self"
  | Memory -> "memory"
  | Private_body -> "private_body"
  | Work_medium -> "work_medium"
  | Projection_surface -> "projection_surface"

(* === Identity === *)

type identity = {
  cn_version : string;
  hub_name : string;
  profile : string;
}

(* === Extension contract info === *)

type extension_contract_info = {
  ext_name : string;
  ext_version : string;
  ext_package : string;
  ext_backend : string;
  ext_state : string;
  ext_ops : string list;
}

(* === Command entry === *)

type command_entry = {
  cmd_name : string;
  cmd_source : string;          (** "repo-local" | "package" *)
  cmd_package : string option;
  cmd_summary : string;
}

(* === Orchestrator entry === *)

type orchestrator_entry = {
  orch_name : string;
  orch_source : string;         (** always "package" in v1 *)
  orch_package : string;
  orch_trigger_kinds : string list;
}

(* === Cognition layer === *)

type cognition = {
  packages : package_info list;
  overrides : override_info;
  extensions_installed : extension_contract_info list;
  activation_index : activation_entry list;
}

(* === Body contract layer === *)

type body_contract = {
  capabilities_text : string;
  peers : string list;
  extensions_active : extension_contract_info list;
  commands : command_entry list;
  orchestrators : orchestrator_entry list;
}

(* === Runtime contract (four-layer root) === *)

type runtime_contract = {
  identity : identity;
  cognition : cognition;
  body : body_contract;
  medium : zone_entry list;
}
