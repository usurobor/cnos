# Gate — v3.43.0 (#205: Go kernel Phase 1)

- **CI:** pending (draft PR — check 8 formal this cycle)
- **Artifacts:** README ✅, SELF-COHERENCE ✅ (α A, β A, γ A), GATE ✅
- **ACs:** all 6 mapped to code + tests
- **Tests pass locally:** `go test ./... && go vet ./...` ✅ (13 tests, 0 failures)
- **§2.5b 8-check:** all 8 green pre-commit; check 8 = draft until CI green
- **§1.4:** steps 9–13 owned by user (reviewer default releaser)
- **Release decision:** HOLD until CI green + review converges

## Gate checklist

- [ ] CI green (`go` workflow + existing `ocaml`/`coherence` workflows unaffected)
- [ ] `go test ./...` passes in CI
- [ ] `go vet ./...` clean in CI
- [ ] PR review converged
- [ ] Go types match OCaml type spec (`cn_package.ml` field names)
