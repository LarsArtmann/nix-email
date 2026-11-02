# Security Policy

## Supported Versions

| Version | Supported  |
| ------- | ---------- |
| v0.5.0  | ✅ Current |

Only the latest release receives security fixes. Please update to the latest
version before reporting issues found in older releases.

## Reporting a Vulnerability

Please do **not** open public issues for security problems. Report privately instead:

- **GitHub Security Advisory**: https://github.com/LarsArtmann/nix-email/security/advisories/new

### What to include

- Vulnerability type and severity
- Steps to reproduce
- Potential impact
- Proof of concept (if available)

### Response commitments

| Phase            | Timeline                    |
| ---------------- | --------------------------- |
| Initial response | Within 48 hours             |
| Triage           | Within 72 hours             |
| Disclosure       | Coordinated, within 90 days |

## Security Practices

Honest statement of what is actually wired (2026-11-02):

- **Every change runs the gate**: `nix flake check` (eval contracts + VM
  E2E), the unified formatter check, statix, the python floor and the
  markdown lints. There is no mandatory pull request - an automated commit
  daemon can land on master, and CI alone does not block those pushes
  (branch protection is bypassed by design, tracked as C18). Review
  therefore happens at the gate and in `CHANGELOG.md`, not as a second
  pair of eyes on every commit.
- **No automated vulnerability scanner is wired.** `vulnix` is disabled
  fleet-wide because it crashes updating the retired NVD legacy feed, so
  dependency risk rides the pinned nixpkgs rev (advanced deliberately,
  both repos' locks together) plus Dependabot for GitHub Actions.
  Upstream mail-stack CVEs are tracked by hand in the README's
  verified-facts ledger.
- **Secrets never enter the Nix store**: admin/relay/IMAP passwords are
  systemd credentials or sops-rendered files (see THREAT_MODEL.md).
- Dependencies: nixpkgs is pinned and advanced by the pin-advance runbook;
  GitHub Actions versions are bumped by Dependabot.

---

_Maintained with [securitymd](https://github.com/LarsArtmann/securitymd). Last updated: 2026-10-09._
