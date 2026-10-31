# Demo VM smoke on 0.16.26 (Ω-plan D8/D7 ride, 2026-10-31)

Fresh `nix run .#vm` boot, host-side probes over the forwarded ports
(18080/2525/2587/2593 per the README quickstart). Executor: Crush
session (Ω-plan execution). All probes ran from the HOST with python
stdlib (urllib/smtplib/imaplib); no in-guest commands.

## Results

| Leg                                               | Result                                                                       |
| ------------------------------------------------- | ----------------------------------------------------------------------------- |
| Anon JMAP session `GET /.well-known/jmap`         | 200, `primaryAccounts: {}`, absolute `apiUrl` (`.../jmap/`), `downloadUrl` present - the documented 0.16 shape |
| AUTH submission 2587 (STARTTLS + LOGIN)           | accepted; sender=recipient `demo@mail.demo.test`                              |
| IMAPS round-trip 2593                             | DELIVERED within seconds (needle `d8-smoke-e2af063665a0`)                     |
| Inbound 2525 to unknown local part `@mail.demo.test` | 250 accepted (catch-all contract)                                          |
| Inbound 2525 to `@demo.test` (wrong domain)       | `550 5.1.2 Relay not allowed` - strict rejection OUTSIDE the provisioned domain (the negative leg) |
| Catch-all mailbox delivery leg                    | NOT asserted: the target is the credential-less `catchall@mail.demo.test` account (by design, demo-eval pins it); the README's claim is SMTP-accept semantics, which the two legs above pin |

## Notes

- The 0.15-era "runtime smoke pending" README caveat is retired by this
  transcript: anon-session shape, AUTH round-trip, and the catch-all
  accept/reject pair all behave as documented on 0.16.26.
- `/metrics/prometheus` is NOT served on the demo (`metrics.enable` is
  off in the demo contract); the 0.16.26 series verification rode the
  fresh `stalwart-e2e` rebuild the same session (see TELEMETRY.md's
  dated banner).
- First catch-all probe used `@demo.test` (wrong domain) and 550'd -
  kept as the negative leg; the provisioned Domain equals the wrapper
  `hostname` (`mail.demo.test`), the ledger's "hostname = provisioned
  Domain" fact, re-demonstrated.
