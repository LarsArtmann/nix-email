# Self-review pass: what the 17:59 report missed (formatter, CI style gate, harvest loop), gate re-verified

**Date:** 2026-09-15, 18:00 → 18:17 CEST (report written 18:17)
**Directive:** "What did you forget? What could you have done better? What could you still improve?" + full a–g status report.
**Scope:** this session's entire run (17:10 → 18:17), with the emphasis on the
critique the 17:59 report did NOT contain. Everything here was found by
re-examining my own work this session - no new scope was opened.
**Format note:** you asked for `.md` at `docs/status/` - this overrides both
the status-report and brutal-self-review skills' HTML-canonical outputs; the
override is deliberate and not propagated into either skill.

## Headline

The self-review found four things the 17:59 report was too generous about:
the repo formatter was NEVER run on my edits (one file carried real drift),
`nix fmt` has been broken-as-invoked since 0.1.0 shipped it (alejandra 4.0.0
stdin trap), CI enforced parsing but not FORMATTING (a real gate hole, now
closed with a fail-closed step), and my own 17:59 §f left three items
unrouted - the exact entombment the docs-health contract forbids. All four
are fixed in-tree and re-verified. A final full gate for the exact end-state
tree was launched at 18:16; verdict recorded below.

---

## a) FULLY DONE (18:00 → 18:17 pass; session recap where marked)

1. **Formatting drift found and fixed.** `alejandra --check` flagged
   `tests/parsedmarc-e2e.nix` (the `(sendEmail)` paren slip, predating this
   session but sitting in a file I edited). Formatted; `nix fmt -- . --check`
   now exits 0 across all 7 files.
2. **`nix fmt` invocation trap root-caused and documented.** Bare `nix fmt`
   forwards no paths, so alejandra 4.0.0 reads STDIN and dies with
   `unexpected end of file` - the "nix fmt support" shipped in 0.1.0 never
   worked as invoked. Correct invocation (`nix fmt .`, check-mode
   `nix fmt -- . --check`) added to AGENTS Commands.
3. **CI style gate added (fail-closed).** `.github/workflows/ci.yml` now
   runs `nix fmt -- . --check` after the parse step - unformatted Nix can no
   longer ship green. Both my CI edits (aarch64 eval step at 17:35, format
   step at 18:15) are YAML-validated (8 steps parse cleanly).
4. **The 17:59 §f harvest loop closed.** Its unrouted items are now routed:
   the transcript-first rule is in CONTRIBUTING (§f-12), the
   two-reschedule over-quota assertion is a TODO_LIST row (§f-14), the
   CI/aarch64 pairing note is recorded in the 17:59 report and needs no row.
5. **Session recap (verified earlier this session, still true):** §f harvest
   executed (TODO_LIST 15 rows / ROADMAP +7 / CHANGELOG + FEATURES synced),
   parsedmarc-e2e elasticsearch-absence + 120 s bound, dmarc-eval
   ExecStartPre order guards, aarch64 dmarc-eval BUILT green (first ever),
   SystemNix contract test hardened to the literal reports dir, SVG
   re-render, THREAT_MODEL catch-all row, ledger +4 (line cites, `:225`
   fix, upstream-status-vs-master for both nixpkgs bugs), full gate GREEN at
   17:59 (`FLAKECHECK_EXIT:0`) after the transcript fix
   (`Message rescheduled for delivery`).

## b) PARTIALLY DONE

