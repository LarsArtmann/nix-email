# perSystem package: parsedmarc 11.2.1, AHEAD of nixpkgs (owner decision
# 2026-11-05, "all my tech latest"; SECURITY fix GHSA-3588-2mr7-vrcm).
# The pin (fe132422) ships 11.0.2 and nixpkgs master 11.0.4. Unlike the
# stalwart_1_0 case there is NO store-migration boundary - parsedmarc is
# a stateless parser/poller - so the wrapper DEFAULT flips to this
# closure (modules/dmarc-monitor.nix services.dmarc-monitor.package);
# the attr name matches nixpkgs exactly, so the pin advance that ships
# parsedmarc >= 11.2.1 deletes pkgs/parsedmarc/ wholesale with zero
# consumer churn.
{
  perSystem = {pkgs, ...}: {
    packages.parsedmarc = import ../pkgs/parsedmarc {inherit pkgs;};
  };
}
