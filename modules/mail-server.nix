# Opinionated wrapper around the (vendored) nixpkgs Stalwart 0.16+ module.
#
# UPSTREAM BASE: Stalwart 0.16.x (pkgs.stalwart_0_16) - the 2026-04 release
# that removed TOML configuration and the /api REST surface entirely
# (UPGRADING/v0_16.md). Everything except the datastore descriptor lives in
# the datastore as JMAP objects, applied declaratively by
# `stalwart-cli apply` through the vendored module's
# `services.stalwart.provision` mechanism (NixOS/nixpkgs PR #552103,
# vendored under ./stalwart-module/ until it merges upstream).
#
# WHY a wrapper: 0.16 objects are verbose (typed variants, #id references,
# dependency ordering). This module fixes ONE RFC-compliant listener set and
# maps the wrapper options onto the 0.16 object model, so a deployment stays
# "enable + hostname (+ admin secret)" instead of plan archaeology.
#
# WHY NOT re-hardened: the nixpkgs unit already carries the full systemd
# hardening set (SystemCallFilter=@system-service ~@privileged,
# ProtectSystem=strict, MemoryDenyWriteExecute). SystemNix layers sops
# credentials, port registration, Gatus checks, and onFailure alerting on the
# consumer side (DiscordSync/monitor365 upstream-flake pattern).
#
# Listener contract (the one decision this module owns - unchanged from the
# 0.15 era):
#   25   smtp          inbound MX (STARTTLS offered)
#   587  submission    client auth + STARTTLS. NOTE: upstream 0.16 ships NO
#                      plain-STARTTLS listener by default (PACC advertises
#                      implicit-TLS only); this wrapper keeps 587 on purpose
#                      so the client contract never changed.
#   465  submissions   client auth + implicit TLS
#   993  imaps         mailbox access, implicit TLS. IMAP LOGIN resolves by
#                      the account's EMAIL ADDRESS in 0.16 (accounts are
#                      local part + domain object; the pre-0.16
#                      "login by principal NAME" trap is gone).
#   http admin/JMAP     binds cfg.httpBind (LOOPBACK by default): expose via
#                      a reverse proxy, never raw.
#
# Outbound delivery defaults to direct-to-MX. Setting `relay` hands every
# non-local message to an authenticated smarthost (Resend) instead - emitted
# as a MtaRoute (Relay variant) + MtaOutboundStrategy route expression, the
# 0.16 replacement of the 0.15 `queue.route`/`queue.strategy.route` TOML.
#
# PASSTHROUGH: everything the wrapper does not own is provisioned by the
# consumer through `services.stalwart.provision.singletons` /
# `.objects` (merged into the wrapper's plan). Extending is the normal path
# (add new object ids); REPLACING a wrapper-owned id needs mkForce because
# the wrapper emits plain (not mkDefault) definitions - see the README
# "0.16 provisioning" section.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mail-server;

  # Mirrors the vendored module: the unit is stalwart-mail.service on
  # stateVersion < 26.05 and stalwart.service since. The LoadCredential
  # mount path embeds the unit name, so secret filePaths must too.
  stalwartUnit =
    if lib.versionOlder cfg.stateVersion "26.05"
    then "stalwart-mail"
    else "stalwart";
  credentialPath = key: "/run/credentials/${stalwartUnit}.service/${key}";

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
  httpBindIsWildcard =
    httpBindHost == "0.0.0.0" || httpBindHost == "::" || httpBindHost == "[::]" || httpBindHost == "*";

  # Port part of httpBind, when the string carries one ("<host>:<port>").
  httpBindPort = let
    m = builtins.match ".*:([0-9]+)$" cfg.httpBind;
  in
    if m == null
    then null
    else lib.toInt (builtins.head m);

  # The provisioning unit talks to the management listener. Reach it over
  # loopback whenever the bind is loopback OR wildcard; a specific
  # non-local bind address is used verbatim.
  provisionHost =
    if httpBindIsLoopback || httpBindIsWildcard
    then "127.0.0.1"
    else httpBindHost;
  provisionPort =
    if httpBindPort == null
    then 8080
    else httpBindPort;
  provisionUrl = "http://${provisionHost}:${toString provisionPort}";

  # 0.16 durations are INTEGER MILLISECONDS (registry/src/types/duration.rs
  # serializes as_millis), unlike the 0.15 "5s" strings. The wrapper option
  # stays in seconds (0.15-compat for consumers); the plan gets ms.
  secondsToMs = s: s * 1000;

  # rate "<count>/<period>" -> { count; period(ms) } (x:Rate fields).
  ratePeriodMs = {
    ms = 1;
    s = 1000;
    m = 60000;
    h = 3600000;
    d = 86400000;
  };
  parseRate = rate: let
    m = builtins.match "([0-9]+)/([0-9]+)(ms|s|m|h|d)" rate;
    count = lib.toInt (builtins.elemAt m 0);
    period = lib.toInt (builtins.elemAt m 1);
    unit = builtins.elemAt m 2;
  in {
    inherit count;
    period = period * ratePeriodMs.${unit};
  };

  # Throttle keys renamed in the 0.16 object model
  # (enum MtaInboundThrottleKey): snake_case -> camelCase. "mx" is GONE
  # upstream - the option refuses it instead of silently dropping.
  throttleKeyMap = {
    rcpt = "rcpt";
    rcpt_domain = "rcptDomain";
    sender = "sender";
    sender_domain = "senderDomain";
    authenticated_as = "authenticatedAs";
    listener = "listener";
    remote_ip = "remoteIp";
    local_ip = "localIp";
    helo_domain = "heloDomain";
  };
  rateLimiterKeys = builtins.attrNames throttleKeyMap;

  # DNSBL scope -> SpamDnsblServer variant name (the variant IS the scope in
  # the 0.16 object model).
  dnsblScopeVariant = {
    ip = "Ip";
    domain = "Domain";
    email = "Email";
    url = "Url";
  };

  # ACME challenge -> AcmeChallengeType enum names.
  acmeChallengeEnum = {
    http-01 = "Http01";
    tls-alpn-01 = "TlsAlpn01";
    dns-01 = "Dns01";
  };

  # A 0.16 Expression is { match = [ {if;then} ]; else = <string> } - a
  # CONSTANT expression is just the else branch. Zone/tag strings keep the
  # 0.15 QUOTED-constant discipline: unquoted values die in the expression
  # tokenizer ("Invalid variable or constant").
  constantExpr = s: {"else" = "'${s}'";};

  # The wrapper-owned Domain object id (documented: consumers reference it
  # as "#domain" in domainId fields).
  wrapperDomainId = "domain";
