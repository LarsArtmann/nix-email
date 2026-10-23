#!/usr/bin/env python3
"""T06: SOCIALPROFILE-without-uri edge probe (pin 0.16.22).

Upstream issue-class #2884: a SOCIALPROFILE carrying service + username
parameters but NO uri value. PUT such a card via CardDAV, then compare what
comes back through:
  - CardDAV GET (raw stored form)
  - JMAP ContactCard/get (the parsed JSContact-ish view)

Verdict recorded in the transcript; appended to the assessment addendum.
"""

import base64
import http.client
import json
import sys
import time

HOST, PORT = "127.0.0.1", 18080
USER = "demo@mail.demo.test"
PASS = "demo-nixemail-2026"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
HOME = f"/dav/card/{USER}/"
CARD = f"{HOME}social-edge.vcf"

FIXTURE = (
    "BEGIN:VCARD\r\nVERSION:4.0\r\n"
    "UID:social-edge-1\r\n"
    "FN:Social Edge\r\n"
    "N:Edge;Social;;;\r\n"
    "EMAIL:social-edge@example.com\r\n"
    "SOCIALPROFILE;SERVICE-TYPE=Mastodon;USERNAME=edgeuser:\r\n"
    "SOCIALPROFILE:https://github.com/edgeuser\r\n"
    "END:VCARD\r\n"
)


def req(method, path, body=None, extra=None, timeout=60):
    conn = http.client.HTTPConnection(HOST, PORT, timeout=timeout)
    headers = {"Authorization": f"Basic {CREDS}"}
    headers.update(extra or {})
    if body is not None:
        headers["Content-Type"] = (
            "application/json"
            if path.startswith("/jmap")
            else "text/vcard; charset=utf-8"
        )
    print(f"\n>> {method} {path}", flush=True)
    if body:
        print(
            body if len(body) <= 800 else body[:800] + "\n... (truncated)", flush=True
        )
    conn.request(method, path, body=body, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    lower = {k.lower(): v for k, v in resp.getheaders()}
    print(f"<< {resp.status} {resp.reason}", flush=True)
    if data:
        text = data.decode(errors="replace")
        print(
            text if len(text) <= 2000 else text[:2000] + "\n... (truncated)", flush=True
        )
    conn.close()
    return resp.status, lower, data


def main() -> int:
    print(
        f"# SOCIALPROFILE edge probe {time.strftime('%Y-%m-%dT%H:%M:%S%z')}", flush=True
    )

    # T06.1: PUT the fixture.
    status, _, _ = req("PUT", CARD, FIXTURE)
    print(f"\nVERDICT T06.1 PUT fixture: {status}", flush=True)

    # T06.2a: CardDAV GET back.
    status, _, data = req("GET", CARD)
    stored = data.decode(errors="replace")
    print(
        f"\nVERDICT T06.2a CardDAV GET: status {status}, "
        f"uri-less SOCIALPROFILE preserved={'USERNAME=edgeuser:' in stored}, "
        f"uri SOCIALPROFILE preserved={'SOCIALPROFILE:https' in stored}",
        flush=True,
    )

    # T06.2b: JMAP ContactCard/get.
    jmap_call = json.dumps(
        {
            "using": ["urn:ietf:params:jmap:contacts"],
            "methodCalls": [
                [
                    "ContactCard/get",
                    {
                        "accountId": "c",
                        "#ids": {
                            "resultOf": "c0",
                            "name": "Card/query",
                            "path": "/ids",
                        },
                    },
                    "c1",
                ],
                [
                    "Card/query",
                    {"accountId": "c", "filter": {"uid": "social-edge-1"}},
                    "c0",
                ],
            ],
        }
    )
    status, _, data = req("POST", "/jmap", jmap_call)
    try:
        body = json.loads(data)
        for m in body.get("methodResponses", []):
            if m[0] == "ContactCard/get":
                cards = m[1].get("list", [])
                print(
                    f"\nVERDICT T06.2b JMAP ContactCard/get: {len(cards)} card(s)",
                    flush=True,
                )
                for c in cards:
                    print(json.dumps(c, indent=1)[:1500], flush=True)
            elif m[0] not in ("Card/query",):
                print(
                    f"\nVERDICT T06.2b JMAP {m[0]}: {json.dumps(m[1])[:400]}",
                    flush=True,
                )
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"\nVERDICT T06.2b JMAP parse failed: {e}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
