# Status Report: README + AGENTS "superb" pass — verify-and-fix self-review (2026-10-17)

- **Date:** 2026-10-17, 05:37 CEST (`date` CLI)
- **Session:** the user's "Is the README.md and AGENTS.md as superb as possible???" +
  the follow-up interrogation ("what did you forget / better / still improve").
  Docs-health skill loaded (BUILD/VERIFY mode, agents-quality-guide applied);
  this report is the status-report answer, scoped to THIS session only per the
  user's instruction ("do not research other stuff").
- **Prior episode cross-ref:** `2026-10-17_04-09_docs-health-self-review-forgotten-and-fixed.md`
  is the 03:53 sweep's self-review; its (b) items are the drift classes this
  session attacked. Not duplicated here — referenced where closed.
- **Repo state at write time:** head `265d06b` — the auto-commit daemon
  committed the session's edits mid-flight (`ed8f06f`, `7949104`,
  `265d06b`; expected repo behavior); tree now carries only this report
  (untracked) + a TODO_LIST table-padding re-format. The CI runs over those
  daemon commits are UNWATCHED - see f/6.

## Verdict in one line

Both files were structurally superb already; they were NOT fully accurate —
this session verified every checkable claim against code/CI and fixed six
README plus six AGENTS drift points plus six cross-file contradictions, with
TWO self-inflicted (both self-caught) formatter manglings on the way; the
remaining gap to "superb as possible" is two deliberate user-gated
structure decisions and a handful of un-swept sibling docs.

## a) FULLY DONE (verified this session)

1. **Full claim verification of README.md + AGENTS.md against the repo** —
   flake.nix, flake-modules/checks.nix, .github/workflows/ci.yml lockstep,
   tests/{stalwart-e2e,demo-eval,module-import-eval}.nix,
   modules/{mail-server,dmarc-monitor}.nix option surfaces,
   flake-modules/{demo-vm,devshells}.nix, flake.lock rev `6774f7bc`,
   .buildflow.yml skips, CONTRIBUTING.md sections, docs/ paths, git + CI
   state. nixpkgs pin claim, 6-check set, 17 subtests, demo ports/credentials,
   option lists, devShell tools: all confirmed.
2. **README drift fixes (6):** check-set list gained the missing
   `module-import-eval` + `demo-eval` (ci.yml lockstep = authority, 6 checks);
   dmarc-monitor row "eval contract-tested" -> VM-tested E2E (parsedmarc-e2e
   two-node); truncated `What it` port-table header -> `Purpose`; devShell
   list gained actionlint + shellcheck; Non-goals dropped the 0.15.5-era
   "POP3 is compiled into" phrasing; local-only design-note path marked
   internal.
3. **AGENTS.md drift fixes (6):** stale "quota subtest re-pin is open" ->
   the re-pinned journal-silence posture (tests/stalwart-e2e.nix:720,
   green 2026-10-17); 0.15-era "web/API host" -> "web admin/JMAP"; ambiguous
   `admin demo-admin` -> login `admin` + password `demo-admin` (demo-eval
   assertion shape); documentation map gained `docs/MONITORING.md` +
   `CONTRIBUTING.md`; table-pipe rule now cites its mechanized CI lint; NEW
   lesson bullet: dprint re-indents/rewrites prose whose continuation line
   starts with a list marker (`-` or `+`; recorded at discovery, extended
   after the second incident).
4. **Cross-file contradiction fixes (6 rows/entries):** FEATURES rows for
   relay / native DMARC ingestion / rate limiting / provisioning still
   described pre-gate-green state and contradicted the gate row in the SAME
   file — updated to the 03-34 green-run truth (ingestion + provisioning
   flipped PARTIAL -> FULL on that evidence); TODO_LIST sweep header
   ("one subtest from green, origin CI red" -> gate green, master pushed,
   CI green — verified via `git status -sb` + `gh run list`); CHANGELOG
   `[Unreleased]` Fixed entry added.
