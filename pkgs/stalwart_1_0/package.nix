# VENDORED from NixOS/nixpkgs master pkgs/by-name/st/stalwart_1_0/package.nix
# at rev fb5c4451d5cf2f886dd2ef8c92704001a591a454 (fetched 2026-11-05,
# packaged there as `stalwart_1_0` 1.0.0 with NO NixOS module). Local
# deltas ONLY: version 1.0.0 -> 1.0.3 (upstream latest, 2026-11-04),
# update-script machinery dropped (vendored files do not self-update),
# and provenance comments. The expression is otherwise verbatim so a
# future pin advance (pkgs.stalwart_1_0 present at the pin) can delete
# this directory wholesale - the attr name matches on purpose.
#
# DEPLOYMENT DOCTRINE (nix-email, 2026-11-05): this package is the
# stay-current path for the Stalwart 1.x line, AHEAD of nixpkgs by
# owner decision ("all my tech latest"). It does NOT change the
# wrapper default (pkgs.stalwart_0_16 at modules/mail-server.nix) -
# flipping a fleet default is a store-migration event, not a package
# bump: Stalwart 1.0.0 redesigned the database layout and numeric id
# spaces; a 1.x binary CANNOT run against a 0.16 store (must be
# migrated with stalwartlabs/stalwart-migrate first - see
# SCHEMA_CHANGES.md and the README ledger).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  protobuf,
  bzip2,
  openssl,
  sqlite,
  foundationdb,
  zstd,
  stdenv,
  cmake,
  callPackage,
  withFoundationdb ? false,
  stalwartEnterprise ? false,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stalwart" + (lib.optionalString stalwartEnterprise "-enterprise");
  version = "1.0.3";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "stalwart";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4NUb6Peivb5yG4jZSKUSwYijoF4JTvw4+u2uvN4tGqU=";
  };

  cargoHash = "sha256-QOdPdcCa5HxckfMiNkgnkGMuOlRGIfMMylQs7QUGI5Q=";

  # LOCAL DELTA vs nixpkgs master (build-correctness, 2026-11-05): the
  # ROCKSDB_INCLUDE_DIR/ROCKSDB_LIB_DIR env vars are DROPPED. Stalwart
  # 1.x locks `librocksdb-sys 0.19.0+11.8.1` from the stalwartlabs fork
  # (Cargo.lock), whose FFI expects RocksDB 11.8 - linking the pin's
  # nixpkgs rocksdb 10.10.1 fails with `rocksdb_slicetransform_create`
  # arity errors (E0061/E0308, proven this build). Without the env vars
  # librocksdb-sys builds its vendored 11.8.1 via cmake/cc, which is
  # also how upstream ships it. nixpkgs master (stalwart_1_0 = 1.0.0)
  # still links the system 10.10.1 - the 1.0.0 lock pairs with it; the
  # divergence starts at upstream 1.0.1 ("RocksDB: Updated to 11.8.1",
  # v1.0.1 release notes).
  env =
    {
      # https://docs.rs/openssl/latest/openssl/#manual
      OPENSSL_NO_VENDOR = true;
      OPENSSL_DIR = lib.getDev openssl;
      OPENSSL_LIB_DIR = "${lib.getLib openssl}/lib";
      ZSTD_SYS_USE_PKG_CONFIG = true;
    }
    // lib.optionalAttrs
    (stdenv.hostPlatform.isLinux && (stdenv.hostPlatform.isAarch64 || stdenv.hostPlatform.isArmv7))
    {
      # Required to fix Stalwart on ARM systems with 16 KB page size.
      # Using rust-jemalloc-sys causes segmentation faults on x86_64.
      JEMALLOC_SYS_WITH_LG_PAGE = 16;
    };

  depsBuildBuild = [
    pkg-config
    zstd
    cmake # librocksdb-sys (vendored RocksDB 11.8.1) builds via cmake
  ];

  nativeBuildInputs = [
    protobuf
    rustPlatform.bindgenHook
  ];

  buildInputs =
    [
      bzip2
      openssl
      sqlite
      zstd
    ]
    ++ lib.optionals (stdenv.hostPlatform.isLinux && withFoundationdb) [foundationdb];

  # Issue: https://github.com/stalwartlabs/stalwart/issues/1104
  buildNoDefaultFeatures = true;
  buildFeatures =
    [
      "sqlite"
      "postgres"
      "mysql"
      "rocks"
      "s3"
      "redis"
      "azure"
      "nats"
    ]
    ++ lib.optionals withFoundationdb ["foundationdb"]
    ++ lib.optionals stalwartEnterprise ["enterprise"];

  cargoBuildFlags = [
    "-p"
    "stalwart"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags;

  doCheck = false;

  # Upstream keeps its test suites in a private repository since v1.0.0
  # ("Test suites ... are now kept in a private repository", v1.0.0
  # release notes), so the nixpkgs check config would not apply; doCheck
  # is false here instead of carrying the whole skip list.

  postInstall = ''
    mkdir -p $out/etc/stalwart

    mkdir -p $out/lib/systemd/system

    substitute resources/systemd/stalwart-mail.service $out/lib/systemd/system/stalwart.service \
      --replace-fail "__PATH__" "$out"
  '';

  passthru = {
    # NOTE vs nixpkgs: no `inherit rocksdb;` here - the 1.x binary links
    # the librocksdb-sys-vendored 11.8.1, not a system rocksdb, so there
    # is no meaningful system package to expose for backup scripts.
    webui = callPackage ./webui.nix {};
    spam-filter = callPackage ./spam-filter.nix {};
  };

  meta = {
    description = "Secure, modern, all-in-one mail and collaboration server";
    longDescription = ''
      Secure, scalable and fluent in every protocol (IMAP, JMAP, SMTP, CalDAV, CardDAV, WebDAV).
    '';
    homepage = "https://github.com/stalwartlabs/stalwart";
    changelog = "https://github.com/stalwartlabs/stalwart/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license =
      [
        lib.licenses.agpl3Only
      ]
      ++ lib.optionals stalwartEnterprise [
        lib.licenses.stalwart
      ];
    maxSilent = 14400; # 4 hours
    mainProgram = "stalwart";
  };
})
