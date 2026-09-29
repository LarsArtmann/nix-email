# Status 2026-09-16 18:41 — docs-health pass 2: seven reports annotated+archived, living docs rebuilt, one false count owned

Session 9. Directive: re-run the docs-health SKILL over ALL `2026-0*`
files ("PROPERLY... Archive FULLY done and UPDATED (inline strikethrough)
.md files"). Scope: THIS session only (~18:05→18:45 CEST). Prior sessions
are covered by the archived 08:03→18:03 reports.

**State at yield**: tree clean, `buildflow` EXIT:0 (`nix-flake-check ✔
15.5s`, `nix-build ✔ 28.8s`), master = daemon commits (5 ahead of origin,
unpushed — user-gated). PR #1 confirmed MERGED (16:08 UTC). CI on HEAD
(`0de8b3d`) success.

---

## a) FULLY DONE (each verified against the tree this session)

1. **Skill + 6 references loaded before acting** (SKILL.md, doc-ownership,
   harvest-guide, verify-checklist, health-report-format, resolving-items,
   annotation-placement).
2. **All seven active 2026-09-16 reports read in full** + living docs +
   house-style study of the archived 02-08/07-04 annotations before any
   edit. Archived tree completeness re-verified (`grep -rLn '~~'` → empty).
3. **Fresh evidence before every verdict**: PR #1 state via `gh` (MERGED),
   CI run states, `rg` for the missing `.data.errors` assertion (exit 1 →
   genuinely absent), `rg` for dmarc-eval offline/optionsDoc assertions
   (present, exact lines), AGENTS fmt rule on disk, renovate.json
   re-read (github-actions still enabled → inside the Renovate decision),
   README devShell coverage (absent → gap confirmed), commit archaeology
   (`git show --stat` over 11 daemon commits to map DKIM fix → `891fa44`,
   sweep → `2b7257e`, fmt → `24def0e`, AGENTS rule → `fae9e81`).
4. **All 7 reports annotated inline** — every numbered item in §b/§c/§f/§g
   got a verdict: done (commit/evidence), Won't implement (reason),
   NOT-DO/DUPLICATE, or `_(routed: …)_` open marker. 369 strikethrough
   lines total (08-03: 126, 08-08: 31, 08-16: 39, 12-54: 48, 15-21: 31,
   16-33: 32, 18-03: 62); per-file Resolution addenda appended; §a
   done-tables left intact as records (house precedent from the 08:08
   pass). One new trap fixed en route: `12-54` g/1's GH013 URL briefly
   dropped from its strikethrough → restored (strike the ENTIRE original,
   never replace); 08-16's snapshot line likewise restored.
5. **All 7 reports ARCHIVED** via `git mv` to `docs/status/archived/`;
   `docs/status/` now holds only `archived/`; completeness gate green
   (every archived .md carries strikethroughs).
6. **TODO_LIST rebuilt from the harvest** — 17 open rows, every row
   evidence-cited: High (release 0.3.0, UNBLOCKED by the PR #1 merge),
   Medium (filings watch with #663 re-checked OPEN; reload
   `.data.errors` assertion; pre-push fmt hook), a new 3-row Low hygiene
   tier (dovecot2.protocols warning, formatter `{...}` mystery, SVG
   re-render + 36-label re-diff), 3 D1-gated, 7 user-blocked (SystemNix
   row extended with worktree cache hygiene; new branch-protection policy
   row).
7. **FEATURES.md `dmarc-eval` row** now carries the offline +
   `nixosOptionsDoc` assertions (the 18-03 report's own §b/3 miss).
8. **README**: new "Development" section (devShell contract, gate
   hierarchy buildflow vs `nix flake check` vs fmt-check, no-pipes rule);
   #563652 ledger entry extended with dotlambda's conditional-accept and
   the open mjs/imapclient#663 PR (state re-verified via `gh`).
9. **ROADMAP**: §5 pruned of shipped items (CI, formatter, upstream
   filings, aarch64 decision — all done elsewhere); reload-smoke ops idea
   added to §4; treefmt-vs-alejandra tradeoff + aarch64 `--all-systems`
   residue added to §5.
10. **AGENTS.md deadnix wording fixed** — "deadnix --fix re-removes it"
    (flag does not exist, flagged by 08-03 §b/5) → report-only default +
    BuildFlow auto-fix; my first rewrite claimed a specific `-e` flag
    without verification and was softened in a follow-up edit before
    yielding.
11. **CHANGELOG [Unreleased]** extended with the full pass entry.
12. **Gate**: `buildflow` → EXIT:0, log-redirected (no pipes). Warnings
    are exactly the documented non-fixes + expired GH013 URLs in two
    archived snapshots (link-rot in historical files, left deliberately).
13. **Inline health report delivered** (post-fix Accuracy 9.75 / Fitness
    10, visible math).

## b) PARTIALLY DONE

~~1. **TELEMETRY.md + CONTRIBUTING.md freshness** — light pass only~~ routed - TODO_LIST docs-freshness-audits row (added 2026-09-29; TELEMETRY core keys were source-verified 2026-09-22, webhooks/alert-objects + the CONTRIBUTING per-claim pass remain)
   (structure, provenance caveat, d2 regen command, AGENTS pointers
   verified). Not a per-claim audit of every link/number in either file.
~~2. **SVG currency** — 08-08 §f/14 said "re-render at the next docs~~ routed - ROADMAP §5 arch-diagram content-freshness audit (covers render + content on the next diagram session)
   touch"; this WAS a docs touch and I routed it to a TODO row instead
   (render churn mid-docs-pass felt wrong; tradeoff stated, not hidden).
3. **§a done-tables unverified as records** — I trusted each report's
   own verification claims plus later-session corroboration, per the
   established house pattern; not a fresh re-verification of all ~60
   table rows.
~~4. **Health-report presentation** — I folded fixed findings into the~~ done(superseded) - the skill's math-discipline rules (visible substitution, count-first) now govern the format
   per-doc table as "(n fixed)" notes instead of strict before/after
   tables; the math stayed honest but the format was a compromise.
5. **Commit hygiene** — everything landed via 5 daemon heuristic commits;
   no explicit per-task commits (no commit authorization this session —
   defensible, but history readability paid).

## c) NOT STARTED (correctly parked; canonical list = TODO_LIST)

- Release 0.3.0 cut (unblocked tonight by the PR #1 merge).
- Reload-precondition jq assertion; pre-push fmt hook; the 3 hygiene rows.
- All user-gated rows: SystemNix push (~47+ commits + CI debt + cache
  sweep), Renovate install-or-drop, mailsuite file-or-skip, Resend SASL
  smoke, Discussions, branch-protection policy, D1/D2/Q6 verdicts.
- Push of this session's 5 unpushed daemon commits.

## d) TOTALLY FUCKED UP

1. **A FALSE COUNT — the exact documented sin — in a session that
   ANNOTATED the report documenting it.** I wrote "14 open rows" for
   TODO_LIST in four places (CHANGELOG + two archived annotations + the
   health report context); the grep-verified truth is **17** (21
   status-emoji rows − 4 legend rows; 1+3+3+3+7). Root cause: I derived
   the number from memory of the file structure instead of `grep -c`
   first. Caught by the user's own report prompt (count-first reflex
   while drafting this report) and fixed in all four locations the same
   hour; residue grep now exits 1 (zero matches). 08-08 §d/1 describes
   this failure byte-for-byte and I re-performed it anyway.
2. **Two failed edits from trusting eyes over bytes** — I doubled the
   table pipes in 08-08 (misread the view tool's `NNN|` line-number
   prefix as literal content) and wrote `\|` for a plain `|` in 18-03.
   The repo rule ("extract identifiers mechanically, never from memory")
   exists for exactly this; I paid two round trips before switching to
   `sed -n` + `cat -A` first.
3. **Two content-dropping near-misses in historical files** — one edit
   replaced the 08-16 snapshot line with my addendum; another dropped the
   GH013 URL from 12-54's strikethrough. Both caught on self-review and
   restored within one edit; but the failure class is "new content for
   old anchor" — the same root cause 08-08 §d/2 documents for the
   FEATURES row deletion.
4. **Unverified flag claim written into AGENTS.md** — my deadnix fix
   first cited BuildFlow's `-e` mode from inference; repo law is never
   document tool behavior unverified. Softened before yielding; still an
   unnecessary round trip if I had followed the rule the first time.
5. **One whitespace-equivalent edit accepted without immediate re-read**
   (FEATURES dmarc-eval row); verified only in the final sweep. Should
   have re-read the row before moving on.

## e) WHAT WE SHOULD IMPROVE

1. **Count-first, every time, no exceptions** — `grep -c` before any
   number leaves the session, including numbers about files I wrote
   myself minutes earlier. The 17-rows error was three seconds of grep
   against zero seconds of memory-recall that was wrong.
2. **`sed -n`/`cat -A` the exact bytes before ANY edit into table-heavy
   or historical files** — and when sourcing `old_string` from view-tool
   output, strip the `NNN|` prefix programmatically (the `||` doubling
   trap is now a known failure mode).
3. **Annotate edits should be pure markers-on-original**: `new_string`
   = `old_string` + `~~` + verdict, nothing else added, nothing
   dropped. Mechanically checkable after each edit (diff the
   non-marker text).
4. **Link-rot policy for archived docs** — expired secret-unblock URLs
   now 404 inside two archived snapshots and trip the link-checker as
   warnings; decide: allowlist `docs/**/archived/**` in the link checker,
   or accept the noise as historical truth (current state).
5. **Fixed-findings health reports deserve before/after tables**, not
   inline "(n fixed)" notes — cleaner math, harder to fudge.
6. **SVG re-render should ride the next intentional docs/diagram touch**
   (decide which: parked TODO row vs part of a diagram-touch checklist).

## f) Up to 50 things to get done next

_The canonical open list is TODO_LIST.md (17 rows, verified tonight).
Session-specific additions/observations below; do not double-harvest._

**Immediate self-serve (verified-needed)**

~~1. Release 0.3.0: CHANGELOG cut, tag `v0.3.0`, notes with lock~~ done - v0.3.0 AND v0.3.1 tagged 2026-09-17 (v0.4.0 since)
   rev/narHash — gate CLEARED tonight (PR #1 merged).
~~2. `stalwart-e2e`: direct `jq -e '.data.errors | length == 0'` on the~~ done - the `.data.errors` precondition assertion (16_19-16 a/1)
   reload response (TODO_LIST Medium row).
~~3. Git pre-push hook running `nix fmt -- . --check`~~ done - `.githooks/pre-push` fmt check + CONTRIBUTING section (16_19-16 a/2)
   (repo-shipped + `core.hooksPath` + CONTRIBUTING note).
~~4. Push this repo's 5 unpushed daemon commits (docs-only + renames).~~ done - pushed long since; master in sync with origin (verified 2026-09-29)
~~5. SVG re-render (`d2 --layout=elk`) + full 36-label d2↔SVG re-diff.~~ done - both SVGs re-rendered + label-diffed (16_19-16 a/5)
~~6. Investigate the nixpkgs `dovecot2.protocols` rename warning in our~~ done - root-caused: nixpkgs-internal noise (16_19-16 a/3)
   check evals (ours or noise?).
~~7. Root-cause the `{ ... }`→`{...}` formatter mystery in `tests/*.nix`.~~ done - manual edit in ba7645c, no formatter involved (16_19-16 a/4)

**User decisions (minutes each)**
~~8. Branch protection: keep the "Bypassed rule violations" daemon bypass~~ still open - decision-batch C18
or go strict (TODO_LIST policy row).
~~9. Renovate: install the app or drop `renovate.json` (it never ran;~~ still open - decision-batch C19
its actions scope duplicates Dependabot).
~~10. mailsuite auto-STARTTLS issue: file the staged draft or skip~~ still open - decision-batch C20
(all 5 verify-before-filing gates passed).
~~11. D1 (Workspace fork / rua mailbox) — gates the D1 rows + ROADMAP spine.~~ still open - decision-batch D1
~~12. D2 (VPS placement/budget).~~ still open - decision-batch D2
~~13. Q6 junk-filing verdict (c+d recommended; FR row pre-staged).~~ still open - decision-batch Q6
~~14. GitHub Discussions vs issues-only.~~ still open - decision-batch C22
~~15. Resend account/API key → unblocks the SASL smoke.~~ still open - TODO_LIST blocked row (SASL smoke)

**SystemNix side (one TODO_LIST row)**
~~16. Push ~47+ commits; 17. Clear CI debt (statix sweep, `syn_` policy,~~ still open - TODO_LIST blocked rows (C17 set)
2 pin flips, gitleaks allowlist); 18. Sweep worktree caches
(`.cache/signoz-src`, `.cache/gatus-src`, `nixos.qcow2`); 19. Spot
-check the v0.2.0 pin still evals against this flake; 20. Ask
whether SystemNix wants upstream devShells.

**Docs follow-ups (this pass's residue)**
~~21. Full per-claim freshness audit of `docs/TELEMETRY.md` (upgrade from~~ routed - TODO_LIST docs-freshness-audits row (2026-09-29)
tonight's light pass).
~~22. Full freshness audit of `CONTRIBUTING.md`.~~ routed - TODO_LIST docs-freshness-audits row (2026-09-29)
~~23. Link-rot policy decision for archived docs (see e/4).~~ declined - accepted noise (e/4's current state held: historical files keep their truth; no allowlist built)
~~24. Upstream the docs-health skill: `routed` marker kind + w-marker~~ out of scope here - skill-repo work, not this repo
contradiction lint (skill-repo, out of repo scope).
~~25. Watch mjs/imapclient#663 to merge (retires the py3.13 pin via the~~ done - MERGED 2026-09-18, released in 4.1.0 (02-58 a/1); the py3.13 pin retires at the bump carrying >= 4.1.0
Pin-advance runbook).
~~26. Watch #563651/#563652/#563777 for maintainer movement (TODO row).~~ standing - TODO_LIST watch row (re-checked 2026-09-22)
~~27. aarch64: occasional local `nix flake check --all-systems`.~~ standing - ROADMAP §5 residue (habit, not a row)
~~28. treefmt-vs-minimal-alejandra decision (ROADMAP §5).~~ done - REJECTED 2026-09-17 (AGENTS Conventions; treefmt would swap alejandra for nixfmt and break the CI contract)
~~29. Reload-smoke ops step when a live host uses management-API settings~~ routed - ROADMAP §4 Respond (D1-conditional)
(ROADMAP §4, D1-conditional).
~~30. Gatus external-view checks (ROADMAP §4, D1-conditional).~~ done(spec) - MONITORING §5.1 templates (21-10 a/9); implementation consumer-side
~~31. Post-0.3.0: retire-or-keep documentation for the Resend-only path.~~ routed - ROADMAP §5
~~32. Consider a TODO_LIST row-count lint (grep-verified count vs claimed~~ Won't implement - YAGNI (the count-first discipline + docs-health VERIFY cover the class; no lint built)
count) — cheap mechanization of tonight's d/1 sin; assess honestly,
likely YAGNI.

## g) QUESTIONS (cannot resolve myself)

~~1. **Push approval**: this session added 5 daemon commits (docs-only:~~ done - pushed; master in sync with origin, CI green (verified 2026-09-29)
   living-doc rebuild, annotations, 7 renames, this report) to unpushed
   master. Push nix-email now?
~~2. **Release 0.3.0 tonight?** The gate cleared with the PR #1 merge and~~ done - v0.3.0 cut 2026-09-17 (v0.3.1 same evening)
   `[Unreleased]` is thick (relay, native ingestion, DKIM dual-sign,
   pipe-lint, devShell, two docs-health passes). Cut now, or batch with
   more changes? Precedent says self-serve; your call on timing.
~~3. **Strict required-checks vs daemon bypass**: pushes currently bypass~~ still open - decision-batch C18 (unchanged)
   the required `nix flake check` (remote says so verbatim). Keep the
   bypass for daemon velocity, or tighten and accept rejected daemon
   pushes until CI-green? (Flagged twice by earlier sessions; still
   open.)

---

_Point-in-time snapshot. Written 2026-09-16 18:41 CEST after the second
docs-health pass completed green. WAITING FOR INSTRUCTIONS._
