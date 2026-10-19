# Status: Stalwart Contacts Feature Assessment (read-only review session)

- **Date:** 2026-10-19 02:35
- **Session trigger:** "How good is /home/lars/projects/nix-email aka stalwart's Contacts feature??"
- **Session type:** Read-only external assessment. **No code, config, or module files were modified in any repo.** The only artifact produced before this report was research state under `/tmp/stalwart-review/` (disposable).
- **Method:** source review of upstream Stalwart `v0.16.26` + `calcard 0.3.0` (tarballs in `/tmp/stalwart-review/`), cross-referenced with this repo's live-verified probe notes (`docs/INBOXCLEAN.md`, `docs/probes/2026-10-05-jmap-demo-vm/`, 0.16.22 demo re-verification 2026-10-18) and one upstream GitHub issue-tracker sweep.
- **Evidence levels used below:** `[SRC]` = read in source (0.16.26); `[LIVE]` = verified on this repo's demo VM (0.16.22, per existing transcripts); `[WEB]` = upstream issue tracker (weak: new bugs auto-redirect to support.stalw.art, so "no open issues" is thin evidence).

## Work product (the session's actual output)

**Verdict: A- data/protocol layer, C+ interop fringe.**

Strengths `[SRC]`:

- vCard model: full RFC 6350 IANA property table + RFC 6474 (deathdate/birthplace), RFC 9556 (PRONOUNS/GRAMGENDER), SOCIALPROFILE, `Other` catch-all preserving unknown properties and params; vCard 3.0/4.0 output negotiation (`calcard/src/vcard/types.rs`).
- JSContact (RFC 9553) conversion is serious: ~5.4k lines in `calcard/src/jscontact/{import,export}/` handling prop-ids, localizations, alt-ids, phonetic systems, JSCOMPS — the hard 20% most implementations skip.
- Storage: parsed vCard archived via rkyv (zero-copy), versioned, changelog'd, quota-aware (`crates/groupware/src/contact/storage.rs`).
- CardDAV PUT discipline: strict parse (rejects truncated cards), max-size guard, ETag/If-Match incl. `return=representation`, UID-conflict detection + per-addressbook UID uniqueness, ACL `AddItems` vs `ModifyItems` (`crates/dav/src/card/update.rs`).
- Sync: WebDAV sync-collection (RFC 6578) implemented and tested incl. stale-token `If` failures (`tests/src/webdav/sync.rs`).
- Real FTS: language-detecting indexing over name/nickname/org/email/phone/IMPP/social/address/note + keyword fields, backing JMAP's 22 filter keys + 6 comparators (`crates/groupware/src/contact/index.rs`).
- Test breadth: webdav suite (put_get 634 loc, copy_move 904, card_query, sync, multiget, mkcol, principals, acl, lock) + 1.4k-line JMAP contacts suite with 4 full JSContact fixtures.
- JMAP surface live-confirmed `[LIVE]`: `urn:ietf:params:jmap:contacts` (+`:parse`), `mayCreateAddressBook: true`, `maxAddressBooksPerCard: null` (session-admin/user.json).

Weaknesses `[SRC]`:

- `addressbook-query` filters = in-memory scan of every card in the book; no index pushdown (`crates/dav/src/card/query.rs`). Fine at personal scale; degrades past a few thousand cards.
- Storage is the parsed model, not raw bytes → GET re-serializes; model-faithful (via `Other`) but not byte-faithful for exotic cards.
- `FilterOp::TimeRange` always returns `false` (unimplemented; rarely used for contacts).
- No dedup/merge beyond UID uniqueness.
- Interop fringe learned the hard way upstream `[WEB]`: #2884 (SOCIALPROFILE w/o uri dropped on JMAP get), #2431 (media blobId silently lost → now rejected), #3265 (JSCOMPS not stripped on 4.0→3.0 downgrade garbling iOS names — closed not-planned), #1608 (Apple bulk-import stalls — fixed 0.16.10), #1607 (truncated avatar accepted → strict parsing added). Pattern: strict-first server, lossy edges on client dialect corners.

