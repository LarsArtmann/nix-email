# Opinionated wrapper around the nixpkgs Stalwart module (services.stalwart).
#
# WHY a wrapper: nixpkgs ships a battery-free `settings` attrset - every
# listener, TLS mode, and the hostname must be assembled per host. This module
# fixes ONE RFC-compliant listener set so a deployment is "enable + hostname"
# instead of TOML archaeology, while everything stays overridable through
# `services.stalwart.settings` (all wrapper values are mkDefault).
#
# WHY NOT re-hardened: the nixpkgs unit already carries the full systemd
# hardening set (SystemCallFilter=@system-service ~@privileged,
# ProtectSystem=strict, MemoryDenyWriteExecute, dynamic user omitted
# deliberately for large-state chown costs). SystemNix layers sops
# credentials, port registration, Gatus checks, and onFailure alerting on the
# consumer side (DiscordSync/monitor365 upstream-flake pattern).
#
# Listener contract (the one decision this module owns):
#   25   smtp          inbound MX (TLS via STARTTLS, opportunistic at first)
#   587  submission    client auth + STARTTLS
#   465  submissions   client auth + implicit TLS
#   993  imaps         mailbox access, implicit TLS
#   http admin/JMAP listener binds LOOPBACK ONLY by default - expose via a
#   reverse proxy (Caddy protectedVHost / native OIDC doctrine), never raw.
#
# Outbound delivery is deliberately NOT set here: relaying through a
# smarthost (Resend) is a per-host `settings` addition - see README for the
# exact keys once the VPS exists. Direct-to-MX from a fresh VPS IP is the
# reputation trap the selfhosted-email guide warns about.
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.mail-server;
in
{
  options.services.mail-server = {
    enable = lib.mkEnableOption "an opinionated Stalwart mail server (all-in-one SMTP/IMAP/JMAP, built-in spam filter, web admin)";

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "mail.example.com";
      description = ''
        The mail server's FQDN. Used for the SMTP banner, HelO/greeting, and
        must match the DNS MX/PTR story of the host (rDNS at the provider
        should resolve back to this name).
      '';
    };

    httpBind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8080";
      description = ''
        Bind address for the HTTP listener (web admin, JMAP, REST API).
        Loopback by default: put a TLS-terminating reverse proxy in front.
      '';
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "26.11";
      description = ''
        Passed through to services.stalwart.stateVersion (which has no
        default): the NixOS release this module was first enabled on the
        machine. Only touch when migrating an existing install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasInfix "." cfg.hostname;
        message = "services.mail-server.hostname must be an FQDN (got \"${cfg.hostname}\") - a bare host name breaks MX/PTR alignment.";
      }
    ];

    services.stalwart = {
      enable = true;
      inherit (cfg) stateVersion;
      # nixpkgs' openFirewall derives ports from ALL listener binds, which
      # would punch the loopback-only httpBind port (8080) through the
      # firewall on every interface. Open exactly the public listener ports
      # below instead; loopback needs no firewall rule.
      openFirewall = lib.mkDefault false;
      settings = {
        # Implicit-TLS listeners (465/993) are DEAD without a certificate:
        # live-observed "No TLS certificates available" in the VM test. The
        # key is `certificate.self-signed` (verified against the 0.15.5
        # binary - there is no .default level). Default to Stalwart's
        # generated self-signed cert so a fresh deployment serves TLS out of
        # the box; override with real cert material or ACME on the
        # production host (mkDefault loses to consumer settings).
        certificate.self-signed = lib.mkDefault true;
        server = {
          hostname = lib.mkDefault cfg.hostname;
          listener = {
            smtp = {
              bind = [ "[::]:25" ];
              protocol = "smtp";
            };
            submission = {
              bind = [ "[::]:587" ];
              protocol = "smtp";
            };
            submissions = {
              bind = [ "[::]:465" ];
              protocol = "smtp";
              tls.implicit = true;
            };
            imaps = {
              bind = [ "[::]:993" ];
              protocol = "imap";
              tls.implicit = true;
            };
            http = {
              bind = [ cfg.httpBind ];
              protocol = "http";
            };
          };
        };
      };
    };

    # The module owns the listener contract, so it owns the firewall ports
    # for it. Plain definition (NOT mkDefault): on this nixpkgs pin a
    # mkDefault list here is silently dropped to [] (empirically verified,
    # 2026-09-14; services.openssh.ports mkDefault works fine - something in
    # the base firewall modules filters weaker-priority defs). Lists concat:
    # consumer port lists merge additively; mkForce yours to replace.
    networking.firewall.allowedTCPPorts = [
      25
      465
      587
      993
    ];
  };
}
