# VENDORED from NixOS/nixpkgs master pkgs/by-name/st/stalwart-cli/package.nix
# at rev fb5c4451d5cf2f886dd2ef8c92704001a591a454 (fetched 2026-11-05,
# packaged there as stalwart-cli 1.0.14; our pin fe132422 has 1.0.13).
# Local deltas ONLY: the versionCheck install-check dropped (vendored)
# and provenance. Hashes lifted verbatim from the master expression.
#
# WHY this exists (2026-11-05, stalwart-e2e-v1 round 2 transcript): the
# pin's stalwart-cli 1.0.13 cannot parse a Stalwart 1.0.3 server's
# schema - `unknown variant \`sieve\`` (the v1 schema added the `sieve`
# field type, SCHEMA_CHANGES 3.5) - so the provision unit dies before
# applying anything. The wrapper wires this CLI in automatically for
# 1.x binaries (mail-server.nix since1_0). Retire when the pin carries
# >= this version.
{
  lib,
  cacert,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stalwart-cli";
  version = "1.0.14";
  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3SotRkEDIrI3hgYFjAkkKhCZoD/woXreLshBaLr0Y2c=";
  };
  cargoHash = "sha256-/vYb083UVPDZQpDWh16XkMWk+n9081OiV9S1i1om5zQ=";
  __structuredAttrs = true;
  # `Result::unwrap()` on an `Err` value: Network(reqwest::Error { kind: Builder, source: General("No CA certificates were loaded from the system") })
  nativeCheckInputs = [ cacert ];

  meta = {
    description = "Stalwart Command Line Interface";
    longDescription = ''
      A schema-driven command line tool for administering Stalwart Mail and Collaboration Server over its JMAP API.

      The tool fetches the server's schema on first use and derives every command, validation rule, and rendered view from it. The same binary works against any compatible Stalwart deployment without recompilation.
    '';
    homepage = "https://github.com/stalwartlabs/cli";
    changelog = "https://github.com/stalwartlabs/cli/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "stalwart-cli";
  };
})