1. ~~**Final gate for the exact end-state tree:** launched 18:16 (the tree~~ done (verdict in the file's own gate addendum: FLAKECHECK_EXIT:0)
   ~~changed after the 17:59 green: style-only Nix fix + CI/docs). Style-only~~
   ~~diffs cannot change behavior, but the repo's rule is that green claims~~
   ~~name the tree they ran on - the verdict lands in this file's addendum /~~
   ~~the session log, not by inference.~~
2. ~~**aarch64:** eval-verified and CI-evaluated; the ARM VM run of~~ done (posture decided (documented-manual))
   ~~`stalwart-e2e` is still TODO_LIST.~~
3. ~~**Upstream nixpkgs filings:** diagnosis current vs master; drafts not~~ done (filed 2026-09-15 (#563651, #563652))
   ~~written (filing authorization pending).~~

## c) NOT STARTED (gated - correctly untouched)

1. ~~Push of either repo (nix-email master 46+ ahead; SystemNix 2 ahead).~~ done (pushed 2026-09-15)
2. ~~SystemNix pin advance + relay-assertion restore + guard delete.~~ done (pin advanced to v0.2.0)
3. ~~Upstream issue filing; Junk-filing implementation (ROADMAP Q6);~~ done (filed + MIT confirmed + Q6 re-posed)
   ~~v0.1.0 tag/release; MIT confirmation.~~
4. ~~All D1-gated work (live dmarc validation, migration compare, secret~~ **Won't implement — D1-gated block - stays in ROADMAP/TODO_LIST.**
   ~~rotation + sops-key-audit, VPS/DNS themes).~~

## d) TOTALLY FUCKED UP (all NEW - the 17:59 §d stands, this adds to it)

1. **I demanded routing discipline and then violated it in the same report.**
   The 17:59 report's §f-12/13/14 were left unrouted while §f-1..11 pointed
   at TODO_LIST - exactly the "entombed in a timestamped file" anti-pattern
   docs-health forbids and I had just spent an hour enforcing. Fixed this
   pass; the lesson is that §f routing is part of WRITING the report, not a
   follow-up someone might do.
2. **Never ran the repo formatter on my own edits.** I edited three `.nix`
   files and the gate + CI never check style, so nobody would have caught
   drift - `alejandra --check` found one file non-compliant. My "quality
   gates" checklist had lint/format in it and I skipped it because "the
   daemon formats" (it does not - that assumption was untested and wrong).
3. **A shipped feature that never worked went unnoticed for a day:**
   `nix fmt` (bare) has exited 1 with `unexpected end of file` since alejandra
   4.0.0 landed - the CHANGELOG's "nix fmt support + one full formatting
   pass" claim from 0.1.0 cannot have used the bare invocation that
   everyone would naturally type. I used the repo for hours before trying
   it once.
4. **CI gate hole I walked past:** the workflow's "Parse all Nix files" step
   lulls - parsing is not formatting, and nothing enforced style. Found only
   because of (2). Now a fail-closed step.
5. **The 17:59 report overstated one item:** §a-5 said "CI gained a
   fail-closed step" before any YAML validation had run (validated 25 min
   later). Small, but it is the docs-lead-the-gate failure mode again, in a
   report whose §d-2 was literally about that.
6. **Minor:** one accidental no-op MCP tool call mid-session (read_mcp_resource
   with a placeholder URI) - harmless noise, but sloppy tool discipline.

## e) WHAT WE SHOULD IMPROVE

1. **§f routing is part of the report,** not a TODO (d-1). The docs-health
   HARVEST contract applies to my own reports with the same force as to
   prior sessions'.
2. **Run `nix fmt -- . --check` at the end of every session that touches
   `.nix`** - now CI-enforced, but local habit beats CI latency.
3. **Validate workflow YAML the moment it is edited** (one python -c yaml
   line; done for both edits this pass).
4. **Verify shipped tool claims by using them** (d-3): any documented
   command should be executed at least once per session that touches its
   area.
5. **Narrow-first gate pattern is now in AGENTS** (build the changed check,
   then the full gate) - this session paid ~9 minutes for ignoring it.
6. **The improved-architecture SVG carries a latent trap:** its geometry
   differs from a fresh render of its own source (content is identical,
   layout is not). Next docs touch should re-render BOTH diagrams together
   so the next person does not inherit a mystery diff.

## f) Up to 50 things we should get done next

Already routed this session - `TODO_LIST.md` (16 rows) and `ROADMAP.md` are
current; do not re-harvest. The concrete short list:

1. ~~Answer §g - it gates 8+ TODO rows by itself.~~ done (answers received + executed (file addendum))
2. ~~Push both repos once authorized; watch CI's first real run (now with the~~ done (pushed; CI green after the SHA + aarch64 fixes (in-file addendum))
   ~~format gate + aarch64 eval step - expect them to be exercised for the~~
   ~~first time).~~
3. ~~SystemNix pin advance + relay assertions restore + guard delete + both~~ done (done (pin v0.2.0))
   ~~gates (TODO_LIST high-impact).~~
4. ~~v0.1.0 tag + GitHub release after the push.~~ done (cut + released (v0.1.0 retroactive, v0.2.0))
5. ~~File the two nixpkgs issues (diagnoses verified vs master 2026-09-15).~~ done (filed (both))
6. ~~Junk-filing decision → possible wrapper sieve + GTUBE subtest upgrade.~~ **Won't implement — re-posed - wrapper-owned impossible (sieve wall); ROADMAP Q6.**
7. ~~aarch64 `stalwart-e2e` emulated run once.~~ done (attempted; documented-manual)
8. ~~parsedmarc-e2e TLS localMail variant; CSV row-count assertion;~~ done (TLS node + row-count + two-reschedule all shipped)
   ~~two-reschedule over-quota assertion (new row).~~
9. ~~Pin-advance runbook note; CI lockstep audit test; negative-cache 65 s~~ done (all shipped (runbook, lockstep, 65s proof, pointer, fixture); ANNOTATE = the 2026-09-16 pass)
   ~~cost proof; README runbook SystemNix pointer; stateVersion consolidation;~~
   ~~pin-discipline note; debug-script fixture template; docs-health ANNOTATE~~
   ~~pass (all TODO_LIST).~~
10. ~~Re-render both architecture SVGs together at the next docs touch (e-6).~~ **Won't implement — SVGs content-verified current 2026-09-16 (the 09-16 rewrap was text-neutral).**
11. Consider `actionlint` in CI alongside the YAML parse (found nothing
    broken today; would catch expression typos the YAML parse cannot).
    _(routed: TODO_LIST low row - still open)_
12. ~~Consider teaching the auto-commit daemon to run `nix fmt -- . --check`~~ **Won't implement — user-level daemon config, outside repo scope.**
    ~~(it "formats" by reputation only - that assumption failed d-2).~~

## g) Questions I cannot figure out myself

1. ~~**Push authorization:** nix-email `master` is 46+ commits ahead of origin,~~ done (both plain - executed)
   ~~SystemNix 2 ahead. Push both? Plain, or split (docs first, then code) so~~
   ~~CI's first run is readable?~~
2. **Junk-filing ownership** (ROADMAP open question 6): 0.15.5 tags
   `X-Spam-Status` but never files to Junk. (a) this wrapper ships a
   declarative sieve (GTUBE subtest then asserts real Junk filing),
   (b) SystemNix owns the sieve, or (c) tag-only is the documented end state?
3. ~~**MIT confirmed?** LICENSE shipped MIT under the earlier mandate; one~~ done (MIT CONFIRMED 2026-09-15)
   ~~word flips the TODO_LIST row to done (or names the license you want).~~

---

**Gate addendum (18:16 run):** `nix flake check` on the exact end-state tree
(style fix + CI steps + docs) → `FLAKECHECK_EXIT:0`, "all checks passed!",
unmasked (redirected log, exit echoed into the file).

**Then per the skill: WAITING FOR INSTRUCTIONS.**

---

## Post-report addendum (18:20 → 19:20, answers received and executed)

§g was answered: **push = "both, plain"** (executed), **MIT = NOT confirmed**
(TODO_LIST/ROADMAP updated; the actual license choice is still open), and
**Junk filing** came back as a question ("in nix-email or not?") - answered
in the session close-out: recommendation is wrapper-owned in nix-email
(option a), awaiting the final word.

Execution after the answers, in order:

1. **Both repos pushed** (nix-email `1f8bb52..6efff9d`, SystemNix
   `ad6edcbb..ee85f1ff`), after the daemon committed the answer-driven doc
   updates.
2. **First-ever nix-email CI run failed at Set up job:** all three pinned
   action SHAs in `ci.yml` were WRONG (checkout was one digit off the real
   v4.2.2 SHA `11bd71...` vs the pinned `11bd19...`) - written from memory in
   a prior session and never validated because the repo was never pushed.
   The identifier-from-memory failure mode, now in `uses:` lines. Repinned
   from the real tag refs (commit `c6aa0fa`).
3. **Second run failed on MY aarch64 step:** forcing the aarch64 check's
   outPath builds its strip script - "platform mismatch" on the x86_64
   runner. The step only worked locally because this host HAS emulation:
   "works on my machine" was literally emulation-dependent. Step made
   shape-only (`attrNames`, genuinely arch-independent), deep build stays a
   locally-verified fact (commit `b80137f`).
4. **Third run: GREEN** - `Enforce alejandra formatting`, expected-checks
   guard, aarch64 shape guard, and the full `nix flake check` (VM tests
   included) all success on GitHub runners (run 34999737899). The daemon
   had a commit blind spot during this window; per the buildflow skill's
   guidance the two CI fixes were committed explicitly (narrow, single-file
   commits) and pushed within the push authorization.
5. **SystemNix CI failed too - PRE-EXISTING, not this session's change:**
   runs at 15:53 and 16:19 (before any of today's pushes) failed the same
   way. Root cause identified: `flake.nix:448` pins
   `git+file:///home/lars/projects/branching-flow` - a local-path input that
   can never resolve on CI ("Secret history scan" also failing, unchecked).
   Fixing that is SystemNix-territory work (the nix-private-go-repos
   prepared-source pattern), deliberately not started here.

---

## Resolution addendum (2026-09-16, docs-health pass)

All items resolved inline except g/2 (spam→Junk - ROADMAP Q6) and f/11
(actionlint - TODO_LIST low row, still open). Archived.
