#!/usr/bin/env python3
"""T14: E2E driver — CRM -> Stalwart demo-VM mirror via the real binary.

Seeds a throwaway CRM (HTTP form posts against a locally booted
crm-server), then the orchestration shell runs the -carddav-sync one-shot
against the demo VM (Stalwart 0.16.22 pin, port 18080) and this script
asserts the server-side outcome: card set, vCard field shapes, idempotent
rerun, and the CRM-wins conflict path after a simulated device edit.

Run via the surrounding shell transcript (carddav-e2e.log); every verdict
prints VERDICT for the transcript.
"""

import base64
import http.client
import re
import sys
import time
import xml.etree.ElementTree as ET

CRM, CRM_PORT = "127.0.0.1", 18099
DAV, DAV_PORT = "127.0.0.1", 18080
USER, PASS = "demo@mail.demo.test", "demo-nixemail-2026"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
BOOK = "/dav/card/demo@mail.demo.test/Kith-E2E/"

results: list[tuple[str, str]] = []


def record(step: str, verdict: str) -> None:
    results.append((step, verdict))
    print(f"VERDICT {step}: {verdict}", flush=True)


def crm_req(method, path, body=None, extra=None):
    conn = http.client.HTTPConnection(CRM, CRM_PORT, timeout=15)
    headers = dict(extra or {})
    if body is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    loc = resp.getheader("Location", "")
    conn.close()
    return resp.status, loc, data


def dav_req(method, path, body=None, extra=None, depth=None):
    conn = http.client.HTTPConnection(DAV, DAV_PORT, timeout=60)
    headers = {"Authorization": f"Basic {CREDS}"}
    if depth is not None:
        headers["Depth"] = depth
    if body is not None:
        headers["Content-Type"] = "application/xml; charset=utf-8"
    headers.update(extra or {})
    print(f"\n>> DAV {method} {path}", flush=True)
    if body:
        print(body if len(body) <= 500 else body[:500] + "…", flush=True)
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    print(f"<< {resp.status}", flush=True)
    conn.close()
    return resp.status, data


def form_key(page: bytes) -> str:
    match = re.search(rb'name="form_key" value="([^"]+)"', page)
    return match.group(1).decode() if match else ""


def wait_crm_contacts(want: int, tries: int = 100) -> bool:
    for _ in range(tries):
        status, _, page = crm_req("GET", "/contacts")
        if status == 200 and page.count(b"/contacts/") >= want + 1:
            return True
        time.sleep(0.2)
    return False


def seed() -> None:
    status, _, page = crm_req("GET", "/contacts")
    if status != 200:
        record("E2E-seed open contacts page", f"FAIL ({status})")
        return

    key = form_key(page)
    record("E2E-seed form_key", f"{'PASS' if key else 'FAIL'} ({len(key)} chars)")

    status, loc, _ = crm_req(
        "POST",
        "/companies",
        body=f"form_key={key}&name=ACME E2E GmbH&domain=acme-e2e.test",
    )
    record("E2E-seed create company", f"{status} -> {loc}")

    status, _, page = crm_req("GET", "/contacts")
    match = re.search(rb'<option value="([^"]+)"[^>]*>ACME E2E', page)
    org_id = match.group(1).decode() if match else ""
    record("E2E-seed resolve company id", f"{'PASS' if org_id else 'FAIL'} ({org_id})")

    key = form_key(page)
    status, loc, _ = crm_req(
        "POST",
        "/contacts",
        body=(
            f"form_key={key}&email=ada@example.com&first_name=Ada&last_name=Lovelace"
            f"&company_id={org_id}&phones=+49 170 0000001"
        ),
    )
    record("E2E-seed create Ada", f"{status} -> {loc}")

    status, _, page = crm_req("GET", "/contacts")
    key = form_key(page)
    status, loc, _ = crm_req(
        "POST",
        "/contacts",
        body=f"form_key={key}&email=grace@example.com&first_name=Grace&company_id=",
    )
    record("E2E-seed create Grace", f"{status} -> {loc}")

    record(
        "E2E-seed projections settled",
        "PASS" if wait_crm_contacts(2) else "FAIL (timeout)",
    )


def eventually(check, tries: int = 60, delay: float = 0.25):
    """Stalwart ingests PUT cards ASYNCHRONOUSLY: address-data renders from
    the parsed contact store, so an immediate readback can be partial
    (observed 2026-10-20: +30ms after PUT the cards rendered UID-only) and
    the normalized form (KIND upper-cased, TEL leading + stripped) lands
    only once the import settles. Retry until the invariant holds."""
    detail = None
    for _ in range(tries):
        ok, detail = check()
        if ok:
            return True, detail
        time.sleep(delay)
    return False, detail


def book_hrefs() -> list[str]:
    body = (
        '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/></D:prop></D:propfind>"
    )
    _, data = dav_req("PROPFIND", BOOK, body=body, depth="1")
    return [
        e.text
        for e in ET.fromstring(data).iter("{DAV:}href")
        if (e.text or "").endswith(".vcf")
    ]


