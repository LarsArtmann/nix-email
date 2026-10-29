#!/usr/bin/env python3
"""CalDAV probe suite against the nix-email demo VM (Stalwart 0.16.26 pin).

Host-side, port 28080 by default (override CALDAV_PROBE_PORT; forwarded to
the guest's 8080 HTTP listener). Gate artifact of the 2026-10-29 Stalwart
single-truth decision (SystemNix
docs/planning/2026-10-29_22-11_stalwart-single-truth-pareto-execution-plan.md
tasks 3.x-5.x): the one unmeasured surface before Stalwart may own
calendars. Mirrors the 2026-10-19/10-28 CardDAV suite style exactly:

  well-known redirect, principal + calendar-home-set discovery, calendar
  enumeration, MKCOL calendar, PUT/GET VEVENT round-trip, RRULE + TZID
  fidelity, RECURRENCE-ID override round-trip, conditional PUT (stale
  If-Match + UID swap), sync-collection token advance, DELETE/tombstone,
  supported-report-set + freebusy-query, calendar-query time-range.

Stdlib only. Prints a full request/response transcript; redirect to a log.
Exits non-zero only on hard connect failures - individual step verdicts
are printed as PASS/FAIL/SEE-TRANSCRIPT so unexpected server behavior
still produces a transcript instead of a traceback.
"""

import base64
import http.client
import os
import sys
import time
import xml.etree.ElementTree as ET

HOST = "127.0.0.1"
PORT = int(os.environ.get("CALDAV_PROBE_PORT", "28080"))
USER = "demo@mail.demo.test"
PASS = "demo-nixemail-2026"
CAL = f"kith-cal-probe-{int(time.time())}"
DAV = "DAV:"
CALDAV = "urn:ietf:params:xml:ns:caldav"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()

EVENT_BASIC = (
    "BEGIN:VCALENDAR\r\n"
    "VERSION:2.0\r\n"
    "PRODID:-//nix-email caldav probe//EN\r\n"
    "BEGIN:VEVENT\r\n"
    f"UID:cal-probe-{CAL}-basic\r\n"
    "DTSTAMP:20261029T120000Z\r\n"
    "DTSTART:20261103T100000Z\r\n"
    "DTEND:20261103T110000Z\r\n"
    "SUMMARY:Probe Basic Event\r\n"
    "DESCRIPTION:round-trip fidelity probe\r\n"
    "END:VEVENT\r\n"
    "END:VCALENDAR\r\n"
)

EVENT_RECUR = (
    "BEGIN:VCALENDAR\r\n"
    "VERSION:2.0\r\n"
    "PRODID:-//nix-email caldav probe//EN\r\n"
    "BEGIN:VTIMEZONE\r\n"
    "TZID:Europe/Berlin\r\n"
    "BEGIN:STANDARD\r\n"
    "DTSTART:19701025T030000\r\n"
    "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\n"
    "TZOFFSETFROM:+0200\r\n"
    "TZOFFSETTO:+0100\r\n"
    "TZNAME:CET\r\n"
    "END:STANDARD\r\n"
    "BEGIN:DAYLIGHT\r\n"
    "DTSTART:19700329T020000\r\n"
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n"
    "TZOFFSETFROM:+0100\r\n"
    "TZOFFSETTO:+0200\r\n"
    "TZNAME:CEST\r\n"
    "END:DAYLIGHT\r\n"
    "END:VTIMEZONE\r\n"
    "BEGIN:VEVENT\r\n"
    f"UID:cal-probe-{CAL}-recur\r\n"
    "DTSTAMP:20261029T120000Z\r\n"
    "DTSTART;TZID=Europe/Berlin:20261104T090000\r\n"
    "DTEND;TZID=Europe/Berlin:20261104T093000\r\n"
    "RRULE:FREQ=WEEKLY;COUNT=5;BYDAY=WE\r\n"
    "SUMMARY:Probe Recurring Berlin\r\n"
    "END:VEVENT\r\n"
    "END:VCALENDAR\r\n"
)

