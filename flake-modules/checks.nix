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
  }: let
    # The Stalwart version this flake actually deploys, DERIVED from the
    # wrapper module's own default (evaluated with the mail server enabled)
    # instead of retyping `pkgs.stalwart_0_16` here: a pin that renames the
    # package attr must not leave the README check comparing a stale one.
    # `parsedmarc` needed no such hop until 2026-11-06: the dmarc module
    # now vendors 11.2.1 ahead of nixpkgs (services.dmarc-monitor.package
    # default; pkgs.parsedmarc at the pin is still 11.0.2), so the README
    # check must follow the WRAPPER's default, same doctrine as Stalwart.
    deployedStalwart =
      (inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ../modules/mail-server.nix
          {
            services.mail-server.enable = true;
            services.mail-server.hostname = "mail.example.test";
            boot.loader.grub.enable = false;
            fileSystems."/".device = "/dev/null";
            system.stateVersion = "26.11";
          }
        ];
      })
      .config.services.stalwart.package;
    deployedParsedmarc =
      (inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ../modules/dmarc-monitor.nix
          {
            services.dmarc-monitor.enable = true;
            boot.loader.grub.enable = false;
            fileSystems."/".device = "/dev/null";
            system.stateVersion = "26.11";
          }
        ];
      })
      .config.services.dmarc-monitor.package;
  in {
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
        # Check-set lockstep (2026-10-19): the declared check set must
        # equal tests/check-expected.json EXACTLY - the canonical machine
        # list that ci.yml and scripts/check-inventory.sh also read, so a
        # check add/remove edits ONE file (plus the README prose row).
        # builtins.attrNames forces only attribute names, so referencing
        # self.checks here stays lazy (no recursion) and the throw below
        # fires from `nix flake check` with the drift spelled out. Pure
        # eval, arch-independent.
        check-set-lockstep = let
          expected =
            builtins.fromJSON (builtins.readFile ../tests/check-expected.json);
          sorted = builtins.sort (a: b: a < b);
          driftX =
            sorted (builtins.attrNames self.checks.x86_64-linux)
            != sorted expected.x86_64-linux;
          driftA =
            sorted (builtins.attrNames self.checks.aarch64-linux)
            != sorted expected.aarch64-linux;
        in
          if driftX || driftA
          then
            throw ''
              check-set lockstep: the declared flake checks diverge from
              tests/check-expected.json (x86_64 drift: ${
                pkgs.lib.boolToString driftX
              }, aarch64 drift: ${pkgs.lib.boolToString driftA}).
              flake declares x86_64: ${builtins.toJSON (builtins.attrNames self.checks.x86_64-linux)}
              expected        x86_64: ${builtins.toJSON expected.x86_64-linux}
              flake declares aarch64: ${builtins.toJSON (builtins.attrNames self.checks.aarch64-linux)}
              expected        aarch64: ${builtins.toJSON expected.aarch64-linux}
              Edit tests/check-expected.json in the same commit that
              adds/removes a check, and add the README prose row.
            ''
          else pkgs.runCommand "check-set-lockstep" {} "touch $out";
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
        # Convert-smoke for the vendored migrate_v016.py (2026-10-19):
        # the migration script's first FUNCTIONAL test - the real convert
        # subcommand against a minimal 0.15 dump fixture, pinning the
        # DataStore descriptor, the Domain/Account/SystemSettings plan
        # shape (local-part names, restore-<id> account ids), and the
        # --patch-paths rewrite the migration script depends on. Pure
        # derivation + build-time python, arch-independent.
        migrate-convert-eval = import ../tests/migrate-convert-eval.nix {
          inherit system;
          inherit (inputs) nixpkgs;
        };
        # Deprecated nixpkgs aliases (2026-11-01): a `warnAlias` attr warns
        # on EVERY force, so a wrapper default naming one prints on every
        # consumer rebuild while both gate and deployment stay green (the
        # `package = pkgs.stalwart` migration default behind the pbx-artmann
        # switch noise). The check parses the warnAlias set out of the SAME
        # pin the build uses (`pkgs.path`), scans repo code with comments
        # and string bodies masked, and self-tests both directions first.
        # Pure build of a python script, arch-independent.
        deprecated-alias-lint =
          pkgs.runCommand "deprecated-alias-lint" {
            nativeBuildInputs = [pkgs.python3];
          } ''
            python3 ${../scripts/check-deprecated-aliases.py} --self-test
            python3 ${../scripts/check-deprecated-aliases.py} \
              --aliases ${pkgs.path}/pkgs/top-level/aliases.nix ${../.}
            touch $out
          '';
        # README version lockstep (2026-11-02): the status block is the ONE
        # canonical place stating which versions this flake ships, and it
        # used to be hand-maintained prose - a pin advance could move
        # flake.lock and the module defaults while the front door kept
        # claiming the old pair. The Stalwart value comes from
        # `deployedStalwart` above (the wrapper module's own default, not a
        # retyped attr); parsedmarc is the attr the dmarc module wraps. An
        # advance that forgets the README fails HERE. Deliberately scoped to
        # the status block's FIRST paragraph: every other 0.16.x mention is
        # history ("0.16.22 until the 2026-10-28 advance", the delta table)
        # and a blanket textual check would fail on correct prose.
        # Self-tested both directions; `readme-version-lockstep-fires`
        # proves the drift class is actually caught.
        readme-version-lockstep =
          pkgs.runCommand "readme-version-lockstep" {
            nativeBuildInputs = [pkgs.python3];
          } ''
            python3 ${../scripts/check-readme-versions.py} --self-test
            python3 ${../scripts/check-readme-versions.py} \
              --readme ${../README.md} \
              --stalwart ${deployedStalwart.version} \
              --parsedmarc ${deployedParsedmarc.version}
            touch $out
          '';
        # A gate is proven by the drift it catches, not by its green: this
        # builds a writable copy of the REAL README, plants a wrong version
        # in the status block and fails if the lint accepts it. Without it a
        # regex that stops matching keeps the check above green forever.
        readme-version-lockstep-fires =
          pkgs.runCommand "readme-version-lockstep-fires" {
            nativeBuildInputs = [pkgs.python3];
          } ''
            cp ${../README.md} README.md
            chmod u+w README.md
            sed -i \
              's/Stalwart \*\*[0-9][0-9.]*\*\*/Stalwart **0.0.0**/' \
              README.md
            if python3 ${../scripts/check-readme-versions.py} \
              --quiet \
              --readme README.md \
              --stalwart ${deployedStalwart.version} \
              --parsedmarc ${deployedParsedmarc.version}; then
              echo "FATAL: planted version drift was accepted" >&2
              exit 1
            fi
            touch $out
          '';
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
        # The SAME battery against the vendored Stalwart 1.x package
        # (pkgs/stalwart_1_0/, ahead of nixpkgs by owner decision
        # 2026-11-05): proves the 1.x line stays deployable through the
        # wrapper WITHOUT flipping the fleet default - the 0.16 -> 1.0
        # store boundary is a migration event (SCHEMA_CHANGES.md), so
        # the default stays 0.16 until a consumer migrates. Expect
        # dialect-fix iterations here when upstream renames provision
        # keys (EmailAlias.enabled -> enable etc.); fix the wrapper or
        # version-gate in the test, never the module defaults.
        stalwart-e2e-v1 = import ../tests/stalwart-e2e.nix {
          inherit pkgs;
          package = pkgs.callPackage ../pkgs/stalwart_1_0/package.nix {};
        };
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
        # 0.16 -> 1.0 migration REHEARSAL (the gold-standard gate before
        # any live 1.x flip): a REAL 0.16.26 store (schema 6 - accepted by
        # the tool's exact-match gate, which 0.16.27 also ships) with a
        # delivered needle mail is migrated OFFLINE by the vendored
        # stalwart-migrate v1.0.6 into a fresh v1 store, and the vendored
        # 1.0.3 package then serves it: the 0.16 password and the mail
        # both survive the id-space renumbering. prepare runs through a
        # pty answering every question with the recommended default.
        stalwart-migrate-1x-e2e = import ../tests/stalwart-migrate-1x-e2e.nix {inherit pkgs;};
        stalwart-relay-e2e = import ../tests/stalwart-relay-e2e.nix {inherit pkgs;};
        parsedmarc-e2e = import ../tests/parsedmarc-e2e.nix {inherit pkgs;};
        # Continuous deliverability checks (services.mail-server.
        # deliverabilityChecks): probe unit + timer green on a real
        # Stalwart with a real local DNS zone (MX/SPF/DMARC/DKIM + a
        # mock DNSBL), the round-trip canary, the emission contract
        # (report JSON + Prometheus textfile + timer shape), and the
        # negative paths (DNSBL listing, canary auth failure at the
        # send phase).
        deliverability-e2e = import ../tests/deliverability-e2e.nix {inherit pkgs;};
      };
  };
}
