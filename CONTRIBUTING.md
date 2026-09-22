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

### Known fixture traps (before you write a VM test)

Two live-observed generator traps are recorded in `AGENTS.md` ("VM-test
fixture traps"): dovecot settings values must not use dovecot's own
`<path` include prefix (the NixOS generator renders them literally), and
the ini generator renders booleans Python-style (`True`/`False`, not
`true`/`false`) — one failed VM run each, 2026-09-15.

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

In-VM assertions are file-based, never `producer | grep -q`: the test shell
runs pipefail, so grep -q's early exit can EPIPE the producer (observed as
curl exit 23 on a matching payload, 2026-09-15) - and `! producer | grep -q`
can phantom-green. Dump the producer to a file, then grep the file.

## Release procedure

Distilled from the v0.3.0/v0.3.1 cuts (2026-09-17). The auto-commit daemon
races explicit commits - for release-critical files (CHANGELOG above all),
commit in the SAME tool call that edits them, before drafting anything else.

1. Assess: `git log <last-tag>..HEAD --oneline` - is [Unreleased] carrying a
   release-worthy payload?
2. Cut the CHANGELOG: rename `## [Unreleased]` -> `## [X.Y.Z] - <date>`,
   merge any duplicate `### Added/Changed/Fixed` blocks into single sections
   (sessions append in parallel - check for doubles), leave a fresh empty
   `## [Unreleased]` with the three headers. Commit immediately.
3. Verify the claim surface BEFORE writing notes: `git diff <last>..HEAD --
   modules/` (a "docs-only / no breaking changes" claim needs this diff).
4. Gates: `buildflow` (wrapper) AND the full `nix flake check` (the VM
   suites - buildflow's flake-check step is eval-only). Both redirect to
   logs, read the logs, EXIT:0 required.
5. Annotated tag: `git tag -a vX.Y.Z -m "<key changes one-liner>"`, then
   verify the tagged tree: `git show vX.Y.Z:CHANGELOG.md | grep '<X.Y.Z>'`.
6. Push master + tag (the pre-push alejandra hook runs).
7. Verify tag CI goes green (`gh run list`, the tag push runs the full
   `nix flake check`).
8. `gh release create vX.Y.Z --latest --title ... --notes-file ...` with a
   nixpkgs-pin evidence footer (rev + "narHash unchanged since vX.Y.Z-1"
   from flake.lock), then `gh release view vX.Y.Z` (not draft, Latest).
9. Note the release in TODO_LIST/decision docs if a consumer pin decision
   (C17-class) was waiting on the tag.

## Formatting gate (pre-push)

CI fail-closes on `nix fmt -- . --check` (alejandra). A local `pre-push`
hook in `.githooks/` (`core.hooksPath` already points there) runs the same
check before every push, so an unformatted tree fails locally instead of
going red on master (which happened twice on 2026-09-16, ~13 min public
red). Bypassing with `git push --no-verify` is discouraged - CI still
enforces it. If the hook fires, run `nix fmt -- .` and re-push.

## Architecture diagrams

The D2 sources and rendered SVGs live in
`docs/architecture-understanding/`. After editing a `.d2` file, regenerate
its SVG (elk layout is what the committed renders use):

```sh
nix run nixpkgs#d2 -- --layout=elk docs/architecture-understanding/<file>.d2 \
  docs/architecture-understanding/<file>.svg
```

Commit the `.d2` and the `.svg` together - the SVG is the artifact readers
open, the D2 is the source of truth.

## Docs map

- `README.md` - architecture, module docs, go-live runbook, ledger.
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work (delete done items; CHANGELOG records them).
- `ROADMAP.md` - long-term themes and open user decisions.
- `CHANGELOG.md` - what changed.
- `docs/{status,planning,reviews}/` - point-in-time session snapshots
  (historical; annotated as work resolves).
