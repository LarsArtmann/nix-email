#!/usr/bin/env python3
"""demo-smoke: one-command demo-VM smoke against the forwarded ports.

Reproduces the 2026-10-31 0.16.26 smoke (docs/probes/
2026-10-31-demo-smoke-01626/) as a checked-in probe so the next smoke
(after a bump or a demo change) is `python3 scripts/demo-smoke.py`
against a running `nix run .#vm` - host-side, stdlib only.

Legs (README quickstart ports, all on 127.0.0.1):
  1. anon JMAP session doc      GET :18080/.well-known/jmap
  2. AUTH submission round-trip SMTP :2587 STARTTLS + LOGIN, send
  3. IMAPS arrival             :2593, needle-token search
  4. catch-all accept          SMTP :2525, random local part -> 250
  5. strict domain rejection   SMTP :2525, wrong domain -> 550

Exit code 0 = all legs green; each leg prints PASS/FAIL with evidence.
"""

import imaplib
import secrets
import smtplib
import ssl
import sys
import time
import urllib.request

JMAP_URL = "http://127.0.0.1:18080/.well-known/jmap"
SUBMISSION = ("127.0.0.1", 2587)
IMAPS = ("127.0.0.1", 2593)
INBOUND = ("127.0.0.1", 2525)
USER = "demo@mail.demo.test"
PASSWORD = "demo-nixemail-2026"
DOMAIN = "mail.demo.test"

failures = []


def leg(name, ok, evidence):
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}: {evidence}")
    if not ok:
        failures.append(name)


def anon_jmap_session():
    try:
        with urllib.request.urlopen(JMAP_URL, timeout=10) as resp:
            body = resp.read().decode()
        ok = resp.status == 200 and "apiUrl" in body
        leg("anon JMAP session", ok, f"status={resp.status} apiUrl present")
        return ok
    except Exception as exc:  # probe reports, never raises
        leg("anon JMAP session", False, repr(exc))
        return False


def round_trip():
    needle = "smoke-" + secrets.token_hex(8)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with smtplib.SMTP(SUBMISSION[0], SUBMISSION[1], timeout=30) as smtp:
            smtp.starttls(context=ctx)
            smtp.login(USER, PASSWORD)
            smtp.sendmail(USER, [USER], f"Subject: {needle}\n\n{needle}\n")
        leg("AUTH submission", True, f"STARTTLS+LOGIN accepted, sent {needle}")
    except Exception as exc:  # probe reports, never raises
        leg("AUTH submission", False, repr(exc))
        return
    try:
        imap = imaplib.IMAP4_SSL(IMAPS[0], IMAPS[1], ssl_context=ctx,
                                 timeout=60)
        imap.login(USER, PASSWORD)
        imap.select("INBOX")
        for _ in range(12):
            status, data = imap.search(None, f'TEXT "{needle}"')
            if status == "OK" and data[0].split():
                leg("IMAPS round-trip", True, f"delivered, needle {needle}")
                imap.logout()
                return
            time.sleep(5)
        imap.logout()
        leg("IMAPS round-trip", False, f"needle {needle} never arrived")
    except Exception as exc:  # probe reports, never raises
        leg("IMAPS round-trip", False, repr(exc))


def catch_all_and_reject():
    local = "any-" + secrets.token_hex(4)
    try:
        with smtplib.SMTP(INBOUND[0], INBOUND[1], timeout=30) as smtp:
            smtp.sendmail(f"probe@{DOMAIN}", [f"{local}@{DOMAIN}"],
                          f"Subject: catchall\n\n{local}\n")
        leg("catch-all accept", True,
            f"unauthenticated send to {local}@{DOMAIN} accepted (250 path)")
    except (smtplib.SMTPException, OSError) as exc:
        leg("catch-all accept", False, repr(exc))
    try:
        with smtplib.SMTP(INBOUND[0], INBOUND[1], timeout=30) as smtp:
            smtp.sendmail(f"probe@{DOMAIN}", ["x@demo.test"],
                          "Subject: reject\n\nx\n")
        leg("strict domain reject", False,
            "x@demo.test was ACCEPTED - strict rejection missing")
    except smtplib.SMTPRecipientsRefused as exc:
        code = list(exc.recipients.values())[0][0]
        leg("strict domain reject", code == 550,
            f"x@demo.test -> {code} (550 expected)")
    except (smtplib.SMTPException, OSError) as exc:
        leg("strict domain reject", False, repr(exc))


def main():
    print("demo-smoke against 127.0.0.1 (JMAP 18080 / 2525 / 2587 / 2593)")
    anon_jmap_session()
    round_trip()
    catch_all_and_reject()
    if failures:
        print(f"SMOKE RED: {len(failures)} leg(s) failed: {', '.join(failures)}")
        return 1
    print("SMOKE GREEN: all legs passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
