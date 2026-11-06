# The full ahead-of-nixpkgs parsedmarc closure, assembled in ONE place:
# parsedmarc 11.2.1 with the vendored mailsuite 2.3.4 injected (parsedmarc
# floors mailsuite >= 2.3.4; the pin ships 2.3.2). The wrapper module
# (modules/dmarc-monitor.nix) defaults services.dmarc-monitor.package to
# this closure, and flake-modules/parsedmarc-package.nix exposes it as
# packages.parsedmarc - both import THIS file so there is exactly one
# definition of what "the deployed parsedmarc" is. When the pin advance
# ships parsedmarc >= 11.2.1 and mailsuite >= 2.3.4, delete this
# directory and point the seam back at pkgs.parsedmarc (zero consumer
# churn; same retirement doctrine as pkgs/stalwart_1_0).
{pkgs}:
pkgs.python3.pkgs.callPackage ./package.nix {
  mailsuite = pkgs.python3.pkgs.callPackage ./mailsuite.nix {};
}
