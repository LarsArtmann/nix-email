# perSystem.checks, extracted from flake.nix 2026-10-05 (flake-parts
# module split). The raw nixpkgs INPUT is passed to the pure-eval tests
# so their legacyPackages semantics are unchanged.
{inputs, ...}: {
  # `pkgs` is provided by flake-parts' built-in nixpkgs module
  # (inputs'.nixpkgs.legacyPackages - the semantics the tests were
  # verified against). NOTE: inside perSystem use `pkgs.lib`, not a
  # bare `lib` - that is the shape proven in
  # nix-international-telephony; redefining _module.args.pkgs here is
  # NOT (it leaves pkgs unbound in this flake-parts rev).
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # NixOS VM tests only run reliably on x86_64-linux. MEASURED
    # 2026-09-15 (one emulated stalwart-e2e attempt on an x86 host with
    # qemu-aarch64 binfmt): the aarch64 guest BUILDS and BOOTS fine
    # (arm64 kernel + systemd reach userspace), but TCG emulation is so
    # slow that boot alone (~6 min) exceeds the test driver's
    # shell-connect timeout, and a full E2E (cert generation + the
    # ~131 s of DNS-less resolver stalls) would run well over an hour.
    # Decision: documented-manual - NOT worth CI time; anyone porting to
    # aarch64 re-runs it on real ARM hardware. The pure-eval contract
    # test below is arch-independent and runs everywhere.
    checks =
      {
        dmarc-eval = import ../tests/dmarc-eval.nix {
          inherit system;
          nixpkgs = inputs.nixpkgs;
        };
        # Export-surface contract (2026-09-22): both arches eval the full
        # wrapper toplevel - mail-server + dmarc-monitor merged in ONE
        # nixosSystem (pure check, no VM).
        module-import-eval = import ../tests/module-import-eval.nix {
          inherit system;
          nixpkgs = inputs.nixpkgs;
        };
      }
      // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        stalwart-e2e = import ../tests/stalwart-e2e.nix {inherit pkgs;};
        stalwart-relay-e2e = import ../tests/stalwart-relay-e2e.nix {inherit pkgs;};
        parsedmarc-e2e = import ../tests/parsedmarc-e2e.nix {inherit pkgs;};
      };
  };
}
