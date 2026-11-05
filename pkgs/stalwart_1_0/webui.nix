# VENDORED from NixOS/nixpkgs master pkgs/by-name/st/stalwart_1_0/webui.nix
# at rev fb5c4451d5cf2f886dd2ef8c92704001a591a454 (fetched 2026-11-05,
# packaged there as webui 2.0.0). Local deltas ONLY: version 2.0.0 ->
# 2.0.5 (upstream latest, 2026-11-05), the `stalwart_1_0` meta-maintainers
# argument dropped, and update-script machinery removed.
{
  lib,
  buildNpmPackage,
  zip,
  fetchFromGitHub,
}:
buildNpmPackage (finalAttrs: {
  pname = "webui";
  version = "2.0.5";

  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "webui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3kOGg3RGSJeGK4/hX/yxSPcpOs7VhyYCtC7HwuKlk/U=";
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  __structuredAttrs = true;

  env = {
    # https://github.com/stalwartlabs/webui/tree/main#environment-variables
    # https://github.com/stalwartlabs/webui/blob/main/.env.development
    VITE_API_BASE_URL = "";
  };

  nativeBuildInputs = [ zip ];
  preBuild = ''
    rm .env.development
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cd dist
    zip -r $out/webui.zip *
    cd ..
    runHook postInstall
  '';

  meta = {
    description = "Stalwart WebUI";
    longDescription = ''
      Stalwart WebUI is schema-driven single-page application for administering Stalwart.

      After authentication the panel fetches a JSON schema from the server and dynamically
      generates all forms, lists, navigation, and layouts from that schema. Nothing is hardcoded.
    '';
    homepage = "https://github.com/stalwartlabs/webui";
    changelog = "https://github.com/stalwartlabs/webui/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.OR [
      lib.licenses.agpl3Only
      {
        fullName = "Stalwart Enterprise License 2.0 (SELv2) Agreement";
        url = "https://github.com/stalwartlabs/webui/blob/main/LICENSES/LicenseRef-SEL.txt";
        free = false;
        redistributable = false;
      }
    ];
  };
})
