# Implementation Plan: N-Pass Bind Loop (Issue #50)

**Status:** Draft
**Date:** 2026-03-21
**Design:** [`N-PASS-BIND-v3.8.0.md`](../../alpha/N-PASS-BIND-v3.8.0.md)
**Issues:** #50 (N-pass bind loop), #48 (Telegram typing indicators)
**Branch:** `claude/n-pass-bind-loop-VWKUT`

---

## Overview

Replace `Cn_orchestrator.run_two_pass` with a generalized `run_n_pass` bind loop.
Add a processing indicator abstraction with Telegram typing as the first sink.

### Guiding constraint

The existing two-pass behavior at `max_passes=2` MUST remain bit-identical in
receipts, events, coordination gating, and projection. The generalization adds
capability without breaking the established contract.

---

## Step 1: Extend `cn_shell.ml` — config fields

**File:** `src/cmd/cn_shell.ml`

Add to `shell_config`:

```ocaml
type shell_config = {
  (* ... existing fields ... *)
  max_passes : int;           (* default 5 *)
  max_total_ops : int;        (* default 32 *)
}
```

Update `default_shell_config`:
```ocaml
let default_shell_config = {
  (* ... existing ... *)
  max_passes = 5;
  max_total_ops = 32;
}
```

Generalize `needs_two_pass` → `needs_continuation`:

```ocaml
(** Determine if the current pass has observe ops requiring a followup.
    Under auto: any observe op triggers continuation. *)
let needs_continuation ~two_pass_mode ops =
  match two_pass_mode with
  | "off" -> false
  | _ (* "auto" *) ->
    let observe, _ = classify ops in
    List.length observe > 0
```

Keep `needs_two_pass` as a thin alias for backward compatibility in tests.

**Tests:** Update `cn_shell_test.ml` — verify new defaults parse correctly.

---

## Step 2: Extend `cn_config.ml` — parse new fields

**File:** `src/cmd/cn_config.ml`

Parse from the `runtime` config block:

```ocaml
max_passes = get_int "max_passes" d.max_passes 1;
max_total_ops = get_int "max_total_ops" d.max_total_ops 1;
```

Parse Telegram indicator config from `runtime.telegram` sub-object:
- `typing_indicator` (bool, default true)
- `typing_refresh_sec` (int, default 4, min 2)

Add to `config` type:

```ocaml
type telegram_config = {
  typing_indicator : bool;
  typing_refresh_sec : int;
}
```

**Tests:** Verify config loading with and without new fields.

---

## Step 3: Create `cn_indicator.ml` — processing indicator abstraction

**New file:** `src/cmd/cn_indicator.ml`

```ocaml
(** cn_indicator.ml — Processing indicator abstraction
    Best-effort UX signals for human-facing sinks.
    Never blocks processing pipeline. Never changes correctness. *)

type sink =
  | Telegram of { token : string; chat_id : int }
  | No_sink

type handle = {
  sink : sink;
  trigger_id : string;
}

(** Start a processing indicator for the given sink.
    Returns None for No_sink. Emits indicator.start event. *)
val start : sink:sink -> trigger_id:string -> handle option

(** Refresh the indicator (e.g., re-send typing action).
    Emits indicator.refresh event. *)
val refresh : handle -> unit

(** Stop the indicator. Emits indicator.stop event. *)
val stop : handle -> unit
```

Implementation:
- `start` — calls `Cn_telegram.send_typing` for Telegram sink, emits trace event
- `refresh` — calls `Cn_telegram.send_typing` again, emits trace event
- `stop` — no-op for Telegram (typing expires naturally), emits trace event
- All calls are wrapped in `try ... with _ -> ()` — never fatal

Add to `dune` build.

**Tests:** `cn_indicator_test.ml` — verify Telegram dispatch is called, No_sink is no-op.

---

## Step 4: Rewrite `cn_orchestrator.ml` — `run_n_pass`

**File:** `src/cmd/cn_orchestrator.ml`

### 4.1 New types

```ocaml
type pass_result = {
  pass_index : int;
  receipts : Cn_shell.receipt list;
  has_continuation : bool;
}

type n_pass_result = {
  all_receipts : Cn_shell.receipt list;     (* all passes combined *)
  final_coordination_ops : (Cn_lib.agent_op * coord_decision) list;
  final_output : Cn_output.parsed_output option;
  passes_used : int;
  stop_reason : string;                     (* no_ops | max_passes_reached | budget_exhausted | ... *)
}
```

### 4.2 Core loop: `run_n_pass`