5. **Gates run on every touched file:** `dprint check` EXIT 0,
   `scripts/check-md-table-pipes.sh` clean, all internal README/AGENTS
   links resolve (mechanical python check), stale-string grep zero hits.
6. **In-session self-repairs:** BOTH dprint prose manglings I introduced
   (see d/1) were caught in diff/re-read review and fixed before yield.

Closes `04-09` b/1 partially (README line-level drift: six instances),
b/2 partially (CONTRIBUTING read + mapped).

## b) PARTIALLY DONE

~~1. **"As superb as possible" itself.** Accuracy: restored. Structure:~~ routed - accuracy restored was the deliverable; structure calls split: AGENTS prune executed 06-05 (31,498 -> 28,040 B), README TOC + ledger home parked as decision-batch C52
deliberately untouched (no TOC — new rot surface with no anchor gate; no
AGENTS.md pruning — see g/1). The honest framing: this pass made the docs
TRUE, not newly-shaped; structural superb-ness is a user decision, not
mine to impose. Remaining effort: S per decision once taken.
~~2. **Cross-file consistency sweep.** FEATURES/TODO/CHANGELOG done; NOT~~ done 2026-10-17 - ROADMAP swept (03-53 + migration passes), INBOXCLEAN carries the 0.16 banner (verified this pass), SECURITY.md glanced (v0.4.0-current table is factual)
opened: ROADMAP.md (15 KB — the 03-34 sweep claims it was swept, but the
TODO header proved that class of claim can lag), docs/INBOXCLEAN.md's
0.16 banner, SECURITY.md. Blocker: session scope. Effort: S each.
~~3. **dprint verdict provenance.** "dprint clean" was proven with~~ done - buildflow -s dprint-format is the canonical pinned invocation (buildflow owns the toolchain; recorded in the AGENTS archive-policy line); the devShell deliberately carries only CI-parity tools
registry-floating `nix shell nixpkgs#dprint` (0.61.1), NOT a pinned
toolchain — and the devShell carries no dprint at all. CI runs no dprint
step (alejandra + pipes lint only), and buildflow's dprint step is
`--fix`, so no red CI can result; but the verdict is toolchain-relative.
Effort to close: S (devShell gains dprint, or document the canonical
invocation).

## c) NOT STARTED (correctly parked; canonical list = TODO_LIST)

~~1. **Primary-evidence read of the 03-34 report.** My FEATURES status flips~~ done 2026-10-17 - the 03-34 report's verdict section was read in full THIS pass; 17/17 + relay 3/3 quotes confirmed behind the FEATURES flips
rest on triple citation (FEATURES gate row + README banner + test-file
content) — the report's own verdict section was never opened this
session. Effort: S. Priority: Medium (weakens otherwise-solid flips).
~~2. **ROADMAP/INBOXCLEAN/SECURITY sweeps** (b/2 above).~~ done 2026-10-17 - ROADMAP swept; INBOXCLEAN 0.16 banner verified; SECURITY.md glanced (see b/2)
~~3. **Mechanizing the prose-wrap dash lint** — the new AGENTS lesson is~~ routed - TODO_LIST prose-wrap list-marker lint row (added this pass)
prose-only doctrine today; the pipes lint could grow a sibling rule.
~~4. **AGENTS.md size-pruning / README TOC** — parked behind g/1 + g/2.~~ routed - AGENTS prune executed 06-05; deeper <20 KB cuts are the C41 addendum; README TOC is C52-adjacent (user-gated)
~~5. **CI watch of the daemon-committed docs tree** — the daemon landed the~~ done 2026-10-17 - origin green verified (runs 39016232923 + 39072344502)
session's commits mid-flight (see header); their CI runs are unobserved
(the repo's own "never assume the known red" rule applies to greens
too).

## d) TOTALLY FUCKED UP (all self-caught; nothing shipped)

