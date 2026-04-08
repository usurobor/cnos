(** cn_workflow.ml — Orchestrator IR runtime (`cn.orchestrator.v1`).

    Implements the mechanical workflow engine specified in
    `docs/alpha/agent-runtime/ORCHESTRATORS.md` §7-8.

    Responsibilities:
    - Parse an orchestrator manifest (`cn.orchestrator.v1` JSON)
      into typed IR.
    - Validate it structurally: no duplicate step ids, all step
      refs resolve, every dispatched op is in `permissions.ops`,
      every `llm` step requires `permissions.llm = true`.
    - Discover installed orchestrators under
      `.cn/vendor/packages/*/orchestrators/<id>/orchestrator.json`
      per the package-system content-class rule (§10.3).
    - Execute a loaded IR step by step: deterministic control
      flow (`if`, `match`, `return`, `fail`) plus typed `op`
      dispatch via [Cn_executor.execute_op]. Receipts/events are
      emitted to the global trace session (no-op when no session).

    Deferred to a later cycle (documented in ORCHESTRATORS.md §8.2):
    - [parallel] step kind (cnos has no async model)
    - [llm] step execution (prompt + context injection mechanism
      not yet designed)

    Naming: this module is distinct from the pre-existing
    [Cn_orchestrator] which implements the N-pass LLM bind loop.
    Two orthogonal orchestration concerns, two modules. *)

(* === Types === *)

type trigger = {
  trigger_kind : string;       (** "command" | "schedule" | "event" *)
  trigger_name : string;
}

type permissions = {
  llm : bool;
  ops : string list;           (** allowed op kind names *)
  external_effects : bool;
}

type step =
  | Op_step of {
      id : string;
      op : string;             (** op kind name e.g. "fs_read" *)
      args : (string * Cn_json.t) list;
      bind : string option;
    }
  | Llm_step of {
      id : string;
      prompt : string;
      bind : string option;
    }
  | If_step of {
      id : string;
      cond : string;           (** name of bound boolean *)
      then_ref : string;       (** step id to jump to on true *)
      else_ref : string;       (** step id to jump to on false *)
    }
  | Match_step of {
      id : string;
      input : string;          (** bound value name to match on *)
      cases : (string * string) list;  (** literal-value -> step id *)
      default : string option; (** step id when no case matches *)
    }
  | Return_step of {
      id : string;
      value : Cn_json.t;
    }
  | Fail_step of {
      id : string;
      message : string;
    }

type orchestrator = {
  kind : string;
  name : string;
  trigger : trigger;
  permissions : permissions;
  steps : step list;
}

(* === Parser === *)

let ( let* ) r f = match r with Ok v -> f v | Error _ as e -> e

let require_string key json =
  match Cn_json.get_string key json with
  | Some s -> Ok s
  | None -> Error (Printf.sprintf "missing or non-string field '%s'" key)

let parse_string_list key json =
  match Cn_json.get key json with
  | None -> []
  | Some (Cn_json.Array xs) ->
      xs |> List.filter_map (function
        | Cn_json.String s -> Some s
        | _ -> None)
  | Some _ -> []

let parse_trigger json =
  match Cn_json.get "trigger" json with
  | None -> Error "missing 'trigger'"
  | Some t ->
      let* tk = require_string "kind" t in
      let* tn = require_string "name" t in
      Ok { trigger_kind = tk; trigger_name = tn }

let parse_permissions json =
  match Cn_json.get "permissions" json with
  | None -> Error "missing 'permissions'"
  | Some p ->
      let llm = match Cn_json.get "llm" p with
        | Some (Cn_json.Bool b) -> b
        | _ -> false in
      let ops = parse_string_list "ops" p in
      let external_effects = match Cn_json.get "external_effects" p with
        | Some (Cn_json.Bool b) -> b
        | _ -> false in
      Ok { llm; ops; external_effects }

