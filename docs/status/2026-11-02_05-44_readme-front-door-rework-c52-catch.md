<!-- Status snapshot 2026-11-02 05:44 CET. Owner order: "FIX IT" on the
     README front-door review (items: no TOC, dev-diary STATUS banner,
     quickstart at 50% depth, ledger inline, no install snippet, no
     license/security/contributing links, stale root demo disk).
     Tree at write: README.md + CHANGELOG.md modified, docs/LEDGER.md
     deletion staged (transient file from an in-flight attempt, see c). -->

# README front-door rework: quickstart hoisted, banner cut, ledger move REFUSED by C52 (2026-11-02 05:44)

## 0. TL;DR

| Question                                   | Answer                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| What was asked?                            | Fix the README review findings: no TOC, 38-line pin-advance banner before any value prop, first runnable command at ~50% depth, ledger inline, no install snippet, no LICENSE/SECURITY/CONTRIBUTING links, stale root `demo.qcow2`.                                                                                                                                                                                      |
| What shipped?                              | Hero (pitch -> one-command try -> 5-line status), `## Contents` (18 rows, every anchor machine-checked), demo VM hoisted to `## Quickstart: try it in a VM` (command now on line 19), SystemNix section de-staled + full flake-input/`nixosModules.default` snippet, LICENSE/Security/Contributing footer, split delta heading fixed, stale "`nix fmt` is alejandra only" claim fixed, 20 MB stale `demo.qcow2` trashed. |
| What was REFUSED, and why?                 | Moving the ledger to `docs/LEDGER.md` - **owner decision C52 (ratified 2026-10-23): "Accept README-as-ledger"**, the move explicitly rejected as "rewrites many pointers". The move was executed, then reverted byte-identically; only its discoverability changed (status link + TOC row).                                                                                                                              |
| Verification (scope: README + this report) | `nix flake check` EXIT 0 ("all checks passed!"), `nix fmt -- . --check` EXIT 0, md pipe/list-marker/check-set-drift lints EXIT 0, inventory lockstep EXIT 0, testScript shell lint EXIT 0, link+anchor checker: 0 broken.                                                                                                                                                                                                |

## a) FULLY DONE

1. **Hero + status** - README:1-30. Pitch keeps the concrete design basis
   (Hetzner VPS inbound, Resend relay, evo-x2 parsing, the internal
   selfhosted-email-guide study), then `nix run github:LarsArtmann/nix-email#vm`,
   then a five-line status block whose detail already lives in CHANGELOG
   (`fe132422` ride-alongs at CHANGELOG.md:252/545/820) and
   [0.5.0] (CHANGELOG.md:243).
2. **`## Contents`** - README:32-50, 18 rows. Anchors generated from the
   headings with a GitHub slugger and then verified: every `#anchor`
   resolves to a real heading (0 broken).
3. **Quickstart hoisted** - the demo VM section moved out of
   `## Development` to README:53; first runnable command is line 19
   (was ~825). JMAP/contacts quickstarts moved with it and were demoted one
   level. `tests/demo-eval.nix` comment updated to the new heading name
   (comments only; no assertion touched).
4. **Install snippet** - `## SystemNix integration (planned shape)` lost
   the stale label (the consumer wrapper EXISTS, per the paragraphs below
   it) and gained a real flake-input + `nixosModules.default` + required
   `hostname`/`admin.secretFile` snippet (option names checked against the
   module assertions, `modules/mail-server.nix:820`).
5. **Footer sections** - License (MIT), Security (links
   docs/THREAT_MODEL.md + SECURITY.md), Contributing (links CONTRIBUTING,
   CHANGELOG, TODO_LIST, FEATURES). CONTRIBUTING was previously named in
   prose but never linked.
6. **Two real defects found while reading** -
   the 0.16.22 -> 0.16.26 delta heading was SPLIT by an embedded `###`
   (rendered as a title plus a stray heading), and Platform support still
   claimed "`nix fmt` (alejandra) formats .nix; dprint covers ..." after
   the 2026-11-01 unified wrapper. Both fixed; the formatter note now lives
   with the other gates in Development.
7. **CHANGELOG** - Changed entry for the rework, stating explicitly that
   the ledger location is unchanged by C52 (so a future session does not
   read the entry as a licence to move it).

## b) PARTIALLY DONE / BY DESIGN

1. **File length** - 1680 lines, unchanged in substance: the 644-line
   ledger stays where C52 put it. The TOC is the mitigation; a length cut
   is an owner call, not a docs pass.

## c) FAILED ATTEMPTS (kept for the next session)

1. **Ledger move (executed, then reverted).** The reference scan that
   should precede any relocation caught it late: `docs/planning/decision-batch.md`
   C52 + the ratified verdict sheet. Revert verified: the
   `## Verified-facts ledger` .. `## Non-goals` slice is byte-identical to
   the pre-session file (`git show 20da24e:README.md`).
2. **Transient `docs/LEDGER.md` in history** - the auto-commit daemon
   committed the in-flight move (`c1ef1a6`) before the revert landed. The
   final tree deletes the file (deletion staged); history keeps one
   add-then-delete pair. No live pointer refers to it: the only remaining
   mentions are this report and the CHANGELOG entry that explains the revert
   (`rg 'docs/LEDGER' README.md AGENTS.md CONTRIBUTING.md scripts modules tests`
   = no hits).

## d) VERIFICATION (commands + results)

| Command                             | Result                                                          |
| ----------------------------------- | --------------------------------------------------------------- |
| `nix flake check`                   | `GATE_EXIT:0`, "all checks passed!" (13-check x86_64 set)       |
| `nix fmt -- . --check`              | `FMTCHECK_EXIT:0` (alejandra + dprint unified wrapper)          |
| `scripts/check-md-table-pipes.sh`   | `PIPE_EXIT:0` (after staging the `docs/LEDGER.md` deletion)     |
| `scripts/check-md-list-markers.sh`  | `LIST_EXIT:0`                                                   |
| `scripts/check-check-set-drift.sh`  | `DRIFT_EXIT:0`                                                  |
| `scripts/check-inventory.sh`        | `INV_EXIT:0`                                                    |
| `scripts/check-testscript-shell.py` | `testScript shell syntax OK (287 fragments, 12 nix files)`      |
| README link/anchor audit            | 0 broken files, 0 broken anchors (18 TOC rows incl. the ledger) |

## e) NEXT

1. `nix run .#vm` spot-check is unchanged by docs edits (demo-eval pins the
   port table this README prints) - no re-run needed.
2. If the README ever grows past readability again, the C52-compatible
   lever is moving the RUNBOOKS (go-live + pin-advance) to `docs/`, not the
   ledger: runbooks are procedures, the ledger is the pointer web C52
   protects. This is NOT a new task - it is ROADMAP open question 4
   ("README ops-detail level: keep as-is, trim to outline, or move detail
   into a private consumer doc?"), still unanswered. Harvest it from there
   when the owner sits; do not mint a parallel TODO row.
3. Out of scope this round, so NOT verified: FEATURES/TODO_LIST/ROADMAP
   freshness beyond the few rows cross-read for this report; the ledger's
   ~150 bullets beyond the pin/version/check-set arms; external competitor
   claims (the hero's unsourced Mailcow RAM figure was dropped rather than
   dated, because no fetch was performed).
