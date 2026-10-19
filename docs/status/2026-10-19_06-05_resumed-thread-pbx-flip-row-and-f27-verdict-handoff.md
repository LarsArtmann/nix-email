# Status: Resumed-thread triage — pbx flip row + f27 verdict hand-off — 2026-10-19 06:05

> Scope: THIS thread only (a resumed conversation re-grounded on 2026-10-19
> after an interrupted 2026-10-17 turn). Companion sessions (V/W-generation,
> upstream-watch, contacts-assessment) own their own reports. Format `.md`
> per standing instruction.

| Field   | Value                                                                    |
| ------- | ------------------------------------------------------------------------ |
| Date    | 2026-10-19 06:05 CEST (`date` CLI)                                       |
| HEAD    | `4c51fb7`, master CI green (run 39191414206); concurrent sessions active |
| Session | repo triage + one TODO row + this report; no code touched                |

## a) DONE (this thread)

1. **Re-ground after 2-day gap**: verified master green, check-set inventory
   in sync, `stalwart-migrate-e2e` unregistration understood (later FIXED by
   W-generation - my Oct-17 analysis of it is obsolete), and the Oct-17
   thread's edits all survived and fed forward: C42 evidence recorded
   (decision-batch), guard-sites rule institutionalized (`3d5c11b`, since
   widened to four lists by W10), backup story EXECUTED 2026-10-18 by the
   V-session (my research slice was its input; done rows deleted per canon).
2. **pbx-artmann flip TODO row added** (TODO_LIST, Medium Impact): their
   `stalwart-host-wiring` gate is red BY DESIGN - the deadlock-pin
   (`machine.fail`, test line 166) predates our bootstrap fix and its own
   comment prescribes the flip; row also carries the TLS/webadmin/admin
   leg re-adds. Gates over the edit: pipes EXIT:0, check-rows EXIT:0,
   dprint EXIT:0.

## b) HAND-OFF (found broken, not repaired - file under concurrent edit)

- **06-12 report f27 verdict cell lost**: a later annotate rebuild of
  `docs/status/2026-10-17_06-12_*.md` dropped my verdict (the row is now a
  bare strike). The c/47 annotation still preserves the substance. The file
  was being modified by another session DURING this thread (mtime <10 min),
  so the restore is routed into the new TODO row instead of racing the
  file. Verdict to restore: "done 2026-10-17 - their lock d7e1334
  (0.16.26): stalwart.service ACTIVE + provision FINISHED at boot, fix
  validated; remaining red = the file's own deliberate deadlock-pin".

## c) Open (unchanged, owner-gated)

- P1/P2 owner sittings (C39-C46 answers, ratifications, D1/D2, Resend key)
  - unchanged; C42 evidence is complete and tilts retire-once-0.16-pins.
- The concurrently modified `V-plan` + `decision-batch.md` working-tree
  edits belong to the live sessions - left untouched (daemon will sweep).

WAITING FOR INSTRUCTIONS.