in {
  # Swap the pinned nixpkgs 0.15 module for the vendored 0.16 one in EVERY
  # evaluation that imports this wrapper (consumers, tests, demo). Both
  # spellings are listed because a future nixpkgs bump replaces
  # stalwart.nix with the stalwart/ directory - a nonexistent
  # disabledModules entry is a no-op, so both can ride along safely.
  # TOP-LEVEL (not config): disabledModules is a special module attribute,
  # unconditional by design - importing this wrapper means "stalwart comes
  # from the 0.16 module".
  disabledModules = [
    "services/mail/stalwart.nix"
    "services/mail/stalwart"
  ];

  # The vendored 0.16 module REPLACES the disabled nixpkgs one (options +
  # provision mechanism). Imported HERE so any consumer of the wrapper
  # gets a self-contained, working services.stalwart regardless of which
  # export surface they import.
  imports = [
    ./stalwart-module/default.nix
    ./stalwart-module/provision.nix
  ];

  options.services.mail-server = {
    enable = lib.mkEnableOption "an opinionated Stalwart mail server (all-in-one SMTP/IMAP/JMAP, built-in spam filter, web admin)";

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "mail.example.com";
      description = ''
        The mail server's FQDN. Used as the SystemSettings defaultHostname,
        provisioned as the server's primary Domain object, and must match
        the DNS MX/PTR story of the host (rDNS at the provider should
        resolve back to this name).
      '';
    };

    httpBind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8080";
      description = ''
        Bind address for the HTTP listener (web admin, JMAP, management
        API). Loopback by default: put a TLS-terminating reverse proxy in
        front.
      '';
    };

    publicUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://mail.example.com";
      description = ''
        The PUBLIC URL of the instance (STALWART_PUBLIC_URL). 0.16 publishes
        OIDC/JMAP discovery documents from it, so it must be the URL users
        actually hit (scheme + hostname [+ port if not 443]). Defaults to
        https://hostname.
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

    admin = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = ''
          Fallback administrator login (0.16 systemd-credentials fallback
          admin). This account is the provisioning CLI's only credential
          path, so the wrapper always enables it.
        '';
      };
      secretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to the fallback admin PASSWORD (sops template / credential
          file on real hosts). Fed through systemd LoadCredential - the
          password never lands in the Nix store. REQUIRED.
        '';
      };
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
              (implicitTls = false), 465 = implicit TLS (implicitTls = true).
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
              from the relay route as a File secret ({"@type" = "File";
              filePath}), so the password never lands in the Nix store.
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
              Object id of the generated MtaRoute; the outbound strategy
              expression routes non-local mail to this id (by NAME).
            '';
          };
        };
      });
      default = null;
      description = ''
        Outbound smarthost relay. null (default) = direct-to-MX delivery.
        When set, mail for NON-local domains is handed to this relay; local
        delivery is untouched. Generates a MtaRoute (Relay variant) and the
        MtaOutboundStrategy route expression (is_local_domain -> 'local',
        else -> relay) - the 0.16 shape of the 0.15 queue.route/strategy
        pair.
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
          basic auth by extending provision.singletons.Metrics.prometheus
          with authUsername/authSecret.
        '';
      };
    };

    directoryCacheTtlNegative = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 60;
      description = ''
        Negative-cache TTL in SECONDS (Cache singleton negativeTtl; upstream
        default 3600). A miss is cached for this long, so ANY SMTP traffic
        touching a domain before it is provisioned routes that domain's mail
        to the MX path until the TTL expires (the 1h trap in the README
        ledger). Dev/test hosts want this low; leave null to keep the
        upstream default.
      '';
    };

    rateLimits = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Add ONE wrapper-managed inbound rate limiter (a sustained-volume
          damper, MtaInboundThrottle object). OFF by default: upstream ships
          conservative inbound limiters of its own, and every matching
          limiter must allow a message - this one only binds on sustained
          volume.
        '';
      };
      id = lib.mkOption {
        type = lib.types.str;
        default = "wrapper-sustained";
        description = "Object id of the generated MtaInboundThrottle.";
      };
      rate = lib.mkOption {
        type = lib.types.strMatching "[0-9]+/[0-9]+(ms|s|m|h|d)";
        default = "600/1h";
        description = ''
          `<requests>/<period>` for the throttle's x:Rate; the period grammar
          is `<digits><ms|s|m|h|d>` (rendered as integer milliseconds in the
          0.16 object). Stalwart also accepts "false"/"none"/"unlimited"
          spellings which silently DISABLE a limiter - the type refuses
          those so enable/rate always mean what they say.
        '';
      };
      keys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["remote_ip"];
        description = ''
          Throttle keys (snake_case, 0.15-compatible spelling; translated to
          the 0.16 MtaInboundThrottleKey enum): one bucket per distinct
          tuple. Valid: rcpt, rcpt_domain, sender, sender_domain,
          authenticated_as, listener, remote_ip, local_ip, helo_domain.
          ("mx" no longer exists upstream.) Sizing guidance lives in README
          "Rate-limit sizing". Conditional limiters (Expression match) are
          passthrough-only: write provision.objects.MtaInboundThrottle.
        '';
      };
    };

    spamFilter.dnsbl.servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          scope = lib.mkOption {
            type = lib.types.enum ["ip" "domain" "email" "url"];
            description = ''
              Which element is queried against the zone; maps to the
              SpamDnsblServer variant (Ip/Domain/Email/Url). Header/body
              variants exist upstream but are unreachable in the DNSBL check
              path, so the wrapper does not offer them.
            '';
          };
          zone = lib.mkOption {
            type = lib.types.str;
            example = "zen.spamhaus.org";
            description = ''
              DNSBL zone queried. Emitted as a quoted expression constant:
              an UNQUOTED zone fails Stalwart's expression parser
              ("Invalid variable or constant").
            '';
          };
          tag = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Spam tag added when the element lists (quoted like zone).
              Default: Stalwart's built-in tag for the server.
            '';
          };
        };
      });
      default = {};
      description = ''
        DNS blocklist servers for spam analysis (SpamDnsblServer objects).
        EMPTY BY DEFAULT: DNSBL lookups need working resolver DNS
        (unavailable in the DNS-less E2E VM; same class as pyzor), and it is
        content-analysis only: matches add spam tags, nothing is rejected at
        connection time.
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
              self-signed (default): no Certificate objects are provisioned;
              the 0.16 server self-generates a cert at first start
              (asynchronously - can take >80 s in entropy-poor VMs).
              acme: AcmeProvider object + Automatic certificateManagement on
              the wrapper Domain.
              manual: cert/key files via systemd LoadCredential referenced
              as File secrets from a Certificate object.
            '';
          };
          acme = {
            id = lib.mkOption {
              type = lib.types.str;
              default = "letsencrypt";
              description = "Object id of the generated AcmeProvider.";
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
                Contact addresses (required - the AcmeProvider schema
                demands minItems 1).
              '';
            };
            domains = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = ["mail.example.com"];
              description = ''
                Domains to issue certificates for. In 0.16 the domain list
                is DERIVED from Domain objects carrying Automatic
                certificateManagement; this option is validated non-empty
                and cross-checked against hostname.
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
                ACME challenge type (AcmeChallengeType enum). http-01 needs
                port 80 reachable on the mail hostname; tls-alpn-01 needs
                the TLS listener itself. dns-01 additionally needs a DNS
                provider object (consumer provision territory).
              '';
            };
          };
          manual = {
            id = lib.mkOption {
              type = lib.types.str;
              default = "wrapper";
              description = "Object id of the generated Certificate.";
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
                Set this certificate as SystemSettings.defaultCertificateId
                so SNI-less handshakes (and listeners without a domain
                match) serve something.
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
        {
          assertion = cfg.admin.secretFile != null;
          message = "services.mail-server.admin.secretFile is REQUIRED - the 0.16 fallback admin is the provisioning CLI's only credential path (systemd-creds), and without it stalwart-provision cannot authenticate.";
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
          message = "services.mail-server.rateLimits.keys contains an invalid throttle key - Stalwart would reject the whole throttle object. Valid keys (snake_case; translated to the 0.16 MtaInboundThrottleKey enum): ${lib.concatStringsSep ", " rateLimiterKeys}.";
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
          message = "services.mail-server.certificate.acme.contact must list at least one contact address - the AcmeProvider schema requires minItems 1.";
        }
        {
          assertion = cfg.certificate.acme.domains != [];
          message = "services.mail-server.certificate.acme.domains must list at least one domain (typically the mail hostname) - with no domains the Automatic certificateManagement has nothing to issue for.";
        }
        {
          assertion = lib.elem cfg.hostname cfg.certificate.acme.domains;
          message = "services.mail-server.certificate.acme.domains must include the mail hostname (\"${cfg.hostname}\") - the wrapper's Domain object carries the Automatic certificateManagement, so the hostname itself is the primary issuance target.";
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
          web admin, JMAP and management API would be exposed raw on every interface.
          README doctrine: keep the bind on loopback and put a TLS-terminating reverse proxy
          (with auth) in front instead.
        ''
      ]
      ++ lib.optionals (cfg.enable && cfg.certificate.mode != "acme" && (cfg.certificate.acme.contact != [] || cfg.certificate.acme.domains != [])) [
        "services.mail-server.certificate.acme.* is set but certificate.mode is \"${cfg.certificate.mode}\" - the ACME settings are IGNORED. Set certificate.mode = \"acme\" to use them."
      ]
      ++ lib.optionals (cfg.enable && cfg.certificate.mode != "manual" && (cfg.certificate.manual.certFile != null || cfg.certificate.manual.keyFile != null)) [
        "services.mail-server.certificate.manual.* is set but certificate.mode is \"${cfg.certificate.mode}\" - the manual certificate files are IGNORED. Set certificate.mode = \"manual\" to use them."
      ]
      ++ lib.optionals (cfg.enable && cfg.certificate.mode == "acme") [
        ''
          services.mail-server.certificate.mode = "acme": the 0.16 AcmeProvider object is emitted
          from the schema, but NO VM test exercises live ACME (needs real DNS + a reachable CA).
          Verify issuance against a live host before prod (README go-live runbook owns that gate).
        ''
      ];

    services.stalwart = {
      enable = true;
      # The 0.16 package attr; pkgs.stalwart is still the 0.15 line at this
      # pin (and warns loudly if used with this module).
      package = pkgs.stalwart_0_16;
      inherit (cfg) stateVersion;
      # nixpkgs' openFirewall derives ports from provision listener binds,
      # which would punch the management port through the firewall on every
      # interface. The wrapper owns the exact public port list below;
      # loopback needs no firewall rule.
      openFirewall = false;

      url =
        if cfg.publicUrl != null
        then cfg.publicUrl
        else "https://${cfg.hostname}";

      admin = {
        enable = true;
        username = cfg.admin.username;
      };

      credentials = lib.mergeAttrsList (
        [
          {${cfg.admin.username} = toString cfg.admin.secretFile;}
        ]
        ++ lib.optionals (cfg.relay != null && cfg.relay.username != null) [
          {mail-server-relay = toString cfg.relay.secretFile;}
        ]
        ++ lib.optionals (cfg.certificate.mode == "manual" && cfg.certificate.manual.certFile != null) [
          {mail-server-certificate = toString cfg.certificate.manual.certFile;}
        ]
        ++ lib.optionals (cfg.certificate.mode == "manual" && cfg.certificate.manual.keyFile != null) [
          {mail-server-certificate-key = toString cfg.certificate.manual.keyFile;}
        ]
      );

      provision = {
        enable = true;
        url = provisionUrl;

        singletons = lib.mkMerge (
          [
            {
              SystemSettings =
                {
                  defaultHostname = cfg.hostname;
                }
                // lib.optionalAttrs (cfg.certificate.mode == "manual" && cfg.certificate.manual.default) {
                  defaultCertificateId = "#${cfg.certificate.manual.id}";
                };
            }
          ]
          ++ lib.optionals (cfg.directoryCacheTtlNegative != null) [
            {
              # SINGLETON (x:Cache): negativeTtl is integer MILLISECONDS
              # upstream - the wrapper option stays in seconds
              # (0.15-compat for consumers).
              Cache = {
                negativeTtl = secondsToMs cfg.directoryCacheTtlNegative;
              };
            }
          ]
          ++ lib.optionals cfg.metrics.enable [
            {
              Metrics.prometheus."@type" = "Enabled";
            }
          ]
          ++ lib.optionals (cfg.relay != null) [
            {
              # SINGLETON (x:MtaOutboundStrategy): the route Expression.
              # Shape mirrors the 0.16 built-in default (is_local_domain ->
              # 'local', else -> 'mx') with the relay NAME replacing 'mx'.
              MtaOutboundStrategy.route = {
                match = [
                  {
                    "if" = "is_local_domain(rcpt_domain)";
                    "then" = "'local'";
                  }
                ];
                "else" = "'${cfg.relay.routeId}'";
              };
            }
          ]
        );

        objects = lib.mkMerge (
          [
            {
              # The wrapper's own domain, present from first boot so
              # is_local_domain never sees a cold cache for it.
              Domain.objects.${wrapperDomainId} = {
                name = cfg.hostname;
                dkimManagement."@type" = "Manual";
                dnsManagement."@type" = "Manual";
                certificateManagement =
                  if cfg.certificate.mode == "acme"
                  then {
                    "@type" = "Automatic";
                    acmeProviderId = "#${cfg.certificate.acme.id}";
                  }
                  else {"@type" = "Manual";};
              };

              NetworkListener = {
                reconcile = true;
                match = ["name"];
                objects = {
                  smtp = {
                    name = "smtp";
                    protocol = "smtp";
                    bind = ["[::]:25"];
                  };
                  submission = {
                    name = "submission";
                    protocol = "smtp";
                    bind = ["[::]:587"];
                  };
                  submissions = {
                    name = "submissions";
                    protocol = "smtp";
                    bind = ["[::]:465"];
                    tlsImplicit = true;
                  };
                  imaps = {
                    name = "imaps";
                    protocol = "imap";
                    bind = ["[::]:993"];
                    tlsImplicit = true;
                  };
                  http = {
                    name = "http";
                    protocol = "http";
                    bind = [cfg.httpBind];
                    useTls = false;
                  };
                };
              };
            }
          ]
          ++ lib.optionals cfg.rateLimits.enable [
            {
              MtaInboundThrottle.objects.${cfg.rateLimits.id} = {
                enable = true;
                key = map (k: throttleKeyMap.${k}) cfg.rateLimits.keys;
                rate = parseRate cfg.rateLimits.rate;
              };
            }
          ]
          ++ lib.optionals (cfg.spamFilter.dnsbl.servers != {}) [
            {
              SpamDnsblServer = {
                reconcile = false;
                objects = lib.mapAttrs (id: srv:
                  {
                    "@type" = dnsblScopeVariant.${srv.scope};
                    name = id;
                    enable = true;
                    zone = constantExpr srv.zone;
                  }
                  // lib.optionalAttrs (srv.tag != null) {
                    tag = constantExpr srv.tag;
                  })
                cfg.spamFilter.dnsbl.servers;
              };
            }
          ]
          ++ lib.optionals (cfg.relay != null) [
            {
              MtaRoute.objects.${cfg.relay.routeId} =
                {
                  "@type" = "Relay";
                  name = cfg.relay.routeId;
                  address = cfg.relay.address;
                  port = cfg.relay.port;
                  protocol = "smtp";
                  implicitTls = cfg.relay.tlsImplicit;
                }
                // lib.optionalAttrs (cfg.relay.username != null) {
                  authUsername = cfg.relay.username;
                  authSecret."@type" = "File";
                  authSecret.filePath = credentialPath "mail-server-relay";
                };
            }
          ]
          ++ lib.optionals (cfg.certificate.mode == "acme") [
            {
              AcmeProvider.objects.${cfg.certificate.acme.id} = {
                directory = cfg.certificate.acme.directory;
                contact = cfg.certificate.acme.contact;
                challengeType = acmeChallengeEnum.${cfg.certificate.acme.challenge};
              };
            }
          ]
          ++ lib.optionals (cfg.certificate.mode == "manual") [
            {
              Certificate.objects.${cfg.certificate.manual.id} = {
                certificate."@type" = "File";
                certificate.filePath = credentialPath "mail-server-certificate";
                privateKey."@type" = "File";
                privateKey.filePath = credentialPath "mail-server-certificate-key";
              };
            }
          ]
        );
      };
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
    #
    # The httpBind port joins ONLY on a non-loopback bind (demo-VM hostfwd
    # root cause, transcript 2026-09-22: `httpBind = "0.0.0.0:8080"` with the
    # port firewalled makes every remote connection OPEN and then hang
    # forever - SYN dropped after slirp/proxy already accepted host-side;
    # in-guest loopback keeps working, SMTP ports flow, so the failure mode
    # is a near-undebuggable "connects but never answers"). The non-loopback
    # warning above already flags the raw-exposure tradeoff.
    networking.firewall.allowedTCPPorts =
      [
        25
        465
        587
        993
      ]
      ++ lib.optionals (!httpBindIsLoopback && httpBindPort != null) [httpBindPort];
  };
}