CRM-relevant takeaway (Kith CRM's `Source` seam, "CardDAV later"): viable sync target; UID uniqueness maps onto the gcontacts one-key-per-account invariant, sync-collection gives cheap incrementals, ETag/If-Match gives conflict detection. Costs: strict parser demands clean vCard emission; Apple-dialect interop needs real-device testing.

---

## a) FULLY DONE

1. Identified repo topology: nix-email is a NixOS wrapper; Stalwart itself is a pinned nixpkgs dependency (`pkgs.stalwart_0_16`, vendored 0.16 module from nixpkgs PR #552103).
2. Downloaded and extracted upstream sources for review: `stalwart v0.16.26` (8.7 MB) + `calcard 0.3.0` (the vCard/JSContact engine crate) to `/tmp/stalwart-review/`.
3. Reviewed all five contacts-relevant layers end-to-end: vCard model, JSContact conversion, groupware storage/indexing, CardDAV handlers (PUT/query/update), JMAP methods (get/set/query/copy/parse).
4. Inventoried test coverage (webdav + jmap contacts suites) with concrete file sizes.
5. Swept upstream issue history for contacts/CardDAV/JSContact bugs; triaged 12 relevant of 33 results, all closed.
6. Verified the JMAP contacts capability claims against this repo's existing live transcripts instead of re-probing.
7. Delivered a graded verdict with the CRM-integration angle in-session.
8. **This turn:** corrected the version basis — flake.lock nixpkgs rev `6774f7bc…` pins stalwart **0.16.22**, NOT 0.16.26 (see d) item 1).

## b) PARTIALLY DONE

1. **Version grounding:** source review was of 0.16.26 while the deployed/demo-verified pin is 0.16.22 (4 patch releases of drift). Root cause found and verified (registry vs lock eval); the 0.16.22↔0.16.26 contacts-crate diff itself was NOT checked — the verdict is probably robust to patch drift but that is an assumption, not a fact.
2. **Upstream-issue evidence:** single GitHub search page; new upstream bugs are filed on support.stalw.art, not GitHub — "all closed" is weak negative evidence and was only partially caveated in-session.
3. **calcard test quality:** counted inline `#[cfg(test)]` presence (modest, ~15 across the crate) but did not read them; no verdict on their depth.
4. **Config surface:** saw groupware knobs exist in source (`max_vcard_size`, `vcard_version`) but never mapped what the vendored nix-email module exposes or overrides.

## c) NOT STARTED

1. **Live probing** — no demo VM boot, no CardDAV transcript set (PUT vCard 3/4, addressbook-query, multiget, sync-collection token flow). This repo's own transcript rule ("a claim without a transcript is a guess") applies: my verdict is source-level and was labeled as such, but nothing was live-verified for contacts specifically.
2. **Webmail UI assessment** — the contacts editor UI is not in the server repo; whether the nixpkgs build bundles the webmail dist at all was not checked. UI quality remains unknown.
3. **Real-client interop** — no Apple Contacts / Thunderbird / eM Client dialect testing (the historically bumpy area).
4. **JSContact edge regression checks on the pin** — e.g., #2884-class (SOCIALPROFILE w/o uri) on 0.16.22 specifically.
5. **Contacts→spam-classification and autocomplete interactions** — known to exist upstream; unexamined here.
6. **CRM CardDAV Source design work** — only the viability verdict was delivered, no design doc.
7. Cleanup of `/tmp/stalwart-review/` (~50 MB extracted) — left in place deliberately (see f) item 20).

## d) TOTALLY FUCKED UP!

