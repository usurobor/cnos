---
name: typescript
description: Write TypeScript that keeps runtime behavior, type surfaces, and module boundaries aligned. Use when building CLIs, services, tooling, registries, package flows, or browser/node apps in TypeScript.
artifact_class: skill
kata_surface: embedded
governing_question: How do we write TypeScript that is explicit at runtime, strict at compile time, and hard to lie to?
triggers:
  - implementing cnos-adjacent tools or services in TypeScript
  - building package/index/registry tooling in TS
  - reviewing TypeScript for runtime/type drift
  - debugging async, module, or schema issues in TS
  - migrating JavaScript into TypeScript
---

# TypeScript

## Core Principle

**Write TypeScript so the runtime truth and the type story stay aligned.**

Use TypeScript to make invalid states harder to represent, not easier to hide. Prefer explicit data models, narrowing, discriminated unions, and checked boundaries over `any`, type assertions, and wishful typing.

## Algorithm

1. **Define** — name the runtime model, the module boundary, the async/error policy, and the validation boundary.
2. **Unfold** — design types, modules, runtime validation, async flow, and tests together.
3. **Rules** — keep the code strict, explicit, exhaustively handled, and hostile to type/runtime drift.
4. **Verify** — compile, lint, test, and check the same boundary cases across the whole surface.

---

## 1. Define

### 1.0. Classify the artifact first

Use this skill for TypeScript code that belongs to:

- CLI/tools
- services
- registries/manifests
- package/index handling
- command dispatch
- orchestrator tooling
- browser/node apps where runtime/type drift matters

Do **not** use this skill for:

- prose-only documentation
- framework-specific style wars with no runtime consequence
- "just add types later" JavaScript scaffolding

### 1.1. Identify the parts

A coherent TypeScript subsystem has:

- **Runtime model** — what actually exists at runtime
- **Type model** — how that reality is represented statically
- **Boundary validation** — where `unknown` input becomes trusted data
- **Module surface** — what a module exports and what it hides
- **Async policy** — how promises, cancellation, and retries are handled
- **Error policy** — how failure is represented and propagated
- **Build/lint/test contract** — what proves the code is safe to ship
  - ❌ Start with types disconnected from runtime parsing
  - ✅ Define the runtime payloads and the type model together

### 1.2. Articulate how they fit

Runtime values cross boundaries as `unknown`. Validation makes them trusted. Types model the trusted shape. Modules expose only what callers need. Async flow is explicit. Errors are values or exceptions by policy, not accidents.

- ❌ Parse JSON straight into `any` and let the app discover the real shape later
- ✅ Treat external input as `unknown`, validate it, then narrow to the domain type

### 1.3. Name the failure mode

TypeScript fails through **type/runtime drift**. Typical signs:

- `any` leakage
- assertion-driven programming (`as X`) at trust boundaries
- promises started and ignored
- unions that are never exhaustively checked
- optional fields used as if always present
- type-only imports mixed with runtime imports carelessly
- module surface confusion between ESM/CJS/runtime shape
  - ❌ `const cfg = JSON.parse(text) as Config`
  - ✅ `const raw: unknown = JSON.parse(text); const cfg = parseConfig(raw)`

---

## 2. Unfold

### 2.1. Compiler posture

Start strict. Use TypeScript's `strict` mode as the baseline. Tighten further where the project needs it.

Recommended baseline:

- `strict: true`

Recommended extra scrutiny when it fits the codebase:

- `noUncheckedIndexedAccess`
- `exactOptionalPropertyTypes`
- `noImplicitOverride`
- `useUnknownInCatchVariables`
  - ❌ Start loose and promise to tighten later
  - ✅ Start strict and carve out exceptions only when justified

### 2.2. Runtime boundary first

Every external boundary should begin as `unknown`. Typical boundaries:

- JSON parse
- HTTP request/response
- env/config
- local storage / database reads
- message bus / queue payloads
- plugin/extension manifests

Use narrowing and explicit validators to move from `unknown` to trusted types. TypeScript's narrowing model is built for this.

- ❌ `function load(x: any): Settings`
- ✅ `function parseSettings(x: unknown): Settings`

### 2.3. Type design

Prefer:

- concrete object types
- discriminated unions
- `readonly` where mutation is not part of the design
- `keyof`, indexed access, and generics when they remove duplication rather than add cleverness

