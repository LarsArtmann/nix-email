#!/usr/bin/env python3
"""EventSource push probe against the demo VM's JMAP endpoint (0.16).

Prints every server-sent line with a timestamp; runs for --seconds.
Verifies: (a) the stream opens and pings, (b) an Email push arrives when
a message is delivered while we listen, (c) the connection behavior we
rely on for InboxClean's push contract.
"""

import argparse
import base64
import http.client
import sys
import time
import urllib.parse

parser = argparse.ArgumentParser()
parser.add_argument("--seconds", type=int, default=45)
parser.add_argument("--types", default="Email")
parser.add_argument("--closeafter", default="no")
args = parser.parse_args()

creds = base64.b64encode(b"demo@mail.demo.test:demo-nixemail-2026").decode()
url = urllib.parse.urlparse(
    f"http://127.0.0.1:18080/jmap/eventsource/?types={args.types}&closeafter={args.closeafter}"
)
conn = http.client.HTTPConnection(url.hostname, url.port, timeout=10)
start = time.time()
conn.request(
    "GET",
    url.path + "?" + url.query,
    headers={"Authorization": f"Basic {creds}", "Accept": "text/event-stream"},
)
resp = conn.getresponse()
print(f"[{time.time() - start:7.2f}s] HTTP {resp.status} {resp.reason}", flush=True)
if resp.status != 200:
    print(resp.read().decode(errors="replace")[:500])
    sys.exit(1)
conn.sock.settimeout(max(1, args.seconds))
try:
    while True:
        remaining = args.seconds - (time.time() - start)
        if remaining <= 0:
            print(f"[{time.time() - start:7.2f}s] probe window elapsed", flush=True)
            break
        conn.sock.settimeout(remaining)
        try:
            line = resp.fp.readline()
        except TimeoutError:
            print(
                f"[{time.time() - start:7.2f}s] (read timeout - no data in window)",
                flush=True,
            )
            break
        if not line:
            print(
                f"[{time.time() - start:7.2f}s] EOF - server closed the stream",
                flush=True,
            )
            break
        text = line.decode(errors="replace").rstrip("\n")
        if text:
            print(f"[{time.time() - start:7.2f}s] {text}", flush=True)
except Exception as exc:  # noqa: BLE001 - probe tool, report and exit
    print(f"[{time.time() - start:7.2f}s] EXC {exc!r}", flush=True)
    sys.exit(2)
