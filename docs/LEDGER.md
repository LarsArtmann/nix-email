# Verified-facts ledger (do not re-derive from memory)

Transcript- and source-pinned facts for this wrapper. Read this before
touching Stalwart or parsedmarc config keys - several "obvious" upstream
keys are wrong, and most 0.15 intuitions are dead on 0.16.

Entry rules (transcript-or-it-did-not-happen, dates + probe paths) live in
[CONTRIBUTING.md](../CONTRIBUTING.md). The [README](../README.md) owns the
architecture and the runbooks; this file owns the fact set.


### Stalwart 0.16 (transcript-pinned during the 2026-10-16/17 upgrade)

> **PIN RIDE-ALONG 2026-10-28**: the fe132422 advance moved the binary
> 0.16.22 -> 0.16.26 ([delta table](../README.md#module-servicesmail-server)). Re-verified on 0.16.26:
> provision-plan-eval (object shapes/typecheck), the stalwart-e2e VM run,
> the full parsedmarc-e2e suite, and the CardDAV probe baseline (17/18
> PASS reproduced unchanged; `docs/probes/2026-10-28-carddav-01626/`).
> The remaining transcript-pinned facts below date to 0.16.22 unless
> re-marked (a JMAP-specific probe re-run is NOT done - only the CardDAV
> surface was re-proven; re-run at the next bump that touches JMAP).

- **JMAP session endpoint moved**: `GET /jmap` -> 404 for everyone; session = `/.well-known/jmap` -> 307 (`location: /jmap/session`) -> 200 authed.
  ANONYMOUS session requests return 200 with `primaryAccounts: {}` (NOT
  401 - the enforcement point is the API POST, which 401s). `apiUrl` is an
  absolute `https://<host>/jmap/` URL (unusable in a DNS-less VM; tests
  strip scheme+authority). Demo-VM transcripts, 2026-10-16/17.
- **Account/User object schema (apply-transcript-pinned)**: `User.name` is
  the LOCAL PART (a full address fails apply: "Invalid email local part");
  there is NO `emailAddress` field (silently dropped); the synthesized
  `name@<Domain.name>` address is the unique `email` index and the auth
  identity (IMAP LOGIN and MAIL FROM both key on it); MAIL FROM outside
  the address set = 501. `EmailAlias.name` also takes the local part only.
- **Provision-plan dialect (`stalwart-cli apply`)**: ops apply SEQUENTIALLY;
  `#id` references resolve ONLY against earlier ops in the SAME plan;
  an upsert patching an existing object MUST carry its match property
  (`name` for Domain - "match property `name` is missing from the object
  body" otherwise); `credentials` must be the indexed-map form
  `{"0":{...}}`, not a JSON array; `MtaInboundThrottle` has no `name` -
  its implicit match key is `description` (wrapper emits
  `match = ["description"]`); DkimSignature needs NO `publicKey` (server
  derives it); Account match keys must be explicit (`match = ["name"]`) -
  value-matching breaks once the server hashes stored secrets.
  DIVERGENCE (VM-proven 2026-10-18, backup-transcript probes):
  `stalwart-cli snapshot` generates plans with NO Account matchOn
  (id-keyed upserts) - both shapes work; the wrapper deliberately sets
  `match = ["name"]` for e2e/demo idempotence (pinned by
  `provision-plan-eval`), so do not "fix" snapshot-derived plans to match
  the wrapper or vice versa.
- **Static `server.listener` config keys are SILENTLY IGNORED** on 0.16
  (binary-proven 2026-10-17): listeners live exclusively in the datastore,
  and a VIRGIN store binds only the built-in default set (smtp 25 + http
  8080). A non-8080 `httpBind` therefore bootstraps through the built-in
  endpoint: the provision unit probes `cfg.url`, falls back to
  `127.0.0.1:8080`, applies against whichever answered, restarts stalwart,
  then verifies `cfg.url`. An endpoint is accepted ONLY when its
  unauthenticated `/jmap/session` carries
  `urn:ietf:params:jmap:core` - a bare HTTP answer on the built-in port is
  not identity (post-fix, 2026-10-23: the built-in port is Stalwart's only
  on a host that leaves it free; on pbx-artmann the webphone owned :8080
  and a blind `curl --fail` fallback handed it the WHOLE plan - schema
  refresh 404, red switch; the unit now keeps waiting and names the
  foreign responder in the journal). A wedge, a foreign responder, or a
  never-activated listener set fails the unit at its 3-min bound instead
  of hanging forever (the pbx-artmann 43-min burn, nix-email#4;
  `stalwart-bind-e2e` pins both the bootstrap and the refusal).
- **Reload does NOT re-bind listeners on 0.16.22** (upstream #352, open
  since 2024): the vendored unit's `ExecStartPost` stalwart restart is the
  workaround; plan-changing deploys bounce the mail ports for seconds
  (tolerance question = C46).
- **0.16.22 ships broken default DNSBL rows**: 18 default
  SpamDnsblServer rows carry `bit_and` tag expressions the 0.16.22 parser
  rejects ("Invalid variable or constant"), failing EVERY reload validation
  and silently preventing provisioned config from activating. Fixed
  upstream in 0.16.23 (commit `87de8601`); the wrapper ALWAYS reconciles
  the DNSBL set (empty by default), destroying the broken rows at apply.
- **Reload validation resolves configured addresses through the system
  resolver**: a DNS-less VM (or a black-hole dnsmasq upstream) fails the
  SpamPyzor#singleton validation ("Invalid address: failed to lookup
  address information") and the apply aborts before listeners spawn. VM
  nodes provision `DnsResolver."@type" = "Cloudflare"` (same patch as the
  upstream 0.16 NixOS test) and dnsmasq forwards upstream to 10.0.2.3.
- **Misc 0.16 facts**: durations are integer milliseconds; account
  passwords are zxcvbn-enforced; `.invalid` hostnames are REJECTED
  ("Invalid hostname or IP address ... defaultHostname" - the demo renamed
  to `.test`); `hostname` becomes the provisioned Domain value (accounts
  synthesize `name@<hostname>`; keep them equal or addresses land outside
  the local namespace: auth 535, MAIL FROM 501); `--export`/`--import` are
  GONE (backup answer TBD); the web admin moved to `/admin` (downloadable
  Application bundle; the bare `/` root is 4xx); the fallback admin is a
  REQUIRED systemd credential (the provisioning CLI's only auth path);
  `stalwart-cli` >= 1.0.2 required (pin ships 1.0.12).
- **0.16 report features (upstream CHANGELOG-verified 2026-10-16; docs
  fetched 2026-10-17)**: DMARCbis - RFC 9989/9990/9991 - landed in 0.16.12
  (2026-07-06); 0.16.x natively imports inbound DMARC AND TLS aggregate
  reports; `inboundReportMaxSize` bounds them. RESOLVED 2026-10-17
  (stalw.art/docs/mta/reports + /analysis): 0.16 also RECEIVES AND PARSES
  inbound authentication-failure reports (DKIM/SPF/DMARC ARF) - governed by
  `inboundReportAddresses` / `inboundReportForwarding` /
  `holdMtaReportsFor`. C42 evidence base complete: parsedmarc's remaining
  unique value = file sinks + arbitrary-mailbox polling. RUNTIME-VERIFIED
  2026-10-26 on the pin (stalwart-e2e subtest 16b, transcript in the gate
  log): an RFC 5965 `message/feedback-report` with `Feedback-Type:
  auth-failure` sent to the configured report recipient is CONSUMED (never
  in the INBOX), while a report-LESS message to the SAME address IS
  delivered - so the detector is report-specific, not address-wide.
  Detection for ARF is MIME-typed, not filename-based (upstream
  `crates/smtp-report/src/arf/parse.rs` requires a
  `message/feedback-report` part carrying a recognised `Feedback-Type`;
  the aggregate detector instead keys on the attachment NAME - the
  asymmetry is why a single filename-shaped probe proves nothing about
  ARF). At default tracing verbosity 0.16 logs nothing per message, so
  the runtime evidence is the delivery outcome, not a journal event.
- **Contacts surface (CardDAV + JMAP contacts, probe-pinned on the
  deployed pin 2026-10-19/20; transcripts
  `docs/probes/2026-10-19-carddav-demo-vm/`)**: the HTTP listener serves
  full CardDAV (discovery chain, MKCOL books, conditional PUT, multiget,
  addressbook-query, sync-collection) and JMAP contacts
  (`urn:ietf:params:jmap:contacts` at `/jmap/`, trailing slash required;
  card ids server-assigned, UID preserved). Dialect notes that bit the
  CRM mirror: PUT onto an EXISTING card requires `If-Match`
  (unconditional -> 412); a PUT whose vCard UID differs from the stored
  card's -> 412 `no-uid-conflict` even with the correct etag; card
  ingestion is ASYNC (address-data renders partial, then normalized -
  KIND upper-cased, TEL leading `+` stripped - once the import settles,
  etag stable); sync-collection REQUIRES `<D:sync-level>1</D:sync-level>`
  in the body (silent-empty otherwise; the HTTP Depth header is ignored
  for that report); DAV result sets cap at `WebDav.maxResults` 2000.
- **AddressBook knobs (source-verified 2026-10-19, defaults healthy -
  document, do not expose)**: `AddressBook.maxVCardSize` 512 KiB (enforced
  on JMAP set + DAV address-data), `vCardVersion` V4, `maxAddressBooks`
  250, `maxContacts` unlimited. Exposure path if ever needed: registry
  `AddressBook` object via the provision pattern.
- **Spam x contacts: ZERO coupling** (checked 2026-10-19 for the CRM
  out-mirror): no contact/addressbook reference anywhere in spam-filter
  or SMTP delivery crates; the addressbook does not influence
  classification (consistent with the 10-18 "may land in Junk Mail"
  finding).
- **No webmail/frontend assets ship in the package** (nixpkgs
  `stalwart_0_16` 0.16.22 store path inspected 2026-10-20): only
  `bin/stalwart` + `bin/migrate_v0_16`; zero webmail references in the
  source tree. The webmail/admin UIs are separate runtime-fetched
  frontend bundles (the admin is the downloadable Application bundle at
  `/admin`) - the module's contacts story is API-surface only.
- **The 0.16 admin bundle is a SEPARATE package output, and its spelling
  changed** (re-verified 2026-10-26 against the pin): `stalwart_0_16`
  exposes `passthru.webui` = `webui-1.0.10` containing `webui.zip` (the
  admin Application bundle). The 0.15 alias `pkgs.stalwart` (0.15.5)
  exposes `passthru.webadmin` instead, containing `webadmin.zip`. The
  module's `webadmin.resource` default used to spell a bare
  `cfg.package.webadmin`. 2026-10-26 probe correction of the earlier
  "a 0.16 consumer with an http listener would hit it" claim: that
  consumer CANNOT - the whole webadmin block lives in the module's
  PRE-0.16 settings branch, so on 0.16 `settings.webadmin` does not
  exist at all (three-shape eval probes). The real landmine is the
  else-branch expression against a webui-only package (forced-branch
  repro: `stalwart_0_16.overrideAttrs (_: { version = "0.15.99"; })` +
  an http settings listener threw `attribute 'webadmin' missing`
  pre-fix, eval transcripts 2026-10-26). The vendored copy now carries
  the version-aware default (`? webui` -> webui.zip, else
  webadmin.zip; zero behavioral delta proven: 0.15 line identical, 0.16
  line dormant both sides); upstream #552103 (identical shape at head
  9b15e1f) has the fix drafted in
  `docs/drafts/552103-webui-resource-comment.md` - owner-review-gated
  (gh auth LIVE since 2026-10-30). User webmail remains a non-goal (C34):
  Bulwark on the consumer host is the JMAP-native client.

### Stalwart 0.15.5 era (historical facts; several are superseded above)

- nixpkgs `services.stalwart` ran **0.15.5**; `stalwart_0_16` existed but
  was module-incompatible - THIS FLAKE NOW VENDORS the 0.16 module (PR
  #552103) and runs `stalwart_0_16`; the bullets below describe the 0.15.5
  world unless marked otherwise.
- TLS cert key is `certificate.self-signed` (NO `.default` level) - verified
  against the binary and a live handshake. Without any cert, implicit-TLS
  listeners log "No TLS certificates available" and serve nothing.
- parsedmarc 11: connection settings MUST be in the `[imap]` ini section
  (missing host/user/password raises ConfigurationError); `[mailbox]` is
  behavior flags only. nixpkgs' typed `_secret` support exists only on
  `settings.imap.*`. There is NO SQLite sink; JSON/CSV files are the
  zero-dependency output. A `[postgresql]` sink exists but needs the
  `psycopg` extra (not in the nixpkgs package; psycopg 3.3.4 is available
  for an override).
- parsedmarc `_secret` values must be absolute path STRINGS
  (`password._secret = "/run/secrets/dmarc-imap-password";`) - the nixpkgs
  ini generator gates on `isString v._secret` and THROWS on path values
  ("unsupported type path"), and path literals are forbidden in flake source
  anyway (pure eval). Corrected 2026-09-15: an earlier phrasing here said
  "PATHS, not strings", which read as "path values" - it always meant
  "a path pointing at the secret file, given as a string".
- swaks marks SMTP error-response lines with `<**`, success with `<-`, AND
  (observed 2026-09-15, relay VM) a 550 RCPT refusal can arrive with the
  `<~*` marker (its timeout-receive variant) - assert the marker set you
  OBSERVED in the transcript, never the one you expected; tests need
  `--timeout 120` because RCPT policy checks (SPF/DNSBL) stall ~30 s per
  lookup in a DNS-less VM. Also (host-verified 2026-09-16, swaks
  20240103.0): `--attach <path>` attaches the path STRING as literal data
  with NO filename= header - reading a file requires the @-prefix
  (`--attach @/path/file.zip`), which also sets filename= from the
  basename. A silently-literal attach is why the native-ingestion subtest
  first ran empty: Stalwart's report detector matches '!' / '.xml' in the
  attachment NAME, and a nameless string part matches nothing - no error
  anywhere, the message is just consumed and dropped.
- Two "Configuration build error" journal lines at startup in the DNS-less
  VM are BENIGN (details only visible via `journalctl -o verbose`):
  `resolver.type: no nameservers found in config` (nixpkgs module default
  `resolver.type = "system"` + empty resolv.conf) and
  `spam-filter.pyzor.host` lookup failure. A host with a resolver hits
  neither.
- The self-signed cert (`certificate.self-signed`, generated by rcgen) is
  created ASYNCHRONOUSLY at first start and can take >80 s in the
  entropy-poor DNS-less VM - implicit-TLS checks must POLL, not single-shot
  (this is what made the pre-account E2E test flaky).
- Stalwart downloads ASN/Geo IP data from cdn.jsdelivr.net at first start -
  offline environments log "Resource error" lines (benign) and need egress.
- Hetzner Cloud port policy (VERIFIED against docs.hetzner.com/cloud/servers/faq,
  "Why can I not send any mails from my server?", 2026-09-14): ports 25 and
  465 are blocked BY DEFAULT on all cloud servers, enforced per account,
  both directions. Unblock via a limit request after 1 month + first paid
  invoice (case-by-case). Port 587 is never blocked. Consequence: the
  hybrid design is safe on outbound (relay via 587), but INBOUND MX on :25
  requires the unblock before go-live - the community guides claiming
  "Hetzner port 25 open by default" are outdated.
- Metrics (VERIFIED against v0.15.5 source): `metrics.prometheus.enable =
  true`, optional `metrics.prometheus.auth.username`/`auth.secret` (HTTP
  basic auth). Endpoint is `/metrics/prometheus` ON THE HTTP LISTENER - with
  the loopback default that means a reverse-proxy route or ssh tunnel for
  Prometheus; do not expose the whole admin port for it.
- Outbound relay (VERIFIED against v0.15.5 source, closes the old "do not
  guess" item): since 0.13 routing is expression-based. A smarthost is
  `[queue.route."<id>"]` with `type = "relay"`, `address`, `port`,
  `protocol = "smtp"`, `auth.username`, `auth.secret`, optional
  `tls.implicit`. Select it with `queue.strategy.route` (an expression;
  default routes local domains to `'local'`, everything else to `'mx'`).
  The nixpkgs module ASSERTS against the pre-0.13 `queue.*.next-hop`.
  LIVE SPIKE 2026-09-14 (local binary + Mailpit): (a) an IfBlock route
  needs INDEXED keys - `queue.strategy.route.1.if` / `.1.then` /
  `.2.else`; a bare `if`/`then`/`else` fails to parse, and `else` must
  sort AFTER `if` (else-before-if is a parse error); (b) the relay
  address is resolved via DNS A lookup - a bare IP literal fails with
  "record not found for MX", so use a resolvable hostname
  (e.g. `smtp.resend.com`); (c) Stalwart REFUSES to relay to loopback
  addresses ("host resolves loopback address") - a good SSRF guard, and
  the reason the VM E2E cannot exercise the smarthost path.
- Bootstrap admin (VERIFIED): `authentication.fallback-admin.user`/`.secret`
  work with an empty internal directory. This is how the E2E test gets an
  admin declaratively (the upstream reference config ships exactly this).
- Account provisioning API (VERIFIED against webadmin source + live VM):
  `POST /api/principal` (basic auth as admin) with `{"type": "individual",
  "name": ..., "emails": [...], "secrets": ["<sha512-crypt $6$ hash>"]}` -
  passwords are hashed CLIENT-side (pwhash sha512_crypt format).
  `{"type": "domain", "name": ...}` makes a domain local (returns
  `{"data": <id>}`). DKIM keygen via `POST /api/dkim`. GOTCHA: individuals
  need `"roles": ["user"]` - without it auth succeeds but submission is
  refused with 550 5.7.1 "not authorized to use this service" (the webadmin
  adds the role silently).
- Local-domain routing (VERIFIED in VM + source read, 2026-09-14): the
  default queue route is `is_local_domain('*', rcpt_domain) -> 'local'`,
  else MX. The directory NEGATIVELY caches `is_local_domain` misses for
  1 HOUR (`directory.<id>.cache.ttl.negative`, default 3600s, e.g.
  `directory."internal".cache.ttl.negative`;
  crates/directory/src/core/cache.rs - positive cache is 24h). Consequence:
  ANY SMTP traffic (even a MAIL FROM probe) touching a domain before it is
  provisioned poisons the cache and routes that domain's mail to the MX
  path - in the VM that means DNS timeouts, never local delivery. Provision
  domains before first traffic, or lower the negative TTL on dev/test hosts.
- DKIM signing (VERIFIED): keys live under `signature.<id>` with
  `algorithm` (`rsa-sha256`/`ed25519-sha256`), `private-key` (inline PEM,
  supports `%{file:...}%` macros), `domain`, `selector`. `auth.dkim.sign`
  is an expression defaulting to sign local-domain mail with ids
  `['rsa-' + sender_domain, 'ed25519-' + sender_domain]` - exactly the ids
  the webadmin generates via `POST /api/dkim`.
- TLS/ACME (VERIFIED key names): manual certs are `certificate.<id>.cert`
  - `certificate.<id>.private-key`; built-in ACME is `acme.<id>.directory`,
    `.contact`, `.challenge`, `.renew-before` (default 30d), DNS-challenge
    extras `.origin`, `.polling-interval`, `.propagation-timeout`.
- nixpkgs module secret injection: `services.stalwart.credentials` (attrsOf
  path) becomes systemd LoadCredential files, referenced in settings as
  `%{file:/run/credentials/stalwart.service/<key>%}` - the sops-compatible
  way to feed the relay and admin secrets.
- Inbound auth defaults need NO config: SPF/DMARC/iprev verification only
  runs on port 25 (`local_port == 25` conditions), disabled on submission
  ports; DKIM verify is `relaxed` everywhere.
- Stalwart's system resolver reads ONLY /etc/resolv.conf - it IGNORES
  /etc/hosts (observed 2026-09-15, relay VM: dnsmasq on 127.0.0.1 bridging
  /etc/hosts made `relay` resolvable; the NixOS test driver's /etc/hosts
  injection alone did not). Same mechanism any VM test needs for hostname
  relay targets.
- Stalwart's OWN resolver is NOT the system resolver by default (VERIFIED
  2026-11-02, deliverability-e2e take-4 transcript): inbound sender-auth
  (SPF/iprev) post-DATA lookups ignored the node's local dnsmasq
  (`/etc/resolv.conf` pointed at it) and went to an external resolver the
  driver network black-holes - EHLO/MAIL/RCPT/DATA-354 all 0.0 s, post-DATA
  reply > 25 s, inbound canary dead at socket timeout. Pointing stalwart at
  a local resolver is the `DnsResolver` provision singleton in the 0.16
  object dialect, discovered through the Lua typecheck ladder (`unknown key
  resolver` -> `expected object DnsCustomResolver` -> `unknown key @type` on
  the array element -> accepted): `DnsResolver."@type" = "Custom";
  DnsResolver.servers = [{address = "127.0.0.1";}]` - array elements carry
  NO `@type`. Contrast the DNS-less-VM `Cloudflare` singleton (module
  verdict above): same singleton id, different `@type` payload.
- The nixpkgs parsedmarc unit runs as a DynamicUser and prepares NO writable
  state; parsedmarc 11.0.1 os.makedirs()es its output directory on first
  write, which fails on root-owned /var/lib without `StateDirectory`
  (verified 2026-09-15 against parsedmarc.nix + parsedmarc/**init**.py:3478;
  the wrapper now sets StateDirectory).
- `mkDefault` lists on `networking.firewall.allowedTCPPorts` are silently
  dropped (ROOT-CAUSED 2026-09-15, closing the 2026-09-14 symptom-only
  entry): `lib/modules.nix filterOverrides'` keeps only numerically-lowest
  priority definitions - lists concat WITHIN a tier, never across - and base
  nixpkgs ships unconditional `[]` defs at priority 100 on that option from
  modules whose services are DISABLED: podman `network-socket.nix:95`
  (`lib.optional (enable && openFirewall) port`) and `udp-over-tcp.nix:276`
  (`getFirewallPorts`). Verified via
  `options.<name>.definitionsWithLocations` (the debugging tool for any
  "where did my definition go" mystery) plus a priority bisect (100
  survives, 101 drops). The `lib.optional`-instead-of-`mkIf` shape is the
  upstream anti-pattern: `mkIf false` contributes NO definition, an
  evaluated `[]` still wins its priority tier. `services.openssh.ports` has
  no such base def, which is why mkDefault works fine there.
- Dovecot 2.4 (this nixpkgs pin) ASSERTS on explicit
  `dovecot_config_version`/`dovecot_storage_version` - and nixpkgs'
  parsedmarc `provision.localMail` enables dovecot2 WITHOUT them (also
  still uses the renamed `services.dovecot2.protocols`, warning-only).
  Any localMail consumer must pin both versions itself
  (`tests/parsedmarc-e2e.nix` does; found 2026-09-15). Same migration also
  renamed the UNIT: `systemd.services.dovecot` (was `dovecot2.service`) -
  `wait_for_unit "dovecot2.service"` fails with "inactive, no pending jobs"
  even though dovecot is running (observed in parsedmarc-e2e, 2026-09-15).
  SUPERSEDED SURFACE 2026-10-28 (fe132422, PR #566282): localMail no
  longer wires dovecot AT ALL (postfix + a `[maildir]` watch only), so
  this trap now bites only test-owned dovecot stacks - the e2e's `tls`
  node pins both versions for exactly that reason; historical evidence
  below stays.
- Per-account storage QUOTA (VERIFIED in VM, 2026-09-15; 0.16.22 delta
  2026-10-17): the `quota` principal field is an integer byte count on
  any individual. An over-quota message is ACCEPTED at SMTP but never
  delivered - there is no 5xx rejection at SMTP time (0.16.22 exact
  acceptance line: `250 2.0.0 Message queued with id <id>`). Assert
  delivery-absence (IMAP), not SMTP refusal. JOURNAL GOTCHA (0.15,
  VM-observed 2026-09-15): the reason string "Mailbox over quota." was
  never logged at default verbosity - the retry's journal signature was
  `Message rescheduled for delivery`. 0.16.22 SUPERSEDES both facts: the
  journal is SILENT on over-quota mail (no quota/retry/reschedule/4xx
  line, the queue id is never re-mentioned, 200 s observation across
  three debug-driver boots, 2026-10-17) - do not grep for EITHER string
  on 0.16; assert journal silence instead (the e2e does).
- CATCH-ALL vs unknown-recipient rejection is a TEST-ORDERING trap
  (observed 2026-09-15): a principal with the literal `"@<domain>"` address
  (AddressMapping retries the lookup with `@<domain>`) makes EVERY local
  part deliverable - `RCPT TO:<nobody@example.test>` then answers
  `250 2.1.5 OK` and any "unknown recipient rejected 5xx" assertion fails.
  Create the catch-all principal AFTER the rejection probe (the E2E does).
- Spam filter DEFAULTS (GTUBE, VM 2026-09-15): the built-in rule filter
  scans authenticated submission on 587 too, adds `X-Spam-Status` (GTUBE
  in the BODY triggers; subject-only text does not match the rule).
  CORRECTED 2026-09-22 (do not trust the old absolute): "no server-side
  auto-filing into Junk" no longer holds universally - on the demo VM
  (live slirp DNS, same 0.15.5 + spam-filter-2.0.5 resource) an
  unauthenticated external no-SPF message WAS auto-filed to Junk Mail
  (`X-Spam-Status: Yes`, score 13.50), while GTUBE-tagged submission
  stayed in INBOX in the DNS-less E2E on the same pin (re-run green
  2026-09-22). Filing fires under a condition these two experiments do
  not isolate - the exact threshold/mechanism is UNVERIFIED; assert
  neither behavior as universal. Journal noise to expect: "Spam
  classifier model not found" (the statistical classifier has no trained
  model; the rule engine works without it). IMAP LOGIN resolves by
  principal NAME, not by the principal's email addresses: a principal
  named `catchall` with email `catchall@example.test` cannot log in as
  the email address, only as `catchall` (accounts whose name IS their
  address never trip this).
- NIXPKGS BUG (workaround shipped 2026-09-15; filed upstream as
  NixOS/nixpkgs#563651): with
  `provision.elasticsearch = false`, the parsedmarc module's settings
  submodule still MATERIALIZES `elasticsearch.cert_path` (types.path,
  defaults to the CA bundle) and `.ssl` (types.bool, defaults false).
  Both survive the module's null/[]/{} config filter, so the rendered ini
  carries `[elasticsearch]` with no `hosts` - and parsedmarc 11 raises
  "hosts setting missing from the elasticsearch config section"
  (ConfigurationError, exit 255) at start. Neither key can be nulled
  through its option type, so `modules/dmarc-monitor.nix` strips the
  section from the RENDERED ini via a guarded `ExecStartPre` (only while
  ES is off); `tests/dmarc-eval.nix` asserts the workaround stays wired.
  Upstream-able: the module should not emit the section when ES is not
  provisioned. Re-checked against nixpkgs MASTER 2026-09-15: still present
  (`elasticsearch.ssl`/`.cert_path` defaults pass the same
  `lib.filterAttrsRecursive` null/[]/{} filter), so the issue is still live
  upstream, not stale. **PORTED 2026-10-28 at the fe132422 pin advance**
  (PR #566282 in-pin): the option is now `provision.opensearch`
  (`mkRemovedOptionModule` on the elasticsearch name) and the host-less
  section materializes as `[opensearch]` - same guarded strip, renamed
  script, asserted by `tests/dmarc-eval.nix` (green) and the
  parsedmarc-e2e ini assertion.
- NIXPKGS BUG (workaround shipped 2026-09-15; filed upstream as
  NixOS/nixpkgs#563652): on this rev the NixOS
  python scope resolves imapclient 3.1.0 for parsedmarc, and 3.1.0 is
  incompatible with python 3.14 (the VM's interpreter): its
  `IMAP4WithTimeout.open()` assigns `self.file`, a read-only property
  since 3.14 - parsedmarc dies at the first IMAP connect with
  AttributeError (exit 255) before any polling happens. The SAME rev
  ships parsedmarc 11.0.1 on python 3.13, where 3.1.0 still works, so
  the wrapper pins the unit's ExecStart to the python3.13 build (same
  version, same CLI, same ini contract). `dmarc-eval` asserts the pin.
  Revert when nixpkgs ships an imapclient compatible with 3.14's
  imaplib. Upstream status 2026-09-15: imapclient 4.0.1 (the version on
  nixpkgs master) DROPPED the `imap4.py` `open()` override entirely, so
  the common connect path is fixed - but `imapclient.py` `starttls()`
  still assigns `self._imap.file`, so 4.x on python 3.14 still breaks the
  STARTTLS-upgrade path (`lib/python3.14/imaplib.py:337` is the read-only
  property). Cite both halves when filing. **PIN REVERTED 2026-10-28**:
  the fe132422 pin ships imapclient 4.1.0 (`nix eval` 2026-10-28) and
  parsedmarc 11.0.2 on the DEFAULT py3.14 scope, so the wrapper dropped
  the py3.13 `parsedmarcPackage` pin and the `ExecStart = mkForce`
  override; `tests/dmarc-eval.nix` now asserts the module's own
  `python3.14-parsedmarc` ExecStart.
- mailsuite (parsedmarc's IMAP layer) AUTO-ACTIVATES STARTTLS whenever the
  server advertises the capability (mailsuite/imap.py:284: `if not ssl and
  b"STARTTLS" in self.capabilities()`). A dovecot that advertises STARTTLS
  without usable certificate material therefore breaks plaintext-IMAP
  consumers with `SSL: WRONG_VERSION_NUMBER` at connect - the VM's
  localMail dovecot needed `ssl = "no"` (plaintext fixture, no cert
  material; production rua mailboxes use real TLS). Found while bringing
  `tests/parsedmarc-e2e.nix` green, 2026-09-15.
- The upstream sample DMARC report (estadocuenta1...2940.xml.zip) parses
  with org_name "XYZ Corporation" even though the FILENAME says
  infonacot.gob.mx - parsedmarc reads the XML body, so assertions must use
  the body's metadata. (This bit nobody once, exactly once - 2026-09-15.)
- IMAP/IMAPS LOGIN resolves by principal NAME (VM-verified 2026-09-15 via
  curl-imaps probe): a principal named `catchall` with email
  `catchall@example.test` CANNOT log in as the email address, only as
  `catchall`. Accounts created by the webadmin never trip this because
  their name IS their address - a scripting/API-created account with a
  non-address name must be probed by name.
- CAPABILITY AUDIT vs 0.15.5 (2026-09-15; method: grep of the v0.15.5 git
  tag source tarball + vendor compare page + v0.16.0 release notes - a
  source-tag audit, NOT live-binary proof; presence claims below still need
  runtime confirmation before wiring): automated DKIM rotation and automated
  DNS management are **0.16.0 features** (not on this pin - the manual
  `POST /api/dkim` recipe and Terraform-as-DNS-truth stand); native
  DMARC/TLS-RPT/ARF ingestion IS on 0.15.5 (`smtp/src/reporting/`, report
  store family, CLI/management readout) and is kept as a free complement to
  parsedmarc, not a replacement; OIDC, TOTP, encryption-at-rest, autoconfig,
  POP3, JMAP-WS, MTA-STS/DANE, Zenoh clustering are present in the 0.15.5
  source; PROXY protocol is NOT (0.16+). Verdicts live in
  `docs/planning/archived/2026-09-15_19-23_nix-email-pareto-master-plan.md` §10.
- SIEVE/JUNK-FILING architecture in 0.15.5 (source-verified 2026-09-15
  against the pinned store source, while implementing wrapper-owned Junk
  filing - it is NOT implementable via settings):
  - Settings keys exist (`sieve.trusted.scripts.<id>.contents`,
    `sieve.untrusted.scripts.<id>.contents`; crates/common/src/config/
    scripts.rs `Scripting::parse`) - but the TRUSTED runtime is built with
    `.without_capabilities([FileInto, Mailbox, ...])` (same file), so a
    settings script can NEVER file a message anywhere.
  - Delivery-time sieve runs ONLY the recipient account's ACTIVE script
    fetched from the STORE (crates/email/src/message/delivery.rs:
    `sieve_script_get_active(account_id)`; `None` -> plain INBOX ingest -
    which is why GTUBE mail lands in INBOX).
  - Settings-defined UNTRUSTED scripts are include-libraries for user
    scripts (crates/email/src/sieve/ingest.rs:187), not entry points.
  - `X-Spam-Status` is added at ingest from the SMTP-session spam verdict
    (crates/email/src/message/ingest.rs:319).
  - Q6 RESIDUE RESOLVED (2026-10-05, source-verified against upstream ref
    v0.15.5): the "auto-move-to-Junk" has NO setting name - it is
    HARD-CODED in crates/email/src/message/ingest.rs:344 (`if is_spam &&
    params.mailbox_ids == [INBOX_ID] { params.mailbox_ids[0] = JUNK_ID;
    params.keywords.push(Keyword::Junk); }`), inside the
    `self.core.spam.enabled` block of the Smtp ingest arm; classification
    itself only runs for UNAUTHENTICATED sessions (crates/smtp/src/inbound/
    spam.rs: `if !self.is_authenticated()`). The only knobs are
    `spam-filter.enable`, the score thresholds
    (`spam-filter.score.spam`/`.reject`/`.discard`), and the
    card-is-ham/trusted-reply overrides. Upstream CHANGELOG 0.5.0 (2023):
    "Messages marked as spam by the spam filter can now be automatically
    moved to the account's Junk Mail folder" - the behavior ships
    unconditionally, no key ever existed (which is why the 2026-09-23
    binary-strings sweep found none). Consequence for Q6: a wrapper
    `junkFiling` option CANNOT exist as a Stalwart setting; the (c)
    tag-only posture stands.
  - No OSS management-API endpoint sets an account's active sieve script
    (JMAP per-account, or the enterprise webadmin) - the OSS CLI has no
    sieve subcommand either.
    Consequence: Junk filing on this pin is per-account (webmail-managed
    sieve or per-account JMAP automation), not declarable from the wrapper.
    Revisit if 0.16+ grows server-side filing.
- Stalwart's TOML parser (BINARY-VERIFIED 2026-09-16, pinned 0.15.5, a/b
  probe with the local binary) REJECTS a fully-quoted dotted table header:
  `["report.analysis"]` fails with "Invalid configuration file: Unexpected
  end of line" at exactly the header's line. Bare-dotted (`[report.
  analysis]`) and mixed (`[signature."rsa-example.test"]`) headers parse
  fine. Consequence for settings style: nest via real attr structure
  (`settings.report.analysis = {...}`), never a dotted-string attr key
  holding a table (`settings."report.analysis" = {...}` renders the broken
  quoted header; scalar dotted-string keys like `"server.hostname"` are
  fine).
- nixpkgs mailpit module freeform keys (BINARY-VERIFIED 2026-09-16, mailpit
  1.31.0 usage dump + startup probes): `services.mailpit.instances.<id>`
  freeform attrs go through `lib.cli.toCommandLineGNU` VERBATIM - there is
  no camelCase/underscore mangling, so flag names must be written as
  DASHED, QUOTED attr keys (`"smtp-auth-file" = "/etc/...";`). A camelCase
  key (`smtpAuthFile`) renders the literal `--smtpAuthFile`, an unknown
  flag, and mailpit exits 1 at start. Also: with a PLAIN `user:pass` auth
  file and no TLS on the SMTP listener, mailpit REFUSES TO START
  ("authentication requires STARTTLS or TLS encryption") unless
  `"smtp-auth-allow-insecure" = true;` is set - the flag pair for
  plaintext test hops.
- Import-and-eval inside `{pkgs}` tests (bit dependabot PR #1's CI
  2026-09-16): `import "${pkgs.path}/nixos"` accepts ONLY
  `{configuration, system, specialArgs}` on the pinned nixpkgs - a
  `modules` argument throws "function called with unexpected argument".
  Use `import "${pkgs.path}/nixos/lib/eval-config.nix" { system = ...;
  modules = [...]; }` (what `lib.nixosSystem` bottoms out in; the green
  dmarc-eval pattern).
- INCOMING vs QUEUED report endpoints (SOURCE-VERIFIED 2026-09-16 against
  v0.15.5 + its bundled openapi.yml, closing the "store stays empty"
  mystery): native ingestion writes to the report value store
  (`ValueClass::Report(ReportClass::Dmarc)`, gated on
  `report.analysis.store`, default "30d" - the write happens with NO
  explicit setting) and the readout is `GET /api/reports/dmarc`
  (management/report.rs, `IncomingReportList`). `GET /api/queue/reports`
  is a DIFFERENT thing entirely: the OUTBOUND report queue
  (management/queue.rs, `OutgoingReportList` - reports Stalwart itself
  will send), permanently `total:0` on a host that schedules no outgoing
  reports. Both return the same `{"data":{"items":[...],"total":N}}`
  shape, so polling the wrong one looks like a write-side bug but is not.
  EXTRA shape trap: `/api/reports/dmarc` list items are `"<id>_<expires>"`
  STRINGS (not objects) - the detail URL is `/api/reports/dmarc/<item>`
  verbatim. (The 0.15.5 CLI `report list` command itself GETs
  `/api/queue/reports` - do not copy it as an incoming-reports recipe.)
- DKIM API keygen needs an explicit reload, and the reload can SILENTLY
  NO-OP (SOURCE-VERIFIED 2026-09-16 against v0.15.5 + VM transcript):
  `POST /api/dkim` writes `signature.<id>.*` via `config.set(...)`, which
  is store-only - no broadcast, no core rebuild (manager/config.rs) - and
  the SMTP signing path resolves signers from the startup-built
  `signatures` map (core.rs `resolve_signature`), so submissions keep
  logging "DKIM signer not found" until `GET /api/reload` swaps in a
  rebuilt core. Second trap on top: the reload handler only matches
  `Method::GET` for the plain reload, and `reload()` returns WITHOUT a
  new core while ANY config error exists (manager/reload.rs
  `if !config.errors.is_empty() { return }` before new_core) - the
  response is still HTTP 200 with an `errors` dict. In the DNS-less test
  VM the default pyzor host lookup (`spam-filter.pyzor.host` ->
  public.pyzor.org) fails at build time and pins EVERY full reload; the
  test disables `spam-filter.pyzor.enable` so reloads actually apply.
  Operational read for live hosts: if a settings reload "did nothing",
  check the response body's `errors` first.

- Monitoring/observability config keys (SOURCE-VERIFIED 2026-09-22 against
  the pinned v0.15.5 tarball, store-path grep - do not re-derive):
  (a) METRICS: `metrics.prometheus.enable` (default false; telemetry.rs:626)
  with optional `metrics.prometheus.auth.username`/`auth.secret`; endpoint
  `/metrics/prometheus` on the HTTP listener; series names are trc-driven
  (prometheus.rs renders Collector counters/gauges/histograms). (b)
  TELEMETRY: `tracing.level.<event>` per-event levels (telemetry.rs:167)
  and `tracing.history.enable` + `tracing.history.store` (telemetry.rs:529)
  for store-backed event history. (c) RATE LIMITS:
  `queue.limiter.inbound.<id>` / `queue.limiter.outbound.<id>`
  (queue.rs:563,612) with sub-keys `enable` (default true), `key` (one or
  more of rcpt, rcpt_domain, sender, sender_domain, remote_ip, auth_as,
  helo_domain, listener, local_ip - throttle.rs:87), optional `match`
  expression, and REQUIRED `rate` ("requests/period" Rate; throttle.rs:80).
  (d) SPAM-FILTER DNSBL: `spam-filter.dnsbl.server.<id>.{enable,scope,...}`
  - `spam-filter.dnsbl.max-check.{ip,domain,email,url}`
    (spamfilter.rs:268-304) - this is CONTENT-analysis DNSBL inside the spam
    filter, NOT a connection-level client-IP blocklist (no such static key in
    0.15.5). (e) AUTO-EXPUNGE: `email.auto-expunge` (default 30d) and
    `email-submission.auto-expunge` (default 3d) purge destroyed/expired JMAP
    emails (jmap/settings.rs:282-286) - already active by default; there is
    NO per-mailbox (Junk-only) expunge knob. (f) AUDIT: NO audit-log config
    surface exists in 0.15.5 (zero `audit` strings in the crates) - the audit
    trail is `tracing.level.*` verbosity + journald/history-store retention.
    (g) AUTOCONFIG: the HTTP crate serves Thunderbird autoconfig XML
    (`crates/http/src/autoconfig/mod.rs`, routes in request.rs:321-331/475
    incl. `.well-known` + `config-v1.1.xml`) on the existing HTTP listener -
    no server wiring needed; client discovery is DNS-side (autoconfig./SRV).
    (h) TLS-RPT CONSUMPTION: parsedmarc 11.0.1 (the nixpkgs pin this flake
    ships) parses RFC 8460 reports - `parse_smtp_tls_report_json`
    (`parsedmarc/__init__.py:737` in the built package) - and the shared
    mailbox poll routes them (`report_type == "smtp_tls"`,
    `__init__.py:2124`), writing `smtp_tls.json/csv` next to the aggregate
    output. TLS-RPT rides the SAME rua mailbox as DMARC: point the
    `_smtp._tls` TXT `rua` mailto at the same mailbox - no new polling exists
    or is needed.
    (i) RATE LIMITING (2026-09-22, pinned source): v0.15.5 SHIPS two
    conservative inbound limiters via `DEFAULT_SETTINGS` (boot.rs:85-94) -
    `queue.limiter.inbound.ip`: key `remote_ip`, rate `5/1s` (burst) and
    `queue.limiter.inbound.sender`: keys `[sender_domain, rcpt]`, rate
    `25/1h`. Limiter schema (throttle.rs:53-87, queue.rs:563-641):
    `queue.limiter.inbound.<id>.{enable,key,match,rate}`, `key` is a string
    OR list from exactly: rcpt, rcpt_domain, sender, sender_domain,
    `authenticated_as` (NOT "auth_as"), listener, mx, remote_ip, local_ip,
    helo_domain; `rate` = `<digits>/<digits><ms|s|m|h|d>`
    (utils/config/utils.rs:594-620) and "false"/"none"/"unlimited" silently
    DISABLE the limiter (zero-request rate filtered, throttle.rs:56-58).
    Multiple limiters stack: every matching one must allow. Enforcement is
    connection-gating (`session.is_allowed()`, inbound/spawn.rs:45), so a
    tripped limiter is a pre-SMTP hangup, not a 4xx code. The wrapper's
    `services.mail-server.rateLimits` is therefore OPT-IN (default OFF):
    enabling stacks a sustained-volume damper NEXT to the upstream pair.
    (j) DNSBL (2026-09-22, pinned source): v0.15.5 has NO master switch -
    `spam-filter.dnsbl.server.<id>` entries ARE the switch (none shipped by
    default). Per-server: `scope` REQUIRED, exactly one of
    ip|domain|email|url (spamfilter.rs:268-320 + Element parse 579-592;
    header/body/any are unreachable in check_dnsbl, dnsbl.rs:37-45),
    `zone`/`tag` are IfBlocks that accept a single value, which MUST be a
    QUOTED expression constant (`zone = "'zen.spamhaus.org'"`) - unquoted
    strings die in the tokenizer with "Invalid variable or constant"
    (tokenizer.rs:342); `enable` per server defaults true (spamfilter.rs:297).
    Lookups happen in CONTENT ANALYSIS only (matches add spam tags; nothing
    is rejected at connection time, dnsbl.rs:19-57) and need working resolver
    DNS - hence the wrapper's `spamFilter.dnsbl.servers` defaults to `{}`.
    Caps: `spam-filter.dnsbl.max-check.{ip,domain,email,url}` (default "50"
    parsed, spamfilter.rs:276-286). RUNTIME-EVIDENCE PATH DECIDED 2026-09-22:
    documented eval-only (same doctrine as pyzor) - the wrapper's risk
    surface is the emitted config shape (quoted constants, scope enum),
    which `module-import-eval` already asserts; runtime lookup behavior is
    upstream's code against external zones, and the E2E VM is deliberately
    DNS-less (~60 s resolver-stall doctrine). First live-host run under D1
    provides the runtime evidence for free. (k) Demo-VM hostfwd "connects but never
    answers" (root-caused 2026-09-22, live-VM transcripts): the wrapper's
    firewall list opened only the four mail ports - a NON-loopback `httpBind`
    ("0.0.0.0:8080") was silently dropped by the guest firewall, so
    hostfwd/proxy connections opened (the proxy side had already accepted
    host-side) and then starved: in-guest loopback answered in 1.5 ms while
    host->18080 hung forever and SMTP ports flowed. Fix: the module opens
    the httpBind port exactly when the bind is non-loopback (the
    raw-exposure warning already covers the tradeoff). Lesson: "connects,
    never answers" behind a port-forward is a FIREWALL signature, not a
    transport bug. (l) systemd unit scripts do NOT inherit
    `environment.systemPackages` (demo provisioning transcript 2026-09-22):
    the oneshot's bare `curl` was "command not found" 120x, the `|| true`s
    masked it, and the unit exited SUCCESS having provisioned NOTHING. Fix:
    absolute store paths + `--max-time` in unit scripts, and fail loudly
    when a readiness gate exhausts. (m) A tripped inbound limiter is a
    pre-SMTP hangup, observed live 2026-09-22 on the default 5/1s
    per-remote_ip limiter (demo-VM flood: 12 rapid connections -> exactly 5
    SMTP banners + 7 empty/pre-banner hangups; matches (i)'s source cite).
    Assert hangups, never 4xx codes, when probing limiters. (n) Demo
    spam-filter behavior (transcripts 2026-09-22): unauthenticated external
    mail (no-SPF sender via slirp) files to Junk Mail (`X-Spam-Status: Yes`,
    score 13.50); authenticated :587 submission delivers to INBOX
    (`X-Spam-Status: No`). The spam-filter resource's ASN/GeoIP CSV
    downloads (cdn.jsdelivr.net, `[asn.urls]` in spam-filter-2.0.5) fail in
    the slirp NAT -> `Resource error` x3 + `Spam classifier model not
    found` at boot; non-fatal (lookups just miss).
- Management API `POST /api/reload` returns `{"data": <Config>}` and the
  serialized Config ALWAYS carries an `errors` array (only `keys` is
  skipped); the core swap is SKIPPED when errors is non-empty
  (source-verified v0.15.5: `http/src/management/reload.rs`,
  `utils/src/config/mod.rs`, `common/src/manager/reload.rs`). The e2e
  reload subtest asserts `.data.errors | length == 0` as a precondition -
  any config error silently no-ops a reload (the pyzor-disable note in the
  e2e is the same trap).

