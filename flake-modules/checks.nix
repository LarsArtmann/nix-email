# perSystem.checks, extracted from flake.nix 2026-10-05 (flake-parts
# module split). The raw nixpkgs INPUT is passed to the pure-eval tests
# so their legacyPackages semantics are unchanged.
{
  inputs,
  self,
  ...
}: {
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
          inherit (inputs) nixpkgs;
        };
        # Export-surface contract (2026-09-22): both arches eval the full
        # wrapper toplevel - mail-server + dmarc-monitor merged in ONE
        # nixosSystem (pure check, no VM).
        module-import-eval = import ../tests/module-import-eval.nix {
          inherit system;
          inherit (inputs) nixpkgs;
        };
        # Provision-plan structure contract (2026-10-18): hostname/Domain
        # coherence, match-property posture (reconcile sets MUST match;
        # no-match sets only on the documented implicit-key allowlist),
        # the fallback listener port set, the Exec* multi-line lint, and
        # the MtaInboundThrottle description identity - the paid-for
        # plan-dialect bug classes caught at eval speed (~10 s) instead of
        # a VM build. Pure eval, arch-independent.
        provision-plan-eval = import ../tests/provision-plan-eval.nix {
          inherit system;
          inherit (inputs) nixpkgs;
        };
      }
      // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        # Demo-host contract (2026-10-06): flake check already forces the
        # demo toplevel (probe-verified), but the HUMAN contract - quickstart
        # port forwards, provision roles:["user"], fallback admin, pyzor
        # off - can regress while still evaling clean. Pure eval, no VM;
        # x86_64-only because the demo host is.
        demo-eval = import ../tests/demo-eval.nix {
          inherit pkgs system;
          demoConfig = self.nixosConfigurations.demo.config;
        };
        stalwart-e2e = import ../tests/stalwart-e2e.nix {inherit pkgs;};
        # Dedicated non-default httpBind bootstrap (nix-email#4): the
        # virgin-store fallback class stalwart-e2e cannot cover (its bind
        # coincides with the built-in 8080).
        stalwart-bind-e2e = import ../tests/stalwart-bind-e2e.nix {inherit pkgs;};
        # 0.15 -> 0.16 store migration (guard + script + poisoned-store
        # recovery): the class that took the pbx host's mail down - no
        # virgin-store test can see it by construction. RE-REGISTERED
        # 2026-10-18 with the two-node redesign: the 0.15.5 phase-A node
        # seeds a real store, the store travels to the 0.16 consumer node
        # through a shared virtfs directory, and no in-VM
        # switch-to-configuration ever runs (the 2026-10-17 single-node
        # switch stopped backdoor.service and wedged the driver).
        stalwart-migrate-e2e = import ../tests/stalwart-migrate-e2e.nix {inherit pkgs;};
        stalwart-relay-e2e = import ../tests/stalwart-relay-e2e.nix {inherit pkgs;};
        parsedmarc-e2e = import ../tests/parsedmarc-e2e.nix {inherit pkgs;};
      };
  };
}