1. **Wrong version basis for the whole source review (the big one):** I resolved stalwart's version via `nix eval nixpkgs#stalwart_0_16` — the _registry_ nixpkgs (0.16.26) — instead of this repo's _flake.lock_ (0.16.22). The in-session verdict cited "the pinned 0.16.26". Discovered during this self-review, corrected by evaluating `stalwart_0_16.version` at the locked rev (`6774f7bc…` → "0.16.22"). Lesson: resolve versions through the project's lock, never the registry.
2. **Banned command attempt:** first download tried `curl` in bash — rejected by the tool contract; wasted a round-trip. The `download` tool should have been the first and only choice.
3. **Sloppy rg pattern:** `use .*vcard|vcard::` produced mangled output; I worked around it instead of fixing the pattern. Harmless, but pattern discipline slipped.
4. **Premise drift in-flight:** mid-session I implied calcard had no tests (empty `tests/` dir) before confirming the inline `#[cfg(test)]` modules existed. Corrected within the session, but the intermediate claim should never have been made.
5. **Report-home ambiguity decided unilaterally:** the question was asked from the CRM cwd but is entirely about this repo; I chose `nix-email/docs/status/` on my own judgment (flagged for the owner in the closing message).

## e) WHAT WE SHOULD IMPROVE!

1. **Transcript discipline for contacts claims:** before any contacts wire-claim gets encoded into this repo's docs (the way `docs/INBOXCLEAN.md` does for JMAP), boot the demo VM and capture a CardDAV probe set under `docs/probes/`. Source-level reading is not this repo's evidence standard.
2. **Version resolution rule:** always ground "pinned version" statements in `flake.lock` revs (parse lock → eval at rev), not registry nixpkgs. Add to the pin-advance checklist mentally.
3. **Tool defaults:** `download` tool for fetches, never curl; clean rg patterns the first time.
4. **Label evidence levels explicitly in every report** ([SRC]/[LIVE]/[WEB]) — this report does it; keep the habit.
5. **Scope honesty:** "up to 50 next things" padding would have been noise; ~20 real items is the honest ceiling for a single read-only session. Quality over quota.

## f) Things we should get done next (impact-sorted; honest count: 20)