1. **I introduced formatter manglings TWICE, once inside this very report.**
   First: my AGENTS.md rewrap put `- TODO_LIST):` at a line start; dprint
   parsed it as a nested list item and re-indented the following ~10 lines
   of a Commands bullet. Second: the report's own verdict paragraph wrapped
   as `...fixed 6 README\n+ 6 AGENTS...` - dprint normalized the `+` line
   start into a `-` list item, splitting the paragraph mid-sentence. Both
   caught in post-fmt review, both fixed, lesson promoted to an AGENTS.md
   Working-rules bullet covering BOTH markers. Severity: zero (working tree
   only, never committed in a broken shape). Root cause: writing wraps by
   hand in marker-hostile positions, twice, after documenting the rule once.
2. **Four edit-tool "modified since read" rejections.** I repeatedly ran
   `dprint fmt` between reads and edits and then edited stale views —
   violating the repo's own "register reads with view" session rule. Cost:
   four rejected edits (2x AGENTS.md, 2x this report) + re-reads. Root
   cause: formatting passes interleaved with editing without re-reading.
3. **Unpinned toolchain for a pin-doctrine repo.** d/3 in (b): the format
   verdict came from a floating dprint. Not a shipped defect, but a
   provenance failure by this repo's own standards — the exact class the
   ledger exists to prevent.

## e) WHAT WE SHOULD IMPROVE

1. **Canonical pinned dprint:** devShell gains dprint (making `nix develop`
   the formatting environment) or AGENTS records the canonical invocation;
   float-versus-pin then never matters again.
2. **Read-after-format discipline:** after ANY `dprint fmt` over files I will
   keep editing, re-`view` before the next edit — the two failed edits were
   pure sequence errors.
3. **Primary-evidence discipline on status flips:** flipping FEATURES rows on
   triple-citation without opening the cited report's verdict section is the
   docs-health "quote the verdict before routing" rule applied sloppily;
   next time open the primary.
4. **Check-set single-sourcing:** the 6-check descriptions now exist in
   README AND summarized in AGENTS (pre-existing pattern, I added to it) —
   a small split brain; AGENTS could point at README's list.
5. **Mechanize prose-wrap rules:** the dash/plus-at-line-start trap is now
   the THIRD dprint misparse class this repo has met (pipes, struck-row
   rewrap, list markers); lint it instead of remembering it.
6. **CI watch as a standing yield-step:** after daemon-commit, read the next
   run's step names — cheap, and the repo's red-triage doctrine already
   demands the discipline in the other direction.

## f) Next tasks (session-scoped; honest count: 14 — not padded to 50)

The user's instruction forbade unrelated research, so this list contains
only work this session surfaced or touched.

