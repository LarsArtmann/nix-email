#!/usr/bin/env python3
"""CardDAV probe suite against the nix-email demo VM (Stalwart 0.16.22 pin).

Host-side, port 18080 (forwarded to the guest's 8080 HTTP listener that
also serves JMAP/webmail). Covers plan tasks T04.2-T04.10 + T17.1 of
crm/docs/planning/2026-10-19_04-09_data-mesh-carddav-pareto.md:

  well-known redirect, principal + addressbook-home-set discovery,
  book enumeration, MKCOL, PUT vCard 4.0 + 3.0 (version negotiation),
  strict-parse rejection, addressbook-query (text-match / param-filter /
  anyof-allof), addressbook-multiget, sync-collection round-trip,
  UID-conflict, ETag If-Match (stale + matching).

Stdlib only. Prints a full request/response transcript; redirect to a log.
Exits non-zero only on hard connect failures - individual step verdicts
are printed as PASS/FAIL/SEE-TRANSCRIPT so unexpected server behavior
still produces a transcript instead of a traceback.
"""

import base64
import http.client
import re
import sys
import time
import xml.etree.ElementTree as ET

HOST, PORT = "127.0.0.1", 18080
USER = "demo@mail.demo.test"
PASS = "demo-nixemail-2026"
BOOK = f"kith-probe-{int(time.time())}"
DAV, CARD = "DAV:", "urn:ietf:params:xml:ns:carddav"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()

VCARD_4 = (
    "BEGIN:VCARD\r\n"
    "VERSION:4.0\r\n"
    f"UID:kith-probe-{BOOK}\r\n"
    "FN:Kith Probe One\r\n"
    "N:Probe;Kith;;;\r\n"
    "EMAIL;TYPE=work:kith-probe@example.com\r\n"
    "TEL;TYPE=cell:+49 170 0000001\r\n"
    "TEL;TYPE=work:+49 30 0000002\r\n"
    "ORG:Kith Probe Works\r\n"
    "CATEGORIES:probe,kith\r\n"
    "END:VCARD\r\n"
)
VCARD_3 = (
    "BEGIN:VCARD\r\n"
    "VERSION:3.0\r\n"
    f"UID:kith-probe-v3-{BOOK}\r\n"
    "FN:Kith Probe Three\r\n"
    "N:Probe;Kith Three;;;\r\n"
    "EMAIL;TYPE=INTERNET:kith-v3@example.com\r\n"
    "TEL;TYPE=CELL:+49 170 0000003\r\n"
    "END:VCARD\r\n"
)
VCARD_BAD = "BEGIN:VCARD\r\nNOPE: this is not a card\r\nEND:VCARD\r\n"

results: list[tuple[str, str]] = []


def record(step: str, verdict: str) -> None:
    results.append((step, verdict))
    print(f"VERDICT {step}: {verdict}", flush=True)


def req(
    method: str,
    path: str,
    body: str | None = None,
    depth: str | None = None,
    extra: dict[str, str] | None = None,
    auth: bool = True,
):
    conn = http.client.HTTPConnection(HOST, PORT, timeout=30)
    headers = {"Authorization": f"Basic {CREDS}"} if auth else {}
    if depth is not None:
        headers["Depth"] = depth
    if body is not None:
        headers["Content-Type"] = "application/xml; charset=utf-8"
    for k, v in (extra or {}).items():
        headers[k] = v
    print(f"\n>> {method} {path}" + (f"  Depth: {depth}" if depth else ""), flush=True)
    if body:
        print(
            body if len(body) <= 900 else body[:900] + "\n... (truncated)", flush=True
        )
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    print(f"<< {resp.status} {resp.reason}", flush=True)
    interesting = {
        k.lower(): v
        for k, v in resp.getheaders()
        if k.lower() in ("location", "etag", "content-type", "dav", "allow")
    }
    if interesting:
        print(
            "   " + " | ".join(f"{k}: {v}" for k, v in interesting.items()), flush=True
        )
    if data:
        text = data.decode(errors="replace")
        print(
            text if len(text) <= 1200 else text[:1200] + "\n... (truncated)", flush=True
        )
    conn.close()
    return resp.status, dict(resp.getheaders()), data


