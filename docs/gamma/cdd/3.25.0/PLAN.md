# Implementation Plan — v3.25.0

## Engineering Level Target: L7

**Justification:** The fix changes the system boundary so that self-knowledge probing becomes structurally impossible, not just instructionally discouraged.

- **L5 (local correctness):** Fix the specific probing behavior — add instructions to the RC. Already done in v3.12.0-v3.16.2. Not sufficient.
- **L6 (system-safe):** Ensure RC, instructions, and doctor all agree — partially done. But the executor still processes probes normally.
- **L7 (system-shaping):** Change the executor boundary so probes for self-knowledge paths are intercepted and redirected. The class of failure (probing for self-knowledge) becomes impossible by construction, not by instruction.

The L7 move is justified because:
1. A structural interceptor eliminates the failure class — no LLM compliance needed
2. The change is small (one function, one path list) — not over-abstracted
3. Future agents on any LLM automatically get the protection

## Design

### What changes

1. **`cn_executor.ml`** — Add a `check_self_knowledge_path` function that identifies paths containing self-knowledge (version, identity, config). When `execute_fs_read` or `execute_fs_list` targets such a path, return a new receipt with status `contract_redirect` and a reason pointing to the Runtime Contract.

2. **`cn_shell.ml`** — Add `Contract_redirect` to the `op_status` type so the redirect is a first-class status, not overloaded on `Denied` or `Error_status`.

3. **`cn_runtime_contract.ml`** — Update the authority declaration to reference structural interception: "Probing these paths will return a contract_redirect — the runtime enforces this structurally."

4. **`cn_executor_test.ml`** — Add expect tests for:
   - `fs_read cn.json` -> contract_redirect
   - `fs_read` on package manifests -> contract_redirect
   - Legitimate reads unaffected
   - `fs_list` on self-knowledge dirs -> contract_redirect where applicable

### What doesn't change

- Sandbox denylist — self-knowledge interception is NOT a security boundary. The denylist remains for `.cn/`, `.git/`, `state/`, `logs/`. Self-knowledge paths may overlap with allowed paths (e.g., `cn.json` is in the hub root, which is allowed).
- Protected files list — remains for `spec/SOUL.md`, `spec/USER.md`, `state/peers.md`.
- Legitimate filesystem reads — `src/`, `docs/`, `agent/wake/README.md`, etc. are unaffected.

### Tradeoffs

- **False positives:** A path like `cn.json` is always redirected. If an agent has a legitimate reason to read it (e.g., debugging), the redirect blocks this. Acceptable because: (a) the RC already says not to read it, (b) the redirect reason explains where to find the information, (c) this is the canonical incident path from #64.
- **Path list maintenance:** The self-knowledge path list is static. New self-knowledge sources require updating the list. Acceptable because: (a) self-knowledge sources change rarely, (b) the list is small and explicit, (c) it's in one place in the executor.

## Self-Knowledge Paths

Paths that contain identity/version/config information already declared in the Runtime Contract:

| Path pattern | Why self-knowledge | RC section |
|---|---|---|
| `cn.json` | Contains cn_version, profile | Identity |
| `*.package.json` | Package manifests (version, deps) | Cognition |
| `state/runtime-contract.json` | JSON copy of the RC itself | All layers |

Note: `state/runtime-contract.json` is already denied by the sandbox denylist (`state/` prefix). But the interceptor should catch it first with a more helpful message.

## Implementation Steps

1. Add `Contract_redirect` status to `cn_shell.ml` op_status type
2. Add `is_self_knowledge_path` function to `cn_executor.ml`
3. Add interception logic to `execute_fs_read` and `execute_fs_list`
4. Write expect tests in `cn_executor_test.ml`
5. Update RC authority declaration in `cn_runtime_contract.ml`
6. Run `dune build` and `dune runtest`
7. Write SELF-COHERENCE.md
