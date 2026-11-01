# A4 probe v3 (2026-10-31): error-safe capture of the remaining legs.
# v2 datum: `dig @10.0.2.3` exits 9 ("no servers could be reached") in
# 58 ms - INSTANT unreachability, not a timeout. v3 captures: pyzor name
# through dnsmasq, external through dnsmasq, system path (with timeout),
# resolv.conf + routes (the networking shape), and the boot journal.

smtp.start()

smtp.wait_for_unit("stalwart.service")
smtp.wait_for_open_port(587)
print("=== v3: error-safe capture ===")

net = smtp.succeed(
    "cat /etc/resolv.conf > /tmp/d0.txt 2>&1;"
    " ip -brief addr >> /tmp/d0.txt 2>&1;"
    " ip route >> /tmp/d0.txt 2>&1; cat /tmp/d0.txt"
)
print("NET SHAPE:", net[:500])

pyz = smtp.succeed(
    "dig @127.0.0.1 spam.pyzor.org A +time=10 +tries=1"
    " > /tmp/d2.txt 2>&1; echo RC:$? >> /tmp/d2.txt; cat /tmp/d2.txt"
)
print("LEG2b spam.pyzor.org via dnsmasq:", pyz[:300])

ext = smtp.succeed(
    "dig @127.0.0.1 example.com A +time=10 +tries=1"
    " > /tmp/d5.txt 2>&1; echo RC:$? >> /tmp/d5.txt; cat /tmp/d5.txt"
)
print("LEG2 example.com via dnsmasq:", ext[:300])

ge = smtp.succeed(
    "timeout 15 getent hosts example.com > /tmp/d3.txt 2>&1;"
    " echo RC:$? >> /tmp/d3.txt; cat /tmp/d3.txt"
)
print("LEG4 getent (timeout-guarded):", ge[:300])

j = smtp.succeed(
    "journalctl -u stalwart -b 0 -o cat | grep -iE 'resolve|lookup|pyzor"
    " |invalid address|dns' | head -5 > /tmp/d4.txt 2>&1;"
    " echo MATCHES:$(wc -l < /tmp/d4.txt) >> /tmp/d4.txt; cat /tmp/d4.txt"
)
print("JOURNAL matches:", j[:400])
print("=== v3 done ===")
