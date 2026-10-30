# Status Report — Store-Advisory Session (RocksDB / SQLite / BTRFS / Clusters)

- **Date:** 2026-10-25 15:26 CET
- **Session type:** Pure advisory Q&A. **Zero code changes, zero commits, zero file modifications** (git was clean at start and stayed clean).
- **Scope discipline:** Per operator instruction, this report covers ONLY what this session did and noticed. It is NOT a project-wide inventory; no research beyond the session's own reads was performed.
- **Baseline ritual (run before this report):** `git status --short` = clean; 37 parallel `crush -y` processes observed (multi-session machine, expected); corridor scan (`docs/status`, `docs/planning`, `docs/reviews`) found **no same-day reports** — most recent prior report is 2026-10-24_19-03 (yesterday's EventCatalog session, not restated here).

## TL;DR

Three advisory answers were delivered (store-backend comparison, storage-engine internals + snapshot safety, clustering constraints). All repo-facing claims were grounded in files read this session (`modules/stalwart-module/default.nix`, `modules/stalwart-module/migrate_v016.py` via grep). Several upstream-behavior claims were delivered from model knowledge and are **unverified** — flagged below. Nothing was encoded into the repo, so the unverified claims caused no damage, but they become liability the moment anyone wants them durable. Three owner decisions are pending (section g).

---

## Session Work Inventory

| # | Turn                                    | Deliverable                                                                                                                                                                                                                                    | Grounding                                                                                                                                                  |
| - | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | "RocksDB vs SQLite"                     | Comparison table (model, write path, debuggability, backup, ops, sweet spot) + verdict: wrapper's 0.16 RocksDB default is right for the real host; SQLite better for probe/dev VMs                                                             | `modules/stalwart-module/default.nix:288-308` (dual layout: legacy SQLite+fs vs 0.16 RocksDB), store taxonomy in `modules/stalwart-module/migrate_v016.py` |
| 2 | "LSM-tree vs B-tree / BTRFS snapshots?" | Mechanics table (write path, compaction, crash recovery) + verdict: atomic CoW subvolume snapshot fixes torn-copy for BOTH engines; keep CoW enabled on the data dir; restore drill required; snapshots are not backup, pair with send/receive | Model knowledge (engine internals) + in-repo layout fact that data + blobs co-locate under `${cfg.dataDir}`                                                |
| 3 | "How does RocksDB affect clusters?"     | Verdict: RocksDB/SQLite are the single-node options (embedded, one process, one lock, no replication); Stalwart clusters need shared stores (FoundationDB / PostgreSQL / MySQL) + shared blob store                                            | Store taxonomy from `migrate_v016.py` (in-repo); cluster-behavior claims from model knowledge (unverified — see d/e)                                       |

## a) FULLY DONE

1. **All three advisory answers delivered**, each with a comparison table and a concrete verdict tied to this stack (no generic essay answers).
2. **In-repo grounding** for every repo-facing claim: the dual store layout (legacy `sqlite`+`fs` vs 0.16 `rocksdb`, `useLegacyStorage` branch) was read at `default.nix:288-308` before answering — not quoted from memory.
3. **Correct restraint on scope:** no files were created or edited during the Q&A (operator had not asked for durable artifacts).
4. **Session-start baseline ritual** executed before this report (git state, corridor scan, process scan) — no collision with other sessions' work.

## b) PARTIALLY DONE

1. **Verification level of the advisory content:** split. Claims about THIS repo are file-verified; claims about Stalwart upstream behavior (FoundationDB as the blessed cluster store, absence of built-in replication, SQLite-vs-RocksDB recovery semantics as stated) and BTRFS snapshot semantics (nodatacow partial-extent visibility) are model-knowledge-grade, not ledger- or source-verified. Nothing depends on them yet, which is why this is "partial" and not "fucked up".
2. **Routing of session outcomes:** the answers surfaced at least three durable candidates (backup doctrine row, cluster-store decision note, ledger pins) — identified and listed in (f), but not routed into TODO_LIST/ROADMAP/ADR data yet. Harvest pending (see skill note at bottom).

## c) NOT STARTED

1. Everything durable: no decision note, no runbook row, no ledger pin, no probe script exists from this session — deliberately, pending owner answers (section g).
2. The restore drill (snapshot a live store, restore into a scratch VM, verify clean journal replay) — proposed in the BTRFS answer, never run. This repo's own doctrine applies: journal-replay-on-restore is a claim, not a fact, until a transcript exists.
3. TODO_LIST/ROADMAP harvest of this report's section (f).

## d) TOTALLY FUCKED UP

**Nothing.** No code was touched, no state was broken, git is clean, no gates were run or left red, no foreign files were edited. Honest closest candidates, listed with why they do NOT qualify as (d):

- "Three answers, zero durable artifacts" — process outcome, not damage; encoding unverified claims WOULD have been the fuckup, and it didn't happen.
- "Advisory claims not ledger-pinned" — exposure, not breakage (see e1).
- "Ledger not read before answering" — the AGENTS.md rule scopes the ledger to _touching Stalwart/parsedmarc config keys_; no keys were touched, so no rule was broken. Spirit-level miss, logged in e1.

## Self-Review (operator's three questions)

**What did I forget?**

1. To read the README VERIFIED-FACTS LEDGER before answering Stalwart store questions. In a repo where "several obvious keys are wrong", store-doctrine claims deserve the same transcript-pinning discipline as config keys. Nothing I said contradicted anything I saw in-repo, but I did not CHECK that.
2. To classify my claims explicitly _at answer time_ (verified-in-repo vs model-knowledge) instead of only in this report.
3. To offer the three pending owner decisions inline, at the moment each answer landed, rather than deferring them all to a status report.

**What could I have done better?**

1. Ground turn 2 and turn 3 in sources: upstream Stalwart docs for cluster/store doctrine, BTRFS docs for snapshot semantics — the `verify-external-claims` discipline this repo runs on applies to advisory answers too if they might become durable.
2. Turn 1 could have checked how `useLegacyStorage` is derived (I described the branch, not the condition) before asserting which layout a given consumer gets.
3. Offered the "SQLite for probe/dev VMs" note as a one-line docs candidate immediately, since the carddav probe already relies on a throwaway SQLite store — the pattern is established, only the doctrine line is missing.

**What could I still improve?**

1. A standing habit: advisory answers that name repo mechanisms end with file:line citations by default (turn 1 did; turns 2-3 partially).
2. Convert advisory sessions into decision notes faster when the owner is present — the cost of re-deriving this in a future session is pure waste.

## e) WHAT WE SHOULD IMPROVE

1. **Claim-class labeling for advisory answers:** verify-before-encoding should extend to Q&A — label every claim "file-verified" or "model-knowledge" at delivery time in this repo, given its verified-facts culture.
2. **Ledger-first reflex even for non-editing sessions:** reading the ledger costs one `view` call and would have hardened turns 1-3.
3. **Backup/restore doctrine is currently scattered:** the repo defers backup-coordination to the SystemNix consumer layer (correct per AGENTS.md), but the mechanics answer (subvolume placement, CoW flag, atomic-snapshot reasoning) is nowhere — either as a consumer-layer doc pointer or a runbook row. One owner decision (g2) resolves this.
4. **Cluster story is undocumented-by-design but unanchored:** nothing in the repo states "this stack is single-host by doctrine" vs "clusters are hypothetically possible via shared stores". One line somewhere (ROADMAP or README architecture) would prevent future sessions from re-deriving the whole analysis.
5. **Status-report cadence note:** yesterday's and today's sessions are both advisory/execution mix; no drift issues found in the corridor (same-day check clean). No action.

## f) Next Things (session-grounded; capped honestly)

Operator asked for "up to 50". Filling to 50 would require exactly the project-wide research this report was told NOT to do, so the list stops where evidence stops. Items carry their source. Items marked [owner] need a section-g answer first.

~~1. [owner] Decide the cluster horizon: is multi-node Stalwart ever planned for this stack? If yes → open a decision note "cluster store choice" (FoundationDB vs PostgreSQL as shared data store). If no → one ROADMAP/README line: "single-host by doctrine; RocksDB default is final until that changes."~~ **→ routed — ROADMAP open question 9a (cluster horizon; added 2026-10-30)**
~~2. [owner] Decide where backup/restore doctrine lives: this flake's README go-live runbook vs SystemNix consumer docs exclusively.~~ **→ routed — ROADMAP open question 9b (backup-doctrine ownership)**
~~3. [owner] Decide durability: should this session's advisory content (store comparison, cluster constraints, snapshot doctrine) be verified and pinned into the ledger/module docs, or remain one-off Q&A?~~ **→ routed — ROADMAP open question 9c (durability)**
~~4. If (3) = durable: verify Stalwart cluster/shared-store claims against upstream docs at the pin's version, then add a ledger row ("store backends and clusters" class).~~ **→ routed — rides 9c**
~~5. If (3) = durable: verify the BTRFS nodatacow/snapshot semantics claim against BTRFS docs before encoding it anywhere.~~ **→ routed — rides 9c**
~~6. Add a backup/restore row to whichever doc (2) selects: dataDir on its own subvolume, CoW enabled on DB paths (never `chattr +C` on `index.sqlite3` or the RocksDB dir), atomic snapshot captures all store files at one instant, restore = copy + journal replay.~~ **→ routed — rides 9b**
~~7. Run the restore drill once: snapshot a live (demo-VM or scratch) store, restore into a clean VM, start the service, capture the journal-replay transcript under `docs/probes/<date>/` — the repo's own "no assertion without a transcript" rule applies to backup claims.~~ **→ routed — the STORE-level restore drill is VM-proven (FEATURES backup row, 2026-10-18 transcripts); the BTRFS-snapshot drill rides 9b**
~~8. Add the one-line dev-VM doctrine: "SQLite layout (legacy) is the probe/dev default because the store stays inspectable with sqlite3; RocksDB layout is the real-host default" — the carddav probe already depends on the SQLite side of this, only the written doctrine is missing.~~ **→ routed — rides 9a/9c**
~~9. README module docs: one paragraph on switching store backends per consumer (`services.stalwart.settings` override path) + the migration reality (dump/convert via the migrate path, never in-place) — grounded in `migrate_v016.py`'s converter surface.~~ **→ routed — rides 9c**
~~10. Add a decision-note stub only if (1) says cluster: store taxonomy table (rocksdb/sqlite = single-node; foundationdb/postgresql/mysql = shareable; s3/azure = blobs; elasticsearch/meilisearch = FTS) lifted from `migrate_v016.py`'s own validation messages so it cannot drift from code.~~ **→ routed — rides 9a (only if cluster becomes planned)**
~~11. If (2) selects runbook: add the "snapshots are not backup" pairing rule (send/receive off-host) next to the existing dead-man-monitor doctrine in `docs/MONITORING.md`'s neighborhood.~~ **→ routed — rides 9b**
~~12. Optionally pin the crash-recovery claim (SQLite WAL replay / RocksDB MANIFEST+WAL replay) into the ledger row from (4) — same verification pass, one visit.~~ **→ routed — rides 9c**
~~13. TODO_LIST harvest of this report: section (f) rows 1-12 into TODO_LIST/ROADMAP with the [owner] gates made explicit (docs-health HARVEST mode).~~ **→ done — THIS pass (2026-10-30): the owner-gated trio routed to ROADMAP open question 9; nothing belongs in TODO_LIST (questions, not tasks)**

**Pre-existing items noticed in passing this session (NOT session work; listed for routing honesty only):** C44 account-secrets doctrine row (TODO_LIST, seen in grep), C42/C45 ADRs shipping `proposed` (seen in grep), `docs/TELEMETRY.md` 0.15-era caveat (AGENTS.md). These already have homes; no new action created here.

## g) Questions I Cannot Figure Out Myself

~~1. **Cluster horizon:** Is a second Stalwart node ever on the roadmap for this stack, or is single-host the permanent shape? This decides whether "cluster store choice" becomes a tracked decision now, or a one-line doctrine note forever.~~ **→ routed — 9a**
~~2. **Backup doctrine ownership:** Should the store-backup mechanics (BTRFS subvolume layout, CoW flag, snapshot + restore-drill procedure) be documented in THIS flake's README runbook, or is all backup doctrine consumer-layer (SystemNix) by design, leaving this flake with nothing to say?~~ **→ routed — 9b**
~~3. **Durability of this session's answers:** Do you want any of the advisory content verified and pinned (ledger rows / module docs), or was it one-off Q&A with no doc obligation? (If durable, items 4/5/12 define the verification pass.)~~ **→ routed — 9c**

---

_Per the status-report skill: section (f) is primary HARVEST input for TODO_LIST/ROADMAP — harvest pending operator go-ahead since three items are owner-gated. Report written per operator's explicit `.md` path demand (skill default is HTML; override honored, not propagated). No manual commit — the auto-commit daemon picks this file up (harness forbids commits without explicit request)._