let parse_step json =
  let* id = require_string "id" json in
  let* kind = require_string "kind" json in
  match kind with
  | "op" ->
      let* op = require_string "op" json in
      let args = match Cn_json.get "args" json with
        | Some (Cn_json.Object fields) -> fields
        | _ -> []
      in
      let bind = Cn_json.get_string "bind" json in
      (* Note: the `inputs` field (a string list referencing bound
         names from prior steps) is accepted by the wire schema
         (ORCHESTRATORS.md §8) but not yet consumed by the executor.
         The binding-substitution mechanism is part of the `llm`
         step design work deferred from this cycle. Once `llm` is
         wired, `inputs` is re-added to the Op_step record with a
         resolution pass from the environment into args. For now it
         is silently accepted at parse time to preserve
         forward-compatibility at the wire level. *)
      ignore (parse_string_list "inputs" json);
      Ok (Op_step { id; op; args; bind })
  | "llm" ->
      let* prompt = require_string "prompt" json in
      (* Same deferral as Op_step: inputs is accepted but not stored. *)
      ignore (parse_string_list "inputs" json);
      let bind = Cn_json.get_string "bind" json in
      Ok (Llm_step { id; prompt; bind })
  | "if" ->
      let* cond = require_string "cond" json in
      let* then_ref = require_string "then" json in
      let* else_ref = require_string "else" json in
      Ok (If_step { id; cond; then_ref; else_ref })
  | "match" ->
      let* input = require_string "input" json in
      let cases = match Cn_json.get "cases" json with
        | Some (Cn_json.Object fields) ->
            fields |> List.filter_map (function
              | (k, Cn_json.String v) -> Some (k, v)
              | _ -> None)
        | _ -> []
      in
      let default = Cn_json.get_string "default" json in
      Ok (Match_step { id; input; cases; default })
  | "return" ->
      let value = match Cn_json.get "value" json with
        | Some v -> v
        | None -> Cn_json.Object []
      in
      Ok (Return_step { id; value })
  | "fail" ->
      let message = Cn_json.get_string "message" json
        |> Option.value ~default:"" in
      Ok (Fail_step { id; message })
  | other ->
      Error (Printf.sprintf
        "step '%s': unknown kind '%s' (supported: op, llm, if, match, return, fail)"
        id other)

let parse json =
  let* kind = require_string "kind" json in
  if kind <> "cn.orchestrator.v1" then
    Error (Printf.sprintf "unsupported schema kind '%s' \
      (expected 'cn.orchestrator.v1')" kind)
  else
    let* name = require_string "name" json in
    let* trigger = parse_trigger json in
    let* permissions = parse_permissions json in
    let* steps =
      match Cn_json.get "steps" json with
      | None -> Error "missing 'steps'"
      | Some (Cn_json.Array items) ->
          let rec collect acc = function
            | [] -> Ok (List.rev acc)
            | s :: rest ->
                (match parse_step s with
                 | Ok step -> collect (step :: acc) rest
                 | Error e -> Error e)
          in
          collect [] items
      | Some _ -> Error "'steps' is not an array"
    in
    Ok { kind; name; trigger; permissions; steps }

let parse_file path =
  if not (Cn_ffi.Fs.exists path) then
    Error (Printf.sprintf "missing orchestrator file: %s" path)
  else
    match Cn_json.parse (Cn_ffi.Fs.read path) with
    | Error msg -> Error (Printf.sprintf "invalid JSON: %s" msg)
    | Ok json -> parse json

(* === Validation === *)

type issue_kind =
  | Missing_field of string
  | Unknown_step_kind of string
  | Duplicate_step_id of string
  | Invalid_step_ref of string
  | Permission_gap of string
  | Llm_without_permission
  | Empty_steps

type issue = {
  issue_kind : issue_kind;
  message : string;
}

let step_id = function
  | Op_step s -> s.id
  | Llm_step s -> s.id
  | If_step s -> s.id
  | Match_step s -> s.id
  | Return_step s -> s.id
  | Fail_step s -> s.id

let validate (o : orchestrator) =
  let issues = ref [] in
  let add kind message =
    issues := { issue_kind = kind; message } :: !issues
  in

  if o.steps = [] then
    add Empty_steps "orchestrator has no steps"
  else begin
    (* Duplicate step ids *)
    let seen = Hashtbl.create 16 in
    o.steps |> List.iter (fun s ->
      let id = step_id s in
      if Hashtbl.mem seen id then
        add (Duplicate_step_id id)
          (Printf.sprintf "duplicate step id: %s" id)
      else
        Hashtbl.add seen id ());

    (* Invalid step refs: if/match targets must exist *)
    let all_ids = Hashtbl.create 16 in
    o.steps |> List.iter (fun s ->
      Hashtbl.replace all_ids (step_id s) ());
    let check_ref target =
      if not (Hashtbl.mem all_ids target) then
        add (Invalid_step_ref target)
          (Printf.sprintf "step ref '%s' does not resolve" target)
    in
    o.steps |> List.iter (function
      | If_step s ->
          check_ref s.then_ref;
          check_ref s.else_ref
      | Match_step s ->
          List.iter (fun (_, ref) -> check_ref ref) s.cases;
          (match s.default with
           | Some ref -> check_ref ref
           | None -> ())
      | _ -> ());

    (* Permission gaps *)
    o.steps |> List.iter (function
      | Op_step s ->
          if not (List.mem s.op o.permissions.ops) then
            add (Permission_gap s.op)
              (Printf.sprintf "step '%s' uses op '%s' not in permissions.ops"
                 s.id s.op)
      | Llm_step s when not o.permissions.llm ->
          add Llm_without_permission
            (Printf.sprintf "step '%s' is an llm step but permissions.llm=false"
               s.id)
      | _ -> ())
  end;

  List.rev !issues