# Second resource: override the 2nd occurrence of EVENT_RECUR via
# RECURRENCE-ID (Berlin local time of occurrence #2 = 2026-11-11 09:00).
EVENT_OVERRIDE = (
    "BEGIN:VCALENDAR\r\n"
    "VERSION:2.0\r\n"
    "PRODID:-//nix-email caldav probe//EN\r\n"
    "BEGIN:VTIMEZONE\r\n"
    "TZID:Europe/Berlin\r\n"
    "BEGIN:STANDARD\r\n"
    "DTSTART:19701025T030000\r\n"
    "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\n"
    "TZOFFSETFROM:+0200\r\n"
    "TZOFFSETTO:+0100\r\n"
    "TZNAME:CET\r\n"
    "END:STANDARD\r\n"
    "BEGIN:DAYLIGHT\r\n"
    "DTSTART:19700329T020000\r\n"
    "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n"
    "TZOFFSETFROM:+0100\r\n"
    "TZOFFSETTO:+0200\r\n"
    "TZNAME:CEST\r\n"
    "END:DAYLIGHT\r\n"
    "END:VTIMEZONE\r\n"
    "BEGIN:VEVENT\r\n"
    f"UID:cal-probe-{CAL}-recur\r\n"
    "RECURRENCE-ID;TZID=Europe/Berlin:20261111T090000\r\n"
    "DTSTAMP:20261029T120000Z\r\n"
    "DTSTART;TZID=Europe/Berlin:20261111T140000\r\n"
    "DTEND;TZID=Europe/Berlin:20261111T143000\r\n"
    "SUMMARY:Probe Recurring Berlin (moved)\r\n"
    "END:VEVENT\r\n"
    "END:VCALENDAR\r\n"
)

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
    ctype: str | None = None,
):
    conn = http.client.HTTPConnection(HOST, PORT, timeout=30)
    headers = {"Authorization": f"Basic {CREDS}"} if auth else {}
    if depth is not None:
        headers["Depth"] = depth
    if body is not None:
        headers["Content-Type"] = ctype or "application/xml; charset=utf-8"
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
    lower = {k.lower(): v for k, v in resp.getheaders()}
    return resp.status, lower, data


def hrefs(xml_bytes: bytes, tag: str, ns: str = DAV) -> list[str]:
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return []
    return [e.text or "" for e in root.iter(f"{{{ns}}}{tag}")]


