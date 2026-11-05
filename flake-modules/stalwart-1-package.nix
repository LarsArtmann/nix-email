# perSystem package: Stalwart 1.x, AHEAD of nixpkgs (owner decision
# 2026-11-05, "all my tech latest"). The pin (fe132422) has no
# stalwart_1_0 attr at all, so the expression is vendored under
# pkgs/stalwart_1_0/ (nixpkgs-master shape, provenance in-file) and
# exposed under the SAME attr name nixpkgs uses - when the pin
# advance ships pkgs.stalwart_1_0, this output can switch to the pin's
# (or the directory is deleted and consumers read pkgs.stalwart_1_0
# directly) with zero consumer churn.
#
# The wrapper DEFAULT stays pkgs.stalwart_0_16 (modules/mail-server.nix):
# a 1.x binary cannot run against a 0.16 store (v1.0.0 redesigned the
# database layout and renumbered every id space - migration via
# stalwartlabs/stalwart-migrate is a hard prerequisite; ledger + the
# package.nix doctrine comment own the details). Consumers that HAVE
# migrated override services.stalwart.package with this attr.
{
  perSystem = {pkgs, ...}: {
    packages.stalwart_1_0 = pkgs.callPackage ../pkgs/stalwart_1_0/package.nix {};
  };
}
