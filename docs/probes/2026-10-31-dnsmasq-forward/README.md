# dnsmasq forward-vs-blackhole: the driver-vs-demo scope split (A4, 2026-10-31)

The X12.2 question (kept-live 10-19/10-20 reports): is relay-e2e's
`server = ["10.0.2.3"]` dnsmasq forward a working bridge to host DNS or a
blackhole whose green rides local answers only?

**VERDICT: blackhole in the test-driver network, live in single-VM
contexts. The stale "forwarding upstream / REQUIRED" comments were the
only victims - fixed in both tests this day. No upstream filing: the
framework behavior is by design (multi-node tests get vlan-hub netdevs,
no user-net), and no measured victim exists beyond our own comments.**

## Driver VM (stalwart-relay-e2e `smtp` node, three vm-debug runs)

| Leg                                            | Result                                                                                                                                                                                                                                            |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NET SHAPE                                      | eth0 = link-local v6 ONLY, eth1 = 192.168.1.2/24 (the test hub); **no 10.0.2.x interface, no default route** - the mechanism of everything below                                                                                                  |
| `dig @127.0.0.1 relay A` (local zone, control) | `192.168.1.1` - dnsmasq serves its zone                                                                                                                                                                                                           |
| `dig @127.0.0.1 example.com A` (+time=5)       | empty at v1; v3: dnsmasq answers **REFUSED** instantly (0.08-0.12 s)                                                                                                                                                                              |
| `dig @10.0.2.3 example.com A` (+time=20)       | **exit 9 ("no servers could be reached") in 58 ms** - instant unreachability, not a timeout                                                                                                                                                       |
| `dig @127.0.0.1 spam.pyzor.org A`              | **REFUSED** (dnsmasq has no working upstream)                                                                                                                                                                                                     |
| `getent hosts example.com` (system path)       | **fails, exit 2** (the driver runs succeed-compounds with errexit: the dig exit-9 and getent exit-2 aborts are the datum; the trailing `echo RC:` never ran)                                                                                      |
| Why relay-e2e is still GREEN                   | SpamPyzor is explicitly disabled (`tests/stalwart-relay-e2e.nix`: `SpamPyzor.enable = false`) - the one reload-validation lookup that made a dead upstream fatal on 2026-10-16 never happens; every resolved name comes from dnsmasq's LOCAL zone |
| `journalctl -u stalwart` resolve/pyzor matches | (leg aborted by the getent abort under errexit; boot is silent per the 0.16 journal-silence doctrine)                                                                                                                                             |

## Demo VM (single VM, `nix run .#vm`, FIFO console)

| Leg                        | Result                                                                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/resolv.conf`         | `nameserver 10.0.2.3` (slirp; no dnsmasq)                                                                                                               |
| `getent hosts example.com` | **EXIT 0** - resolved. Single-VM QEMU HAS the user-net NIC (visible in the process cmdline: `-netdev user,id=user.0,hostfwd=...`), so slirp DNS is live |
| Stalwart's own DNS         | the `DnsResolver = "Cloudflare"` provision singleton (tests/common.nix posture, eval-verified on the demo toplevel)                                     |

## Consequences

1. Both test headers now say the truth (relay-e2e + deliverability-e2e
   comments fixed 2026-10-31): the `server = ["10.0.2.3"]` entries are
   labelled dead ends, green rides the local zone, and the scope split
   is recorded. deliverability-e2e's inline comment already carried the
   correct "black hole / dig exit-9" lesson from 2026-10-30 - this pass
   reconciled its header with it.
2. Anyone adding an external-resolution dependency to a multi-node VM
   test must NOT assume 10.0.2.3 - it does not exist there. Use a
   dnsmasq local zone (or a stub record).
3. `tests/common.nix`'s Cloudflare DnsResolver patch posture is
   reaffirmed: DNS-less VMs point stalwart at Cloudflare precisely
   because the slirp resolver cannot be relied on - and resolver-running
   nodes (relay-e2e, deliverability-e2e) stay exempt, running dnsmasq.

Raw logs: `driver-v1` summary is in this README's table (the /tmp log was
swept mid-session); `demo-console-transcript.log` holds the demo FIFO
console capture verbatim.
