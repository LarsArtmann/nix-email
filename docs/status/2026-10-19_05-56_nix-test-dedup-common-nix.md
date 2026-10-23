# Status Report: Nix Test Deduplication — tests/common.nix (2026-10-19 05:56)

> Point-in-time snapshot of the 2026-10-19 dedup session ("Can we
> deduplicate some nix code?"). Scope: this session only — what was done,
> what broke, what remains. Tree base for all identity proofs: `67914d7`
> (last pre-edit commit); work landed via daemon auto-commits
> `ff10c21..4c51fb7`. Format note: `.md` at the user's explicit request
> (skill default is HTML — override flagged in the session close-out).

## a) FULLY DONE

1. **Clone inventory of the whole Nix surface** (20 files, ~6.1k lines).
   Manual scan — `art-dupl` is Go-only, so the skill's judgment rules were
   applied by hand. Produced 7 harmful clone groups + 5 accepted groups with
   rationale. Evidence: session analysis; groups below.
2. **`tests/common.nix` created** — one canonical copy each for:
   `dnslessVmPatches` (DnsResolver Cloudflare + SpamPyzor off, full
   boot-race rationale), `testAdminSecretModule` + `testAdminSecret`
   (the `/etc/test-admin-secret` fallback-admin file), and
   `dmarcAggregateReport` (the upstream parsedmarc aggregate fixture).
   Evidence: file exists; imported by 7 files.
3. **DNS-less-VM patch block: 6 sites → 1.** Converted: stalwart-e2e (both
   nodes), stalwart-bind-e2e, stalwart-migrate-e2e (mig016),
   provision-plan-eval, demo-vm. relay-e2e deliberately keeps only the
   pyzor pin inline (it runs dnsmasq — the module's documented exception).
4. **test-admin-secret etc block: 6 sites → 1 module.** All e2e nodes +
   the `adminSecret` let-bindings in bind/migrate now source the value
   from common.
5. **DMARC aggregate fixture: 2 byte-identical fetchurls → 1.** The only
   behavioral delta anywhere: parsedmarc-e2e's fetchurl `name` changed
   `dmarc-test-report` → `dmarc-sample-aggregate` (same URL + sha256, so
   same bytes; different store-path name).
6. **module-import-eval: 4× `nixosSystem` boilerplate → `mailServerBase` +
   `mkEval`** (mirrors provision-plan-eval's existing `mkConfig` pattern).
   Evidence: **bit-identical derivation** pre/post (refactor-identity).
7. **stalwart-e2e in-file dedup:** 5 near-identical User objects →
   `mkUser`; 3 IMAP probe scripts → ONE mode-parameterized `imap-probe`
   (wait / absent / header; exit codes and messages kept verbatim); 7
   copy-pasted swaks submission blocks → `submit()` helper; 2 admin-secret
   literals → `${common.testAdminSecret}`.
8. **Verification battery, all green:**
   - `nix-instantiate --parse` on all 9 edited files.
   - `nix fmt -- . --check` — green twice, including on the FINAL tree
     (after the last nix edit).
   - Eval guards: 10 x86_64 checks + 4 aarch64 evals — set unchanged
     (lockstep + shape guards safe by construction).
   - **Refactor-identity proofs:** module-import-eval, provision-plan-eval,
     demo-eval, stalwart-bind-e2e, stalwart-migrate-e2e, stalwart-relay-e2e
     are BIT-IDENTICAL derivations vs `67914d7` (via
     `scripts/check-refactor-identity.sh` + `builtins.getFlake` at rev).
   - The three eval checks built + executed green (`--rebuild` forced).
   - stalwart-e2e: full VM run GREEN (rerun; see d5). parsedmarc-e2e: full
     VM run GREEN.
   - `buildflow --build-mode fast` exit 0. Full `nix flake check` exit 0.
   - CI lints run locally, green: pipe lint (awk), check-md-table-pipes,
     check-md-list-markers.
   - Flood-node config identity proven at eval (old inline shape vs new
     imports shape → `FLOOD_NODE_CONFIG_IDENTICAL`).
9. **Docs/memory updated:** AGENTS.md gained the tests/common.nix
   convention + the flake8 E501-in-writers trap; TODO_LIST.md gained the
   flood-flake watch row. Both pass the repo md lints.
10. **Net effect:** ~412 insertions / ~511 deletions across 12 files
    (excluding a foreign session's +314 status doc that appeared mid-window
    — noticed, not touched, per repo rules).

## b) PARTIALLY DONE

~~1. **Session close-out loop.** A re-engagement pass identified 8 open gaps~~ done — residue executed same day + next sessions (statix/deadnix green in gates; CI observed green; CHANGELOG entry added 2026-10-23)
   (format re-check, statix, deadnix, inventory scripts, dprint
   verification, CHANGELOG entry, accepted-duplication rationale, CI
   observation). Only the format re-check was executed before this report
   was requested; the rest are enumerated in (c). Effort: S each.
~~2. **dprint verification of this session's markdown edits** (AGENTS.md,~~ done — dprint pinned in the devShell (07-18 pass, 2026-10-19)
   TODO_LIST.md, this report). What works: the repo's own md lints pass.
   What remains: an actual `dprint check` pass — the binary is absent from
   PATH and from the flake devShell, so CI is currently the only executor.
   Blocker: no known pinned local invocation (question g1). Effort: S.

## c) NOT STARTED

~~1. `buildflow -s statix` — W20 posture of the restructured node configs~~ done — green in every gate since (pinned statix; CI 2026-10-22 green)
   (machine node kept a `services = { mail-server ...; stalwart.provision
   ...; }` wrapper; flood node was fully collapsed) is unproven this
   session. Priority: high (CI-adjacent).
~~2. `buildflow -s deadnix` — same surface, unused-args class.~~ done — green in every gate since (07-18 verified its auto-fixes)
~~3. Local runs of `scripts/check-inventory.sh` +~~ done — pre-push + CI run them (green chain through 2026-10-22)
   `scripts/check-check-set-drift.sh` (CI parity; check set is provably
   unchanged, so expected green — but unexecuted).
~~4. CHANGELOG `[Unreleased]` entry for the dedup (blocked on question g2 —~~ done — added 2026-10-23 (docs-health pass)
   doctrine call).
~~5. AGENTS.md line recording the ACCEPTED duplication groups (eval grep~~ done — AGENTS records the common.nix convention (import, never restate); the accepted-clone enumeration stays in this report
   skeletons, cross-file account blocks, cert runCommands) so a future
   session does not relitigate them. Currently the rationale exists only
   in this session's chat.
~~6. CI observation: origin state unobserved; daemon commits are local as~~ done — green chain 2026-10-19 through 2026-10-22 (run 39864876276)
   far as this session saw. First CI run of the refactored tree is
   pending.
~~7. docs-health HARVEST of this report's (f) list (awaiting instruction~~ done (docs-health pass 2026-10-23)
   per this session's brief: report, then wait).

## d) TOTALLY FUCKED UP

1. **Transient python corruption by my own multiedit:** the
   `applyStatus = machine.execute(` prefix was dropped in one edit,
   producing `machine.succeed(...)[0]` nonsense. Caught immediately by
   reading the diff-back; fixed before any build. Severity: would have
   failed the test run. Root cause: editing the interpolation line while
   also changing its content.
2. **demo-vm.nix dangling brace:** removing one nesting level (the
   singletons wrapper) left its closing `};` behind. Caught by the parse
   check; fixed; alejandra normalized indentation. Severity: eval-blocking
   if shipped.
3. **flake8 E501 (80 > 79) in the unified probe** — one nesting level too
   deep; the limit applies AFTER the nix 4-space strip (file lines ≤ 83).
   Cost: one wasted stalwart-e2e run cycle (fails at imap-probe build,
   before the VM). Lesson recorded in AGENTS.md. Mitigation: flatten with
   `continue` guards.
4. **`nix build --rebuild` misuse, twice:** (a) on a never-built
   derivation (refuses: nothing previously built), (b) the "outputs not
   valid" variant after a failed run. Plain `nix build` was correct both
   times. Cost: two short cycles, no VM time wasted.
5. **First full stalwart-e2e run RED at the FINAL subtest:** the flood
   node's still-gated-after-2s probe got a banner. Burst itself exact
   (3 banners + 7 hangups in 0.04 s); immediate rerun GREEN; flood-node
   config proven eval-identical. Classified: one-off runtime flake in the
   limiter refill. Cost: one extra full VM run. Watch row in TODO_LIST
   with the capture-before-rerun rule.

## e) WHAT WE SHOULD IMPROVE

1. **Run the format check after EVERY nix edit, not once per batch.** The
   E501 probe fix landed after the session's only fmt apply; the final
   check happened only because the close-out loop re-ran it. Impact: one
   wasted VM cycle here; potentially a red CI push elsewhere.
2. **Verify formatter availability for a file type BEFORE editing it.**
   dprint turned out to be unavailable locally; the md edits shipped on
   lint-subset + convention-matching alone. Suggested fix: a session
   pre-flight that resolves the pinned invocation (or a devShell addition,
   which is a fleet-level ask).
3. **Capture refactor-identity baselines for ALL affected checks before
   the first edit.** This session baselined the eval checks only and
   recovered the VM-check comparisons via `builtins.getFlake` at the base
   rev — correct but improvised. Make the full-before capture habitual.
4. **Read the error hint before re-issuing command variants** (the
   `--rebuild` double-miss; the hint text explained both failures).

## f) Top next tasks (ranked; honest count 15, not padded to 50)

~~1. Run `buildflow -s statix` on the restructured node configs. Impact:~~ done — green in every gate since
   High. Effort: S. Category: Quality.
~~2. Run `buildflow -s deadnix` on the same surface. Impact: Med. Effort:~~ done — green in every gate since
   S. Category: Quality.
~~3. Run `scripts/check-inventory.sh` plus `scripts/check-check-set-drift.sh`~~ done — pre-push + CI (green chain)
   locally. Impact: High. Effort: S. Category: Quality.
~~4. Establish a pinned local dprint invocation, then check AGENTS.md plus~~ done — devShell pin (07-18 pass)
   TODO_LIST.md plus this report. Impact: High. Effort: S. Category:
   Quality.
~~5. Observe the first CI run over the refactored tree (push state~~ done — green (runs 39190484173/39191414206 through 39864876276)
   currently unobserved). Impact: High. Effort: S. Category: Quality.
~~6. CHANGELOG `[Unreleased]` entry for the dedup (gated on g2). Impact:~~ done — added 2026-10-23
   Med. Effort: S. Category: Documentation.
~~7. AGENTS.md: record the accepted-duplication groups plus rationale.~~ done — convention recorded; enumeration stays in this report
   Impact: Med. Effort: S. Category: Documentation.
~~8. docs-health HARVEST of this report's (f) list. Impact: Med. Effort:~~ done (docs-health pass 2026-10-23)
   S. Category: Documentation.
9. Flood-flake watch: on recurrence, capture journal plus limiter bucket **→ TODO_LIST flood watch row**
   state BEFORE rerun (TODO_LIST row exists). Impact: Low. Effort: S.
   Category: Quality.
10. Decide flood-subtest posture: watch-item vs built-in **→ TODO_LIST flood row (owner taste call, open)**
    retry-with-capture (gated on g3). Impact: Low. Effort: S. Category:
    Quality.
~~11. If a third consumer of the account-provision shape appears, extract~~ **NOT-DO — conditional; accept stands at two consumers.**
    a cross-file `mkUser` (accept stands at two). Impact: Low. Effort: M.
    Category: Cleanup.
~~12. If a fifth eval-contract check appears, consider a shared~~ **NOT-DO — conditional; accept stands at four checks.**
    derivation+grep helper (accept stands at four). Impact: Low. Effort:
    M. Category: Cleanup.
~~13. Fleet ask: add dprint to the devShell pattern (BuildFlow/repo~~ done — shipped 2026-10-19 (devshells.nix pins dprint)
    owners). Impact: Low. Effort: S. Category: Quality.
~~14. AGENTS.md working-rules: extend the `--rebuild` note with the~~ done — AGENTS carries the cache-hit/--rebuild rule; the never-built/failed-output variants stay in this report
    never-built and failed-output variants. Impact: Low. Effort: S.
    Category: Documentation.
~~15. docs-health VERIFY pass over this report's claims when convenient.~~ done (docs-health pass 2026-10-23)
    Impact: Low. Effort: S. Category: Documentation.

## g) Questions I cannot answer myself

~~1. **dprint local invocation:** is there a sanctioned pinned way to run~~ done — answered: pinned in the devShell (2026-10-19)
   `dprint check` outside CI in this repo? Tried: PATH, `nix develop -c
   dprint`, bare `dprint` — all absent. Unwilling to use the registry's
   `nixpkgs#dprint` blindly (version drift vs the CI pin could produce a
   false red/green). Answer unblocks task f4.
~~2. **CHANGELOG doctrine:** do internal test-infrastructure refactors get a~~ done — answered by practice: internal infra refactors DO get entries (guard-tooling batch; the dedup entry added 2026-10-23)
   `[Unreleased]` entry when they land, or only at release-cut time? The
   existing entries are feature/behavior level; this dedup changed no
   module behavior (bit-identity proofs). Answer decides f6 either way.
3. **Flood-subtest posture:** harden now (built-in retry with journal + **→ TODO_LIST flood row (owner call, open)**
   bucket-state capture on the retry path) or keep the TODO watch-item?
   Hardening reduces flake signal noise but adds a second attempt to a
   test whose value is single-shot evidence (M14). Owner taste call.

## Accepted duplication (recorded for future sessions — candidate AGENTS.md row)

- Eval-contract `builtins.derivation` + grep skeletons (dmarc-eval,
  module-import-eval, provision-plan-eval, demo-eval): the grep set IS
  each test's substance; a helper would take more parameters than the
  duplicated lines it saves, in deliberately self-contained proofs.
- Cross-file account-provision blocks (relay-e2e, demo-vm vs
  stalwart-e2e's in-file `mkUser`): different domain refs, passwords, and
  ledger-pinned comments; two consumers do not justify the coupling.
- Cert-generation runCommands (bind-e2e vs parsedmarc-e2e): different
  subjects, SANs, and purposes.
- `system.stateVersion` + node `systemPackages` boilerplate: idiomatic
  per-node config; a module would hide required boilerplate.
- `modules/*.nix` `match = ["name"]` sites: semantically distinct object
  sets with transcript-pinned rationale comments (never consolidate
  ledger comments away).