```ocaml
let run_n_pass ~hub_path ~trigger_id ~config ~llm_call ~indicator typed_ops =
  let max_passes = config.Cn_shell.max_passes in
  let max_total_ops = config.max_total_ops in
  let total_ops = ref 0 in
  let all_receipts = ref [] in

  let rec loop ~pass_index ~current_ops ~last_output =
    let pass_label = string_of_int (pass_index + 1) in

    (* Emit pass.N.start *)
    emit_pass_start ~trigger_id ~pass_label;

    (* Refresh indicator before LLM call (skip first pass — already started) *)
    if pass_index > 0 then
      Option.iter Cn_indicator.refresh indicator;

    (* Classify: observe-class or effect-class pass *)
    let has_observe = needs_continuation ~two_pass_mode:config.two_pass current_ops in

    if has_observe then begin
      (* Observe-class: execute observe, defer effects *)
      let receipts = run_pass_observe ~hub_path ~trigger_id ~config
        ~pass_label current_ops in
      all_receipts := !all_receipts @ receipts;
      total_ops := !total_ops + List.length current_ops;

      if pass_index + 1 >= max_passes then begin
        emit_pass_complete ~trigger_id ~pass_label ~reason:"max_passes_reached";
        stop ~pass_index ~reason:"max_passes_reached" ~last_output
      end else if !total_ops >= max_total_ops then begin
        emit_pass_complete ~trigger_id ~pass_label ~reason:"budget_exhausted";
        stop ~pass_index ~reason:"budget_exhausted" ~last_output
      end else begin
        emit_pass_complete ~trigger_id ~pass_label ~reason:"observe_detected";
        (* Repack and call LLM *)
        let repack = repack_for_next_pass ~hub_path ~trigger_id ~config
          ~receipts in
        match llm_call repack with
        | Error msg -> Error (Printf.sprintf "Pass %s LLM call failed: %s" pass_label msg)
        | Ok raw_output ->
          let parsed = Cn_output.parse_output raw_output in
          if parsed.typed_ops = [] then
            (* No more ops — terminal *)
            Ok (make_result ~all_receipts:!all_receipts ~passes:(pass_index + 2)
                  ~final_output:(Some parsed) ~reason:"no_ops")
          else
            loop ~pass_index:(pass_index + 1)
                 ~current_ops:parsed.typed_ops ~last_output:(Some parsed)
      end
    end else begin
      (* Effect-class: execute all, then done *)
      let receipts = run_pass_effects ~hub_path ~trigger_id ~config
        ~pass_label current_ops in
      all_receipts := !all_receipts @ receipts;
      total_ops := !total_ops + List.length current_ops;

      emit_pass_complete ~trigger_id ~pass_label ~reason:"effect_only";

      (* At boundary: if we've used all passes, deny any further observe *)
      Ok (make_result ~all_receipts:!all_receipts ~passes:(pass_index + 1)
            ~final_output:last_output ~reason:"no_ops")
    end
  in

  loop ~pass_index:0 ~current_ops:typed_ops ~last_output:None
```

### 4.3 Preserve existing helpers

Keep `classify_coordination_pass_a`, `gate_coordination`, `is_terminal_op`,
`effects_all_ok`, `repack_for_pass_b`, `receipts_summary`, `artifact_excerpts`,
`receipt_result_signal` — they are all pass-agnostic already.

Rename `repack_for_pass_b` → `repack_for_next_pass` (keep old name as alias).

### 4.4 Pass-label mapping

Pass labels shift from "A"/"B" to "1"/"2"/..."N":
- `pass_label = string_of_int (pass_index + 1)`
- Receipt `pass` field uses this label

### 4.5 Backward compatibility at N=2

When `max_passes = 2`:
- Pass 1 = observe ops execute, effects deferred (was Pass A)
- Pass 2 = effects execute, observe denied (was Pass B)
- Coordination gating identical
- Same stop conditions

**Tests:** All existing `cn_orchestrator_test.ml` tests must pass with `max_passes=2`.

---

## Step 5: Wire `run_n_pass` in `cn_runtime.ml`

**File:** `src/cmd/cn_runtime.ml`

### 5.1 In `finalize`

Replace the `orchestrate` closure that calls `Cn_orchestrator.run_two_pass` with
one that calls `Cn_orchestrator.run_n_pass`:

```ocaml
let orchestrate typed_ops =
  let indicator = build_indicator ~config ~from ~chat_id_opt in
  Cn_orchestrator.run_n_pass ~hub_path ~trigger_id
    ~config:config.shell ~llm_call ~indicator typed_ops
in
```

### 5.2 Indicator lifecycle in `process_one`

