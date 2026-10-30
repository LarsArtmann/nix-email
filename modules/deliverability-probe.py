#!/usr/bin/env python3
"""Deliverability probe for the nix-email stack.

Runs a battery of deliverability checks against one mail host and emits:

- human-readable lines (journald when run from the systemd unit),
- a JSON report (latest + rolling history),
- a Prometheus textfile (latest run),
- exit code 0 iff no CRITICAL check failed (systemd OnFailure /
  consumer alert routing keys off this; WARNING never fails the unit).

Dependencies (deliberately stdlib-only Python + two binaries on PATH):
- `dig` (nixpkgs dnsutils) for DNS: MX / SPF / DMARC / DKIM / PTR / DNSBL,
- `openssl` for certificate expiry (python-ssl cannot surface notAfter
  from an unverified peer cert; getpeercert() returns {} with
  CERT_NONE, and the self-signed bootstrap tier must still be probed).

Two run modes, one code path:
- HOST mode: the wrapper's mail-deliverability-probe.service runs this
  on the mail host itself (loopback-adjacent, full local path).
- VANTAGE mode: the flake package `deliverability-probe` runs the same
  script from any other machine (evo-x2, a VPS cron) against the public
  hostname - the outside view MONITORING.md row 10 asks for.

Design contract (MONITORING.md "Routing table"):
- Alerts never ride the mail stack they watch: this probe only EMITS
  (exit code, journal, JSON, textfile); channels (Discord/ntfy push,
  SigNoz rules, Gatus) are wired by the consumer layer.
- The monitors are monitored: `mail_deliverability_probe_timestamp_seconds`
  must be scraped and dead-man'd (absent/staleness rule) by the consumer.
"""

import argparse
import datetime
import imaplib
import json
import os
import re
import smtplib
import socket
import ssl
import subprocess
import sys
import time
import uuid
from email.message import EmailMessage
from email.utils import formatdate

PROBE_NAME = "deliverability-probe"
PROBE_VERSION = 1

PASS = "pass"
WARN = "warn"
FAIL = "fail"
SKIP = "skip"

# Spamhaus-documented error answers (public-resolver refusal, quota,
# invalid IP) - a WARNING (probe config problem), never a "listed".
DNSBL_ERROR_ANSWERS = {"127.255.255.252", "127.255.255.253", "127.255.255.254"}

HOSTNAME_RE = re.compile(r"^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$")
IP_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")


class Check:
    """One named check verdict. `name` is a stable id: it becomes the
    Prometheus label and the JSON key - never rename one casually."""

    def __init__(self, name, severity, status, detail, duration_ms=0):
        self.name = name
        self.severity = severity
        self.status = status
        self.detail = detail
        self.duration_ms = duration_ms

    def to_dict(self):
        return {
            "name": self.name,
            "severity": self.severity,
            "status": self.status,
            "detail": self.detail,
            "duration_ms": self.duration_ms,
        }


def run_checks(config):
    """Sequential check battery. A check may raise anything; the failure
    is captured as that check's FAIL verdict instead of killing the run
    (one broken check must never blind the whole probe)."""
    checks = []

    def record(name, severity, fn):
        started = time.monotonic()
        try:
            check = fn()
        except Exception as exc:  # noqa: BLE001 - see docstring
            check = Check(name, severity, FAIL, f"probe error: {type(exc).__name__}: {exc}")
        check.name = name
        check.severity = severity
        check.duration_ms = int((time.monotonic() - started) * 1000)
        checks.append(check)

    if config.check_dns:
        for domain in config.domains:
            record(f"dns-mx:{domain}", "critical", lambda d=domain: check_dns_mx(config, d))
            record(f"dns-spf:{domain}", "critical", lambda d=domain: check_dns_spf(config, d))
            record(f"dns-dmarc:{domain}", "critical", lambda d=domain: check_dns_dmarc(config, d))
            for selector in config.selectors:
                record(
                    f"dns-dkim:{selector}.{domain}",
                    "critical",
                    lambda d=domain, s=selector: check_dns_dkim(config, d, s),
                )

    for ip in config.ips:
        record(f"dns-ptr:{ip}", "warning", lambda i=ip: check_dns_ptr(config, i))
        for zone in config.dnsbl_zones:
            record(
                f"dnsbl:{zone}:{ip}",
                "critical",
                lambda i=ip, z=zone: check_dnsbl(config, i, z),
            )

    if 25 in config.ports:
        record("smtp-starttls-25", "critical", lambda: check_smtp_starttls(config, 25, "smtp"))
    if 587 in config.ports:
        record(
            "submission-587",
            "critical",
            lambda: check_submission(config, 587),
        )
    if 465 in config.ports:
        record("submissions-465", "critical", lambda: check_imaps_like(config, 465, "smtp"))
    if 993 in config.ports:
        record("imaps-993", "critical", lambda: check_imaps_like(config, 993, "imap"))
        record("tls-cert-expiry", "warning", lambda: check_cert_expiry(config, config.host, 993))
        record(
            "tls-verification",
            "critical" if config.tls_verify == "required" else "warning",
            lambda: check_tls_verification(config, config.host, 993),
        )
    if 465 in config.ports:
        record("tls-cert-expiry-465", "warning", lambda: check_cert_expiry(config, config.host, 465))

    canary = None
    if config.canary_address:
        canary = check_canary(config)
        checks.append(canary["check"])

    return checks, canary


