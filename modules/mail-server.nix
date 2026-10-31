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
# RETIRING `relay` (set it back to null): the plan is UPSERT-ONLY per set
# (reconcile lives only on the sets that opt in), so stopping the emission
# does NOT touch the store - the stale MtaRoute row AND the stale
# MtaOutboundStrategy singleton (else -> 'smarthost') survive and keep
# routing every non-local message at the dead smarthost. This bit the
# 2026-10-26 pbx-artmann strand (3 stale MtaRoutes + a dead else-branch).
# The one-shot consumer remedy on the SAME host after retiring the option:
#   services.stalwart.provision.objects.MtaRoute.reconcile = true;
#   services.stalwart.provision.objects.MtaRoute.match = ["name"];
#   services.stalwart.provision.objects.MtaRoute.objects = {};
#   services.stalwart.provision.objects.MtaRoute.scope.name = "smarthost";
# (empty reconciled set + scope pinned to the wrapper's routeId: reconcile
# deletes only rows matching the scope, so consumer-declared extra routes
# are untouchable; apply ONCE, then remove - leaving an empty reconciled
# set in place also forbids any future non-plan MtaRoute). The stale
# strategy singleton needs its `route` field reset to the direct-MX
# default once (admin CLI, or an update-op singleton with the default
# expression). A guarded wrapper-automated path (opted-in empty reconciled
# set + default-strategy update when `relay = null`) is DESIGNED, not
# implemented (2026-10-31 evaluation, TODO row): it is a public option
# surface + behavior change that wants its own VM proof - see the
# "0.16-born wrapper options" backlog row.
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

  inherit (cfg) deliverabilityChecks;

  # Single-source probe derivation (host mode unit, vantage package, VM
  # test manual runs all import the same file - modules/deliverability-probe-bin.nix).
  deliverabilityProbe = import ./deliverability-probe-bin.nix {inherit pkgs;};

  # /var/lib home of the probe's report.json / metrics.prom / history/
  # (StateDirectory basis - systemd creates and chowns it).
  probeStateDir = "/var/lib/mail-deliverability-probe";
  canaryCredential = "/run/credentials/mail-deliverability-probe.service/canary-password";

  probeArgs =
    [
      "--host"
      (lib.escapeShellArg cfg.hostname)
      "--domains"
      (lib.escapeShellArg (lib.concatStringsSep "," deliverabilityChecks.domains))
      "--ports"
      (lib.escapeShellArg (lib.concatStringsSep "," (map toString deliverabilityChecks.ports)))
      "--tls-verify"
      deliverabilityChecks.tlsVerification
      "--cert-warn-days"
      (toString deliverabilityChecks.certWarnDays)
      "--slo-seconds"
      (toString deliverabilityChecks.sloSeconds)
      "--json-out"
      "${probeStateDir}/report.json"
      "--history-dir"
      "${probeStateDir}/history"
      "--history-keep"
      (toString deliverabilityChecks.historyKeep)
      "--prom-out"
      "${probeStateDir}/metrics.prom"
    ]
    ++ lib.optionals (deliverabilityChecks.resolver != null) [
      "--resolver"
      (lib.escapeShellArg deliverabilityChecks.resolver)
    ]
    ++ lib.optionals (deliverabilityChecks.dkimSelectors != []) [
      "--selectors"
      (lib.escapeShellArg (lib.concatStringsSep "," deliverabilityChecks.dkimSelectors))
    ]
    ++ lib.optionals (deliverabilityChecks.dnsblZones != []) [
      "--dnsbl-zones"
      (lib.escapeShellArg (lib.concatStringsSep "," deliverabilityChecks.dnsblZones))
    ]
    ++ lib.optionals (deliverabilityChecks.ipAddresses != []) [
      "--ips"
      (lib.escapeShellArg (lib.concatStringsSep "," deliverabilityChecks.ipAddresses))
    ]
    ++ lib.optionals (deliverabilityChecks.canary.address != null) [
      "--canary-address"
      (lib.escapeShellArg deliverabilityChecks.canary.address)
      "--canary-password-file"
      (lib.escapeShellArg canaryCredential)
    ];
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
        pair. RETIRING (null) does NOT retire the store objects - read the
        "RETIRING `relay`" note in this file's header for the one-shot
        consumer remedy (reconcile-destroy pattern).
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

    deliverabilityChecks = {
      enable = lib.mkEnableOption ''
        continuous deliverability probes (systemd timer): DNS
        (MX/SPF/DMARC/DKIM), DNSBL listing, transport (25/465/587/993 TLS),
        certificate expiry, and an optional round-trip canary. EMISSION
        ONLY - exit code, journal, /var/lib report JSON + Prometheus
        textfile; alert ROUTING (push/SigNoz/Gatus) stays on the consumer
        host (docs/MONITORING.md "Routing table": alerts never ride the
        mail stack they watch, and the monitor itself is dead-man'd via
        mail_deliverability_probe_timestamp_seconds staleness).
      '';

      frequency = lib.mkOption {
        type = lib.types.str;
        default = "*:0/15";
        description = ''
          systemd OnCalendar expression for the probe timer (default:
          every 15 minutes - the MONITORING.md section 6 canary cadence).
        '';
      };

      sloSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 600;
        description = "Round-trip canary delivery SLO in seconds (breach = CRITICAL).";
      };

      domains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [cfg.hostname];
        description = ''
          Mail domains checked for MX/SPF/DMARC/DKIM records. Defaults to
          the provisioned Domain (= hostname). Add the bare organization
          domain when mail addresses live under it.
        '';
      };

      dkimSelectors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["rs" "ed"];
        description = "DKIM selectors whose `_domainkey` TXT records are verified (empty = skip).";
      };

      dnsblZones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["zen.spamhaus.org"];
        description = ''
          DNSBL zones queried for each outbound IP (empty = skip; a real
          listing is CRITICAL). Off by default like every network-DNS
          feature here: Spamhaus refuses resolver-forwarded queries
          (127.255.255.x answers are classified WARNING, never "listed"),
          so only enable this where the host resolves recursively itself
          (a VPS with provider resolvers qualifies).
        '';
      };

      ipAddresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Outbound IPv4 addresses for PTR/DNSBL checks (empty = resolve from hostname).";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [25 465 587 993];
        description = "Listener ports probed for transport/TLS health (subset of 25/465/587/993).";
      };

      canary = {
        address = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "canary@example.com";
          description = ''
            Existing mailbox the round-trip canary sends to and reads from
            (submit on 587 as this account, assert IMAPS arrival within
            sloSeconds). The wrapper does NOT provision this account
            (plan-borne passwords would be store-world-readable - the C44
            doctrine); provision it via services.stalwart.provision or pick
            an existing one.
          '';
        };
        secretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            File with the canary account password (sops-rendered path on
            real hosts). Fed through systemd LoadCredential - never lands
            in the Nix store. Set together with address.
          '';
        };
      };

      tlsVerification = lib.mkOption {
        type = lib.types.enum ["opportunistic" "required"];
        default = "opportunistic";
        description = ''
          opportunistic (default): untrusted certificates WARN - the
          self-signed bootstrap tier still gets probed. required: they
          FAIL - set this together with certificate.mode = acme/manual.
        '';
      };

      certWarnDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "Warn when the served certificate expires within this many days.";
      };

      resolver = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.0.0.1";
        description = "DNS server for the probe's dig lookups (null = system resolver).";
      };

      historyKeep = lib.mkOption {
        type = lib.types.ints.positive;
        default = 48;
        description = "Timestamped report copies kept in /var/lib/mail-deliverability-probe/history.";
      };
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
      ]
      ++ lib.optionals deliverabilityChecks.enable [
        {
          assertion = (deliverabilityChecks.canary.address == null) == (deliverabilityChecks.canary.secretFile == null);
          message = "services.mail-server.deliverabilityChecks.canary: set address AND secretFile together (or neither) - a canary without credentials (or vice versa) cannot run the round-trip probe.";
        }
        {
          assertion = deliverabilityChecks.canary.address == null || lib.hasInfix "@" deliverabilityChecks.canary.address;
          message = "services.mail-server.deliverabilityChecks.canary.address must be a full address (got \"${toString deliverabilityChecks.canary.address}\") - 0.16 SMTP AUTH and IMAP LOGIN both resolve the synthesized name@domain form.";
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

    # x86-64-v2 runtime preflight (owner verdict 2026-10-28, "handle now"):
    # stalwart_0_16 >= 0.16.26 requires x86-64-v2 on x86_64 and dies with a
    # bare SIGILL on older silicon. VM nodes are covered structurally
    # (tests/common.nix v2CpuPatches at TEST level); REAL hosts (pbx,
    # evo-x2, the VPS - anything rebuilding after the fe132422 pin advance)
    # get this check at BOOT, before the binary ever executes. Lives HERE
    # (upstream) so every consumer inherits it: SystemNix's wrapper module,
    # pbx's direct import, the demo. aarch64 skips (no v2 concept). Flag
    # set = the glibc x86-64-v2 baseline; pure-bash (no unit-PATH traps -
    # see CONTRIBUTING on unit-script PATH).
    systemd = {
      services.stalwart-cpu-preflight = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
        description = "Verify x86-64-v2 CPU features before Stalwart (0.16 requirement)";
        wantedBy = ["multi-user.target"];
        before = ["${stalwartUnit}.service"];
        requiredBy = ["${stalwartUnit}.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.writeShellScript "stalwart-cpu-preflight" ''
            flags=""
            while IFS= read -r line; do
              case "$line" in
                flags*) flags="$line"; break ;;
              esac
            done < /proc/cpuinfo
            missing=""
            for f in cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3; do
              case " $flags " in
                *" $f "*) ;;
                *) missing="$missing $f" ;;
              esac
            done
            # SSE3 is named "pni" in /proc/cpuinfo (the kernel never emits a
            # standalone "sse3" token - the substring only ever appears inside
            # "ssse3"; caught live on the demo VM, 2026-10-28). Accept either.
            case " $flags " in
              *" pni "*|*" sse3 "*) ;;
              *) missing="$missing sse3(pni)" ;;
            esac
            if [ -n "$missing" ]; then
              echo "stalwart-cpu-preflight: CPU lacks x86-64-v2 flags:$missing" >&2
              echo "  Stalwart 0.16.26+ (x86_64 builds) requires x86-64-v2 and would SIGILL at start." >&2
              echo "  This host cannot run the deployed mail stack - halt the migration here." >&2
              exit 1
            fi
          ''}";
        };
      };

      # Continuous deliverability probes (owner request 2026-10-30): a
      # oneshot service + timer running the shared probe derivation. EMISSION
      # ONLY by doctrine - no OnFailure here: SystemNix's onFailure layer
      # (Discord/ntfy push -> desktop) keys off the unit NAME
      # mail-deliverability-probe.service and its non-zero exit; SigNoz
      # scrapes the textfile gauges; Gatus covers the external TCP/TLS view
      # (docs/MONITORING.md owns the three wiring specs). The unit NEVER
      # blocks boot or stalwart: it is ordered after, wanted by nobody but
      # its timer. One `systemd` block for every wrapper unit (statix [20]
      # collapse-all-the-way-down doctrine).
      services.mail-deliverability-probe = lib.mkIf deliverabilityChecks.enable {
        description = "Deliverability probe (DNS/DNSBL/transport/cert/canary; report + Prometheus textfile)";
        after = ["network-online.target" "${stalwartUnit}.service" "stalwart-provision.service"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          StateDirectory = "mail-deliverability-probe";
          LoadCredential =
            lib.optionals (deliverabilityChecks.canary.secretFile != null)
            ["canary-password:${toString deliverabilityChecks.canary.secretFile}"];
          # dig + openssl live on the probe wrapper's own PATH; this PATH is
          # belt-and-suspenders for the python subprocess lookups.
          Environment = ''PATH="${lib.makeBinPath [pkgs.dnsutils pkgs.openssl]}"'';
          ExecStart = "${deliverabilityProbe}/bin/deliverability-probe ${lib.concatStringsSep " " probeArgs}";
          # The parsedmarc wrapper's hardening set, mirrored (the unit writes
          # nothing outside its StateDirectory, which ProtectSystem=strict +
          # StateDirectory auto-whitelist covers).
          ProtectSystem = "strict";
          PrivateTmp = true;
          NoNewPrivileges = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          CapabilityBoundingSet = "";
        };
      };

      timers.mail-deliverability-probe = lib.mkIf deliverabilityChecks.enable {
        description = "Run the deliverability probe continuously";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = deliverabilityChecks.frequency;
          Persistent = true;
          RandomizedDelaySec = 120;
        };
      };
    };

    services.stalwart = {
      enable = true;
      # The 0.16 package attr; pkgs.stalwart is still the 0.15 line at this
      # pin (and warns loudly if used with this module).
      package = pkgs.stalwart_0_16;
      # 0.16 fact (binary-proven 2026-10-17): the config file carries ONLY
      # the store backend — server.listener/tracer/hostname keys are
      # SILENTLY IGNORED, and listeners live exclusively in the datastore
      # (NetworkListener plan objects; on a virgin store the built-in
      # default set binds, which is smtp 25 + http 8080 serving the SPA
      # for every path). The management httpBind is therefore plan-only,
      # which is why a non-8080 httpBind BOOTSTRAPS through the built-in
      # endpoint: the provision unit probes cfg.url and then the built-in
      # 127.0.0.1:8080, applies against whichever answered, restarts
      # stalwart so the plan's listeners bind, and verifies cfg.url
      # (provision.nix applyScript/restartAndVerify). That closes the
      # 2026-10-17 pbx 43-min self-deadlock wedge (nix-email#4) and makes
      # "listeners never activated" fail the unit loudly; the
      # stalwart-bind-e2e check pins the non-default-bind class.
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
                  # REQUIRED server-side (0.16 apply: "defaultDomainId:
                  # required", VM transcript 2026-10-16) - points at the
                  # wrapper Domain object defined below.
                  defaultDomainId = "#${wrapperDomainId}";
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
                # 0.16 renders set-typed fields (bind, SAN sets) as JSON
                # MAPS on the plan wire; the lua sorter normalizes these
                # Nix lists into that shape (binary-proven 2026-10-17:
                # a hand-added LIST bind dies invalidPatch).
                #
                # STATIC EXTRAS MERGE (2026-10-17): 0.16 silently ignores
                # config-file server.listener keys (only the store backend
                # survives in the TOML), so a consumer's
                # services.stalwart.settings.server.listener.<name>
                # addition - the documented 0.15 extension surface - was
                # dropped WITHOUT trace. Extras are merged into the
                # reconcile set as plan objects instead; the wrapper's own
                # five ids win on collision (REPLACING a wrapper-owned
                # listener stays a mkForce move, README "0.16 provisioning").
                # Shape mapping: static { bind = [...]; protocol; tls.implicit }
                # -> plan { name; protocol; bind; tlsImplicit }.
                # Binary-proven end-to-end (pbx pop3 995 listener,
                # 2026-10-17): reconcile accepts the merged object and the
                # restarted server binds it (implicit-TLS POP3 banner).
                objects =
                  (lib.mapAttrs
                    (name: listener: {
                      inherit name;
                      inherit (listener) protocol bind;
                      tlsImplicit = listener.tls.implicit or false;
                    })
                    (config.services.stalwart.settings.server.listener or {}))
                  // {
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
              MtaInboundThrottle = {
                # match ["description"]: MtaInboundThrottle has NO name
                # field; the server's implicit upsert match key for this
                # type is `description` and it refuses the op when the
                # field is missing ("match property `description` is
                # missing", VM transcript 2026-10-16). Carrying the field
                # makes re-applies update instead of value-match.
                match = ["description"];
                objects.${cfg.rateLimits.id} = {
                  description = cfg.rateLimits.id;
                  enable = true;
                  key = map (k: throttleKeyMap.${k}) cfg.rateLimits.keys;
                  rate = parseRate cfg.rateLimits.rate;
                };
              };
            }
          ]
          # ALWAYS reconciled (not optionals): HISTORICAL ROOT (0.16.22,
          # VM transcripts 2026-10-16, docs/status/2026-10-16_20-48_*):
          # the binary SHIPPED 18 default SpamDnsblServer rows whose tag
          # expressions use an operator ("bit_and") its own parser
          # rejected - every apply's reload validation FAILED on them and
          # the core never swapped (provisioned listeners never
          # activate). 0.16.23 ADDED bit_and, so on the 0.16.26 pin
          # (since 2026-10-28) the defaults no longer break validation -
          # but the reconcile posture STAYS: it mechanizes the wrapper's
          # long-standing "DNSBL off by default" posture (DNS-less E2E
          # lesson), and 0.16.24 made upstream rule updates INSERT-ONLY
          # for existing installs ("upstream changes to existing rules,
          # DNSBL servers, HTTP lookups ... never reach an existing
          # installation") - only a reconciled declarative set converges.
          # Consumers merging their own servers into this set keep them;
          # reconcile deletes only rows outside the plan.
          ++ [
            {
              SpamDnsblServer = {
                reconcile = true;
                match = ["name"];
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
              # subjectAlternativeNames is the ONLY filter property of
              # Certificate AND is server-set (derived from the PEM) in
              # 0.16.26: an upsert with no explicit match demands the
              # implicit filter key in the object body and dies with
              # "match property `subjectAlternativeNames` is missing from
              # the object body" (binary-proven 2026-10-17 on a virgin
              # store; the VM e2es never caught it - they run self-signed
              # mode, which provisions no Certificate object at all).
              # Carrying match + the SAN list (the lua sorter validates
              # set-typed fields as unique arrays; the server treats the
              # entry as a MATCH KEY, not a write - server-set fields are
              # rejected as writes) makes the first apply create and
              # re-applies UPDATE in place: the cert-rotation story.
              Certificate = {
                match = ["subjectAlternativeNames"];
                objects.${cfg.certificate.manual.id} = {
                  certificate."@type" = "File";
                  certificate.filePath = credentialPath "mail-server-certificate";
                  privateKey."@type" = "File";
                  privateKey.filePath = credentialPath "mail-server-certificate-key";
                  subjectAlternativeNames = [cfg.hostname];
                };
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
