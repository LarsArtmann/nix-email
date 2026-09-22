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
# Outbound delivery defaults to direct-to-MX. Setting `relay` hands every
# non-local message to an authenticated smarthost (Resend) instead - the
# generated `queue.route`/`queue.strategy.route` keys are verified against the
# v0.15.5 source AND a live Mailpit spike (see README verified-facts ledger).
# Direct-to-MX from a fresh VPS IP is the reputation trap the selfhosted-email
# guide warns about.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.mail-server;

  # Mirrors nixpkgs' stalwart module: the unit is stalwart-mail.service on
  # stateVersion < 26.05 and stalwart.service since. The LoadCredential
  # mount path embeds the unit name, so secret macros must too.
  stalwartUnit =
    if lib.versionOlder cfg.stateVersion "26.05"
    then "stalwart-mail"
    else "stalwart";
  credentialMacro = key: "%{file:/run/credentials/${stalwartUnit}.service/${key}}%";

  # The HTTP bind is "<host>:<port>"; extract the host part to judge loopback.
  httpBindHost = let
    m = builtins.match "(.*):[0-9]+" cfg.httpBind;
  in
    if m == null
    then cfg.httpBind
    else builtins.head m;
  httpBindIsLoopback =
    lib.hasPrefix "127." httpBindHost
    || httpBindHost == "localhost"
    || httpBindHost == "[::1]"
    || httpBindHost == "::1";

  # v0.15.5 throttle key names (crates/common/src/config/smtp/throttle.rs
  # parse_queue_rate_limiter_key). Note: "authenticated_as", NOT "auth_as".
  rateLimiterKeys = [
    "rcpt"
    "rcpt_domain"
    "sender"
    "sender_domain"
    "authenticated_as"
    "listener"
    "mx"
    "remote_ip"
    "local_ip"
    "helo_domain"
  ];