# --- DNS checks (dig) ------------------------------------------------------


def dig(config, args):
    cmd = ["dig", "+time=%d" % config.timeout, "+tries=1", "+short"]
    if config.resolver:
        cmd.append("@" + config.resolver)
    cmd += args
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=config.timeout + 10)
    if proc.returncode != 0:
        raise RuntimeError(f"dig exited {proc.returncode}: {proc.stderr.strip()[:200]}")
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def dig_txt(config, name):
    """TXT records, with multi-string answers re-joined (dig +short
    emits each record's quoted strings on one line: `"v=DMARC1; '
    'p=none"' -> v=DMARC1; p=none)."""
    answers = []
    for line in dig(config, ["TXT", name]):
        parts = re.findall(r'"([^"]*)"', line)
        answers.append("".join(parts) if parts else line)
    return answers


def check_dns_mx(config, domain):
    answers = dig(config, ["MX", domain])
    if not answers:
        return Check("", "", FAIL, f"no MX record for {domain}")
    targets = []
    for answer in answers:
        fields = answer.split()
        target = fields[-1].rstrip(".").lower() if fields else ""
        if target:
            targets.append(target)
    ours = [t for t in targets if t == config.host or t.endswith("." + config.host)]
    if not ours:
        return Check(
            "",
            "",
            WARN,
            f"MX for {domain} exists but points elsewhere ({', '.join(targets)}) - "
            f"not at {config.host}; fine for shared MX, fatal for a solo host",
        )
    return Check("", "", PASS, f"MX {domain} -> {', '.join(sorted(set(ours)))}")


def check_dns_spf(config, domain):
    records = [txt for txt in dig_txt(config, domain) if txt.lower().startswith("v=spf1")]
    if not records:
        return Check("", "", FAIL, f"no SPF (v=spf1) TXT record for {domain}")
    if len(records) > 1:
        return Check("", "", WARN, f"multiple SPF records for {domain} (RFC 7208 permits exactly one)")
    return Check("", "", PASS, f"SPF for {domain}: {records[0][:120]}")


def check_dns_dmarc(config, domain):
    records = [
        txt for txt in dig_txt(config, f"_dmarc.{domain}") if txt.lower().startswith("v=dmarc1")
    ]
    if not records:
        return Check("", "", FAIL, f"no DMARC (v=DMARC1) TXT record at _dmarc.{domain}")
    return Check("", "", PASS, f"DMARC for {domain}: {records[0][:120]}")


def check_dns_dkim(config, domain, selector):
    records = dig_txt(config, f"{selector}._domainkey.{domain}")
    if not records:
        return Check(
            "",
            "",
            FAIL,
            f"no DKIM public key at {selector}._domainkey.{domain} - signed mail from "
            f"this selector is unverifiable and will fail DMARC at receivers",
        )
    return Check("", "", PASS, f"DKIM {selector}.{domain} present ({records[0][:80]}...)")


def check_dns_ptr(config, ip):
    answers = dig(config, ["-x", ip])
    if not answers:
        return Check("", "", WARN, f"no PTR record for {ip} - some receivers reject rDNS-less senders")
    names = [a.rstrip(".").lower() for a in answers]
    if config.host.lower() not in names:
        return Check(
            "",
            "",
            WARN,
            f"PTR for {ip} is {', '.join(names)}, not {config.host} - the FQDN/PTR "
            f"mismatch class (README go-live runbook step 1)",
        )
    return Check("", "", PASS, f"PTR {ip} -> {', '.join(names)}")


