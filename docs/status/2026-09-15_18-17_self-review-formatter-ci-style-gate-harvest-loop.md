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

1. **Final gate for the exact end-state tree:** launched 18:16 (the tree
   changed after the 17:59 green: style-only Nix fix + CI/docs). Style-only
   diffs cannot change behavior, but the repo's rule is that green claims
   name the tree they ran on - the verdict lands in this file's addendum /
   the session log, not by inference.
2. **aarch64:** eval-verified and CI-evaluated; the ARM VM run of
   `stalwart-e2e` is still TODO_LIST.
3. **Upstream nixpkgs filings:** diagnosis current vs master; drafts not
   written (filing authorization pending).

## c) NOT STARTED (gated - correctly untouched)

1. Push of either repo (nix-email master 46+ ahead; SystemNix 2 ahead).
2. SystemNix pin advance + relay-assertion restore + guard delete.
3. Upstream issue filing; Junk-filing implementation (ROADMAP Q6);
   v0.1.0 tag/release; MIT confirmation.
4. All D1-gated work (live dmarc validation, migration compare, secret
   rotation + sops-key-audit, VPS/DNS themes).

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

1. Answer §g - it gates 8+ TODO rows by itself.
2. Push both repos once authorized; watch CI's first real run (now with the
   format gate + aarch64 eval step - expect them to be exercised for the
   first time).
3. SystemNix pin advance + relay assertions restore + guard delete + both
   gates (TODO_LIST high-impact).
4. v0.1.0 tag + GitHub release after the push.
5. File the two nixpkgs issues (diagnoses verified vs master 2026-09-15).
6. Junk-filing decision → possible wrapper sieve + GTUBE subtest upgrade.
7. aarch64 `stalwart-e2e` emulated run once.
8. parsedmarc-e2e TLS localMail variant; CSV row-count assertion;
   two-reschedule over-quota assertion (new row).
9. Pin-advance runbook note; CI lockstep audit test; negative-cache 65 s
   cost proof; README runbook SystemNix pointer; stateVersion consolidation;
   pin-discipline note; debug-script fixture template; docs-health ANNOTATE
   pass (all TODO_LIST).
10. Re-render both architecture SVGs together at the next docs touch (e-6).
11. Consider `actionlint` in CI alongside the YAML parse (found nothing
    broken today; would catch expression typos the YAML parse cannot).
12. Consider teaching the auto-commit daemon to run `nix fmt -- . --check`
    (it "formats" by reputation only - that assumption failed d-2).

## g) Questions I cannot figure out myself

1. **Push authorization:** nix-email `master` is 46+ commits ahead of origin,
   SystemNix 2 ahead. Push both? Plain, or split (docs first, then code) so
   CI's first run is readable?
2. **Junk-filing ownership** (ROADMAP open question 6): 0.15.5 tags
   `X-Spam-Status` but never files to Junk. (a) this wrapper ships a
   declarative sieve (GTUBE subtest then asserts real Junk filing),
   (b) SystemNix owns the sieve, or (c) tag-only is the documented end state?
3. **MIT confirmed?** LICENSE shipped MIT under the earlier mandate; one
   word flips the TODO_LIST row to done (or names the license you want).

---

**Gate addendum (18:16 run):** `nix flake check` on the exact end-state tree
(style fix + CI steps + docs) → `FLAKECHECK_EXIT:0`, "all checks passed!",
unmasked (redirected log, exit echoed into the file).

**Then per the skill: WAITING FOR INSTRUCTIONS.**
