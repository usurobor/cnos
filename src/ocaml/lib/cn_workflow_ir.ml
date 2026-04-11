(** cn_workflow_ir.ml — Pure orchestrator IR types, parser, and validator.

    This module is the canonical authority for the shape of the
    [cn.orchestrator.v1] mechanical workflow engine IR:

    - 6 types: [trigger], [permissions], [step] (6-variant),
      [orchestrator], [issue_kind] (7-variant), [issue]
    - 6 parsers: [require_string], [parse_string_list],
      [parse_trigger], [parse_permissions], [parse_step], [parse]
    - 1 validator: [validate]
    - 2 helpers: [step_id], [manifest_orchestrator_ids]
    - 1 result combinator: [let ( let* )]

    It was extracted from [src/cmd/cn_workflow.ml] in v3.40.0 as the
    third slice of Move 2 of the #182 core refactor: pure-model
    gravity into [src/lib/]. The [Cn_workflow] module in [src/cmd/]
    re-exports each type via OCaml type-equality syntax and
    delegates each function via one-line let-bindings, so existing
    callers (the test file [cn_workflow_test.ml] plus the IO-side
    functions inside [cn_workflow.ml] itself that pattern-match on
    step/issue constructors) compile without edits. [Cn_workflow]
    retains the IO-side functions ([parse_file], [discover],
    [doctor_issues], [execute_step], [execute], [typed_op_of_op_step],
    [trace_event], [find_step], [env_get], [as_bool], [as_string]),
    the three IO-transit types ([load_outcome], [installed],
    [outcome] — they are pure by shape but only consumed by IO
    functions, per option (b) in issue #196), and the execution
    engine.

    Discipline (CORE-REFACTOR.md §7): this module may import only
    stdlib and other [src/lib/] modules. No [Cn_ffi], no [Cn_executor],
    no [Cn_shell], no [Cn_trace], no [Cn_assets], no [Cn_cmd], no HTTP,
    no process exec, no filesystem, no git, no LLM. Verified by grep
    in the cycle's self-coherence. *)

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

(* === Package manifest helper === *)

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