def check_dnsbl(config, ip, zone):
    octets = ip.split(".")
    query = ".".join(reversed(octets)) + "." + zone
    answers = dig(config, ["A", query])
    listed = [a for a in answers if a.startswith("127.") and a not in DNSBL_ERROR_ANSWERS]
    errors = [a for a in answers if a in DNSBL_ERROR_ANSWERS]
    if listed:
        return Check(
            "",
            "",
            FAIL,
            f"{ip} is LISTED at {zone} (answer {', '.join(listed)}) - outbound "
            f"deliverability from this address is broken until delisted",
        )
    if errors:
        return Check(
            "",
            "",
            WARN,
            f"{zone} refused the query for {ip} (answer {errors[0]} - the Spamhaus "
            f"public-resolver block or quota; probe from a host with its own recursion)",
        )
    return Check("", "", PASS, f"{ip} not listed at {zone}")


# --- transport checks (stdlib smtplib/imaplib) -----------------------------


def smtp_starttls_context(config):
    if config.tls_verify == "required":
        return ssl.create_default_context()
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context


def check_smtp_starttls(config, port, expect_banner):
    with smtplib.SMTP(config.host, port, timeout=config.timeout) as client:
        code, banner = client.ehlo(PROBE_NAME)
        if code != 250:
            return Check("", "", FAIL, f"{expect_banner} on :{port} answered EHLO {code} {banner.decode(errors='replace')[:120]}")
        features = client.esmtp_features
        if "starttls" not in features:
            return Check(
                "",
                "",
                FAIL,
                f":{port} does not advertise STARTTLS (features: "
                f"{sorted(features) or 'none - plain SMTP only'})",
            )
        client.starttls(context=smtp_starttls_context(config))
        client.ehlo(PROBE_NAME)
    return Check("", "", PASS, f":{port} banner + EHLO + STARTTLS handshake OK")


def check_submission(config, port):
    with smtplib.SMTP(config.host, port, timeout=config.timeout) as client:
        client.ehlo("deliverability-probe")
        if "starttls" not in client.esmtp_features:
            return Check("", "", FAIL, f"submission :{port} does not advertise STARTTLS")
        client.starttls(context=smtp_starttls_context(config))
        client.ehlo("deliverability-probe")
        if not (config.canary_address and config.canary_password):
            return Check("", "", PASS, f"submission :{port} STARTTLS OK (no credentials: SASL untested)")
        try:
            client.login(config.canary_address, config.canary_password)
        except smtplib.SMTPAuthenticationError as exc:
            return Check(
                "",
                "",
                FAIL,
                f"submission :{port} rejected the canary credentials "
                f"({exc.smtp_code} {exc.smtp_error.decode(errors='replace')[:120]})",
            )
    return Check("", "", PASS, f"submission :{port} STARTTLS + SASL login OK")


def check_imaps_like(config, port, protocol):
    if protocol == "imap":
        with imaplib.IMAP4_SSL(config.host, port, timeout=config.timeout) as client:
            greeting = client.welcome.decode(errors="replace") if client.welcome else ""
            if "OK" not in greeting.upper():
                return Check("", "", FAIL, f"IMAPS :{port} greeting not OK: {greeting[:120]}")
            if not (config.canary_address and config.canary_password):
                return Check("", "", PASS, f"IMAPS :{port} TLS + greeting OK (no credentials: LOGIN untested)")
            try:
                client.login(config.canary_address, config.canary_password)
            except imaplib.IMAP4.error as exc:
                return Check("", "", FAIL, f"IMAPS :{port} LOGIN rejected the canary credentials: {exc}")
            client.logout()
        return Check("", "", PASS, f"IMAPS :{port} TLS + LOGIN OK")
    with smtplib.SMTP_SSL(config.host, port, timeout=config.timeout, context=smtp_starttls_context(config)) as client:
        code, message = client.noop()
        if code != 250:
            return Check("", "", FAIL, f"submissions :{port} implicit-TLS NOOP answered {code}")
    return Check("", "", PASS, f"submissions :{port} implicit TLS + banner OK")


# --- certificate checks (openssl) -------------------------------------------


