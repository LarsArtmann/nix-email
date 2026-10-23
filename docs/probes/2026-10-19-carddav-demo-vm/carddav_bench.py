#!/usr/bin/env python3
"""T05: 10k-card CardDAV benchmark against the demo VM (pin 0.16.22).

Seeds 10k deterministic vCards into a fresh addressbook (rate-limited PUTs),
then times (3 runs each, wall clock):

  B1  filtered addressbook-query (EMAIL text-match contains, ~1% hit rate)
  B2  plain PROPFIND Depth:1 (resourcetype+getetag, no bodies)
  B3  addressbook-multiget of 100 hrefs (etags + address-data)
  B4  single GET (reference point)

Feeds the file-or-close verdict (plan T05.4): the upstream-filing question is
whether the sequential per-card store reads in the filtered-query path are
harmful at personal scale. Orders of magnitude matter here, not milliseconds.
"""

import base64
import http.client
import statistics
import sys
import time
import xml.etree.ElementTree as ET

HOST, PORT = "127.0.0.1", 18080
USER = "demo@mail.demo.test"
PASS = "demo-nixemail-2026"
N = 10_000
BOOK = f"kith-bench-{int(time.time())}"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
HOME = f"/dav/card/{USER}/"
BOOK_URL = f"{HOME}{BOOK}/"


def req(method, path, body=None, depth=None, extra=None, timeout=300):
    conn = http.client.HTTPConnection(HOST, PORT, timeout=timeout)
    headers = {"Authorization": f"Basic {CREDS}"}
    if depth is not None:
        headers["Depth"] = depth
    if body is not None:
        headers["Content-Type"] = "application/xml; charset=utf-8"
    headers.update(extra or {})
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    lower = {k.lower(): v for k, v in resp.getheaders()}
    conn.close()
    return resp.status, lower, data


def req_throttled(method, path, body=None, depth=None, extra=None, timeout=300):
    """req + 429 handling: honor Retry-After, retry up to 30 times."""
    for attempt in range(30):
        status, headers, data = req(method, path, body, depth, extra, timeout)
        if status != 429:
            return status, headers, data
        wait = float(headers.get("retry-after", "5")) + 0.5
        print(f"  429 (attempt {attempt + 1}), sleeping {wait:.0f}s", flush=True)
        time.sleep(wait)
    return status, headers, data


def card(n: int) -> str:
    domain = "example.net" if n % 10 == 0 else "example.com"
    org = f"Bench Org {n % 37}" if n % 3 == 0 else ""
    cats = "bench,vip" if n % 5 == 0 else "bench"
    lines = [
        "BEGIN:VCARD",
        "VERSION:4.0",
        f"UID:bench-{n:05d}",
        f"FN:Bench Person {n}",
        f"N:Person;Bench {n};;;",
        f"EMAIL;TYPE=work:bench{n}@{domain}",
        f"TEL;TYPE=cell:+49 170 {n:07d}",
    ]
    if org:
        lines.append(f"ORG:{org}")
    lines.append(f"CATEGORIES:{cats}")
    if n % 7 == 0:
        lines.append(f"NOTE:deterministic bench card {n}")
    lines.append("END:VCARD")
    return "\r\n".join(lines) + "\r\n"


