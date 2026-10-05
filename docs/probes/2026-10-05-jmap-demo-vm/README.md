# JMAP probe transcripts - demo VM, 2026-10-05

Captured against `nix run .#vm` (Stalwart 0.15.5, pinned nixpkgs
6774f7bc) from the host over the 18080 forward. Every claim in
`docs/INBOXCLEAN.md` cites one of these files. The VM log itself (boot +
provision) stayed outside the repo - these are the wire-level artifacts.

- `session-admin.json` - session document, admin principal (capabilities,
  URL templates, `eventSourceUrl`)
- `session-user.json` - session document, `roles: ["user"]` probe
  principal (account-capability delta)
- `create-probe-user.txt` - `POST /api/principal` creation transcript
- `mailbox-probe.json` - `Mailbox/query` + `Mailbox/get` +
  `Email/query` as the probe user (system mailboxes with roles)
- `push-event.txt` - EventSource stream capture: `StateChange` event
  ~5 s after an SMTP delivery (`?types=Email`; the advertised
  `{closeafter}`/`{ping}` params are rejected by this pin)
- `email-after-push.json` - the delivered message visible to
  `Email/query` after the push event
