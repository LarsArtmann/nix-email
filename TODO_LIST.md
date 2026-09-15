<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                                                                                                                             | Status    | Impact | Effort | Evidence                                                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | ------------------------------------------------------------------------------------------------------ |
| SystemNix consumer wrapper: flake input (`github:LarsArtmann/nix-email` - repo is public), consumer module, ports.nix, sops templates, onFailure→Discord, Gatus checks, backup-coordination (work happens in the SystemNix repo) | 🔴 `TODO` | High   | 2h     | Unblocked: D3 visibility decided (published 2026-09-14); nothing in this repo blocks it                |
| Two-node VM test (stalwart + Mailpit node) E2E-ing the smarthost relay path despite the loopback-address refusal (`docs/status/2026-09-14_19-45`, f/11; `docs/planning/2026-09-14_18-37`, R3 b/2)                                | 🔴 `TODO` | High   | 2h     | Relay mechanism verified locally only; loopback guard blocks single-node test (`README.md` ledger, R3) |
| CI: GitHub Action running `nix flake check` on push/PR, fail-closed (asserts the check actually ran, Files>0-style guard; do not repeat the go-paperless `-no-fail` false-green)                                                 | 🔴 `TODO` | High   | 1h     | No `.github/` exists; every sibling repo gates pushes                                                  |
| Wrapper option `services.mail-server.relay = { address, port, username, secretFile; }` generating the verified `queue.route` + `queue.strategy.route` TOML (ledger entry → product)                                              | 🔴 `TODO` | High   | 2h     | Verified keys in `README.md` ledger; no option in `modules/mail-server.nix` yet                        |
| DKIM signing VM test: declarative `signature.<id>` with a test key, assert `DKIM-Signature` header on submission (`docs/status/2026-09-14_19-39`, f/10)                                                                          | 🔴 `TODO` | High   | 1h     | Keys source-verified (`README.md` ledger); zero test coverage                                          |

## Medium Impact

| Task                                                                                                                                                            | Status       | Impact | Effort | Evidence                                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ------ | --------------------------------------------------------------------------------------------------------- |
| LICENSE file + GitHub license metadata (license choice pending - MIT is the default recommendation)                                                             | 🔵 `BLOCKED` | Med    | 10min  | No LICENSE in repo; `gh repo view` shows `license: null`; choice is a user decision                       |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                                                   | 🔵 `BLOCKED` | Med    | 1h     | `modules/dmarc-monitor.nix` exercised by eval contract only; needs rua-mailbox decision (D1)              |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                              | 🔵 `BLOCKED` | Med    | 1h     | `docs/planning/2026-09-14_18-37` R6; needs live mailboxes (D1)                                            |
| Restart-persistence VM test: deliver, `systemctl restart stalwart`, message still in INBOX; anonymous admin API stays 401 across the restart                    | 🔴 `TODO`    | Med    | 30min  | RocksDB state survival never asserted (`tests/stalwart-e2e.nix` has no restart subtest)                   |
| parsedmarc E2E VM test: seed a sample DMARC aggregate report into a local mailbox (dovecot), assert JSON/CSV output lands (`docs/status/2026-09-14_19-45` f/13) | 🔴 `TODO`    | Med    | 1h     | `tests/dmarc-eval.nix` is eval-only; parser never exercised in CI                                         |
| Metrics VM assertion: `metrics.prometheus.enable = true` → `/metrics/prometheus` 200 (401 with auth)                                                            | 🔴 `TODO`    | Med    | 30min  | Keys verified in ledger, endpoint never probed (`tests/stalwart-e2e.nix`)                                 |
| Backup/restore VM drill: `stalwart --export`, wipe, `--import`, assert message survival                                                                         | 🔴 `TODO`    | Med    | 1h     | Native export source-verified (`README.md` ledger); never exercised                                       |
| `directory."internal".cache.ttl.negative` wrapper option (dev/test hosts want it low; kills the 1h negative-cache trap)                                         | 🔴 `TODO`    | Med    | 30min  | Cache-poisoning root cause in `README.md` ledger; no option today                                         |
| `certificate` option tier (`self-signed \| acme \| manual`) with mutual-exclusion assertions (nms x509 pattern)                                                 | 🔴 `TODO`    | Med    | 1h     | `modules/mail-server.nix` hardcodes the self-signed default only                                          |
| `metrics.enable` wrapper option wiring `metrics.prometheus.*`                                                                                                   | 🔴 `TODO`    | Med    | 30min  | No wrapper surface for metrics (`modules/mail-server.nix`)                                                |
| Assertion: warn when `httpBind` is non-loopback (README doctrine: reverse-proxy only, never expose raw)                                                         | 🔴 `TODO`    | Med    | 15min  | Doctrine stated in `README.md` listener table; not enforced                                               |
| Nix formatter for `.nix` files (alejandra or nixfmt via treefmt; dprint covers json/yaml/markdown only) + one formatting pass                                   | 🔴 `TODO`    | Med    | 45min  | `dprint.json` has no nix plugin; modules unformatted                                                      |
| aarch64 posture: run the VM test under qemu-aarch64 once, or document x86_64-only loudly                                                                        | 🔴 `TODO`    | Med    | 30min  | `flake.nix` gates stalwart-e2e to x86_64; nobody has ever run it on ARM                                   |
| Threat-model doc: what the loopback guard does/does not protect, admin exposure policy, secret inventory                                                        | 🔴 `TODO`    | Med    | 1h     | `docs/status/2026-09-14_19-45` f/50; loopback-refusal behavior is verified but undocumented as a boundary |
| GitHub repo topics (mail, nixos, stalwart, dmarc) - description already set                                                                                     | 🔴 `TODO`    | Med    | 5min   | `gh repo view` shows `topics: null`                                                                       |

