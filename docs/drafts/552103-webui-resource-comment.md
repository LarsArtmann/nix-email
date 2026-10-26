# Draft review comment for NixOS/nixpkgs#552103 (admin-bundle spelling)

Status: DRAFT, not filed. Filing blocked on `gh auth` (token expired
2026-10-26); post verbatim once authenticated, as a review comment on
the module file or an issue comment.

Local hardening already shipped in the vendored copy (commit cc62a75,
zero behavioral delta proven by the three-shape probe below).

---

Small latent-eval finding while vendoring this module (same head rev
`9b15e1f`, nixpkgs pin `6774f7bc`, running it against 0.16.22 in NixOS
VM tests: https://github.com/LarsArtmann/nix-email).

The pre-0.16 `settings.webadmin.resource` default reads
`cfg.package.webadmin`. On the 0.15 line (`pkgs.stalwart`, 0.15.5) that
passthru exists, so the branch is fine - and on 0.16 the whole
`webadmin` block sits in the `else` of the `since0_16` split, so it is
unreachable there. But the expression is a landmine for any future
restructure: `stalwart_0_16` exposes the bundle as `passthru.webui`
(`webui-1.0.10`, containing `webui.zip`), not `webadmin`. Evaluating
the default against that package throws `attribute 'webadmin'
missing`. Repro: run the module with
`package = stalwart_0_16.overrideAttrs (_: { version = "0.15.99"; })`
plus any `services.stalwart.settings.server.listener.<id>.protocol =
"http"`.

A version-aware default defuses it for both package lines:

```nix
resource = lib.mkIf hasHttpListener (lib.mkDefault (
  if cfg.package ? webui
  then "file://${cfg.package.webui}/webui.zip"
  else "file://${cfg.package.webadmin}/webadmin.zip"
));
```

Verified by eval-probing all three shapes (2026-10-26): the 0.15 line
still evaluates to `...-webadmin-0.1.37/webadmin.zip`; the 0.16 line
stays dormant (`settings.webadmin` absent, as designed); the forced
branch now evaluates to `...-webui-1.0.10/webui.zip` instead of
throwing.