def cert_not_after(config, host, port):
    """PEM notAfter via openssl s_client | openssl x509. Binary pipeline
    (no shell): the host string is validated to be a hostname at arg
    parse time, but avoiding shell=True keeps that a defense in depth."""
    sclient = subprocess.run(
        ["openssl", "s_client", "-connect", f"{host}:{port}", "-servername", host],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        timeout=config.timeout + 10,
        env={**os.environ, "LANG": "C"},
    )
    x509 = subprocess.run(
        ["openssl", "x509", "-noout", "-enddate"],
        input=sclient.stdout,
        capture_output=True,
        timeout=config.timeout + 10,
        env={**os.environ, "LANG": "C"},
    )
    match = re.search(r"notAfter=(.+)", x509.stdout.decode(errors="replace"))
    if not match:
        raise RuntimeError(
            f"no certificate served on :{port} (s_client rc={sclient.returncode}, "
            f"x509 stderr={x509.stderr.strip()[:120]})"
        )
    return datetime.datetime.strptime(match.group(1).strip(), "%b %d %H:%M:%S %Y %Z").replace(
        tzinfo=datetime.timezone.utc
    )


def check_cert_expiry(config, host, port):
    not_after = cert_not_after(config, host, port)
    remaining = not_after - datetime.datetime.now(datetime.timezone.utc)
    days = remaining.days
    if remaining.total_seconds() <= 0:
        return Check("", "", FAIL, f"certificate on :{port} EXPIRED {abs(days)} day(s) ago ({not_after})")
    if days < config.cert_warn_days:
        return Check(
            "",
            "",
            WARN,
            f"certificate on :{port} expires in {days} day(s) ({not_after}) - "
            f"renew before receivers start refusing STARTTLS",
        )
    return Check("", "", PASS, f"certificate on :{port} valid for {days} more day(s)")


def check_tls_verification(config, host, port):
    context = ssl.create_default_context()
    try:
        with socket.create_connection((host, port), timeout=config.timeout) as sock:
            with context.wrap_socket(sock, server_hostname=host):
                pass
    except ssl.SSLCertVerificationError as exc:
        verdict = FAIL if config.tls_verify == "required" else WARN
        return Check(
            "",
            "",
            verdict,
            f"certificate on :{port} does not verify against system trust: "
            f"{exc.verify_message or exc} (expected for the self-signed bootstrap tier; "
            f'set certificate.mode = acme/manual and tlsVerification = "required" in prod)',
        )
    except (OSError, ssl.SSLError) as exc:
        verdict = FAIL if config.tls_verify == "required" else WARN
        return Check("", "", verdict, f"TLS handshake on :{port} failed: {exc}")
    return Check("", "", PASS, f"certificate on :{port} verifies against system trust")


# --- round-trip canary -------------------------------------------------------


def check_canary(config):
    """The message-level SLO probe (MONITORING.md row 10): submit a
    uniquely-tokened mail through :587 as the canary account and assert
    its arrival in the same mailbox over IMAPS. Failure phases are
    distinguished on purpose - a SEND failure means the submission path
    (auth/TLS/queue-accept) is broken; a DELIVER timeout means the
    queue/local-delivery path is broken; different on-call reactions."""
    token = f"deliverability-{uuid.uuid4().hex}"
    started = time.monotonic()
    result = {"enabled": True, "token": token, "phase": "send"}

    message = EmailMessage()
    message["From"] = config.canary_address
    message["To"] = config.canary_address
    message["Subject"] = f"deliverability canary {token}"
    message["Date"] = formatdate(localtime=False)
    message["X-Deliverability-Token"] = token
    message.set_content(f"Automated deliverability probe round-trip token {token}.\n")

    try:
        with smtplib.SMTP(config.host, 587, timeout=config.timeout) as client:
            client.ehlo(PROBE_NAME)
            client.starttls(context=smtp_starttls_context(config))
            client.ehlo(PROBE_NAME)
            client.login(config.canary_address, config.canary_password)
            client.send_message(message)
    except smtplib.SMTPAuthenticationError as exc:
        return _canary_fail(result, started, "send", f"SASL rejected canary credentials: {exc}")
    except (smtplib.SMTPException, OSError) as exc:
        return _canary_fail(result, started, "send", f"submission failed: {type(exc).__name__}: {exc}")
    result["phase"] = "deliver"

    deadline = time.monotonic() + config.slo_seconds
    found = False
    last_error = ""
    while time.monotonic() < deadline:
        try:
            with imaplib.IMAP4_SSL(config.host, 993, timeout=config.timeout) as client:
                client.login(config.canary_address, config.canary_password)
                # SEARCH/STORE/EXPUNGE are only legal in a SELECTED state -
                # select INBOX explicitly (caught live in the VM: "command
                # SEARCH illegal in state AUTH").
                status, _ = client.select("INBOX")
                if status != "OK":
                    last_error = f"SELECT INBOX: {status}"
                else:
                    status, data = client.search(None, f'HEADER "X-Deliverability-Token" "{token}"')
                    if status == "OK" and data[0].split():
                        found = True
                        for seq in data[0].split():
                            client.store(seq, "+FLAGS.SILENT", "\\Deleted")
                        client.expunge()
            if found:
                break
        except (imaplib.IMAP4.error, OSError) as exc:
            last_error = f"{type(exc).__name__}: {exc}"
        time.sleep(config.poll_interval)
    elapsed = time.monotonic() - started
    result["elapsed_s"] = round(elapsed, 1)
    if not found:
        detail = (
            f"canary token {token} did not arrive within the {config.slo_seconds}s SLO"
            + (f" (last IMAP error: {last_error})" if last_error else "")
            + " - submission accepted but delivery is broken (queue/backlog class)"
        )
        return {"check": _canary_check(result, FAIL, detail), **result}
    result["phase"] = "cleanup"
    detail = f"round-trip {config.canary_address} -> :587 -> mailbox -> IMAPS in {elapsed:.1f}s (SLO {config.slo_seconds}s)"
    return {"check": _canary_check(result, PASS, detail), **result}


