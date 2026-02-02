# tsc-agents

Runtime self-specs and wiring for TSC-aligned agents.

This repo is the **agent layer** that sits next to `tsc-practice`:

- `tsc-practice` → shared specs and practices (CLP, CAP, CRS, CTB, etc.).
- `tsc-agents`   → concrete agents that *use* those practices in the wild.

## Current layout

Right now there is a single agent profile: **Usurobor**.

For compatibility with the current OpenClaw setup, Usurobor's self-spec files live at the **repo root**:

- `SOUL.md` — who the agent is.
- `USER.md` — who Axiom is.
- `USER-ROLE.md` — Coherence Team contract.
- `AGENTS.md` — workspace + memory conventions.
- `ENGINEERING.md` — engineering/coherence stance.
- `IDENTITY.md` — compact identity card.
- `HEARTBEAT.md` — periodic background tasks.
- `TOOLS.md` — local infra notes (e.g. Moltbook DB location).

`memory/` and other local state directories are gitignored.

In the future, we may introduce a structure like:

```text
tsc-agents/
  usurobor/
    SOUL.md
    USER.md
    ...
  <other-agent>/
    ...
```

When we do that, we'll also update the OpenClaw config so each agent can be loaded from its own subdirectory without breaking runtime.

## Relationship to tsc-practice

Agents in this repo are expected to treat `tsc-practice` as their **practice kit**:

- Use CLP/CAP/CRS/CTB as defined there.
- Keep their own runtime behavior (this repo) coherent with those specs.

## License

This project is licensed under the [Apache License 2.0](./LICENSE).
