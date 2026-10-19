# T05 verdict — 10k-card benchmark: CLOSE (do not file upstream)

Benchmark: `carddav-bench.log` (2026-10-19 07:45–08:00, pin 0.16.22, demo
VM, book `kith-bench-1792388705`, 10,000 deterministic vCards seeded at
14 PUT/s — rate-limit bound, not server bound). Host was BUSY (loadavg
20–42; parallel session building) — numbers are conservative, if anything.

## Numbers (3 runs, median)

| Measurement                                      | Median      | Notes                                                        |
| ------------------------------------------------ | ----------- | ------------------------------------------------------------ |
| B1 filtered addressbook-query (10k cards, 1 hit) | **0.074 s** | the sequential per-card scan path (the drill-down's concern) |
| B2 PROPFIND Depth:1 (2,000 hrefs, 480 KiB)       | 0.021 s     | result set capped, see below                                 |
| B3 addressbook-multiget 100 (etags + bodies)     | 0.002 s     |                                                              |
| B4 single card GET                               | 0.5 ms      |                                                              |

## Verdict

**CLOSE.** The addressbook-query scan concern (assessment addendum
2026-10-19 ~02:50) measures at ~74 ms for a filtered query over 10k cards
on the pin's in-process store — under heavy host load. Personal scale is
hundreds to low thousands of contacts (low single-digit ms). There is no
measured victim in Lars's deployment class, the only theoretically-affected
configurations (network stores: FoundationDB/Postgres/MySQL) are not in
use, and the semantics-preserving fix (batching the sequential reads)
remains a micro-opt nobody has demonstrated needing. verify-before-filing
Gate 4 stays failed: **do not file**. The filing path is now CLOSED with
numbers; it may only reopen on measured harm in real production use.

## Load-bearing side discovery: the 2,000-result cap

The count PROPFIND returned exactly **2,000** of the 10,000 card hrefs:
`WebDav.maxResults` (registry `WebDav` settings object) defaults to
**2000** and caps DAV result sets — source-verified at
`crates/registry/src/schema/structs.rs` + `structs_impl.rs:47388`
(`max_results: 2000u64`), byte-identical on the pin (T20 delta table).
Consequences for the CRM out-sync client (design doc §8.1/§4):

- PROPFIND enumeration silently truncates at 2,000 — the client must NOT
  treat a full PROPFIND as complete on large books.
- Etag refreshes go through multiget batches over KNOWN uids from state
  (2 ms per 100) — unaffected by the cap.
- First-run enumeration of a book larger than 2,000 cards needs the
  sync-collection initial sync (also capped) or paging; at personal scale
  (<2,000 contacts) this never bites. The runner logs loudly if a count
  returns exactly the cap value (the truncation signature).
