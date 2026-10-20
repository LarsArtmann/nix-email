#!/usr/bin/env python3
"""T14 orchestrator — owns the WHOLE E2E lifecycle in ONE process.

The 2026-10-19 inline-bash attempt hung because no process owned the CRM
server lifecycle. This script does: build the real binary, boot crm-server
on a throwaway sqlite DB, seed via the HTTP-form driver, STOP the server
(the one-shot owns the DB), then run the -carddav-sync one-shot three
times (initial mirror / idempotent rerun / CRM-wins conflict) with the
driver's assert|conflict|verify-restore phases between, and parse the
one-shot's report Summary line for each verdict.

Every verdict prints VERDICT for the transcript; exit code 1 on any FAIL.
Run from this directory:  python3 carddav_e2e_run.py 2>&1 | tee -a carddav-e2e.log
"""

import base64
import http.client
import os
import re
import signal
import socket
import subprocess
import sys
import time

CRM_REPO = "/home/lars/projects/crm"
BIN = "/tmp/crm-e2e-server"
DB = "/tmp/crm-carddav-e2e.db"
STATE = "/tmp/crm-carddav-e2e-state.json"
SERVER_LOG = "/tmp/crm-carddav-e2e-server.log"

CRM_ADDR, CRM_PORT = "127.0.0.1", 18099
DAV_ADDR, DAV_PORT = "127.0.0.1", 18080
USER, PASS = "demo@mail.demo.test", "demo-nixemail-2026"
CREDS = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
BOOK = "/dav/card/demo@mail.demo.test/Kith-E2E/"

DRIVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "carddav_e2e.py")

failures: list[str] = []


def verdict(step: str, ok: bool, detail: str = "") -> None:
    line = f"VERDICT {step}: {'PASS' if ok else 'FAIL'}{(' ' + detail) if detail else ''}"
    print(line, flush=True)
    if not ok:
        failures.append(step)


def wait_port(addr: str, port: int, deadline_s: float) -> bool:
    end = time.monotonic() + deadline_s
    while time.monotonic() < end:
        with socket.socket() as s:
            s.settimeout(0.5)
            try:
                s.connect((addr, port))
                return True
            except OSError:
                time.sleep(0.2)
    return False


def build() -> bool:
    print(f"# build {BIN} from {CRM_REPO}", flush=True)
    env = dict(os.environ, GOTOOLCHAIN="go1.27.2", GOEXPERIMENT="jsonv2")
    done = subprocess.run(
        ["go", "build", "-o", BIN, "./cmd/crm-server"],
        cwd=CRM_REPO, env=env, capture_output=True, text=True, timeout=600,
    )
    if done.returncode != 0:
        print(done.stdout + done.stderr, flush=True)
    return done.returncode == 0


def rotate(path: str) -> None:
    if os.path.exists(path):
        os.replace(path, path + ".old")


def fresh_book() -> None:
    """DELETE the E2E book so the initial mirror starts from a clean slate
    (earlier probe/diag runs left residue; the runner never deletes cards
    it does not own)."""
    conn = http.client.HTTPConnection(DAV_ADDR, DAV_PORT, timeout=30)
    conn.request("DELETE", BOOK, headers={"Authorization": f"Basic {CREDS}"})
    resp = conn.getresponse()
    resp.read()
    conn.close()
    verdict("E2E-0 fresh book", resp.status in (200, 204, 404), f"DELETE -> {resp.status}")


def boot_server() -> subprocess.Popen | None:
    log = open(SERVER_LOG, "w")
    proc = subprocess.Popen(
        [BIN, "-addr", f"{CRM_ADDR}:{CRM_PORT}", "-db", DB],
        stdout=log, stderr=subprocess.STDOUT,
    )
    if not wait_port(CRM_ADDR, CRM_PORT, 30):
        proc.terminate()
        return None
    return proc


def stop_server(proc: subprocess.Popen) -> bool:
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=20)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=10)
        verdict("E2E server stop", False, "SIGTERM timeout, killed")
        return False
    return True


def driver(phase: str) -> bool:
    print(f"\n# driver phase: {phase}", flush=True)
    done = subprocess.run(
        [sys.executable, DRIVER, phase],
        timeout=180, capture_output=True, text=True,
    )
    print(done.stdout, end="", flush=True)
    if done.stderr:
        print(done.stderr, file=sys.stderr, end="", flush=True)
    phase_fails = re.findall(r"^VERDICT \S+: FAIL.*$", done.stdout, re.M)
    return done.returncode == 0 and not phase_fails


SUMMARY_RE = re.compile(
    r"carddav sync[^:]*: created=(\d+) updated=(\d+) unchanged=(\d+) "
    r"deleted=(\d+) conflicts=(\d+) server-side=(\d+) errors=(\d+)"
)


def sync(label: str) -> dict[str, int] | None:
    print(f"\n# one-shot sync: {label}", flush=True)
    env = dict(os.environ, CRM_CARDDAV_PASSWORD=PASS)
    args = [
        BIN, "-carddav-sync",
        "-db", DB,
        "-carddav-url", f"http://{DAV_ADDR}:{DAV_PORT}",
        "-carddav-user", USER,
        "-carddav-book", "Kith-E2E",
        "-carddav-state", STATE,
    ]
    done = subprocess.run(args, env=env, capture_output=True, text=True, timeout=300)
    out = done.stdout + done.stderr
    print(out, end="", flush=True)
    match = SUMMARY_RE.search(out)
    if done.returncode != 0 or not match:
        verdict(f"E2E-sync {label}", False, f"exit={done.returncode}")
        return None
    counts = dict(zip(
        ("created", "updated", "unchanged", "deleted", "conflicts", "server_side", "errors"),
        (int(g) for g in match.groups()),
    ))
    print(f"# report {label}: {counts}", flush=True)
    return counts


def main() -> int:
    started = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    print(f"# carddav E2E orchestrator START {started}", flush=True)

    verdict("E2E-build binary", build())

    rotate(DB)
    rotate(STATE)
    fresh_book()

    proc = boot_server()
    if proc is None:
        print(open(SERVER_LOG).read(), flush=True)
        verdict("E2E boot server", False, "port never opened")
    else:
        verdict("E2E boot server", True)
        verdict("E2E seed phase", driver("seed"))
        verdict("E2E server stop", stop_server(proc))

    if failures:
        print(f"\n# E2E FINAL: FAIL (during setup) — {failures}", flush=True)
        return 1

    first = sync("initial")
    if first:
        verdict("E2E-sync initial mirror", first["created"] == 2 and first["errors"] == 0, str(first))

    verdict("E2E assert mirror phase", driver("assert"))

    second = sync("idempotent")
    if second:
        ok = second["unchanged"] == 2 and second["created"] == 0 and second["updated"] == 0 \
            and second["deleted"] == 0 and second["conflicts"] == 0 and second["errors"] == 0
        verdict("E2E-sync idempotent rerun (zero writes)", ok, str(second))

    verdict("E2E conflict stage phase", driver("conflict"))

    third = sync("conflict")
    if third:
        ok = third["conflicts"] == 1 and third["unchanged"] == 1 and third["errors"] == 0
        verdict("E2E-sync CRM wins (conflict overwritten)", ok, str(third))

    verdict("E2E verify restore phase", driver("verify-restore"))

    print(f"\n# E2E FINAL: {'PASS' if not failures else 'FAIL — ' + ', '.join(failures)}", flush=True)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
