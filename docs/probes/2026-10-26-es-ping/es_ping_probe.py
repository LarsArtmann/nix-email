#!/usr/bin/env python3
"""EventSource `ping` parameter probe against the demo VM's JMAP endpoint.

Closes the last unprobed 0.16 JMAP EventSource quirk: 0.15.5 answered
400 whenever `ping` was present (INBOXCLEAN.md parameter matrix). This
probe answers, on 0.16.22: (a) is `ping` accepted, (b) does the server
emit keep-alive comments at the requested cadence, (c) what do
degenerate values do (0, non-numeric).

Modes (--mode): ping    - types=Email&closeafter=no&ping=<ms>, watch
                        for keep-alive comments and their cadence
                control - types=Email&closeafter=no alone, same window
                bad     - ping=0 and ping=abc acceptance checks
"""

import argparse
import base64
import http.client
import time
import urllib.parse

parser = argparse.ArgumentParser()
parser.add_argument("--seconds", type=int, default=12)
parser.add_argument("--mode", choices=["ping", "control", "bad"], default="ping")
parser.add_argument("--ping", type=int, default=2000)
args = parser.parse_args()

CREDS = base64.b64encode(b"demo@mail.demo.test:demo-nixemail-2026").decode()


def open_stream(query, label, seconds):
    url = urllib.parse.urlparse(f"http://127.0.0.1:18080/jmap/eventsource/?{query}")
    conn = http.client.HTTPConnection(url.hostname, url.port, timeout=10)
    start = time.time()
    conn.request(
        "GET",
        url.path + "?" + url.query,
        headers={"Authorization": f"Basic {CREDS}", "Accept": "text/event-stream"},
    )
    resp = conn.getresponse()
    print(f"[{label}] HTTP {resp.status} {resp.reason}", flush=True)
    if resp.status != 200:
        print(f"[{label}] body: {resp.read().decode(errors='replace')[:300]}", flush=True)
        conn.close()
        return start, False
    markers = []
    while time.time() - start < seconds:
        conn.sock.settimeout(max(0.5, seconds - (time.time() - start)))
        try:
            line = resp.fp.readline()
        except TimeoutError:
            break
        if not line:
            print(f"[{label}] EOF at {time.time() - start:6.2f}s", flush=True)
            break
        text = line.decode(errors="replace").rstrip("\n")
        if text:
            stamp = time.time() - start
            print(f"[{label} {stamp:6.2f}s] {text}", flush=True)
            if text.lstrip().startswith(":"):
                markers.append(stamp)
    if len(markers) >= 2:
        gaps = [round(b - a, 2) for a, b in zip(markers, markers[1:])]
        print(f"[{label}] keep-alive gaps: {gaps}", flush=True)
    elif not markers:
        print(f"[{label}] NO keep-alive comment in window", flush=True)
    conn.close()
    return start, True


if args.mode == "ping":
    open_stream(
        f"types=Email&closeafter=no&ping={args.ping}", f"ping={args.ping}", args.seconds
    )
elif args.mode == "control":
    open_stream("types=Email&closeafter=no", "control", args.seconds)
else:
    for query, label in [
        ("types=Email&closeafter=no&ping=0", "ping=0"),
        ("types=Email&closeafter=no&ping=abc", "ping=abc"),
        ("types=Email&closeafter=no", "closeafter-only-regression"),
    ]:
        open_stream(query, label, 4)
        time.sleep(1)