## Low Impact

| Task                                                                                                              | Status    | Impact | Effort | Evidence                                                                         |
| ----------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | -------------------------------------------------------------------------------- |
| Extend E2E with quota, alias/catch-all, and Junk-delivery subtests (keep ONE VM test file - CI time budget)       | 🔴 `TODO` | Low    | 1h     | `docs/status/2026-09-14_19-39` f/14-16; `tests/stalwart-e2e.nix`                 |
| Regression VM test for the `is_local_domain` negative-cache ordering (guard against the poisoning fix regressing) | 🔴 `TODO` | Low    | 30min  | `docs/status/2026-09-14_19-45` f/12; root cause in `README.md` ledger            |
| Details-level journal assertion with curated benign-filter (resolver/pyzor/ASN lines)                             | 🔴 `TODO` | Low    | 30min  | `docs/status/2026-09-14_19-39` f/18; benign list partially in `README.md` ledger |
| dmarc-eval: guard the `_secret`/`general.output` contract against nixpkgs pin moves (versionOlder on parsedmarc)  | 🔴 `TODO` | Low    | 20min  | `tests/dmarc-eval.nix` assumes current option shapes                             |
| parsedmarc service hardening suggestions (ProtectSystem etc. as mkDefaults)                                       | 🔴 `TODO` | Low    | 20min  | `modules/dmarc-monitor.nix` sets no hardening                                    |
| d2 architecture diagram in README (hosts, flows, decisions)                                                       | 🔴 `TODO` | Low    | 30min  | `docs/planning/2026-09-14_18-37` H6.1                                            |
| CONTRIBUTING note: how to add a verified-facts ledger bullet (source-path citation or VM observation date)        | 🔴 `TODO` | Low    | 15min  | `docs/status/2026-09-14_19-39` f/47; rules live only in README                   |
| Renovate/dependabot for the nixpkgs input (must stay paired with SystemNix's lock - note in config)               | 🔴 `TODO` | Low    | 30min  | `AGENTS.md` convention states the pairing; no automation                         |
| git-town.toml (match sibling-repo workflow)                                                                       | 🔴 `TODO` | Low    | 10min  | `docs/status/2026-09-14_17-05` f/32                                              |
