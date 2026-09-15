# Contributing to nix-email

This repository has ONE core discipline that every change must respect:

## The verified-facts ledger

`README.md` ends in a **verified-facts ledger**. It exists so no future
session ever has to re-derive a Stalwart/parsedmarc config key from memory
(or worse, from a tutorial). Several "obvious" keys are wrong
(`certificate.self-signed` has no `.default` level; parsedmarc 11 reads the
IMAP connection from `[imap]`, not `[mailbox]`).

### Adding a ledger bullet

Every bullet MUST carry evidence in one of exactly two forms:

1. **Source citation** - you read the pinned version's source and can name
   the file/line (e.g. `crates/common/src/config/server/tls.rs`,
   `parse_certificates`). State the tag you read (`v0.15.5`).
2. **Live observation** - you ran the real binary (locally or in the VM) and
   observed the behavior. State the observation date and, briefly, how
   (e.g. "live spike 2026-09-14, local binary + Mailpit").

Anything else - docs read but not pinned, tutorials, "it should work",
"the webadmin does this" - is NOT evidence. Do not add the bullet.

### When a bullet turns out to be wrong

Do not silently rewrite it: correct the entry and note the correction date,
so future readers know the fact changed (see the parsedmarc `_secret` entry
for the pattern).

## Changes to the wrapper modules

- All wrapper defaults are `mkDefault`; consumers override through
  `services.stalwart.settings` / `services.parsedmarc.settings`. Exceptions
  (e.g. the firewall port list) carry a comment explaining why.
- Every config key emitted by the wrapper needs either a ledger bullet or a
  source comment naming the verified origin. No guessed keys.
- Behavior changes need test coverage: VM E2E for behavior
  (`tests/stalwart-e2e.nix`), eval contract for wiring
  (`tests/dmarc-eval.nix`). Never weaken module defaults to make a test
  deterministic - fix the test.

## The gate

`nix flake check` is the full gate: eval contracts + both NixOS VM tests
(~2-4 min each; the SMTP subtests intentionally wait out ~60 s of resolver
timeouts in the DNS-less VM). Failed check results are CACHED - a rerun
without an input change replays the old verdict.

Gate commands never wear pipes: a pipe reports the FILTER's exit code, so
`cmd | tail` can print PASSED on a failing run. Redirect and echo the exit
code into the log instead, then read the log:

```sh
nix flake check > /tmp/gate.log 2>&1; echo "EXIT:$?" >> /tmp/gate.log
```

Test assertions are transcribed from observed transcripts, not from expected
output: grep the line you want to assert out of an existing test log or a
debug VM run first. Reading it in upstream source is NOT evidence of what the
journal/log prints (the `Mailbox over quota.` vs `Message rescheduled for
delivery` lesson, 2026-09-15).

## Docs map

- `README.md` - architecture, module docs, go-live runbook, ledger.
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work (delete done items; CHANGELOG records them).
- `ROADMAP.md` - long-term themes and open user decisions.
- `CHANGELOG.md` - what changed.
- `docs/{status,planning,reviews}/` - point-in-time session snapshots
  (historical; annotated as work resolves).
