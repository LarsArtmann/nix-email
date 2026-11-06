# Vendored mailsuite 2.3.4, AHEAD of nixpkgs (owner decision 2026-11-05,
# "all my tech latest"). The fe132422 pin ships 2.3.2; parsedmarc 11.2.x
# floors mailsuite >= 2.3.4, and 2.3.4 itself carries two security fixes
# the deployed dmarc-monitor wants:
#   - GHSA-2x4j-7g3q-wr6f (affects <= 2.3.3): with starttls=None (the
#     default) a plain-text connection that does not advertise STARTTLS
#     now REFUSES to authenticate instead of leaking credentials
#     (reported to parsedmarc as GHSA-3588-2mr7-vrcm);
#   - GHSA-9jx3-p8wm-g8vw (affects 2.0.0 - 2.3.2): a poison message in a
#     Maildir (unparseable header / deep nesting) could never be moved
#     out of the way - directly relevant to the dmarc localMail mode,
#     which watches a Maildir inside postfix's spool.
# Dependencies re-derived from 2.3.4's own pyproject.toml (fetched
# 2026-11-06), NOT copied from the nixpkgs-master expression (2.3.2):
# authres cryptography dkimpy dnspython expiringdict(==1.2.2) html2text
# IMAPClient(>=4.0.0) mail-parser(>=4.6.2) publicsuffix2. The pin
# satisfies every floor (imapclient 4.1.0, mail-parser 4.8.0,
# cryptography 50.0.0, expiringdict 1.2.2 - evaluated 2026-11-06). The
# gmail/msgraph optional-dependencies from the master expression are
# dropped: parsedmarc 11.2.x rides the BASE mailsuite (its pyproject:
# "the base mailsuite supplies IMAP and Maildir connections"), and this
# repo's dmarc-monitor never configures those backends. When the pin
# advance ships mailsuite >= 2.3.4, delete this file and drop the
# override argument in default.nix.
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  # dependencies
  authres,
  cryptography,
  dkimpy,
  dnspython,
  expiringdict,
  html2text,
  imapclient,
  mail-parser,
  publicsuffix2,
}:
buildPythonPackage (finalAttrs: {
  pname = "mailsuite";
  version = "2.3.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "seanthegeek";
    repo = "mailsuite";
    tag = finalAttrs.version;
    hash = "sha256-qjpDBMZY0VJGUHTwfbn6MMZ5q82njHBqza2OkEEoDdY=";
  };

  build-system = [hatchling];

  # Upstream's tests exercise live DNS/network round-trips; this repo's
  # verification is the parsedmarc-e2e VM battery (parsedmarc drags
  # mailsuite through real IMAP + Maildir paths there), per the
  # VM-E2E-for-behavior doctrine.
  doCheck = false;

  dependencies = [
    authres
    cryptography
    dkimpy
    dnspython
    expiringdict
    html2text
    imapclient
    mail-parser
    publicsuffix2
  ];

  pythonImportsCheck = ["mailsuite"];

  meta = {
    description = "Python package to simplify receiving, parsing, and sending email";
    homepage = "https://seanthegeek.github.io/mailsuite/";
    changelog = "https://github.com/seanthegeek/mailsuite/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.asl20;
  };
})