def multiget_cards(hrefs: list[str]) -> str:
    multiget = (
        '<?xml version="1.0"?>'
        '<C:addressbook-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">'
        "<D:prop><D:getetag/><C:address-data/></D:prop>"
        + "".join(f"<D:href>{h}</D:href>" for h in hrefs)
        + "</C:addressbook-multiget>"
    )
    _, data = dav_req("REPORT", BOOK, body=multiget, depth="1")
    return data.decode(errors="replace")


def assert_mirror() -> None:
    hrefs = book_hrefs()
    record("E2E-1 book exists with 2 cards", f"{len(hrefs)} cards")

    def shapes_ok():
        cards = multiget_cards(hrefs)
        shapes = {
            "VERSION:4.0": (2, len(re.findall(r"VERSION:4\.0", cards))),
            "KIND individual": (
                2,
                len(re.findall(r"KIND:INDIVIDUAL", cards, re.IGNORECASE)),
            ),
            "FN:Ada Lovelace": (1, cards.count("FN:Ada Lovelace")),
            "N:Lovelace;Ada;;;": (1, cards.count("N:Lovelace;Ada;;;")),
            "EMAIL:ada@example.com": (1, cards.count("EMAIL:ada@example.com")),
            "TEL +49 170 0000001": (
                1,
                len(re.findall(r"TEL:\+?49 170 0000001", cards)),
            ),
            "ORG:ACME E2E GmbH": (1, cards.count("ORG:ACME E2E GmbH")),
            "FN:Grace": (1, cards.count("FN:Grace")),
            "EMAIL:grace@example.com": (1, cards.count("EMAIL:grace@example.com")),
        }
        bad = {name: got for name, (want, got) in shapes.items() if got != want}
        return not bad, (bad, cards)

    ok, (bad, cards) = eventually(shapes_ok)
    if not ok:
        print(repr(cards[:4000]), flush=True)
    record("E2E-2 vCard field shapes (settled)", "PASS" if ok else f"FAIL {bad}")

    uid_lines = re.findall(r"UID:([0-9A-HJKMNP-TV-Z]{26})", cards)
    record(
        "E2E-3 UIDs are bare ULIDs",
        f"PASS ({len(uid_lines)}/2)" if len(uid_lines) == 2 else "FAIL",
    )


def device_edit_and_restore() -> None:
    # The etag-bearing listing feeds a CONDITIONAL device PUT: Stalwart
    # rejects an unconditional PUT onto an existing card with 412
    # (observed 2026-10-20; the CRM runner itself always sends If-Match).
    body = (
        '<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/><D:getetag/></D:prop></D:propfind>"
    )
    _, data = dav_req("PROPFIND", BOOK, body=body, depth="1")
    pairs = sorted(
        (
            resp.findtext("{DAV:}href") or "",
            resp.findtext("{DAV:}propstat/{DAV:}prop/{DAV:}getetag") or "",
        )
        for resp in ET.fromstring(data).iter("{DAV:}response")
        if (resp.findtext("{DAV:}href") or "").endswith(".vcf")
    )
    victim, etag = pairs[0]

    # Realistic device edit: same href, same vCard UID, changed content.
    # (A UID-CHANGING PUT is impossible on Stalwart — 412 no-uid-conflict,
    # observed 2026-10-20 — so real devices always edit in place.)
    uid = victim.rsplit("/", 1)[1][: -len(".vcf")]

    status, _ = dav_req(
        "PUT",
        victim,
        body=f"BEGIN:VCARD\r\nVERSION:4.0\r\nUID:{uid}\r\nFN:Device Wins\r\nEND:VCARD\r\n",
        extra={"Content-Type": "text/vcard; charset=utf-8", "If-Match": etag},
    )
    record(
        "E2E-4 device edit PUT (If-Match)",
        "PASS" if status in (200, 201, 204) else f"FAIL ({status})",
    )

    def staged():
        cards = multiget_cards([victim])
        return "Device Wins" in cards, cards

    ok, cards = eventually(staged)
    if not ok:
        print(repr(cards[:4000]), flush=True)
    record("E2E-4b device edit staged (settled)", "PASS" if ok else "FAIL")


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "seed"
    print(
        f"# carddav E2E driver ({mode}) {time.strftime('%Y-%m-%dT%H:%M:%S%z')}",
        flush=True,
    )

    if mode == "seed":
        seed()
    elif mode == "assert":
        assert_mirror()
    elif mode == "conflict":
        device_edit_and_restore()
    elif mode == "verify-restore":

        def restored():
            cards = multiget_cards(book_hrefs())
            return "Device Wins" not in cards and "FN:Ada Lovelace" in cards, cards

        ok, cards = eventually(restored)
        if not ok:
            print(repr(cards[:4000]), flush=True)
        record("E2E-5 CRM wins after device edit (settled)", "PASS" if ok else "FAIL")

    print("\n# SUMMARY", flush=True)
    for step, verdict in results:
        print(f"  {step}: {verdict}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
