# Probe transcripts: the evidence directory

Every behavioural claim in this repository that could not be settled by
reading the pinned source lives here as a directory of raw logs, JSON
dumps and a `README.md` that states what was run, against which pin, and
what it proved. Citations elsewhere (`README.md`, the ledger,
`docs/INBOXCLEAN.md`, `docs/MONITORING.md`) point at these paths.

Rules for adding a probe: one directory named `<YYYY-MM-DD>-<slug>`,
a `README.md` that names the pin, the exact commands and the verdict, and
the raw artifacts beside it unedited. A probe directory without a README
is a finding, not a convention.

| Directory | Date | Pin | What it proves |
| --- | --- | --- | --- |
| `2026-10-05-jmap-demo-vm/` | 2026-10-05 | 0.15.5 | JMAP session, mailbox and push shapes from the host over the 18080 forward |
| `2026-10-17-quota-journal-silence/` | 2026-10-17 | 0.16.22 | Over-quota delivery is SMTP-accepted, absent from IMAP, and silent in the journal (three boots) |
| `2026-10-18-demo-smoke-backup/` | 2026-10-18 | 0.16.22 | Demo smoke plus the 0.16 backup-story proof, with an EventSource probe |
| `2026-10-19-carddav-demo-vm/` | 2026-10-19 | 0.16.22 | CardDAV drill: 10k-card benchmark verdict (close, do not file upstream) and E2E shape |
| `2026-10-26-es-ping/` | 2026-10-26 | 0.16.22 | The JMAP EventSource `ping` parameter matrix, mode by mode |
| `2026-10-28-carddav-01626/` | 2026-10-28 | 0.16.26 | CardDAV re-baseline after the pin advance, with a probe-port diff |
| `2026-10-29-caldav-01626/` | 2026-10-29 | 0.16.26 | CalDAV discovery and query behaviour (the gate artifact for the single-truth decision) |
| `2026-10-31-demo-smoke-01626/` | 2026-10-31 | 0.16.26 | Fresh demo-VM smoke: anonymous JMAP, submission to IMAPS round-trip, catch-all |
| `2026-10-31-dnsmasq-forward/` | 2026-10-31 | in-test | Why `10.0.2.3` is a blackhole in multi-node test VMs and a live forward in demos |
| `2026-11-01_demo-smoke-tooling/` | 2026-11-01 | 0.16.26 | The one-command smoke (`demo-console.sh` + `demo-smoke.py`) and the FIFO console |

Adding a row here is cheap; a transcript whose verdict lives only in a
status report is one archive move away from being unfindable.