Use discriminated unions for state machines and command/result surfaces.

```ts
type RestoreResult =
  | { kind: "ok"; packageName: string; version: string }
  | { kind: "missing"; packageName: string }
  | { kind: "checksum-mismatch"; packageName: string; expected: string; actual: string };
```

- ❌ One wide object with many optional fields and no discriminant
- ✅ A discriminated union with one obvious runtime case at a time

### 2.4. `any`, `unknown`, and assertions

Use:

- `unknown` at boundaries
- type predicates / assertion functions when they truly validate
- `satisfies` to check object shapes without widening away useful literal information. `satisfies` was added specifically for validating an expression's shape without changing the resulting type.

Avoid:

- `any`
- unchecked `as`
- double assertions (`as unknown as X`)

`typescript-eslint` is right to treat `any` as a dangerous escape hatch.

- ❌ `const manifest = raw as PackageManifest`
- ✅ `const manifest = parsePackageManifest(raw)`

### 2.5. Modules and imports

Keep module boundaries explicit. Prefer:

- small modules
- named exports by default
- `import type` for type-only imports
- one clear ESM/CJS strategy per package

`consistent-type-imports` exists for a reason: it prevents value/type ambiguity and improves readability.

- ❌ Mix runtime and type-only imports casually
- ✅ `import type { PackageLock } from "./types.js"`

### 2.6. Async and promises

Every promise must be:

- awaited
- returned
- or intentionally handled

No floating promises. No async functions passed into places that are not expecting promise-returning callbacks unless the behavior is deliberate. `typescript-eslint`'s `no-floating-promises` and `no-misused-promises` are exactly the right guardrails here.

- ❌ `doRestore()` and ignore the returned promise
- ✅ `await doRestore()`

If concurrency exists, own it explicitly:

- `Promise.all`
- bounded task groups
- retries with clear policy
- abort signals where cancellation matters

### 2.7. Exhaustiveness

If a union matters, handle it exhaustively. `switch-exhaustiveness-check` is the right lint rule because it forces the code to acknowledge when a union grows.

```ts
switch (result.kind) {
  case "ok": return ...
  case "missing": return ...
  case "checksum-mismatch": return ...
  default: return assertNever(result);
}
```

- ❌ Default branch that swallows new cases
- ✅ Exhaustive switch with `assertNever`

### 2.8. Schema and compatibility

Treat manifests, contracts, and registries as public contracts.

When handling:

- package manifests
- lockfiles
- indexes
- runtime contracts
- orchestrator IR
- extension manifests

prefer:

- explicit version fields
- additive evolution
- strict validation of required fields
- clear behavior for unknown fields
  - ❌ Silently coerce malformed manifest data into defaults
  - ✅ Reject malformed input with repairable errors

### 2.9. Determinism and reproducibility

For outputs that are:

- hashed
- compared in tests
- written to reports
- stored for later diffing

ensure:

- stable ordering
- canonical serialization
- no dependence on object key enumeration accidents where that matters
- no hidden timestamps unless intentionally included
  - ❌ Render maps/objects in whatever order they happen to appear
  - ✅ Sort before rendering where output stability matters

### 2.10. Side-effect boundaries

Keep parsing/validation/planning separate from:

- filesystem
- HTTP
- subprocesses
- archive extraction
- env access
  - ❌ Parse package manifests inside the fetcher
  - ✅ Fetch bytes in one module; parse and validate in the domain module

### 2.11. Node/browser reality

Types do not exist at runtime. Module systems, globals, file APIs, and network APIs do. Be explicit about:

- environment assumptions
- polyfills/shims if any
- Node vs browser boundaries
- runtime feature detection where necessary
  - ❌ Write code that type-checks but assumes a runtime that isn't there
  - ✅ Make the runtime target obvious in the package and module surface

### 2.12. Testing

Use:

- `tsc --noEmit`
- linter
- unit tests
- boundary tests
- unhappy-path tests

Test:

- malformed input
- missing fields
- unknown union members
- async failure
- retry/degraded paths
- deterministic output
  - ❌ Test only the happy path because "types already prove the rest"
  - ✅ Test the runtime boundary and degraded behavior explicitly

---

## 3. Rules

### 3.1. Start strict

Use `strict` mode by default. Tighten further where the codebase benefits.

### 3.2. External input starts as `unknown`