def _canary_fail(result, started, phase, detail):
    result["phase"] = phase
    result["elapsed_s"] = round(time.monotonic() - started, 1)
    return {
        "check": Check(
            "canary-roundtrip",
            "critical",
            FAIL,
            f"{detail} (phase: {phase})",
            int((time.monotonic() - started) * 1000),
        ),
        **result,
    }


def _canary_check(result, status, detail):
    return Check(
        "canary-roundtrip",
        "critical",
        status,
        detail,
        int(result.get("elapsed_s", 0) * 1000),
    )


# --- output emitters ---------------------------------------------------------


def overall_status(checks):
    if any(c.status == FAIL for c in checks):
        return "fail"
    return "pass"


def write_json(config, checks, canary, started):
    report = {
        "probe": PROBE_NAME,
        "version": PROBE_VERSION,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": config.host,
        "domains": config.domains,
        "overall": overall_status(checks),
        "duration_s": round(time.monotonic() - started, 1),
        "checks": [c.to_dict() for c in checks],
        "canary": without_check(canary) if canary else {"enabled": False},
    }
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if config.json_out:
        write_atomic(config.json_out, text)
    if config.history_dir:
        os.makedirs(config.history_dir, exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        write_atomic(os.path.join(config.history_dir, f"{stamp}.json"), text)
        prune_history(config.history_dir, config.history_keep)
    return report


def without_check(canary):
    return {k: v for k, v in canary.items() if k != "check"}


def prune_history(directory, keep):
    entries = sorted(
        f for f in os.listdir(directory) if f.endswith(".json")
    )
    for stale in entries[:-keep] if keep > 0 else []:
        try:
            os.unlink(os.path.join(directory, stale))
        except OSError:
            pass


def write_prometheus(config, checks, report):
    if not config.prom_out:
        return
    lines = [
        "# HELP mail_deliverability_probe_success 1 if the last probe run had no critical failure.",
        "# TYPE mail_deliverability_probe_success gauge",
        f"mail_deliverability_probe_success {1 if report['overall'] == 'pass' else 0}",
        "# HELP mail_deliverability_probe_timestamp_seconds Unix time of the last probe run (dead-man: alert on staleness).",
        "# TYPE mail_deliverability_probe_timestamp_seconds gauge",
        f"mail_deliverability_probe_timestamp_seconds {time.time():.0f}",
        "# HELP mail_deliverability_probe_duration_seconds Wall time of the last probe run.",
        "# TYPE mail_deliverability_probe_duration_seconds gauge",
        f"mail_deliverability_probe_duration_seconds {report['duration_s']}",
        "# HELP mail_deliverability_check_success 1 if the named check passed (warn counts as success; see the warn gauge).",
        "# TYPE mail_deliverability_check_success gauge",
    ]
    for check in checks:
        ok = 1 if check.status in (PASS, WARN) else 0
        lines.append(f'mail_deliverability_check_success{{check="{check.name}"}} {ok}')
    lines += [
        "# HELP mail_deliverability_check_warn 1 if the named check warned (degraded, not failed).",
        "# TYPE mail_deliverability_check_warn gauge",
    ]
    for check in checks:
        warned = 1 if check.status == WARN else 0
        lines.append(f'mail_deliverability_check_warn{{check="{check.name}"}} {warned}')
    lines += [
        "# HELP mail_deliverability_dnsbl_listed 1 if the address is listed at the DNSBL zone (0 = clean; always emitted per probed zone/ip).",
        "# TYPE mail_deliverability_dnsbl_listed gauge",
    ]
    for check in checks:
        if check.name.startswith("dnsbl:"):
            _, zone, ip = check.name.split(":", 2)
            listed = 1 if check.status == FAIL else 0
            lines.append(f'mail_deliverability_dnsbl_listed{{zone="{zone}",ip="{ip}"}} {listed}')
    write_atomic(config.prom_out, "\n".join(lines) + "\n")


def write_atomic(path, text):
    temporary = f"{path}.tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(temporary, path)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog=PROBE_NAME,
        description="Deliverability probe for the nix-email stack (see docs/MONITORING.md).",
    )
    parser.add_argument("--host", required=True, help="mail host FQDN probed over the network")
    parser.add_argument(
        "--domains",
        default="",
        help="comma-separated mail DOMAINS checked for MX/SPF/DMARC (default: the host itself)",
    )
    parser.add_argument("--no-dns", action="store_true", help="skip the DNS record checks")
    parser.add_argument("--resolver", default=None, help="DNS server for dig (default: system resolver)")
    parser.add_argument("--selectors", default="", help="comma-separated DKIM selectors to verify")
    parser.add_argument("--dnsbl-zones", default="", help="comma-separated DNSBL zones (default: none)")
    parser.add_argument(
        "--ips",
        default="",
        help="comma-separated outbound IPs for PTR/DNSBL (default: resolved from --host)",
    )
    parser.add_argument("--ports", default="25,465,587,993", help="comma-separated ports to probe")
    parser.add_argument("--canary-address", default=None, help="canary mailbox address (round-trip SLO probe)")
    parser.add_argument("--canary-password-file", default=None, help="file with the canary password (one line)")
    parser.add_argument("--slo-seconds", type=int, default=600, help="delivery SLO for the round-trip canary")
    parser.add_argument("--poll-interval", type=float, default=10.0, help="IMAP poll interval during the canary")
    parser.add_argument(
        "--tls-verify",
        choices=["required", "opportunistic"],
        default="opportunistic",
        help="required: untrusted certs FAIL (acme/manual tiers); opportunistic: they WARN (self-signed bootstrap)",
    )
    parser.add_argument("--cert-warn-days", type=int, default=14, help="warn when the certificate expires within N days")
    parser.add_argument("--timeout", type=int, default=15, help="per-connection/lookup timeout in seconds")
    parser.add_argument("--json-out", default=None, help="write the JSON report here (latest run)")
    parser.add_argument("--history-dir", default=None, help="keep timestamped report copies here")
    parser.add_argument("--history-keep", type=int, default=48, help="history files to retain")
    parser.add_argument("--prom-out", default=None, help="write the Prometheus textfile here")
    config = parser.parse_args(argv)

    if not HOSTNAME_RE.match(config.host):
        parser.error(f"--host must be a hostname (got {config.host!r})")
    config.domains = [d for d in (config.domains or config.host).split(",") if d] or [config.host]
    config.selectors = [s for s in config.selectors.split(",") if s]
    config.dnsbl_zones = [z for z in config.dnsbl_zones.split(",") if z]
    config.ips = [i for i in config.ips.split(",") if i]
    for ip in config.ips:
        if not IP_RE.match(ip):
            parser.error(f"--ips entry {ip!r} is not an IPv4 address (v6 unsupported)")
    config.ports = sorted({int(p) for p in config.ports.split(",") if p})
    config.check_dns = not config.no_dns
    if not config.ips and config.check_dns:
        config.ips = [a for a in dig(config, ["A", config.host]) if IP_RE.match(a)]
    config.canary_password = None
    if config.canary_address:
        if not config.canary_password_file:
            parser.error("--canary-address needs --canary-password-file")
        with open(config.canary_password_file, encoding="utf-8") as handle:
            config.canary_password = handle.read().strip()

    started = time.monotonic()
    checks, canary = run_checks(config)
    report = write_json(config, checks, canary, started)
    write_prometheus(config, checks, report)

    for check in checks:
        symbol = {"pass": "PASS", "warn": "WARN", "fail": "FAIL", "skip": "SKIP"}[check.status]
        print(f"{symbol} {check.name} ({check.duration_ms}ms): {check.detail}", flush=True)
    print(
        f"overall {report['overall'].upper()} in {report['duration_s']}s "
        f"({len(checks)} checks, host {config.host})",
        flush=True,
    )
    return 0 if report["overall"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
