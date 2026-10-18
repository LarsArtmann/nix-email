# Probe transcripts — 2026-10-18 demo smoke + 0.16 backup-story proof

Session: V6/V11/V18 of the 2026-10-18 V-generation plan
(`docs/planning/2026-10-18_22-20_SUPERB-pareto-v-generation-backlog-burn.md`).
One fresh boot of `nixosConfigurations.demo` (post DNS-race fix, see
below) via the FIFO-console pattern; host-side probes against the
forwarded ports.

## Files

- `vm-console-transcript.log` — full FIFO console session: boot, layered
  probes (guest services → guest loopback → host ports), mail seeding
  (inbound :25, submission :587 STARTTLS auth, IMAPS), the backup battery
  (offline `cp -a`, `stalwart-cli snapshot`, main-binary `--export`,
  wipe + `--import` restore drill), and the store-guard refusal +
  marker escape hatch.
- `eventsource-probe.log` — JMAP EventSource push probe (host, port
  18080): stream opens 200; a delivery at t+7.65 s emits
  `event: state` / `StateChange` with `Email`/`Mailbox`/`Thread`/
  `EmailDelivery` states; no ping frames within the 40 s window;
  connection stays open (`closeafter=no`).
- `es_probe.py`, `jmap_move.py` — the host-side probe scripts
  (python3 stdlib only), reproducible against any demo boot.

## Key verdicts (all transcript-backed)

1. **Demo boot race FIXED**: without a `DnsResolver` singleton, the
   0.16 reload-validation read the (not-yet-written) system resolv.conf
   and failed apply op #7, aborting before the restart step — stalwart
   kept the built-in listener set (no 587/465). Fix: demo pins
   `DnsResolver."@type" = "Cloudflare"` (same as the e2e). After the
   fix: `stalwart-provision` Result=success, all 5 listeners bound.
2. **0.16 JMAP contract**: `/.well-known/jmap` 307 → `/jmap/session`
   (unchanged from 0.15); auth identity = synthesized email address;
   accountId is `"c"`; no `urn:ietf:params:jmap:core` entry in
   `primaryAccounts` (mail/submission/... only).
3. **SMTP**: 0.16 rejects single-label EHLO (`550 5.5.0 Invalid EHLO
   domain.` for bare `demo`) — probes need an explicit FQDN `--ehlo`.
   Submission :587 STARTTLS + AUTH LOGIN with the synthesized address
   works (`235 2.7.0`), queued, delivered to INBOX.
4. **Filing**: unauthenticated inbound landed in INBOX on the first
   boot, but in Junk Mail after the restore drill — spam-score variance,
   NOT a deterministic "inbound → Junk" rule (the old demo banner claim
   was wrong for 0.16 defaults; banner now says "may land in Junk Mail").
   JMAP `Email/set` move to the Junk-role mailbox works (the InboxClean
   automation path): `updated: {"eaaaaab": null}`, Junk=1/Inbox=2.
5. **Backup story on the PIN (0.16.22)** — all four legs verified:
   - offline copy: stop + `cp -a` (1.8M) + start → mail intact;
   - `stalwart-cli snapshot Domain Account Directory DnsServer
     DnsResolver AcmeProvider Tenant --allow-unresolved PublicKey,Role`
     → 3-line NDJSON plan, password secrets stripped by default
     (`--include-secrets` opts in); snapshot enforces referential
     closure and rejects cycles without `--allow-unresolved`;
   - MAIN-binary `stalwart --export <dir>` EXISTS on 0.16.22 (`-e`,
     20 `subspace_*` files, 780K) and `--import` restores it — but only
     into a store that was NEVER STARTED ("already contains data in the
     key ranges being imported"), and the wiped dir needs the
     `v016-store-migrated` marker touched or OUR store guard refuses the
     first boot (the guard's own escape-hatch message is the procedure);
   - after import + marker: all 5 listeners back (listener settings live
     in the datastore), login + INBOX/Junk counts intact, new delivery
     accepted and filed.
   - Vandelay: NOT packaged in the pinned nixpkgs (eval error,
     `packages.x86_64-linux.vandelay` missing) — per-account export on
     the pin rides imapsync/source-built vandelay; unverified here.