| #  | Task | Impact                                                                                             | Effort | Category |
| -- | ---- | -------------------------------------------------------------------------------------------------- | ------ | -------- |
| ~~1~~ done — 2026-10-17 - ROADMAP is at the 0.16/gate-green truth (03-53 pass + migration-session updates, verified this pass) | ~~Sweep ROADMAP.md to the 0.16/gate-green truth (TODO header proved sweep claims can lag)~~ | ~~High~~ | ~~S~~ |
| ~~2~~ done — 2026-10-17 - the 03-34 verdict section read in full this pass; 17/17 + relay 3/3 confirmed | ~~Read the 03-34 report's verdict section; confirm 17/17 + relay 3/3 quotes behind my status flips~~ | ~~Med~~ | ~~S~~ |
| ~~3~~ done — 2026-10-17 - INBOXCLEAN 0.16 BANNER verified present; the full re-verification gates on the demo-smoke TODO row | ~~Verify docs/INBOXCLEAN.md 0.16 banner matches the current re-verification state~~ | ~~Med~~ | ~~S~~ |
| ~~4~~ done — canonical pinned invocation recorded: buildflow -s dprint-format (AGENTS archive-policy line); devShell stays CI-parity-minimal | ~~Add dprint to the devShell + record the canonical pinned invocation in AGENTS~~ | ~~Med~~ | ~~S~~ |
| 5 **→ TODO_LIST prose-wrap list-marker lint row (added this pass)** | Extend the CI markdown lint with the prose-wrap dash/plus rule (nested-list misparse class) | Med | M |
| ~~6~~ done — 2026-10-17 - origin green (runs 39016232923, 39072344502), step names read via gh run view | ~~Watch the next CI run over the daemon-committed docs tree; read step names if red~~ | ~~Med~~ | ~~S~~ |
| ~~7~~ done — 2026-10-17 - this pass harvested the b/c/f/g items of all five superseded reports into TODO_LIST/decision-batch and archived them | ~~HARVEST this report's (f) rows into TODO_LIST (docs-health loop closure)~~ | ~~Med~~ | ~~S~~ |
| ~~8~~ done — 2026-10-17 - AGENTS names the check set SINGLE-SOURCED (ci.yml lockstep / README list canonical; no restated counts) | ~~Single-source the check-set list (AGENTS points at README instead of restating)~~ | ~~Low~~ | ~~S~~ |
| ~~9~~ done — 2026-10-17 - glanced: supported-versions table says v0.4.0 current (factual; the latest release IS v0.4.0 pending v0.5.0) | ~~SECURITY.md freshness glance (unopened this session)~~ | ~~Low~~ | ~~S~~ |
| 10 **→ AGENTS prune executed 06-05; deeper cuts = C41 addendum (user-gated)** | AGENTS.md size-pruning decision (g/1) — user-gated | Med | M |
| 11 **→ README TOC = structure decision, parked with C52 (README-as-ledger home)** | README TOC decision + anchor-lint gate if yes (g/2-adjacent) | Low | M |
| ~~12~~ done — 2026-10-17 - the morning migration session + this pass re-verified the living docs line-level (README/FEATURES/AGENTS/TODO_LIST claims checked against code) | ~~Re-verify the 03-53 sweep's "all six living docs swept" claim line-level (b/2 residue)~~ | ~~Med~~ | ~~M~~ |
| ~~13~~ done — 2026-10-17 - repo-wide grep clean outside the CHANGELOG historical narration | ~~Confirm no other doc quotes the retired "re-pin is open"/"web/API" phrasings (repo-wide grep)~~ | ~~Low~~ | ~~S~~ |
| ~~14~~ done — the TODO_LIST header carries "Last verification sweep" + date (the convention exists) | ~~Consider archiving rule tweak: sweep headers that narrate state should carry a "updated when" hook~~ | ~~Low~~ | ~~M~~ |

## g) Questions (cannot self-answer)

~~1. **AGENTS.md is 30,190 bytes — the bloat boundary the quality guide sets~~ routed - AGENTS prune EXECUTED 06-05 (28,040 B); the deeper-cut question = C41 addendum
(30 KB), already flagged by the 04-09 report.** Prune it (move
provenance-dated incident narratives into archived status reports, keep
standing rules + pointers — halves context cost for every session), or is
the provenance-dated compendium the deliberate permanent shape? This is a
doctrine call, not a fact I can grep.
~~2. **README (68 KB) owns the verified-facts ledger** while global doctrine~~ routed - decision-batch C52 (new entry, [rec] accept README-as-ledger as permanent)
says README = end-user sales page. Move the ledger to
`docs/LEDGER.md` with a README index (cleaner audience split; breaks the
"READ THE LEDGER in README.md" muscle memory recorded in AGENTS +
SystemNix-side references), or is README-as-ledger permanent?
~~3. **Canonical dprint home:** should the devShell carry dprint so `nix~~ routed - buildflow -s dprint-format is the canonical pinned path (AGENTS); the devShell gains nothing
   develop` is the one formatting environment (my (e)/1 default), or do you
prefer buildflow's internal dprint stays the only one (keeping the
devShell minimal) and AGENTS documents `buildflow -s dprint-format` as
the pinned path?

Awaiting instructions.
