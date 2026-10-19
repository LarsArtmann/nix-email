# Probe transcripts — 2026-10-19 CardDAV demo-VM drill (T04 + T17.1)

Session: execution of the CRM data-mesh CardDAV plan, tasks T04.2–T04.11 +
T17.1 (`crm/docs/planning/2026-10-19_04-09_data-mesh-carddav-pareto.md`).
One fresh boot of `nixosConfigurations.demo` (Stalwart **0.16.22**, the
deployed pin) via the FIFO-console pattern; host-side probes against
127.0.0.1:18080 (→ guest 8080) with `demo@mail.demo.test` basic auth.

## Files

- `vm-console-transcript.log` — boot + `systemctl is-active stalwart`
  (active) + provision diagnosis. NOTE: `stalwart-provision` exits FAILED
  on this disk — pre-existing at the 10-18 boot (journal 02:34) with the
  identical `SpamDnsblServer` tag-validation error (`bit_and` expression);
  accounts/domain/listeners reconcile fine, only the final `reload` action
  aborts. Unrelated to CardDAV; recorded, not fixed here.
- `carddav_probe.py` — the probe suite (python3 stdlib only). Canonical
  run sends `<D:sync-level>1</D:sync-level>` in every sync-collection and
  does case-insensitive header lookups (RFC 9110).
- `carddav-probe.log` — canonical transcript: **17/18 PASS** (the one FAIL
  is a genuine server fact, see verdict 4).
- `carddav-probe-run1-nolevel.log` — first run, kept as evidence for the
  sync-level deviation (verdict 5): probe bugs (case-sensitive headers)
  plus the no-sync-level server behavior, both since characterized.
- `carddav_diag.py` / `carddav-diag.log` — follow-up diagnostics D1–D3 +
  E1–E2 that source-verified the deviations.

## Key verdicts (all transcript-backed)

1. **Discovery chain fully works**: `/.well-known/carddav` → 307
   `/dav/card` (anon, any method); PROPFIND root → `current-user-principal`
   `/dav/pal/demo%40mail.demo.test/`; PROPFIND principal → carddav
   `addressbook-home-set` `/dav/card/demo%40mail.demo.test/`; PROPFIND
   Depth:1 enumerates books (incl. MKCOL-created ones). Discovery inputs
   for the CRM CardDAV client (plan T11.2) are proven on the pin.
2. **CRUD + concurrency contract holds**: MKCOL addressbook 201; PUT vCard
   4.0 → 201 + `etag` header (lowercase!); GET back 200 with etag; PUT
   vCard 3.0 → stored **normalized to VERSION:4.0** (TYPE params
   upper-cased, `TYPE=INTERNET` preserved); PUT with stale `If-Match` →
   412; with the real etag → 204 + new etag, UID preserved; duplicate UID
   → 412 `no-uid-conflict` naming the conflicting href.
3. **Query engine works**: addressbook-query EMAIL text-match contains →
   exact match set {card1, card2} (card2's `kith-v3@example.com` matches;
   card4's `other-domain@example.net` does not); param-filter
   `TEL`/`TYPE=cell` (case-insensitive equals) → 3 hits; `anyof` ⊇ `allof`
   semantics correct (2 vs 1). multiget returns etags + CDATA
   address-data. Supported reports: addressbook-multiget,
   addressbook-query, acl-principal-prop-set, expand-property,
   principal-match, sync-collection.
4. **PUT-time vCard validation is LENIENT (the one FAIL)**: a garbage card
   (`BEGIN:VCARD` / `NOPE: this is not a card` / `END:VCARD`, no VERSION,
   no FN) is ACCEPTED (201 + etag) and stored with `VERSION:4.0`
   **injected**, the unknown `NOPE:` property preserved verbatim (D1).
   The assessment's "strict parse" applies to the query/filter path, not
   PUT storage. Consequence for the out-sync design: never rely on
   server-side card validation.
5. **sync-collection requires `<D:sync-level>1</D:sync-level>` on this
   pin — silent-empty otherwise**: with sync-level, initial sync returns
   ALL members (E1: 6 hrefs + etags + token), mixed delta reports both
   changes (etag) and deletions (404 status markers) (E2). Without it,
   the parsed body-depth defaults to `Depth::None` → 0 → only the
   collection root is examined: initial sync returns zero members, deltas
   after PUTs return zero changes (deletions still surface — the
   tombstone path is depth-independent). Source-verified at
   `crates/dav-proto/src/requests/report.rs` (init `depth: Depth::None`)
   - `crates/dav/src/common/mod.rs:252` (`changes()` maps the BODY depth,
     not the HTTP `Depth` header — the header is ignored for this report).
     RFC 6578's DTD marks sync-level required, so omission is client
     malformation — but 207-with-empty-results (instead of a 400) is the
     interop-hostile part. The CRM client will always send sync-level 1.
6. **Normalization notes for the emitter (plan T10)**: stored TYPE params
   come back upper-cased (`TYPE=WORK`, `TYPE=CELL`); v3 input is
   re-emitted as v4; unknown properties round-trip verbatim; CATEGORIES
   preserved as written.
7. **SOCIALPROFILE-without-uri is safe on the pin (plan T06)**: uri-less
   `SOCIALPROFILE;SERVICE-TYPE=…;USERNAME=…:` round-trips byte-verbatim via
   CardDAV, and JMAP `ContactCard/get` renders it as an `onlineServices`
   entry with empty uri + preserved service/user (`social-edge.log`).
   Route facts: PUT into the home collection (no addressbook parent) → 409;
   JMAP posts to `/jmap/` (trailing slash) with
   `urn:ietf:params:jmap:contacts`; JMAP card ids are server-assigned, uid
   preserved.

## Reproduce

```sh
# VM up (FIFO console), then from this directory:
python3 carddav_probe.py | tee carddav-probe.log
python3 carddav_diag.py | tee carddav-diag.log
```

Each `carddav_probe.py` run MKCOLs a fresh `kith-probe-<epoch>` book; the
run-1 + diag books persist on the demo disk (harmless residue, deletable
via DELETE on the book href).