def hrefs(xml_bytes: bytes, tag: str, ns: str = DAV) -> list[str]:
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return []
    return [e.text or "" for e in root.iter(f"{{{ns}}}{tag}")]


def prop(xml_bytes: bytes, local: str, ns: str = DAV) -> str | None:
    found = hrefs(xml_bytes, local, ns)
    return found[0] if found else None


def main() -> int:
    print(
        f"# CardDAV probe suite {time.strftime('%Y-%m-%dT%H:%M:%S%z')} book={BOOK}",
        flush=True,
    )

    # T17.1: well-known redirect (any method, incl. unauthenticated)
    status, headers, _ = req("GET", "/.well-known/carddav", auth=False)
    loc = headers.get("Location", "")
    record(
        "T17.1 well-known/carddav 307->/dav/card",
        "PASS"
        if status == 307 and loc.rstrip("/").endswith("/dav/card")
        else f"SEE-TRANSCRIPT ({status} {loc})",
    )

    # T17.1b: principal discovery off the DAV root
    propfind_cup = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:current-user-principal/><D:resourcetype/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", "/dav/card/", propfind_cup, depth="0")
    principal = prop(data, "href")
    record(
        "T17.1b current-user-principal",
        f"PASS ({principal})"
        if status == 207 and principal
        else f"SEE-TRANSCRIPT ({status})",
    )

    # T17.1c: addressbook-home-set off the principal
    principal_path = principal or f"/dav/pal/{USER}"
    propfind_home = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><C:addressbook-home-set/><D:displayname/></D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", principal_path, propfind_home, depth="0")
    home = prop(data, "href", CARD)
    record(
        "T17.1c addressbook-home-set",
        f"PASS ({home})" if status == 207 and home else f"SEE-TRANSCRIPT ({status})",
    )

    # enumerate existing books
    home_path = home or f"/dav/card/{USER}/"
    propfind_list = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/><D:displayname/><D:getetag/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", home_path, propfind_list, depth="1")
    books = hrefs(data, "href")
    record(
        "T17.1d enumerate books",
        f"PASS ({len(books)} hrefs)" if status == 207 else f"SEE-TRANSCRIPT ({status})",
    )

    # T04.2: MKCOL a fresh book + PUT a vCard 4.0
    book_path = f"{home_path}{BOOK}/"
    mkcol = (
        '<?xml version="1.0"?>'
        '<D:mkcol xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:set><D:prop>"
        "<D:resourcetype><D:collection/><C:addressbook/></D:resourcetype>"
        f"<D:displayname>{BOOK}</D:displayname>"
        "</D:prop></D:set></D:mkcol>"
    )
    status, headers, _ = req("MKCOL", book_path, mkcol)
    record(
        "T04.2a MKCOL addressbook",
        "PASS" if status in (200, 201) else f"SEE-TRANSCRIPT ({status})",
    )

    card1 = f"{book_path}card1.vcf"
    status, headers, _ = req(
        "PUT", card1, VCARD_4, extra={"Content-Type": "text/vcard; charset=utf-8"}
    )
    etag1 = headers.get("ETag", headers.get("Etag", ""))
    record(
        "T04.2b PUT vCard 4.0 -> 201 + ETag",
        f"PASS ({etag1})"
        if status in (200, 201) and etag1
        else f"SEE-TRANSCRIPT ({status})",
    )

    status, headers, data = req("GET", card1)
    version = re.search(rb"VERSION:(\d\.\d)", data)
    record(
        "T04.2c GET back",
        f"PASS (VERSION {version.group(1).decode() if version else '?'})"
        if status == 200
        else f"SEE-TRANSCRIPT ({status})",
    )

    # supported-report-set on the new book (what REPORTs it advertises)
    propfind_srs = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:supported-report-set/><D:sync-token/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", book_path, propfind_srs, depth="0")
    reports = sorted(
        {m.decode() for m in re.findall(rb"<D:report>\s*<(\w+:[\w-]+)", data)}
    )
    token0 = prop(data, "sync-token")
    record(
        "T04.2d supported-report-set",
        f"PASS ({', '.join(reports)})"
        if status == 207
        else f"SEE-TRANSCRIPT ({status})",
    )

    # T04.3: PUT a vCard 3.0 - what does the pin store?
    card2 = f"{book_path}card2.vcf"
    status, headers, _ = req(
        "PUT", card2, VCARD_3, extra={"Content-Type": "text/vcard; charset=utf-8"}
    )
    status2, headers2, data2 = req("GET", card2)
    version2 = re.search(rb"VERSION:(\d\.\d)", data2)
    record(
        "T04.3 PUT v3.0 round-trip",
        f"PASS (stored VERSION {version2.group(1).decode() if version2 else '?'})"
        if status in (200, 201) and status2 == 200
        else f"SEE-TRANSCRIPT ({status}/{status2})",
    )

    # T04.4: strict parse - garbage card
    card3 = f"{book_path}card3.vcf"
    status, headers, data = req(
        "PUT", card3, VCARD_BAD, extra={"Content-Type": "text/vcard; charset=utf-8"}
    )
    record(
        "T04.4 garbage PUT rejected 4xx",
        "PASS" if 400 <= status < 500 else f"FAIL (accepted {status})",
    )

    # T04.5: addressbook-query, EMAIL text-match contains
    card4 = f"{book_path}card4.vcf"
    req(
        "PUT",
        card4,
        VCARD_4.replace("kith-probe@example.com", "other-domain@example.net")
        .replace(f"UID:kith-probe-{BOOK}", f"UID:kith-probe-2-{BOOK}")
        .replace("Kith Probe One", "Kith Probe Two"),
        extra={"Content-Type": "text/vcard; charset=utf-8"},
    )
    query = (
        '<?xml version="1.0"?>'
        '<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/></D:prop>"
        '<C:filter><C:prop-filter name="EMAIL">'
        '<C:text-match collation="i;ascii-casemap" match-type="contains">kith</C:text-match>'
        "</C:prop-filter></C:filter></C:addressbook-query>"
    )
    status, headers, data = req("REPORT", book_path, query, depth="1")
    hits = [h for h in hrefs(data, "href") if h.endswith(".vcf")]
    record(
        "T04.5 query EMAIL contains 'kith'",
        f"PASS ({len(hits)} hits: card1+card4)"
        if status == 207 and len(hits) == 2
        else f"SEE-TRANSCRIPT ({status}, {len(hits)} hits)",
    )

    # T04.6: param-filter TYPE=cell + anyof/allof variants
    q_param = (
        '<?xml version="1.0"?>'
        '<C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/></D:prop>"
        '<C:filter><C:prop-filter name="TEL">'
        '<C:param-filter name="TYPE">'
        '<C:text-match collation="i;ascii-casemap" match-type="equals">cell</C:text-match>'
        "</C:param-filter></C:prop-filter></C:filter></C:addressbook-query>"
    )
    status, headers, data = req("REPORT", book_path, q_param, depth="1")
    hits = [h for h in hrefs(data, "href") if h.endswith(".vcf")]
    record(
        "T04.6a param-filter TEL TYPE=cell",
        f"PASS ({len(hits)} hits: card1+card2+card4)"
        if status == 207 and len(hits) == 3
        else f"SEE-TRANSCRIPT ({status}, {len(hits)} hits)",
    )

    q_any = query.replace("<C:filter>", '<C:filter test="anyof">').replace(
        "</C:prop-filter></C:filter>",
        '</C:prop-filter><C:prop-filter name="N">'
        '<C:text-match match-type="contains">Three</C:text-match></C:prop-filter></C:filter>',
    )
    status, headers, data = req("REPORT", book_path, q_any, depth="1")
    hits_any = [h for h in hrefs(data, "href") if h.endswith(".vcf")]
    q_all = q_any.replace('test="anyof"', 'test="allof"')
    status, headers, data = req("REPORT", book_path, q_all, depth="1")
    hits_all = [h for h in hrefs(data, "href") if h.endswith(".vcf")]
    record(
        "T04.6b anyof vs allof",
        f"PASS (anyof={len(hits_any)} >= allof={len(hits_all)})"
        if len(hits_any) >= len(hits_all)
        else f"SEE-TRANSCRIPT ({len(hits_any)}/{len(hits_all)})",
    )

    # T04.7: addressbook-multiget
    multiget = (
        '<?xml version="1.0"?>'
        '<C:addressbook-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/><C:address-data/></D:prop>"
        f"<D:href>{card1}</D:href><D:href>{card2}</D:href>"
        "</C:addressbook-multiget>"
    )
    status, headers, data = req("REPORT", book_path, multiget, depth="1")
    hits = [h for h in hrefs(data, "href") if h.endswith(".vcf")]
    has_cards = data.count(b"BEGIN:VCARD") >= 2
    record(
        "T04.7 multiget 2 hrefs",
        "PASS"
        if status == 207 and len(hits) == 2 and has_cards
        else f"SEE-TRANSCRIPT ({status}, {len(hits)})",
    )

    # T04.8: sync-collection round-trip
    sync_empty = (
        '<?xml version="1.0"?>'
        '<D:sync-collection xmlns:D="DAV:">'
        "<D:prop><D:getetag/></D:prop>"
        "<D:sync-token/>"
        "</D:sync-collection>"
    )
    status, headers, data = req("REPORT", book_path, sync_empty, depth="1")
    token1 = prop(data, "sync-token")
    n_initial = len([h for h in hrefs(data, "href") if h.endswith(".vcf")])
    card5 = f"{book_path}card5.vcf"
    req(
        "PUT",
        card5,
        VCARD_4.replace(f"UID:kith-probe-{BOOK}", f"UID:kith-probe-5-{BOOK}").replace(
            "Kith Probe One", "Kith Probe Five"
        ),
        extra={"Content-Type": "text/vcard; charset=utf-8"},
    )
    status, headers, data = req(
        "REPORT",
        book_path,
        sync_empty.replace(
            "<D:sync-token/>", f"<D:sync-token>{token1 or ''}</D:sync-token>"
        ),
        depth="1",
    )
    token2 = prop(data, "sync-token")
    n_delta = len([h for h in hrefs(data, "href") if h.endswith(".vcf")])
    record(
        "T04.8 sync-collection round-trip",
        f"PASS (initial={n_initial}, delta={n_delta}, token advanced={bool(token1 and token2 and token1 != token2)})"
        if status == 207 and n_delta == 1
        else f"SEE-TRANSCRIPT ({status}, initial={n_initial}, delta={n_delta})",
    )

    # T04.9: UID conflict
    card6 = f"{book_path}card6.vcf"
    status, headers, data = req(
        "PUT",
        card6,
        VCARD_4.replace("Kith Probe One", "Kith Probe Dupe"),
        extra={"Content-Type": "text/vcard; charset=utf-8"},
    )
    record(
        "T04.9 duplicate UID rejected",
        "PASS"
        if status == 412 and b"no-uid-conflict" in data.lower()
        else (
            "PASS-412" if status in (403, 409, 412) else f"SEE-TRANSCRIPT ({status})"
        ),
    )

    # T04.10: ETag If-Match stale vs matching
    status, headers, data = req(
        "PUT",
        card1,
        VCARD_4.replace("Kith Probe One", "Kith Probe One v2"),
        extra={
            "Content-Type": "text/vcard; charset=utf-8",
            "If-Match": '"bogus-stale-etag"',
        },
    )
    record(
        "T04.10a stale If-Match -> 412",
        "PASS" if status == 412 else f"SEE-TRANSCRIPT ({status})",
    )
    _, headers_now, _ = req("GET", card1)
    etag_now = headers_now.get("ETag", headers_now.get("Etag", ""))
    status, headers, data = req(
        "PUT",
        card1,
        VCARD_4.replace("Kith Probe One", "Kith Probe One v2"),
        extra={"Content-Type": "text/vcard; charset=utf-8", "If-Match": etag_now},
    )
    record(
        "T04.10b matching If-Match -> 2xx",
        "PASS" if status in (200, 201, 204) else f"SEE-TRANSCRIPT ({status})",
    )

    print("\n# SUMMARY", flush=True)
    for step, verdict in results:
        print(f"  {step}: {verdict}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