in {
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

    relay = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            example = "smtp.resend.com";
            description = ''
              Smarthost hostname. Must be DNS-resolvable: Stalwart resolves
              relay targets via A lookup and REFUSES bare IP literals
              ("record not found for MX" - live-observed, README ledger).
            '';
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 587;
            description = ''
              Submission port on the smarthost: 587 = STARTTLS
              (tlsImplicit = false), 465 = implicit TLS (tlsImplicit = true).
              Resend offers both; Hetzner never blocks 587.
            '';
          };
          username = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              SASL username for the smarthost. Set together with secretFile
              (or neither - auth is all-or-nothing).
            '';
          };
          secretFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to the relay password (sops template / credential file on
              real hosts). Fed through systemd LoadCredential and referenced
              from the Stalwart config via a %{file:...}% macro, so the
              password never lands in the world-readable TOML.
            '';
          };
          tlsImplicit = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "true = implicit TLS (465-style), false = STARTTLS (587-style).";
          };
          routeId = lib.mkOption {
            type = lib.types.str;
            default = "smarthost";
            description = ''
              Identifier of the generated `queue.route` entry; the strategy
              expression routes non-local mail to this id.
            '';
          };
        };
      });
      default = null;
      description = ''
        Outbound smarthost relay. null (default) = direct-to-MX delivery.
        When set, mail for NON-local domains is handed to this relay; local
        delivery is untouched. Generates (verified against v0.15.5 source):
        `queue.route.<routeId>` and `queue.strategy.route` with the exact
        default-shape expression (is_local_domain -> 'local', else -> relay).
      '';
    };

    metrics = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose Prometheus metrics at /metrics/prometheus ON THE HTTP
          LISTENER (loopback by default: scrape via a reverse-proxy route or
          SSH tunnel - never expose the whole admin port for it). Optional
          basic auth via `services.stalwart.settings.metrics.prometheus.auth`.
        '';
      };
    };

    directoryCacheTtlNegative = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 60;
      description = ''
        Negative-cache TTL in seconds for internal-directory lookups
        (`directory."internal".cache.ttl.negative`; upstream default 3600).
        A miss is cached for this long, so ANY SMTP traffic touching a domain
        before it is provisioned routes that domain's mail to the MX path
        until the TTL expires (the 1h trap in the README ledger). Dev/test
        hosts want this low; leave null to keep the upstream default.
      '';
    };

    rateLimits = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Add ONE wrapper-managed inbound rate limiter (a sustained-volume
          damper). OFF by default because v0.15.5 ALREADY ships two
          conservative inbound limiters (README ledger): per remote_ip
          "5/1s" (burst) and per sender_domain+rcpt "25/1h". Enabling stacks
          this limiter NEXT to those - every matching limiter must allow a
          message, so this one only binds on sustained volume.
        '';
      };
      id = lib.mkOption {
        type = lib.types.str;
        default = "wrapper-sustained";
        description = "Identifier of the generated `queue.limiter.inbound` entry.";
      };
      rate = lib.mkOption {
        type = lib.types.strMatching "[0-9]+/[0-9]+(ms|s|m|h|d)";
        default = "600/1h";
        description = ''
          `<requests>/<period>` for `queue.limiter.inbound.<id>.rate`; the
          period grammar is `<digits><ms|s|m|h|d>` (v0.15.5 Duration
          parser). Stalwart
          also accepts "false"/"none"/"unlimited" here, which silently
          DISABLES the limiter (zero-request rate is filtered out) - the
          type refuses those so enable/rate always mean what they say.
        '';
      };
      keys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["remote_ip"];
        description = ''
          Throttle keys (`queue.limiter.inbound.<id>.key`): one bucket per
          distinct tuple of these values. Valid v0.15.5 names (asserted at
          eval time): rcpt, rcpt_domain, sender, sender_domain,
          authenticated_as, listener, mx, remote_ip, local_ip, helo_domain.
        '';
      };
    };

    spamFilter.dnsbl.servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          scope = lib.mkOption {
            type = lib.types.enum ["ip" "domain" "email" "url"];
            description = ''
              Which element is queried against the zone
              (`spam-filter.dnsbl.server.<id>.scope` - REQUIRED upstream).
              v0.15.5 also parses header/body/any scopes, but they are
              unreachable in the DNSBL check path, so the wrapper does not
              offer them.
            '';
          };
          zone = lib.mkOption {
            type = lib.types.str;
            example = "zen.spamhaus.org";
            description = ''
              DNSBL zone queried (`...zone`). Emitted as a quoted expression
              constant: an UNQUOTED zone fails Stalwart's expression parser
              with "Invalid variable or constant" (v0.15.5 tokenizer).
              Conditional (IfBlock) zones need the
              services.stalwart.settings passthrough.
            '';
          };
          tag = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Spam tag added when the element lists (`...tag`, quoted like
              zone). Default: Stalwart's built-in tag for the server.
            '';
          };
        };
      });
      default = {};
      description = ''
        DNS blocklist servers for spam analysis
        (`spam-filter.dnsbl.server.<id>`). EMPTY BY DEFAULT: v0.15.5 has no
        master switch - the server list IS the switch - DNSBL lookups need
        working resolver DNS (unavailable in the DNS-less E2E VM; same class
        as pyzor), and it is content-analysis only: matches add spam tags,
        nothing is rejected at connection time.
      '';
    };

    certificate = lib.mkOption {
      description = ''
        TLS certificate tier. Exactly one mode's material is generated - the
        modes are mutually exclusive by construction (nixos-mailserver
        x509-certificate pattern).
      '';
      default = {mode = "self-signed";};
      type = lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.enum [
              "self-signed"
              "acme"
              "manual"
            ];
            default = "self-signed";
            description = ''
              self-signed (default): Stalwart generates a cert at first start
              (asynchronously - can take >80 s in entropy-poor VMs).
              acme: Stalwart's built-in ACME client (dns-01 additionally needs
              `acme.<id>.provider`/`.secret` via settings passthrough).
              manual: cert/key files via systemd LoadCredential.
            '';
          };
          acme = {
            id = lib.mkOption {
              type = lib.types.str;
              default = "letsencrypt";
              description = "Identifier of the generated `acme.<id>` entry.";
            };
            directory = lib.mkOption {
              type = lib.types.str;
              default = "https://acme-v02.api.letsencrypt.org/directory";
              description = "ACME directory URL.";
            };
            contact = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = ["mailto:hostmaster@example.com"];
              description = ''
                Contact addresses (required - Stalwart fails config parse on
                an empty contact, verified against v0.15.5 source).
              '';
            };
            domains = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = ["mail.example.com"];
              description = ''
                Domains to issue certificates for (required; wildcards only
                with the dns-01 challenge - upstream-validated).
              '';
            };
            challenge = lib.mkOption {
              type = lib.types.enum [
                "http-01"
                "tls-alpn-01"
                "dns-01"
              ];
              default = "http-01";
              description = ''
                ACME challenge type. http-01 needs port 80 reachable on the
                mail hostname; tls-alpn-01 needs the TLS listener itself.
              '';
            };
            default = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Make this ACME manager the default when SNI does not match a
                known certificate (`acme.<id>.default` in Stalwart).
              '';
            };
          };
          manual = {
            id = lib.mkOption {
              type = lib.types.str;
              default = "wrapper";
              description = "Identifier of the generated `certificate.<id>` entry.";
            };
            certFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "PEM-encoded certificate chain file (required in manual mode).";
            };
            keyFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "PEM-encoded private key file (required in manual mode).";
            };
            default = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Serve this certificate when SNI does not match any known
                certificate (`certificate.<id>.default = true` registers it
                under the "*" catch-all - verified against v0.15.5 source).
              '';
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      [
        {
          assertion = lib.hasInfix "." cfg.hostname;
          message = "services.mail-server.hostname must be an FQDN (got \"${cfg.hostname}\") - a bare host name breaks MX/PTR alignment.";
        }
      ]
      ++ lib.optionals (cfg.relay != null) [
        {
          assertion = builtins.match ".*[a-zA-Z].*" cfg.relay.address != null;
          message = "services.mail-server.relay.address must be a DNS-resolvable hostname (got \"${cfg.relay.address}\") - Stalwart resolves relay targets via A lookup and refuses bare IP literals with \"record not found for MX\". Give the smarthost a hostname (e.g. smtp.resend.com).";
        }
        {
          # The ledger's loopback fact, mechanized at eval time: Stalwart
          # REFUSES to relay to loopback-resolving targets ("host resolves
          # loopback address", SSRF guard) - a config pointing the smarthost
          # at localhost fails at first submission, not at build time, unless
          # caught here.
          assertion = builtins.match ".*(localhost|127\\.0\\.0\\.1|::1|0\\.0\\.0\\.0).*" cfg.relay.address == null;
          message = "services.mail-server.relay.address must not be a loopback name or address (got \"${cfg.relay.address}\") - Stalwart refuses to relay to loopback targets with \"host resolves loopback address\" (SSRF guard, README ledger). Point the relay at the real smarthost hostname.";
        }
        {
          assertion = (cfg.relay.username == null) == (cfg.relay.secretFile == null);
          message = "services.mail-server.relay: set username AND secretFile together (or neither) - partial SASL credentials would fail at first submission.";
        }
      ]
      ++ lib.optionals cfg.rateLimits.enable [
        {
          assertion = lib.all (k: lib.elem k rateLimiterKeys) cfg.rateLimits.keys;
          message = "services.mail-server.rateLimits.keys contains an invalid throttle key - Stalwart would drop the whole limiter with a config parse error. Valid v0.15.5 keys: ${lib.concatStringsSep ", " rateLimiterKeys}.";
        }
      ]
      ++ lib.concatLists (lib.mapAttrsToList (id: srv: [
          {
            assertion = srv.zone != "";
            message = "services.mail-server.spamFilter.dnsbl.servers.\"${id}\".zone must be a non-empty DNSBL zone (e.g. zen.spamhaus.org).";
          }
        ])
        cfg.spamFilter.dnsbl.servers)
      ++ lib.optionals (cfg.certificate.mode == "acme") [
        {
          assertion = cfg.certificate.acme.contact != [];
          message = "services.mail-server.certificate.acme.contact must list at least one contact address - Stalwart rejects an empty ACME contact at config parse (verified against v0.15.5 source).";
        }
        {
          assertion = cfg.certificate.acme.domains != [];
          message = "services.mail-server.certificate.acme.domains must list at least one domain (typically the mail hostname) - with no domains Stalwart registers no ACME provider and the implicit-TLS listeners serve nothing.";
        }
      ]
      ++ lib.optionals (cfg.certificate.mode == "manual") [
        {
          assertion = cfg.certificate.manual.certFile != null && cfg.certificate.manual.keyFile != null;
          message = "services.mail-server.certificate.manual: both certFile and keyFile are required in manual mode - a certificate without its key (or vice versa) is silently unusable and implicit-TLS would serve nothing.";
        }
      ];

    warnings =
      lib.optionals (cfg.enable && !httpBindIsLoopback) [
        ''
          services.mail-server.httpBind ("${cfg.httpBind}") is not a loopback address: the Stalwart
          web admin, JMAP and REST management API would be exposed raw on every interface.
          README doctrine: keep the bind on loopback and put a TLS-terminating reverse proxy
          (with auth) in front instead.
        ''
      ]
      ++ lib.optionals (cfg.enable && cfg.certificate.mode != "acme" && (cfg.certificate.acme.contact != [] || cfg.certificate.acme.domains != [])) [
        "services.mail-server.certificate.acme.* is set but certificate.mode is \"${cfg.certificate.mode}\" - the ACME settings are IGNORED. Set certificate.mode = \"acme\" to use them."
      ]
      ++ lib.optionals (cfg.enable && cfg.certificate.mode != "manual" && (cfg.certificate.manual.certFile != null || cfg.certificate.manual.keyFile != null)) [
        "services.mail-server.certificate.manual.* is set but certificate.mode is \"${cfg.certificate.mode}\" - the manual certificate files are IGNORED. Set certificate.mode = \"manual\" to use them."
      ];

    services.stalwart = {
      enable = true;
      inherit (cfg) stateVersion;
      # nixpkgs' openFirewall derives ports from ALL listener binds, which
      # would punch the loopback-only httpBind port (8080) through the
      # firewall on every interface. Open exactly the public listener ports
      # below instead; loopback needs no firewall rule.
      openFirewall = lib.mkDefault false;

      credentials = lib.mkMerge [
        (lib.mkIf (cfg.relay != null && cfg.relay.username != null) {
          mail-server-relay = toString cfg.relay.secretFile;
        })
        (lib.mkIf (cfg.certificate.mode == "manual" && cfg.certificate.manual.certFile != null) {
          mail-server-certificate = toString cfg.certificate.manual.certFile;
        })
        (lib.mkIf (cfg.certificate.mode == "manual" && cfg.certificate.manual.keyFile != null) {
          mail-server-certificate-key = toString cfg.certificate.manual.keyFile;
        })
      ];

      settings = lib.mkMerge [
        {
          server = {
            hostname = lib.mkDefault cfg.hostname;
            listener = {
              smtp = {
                bind = ["[::]:25"];
                protocol = "smtp";
              };
              submission = {
                bind = ["[::]:587"];
                protocol = "smtp";
              };
              submissions = {
                bind = ["[::]:465"];
                protocol = "smtp";
                tls.implicit = true;
              };
              imaps = {
                bind = ["[::]:993"];
                protocol = "imap";
                tls.implicit = true;
              };
              http = {
                bind = [cfg.httpBind];
                protocol = "http";
              };
            };
          };

          # Implicit-TLS listeners (465/993) are DEAD without a certificate:
          # live-observed "No TLS certificates available" in the VM test. In
          # self-signed mode the key is `certificate.self-signed` (verified
          # against the 0.15.5 binary - there is no .default level); in
          # acme/manual mode the tier below owns the material instead.
          certificate = lib.mkMerge [
            (lib.mkIf (cfg.certificate.mode == "self-signed") {
              self-signed = lib.mkDefault true;
            })
            (lib.mkIf (cfg.certificate.mode == "manual") {
              "${cfg.certificate.manual.id}" = {
                cert = credentialMacro "mail-server-certificate";
                private-key = credentialMacro "mail-server-certificate-key";
                # Register as the "*" catch-all: without this the cert only
                # matches its own SANs via SNI and an SNI-less handshake
                # serves nothing (v0.15.5 source, parse_certificates).
                default = lib.mkDefault cfg.certificate.manual.default;
              };
            })
          ];

          acme = lib.mkIf (cfg.certificate.mode == "acme") {
            "${cfg.certificate.acme.id}" = {
              inherit
                (cfg.certificate.acme)
                directory
                contact
                domains
                challenge
                default
                ;
            };
          };
        }

        (lib.mkIf cfg.metrics.enable {
          metrics.prometheus.enable = lib.mkDefault true;
        })

        (lib.mkIf (cfg.directoryCacheTtlNegative != null) {
          directory."internal".cache.ttl.negative = cfg.directoryCacheTtlNegative;
        })

        (lib.mkIf cfg.rateLimits.enable {
          queue.limiter.inbound."${cfg.rateLimits.id}" = {
            enable = lib.mkDefault true;
            key = lib.mkDefault cfg.rateLimits.keys;
            rate = lib.mkDefault cfg.rateLimits.rate;
          };
        })

        (lib.mkIf (cfg.spamFilter.dnsbl.servers != {}) {
          spam-filter.dnsbl.server = lib.mapAttrs (_id: srv:
            {
              enable = lib.mkDefault true;
              scope = lib.mkDefault srv.scope;
              # Quoted expression constant: an unquoted zone string dies in
              # Stalwart's expression tokenizer ("Invalid variable or
              # constant", v0.15.5) - only 'literal' parses.
              zone = lib.mkDefault "'${srv.zone}'";
            }
            // lib.optionalAttrs (srv.tag != null) {
              tag = lib.mkDefault "'${srv.tag}'";
            })
          cfg.spamFilter.dnsbl.servers;
        })

        (lib.mkIf (cfg.relay != null) {
          queue = {
            # Smarthost definition - exact key set verified against v0.15.5
            # parse_route (type/address/port/protocol required; auth and
            # tls.implicit optional). mkDefault on every leaf: consumers
            # override via services.stalwart.settings without conflicts.
            route."${cfg.relay.routeId}" =
              {
                type = lib.mkDefault "relay";
                address = lib.mkDefault cfg.relay.address;
                port = lib.mkDefault cfg.relay.port;
                protocol = lib.mkDefault "smtp";
                tls.implicit = lib.mkDefault cfg.relay.tlsImplicit;
              }
              // lib.optionalAttrs (cfg.relay.username != null) {
                auth = {
                  username = lib.mkDefault cfg.relay.username;
                  secret = lib.mkDefault (credentialMacro "mail-server-relay");
                };
              };

            # Route expression. IfBlocks need INDEXED keys (live spike in the
            # README ledger: a bare if/then fails to parse) and `else` must
            # sort after `if`. Shape mirrors the v0.15.5 built-in default
            # (is_local_domain -> 'local', else -> 'mx') with the relay
            # id replacing 'mx'.
            strategy.route = lib.mkDefault {
              "1" = {
                "if" = "is_local_domain('*', rcpt_domain)";
                "then" = "'local'";
              };
              "2" = {
                "else" = "'${cfg.relay.routeId}'";
              };
            };
          };
        })
      ];
    };

    # The module owns the listener contract, so it owns the firewall ports
    # for it. Plain definition (NOT mkDefault), root-caused 2026-09-15: the
    # module system keeps only the numerically-LOWEST-priority definitions
    # (lib/modules.nix filterOverrides'), and base nixpkgs ships UNCONDITIONAL
    # empty defs at priority 100 on this option - podman's network-socket.nix
    # (`lib.optional (enable && openFirewall) port`) and udp-over-tcp.nix
    # (`getFirewallPorts cfg.tcp2udp`) both yield [] even when their services
    # are disabled. A mkDefault list (priority 1000) is therefore discarded
    # wholesale - lists concat only WITHIN one priority tier. `lib.optional`
    # instead of `mkIf` is the upstream anti-pattern (mkIf contributes no
    # definition when false); `services.openssh.ports` has no such base def,
    # which is why mkDefault works fine THERE. Lists concat: consumer port
    # lists merge additively; mkForce yours to replace.
    networking.firewall.allowedTCPPorts = [
      25
      465
      587
      993
    ];
  };
}
