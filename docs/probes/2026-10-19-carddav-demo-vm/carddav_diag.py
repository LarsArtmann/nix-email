#!/usr/bin/env python3
"""Follow-up diagnostics for the two genuine T04 findings (pin 0.16.22).

D1. T04.4 follow-up: what does the server STORE for the accepted garbage card
    (BEGIN/NOPE/END, no VERSION, no FN)? GET it back.
D2. T04.10b follow-up: If-Match with the REAL current etag (the main probe sent
    an empty etag due to a case-sensitive header lookup bug; headers are
    case-insensitive per RFC 9110). Expect 2xx this time.
D3. T04.8 deep-dive: sync-collection deviations.
    - D3a: fresh token, PUT card7, delta -> does card7 appear?
    - D3b: same with explicit <D:sync-level>1</D:sync-level>.
    - D3c: DELETE card7, delta -> does the delete appear?
    - D3d: sync-collection on the long-lived `default` book (cross-boot).

Stdlib only, same house style as carddav_probe.py; transcript is the artifact.
"""

import base64
import http.client
import sys
import time
import xml.etree.ElementTree as ET

HOST, PORT = "127.0.0.1", 18080
USER = "demo@mail.demo.test"
PASS = "demo-nixemail-2026"
DAV = "DAV:"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()

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
):
    conn = http.client.HTTPConnection(HOST, PORT, timeout=30)
    headers = {"Authorization": f"Basic {CREDS}"}
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
    lower = {k.lower(): v for k, v in resp.getheaders()}
    print(f"<< {resp.status} {resp.reason}", flush=True)
    interesting = {
        k: v
        for k, v in lower.items()
        if k in ("location", "etag", "content-type", "dav", "allow")
    }
    if interesting:
        print(
            "   " + " | ".join(f"{k}: {v}" for k, v in interesting.items()), flush=True
        )
    if data:
        text = data.decode(errors="replace")
        print(
            text if len(text) <= 1600 else text[:1600] + "\n... (truncated)", flush=True
        )
    conn.close()
    return resp.status, lower, data


def prop(xml_bytes: bytes, local: str, ns: str = DAV) -> str | None:
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return None
    found = [e.text or "" for e in root.iter(f"{{{ns}}}{local}")]
    return found[0] if found else None


def card_hrefs(xml_bytes: bytes) -> list[str]:
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return []
    return [
        e.text or ""
        for e in root.iter(f"{{{DAV}}}href")
        if (e.text or "").endswith(".vcf")
    ]


def vcard(uid: str, fn: str) -> str:
    return (
        "BEGIN:VCARD\r\nVERSION:4.0\r\n"
        f"UID:{uid}\r\nFN:{fn}\r\nN:Diag;;;\r\n"
        "EMAIL:diag@example.com\r\nEND:VCARD\r\n"
    )


def sync_body(token: str | None, level: bool = False) -> str:
    lvl = "<D:sync-level>1</D:sync-level>" if level else ""
    tok = f"<D:sync-token>{token}</D:sync-token>" if token else "<D:sync-token/>"
    return (
        '<?xml version="1.0"?>'
        f'<D:sync-collection xmlns:D="DAV:">{lvl}'
        "<D:prop><D:getetag/></D:prop>"
        f"{tok}</D:sync-collection>"
    )


