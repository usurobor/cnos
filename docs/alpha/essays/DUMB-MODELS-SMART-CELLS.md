---
title: "Dumb Models, Smart Cells"
subtitle: "Convention over Vendor Runtime for Agent Systems"
version: v0.1.0
status: DRAFT
author: usurobor (aka Axiom) (human & AI)
date: 2026-06-22
---

# Dumb Models, Smart Cells
## Convention over Vendor Runtime for Agent Systems

**Status:** v0.1.0 (DRAFT — position paper)
**Author(s):** usurobor (aka Axiom) (human & AI)
**Date:** 2026-06-22

> **Scope:** This paper argues where agent-system intelligence should live. It does not specify the CN wire format (see [`WHITEPAPER.md`](../protocol/WHITEPAPER.md)) or the full cnos architecture (see [`THESIS.md`](../../THESIS.md)). It is a companion to both.

---

## 0. Abstract

**Governing question: where should agent-system intelligence live — inside a proprietary LLM runtime, or inside open conventions, cells, packages, receipts, and repo state?**

cnos answers: outside the model. The language model is a powerful but **replaceable executor**. Workflow, memory, identity, and proof live in the convention layer the system owns, not in the vendor runtime it rents.

"Dumb" here means **non-authoritative**, not low-capability. cnos routes hard, high-context work to frontier models on purpose ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md) §3). The model can be the smartest component in the system and still hold no durable authority over workflow, state, or trust. Capability is rented; authority is owned.

The argument is an analogy developers already know. Rails treated the database as a powerful but replaceable engine behind conventions — ActiveRecord, migrations, convention over configuration — so application logic lived in the framework, not in vendor-specific stored procedures. cnos treats the LLM the same way: a powerful but replaceable engine behind cells, packages, receipts, and dispatch conventions, so agent logic lives in the repo, not in the vendor runtime.

This paper shows the boundary is not aspirational. It is already drawn in the provider contract ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md) §21: *Package distributes. Extension declares. Provider executes. Kernel decides.*).

---

## 1. Where does intelligence drift by default?

Into the vendor runtime.

The dominant framing of AI systems says the LLM is the intelligence, tools make it useful, memory makes it durable, and orchestration makes it autonomous ([`THESIS.md`](../../THESIS.md) §1). Followed to its conclusion, that framing pushes every durable concern *into the vendor*: the vendor stores the memory, the vendor runs the agent loop, the vendor defines the threads, the vendor holds the keys.

The cost is structural, not cosmetic. A system organized this way is stateless in essence, fragile in operation, hard to audit, and dependent on a centralized service for its own correctness ([`THESIS.md`](../../THESIS.md) §1). The Moltbook incident is the concrete case: identity lived in a vendor database, one key leak compromised every agent, and write access broke the moment the vendor changed auth ([`WHITEPAPER.md`](../protocol/WHITEPAPER.md) §1). When identity depends on a platform, losing the platform means losing agency.

The drift is the default because it is the path of least resistance. Each vendor feature — managed memory, an assistants API, a hosted agent loop — is individually convenient and collectively a lock-in surface. The question is not whether vendor runtimes are capable. It is whether the things a system must keep should live where the system cannot reach them.

---

## 2. What did Rails teach about replaceable engines?

That conventions outlast engines.

Relational databases in 2004 were powerful, mature, and mutually incompatible. The naive design put application logic where the engine was strongest: stored procedures, vendor SQL dialects, database-specific triggers. That logic was fast and unportable. Switching engines meant rewriting the application.

Rails inverted the dependency. ActiveRecord, migrations, and convention over configuration treated the database as an engine *behind* a convention the framework owned. The database stayed powerful — it still indexed, joined, and enforced constraints — but it stopped being the home of application logic. You could run the same app on Postgres, MySQL, or SQLite because the durable shape lived in the framework, not the engine.

The lesson generalizes: **put the durable, portable intelligence in the convention layer, and treat the powerful component as a replaceable engine behind it.** A convention you own survives an engine you swap.

---

## 3. How does cnos make the model a replaceable engine?

By defining it as a provider the kernel governs, not an authority the system obeys.

The provider contract is explicit about the boundary ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md)):

> **Package distributes. Extension declares. Provider executes. Kernel decides.** (§21)

An LLM backend is a provider — `cnos.llm.local`, `cnos.llm.anthropic` — sitting in the same execution slot as `cnos.net.http` or `cnos.transport.git` (§2.1). It declares what it implements and what it needs; the kernel decides whether it is enabled, which ops it owns, what permissions and limits apply, and whether it is invoked at all (§12). A provider may not widen its own permission envelope (§10). Multiple providers can implement the same capability family without changing the kernel (§3, §19.1). That is the replaceable-engine property, made a runtime invariant.

Model selection is the second half of the move. cnos puts routing in the body/runtime policy layer, not in a skill or a prompt:

> The runtime has no explicit, inspectable policy for when a task should stay local and when it should escalate to a remote frontier model. ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md), Problem)

The challenged assumption is named directly: "Model selection can be left to the agent's judgment or to free-form prompt instructions" is rejected as not robust enough; provider choice is a body-plane decision about cost, locality, resilience, and capability limits. The design "turns routing into inspectable runtime policy instead of prompt folklore," and every routed call leaves a receipt recording the decision, the reason set, the provider, and the model name. The kernel — not the model — chooses the model.

---

## 4. Where does cnos put the intelligence instead?

In four homes the system owns: cells, packages, receipts, and repo state.