For fresh dequeue (State 3):
1. After `queue.dequeue` event, build indicator sink from `from` and `chat_id_opt`
2. Call `Cn_indicator.start` immediately
3. Pass handle into `finalize` for refresh calls
4. `stop` is implicit (Telegram typing expires, or called on finalize completion)

### 5.3 Coordination ops

Generalize the two-pass coordination dispatch:
- Pass 1 through N-1: only pass-A-safe ops (ack, surface, idempotent reply)
- Final pass: all coordination ops, gated on effect success
- Use `n_pass_result.final_coordination_ops` from the orchestrator

### 5.4 Final projection

Use `n_pass_result.final_output` for:
- Telegram projection
- Conversation history append
- (replaces the current `final_parsed` ref pattern)

**Tests:** `cn_runtime_integration_test.ml` — update mocked orchestrate calls.

---

## Step 6: Update `cn_orchestrator_test.ml`

**File:** `test/cmd/cn_orchestrator_test.ml`

### 6.1 Existing tests → backward compat

Update existing tests to use `max_passes = 2` config explicitly.
All existing expect outputs MUST remain identical (pass labels may change A→1, B→2).

### 6.2 New tests

| Test | Verifies |
|------|----------|
| `N=3 observe→observe→effect` | Three-pass chain completes |
| `N=5 all observe → max_passes stops` | Loop terminates at boundary |
| `N=3 budget exhaustion` | `max_total_ops` stops loop |
| `N=1 single pass` | Degraded mode: all ops in one pass |
| `no_ops on pass 2 → terminal` | Early termination on empty ops |
| `pass labels are 1,2,3...` | Receipt pass field uses numeric labels |
| `indicator refresh called per pass` | Processing indicator lifecycle |

---

## Step 7: Update `AGENT-RUNTIME.md` patch notes

**File:** `docs/alpha/AGENT-RUNTIME.md`

Add patch note for v3.8.0:

```markdown
**v3.8.0** — N-Pass Bind Loop and Processing Indicators:
- Replace hardcoded two-pass orchestration with bounded N-pass bind loop
- `max_passes` configurable (default 5), replaces hardcoded `max_passes=2`
- Add `max_total_ops` budget (default 32) — loop stops when cumulative ops exceed
- Each pass emits `pass.N.start` / `pass.N.complete` telemetry with pass_index
- Add processing indicator abstraction (`cn_indicator.ml`) for human-facing sinks
- Telegram typing indicator: sent on dequeue, refreshed before each subsequent LLM call
- Only final pass output projected to user; intermediate outputs archived and receipted
- Receipt pass field changes from "A"/"B" to "1"/"2"/..."N" (schema unchanged)
- See: [`N-PASS-BIND-v3.8.0.md`](N-PASS-BIND-v3.8.0.md) for full design
```

---

## Step 8: Update `.cn/config.json` defaults

**File:** `.cn/config.json`

Add new fields to the runtime block:

```json
{
  "runtime": {
    "max_passes": 5,
    "max_total_ops": 32,
    "telegram": {
      "typing_indicator": true,
      "typing_refresh_sec": 4
    }
  }
}
```

---

## Implementation Order

The steps above are ordered by dependency:

```
Step 1 (cn_shell.ml)
  ↓
Step 2 (cn_config.ml)
  ↓
Step 3 (cn_indicator.ml)     ← independent, can parallel with Step 4
  ↓
Step 4 (cn_orchestrator.ml)  ← core change
  ↓
Step 5 (cn_runtime.ml)       ← wiring
  ↓
Step 6 (tests)
  ↓
Step 7 (docs)
  ↓
Step 8 (config)
```

Steps 3 and 4 are independent and can be developed in parallel.

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Runaway loops | Bounded by `max_passes` and `max_total_ops`; hard default 5 |
| Regression in two-pass behavior | Explicit N=2 backward-compat test suite |
| Indicator blocking pipeline | `request_once` with 3s timeout; wrapped in try/catch |
| Receipt schema break | `cn.receipts.v1` already accepts any string for `pass` |
| Config migration | New fields have defaults; missing = backward-compatible |

---

## Acceptance Criteria (from design doc)

1. `run_n_pass` replaces the hardcoded two-pass path
2. Loop terminates on: no ops, max passes, budget exhaustion, fatal failure
3. Each pass emits `pass.N.start` / `pass.N.complete` with receipts and telemetry
4. Telegram typing: sent on dequeue, refreshed between passes, absent on non-Telegram
5. Only final pass output projected; intermediate outputs archived
6. Existing two-pass behavior preserved when `max_passes=2`