def main() -> int:
    print(f"# CardDAV diagnostics {time.strftime('%Y-%m-%dT%H:%M:%S%z')}", flush=True)

    # Locate the probe book (newest kith-probe-*).
    status, headers, data = req(
        "PROPFIND",
        f"/dav/card/{USER}/",
        '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/><D:displayname/></D:prop></D:propfind>",
        depth="1",
    )
    all_hrefs = (
        [e.text or "" for e in ET.fromstring(data).iter(f"{{{DAV}}}href")]
        if status == 207
        else []
    )
    books = [h for h in all_hrefs if "kith-probe-" in h]
    if not books:
        record("setup locate probe book", f"FAIL (none found, status {status})")
        print("\n# SUMMARY", flush=True)
        for step, verdict in results:
            print(f"  {step}: {verdict}", flush=True)
        return 1
    book = books[-1].rstrip("/") + "/"
    home = f"/dav/card/{USER}/"
    record("setup locate probe book", f"PASS ({book})")

    # D1: what is stored for the accepted garbage card?
    status, headers, data = req("GET", f"{book}card3.vcf")
    body = data.decode(errors="replace")
    version = body.split("VERSION:")[1][:3] if "VERSION:" in body else "absent"
    record(
        "D1 GET garbage card3 stored form",
        f"STORED ({len(data)} bytes, VERSION={version})"
        if status == 200
        else f"GONE ({status})",
    )

    # D2: If-Match with the REAL etag (case-insensitive header lookup).
    status, headers, data = req("GET", f"{book}card1.vcf")
    etag = headers.get("etag", "")
    stored = data.decode(errors="replace")
    uid = next(
        (line[4:] for line in stored.splitlines() if line.startswith("UID:")),
        "diag-uid",
    )
    record("D2a GET card1 etag", f"PASS ({etag})" if etag else "FAIL (no etag header)")
    updated = stored.replace("FN:Kith Probe One", "FN:Kith Diag Updated")
    status, headers, data = req(
        "PUT",
        f"{book}card1.vcf",
        updated,
        extra={"Content-Type": "text/vcard; charset=utf-8", "If-Match": etag},
    )
    record(
        "D2b PUT If-Match real etag",
        "PASS (2xx)" if status in (200, 201, 204) else f"REJECTED ({status})",
    )
    status, headers, data = req("GET", f"{book}card1.vcf")
    stored2 = data.decode(errors="replace")
    record(
        "D2c post-update round-trip",
        f"FN={'Kith Diag Updated' in stored2}, UID preserved={f'UID:{uid}' in stored2}",
    )

    # D3a: token, PUT card7, delta.
    status, headers, data = req("REPORT", book, sync_body(None), depth="1")
    tok = prop(data, "sync-token")
    initial = card_hrefs(data)
    record("D3a-1 initial sync members", f"{len(initial)} member hrefs, token={tok}")
    req(
        "PUT",
        f"{book}card7.vcf",
        vcard(f"diag-card7-{int(time.time())}", "Kith Diag Seven"),
        extra={"Content-Type": "text/vcard; charset=utf-8"},
    )
    status, headers, data = req("REPORT", book, sync_body(tok), depth="1")
    delta = card_hrefs(data)
    tok2 = prop(data, "sync-token")
    record(
        "D3a-2 delta after PUT card7",
        f"{len(delta)} changed hrefs, token {tok} -> {tok2}",
    )

    # D3b: explicit sync-level.
    req(
        "PUT",
        f"{book}card8.vcf",
        vcard(f"diag-card8-{int(time.time())}", "Kith Diag Eight"),
        extra={"Content-Type": "text/vcard; charset=utf-8"},
    )
    status, headers, data = req("REPORT", book, sync_body(tok2, level=True), depth="1")
    delta = card_hrefs(data)
    tok3 = prop(data, "sync-token")
    record(
        "D3b delta after card8 (sync-level form)",
        f"{len(delta)} changed hrefs, token -> {tok3}",
    )

    # D3c: DELETE then delta.
    status, _, _ = req("DELETE", f"{book}card7.vcf")
    record("D3c-1 DELETE card7", f"status {status}")
    status, headers, data = req("REPORT", book, sync_body(tok3), depth="1")
    delta = card_hrefs(data)
    n404 = data.count(b"404")
    record(
        "D3c-2 delta after DELETE",
        f"{len(delta)} hrefs, {n404} x 404 status entries",
    )

    # D3d: the long-lived default book.
    status, headers, data = req("REPORT", f"{home}default/", sync_body(None), depth="1")
    tok_d = prop(data, "sync-token")
    record(
        "D3d default-book initial sync",
        f"status {status}, {len(card_hrefs(data))} member hrefs, token={tok_d}",
    )

    print("\n# SUMMARY", flush=True)
    for step, verdict in results:
        print(f"  {step}: {verdict}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