(* === Discovery === *)

type load_outcome =
  | Loaded of orchestrator
  | Load_error of string

type installed = {
  package : string;
  id : string;
  path : string;
  outcome : load_outcome;
}

(** Read the list of declared orchestrator ids from a package manifest.
    Returns [] when the field is missing or malformed (cn_deps doctor
    covers malformed-manifest reporting). *)
let manifest_orchestrator_ids ~pkg_name json =
  match Cn_json.get "sources" json with
  | None -> []
  | Some sources ->
      match Cn_json.get "orchestrators" sources with
      | None -> []
      | Some (Cn_json.Array items) ->
          items |> List.filter_map (function
            | Cn_json.String s -> Some s
            | other ->
                Printf.eprintf
                  "cn: workflow: package %s: sources.orchestrators entry is \
                   not a string (%s), skipping\n"
                  pkg_name (Cn_json.to_string other);
                None)
      | Some _ ->
          Printf.eprintf
            "cn: workflow: package %s: sources.orchestrators is not an array, ignoring\n"
            pkg_name;
          []

let discover ~hub_path =
  Cn_assets.list_installed_packages hub_path
  |> List.concat_map (fun (pkg_name, pkg_dir) ->
    let manifest_path = Cn_ffi.Path.join pkg_dir "cn.package.json" in
    if not (Cn_ffi.Fs.exists manifest_path) then []
    else
      match Cn_json.parse (Cn_ffi.Fs.read manifest_path) with
      | Error msg ->
          Printf.eprintf
            "cn: workflow: package %s: cannot parse %s: %s\n"
            pkg_name manifest_path msg;
          []
      | Ok json ->
          manifest_orchestrator_ids ~pkg_name json
          |> List.map (fun orch_id ->
            let path = Cn_ffi.Path.join pkg_dir
              (Printf.sprintf "orchestrators/%s/orchestrator.json" orch_id) in
            let outcome = match parse_file path with
              | Ok o -> Loaded o
              | Error msg -> Load_error msg
            in
            { package = pkg_name; id = orch_id; path; outcome }))

(* === Doctor validation === *)

(** Collect a doctor-facing summary of every installed orchestrator:
    load failures and schema-level issues each become a line. *)
let doctor_issues ~hub_path =
  discover ~hub_path
  |> List.concat_map (fun i ->
    match i.outcome with
    | Load_error msg ->
        [ Printf.sprintf "%s/%s: %s" i.package i.id msg ]
    | Loaded o ->
        validate o
        |> List.map (fun (iss : issue) ->
          Printf.sprintf "%s/%s: %s" i.package i.id iss.message))

(* === Execution === *)

type outcome =
  | Completed of Cn_json.t
  | Failed of string

(** Build a [Cn_shell.typed_op] from an [Op_step] invocation. *)
let typed_op_of_op_step ~op_kind (op_name : string) (args : (string * Cn_json.t) list) =
  { Cn_shell.kind = op_kind;
    op_id = Some (Printf.sprintf "orch-%s" op_name);
    fields = args }

let trace_event ~component ~event ~status ~reason ~details =
  let reason_opt = if reason = "" then None else Some reason in
  Cn_trace.gemit
    ~component
    ~layer:Cn_trace.Body
    ~event
    ~severity:Cn_trace.Info
    ~status
    ?reason:reason_opt
    ~details
    ()

(** Look up a step by id. Returns [None] if not found. *)
let find_step orch id =
  List.find_opt (fun s -> step_id s = id) orch.steps