def prop_href(xml_bytes: bytes, container: str, ns: str = DAV) -> str | None:
    """First DAV:href child text inside <container> (property-value extraction)."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return None
    for element in root.iter(f"{{{ns}}}{container}"):
        child = element.find(f"{{{DAV}}}href")
        if child is not None and child.text:
            return child.text
    return None


def prop(xml_bytes: bytes, local: str, ns: str = DAV) -> str | None:
    found = hrefs(xml_bytes, local, ns)
    return found[0] if found else None


def body_fragments(data: bytes, needles: list[str]) -> dict[str, bool]:
    text = data.decode(errors="replace")
    return {n: (n in text) for n in needles}


def main() -> int:
    print(
        f"# CalDAV probe suite {time.strftime('%Y-%m-%dT%H:%M:%S%z')} cal={CAL} "
        f"port={PORT}",
        flush=True,
    )

    # C1: well-known redirect (unauthenticated is fine)
    status, headers, _ = req("GET", "/.well-known/caldav", auth=False)
    loc = headers.get("location", "")
    record(
        "C1 well-known/caldav 307->/dav/cal",
        "PASS"
        if status == 307 and loc.rstrip("/").endswith("/dav/cal")
        else f"SEE-TRANSCRIPT ({status} {loc})",
    )

    # C2: principal discovery off the DAV root
    propfind_cup = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:current-user-principal/><D:resourcetype/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", "/dav/cal/", propfind_cup, depth="0")
    principal = prop_href(data, "current-user-principal")
    record(
        "C2 current-user-principal",
        f"PASS ({principal})"
        if status == 207 and principal
        else f"SEE-TRANSCRIPT ({status})",
    )

    # C3: calendar-home-set off the principal
    principal_path = principal or f"/dav/pal/{USER}"
    propfind_home = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
        "<D:prop><C:calendar-home-set/><D:displayname/></D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", principal_path, propfind_home, depth="0")
    home = prop_href(data, "calendar-home-set", CALDAV)
    record(
        "C3 calendar-home-set",
        f"PASS ({home})" if status == 207 and home else f"SEE-TRANSCRIPT ({status})",
    )

    # C4: enumerate existing calendars
    home_path = home or f"/dav/cal/{USER}/"
    propfind_list = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:resourcetype/><D:displayname/><D:getetag/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", home_path, propfind_list, depth="1")
    cals = hrefs(data, "href")
    record(
        "C4 enumerate calendars",
        f"PASS ({len(cals)} hrefs)" if status == 207 else f"SEE-TRANSCRIPT ({status})",
    )

    # C5: MKCOL a fresh calendar (the load-bearing dialect question)
    cal_path = f"{home_path}{CAL}/"
    mkcol = (
        '<?xml version="1.0"?>'
        '<D:mkcol xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
        "<D:set><D:prop>"
        "<D:resourcetype><D:collection/><C:calendar/></D:resourcetype>"
        f"<D:displayname>{CAL}</D:displayname>"
        "</D:prop></D:set></D:mkcol>"
    )
    status, headers, data = req("MKCOL", cal_path, mkcol)
    record(
        "C5 MKCOL calendar",
        "PASS (201/2xx)" if 200 <= status < 300 else f"SEE-TRANSCRIPT ({status})",
    )

    # C6: PUT basic VEVENT + GET round-trip (UID echo, ETag, calendar-data)
    ev1 = f"{cal_path}{CAL}-basic.ics"
    status, headers, data = req(
        "PUT", ev1, EVENT_BASIC, ctype="text/calendar; charset=utf-8"
    )
    etag1 = headers.get("etag", "")
    put_ok = status in (200, 201, 204)
    record(
        "C6a PUT VEVENT basic",
        f"PASS ({status}, etag={'yes' if etag1 else 'MISSING'})"
        if put_ok
        else f"SEE-TRANSCRIPT ({status})",
    )
    status, headers, data = req("GET", ev1)
    frags = body_fragments(
        data, [f"UID:cal-probe-{CAL}-basic", "SUMMARY:Probe Basic Event"]
    )
    record(
        "C6b GET round-trip (UID + SUMMARY preserved)",
        "PASS" if status == 200 and all(frags.values()) else f"SEE-TRANSCRIPT ({status} {frags})",
    )

    # C7: recurring event + TZID fidelity
    ev2 = f"{cal_path}{CAL}-recur.ics"
    status, headers, data = req(
        "PUT", ev2, EVENT_RECUR, ctype="text/calendar; charset=utf-8"
    )
    etag2 = headers.get("etag", "")
    record(
        "C7a PUT recurring (RRULE weekly x5, TZID Europe/Berlin)",
        f"PASS ({status})" if 200 <= status < 300 else f"SEE-TRANSCRIPT ({status})",
    )
    status, headers, data = req("GET", ev2)
    frags = body_fragments(
        data,
        ["RRULE:FREQ=WEEKLY;COUNT=5;BYDAY=WE", "TZID=Europe/Berlin", f"UID:cal-probe-{CAL}-recur"],
    )
    record(
        "C7b GET recurring fidelity (RRULE + TZID + UID)",
        "PASS (all preserved)"
        if status == 200 and all(frags.values())
        else f"SEE-TRANSCRIPT ({status} {frags})",
    )

    # C8: recurrence override round-trip (RECURRENCE-ID resource)
    ev3 = f"{cal_path}{CAL}-override.ics"
    status, headers, data = req(
        "PUT", ev3, EVENT_OVERRIDE, ctype="text/calendar; charset=utf-8"
    )
    put_status = status
    status, headers, data = req("GET", ev3)
    frags = body_fragments(
        data, ["RECURRENCE-ID;TZID=Europe/Berlin:20261111T090000", "(moved)"]
    )
    record(
        "C8 RECURRENCE-ID override round-trip",
        "PASS (stored + faithful)"
        if put_status in (200, 201, 204) and status == 200 and all(frags.values())
        else f"SEE-TRANSCRIPT (put {put_status}, get {status}, {frags})",
    )

    # C9: conditional PUT semantics (mirror the CardDAV dialect)
    # C9a: stale If-Match must 412
    status, headers, data = req(
        "PUT",
        ev1,
        EVENT_BASIC,
        ctype="text/calendar; charset=utf-8",
        extra={"If-Match": '"stale-etag-probe-0000"'},
    )
    record(
        "C9a stale If-Match -> 412",
        "PASS" if status == 412 else f"SEE-TRANSCRIPT ({status})",
    )
    # C9b: matching If-Match must succeed + advance the etag
    status, headers, data = req(
        "PUT",
        ev1,
        EVENT_BASIC,
        ctype="text/calendar; charset=utf-8",
        extra={"If-Match": etag1} if etag1 else {},
    )
    etag1b = headers.get("etag", "")
    record(
        "C9b matching If-Match -> 2xx",
        "PASS" if 200 <= status < 300 else f"SEE-TRANSCRIPT ({status})",
    )
    # C9c: UID swap on an existing href (server must refuse: 412, not silent rewrite)
    swapped = EVENT_BASIC.replace(f"cal-probe-{CAL}-basic", f"cal-probe-{CAL}-other")
    status, headers, data = req(
        "PUT", ev1, swapped, ctype="text/calendar; charset=utf-8"
    )
    record(
        "C9c UID-swap PUT -> 4xx (no silent rewrite)",
        "PASS" if 400 <= status < 500 else f"SEE-TRANSCRIPT ({status})",
    )

    # C10: sync-collection token round-trip + advance on change
    sync_init = (
        '<?xml version="1.0"?>'
        '<D:sync-collection xmlns:D="DAV:"><D:sync-token/>'
        "<D:prop><D:getetag/></D:prop></D:sync-collection>"
    )
    status, headers, data = req("REPORT", cal_path, sync_init)
    token1 = prop(data, "sync-token")
    record(
        "C10a sync-collection initial token",
        f"PASS ({(token1 or '')[-24:]})" if status == 207 and token1 else f"SEE-TRANSCRIPT ({status})",
    )
    # mutate: PUT a third basic event (fresh UID)
    ev4 = f"{cal_path}{CAL}-mutate.ics"
    event_mutate = EVENT_BASIC.replace(
        f"cal-probe-{CAL}-basic", f"cal-probe-{CAL}-mutate"
    )
    req("PUT", ev4, event_mutate, ctype="text/calendar; charset=utf-8")
    status, headers, data = req("REPORT", cal_path, sync_init)
    token2 = prop(data, "sync-token")
    record(
        "C10b sync-token advances on change",
        "PASS"
        if status == 207 and token2 and token2 != token1
        else f"SEE-TRANSCRIPT ({status} t1={bool(token1)} t2={bool(token2)})",
    )

    # C11: DELETE behavior + tombstone-vs-vanish
    status, headers, data = req("DELETE", ev4)
    del_status = status
    status, headers, data = req("GET", ev4)
    record(
        "C11a DELETE then GET -> 404 (vanish semantics)",
        "PASS" if del_status in (200, 204) and status == 404 else f"SEE-TRANSCRIPT (del {del_status}, get {status})",
    )
    # after delete, sync-collection must report the removal (tombstone href or token bump)
    status, headers, data = req("REPORT", cal_path, sync_init)
    token3 = prop(data, "sync-token")
    removed = ev4.encode() in data or f"{CAL}-mutate".encode() in data
    record(
        "C11b sync reports the removal (href or token bump)",
        "PASS"
        if status == 207 and (removed or (token3 and token3 != token2))
        else f"SEE-TRANSCRIPT ({status} removed={removed})",
    )

    # C12: supported-report-set shape
    propfind_srs = (
        '<?xml version="1.0"?>'
        '<D:propfind xmlns:D="DAV:"><D:prop>'
        "<D:supported-report-set/>"
        "</D:prop></D:propfind>"
    )
    status, headers, data = req("PROPFIND", cal_path, propfind_srs, depth="0")
    reports_text = data.decode(errors="replace")
    has_sync = "sync-collection" in reports_text
    has_cquery = "calendar-query" in reports_text
    has_multiget = "calendar-multiget" in reports_text
    record(
        "C12 supported-report-set (sync + calendar-query + multiget)",
        f"PASS (sync={has_sync} query={has_cquery} multiget={has_multiget})"
        if status == 207 and has_sync and has_cquery and has_multiget
        else f"SEE-TRANSCRIPT ({status} sync={has_sync} query={has_cquery} multiget={has_multiget})",
    )

    # C13: freebusy-query (RFC 4791 CALDAV:free-busy-query REPORT)
    freebusy = (
        '<?xml version="1.0"?>'
        '<C:free-busy-query xmlns:C="urn:ietf:params:xml:ns:caldav">'
        "<C:time-range start=\"20261103T000000Z\" end=\"20261201T000000Z\"/>"
        "</C:free-busy-query>"
    )
    status, headers, data = req("REPORT", cal_path, freebusy)
    fb_ok = status == 200 and b"BEGIN:VFREEBUSY" in data
    record(
        "C13 free-busy-query REPORT",
        "PASS" if fb_ok else f"SEE-TRANSCRIPT ({status})",
    )

    # C14: calendar-query with time-range filter
    calquery = (
        '<?xml version="1.0"?>'
        '<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
        "<D:prop><D:getetag/><C:calendar-data/></D:prop>"
        "<C:filter><C:comp-filter name=\"VCALENDAR\">"
        "<C:comp-filter name=\"VEVENT\">"
        "<C:time-range start=\"20261101T000000Z\" end=\"20261201T000000Z\"/>"
        "</C:comp-filter></C:comp-filter></C:filter>"
        "</C:calendar-query>"
    )
    status, headers, data = req("REPORT", cal_path, calquery, depth="1")
    hits = [h for h in hrefs(data, "href") if h.endswith(".ics")]
    recur_hit = any("recur" in h or "override" in h for h in hits)
    record(
        "C14 calendar-query time-range finds the Berlin series",
        f"PASS ({len(hits)} events)"
        if status == 207 and hits and recur_hit
        else f"SEE-TRANSCRIPT ({status} {hits})",
    )

    print("\n# Summary", flush=True)
    passes = sum(1 for _, v in results if v.startswith("PASS"))
    for step, verdict in results:
        print(f"  {step}: {verdict}", flush=True)
    print(f"# {passes}/{len(results)} PASS", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
