# Demo-VM tooling verification (Alpha-plan T1, 2026-11-01)

One-command smoke + FIFO console, both transcript-verified against a
fresh `scripts/demo-console.sh` boot of the demo VM (0.16.26 pin).

## Results

| Leg                                            | Result                                                            |
| ---------------------------------------------- | ----------------------------------------------------------------- |
| `scripts/demo-console.sh` boot                  | VM reached login prompt; `sleep infinity` holder kept the FIFO open; 900 s timeout killed the whole process group (cat + run-demo-vm + QEMU); NO orphan QEMU left holding the demo-disk write lock |
| `scripts/vm-debug.sh --script-only --check`     | exit 0: check evaled, GC root built (cached), driver discovered from the derivation buildCommand, starter generated under `~/.cache/nix-email/vm-debug/`, lint clean, driver command line printed without executing |
| `python3 scripts/demo-smoke.py` (5 legs)        | ALL PASS: anon JMAP session (200, apiUrl); AUTH submission 2587 STARTTLS+LOGIN; IMAPS 2593 round-trip (needle `smoke-fb9d1a8f095351a1` delivered); catch-all accept on 2525 (`any-6dbea4f0@mail.demo.test`); strict reject `x@demo.test` -> 550 |

Raw probe output of the green run (console session dir of the boot:
`/tmp/nix-email-demo-console.*/console.log`, swept with the session):

    [PASS] anon JMAP session: status=200 apiUrl present
    [PASS] AUTH submission: STARTTLS+LOGIN accepted, sent smoke-fb9d1a8f095351a1
    [PASS] IMAPS round-trip: delivered, needle smoke-fb9d1a8f095351a1
    [PASS] catch-all accept: unauthenticated send to any-6dbea4f0@mail.demo.test accepted (250 path)
    [PASS] strict domain reject: x@demo.test -> 550 (550 expected)
    SMOKE GREEN: all legs passed

## Notes

- The smoke reproduces the 2026-10-31 0.16.26 smoke
  (`docs/probes/2026-10-31-demo-smoke-01626/`) as a checked-in probe; the
  next post-bump smoke is one command against a running demo VM.
- `demo-console.sh` builds `nixosConfigurations.demo.config.system.build.vm`
  (the `.#vm` app is not a package attribute - first-run lesson, fixed
  in-script).
- The vm-debug starter default moved from `/tmp` to the cache dir, and
  user scripts under `/tmp` are copied before the driver runs (the
  2026-10-31 sweeper class).