(** Render a bound-value reference in an [if]/[match] step. The
    environment holds JSON values, and the condition/input names refer
    to either a previously bound name or the literal string in the IR.
    v1 keeps this simple: look up by name, return [None] if not bound. *)
let env_get (env : (string * Cn_json.t) list) name =
  List.assoc_opt name env

(** Convert a bound value to a boolean for [if]-step cond. *)
let as_bool = function
  | Cn_json.Bool b -> b
  | Cn_json.String "true" -> true
  | Cn_json.String "false" -> false
  | Cn_json.Int 0 -> false
  | Cn_json.Int _ -> true
  | Cn_json.Null -> false
  | _ -> true

(** Convert a bound value to a string for [match]-step input. *)
let as_string = function
  | Cn_json.String s -> s
  | Cn_json.Bool true -> "true"
  | Cn_json.Bool false -> "false"
  | Cn_json.Int i -> string_of_int i
  | Cn_json.Null -> "null"
  | v -> Cn_json.to_string v

(** Execute one step, producing either a new environment + next step
    id, or a terminal outcome. *)
let rec execute_step ~hub_path ~shell_config (o : orchestrator) env step =
  let name = o.name in
  let id = step_id step in
  trace_event
    ~component:"workflow"
    ~event:"workflow.step.start"
    ~status:Cn_trace.Ok_
    ~reason:""
    ~details:[
      "workflow", Cn_json.String name;
      "step_id", Cn_json.String id;
    ];
  match step with
  | Return_step s ->
      trace_event
        ~component:"workflow"
        ~event:"workflow.step.complete"
        ~status:Cn_trace.Ok_
        ~reason:""
        ~details:[
          "workflow", Cn_json.String name;
          "step_id", Cn_json.String s.id;
          "terminal", Cn_json.String "return";
        ];
      `Terminal (Completed s.value)

  | Fail_step s ->
      trace_event
        ~component:"workflow"
        ~event:"workflow.step.complete"
        ~status:Cn_trace.Error_status
        ~reason:s.message
        ~details:[
          "workflow", Cn_json.String name;
          "step_id", Cn_json.String s.id;
          "terminal", Cn_json.String "fail";
        ];
      `Terminal (Failed (Printf.sprintf "workflow fail at step '%s': %s"
                           s.id s.message))

  | Op_step s ->
      (* Permission gate — defence in depth; validator also flags. *)
      if not (List.mem s.op o.permissions.ops) then begin
        trace_event
          ~component:"workflow"
          ~event:"workflow.step.complete"
          ~status:Cn_trace.Blocked
          ~reason:"permission_gap"
          ~details:[
            "workflow", Cn_json.String name;
            "step_id", Cn_json.String s.id;
            "op", Cn_json.String s.op;
          ];
        `Terminal (Failed (Printf.sprintf
          "workflow '%s' step '%s': op '%s' not permitted by permissions.ops"
          name s.id s.op))
      end else
        (match Cn_shell.op_kind_of_string s.op with
         | None ->
             `Terminal (Failed (Printf.sprintf
               "workflow '%s' step '%s': unknown op '%s'"
               name s.id s.op))
         | Some op_kind ->
             let top = typed_op_of_op_step ~op_kind s.op s.args in
             let trigger_id = Printf.sprintf "workflow-%s-%s" name s.id in
             let receipt =
               Cn_executor.execute_op
                 ~hub_path
                 ~trigger_id
                 ~config:shell_config
                 top
             in
             (match receipt.status with
              | Cn_shell.Ok_status ->
                  let artifacts_json =
                    receipt.artifacts
                    |> List.map (fun (a : Cn_shell.artifact) ->
                      Cn_json.Object [
                        "path", Cn_json.String a.path;
                        "hash", Cn_json.String a.hash;
                        "size", Cn_json.Int a.size;
                      ])
                  in
                  let bound =
                    Cn_json.Object [
                      "status", Cn_json.String "ok";
                      "kind", Cn_json.String receipt.kind;
                      "artifacts", Cn_json.Array artifacts_json;
                    ]
                  in
                  let env' = match s.bind with
                    | Some key -> (key, bound) :: env
                    | None -> env
                  in
                  trace_event
                    ~component:"workflow"
                    ~event:"workflow.step.complete"
                    ~status:Cn_trace.Ok_
                    ~reason:""
                    ~details:[
                      "workflow", Cn_json.String name;
                      "step_id", Cn_json.String s.id;
                      "op", Cn_json.String s.op;
                      "bind", Cn_json.String (Option.value s.bind ~default:"");
                    ];
                  `Continue (env', next_step_after o s.id)
              | _ ->
                  trace_event
                    ~component:"workflow"
                    ~event:"workflow.step.complete"
                    ~status:Cn_trace.Error_status
                    ~reason:receipt.reason
                    ~details:[
                      "workflow", Cn_json.String name;
                      "step_id", Cn_json.String s.id;
                      "op", Cn_json.String s.op;
                    ];
                  `Terminal (Failed (Printf.sprintf
                    "workflow '%s' step '%s': op '%s' failed: %s"
                    name s.id s.op receipt.reason))))

  | Llm_step s ->
      (* v1 stub: parsed + validated + permission-checked, but not
         executed. The prompt + context injection mechanism is still
         being designed (PLAN-174 §Risk). *)
      trace_event
        ~component:"workflow"
        ~event:"workflow.step.complete"
        ~status:Cn_trace.Error_status
        ~reason:"llm_not_implemented"
        ~details:[
          "workflow", Cn_json.String name;
          "step_id", Cn_json.String s.id;
        ];
      `Terminal (Failed (Printf.sprintf
        "workflow '%s' step '%s': llm step not yet implemented in this release"
        name s.id))

  | If_step s ->
      let cond_val = env_get env s.cond in
      let branch = match cond_val with
        | Some v -> if as_bool v then s.then_ref else s.else_ref
        | None ->
            (* Unbound cond → treat as false, take else branch. This
               is explicit default behaviour, not a silent skip. *)
            s.else_ref
      in
      (match find_step o branch with
       | Some target ->
           trace_event
             ~component:"workflow"
             ~event:"workflow.step.complete"
             ~status:Cn_trace.Ok_
             ~reason:""
             ~details:[
               "workflow", Cn_json.String name;
               "step_id", Cn_json.String s.id;
               "branch", Cn_json.String branch;
             ];
           `Jump (env, target)
       | None ->
           `Terminal (Failed (Printf.sprintf
             "workflow '%s' step '%s': branch target '%s' not found"
             name s.id branch)))

  | Match_step s ->
      let input_val = env_get env s.input in
      let key = match input_val with
        | Some v -> as_string v
        | None -> ""
      in
      let branch = match List.assoc_opt key s.cases, s.default with
        | Some target, _ -> Some target
        | None, Some d -> Some d
        | None, None -> None
      in
      (match branch with
       | None ->
           `Terminal (Failed (Printf.sprintf
             "workflow '%s' step '%s': no case for input '%s' and no default"
             name s.id key))
       | Some target ->
           match find_step o target with
           | Some tgt ->
               trace_event
                 ~component:"workflow"
                 ~event:"workflow.step.complete"
                 ~status:Cn_trace.Ok_
                 ~reason:""
                 ~details:[
                   "workflow", Cn_json.String name;
                   "step_id", Cn_json.String s.id;
                   "branch", Cn_json.String target;
                 ];
               `Jump (env, tgt)
           | None ->
               `Terminal (Failed (Printf.sprintf
                 "workflow '%s' step '%s': match target '%s' not found"
                 name s.id target)))

(** Return the step immediately following the given step id in the
    manifest's step list, or [None] if this was the last step. *)
and next_step_after o id =
  let rec walk = function
    | [] -> None
    | s :: next :: _ when step_id s = id -> Some next
    | _ :: rest -> walk rest
  in
  walk o.steps

(** Execute the orchestrator from its first step.

    [env] supplies a pre-seeded binding environment; the default
    [[]] starts clean. Tests use this to pre-bind scalars so the
    [if] and [match] branches can be exercised directly without
    needing a working [llm] step (which is deferred in v1). *)
let execute ~hub_path ?(shell_config = Cn_shell.default_shell_config)
            ?(env = []) o =
  match o.steps with
  | [] -> Failed (Printf.sprintf "workflow '%s' has no steps" o.name)
  | first :: _ ->
      let rec loop env step =
        match execute_step ~hub_path ~shell_config o env step with
        | `Terminal outcome -> outcome
        | `Continue (env', Some next) -> loop env' next
        | `Continue (_, None) ->
            Failed (Printf.sprintf
              "workflow '%s' step '%s' fell off the end without return/fail"
              o.name (step_id step))
        | `Jump (env', next) -> loop env' next
      in
      loop env first