def main() -> int:
    print(f"# CardDAV 10k benchmark {time.strftime('%Y-%m-%dT%H:%M:%S%z')} book={BOOK}", flush=True)
    load = open("/proc/loadavg").read().strip()
    print(f"# host loadavg at start: {load}", flush=True)

    # Fresh book (run-1 leftovers are deleted by the operator; new timestamp).
    mkcol = (
        '<?xml version="1.0"?>'
        '<D:mkcol xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:set><D:prop>"
        "<D:resourcetype><D:collection/><C:addressbook/></D:resourcetype>"
        f"<D:displayname>{BOOK}</D:displayname>"
        "</D:prop></D:set></D:mkcol>"
    )
    status, _, _ = req_throttled("MKCOL", BOOK_URL, mkcol)
    print(f"MKCOL {status}", flush=True)
    if status not in (200, 201):
        return 1

    # Seed N cards, paced under the server's "requests";q=1000 bucket
    # (~15 req/s) with 429 Retry-After handling.
    t0 = time.perf_counter()
    created = updated = 0
    for i in range(N):
        status, _, _ = req_throttled(
            "PUT",
            f"{BOOK_URL}c{i:05d}.vcf",
            card(i),
            extra={"Content-Type": "text/vcard; charset=utf-8"},
        )
        if status == 201:
            created += 1
        elif status in (200, 204):
            updated += 1
        else:
            print(f"!! PUT {i} -> {status}", flush=True)
        time.sleep(1 / 15)
        if i % 1000 == 999:
            el = time.perf_counter() - t0
            print(f"seeded {i + 1}/{N} ({el:.0f}s elapsed)", flush=True)
    seed_s = time.perf_counter() - t0
    print(f"SEED done: {created} created, {updated} updated in {seed_s:.1f}s "
          f"({N / seed_s:.1f} PUT/s incl. pacing)", flush=True)

    # Let the rate bucket refill before the measurement phase.
    time.sleep(10)

    # Count via PROPFIND Depth:1 (this is also B2's first run).
    propfind_body = (
        '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/><D:getetag/></D:prop></D:propfind>"
    )
    t0 = time.perf_counter()
    status, _, data = req_throttled("PROPFIND", BOOK_URL, propfind_body, depth="1", timeout=600)
    propfind_s = time.perf_counter() - t0
    n_cards = data.count(b".vcf")
    print(f"COUNT via PROPFIND: status {status}, {n_cards} card hrefs, {propfind_s:.2f}s, "
          f"{len(data) / 1024:.0f} KiB body", flush=True)

    hrefs = [e.text for e in ET.fromstring(data).iter("{DAV:}href")
             if (e.text or "").endswith(".vcf")]

    # B1: filtered addressbook-query (~1% hit rate: contains "7133" in EMAIL).
    query = (
        '<?xml version="1.0"?>'
        '<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/></D:prop>"
        '<C:filter><C:prop-filter name="EMAIL">'
        '<C:text-match collation="i;ascii-casemap" match-type="contains">7133</C:text-match>'
        "</C:prop-filter></C:filter></C:addressbook-query>"
    )
    runs = []
    hits = -1
    while len(runs) < 3:
        t0 = time.perf_counter()
        status, _, data = req_throttled("REPORT", BOOK_URL, query, depth="1", timeout=600)
        if status == 429:
            continue
        runs.append(time.perf_counter() - t0)
        hits = data.count(b".vcf")
    print(f"B1 filtered query: median {statistics.median(runs):.3f}s "
          f"(runs {'/'.join(f'{r:.3f}' for r in runs)}), {hits} hits", flush=True)

    # B2: plain PROPFIND Depth:1 timing (count pass above was warm-up run 0).
    runs = []
    while len(runs) < 3:
        t0 = time.perf_counter()
        status, _, data = req_throttled("PROPFIND", BOOK_URL, propfind_body, depth="1", timeout=600)
        if status == 429:
            continue
        runs.append(time.perf_counter() - t0)
    print(f"B2 PROPFIND Depth:1: median {statistics.median(runs):.3f}s "
          f"(runs {'/'.join(f'{r:.3f}' for r in runs)}), {data.count(b'.vcf')} hrefs", flush=True)

    # B3: multiget of 100 hrefs with address-data.
    h100 = "".join(f"<D:href>{h}</D:href>" for h in hrefs[:100])
    multiget = (
        '<?xml version="1.0"?>'
        '<C:addressbook-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/><C:address-data/></D:prop>"
        f"{h100}</C:addressbook-multiget>"
    )
    runs = []
    while len(runs) < 3:
        t0 = time.perf_counter()
        status, _, data = req_throttled("REPORT", BOOK_URL, multiget, depth="1", timeout=600)
        if status == 429:
            continue
        runs.append(time.perf_counter() - t0)
    print(f"B3 multiget 100: median {statistics.median(runs):.3f}s "
          f"(runs {'/'.join(f'{r:.3f}' for r in runs)}), "
          f"{data.count(b'BEGIN:VCARD')} cards, {len(data) / 1024:.0f} KiB", flush=True)

    # B4: single GET reference.
    runs = []
    while len(runs) < 3:
        t0 = time.perf_counter()
        status, _, _ = req_throttled("GET", f"{BOOK_URL}c00042.vcf")
        if status == 429:
            continue
        runs.append(time.perf_counter() - t0)
    print(f"B4 single GET: median {statistics.median(runs) * 1000:.1f}ms "
          f"(runs {'/'.join(f'{r * 1000:.1f}' for r in runs)}ms)", flush=True)

    load = open("/proc/loadavg").read().strip()
    print(f"# host loadavg at end: {load}", flush=True)
    print("# NOTE: demo VM shares the host with other workloads; treat as "
          "order-of-magnitude evidence, not lab numbers.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
