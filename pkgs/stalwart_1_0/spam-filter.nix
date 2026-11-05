# VENDORED from NixOS/nixpkgs master pkgs/by-name/st/stalwart_1_0/spam-filter.nix
# at rev fb5c4451d5cf2f886dd2ef8c92704001a591a454 (fetched 2026-11-05,
# packaged there as spam-filter 3.0.3). Local deltas ONLY: version
# 3.0.3 -> 3.0.4 (upstream latest, 2026-11-01), the `stalwart_1_0`
# meta-maintainers argument dropped, update-script machinery removed,
# and `passthru.resource` added: the vendored NixOS module's
# spam-filter seam consumes `cfg.package.spam-filter.resource or
# "<out>/spam-filter.toml"` so the 1.x subpackage (json.gz payload)
# and the 0.16 pin's subpackage (toml payload) both resolve without
# version-string matching in the module.
{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  python3,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "spam-filter";
  version = "3.0.4";

  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "spam-filter";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nfhbbUrhuEWFfMm/MwSW4jc1GZ5fdJQxK6S8lLTnrpE=";
  };

  __structuredAttrs = true;

  nativeBuildInputs = [ python3 ];

  buildPhase = ''
    runHook preBuild
    python3 generate_rules_json.py
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp spam-filter-rules.json.gz $out
    runHook postInstall
  '';

  passthru = {
    resource = "${finalAttrs.finalPackage}/spam-filter-rules.json.gz";
  };

  meta = {
    description = "Spam filter module for the Stalwart server";
    homepage = "https://github.com/stalwartlabs/spam-filter";
    changelog = "https://github.com/stalwartlabs/spam-filter/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license =
      with lib.licenses;
      OR [
        mit
        asl20
      ];
  };
})