Do not trust JSON, HTTP, env, storage, or plugin data without validation. Use narrowing and validators to make trust explicit.

### 3.3. Avoid `any`

Use `unknown`, unions, generics, and validation instead. If `any` appears, treat it as a boundary or debt, not as the normal language.

### 3.4. Prefer discriminated unions for state and results

They keep runtime cases explicit and make exhaustiveness checking possible.

### 3.5. Use `satisfies` for object-shape validation

Use `satisfies` when you want to confirm an object matches a type while preserving its more specific inferred type.

### 3.6. Keep imports honest

Use `import type` for type-only imports and keep runtime/value imports explicit.

### 3.7. No floating or misused promises

Await them, return them, or handle them deliberately. Do not smuggle async callbacks into sync-shaped APIs accidentally.

### 3.8. Make fallback explicit

Fallback is policy, not accident. If a degraded path exists, it must be:

- visible
- testable
- reviewable
  - ❌ Return empty data and continue
  - ✅ Return a discriminated degraded result or throw an explicit error by policy

### 3.9. Preserve cnos boundaries

Keep these concepts distinct:

- **skills** choose
- **commands** dispatch
- **orchestrators** execute
- **extensions** provide capability

Do not let one registry or one module own two of those ideas at once.

### 3.10. Shell, archive, and path safety

When touching files, subprocesses, or archives:

- avoid shell string interpolation
- validate archive extraction paths
- reject path traversal
- do not log secrets
- make destructive operations explicit

### 3.11. Override precedence must be explicit

If behavior may come from:

- flags
- environment
- config
- runtime discovery
- defaults

define the precedence clearly and test it.

### 3.12. Build and verify before push

Run the equivalent of:

- `tsc --noEmit`
- linter
- test suite

before claiming the code is ready.

---

## 4. Verify

### 4.1. File-level check

- Is the runtime model explicit?
- Are boundaries typed honestly?
- Is validation present where trust begins?

### 4.2. Module check

- Are modules small and specific?
- Are type-only imports separated cleanly?
- Is ESM/CJS/runtime behavior explicit?

### 4.3. Async/error check

- Any floating promises?
- Any swallowed errors?
- Any degraded path that is invisible?

### 4.4. Schema/contract check

- Are manifests/versioned contracts validated?
- Are `unknown` and malformed cases handled explicitly?
- Is output deterministic where it matters?

### 4.5. Build/test check

- compile
- lint
- test
- boundary/degraded-path tests present

---

## 5. Kata

### 5.1. Kata A — package index client

**Scenario:** Implement a TypeScript client that loads a package index, validates package entries, and resolves name + version to a downloadable artifact.

**Task:** Write code that:

- reads JSON as `unknown`
- validates it into a domain type
- resolves a package version
- returns discriminated result types for missing or malformed cases

**Governing skills:** typescript, design, testing

**Inputs:**

- valid package index fixture
- malformed index fixture
- missing package fixture
- missing version fixture

**Expected artifacts:**

- domain types using discriminated unions
- explicit validator or parse layer
- no `any`
- tests for valid and invalid cases

**Verification:**

- no unchecked assertions at the trust boundary
- all union results handled exhaustively
- compile, lint, and tests pass

**Common failures:**

- `JSON.parse(...) as Index`
- one wide result type with many optional fields
- missing tests for malformed input
- swallowed errors on missing packages

**Reflection:**

- Did the type story match the runtime truth?
- Did invalid input fail explicitly enough to repair?

### 5.2. Kata B — async command runner

**Scenario:** Implement a command runner that downloads an artifact, verifies it, and writes it atomically.

**Task:** Write code that:

- uses explicit async flow
- never drops promises
- models success/failure as explicit result cases
- keeps IO separate from parsing/validation

**Governing skills:** typescript, design, testing

**Inputs:**

- successful fetch path
- checksum mismatch path
- network failure path
- atomic replace path

**Expected artifacts:**

- no floating promises
- clear error/result policy
- deterministic verification flow
- tests for unhappy paths

**Verification:**

- `no-floating-promises` and `no-misused-promises` would pass
- atomic path is explicit
- checksum mismatch is visible and test-covered

**Common failures:**

- fire-and-forget promise
- mixing validation inside transport
- broad catch that erases failure detail
- optional fields used as if required

**Reflection:**

- Did the async flow stay visible and auditable?
- Did retries/failures remain policy-driven rather than accidental?
