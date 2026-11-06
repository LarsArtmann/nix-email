# stalwartlabs/stalwart-migrate v1.0.6 (upstream latest 2026-11-05) -
# the OFFICIAL v0.16 -> v1 store migration tool. Not in nixpkgs (no
# expression anywhere in the tree, checked 2026-11-05), so it is
# packaged here from the release tag. This is the hard prerequisite for
# moving any live 0.16 deployment to the vendored stalwart_1_0 binary:
# v1.0.0 redesigned the database layout and renumbered every numeric id
# space (registry objects/properties/permissions/events - raw store
# copies are unsafe), so the store MUST be migrated offline with this
# tool before a 1.x binary may touch it (see README ledger + the
# package.nix doctrine comment in pkgs/stalwart_1_0/).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stalwart-migrate";
  version = "1.0.6";

  nativeBuildInputs = [
    # bindgen (via a locked *-sys crate) needs libclang at build time
    rustPlatform.bindgenHook
  ];

  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "stalwart-migrate";
    tag = "v${finalAttrs.version}";
    hash = "sha256-tOhHKehdoxmmk9oN6BMYYhdPN3NanPnuEjUBsg5UdFI=";
  };

  cargoHash = "sha256-t9t7eWQP+qfeupRkSJgYcq1V+2Xgahh/pEe7te3a96I=";

  # Upstream's own test suite runs against live stores by design; our
  # verification is the VM migration rehearsal (tests/stalwart-migrate
  # pattern), not cargo test.
  doCheck = false;

  meta = {
    description = "Stalwart v1.0.0 migration tool (v0.16 store -> v1)";
    homepage = "https://github.com/stalwartlabs/stalwart-migrate";
    changelog = "https://github.com/stalwartlabs/stalwart-migrate/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    mainProgram = "stalwart-migrate";
  };
})
