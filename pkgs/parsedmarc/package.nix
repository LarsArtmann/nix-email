# Vendored parsedmarc 11.2.1, AHEAD of nixpkgs (owner decision 2026-11-05,
# "all my tech latest"). The fe132422 pin ships 11.0.2 and nixpkgs master
# 11.0.4; 11.2.1 is upstream latest (2026-11-01) and carries the SECURITY
# fix GHSA-3588-2mr7-vrcm (STARTTLS-strip credential leak on the default
# SMTP configuration, affects <= 11.2.0; the fix rides mailsuite 2.3.4's
# refusal to authenticate over plain text - see mailsuite.nix).
#
# 11.2.x RESTRUCTURED the dependency set (upstream issue #883): every
# heavy sink moved from base to EXTRAS, so the nixpkgs-master expression
# (11.0.4, flat base deps incl. dateparser/requests/urllib3/elasticsearch
# /kafka/azure) no longer matches the contract. Dependencies below are
# re-derived from 11.2.1's own pyproject.toml (fetched 2026-11-06):
# dnspython[doh] expiringdict httpx lxml mailsuite maxminddb
# publicsuffixlist python-dateutil tqdm xmltodict PyYAML - notably
# dateparser is GONE (python-dateutil is imported directly at utils.py,
# and arrives here on its own) and requests is GONE from base (only the
# maintainer [build] extra). This wrapper needs only the base install:
# IMAP polling + local JSON/CSV output - no
# elastic/opensearch/kafka/s3/gelf/loganalytics/msgraph/gmail/postgresql.
# The [doh] extra supplies the HTTP client DNS-over-HTTPS needs (httpx +
# httpcore + h2 on dnspython 2.8, the pin's version) - appended below via
# the pin's own optional-dependencies wiring.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  # dependencies
  dnspython,
  expiringdict,
  httpx,
  lxml,
  mailsuite,
  maxminddb,
  publicsuffixlist,
  python-dateutil,
  pyyaml,
  tqdm,
  xmltodict,
}:
buildPythonPackage (finalAttrs: {
  pname = "parsedmarc";
  version = "11.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "domainaware";
    repo = "parsedmarc";
    tag = finalAttrs.version;
    hash = "sha256-3nES8f6vmPYmwBcMqRbfqXOSPDVzQZTrkUloILfzssE=";
  };

  build-system = [hatchling];

  # postPatch carries the nixpkgs-master pyproject rewrite: upstream
  # parks `requires_python` inside [build-system], which is NOT a valid
  # build-system property - the pin's hatchling refuses the build with
  # "Failed to validate `build-system`: Unknown properties:
  # requires_python" (VM-free build transcript 2026-11-06). It is
  # metadata-only (the requires-python range is 3.10-3.15; the pin's
  # python3 3.14.7 is in range regardless). The master postPatch's
  # grafana dashboard output is NOT carried: it is only consumed by the
  # nixpkgs module's grafana provision option, which this wrapper never
  # enables.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requires_python = ">=3.10,<3.15"' ""
  '';

  # Upstream's own suite contacts DNS servers at 1.1.1.1/8.8.8.8 by
  # design; behavior verification here is the parsedmarc-e2e VM battery
  # (IMAP ingestion, fixture parsing, output contracts) per the
  # VM-E2E-for-behavior doctrine.
  doCheck = false;

  dependencies =
    [
      dnspython
      expiringdict
      httpx
      lxml
      mailsuite
      maxminddb
      publicsuffixlist
      python-dateutil
      pyyaml
      tqdm
      xmltodict
    ]
    ++ dnspython.optional-dependencies.doh;

  pythonImportsCheck = ["parsedmarc"];

  meta = {
    description = "Python module and CLI utility for parsing DMARC reports";
    homepage = "https://domainaware.github.io/parsedmarc/";
    changelog = "https://github.com/domainaware/parsedmarc/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "parsedmarc";
  };
})
