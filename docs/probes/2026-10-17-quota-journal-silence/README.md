# Over-quota journal-silence probe transcripts - stalwart-e2e debug driver, 2026-10-17

Three independent boots of the `stalwart-e2e` VM (pinned Stalwart
0.16.22) settle the quota subtest's 0.16 re-pin: the 0.15 retry
signature `Message rescheduled for delivery` is GONE, and the journal
is SILENT on over-quota mail. Every claim in the README ledger
("Per-account semantics" quota bullet + the storage-QUOTA ledger entry)
and the quota subtest comment in `tests/stalwart-e2e.nix` cites these
runs. ANSI stripped and trimmed to the last 300 lines each (boot noise
dropped; all DEBUG polling lines, the swaks transcripts, and the final
journal-tail dumps are retained).

- `driver7.log` - clean-instrument run: swaks via `machine.succeed` +
  file capture, acceptance line `250 2.0.0 Message queued with id
  4a77d05b4000000` (SWAKS-EXIT:0), then journal polling. Broke at
  iter0 on a FALSE POSITIVE: the grep pattern's bare `over` matched
  systemd's `Consumed ... over 2.438s wall clock` noise.
- `driver8.log` - tightened pattern (`over quota` phrase, no bare
  `over`): zero matches through 70 s; driver then died on a guest-shell
  BrokenPipeError mid-poll (driver flake, not product).
- `driver9.log` - DEFINITIVE: queue id tracked explicitly
  (`4a77af9fa00000`); 20 x 10 s = 200 s of polling with pattern
  `quota|reschedul|422 |451 |defer|tempfail|retry|<qid>` = ZERO
  matches - the journal never re-mentions the queue id either.
  DRIVER-EXIT:0.

Instrument lessons (driver6, not archived): a manual
`systemctl start stalwart-provision.service` in a debug script re-runs
the boot apply's oneshot and its try-restart races the probe - swaks
got a 535 on VALID credentials. The debug-script instrument rules live
in AGENTS.md ("VM debug loop").
