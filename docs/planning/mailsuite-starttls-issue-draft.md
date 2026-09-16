# Draft — NOT filed (user-gated: "mailsuite file-or-skip")

Repo: seanthegeek/mailsuite
Title: `ssl=False` cannot opt out of automatic STARTTLS

---

## Problem

`IMAPClient(host, ssl=False)` still upgrades to TLS whenever the server advertises `STARTTLS` — the upgrade is unconditional:

```python
# mailsuite/imap.py:284-286 (2.3.1; current master is byte-identical)
if not ssl and b"STARTTLS" in self.capabilities():
    logger.info("IMAP server supports STARTTLS ... activating now")
    self.starttls(ssl_context=ssl_context)
```

Auto-upgrading is the right default and I am not asking to change it. The gap is that there is no way to decline it: a consumer explicitly passing `ssl=False` for a plaintext-trusted hop (localhost between a mail server and a report processor, or an internal relay with legacy TLS params that advertises STARTTLS anyway) cannot get a plaintext connection, and a failed `starttls()` is fatal to the whole connection.

Parsedmarc users hit exactly this: domainaware/parsedmarc#534 — an internal mailserver advertising STARTTLS with a weak DH key; the reporter quoted these same three lines and closed with "no apparent way of disabling it".

## Proposal

**Add a `starttls` parameter that defaults to auto (today's behavior) and honors an explicit opt-out:**

```python
def __init__(self, ..., ssl: bool = True, starttls: bool | None = None, ...):
    ...
    if not ssl and starttls is not False and b"STARTTLS" in self.capabilities():
```

- `starttls=None` (default): unchanged auto-upgrade
- `starttls=False`: `ssl=False` means plaintext, even when advertised

A dedicated parameter avoids breaking anyone who relies on the current auto-upgrade; strictly reinterpreting `ssl=False` would also work but changes semantics.

I can send a PR for this if the approach sounds good.

Verified on mailsuite 2.3.1 (installed via parsedmarc) and current master (diffed `imap.py`, byte-identical).

💘 Generated with Crush