**nix-email (hardening the assessment into this repo's evidence standard):**

1. Diff contacts-relevant crates (`calcard`, `crates/{groupware,dav,jmap-proto}`) between v0.16.22 and v0.16.26 — confirm the verdict holds for the locked rev; note deltas in this report's appendix if any.
2. Boot demo VM (`nix run .#vm`), run a CardDAV transcript set: PUT vCard 4.0 + 3.0, addressbook-query with prop/param filters, multiget, sync-collection token round-trip → `docs/probes/<date>-carddav-demo-vm/`.
3. Probe the #2884-class edge on the pin: SOCIALPROFILE-without-uri through JMAP `ContactCard/get` vs CardDAV GET.
4. Verify UID-uniqueness + ETag/If-Match behavior live (source says enforced; pin behavior should have a transcript).
5. Check whether nixpkgs `stalwart_0_16` bundles the webmail dist; if not, document how to serve it or flag the gap in README.
6. Map groupware config knobs (`max_vcard_size`, `vcard_version`) through the vendored module — expose or explicitly default them.
7. Add a Contacts section to README/FEATURES posture (today contacts appears only inside `docs/INBOXCLEAN.md`'s capability list — it has no first-class documentation in this repo).
8. Decide + document whether CardDAV should be exposed through the production wrapper's reverse-proxy posture (currently only JMAP posture is documented for InboxClean).

**Kith CRM (if the CardDAV-later `Source` seam is the driver):**
9. Design doc for the CardDAV `Source`: UID key discipline ↔ gcontacts one-key invariant, sync-token vs the atomic per-account state JSON, ETag conflict policy, one-way posture.
10. Decide one-way vs two-way sync before any code (mirrors the ratified gcontacts strictly-one-way rule).
11. vCard emitter decisions: version (4.0 vs 3.0 for client compat), mandatory FN/N synthesis, photo encoding policy, tags→CATEGORIES mapping.
12. Matching ladder analog in Go: ext-id (UID) → email → name; never pushdown (mirrors gcontacts).
13. Reuse `machineapi`'s `phoneMatches` digit-normalization for TEL-based matching (stored phones verbatim — same contract as /rest).
14. Field mapping table CRM contact → vCard (company→ORG, notes→NOTE, relations: vCard has no relation graph — keep relations CRM-side, RELATED best-effort or skip).
15. Test harness: fake CardDAV server with scripted specSources (gcontacts pattern) + optional E2E against the demo VM.
16. Addressbook discovery via `.well-known/carddav` + principals (check what 0.16.22 serves).

**Meta / hygiene:**
17. If the owner ratifies this assessment as durable knowledge, promote the verdict into `docs/reviews/` (or a CONTACTS.md) instead of leaving it only in this timestamped snapshot.
18. Record the "registry vs lock" version lesson where the next session will hit it (this report is the record; consider the pin-advance runbook in README too).
19. If/when the nixpkgs pin advances past 0.16.22: the INBOXCLEAN re-verification procedure should gain a contacts step (re-run items 2–4).
20. Trash `/tmp/stalwart-review/` (~50 MB) once no more source cross-referencing is planned this session.

## g) Questions I can NOT figure out myself

1. **Who is the consumer of this assessment?** The CRM's CardDAV-later `Source` seam, a planned nix-email contacts deployment for your own mail, InboxClean adjacency, or general triage? This decides whether f) items 1–8 or 9–16 go first.
2. **Does this assessment become durable repo knowledge?** Promote to `docs/reviews/` (or CONTACTS.md) in nix-email, or does the timestamped snapshot suffice? I chose snapshot-only.
3. **For a future CRM CardDAV sync: is two-way EVER on the table,** or is one-way CRM→server a hard constraint like gcontacts? I can't infer your trust posture for server-side edits made by phones/clients from the repos alone — and it changes the design (conflict policy, UID ownership, delete semantics).

---

## Addendum (2026-10-19, ~02:50): addressbook-query scan drill-down — filing verdict: DO NOT FILE (yet)

Follow-up question: "are the cards in memory all the time? worth filing an issue?" Verified at source level across v0.16.22 (deployed), v0.16.26, and upstream `main`:

- **What is cached:** `GroupwareCache`/`DavResources` (`crates/common/src/lib.rs`) holds only the resource tree — paths, document ids, names, ACLs, sizes. **No vCard payloads, no etags.** Card contents are NOT in memory.
- **What happens per filtered query:** `crates/dav/src/common/propfind.rs` (`'outer: for item in paths` loop) reads every card of the queried addressbook via a **sequential** `store().get_value::<Archive<AlignedBytes>>().await` per card, then applies `vcard_query` (pure in-memory string matching). No batching, no concurrency, no early exit under `limit`.
- **Impact by backend:** RocksDB/SQLite (in-process + block cache) — milliseconds at personal scale; FoundationDB/PostgreSQL/MySQL (network stores) — N serial network RTTs per query, the genuinely affected configuration.
- **Upstream state:** identical code on `main` (unfixed); no existing open or closed issue about addressbook-query performance (searched `addressbook-query`, `carddav performance`, `contact search`).
- **Why NOT filing (verify-before-filing Gate 4 fail):** no measured victim — Lars's deployments are personal-scale, and the tempting fix ("push filters into the Contacts FTS index") is semantically unfaithful: `TextMatch` implements substring/equals/starts/ends collations (`dav-proto/src/schema/mod.rs`), which a tokenized index cannot serve exactly (infix `contains` impossible). The semantics-preserving ask (batch/concurrent the reads) is a micro-opt nobody has demonstrated needing. Filing now would be a professional-looking issue whose core premise ("this hurts someone") is unverified — plus upstream redirects bug reports to support.stalw.art and has closed-not-planned this class before (#3265).
- **Filing-grade path (new next-task, supersedes nothing):** benchmark on the demo VM — seed 10k/50k cards, time a filtered `addressbook-query` REPORT vs plain PROPFIND. If latency is genuinely bad at realistic scale, file with numbers + the verbatim source citations above (quote code, pin commit).

---

## Addendum (2026-10-19, ~07:45): CardDAV probe transcripts landed — claims upgraded to [LIVE]

f) items 2, 4, and 16 are DONE: the full probe set ran against a fresh demo
boot (pin 0.16.22) — transcripts + verdicts at
`docs/probes/2026-10-19-carddav-demo-vm/` (README indexes them). Upgrades:

- **Discovery chain [LIVE]** (f)16): `/.well-known/carddav` → 307 `/dav/card`
  (anon); `current-user-principal` → `/dav/pal/<email>/`; carddav
  `addressbook-home-set` → `/dav/card/<email>/`; Depth:1 PROPFIND enumerates
  books incl. MKCOL-created ones.
