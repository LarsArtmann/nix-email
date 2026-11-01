# A4 probe v2 (2026-10-31): after v1 found LEG2 empty at +time=5.
# Questions: (1) does 10.0.2.3 answer at all (longer window, timed)?
# (2) does the name stalwart actually needs (spam.pyzor.org) resolve?
# (3) does the SYSTEM path resolve? (4) what does stalwart's journal say?

smtp.start()

smtp.wait_for_unit("stalwart.service")
smtp.wait_for_open_port(587)
print("=== v2: probing with generous windows ===")

out = smtp.succeed(
    "time dig @10.0.2.3 example.com A +short +time=20 +tries=2"
    " > /tmp/d1.txt 2>&1; echo DIG_EXIT:$? >> /tmp/d1.txt; cat /tmp/d1.txt"
)
print("LEG3 direct 10.0.2.3 (timed):", out[:400])

pyz = smtp.succeed(
    "dig @127.0.0.1 spam.pyzor.org A +time=20 +tries=2"
    " > /tmp/d2.txt 2>&1; echo DIG_EXIT:$? >> /tmp/d2.txt; cat /tmp/d2.txt"
)
print("LEG2b spam.pyzor.org via dnsmasq:", pyz[:400])

ge = smtp.succeed(
    "getent hosts example.com > /tmp/d3.txt 2>&1;"
    " echo GETENT_EXIT:$? >> /tmp/d3.txt; cat /tmp/d3.txt"
)
print("LEG4 getent:", ge[:300])

j = smtp.succeed(
    "journalctl -u stalwart -b 0 -o cat > /tmp/d4.txt 2>&1;"
    " echo LINES:$(wc -l < /tmp/d4.txt) >> /tmp/d4.txt;"
    " grep -iE 'resolve|lookup|pyzor|dns|invalid address' /tmp/d4.txt"
    " | head -5 >> /tmp/d4.txt; tail -8 /tmp/d4.txt"
)
print("JOURNAL:", j[:600])
print("=== v2 done ===")
