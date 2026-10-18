#!/usr/bin/env python3
"""JMAP move-to-Junk probe against the demo VM (0.16): the InboxClean
filing automation path. Discovers the session, finds the Junk-role
mailbox, queries the target email, moves it via Email/set, and re-checks
the mailbox message counts via Mailbox/get.
"""
import base64
import json
import urllib.request

BASE = "http://127.0.0.1:18080"
b64 = base64.b64encode(b"demo@mail.demo.test:demo-nixemail-2026").decode()
HDRS = {"Authorization": f"Basic {b64}", "Content-Type": "application/json"}


def jmap(method_calls):
    body = json.dumps(
        {
            "using": [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail",
            ],
            "methodCalls": method_calls,
        }
    ).encode()
    req = urllib.request.Request(f"{BASE}/jmap/", data=body, headers=HDRS, method="POST")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())["methodResponses"]


with urllib.request.urlopen(
    urllib.request.Request(f"{BASE}/jmap/session", headers=HDRS), timeout=15
) as r:
    session = json.loads(r.read())

accounts = session["accounts"]
core_cap = session["primaryAccounts"].get("urn:ietf:params:jmap:mail", "<none>")
account_id = next(iter(accounts))
print(f"accountId: {account_id}")
print(f"mail primary: {core_cap}")

res = jmap(
    [
        ["Mailbox/query", {"accountId": account_id, "filter": {"role": "junk"}}, "m1"],
        ["Mailbox/query", {"accountId": account_id, "filter": {"role": "inbox"}}, "m2"],
        [
            "Email/query",
            {"accountId": account_id, "filter": {"subject": "inbound-one"}},
            "e1",
        ],
    ]
)
junk_id = res[0][1]["ids"][0]
inbox_id = res[1][1]["ids"][0]
email_id = res[2][1]["ids"][0]
print(f"junk mailbox: {junk_id}  inbox mailbox: {inbox_id}  email: {email_id}")

res = jmap(
    [
        [
            "Email/set",
            {
                "accountId": account_id,
                "update": {
                    email_id: {"mailboxIds": {junk_id: True, inbox_id: False}}
                },
            },
            "s1",
        ],
        [
            "Mailbox/get",
            {"accountId": account_id, "ids": [junk_id, inbox_id], "properties": ["name", "totalEmails"]},
            "g1",
        ],
    ]
)
print(f"Email/set: {json.dumps(res[0][1])}")
if res[0][1].get("oldState"):
    print(f"  oldState={res[0][1]['oldState']} -> will read StateChange via eventsource separately")
for mb in res[1][1]["list"]:
    print(f"mailbox {mb['name']!r}: totalEmails={mb.get('totalEmails')}")