- **UID-uniqueness + ETag/If-Match [LIVE]** (f)4): duplicate-UID PUT → 412
  `no-uid-conflict` naming the conflicting href; stale If-Match → 412; real
  etag → 204 + new etag, UID preserved. PUT/GET/MKCOL all return `etag`
  headers (lowercase — clients must do case-insensitive lookups).
- **PUT-time validation is LENIENT [LIVE, new fact]:** a garbage card (no
  VERSION, no FN, unknown property) is ACCEPTED and stored with `VERSION:4.0`
  injected, unknown property preserved verbatim. "Strict parse" applies to
  the query path, not PUT storage.
- **sync-collection needs `<D:sync-level>1</D:sync-level>` [LIVE + SRC]:**
  without it the parsed body-depth defaults to `Depth::None` → 0 → initial
  sync returns zero members and PUT-deltas return zero changes (deletes still
  surface). With it, RFC 6578 behaves fully (initial = all members; mixed
  delta = changes with etags + deletions as 404 markers). Body depth wins;
  the HTTP `Depth` header is ignored for this report
  (`crates/dav-proto/src/requests/report.rs` init + `crates/dav/src/common/mod.rs:252`).
- **Normalization [LIVE]:** v3 input stored as v4 (TYPE upper-cased,
  `TYPE=INTERNET` preserved); query filters are case-insensitive; anyof/allof
  correct; multiget returns etags + CDATA bodies.
- f)3 (SOCIALPROFILE edge) and the f)-addendum benchmark (file-or-close) are
  the next probe tasks on the same boot.

---

## Addendum (2026-10-19, ~07:55): f)3 SOCIALPROFILE-without-uri — PASS, non-issue on the pin

`social-edge.log` in the probe dir: variant cards PUT inside an addressbook,
compared across protocols.

- **CardDAV**: `SOCIALPROFILE;SERVICE-TYPE=Mastodon;USERNAME=edgeuser:`
  (uri-less, svc+user) and `SOCIALPROFILE;SERVICE-TYPE=Mastodon:` (uri-less,
  service only) both round-trip **byte-verbatim** via PUT→GET. A uri-full
  SOCIALPROFILE also round-trips.
- **JMAP**: `ContactCard/get` renders the uri-less property as
  `onlineServices: {k1: {uri: "", service: "Mastodon", user: "edgeuser"}}` —
  no drop, no parse error, no mangling. The #2884-class edge is a non-issue
  on 0.16.22.
- Route facts learned while probing: PUT directly into the home collection
  (no addressbook parent) → 409; JMAP request URL is `/jmap/` (trailing
  slash; `/jmap` returns `notRequest`); JMAP card ids are server-assigned
  (`"edh"`) while `uid` is preserved; capability is
  `urn:ietf:params:jmap:contacts`.

---

_Point-in-time snapshot. Session modified no project files; the auto-commit daemon owns this file's landing._
