# Mechanization queue: six proposals, priced and routed (2026-11-02 06:55)

Companion to `docs/planning/2026-11-02_06-24_SUPERB-front-door-truth-lane-pareto-plan.md`
(FD12). Each item below is a proposal with a REAL cost measured against this
tree, not an abstract wish. Two of the six landed in this session and say so;
the rest carry a recommendation, because a queue that only lists hopes is how
backlogs rot.

**The rule this queue applies**: a gate that cannot fail is noise, and a gate
that fails on correct prose is a Verschlimmbesserung. Every proposal names
what it would assert and what it would falsely flag.

---

## P1 - `check-readme-frontdoor`: positional invariants for the front door

**What it asserts**: the first ~40 lines of `README.md` contain (a) the H1
title, (b) a `**Try it:**` line naming a runnable command, (c) the status
blockquote with both version anchors, (d) the `## Contents` heading.

**Cost**: ~40 min (python script + `--self-test` + the two registration sites
that AGENTS names: `tests/check-expected.json` and the README check list).

**Value**: prevents the slow erosion the 2026-11-02 session had to undo by
hand - 825 lines of quickstart below the fold, a diary banner at the top.

**Risk of false positives**: real. Positional assertions break on legitimate
rewording; "the pitch must be above the quickstart" is a taste rule, not an
invariant. The anchor lint (FD1) and the version lockstep (FD5) already pin
the parts that carry factual weight.

**Recommendation: do NOT build it as a flake check.** If the front door ever
erodes again, the cheaper instrument is a CONTRIBUTING rule (it exists now:
"Editing the README: it is a front door, not a note pile") plus a human
reading the top 40 lines. Revisit only if a second erosion incident lands.

---

## P2 - pre-commit doc guard instead of pre-push

**What it asserts**: the anchor/Contents lint and the markdown lints run on
the commit that introduces the drift, not at push time.

**Cost**: ~20 min (`.githooks/pre-commit` + `core.hooksPath` already set).

**Value**: earlier feedback for human commits.

**Risk / why it is weak here**: the automated commit daemon bypasses git
hooks entirely (it committed four of this session's files without running
any hook), so the guard would protect only the smaller share of commits. CI
is already the hard gate; the pre-push hook already mirrors it.

**Recommendation: NO** (recorded so it is not re-proposed). If hook coverage
matters, the honest fix is CI, not a second local hook that the daemon
skips.

---

## P3 - weekly drift alarm (scheduled workflow)

**What it asserts**: every Monday, master still passes `nix flake check
--no-build`, `readme-version-lockstep`, the markdown lints, and the
SystemNix contract check; on failure it opens (or comments on) an issue.

**Cost**: ~45 min to write + recurring runner minutes + a new failure surface
that can go red for infrastructure reasons (the GitHub cache-API throttle
class is documented in AGENTS.md).

**Value**: catches rot that no push introduces - a pin drifting under a
`follows`, a GitHub Actions deprecation, a stale README claim after an
external event.

**Risk of false positives**: the infra-throttle class would page for nothing;
the alarm needs the same "classify infra vs real" discipline the session
report already demands, which a cron job cannot apply.

**Recommendation: LOW priority, defer.** The two facts that rot fastest
(versions and anchors) are now machine-checked on every gate run, and the
lockstep with SystemNix is contract-tested in their repo. Revisit after the
next external-event surprise, not before.

---

## P4 - SECURITY.md SLA

**Status: ALREADY SATISFIED, and corrected in this session.** The policy
already carried a 48 h / 72 h / 90 day commitment table. What it did NOT
carry was truth: it claimed "all changes are code-reviewed before merge" and
"automated security scanning runs in CI", while branch protection is
bypassed by the daemon (C18) and `vulnix` is disabled fleet-wide. Both claims
were rewritten to describe the real posture. **No further work queued** -
adding a longer SLA would be inventing a promise nobody measured.

---

## P5 - status-report skill: "what I did NOT verify"

**Status: LANDED** (crush `SKILLS` repo commit `8f01c1f`,
`status-report/SKILL.md`). The format now requires a scope line naming what
was verified (with the command/artifact) and what was not, and why.

**Follow-up worth considering later** (not queued): mirror the same sentence
into `references/section-quality-guide.md`, where the per-section pitfalls
live, so the rule appears in both the checklist and the guide.

---

## P6 - GitHub About text + topics

**Status: DONE, partially no-op.** The About description already described
the project accurately (Stalwart wrapper + parsedmarc monitor, upstream for
SystemNix), so it was left alone. Topics gained `jmap` and `carddav`, which
the stack genuinely serves (probe-pinned in the README) and which were
missing from the discoverability set.

**No follow-up.**

---

## P7 (closed) - scheduled external-link checker

**Verdict: NO-GO**, recorded during the claim-hygiene pass (FD6). The README
carries 16 link-shaped strings across 7 hosts, 9 of them GitHub issues whose
state is re-checked by hand at each docs pass. A lychee workflow would add a
job, a token surface and a flaky third-party dependency to police a set small
enough to read. **Closed.**

---

## Summary table

| Proposal                       | State    | Cost   | Verdict                               |
| ------------------------------ | -------- | ------ | ------------------------------------- |
| P1 front-door positional check | proposed | 40 min | do NOT build (taste rule, brittle)    |
| P2 pre-commit doc guard        | proposed | 20 min | NO (daemon bypasses hooks)            |
| P3 weekly drift alarm          | proposed | 45 min | LOW, defer until an external surprise |
| P4 SECURITY.md SLA             | done     | 20 min | already had one; claims corrected     |
| P5 status-report scope line    | done     | 10 min | landed in the SKILLS repo             |
| P6 GitHub About + topics       | done     | 5 min  | description accurate, topics widened  |
| P7 external-link checker       | closed   | n/a    | NO-GO, recorded                       |
