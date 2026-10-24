---
title: "nix-email x eventcatalog-hub: integration executed, publish riding CI handoff"
date: 2026-10-24 18:40
status: executed (T1-T5, T7, T9 done; T6/T8 publish gated on a concurrent hub workstream)
owner: lars
---

# nix-email -> eventcatalog-hub integration: execution report

Executes
[the committed plan](../planning/2026-10-24_17-07_nix-email-eventcatalog-hub-perfect-integration.md)
same-day, tasks T1-T9. Everything under this repo's control is landed,
pushed, and pipeline-verified end to end; the catalog publish (T6/T8) is
gated on a CONCURRENT session's in-flight hub workstream (details below)

- exact handoff included.

## Landed (all receipts reproducible)

| What                                        | Where                                            | Receipt                                                                                                                                                                                                   |
| ------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Exporter (2 services + 7 ADRs + 1 user)     | `scripts/export-catalog.py` @ `456840b` (pushed) | `--selftest` PASS (10 files, deterministic, appliesTo + owner resolve in-tree); BuildFlow gate EXIT:0 (ruff/bandit/vulture)                                                                               |
| Hub adoption (manual source + lint block)   | hub `sources.manual.json` @ `0788a21`            | `generate-sources.sh` wrote it between mesh-orders and pbx-lens; `--check` clean; dprint clean; both files committed together                                                                             |
| Full pipeline rehearsal (scoped)            | hub snapshot build `/tmp/hub-build4.log`         | EXIT:0 - export, merge (copied 10, union-merged 2), governance gate, per-source lint + merged-render lint both "No problems!", npm ci, generate + build, `check-dist-output --expect-source nix-email` OK |
| Badge-union composition (the "perfect" bit) | merged `services/mail-server/index.mdx`          | OUR frontmatter/body + `badges: not deployed (orange)` unioned in from the SystemNix inventory tree; dmarc-monitor likewise                                                                               |
| Live preview eyeball                        | `npx eventcatalog preview` on the built dist     | `/docs/services/mail-server/1.0.0` renders: title, summary, owners Lars Artmann, the not-deployed chip, listener table, Decision Records tab; all 7 ADR routes present in dist                            |
| Docs                                        | AGENTS.md + README.md + CHANGELOG.md @ `7153ed4` | "EventCatalog integration" contract section (lockstep, NOEXEC, no-badges/no-manifest, honest ADR statuses); dprint + pipe lints clean                                                                     |

The rehearsal was scoped to nix-email as the sole source BY DESIGN: two
FOREIGN sources were red mid-flight during this session (webphone's
export boots the app and dies on `/var/lib/webphone` permissions;
go-cqrs-lite master's `mesh-demo` calls `reg.MarkDemo` before the
library half landed). Both belong to the concurrent "demo sources
flagged at the SOURCE (2026-10-24)" workstream that was actively
rewriting the hub's `sources.json` (daemon commits 18:02-18:16) while
this session rehearsed. Hands off per the foreign-file rule; every
pipeline step THIS adoption touches was still exercised for real
(clone -> export -> merge -> both linters -> site build -> dist
assertions -> preview), plus a two-tree merge simulation
(`/tmp/sim`) reproducing build.sh steps 2a/2b exactly.

## Fix caught by the rehearsal (the system worked)

First rehearsal run failed the per-source governance lint with exactly
9 x `refs/owner-exists` ("Referenced user/team lars does not exist"):
the hub lints each source tree IN ISOLATION, so a tree naming an owner
must ship the user resource itself (bank-sync/cqrs-htmx/crm all ship
their own `users/lars.mdx`). Fixed in `456840b` (exporter emits
`users/lars.mdx`; identical copies union first-wins). Re-lint: 10 files,
no problems.

## Publish handoff (T6/T8 remainder - bounded, not blocked on us)

1. Wait for the concurrent demo-flagging workstream to land (webphone
   export fixed + go-cqrs-lite MarkDemo tagged/bumped). A hub-master
   push before that publishes a red run.
2. Ensure the nix-email Forgejo mirror carries >= `456840b` (mirror
   last synced 15:30, pre-exporter; pulls every <= 6h) - or the CI's
   Forgejo-side clone misses `scripts/export-catalog.py`.
3. Then EITHER just push hub master (build.yml fires on push; nightly
   03:23 rebuild bounds staleness anyway) OR force it now on evo-x2:
   `sudo bash scripts/ci-dispatch.sh build.yml master` (root-only PAT
   minting; not executable from an agent shell).
4. Verify T8: catalog.home.lan `/docs/services/mail-server/1.0.0` +
   `/docs/services/dmarc-monitor/1.0.0` (bodies ours, chips SystemNix),
   `/docs/adrs/<id>/1.0.0` x7, `build-stamp.json` covering the
   nix-email rev, `check-stale-sources.sh` quiet.

## Deviations from the plan (honest)

- T1 and T3 were written as one exporter commit instead of two phases
  (same deliverable set, same verification gates; the plan's dependency
  order was preserved).
- T5 ran in a hub SNAPSHOT with sources scoped down after the foreign
  reds - the plan's "full ./build.sh" green with all 9 sources belongs
  to the concurrent workstream's landing.
- T6 `sudo bash scripts/ci-dispatch.sh` is not agent-executable (sudo
  ban); the push-trigger path makes it optional anyway.

## Corridor

- TODO_LIST harvested: publish-handoff row (blocked, foreign
  workstream), SystemNix description-sync cadence row, deferred-kinds
  standing verdict row.
- The plan file carries an execution-record annotation (not archived;
  its T6/T8 rows stay open until the handoff above completes).