**Cells — the workflow lives in the protocol.** The coherence-cell kernel is a five-step closed loop — `contract → matter → review → receipt → verdict → decision` — and it is **substrate-independent**: it names only roles (α, β, γ, δ, ε), the validator predicate V, and the artifacts it reasons over, with no tooling, platform, or model in the kernel sections ([`CDD.md`](../../../src/packages/cnos.cdd/skills/cdd/CDD.md), §Kernel). The validator V is executable as a binary (`cn cdd verify`), not a model judgment call (§Hard rule). A model produces matter; the cell decides whether matter passes. Swap the model and the workflow's shape, gates, and verdicts are unchanged.

**Packages — the cognition arrives locally.** Doctrine, mindsets, and skills are distributed as versioned, installable packages so cognition is local, reproducible, and present at wake-up ([`THESIS.md`](../../THESIS.md) §12). Without packages, "skills become checkout-dependent" and "wake-up becomes nondeterministic." The intelligence an agent boots with is a property of its installed substrate, not of a vendor's hidden system prompt.

**Receipts — the proof is reconstructable from files.** The runtime must not merely act; it must explain itself through receipts for every effect, with state reconstructable from files alone ([`THESIS.md`](../../THESIS.md) §11.5, §11.2). Every provider op and every model route emits a typed receipt ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md) §13; [`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md) §6). Auditability does not depend on the vendor logging anything.

**Repo state — the identity and memory live in Git.** Identity is keys and signed commits; conversations are append-only thread logs; transport is forge-optional ([`WHITEPAPER.md`](../protocol/WHITEPAPER.md) §0.0, §6, §8). Git is the lowest durable substrate — where coherence becomes cloneable, signed, diffable, and mergeable ([`THESIS.md`](../../THESIS.md) §13). The agent's memory is in a repo it can clone, not in a database it can lose.

Together these four are what survives a model swap. The model touches all of them and owns none of them.

---

## 5. What does the model still do?

Bounded execution — and at frontier scale, the hardest of it.

This paper does not argue that models are weak or interchangeable in quality. cnos routes single-file, deterministic, low-context work to local models and escalates architecture, cross-package refactors, releases, and policy reconciliation to a frontier provider, because local models still fail too often on macro-coherence work ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md) §3). The model is often the most capable component in the loop.

What the model does not do is hold authority. It does not decide its own permissions ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md) §10.1), does not choose which provider runs ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md), Authority relationships), does not emit the verdict that gates its own output ([`CDD.md`](../../../src/packages/cnos.cdd/skills/cdd/CDD.md), §Hard rule), and does not own the memory or identity it operates over. "Dumb" is precisely this: powerful at the task, mute on the authority. Capability sits inside the cell; authority sits around it.

---

## 6. What does convention-over-runtime buy?

Four properties, each grounded in a boundary the system already enforces.

- **Swappability.** A new model is a new provider behind an unchanged kernel and unchanged cells ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md) §3, §19.1). No application rewrite — the Rails property.
- **Auditability.** Every effect and every route is a receipt; the verdict is an executable predicate, not a vendor's opaque judgment ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md) §13; [`CDD.md`](../../../src/packages/cnos.cdd/skills/cdd/CDD.md), §Hard rule).
- **Durability.** Identity, memory, and workflow live in cloneable, signed Git state, so they survive a vendor outage, price change, or shutdown ([`WHITEPAPER.md`](../protocol/WHITEPAPER.md) §3; [`THESIS.md`](../../THESIS.md) §13).
- **Cost control.** Routing keeps the baseline local and reserves frontier spend for macro-coherence work, as inspectable policy rather than per-prompt habit ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md), Leverage).

The common root: each property holds because the durable concern lives in a layer the system owns, not in the engine it rents.

---

## 7. How does this relate to the CN whitepaper and THESIS?

Three papers, three governing questions, one boundary.

| Paper | Governing question | Answer |
|-------|--------------------|--------|
| [`WHITEPAPER.md`](../protocol/WHITEPAPER.md) | Where do agents *coordinate*? | Git, with a thin CN convention layer. |
| [`THESIS.md`](../../THESIS.md) | What *is* cnos? | A recurrent coherence system across all scales. |
| This paper | Where should agent *intelligence* live? | Outside the vendor model — in cells, packages, receipts, and repo state. |

The CN whitepaper is the **protocol** thesis: it owns the substrate and the wire format. THESIS is the **system** thesis: it owns the coherence principle that unifies every layer. This paper is the **placement** thesis: it owns the comparative argument, aimed at developers, for why intelligence belongs in the convention layer and not the runtime. The CN whitepaper and THESIS are canonical for their scopes; this paper depends on both and specifies neither.

The three share one structural commitment: substrate and convention are owned; engines and projections are replaceable. CN draws that line under transport (forges are projections, the repo is the substrate). THESIS draws it under the whole stack (Git is the lowest durable articulation, not the source of coherence). This paper draws it under the model (the LLM is a provider the kernel governs, not an authority the system obeys).

---

## 8. Conclusion

The default trajectory of agent systems pushes intelligence into the vendor runtime, where it is convenient, capable, and unreachable. Rails showed the alternative twenty years ago: own the conventions, rent the engine.

cnos has already drawn the line in code. The model is a provider the kernel governs ([`PROVIDER-CONTRACT-v1.md`](../agent-runtime/PROVIDER-CONTRACT-v1.md)). Routing is inspectable policy, not prompt folklore ([`HYBRID-LLM-ROUTING.md`](../agent-runtime/HYBRID-LLM-ROUTING.md)). Workflow lives in a substrate-independent cell kernel ([`CDD.md`](../../../src/packages/cnos.cdd/skills/cdd/CDD.md)). Cognition, proof, and identity live in packages, receipts, and signed Git state ([`THESIS.md`](../../THESIS.md), [`WHITEPAPER.md`](../protocol/WHITEPAPER.md)).

Let the model be smart. Keep the authority in the cells.
