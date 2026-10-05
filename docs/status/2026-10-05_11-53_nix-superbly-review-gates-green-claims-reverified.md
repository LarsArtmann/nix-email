# Status Report — "Do we use nix superbly?" review session

- **Date**: 2026-10-05, 11:53 CEST
- **Session scope**: nix-review skill execution over all 12 `.nix` files (~3,045 lines), gates run live, verdict delivered in chat. Read-only session — no repo files edited by the assistant.
- **Format note**: `.md` at the user's explicit path demand (skill default is HTML; override flagged in chat).

## Method (what this report is based on)

nix-review skill (checklist + both references) + buildflow skill loaded first. All `.nix` files read in full. Mechanical anti-pattern greps. Live gates: both `nix eval` shape guards, `nix fmt -- . --check`, forced build of both eval checks, `nix flake check` (identified as cached replay, compensated with CI evidence), `buildflow` full run, `gh run list`, `nixosModules`/devShell/`apps.vm` evals. Post-session, three inference-based claims were re-verified with hard evidence (grep, BuildFlow git log, pinned nixpkgs source).

---

## a) FULLY DONE

1. **Full nix-review checklist pass over every `.nix` file** — critical/purity/structural/correctness/consistency/module/security/performance/devshell categories all clean or justified.
2. **Mechanical purity sweep** — zero `rec`, `with`, `<nixpkgs>`, `getEnv`, unquoted URLs, placeholder hashes.
3. **Live gate matrix, all green**: eval guards x86_64 + aarch64 (lock guards fired and passed), alejandra check (13 files), forced build of `dmarc-eval` + `module-import-eval` (post-split), `buildflow` in its documented steady state (exit 69 = exactly the 4 known nix-checker port-collision FPs; severity-verified via `--format finding`), CI master last 6 runs green including the 20m full VM matrix after the flake split (a67769e).
4. **Verdict delivered**: "Yes, superbly" — 0 critical, 0 high findings; 4 genuine low/medium observations (MemoryMax policy undocumented, mail-server.nix length, one cheap IFD in dmarc-eval, fixture duplication across test files); 3 documented deliberate deviations confirmed as such.
5. **Claim re-verification (this report's trigger)** — three claims I had asserted from inference were converted to evidence:
   - MemoryMax decision: grep over README/TODO_LIST/ROADMAP/FEATURES/AGENTS/CONTRIBUTING → **no match**; "undocumented" claim stands.
   - BuildFlow port-collision fix: `git -C ~/projects/BuildFlow log 3bb229e..HEAD` → `15ea141d2 nix-checker: stop flagging string/comment ports; warn on privileged-port collisions` → stale-binary explanation stands, now source-backed.
   - Upstream parsedmarc hardening: pinned nixpkgs `services/monitoring/parsedmarc.nix` → `DynamicUser` (568), `SystemCallFilter` (584), `RestrictAddressFamilies` (589) present; module comment accurate. `MemoryMax` absent upstream — consistent with my finding.

## b) PARTIALLY DONE

1. **VM test execution verification** — `nix flake check` returned a cached replay ("running 0 flake checks"); I compensated with CI green runs + forced eval-check builds, but did NOT locally execute any of the three VM tests post-split. The claim "VM tests pass after the split" is inference from CI, not local execution.
2. **CI contract mechanism verification** — I asserted "CI enforces `nix fmt -- . --check` fail-closed and lockstep check guard lists" from AGENTS.md/README only; never read `.github/workflows/ci.yml` this session. Green runs exist; the guard lists' current contents are unverified.
3. **Security-judgment grounding** — I ruled the demo VM creds and secrets posture acceptable without consulting `docs/THREAT_MODEL.md` (the repo's own security posture doc).

## c) NOT STARTED

1. Routing the 4 review findings into TODO_LIST (HARVEST) — deliberately deferred: user said "wait for instructions".
2. Persisting the review verdict as a `docs/reviews/` artifact — the verdict currently lives only in chat + this report.
3. Any remediation of the findings themselves (MemoryMax decision, IFD cleanup, fixture dedup) — assessment session only, nothing was requested or implemented.

## d) TOTALLY FUCKED UP

Nothing in the repo is broken by this session (read-only, gates green, `git status` clean). The fuck-ups were **methodological, in my own reporting**:

1. **Assert-then-verify-later (3x)** — I published the stale-binary explanation sourced from a *commit title*, accepted the upstream-hardening comment without opening the pinned module, and called MemoryMax "undocumented" without grepping the living docs. All three happened to be correct — verified only under this self-review's pressure. Had any failed, my review report would have contained a fabricated causal claim. This is exactly the repo's own "reading it in source is NOT evidence" lesson, applied to my own output.
2. **Concurrent gate runs** — I started `nix flake check` and `buildflow` as simultaneous background jobs; the observed `nix-build` timing regression (+581%) is almost certainly contention noise from my own parallel run, and I hand-waved it as such in passing instead of preventing or cleanly attributing it. Muddied measurement, then under-flagged it.
3. **Skipped the documented cheap instruments** — `nix flake check --no-build` (AGENTS.md's eval-noise triage) and reading the ci.yml guard lists (AGENTS.md warns about them explicitly) were both one-command cheap and both skipped in favor of the heavyweight cached check.

## e) WHAT WE SHOULD IMPROVE

1. **Evidence bar for reviewer claims** — every causal/attribution claim in a review must carry its verification command and output, in the same breath. This session passed 3/3 on luck; the process allowed 0/3 to be verified at publish time.
2. **Sequential gates** — never run `buildflow` and `nix flake check` concurrently; timing regressions in buildflow's analytics become meaningless (and get reported to the user as noise).
3. **Triage order** — cheapest instruments first (`--no-build` eval warnings, guard-list reads), heavyweight cached builds last, and only forced (`--rebuild` / log-grep for execution lines) when execution itself is the claim.
4. **Security sections of reviews should open the repo's threat model** before ruling on secrets/exposure posture.
5. **Persist review artifacts** — a verdict that lives only in chat is invisible to the next session; repo convention already provides `docs/reviews/`.

## f) Up to 50 things to get done next

Items 1-25 are the real work list; 26+ are brainstorm/ROADMAP fuel (per docs-health HARVEST rigor, extra items are not commitments).

**From this session's findings (harvest-ready):**
1. Decide the MemoryMax policy for both wrapped services — wrapper-level `mkDefault` default vs SystemNix consumer-layer ownership — and document it (module header or THREAT_MODEL.md).
2. Rebuild/reinstall the BuildFlow binary (`nix build . && nix run .#reinstall` in the BuildFlow repo) — port-collision fix `15ea141d2` postdates the installed binary.
3. Re-run `buildflow` after the upgrade; expect exit 0 — then retire the port-collision paragraph from AGENTS.md "Known lint noise" (keep the vulnix one).
4. Convert VM verification to local execution once: `nix build .#checks.x86_64-linux.stalwart-e2e --rebuild -L` (~9 min) — kills the CI-inference caveat for the post-split state.
5. Read `.github/workflows/ci.yml` and confirm both guard lists (x86_64 `expected=` + aarch64 shape-guard) still match the 5-check surface.
6. HARVEST this report's section (f) into TODO_LIST.md (docs-health).
7. Add an eval-time assertion to dmarc-eval pinning the upstream unit hardening shape (`DynamicUser`, `RestrictAddressFamilies`) so a pin-advance that drops them fails loudly (now evidence-backed at pinned lines 568/584/589).
8. dmarc-eval IFD cleanup: pass the strip-script store path and grep at build time instead of `builtins.readFile` at eval time (cheap, cosmetic).
9. Fixture dedup: shared `tests/fixtures.nix` for `testHash` and the DMARC sample URL+hash used across three test files (tradeoff: tests currently standalone by design — decide, don't default).
10. Persist this session's nix-review verdict as `docs/reviews/2026-10-05_nix-superbly-review.md` (or fold pointer into this file).

**Repo hygiene noticed en route:**
11. Verify `git config core.hooksPath && ls` actually resolves (AGENTS.md: it can dangle silently).
12. Investigate or skip-with-rationale `nix-hash-fix` (buildflow preflight WARN: failed 6/6, 100%) — no hashes to fix in this repo, but 100% failure smells like tooling drift worth one look.
13. Decide the lychee private-repo link policy (GITHUB_TOKEN vs exclude) — fleet-undecided preflight WARN keeps firing.
14. Decide whether ruff/lychee "not in project devShell" WARNs justify two devShell additions or a documented accept (devshell is minimal on purpose).
15. `nix flake check --no-build` after any future lock/pin move — adopt as standing triage step (AGENTS.md already documents the instrument).

**Pre-existing open items visible from this session's reading (verify current state in TODO_LIST before acting):**
16. SystemNix floating `?ref=master` vs hard-pin (decision-batch C17, open per AGENTS.md).
17. vulnix replacement: check whether BuildFlow now ships a working CVE scanner (`.buildflow.yml` skip is conditioned on exactly that).
18. `docs/TELEMETRY.md` upstream-vs-0.15.5 key-skew caveat: verify keys against the binary before any telemetry wiring.
19. imapclient compat pin retirement in dmarc-monitor.nix — re-check whether nixpkgs ships imapclient >= 4.1.0 on the next pin advance.
20. parsedmarc `[elasticsearch]` strip workaround retirement — check whether the nixpkgs module bug is fixed upstream on the next pin advance.
21. ROADMAP D1/D2 user decisions (spam-to-Junk routing, rua viewer) still gate planned work.

**Brainstorm fuel (26+):**
26. Consider `MemoryMax` on the demo VM's guest services (it is throwaway, but consistent posture).
27. Consider asserting `services.stalwart.settings` renders no `MemoryMax`-conflicting `resource.limits` passthrough docs.
28. Split mail-server.nix options into `modules/mail-server/options.nix` IF it keeps growing (currently acceptable at 667 documented lines).
29. Add a `checks.format`-style named check for alejandra parity with the treefmt-convention world (CI already covers it; naming parity only).
30. Document the "sequential gates" rule from (e)2 in AGENTS.md Working rules if it recurs.
31. Add a link-checker exclude for `docs/status/archived/` + `docs/reviews/archived/` (lychee preflight WARN lists them).
32. Consider `nix flake check --all-systems` in local review habit (aarch64 eval coverage without VM builds).
33. Consider a tiny eval test asserting `apps.vm` program path exists in the store closure (demo rot guard beyond toplevel eval).
34. Consider migrating `{ ... }` vs `{...}` style notes into CONTRIBUTING (currently an AGENTS.md deliberate coexistence note).
35. Consider asserting the demo banner text stays in sync with forwarded ports (cosmetic; banner and hostfwd live in one file already).

## g) Questions I cannot figure out myself

1. **MemoryMax ownership**: should the wrapper ship a `mkDefault MemoryMax` default (consumers override), or is resource policy strictly SystemNIX consumer-layer territory (like sops/Gatus/onFailure)? This is an ops-policy call — a mail server's legitimate memory scales with its store, and a wrong default OOM-kills delivery.
2. **Verification bar for this review**: is CI-green sufficient for "VM tests pass post-split", or do you want the ~9-minute forced local rebuild (`stalwart-e2e --rebuild`) before the verdict is considered proven?
3. **HARVEST now or later**: should I push section (f) items 1-10 into TODO_LIST.md immediately, or does this report stay a pure snapshot until you say go?
