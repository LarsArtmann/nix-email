# Webmail (Bulwark) 1.20.0 train - session report, blindspots, closeout

Session: 2026-11-05 ~21:50-22:45 CET. Ask: "webmail got a lot of new
releases, make sure we stay on the latest version with superb nix
support" + the Bulwark releases URL. The webmail turned out to be
Bulwark (C34 non-goal here; consumer-host concern), deployed via
pbx-artmann's host overlay, with nix-email owning the Stalwart-side
pairing doctrine. Two repos touched: pbx-artmann (the bump), nix-email
(the ledger truth-up). Current time at writing: 2026-11-05 22:40 CET.

## Session run (short form)

1. Resolved "webmail" = Bulwark (C34 non-goal, `services.bulwark` on
   the consumer host); the Stalwart webui admin bundle rides the pin
   and is a separate surface.
2. Verified from primary sources: upstream 1.20.0 (2026-11-03),
   nixpkgs bulwark 1.14.2 at our pin AND unstable AND master, open bump
   PR NixOS/nixpkgs#574920 targeting 1.19.1 (+ a module reshape),
   `stalwart_1_0` 1.0.0 packaged with NO module, #552103 (0.16 module)
   still open, stalwart upstream at 1.0.3 with 0.16.x ended at 0.16.27
   (unstable has it; our pin fe132422 has 0.16.26).
3. Found the deployment mechanism: pbx-artmann hosts/pbx/bulwark.nix +
   the bulwark/bulwark-plugins overlay in hosts/pbx/default.nix
   (app was 1.17.2; nixpkgs lags by design there, the overlay is the
   stay-current mechanism).
4. Bumped the overlay to 1.20.0 with a packaging delta nobody had
   caught: 1.19+ pre-builds public/pst-worker.js +
   public/plugin-sandbox-assets/ (NOT committed upstream; the runtime
   reads the sandbox manifest off disk and 503s without it), so the
   buildPhase now runs both scripts before `next build --webpack`.
   nixpkgs' own expression - and #574920's 1.19.1 - would ship a dead
   sandbox.
5. Re-surveyed the extension store (2026-11-01 republish moved all
   ten) and bumped every plugin; external-link-warning 2.0.0 declares
   minAppVersion 1.20.0 in its own manifest, which makes 1.20.0 a
   floor, not a nicety.
6. Contract updated (floor 1.20.0, plugin latest set, msgs), docs
   truth-ups on both repos, all gates green except one pre-existing
   pbx red (audit-all, 3 foreign items).

## a) FULLY DONE

| Item                                        | Proof                                                                                                                                                                                                   |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App overlay 1.17.2 -> 1.20.0 in pbx-artmann | build green, 2m1s Next build, store path bulwark-1.20.0; patch applies at offset 5 (context re-verified byte-identical at the 1.20.0 tag first)                                                         |
| Sandbox + PST pre-steps added to buildPhase | output verified: public/plugin-sandbox-assets/manifest.json (script/style/preload/slotPreload) + public/pst-worker.js (186 KB) in the built closure; /plugin-sandbox routes in the build route table    |
| npm src + deps hashes computed              | zero-hash FOD loop: src sha256-oNTAR2SO..., deps sha256-mcEfKiwb...; both proven by the green build                                                                                                     |
| Plugin resurvey + bump, all ten             | versions + nar hashes from the store bundles; ALL TEN manifests read (external-link-warning 2.0.0/minApp 1.20.0 read at bump time; the other nine read during this report's prep - see d-2)             |
| trustedDomains wiring intact in 2.0.0       | manifest configSchema.trustedDomains present, comma-or-newline semantics unchanged; new lookup backends default OFF                                                                                     |
| Contract floor 1.20.0 + latest set          | nix-email-contract green; bulwark-registry-pin green; nix flake check --all-systems --no-build all green                                                                                                |
| Deployed-config eval                        | bulwark 1.20.0, external-link-warning 2.0.0, calendar-agenda 1.4.5 answered by the evaluated host config                                                                                                |
| Pairing contract verified raw               | bulwarkmail/website docs: "Bulwark needs Stalwart 0.16.6 or newer" verbatim; BULWARK_VERSION = "1.18.0" in src/lib/version.ts with the comment "The first Bulwark release that works with Stalwart 1.0" |
| 1.20.0 config-schema spot check             | autoSsoEnabled + stalwartAdminAccess present in 1.20.0 lib/admin/types.ts (enum values unchanged); filesEnabled still a feature key                                                                     |
| nix-email ledger + watch row + CHANGELOG    | README Bulwark bullet carries the verified pairing contract; TODO_LIST watch row (BLOCKED on #574920); CHANGELOG entry; text gates + nix fmt --check green                                              |
| pbx docs truth-ups                          | runbook 1.20.0 re-verification note; ROADMAP version-footer update note; CHANGELOG webmail-train section                                                                                                |

## b) PARTIALLY DONE

1. Runtime verification is STATIC only: artifacts in the store output
   and a green build, but the new closure has never been booted - no
   local server.js smoke, no /api/health, no served /plugin-sandbox
   200. The switch is proven evaluable, not proven serving.
2. pbx toplevel: full eval battery green, but
   nix build .#nixosConfigurations.pbx...toplevel was NOT run - the
   switch rides eval proof only.
3. pbx docs battery: 6 of 7 gates green; audit-all is RED with 3
   pre-existing foreign unharvested items (2026-09-30 fresh:skip
   markers, 2026-10-12 Woolly Python row, 2026-11-02 M07+ placement
   readback) - none reference this session's work; left alone per the
   parallel-session rule.
4. The vi locale-callback reconciliation: gap CONFIRMED and spec'd,
   fix NOT applied (see c-1 - it is a regression this session
   introduced).
5. Owner legs by design: the switch itself, verify-live webmail arms,
   the deploy-record ledger block - all pending the owner.

## c) NOT STARTED (surfaced by this session)

1. [REGRESSION I INTRODUCED, CONFIRMED, UNFIXED] 1.20.0 ships 30 UI
   locales (vi added; 1.17.2 had 28 - counted in both source trees),
   but the Pocket ID client allowlist stays at 29 callbacks
   (bare + 28). webmail:/vi/auth/callback is unregistered, so a
   Vietnamese-locale browser hits the invalid_redirect_uri first-login
   breaker - the exact class the contract's own msg names. The gate
   CANNOT see it: the invariant pins desired.json's count, not the
   app's locale set. Fix is spec'd: desired.json callbacks 29 -> 30
   (+ vi entry), contract invariant length 29 -> 30 + msg arithmetic
   ("30 = bare + 29 locales"), same commit.
2. Upstream filing (owner-review-gated): nixpkgs' bulwark expression -
   including #574920's 1.19.1 - skips the sandbox/PST pre-steps and
   ships a dead plugin sandbox. Evidence pack exists (503 path,
   manifest read, our fix). verify-before-filing + github-voice apply.
3. Local boot smoke of the new closure before any switch.
4. Full pbx toplevel build.
5. aarch64 build of the new closure (ARM CAX recreate readiness).
6. Store-survey mechanization (script hitting /api/v1/extensions +
   prefetch + diff vs the overlay pins).
7. Upstream-release watch mechanization (releases.atom vs the overlay
   version; red when behind).
8. The stalwart_1_0 track decision (see g-3) - nixpkgs has no 1.0
   module yet; when one lands, the runbook grows a Bulwark-first
   preflight (>= 1.18.0) and a Stalwart-side delta: 1.0 renames
   useXForwarded to clientIpSource/forwardedHops, and Bulwark sends
   X-Forwarded-For on sign-in checks - without it, failed-login bans
   land on the proxy address and block ALL webmail sign-ins (docs
   read this session).
9. nix-email: stale webui-1.0.10 references (vendored module comment +
   README ledger) vs the pin's actual passthru.webui 1.0.11.
10. Post-switch: journal watch for MemoryMax 1G under the 1.20 feature
    surface; the 1.20 branding ?v= keys (upgrade-safe, downgrade
    needs re-upload).

## d) TOTALLY FUCKED UP

1. The 1.18.0 figure was encoded into FOUR files (nix-email README
   ledger, nix-email TODO row, pbx contract msg, pbx CHANGELOG) from
   an AI summarizer's quote of the docs page - the verify-external-claims
   skill was loaded and still slipped. The docs page actually carries a
   TEMPLATE variable, and the summarizer's number was unfalsifiable at
   encode time. CLOSED during this report's prep: the website repo's
   src/lib/version.ts pins BULWARK_VERSION = "1.18.0" ("the first
   Bulwark release that works with Stalwart 1.0"), so the claim is now
   true AND cited - but it spent its first ~90 minutes in three ledgers
   unverified, and the daemon had already committed two of the four.
2. The pbx CHANGELOG bullet "minAppVersion verified per bundle
   manifest" was written when 9 of 10 manifests had NOT been read
   (only the store listing API's minAppVersion field, which is a
   secondary source). CLOSED during report prep: all ten manifests now
   read, every version + minAppVersion matches what was encoded.
   Lesson: a ledger sentence is a claim - the verification must
   predate the sentence.
3. The CA-FOD silent-reuse trap ate a build round: with the old hash
   still pinned, nix skipped the fetch entirely (the content-addressed
   store path already existed, holding the 1.17.2 tree) and the build
   ran 1.17.2 sources under a bulwark-1.20.0 drv name. Only the
   missing build-pst-worker.mjs exposed it. If the old tree had still
   contained that path, the next line of defense was package.json's
   version 1.17.2 vs the new contract floor - defense by luck and by a
   check that happened to exist, not by design. The zero-hash
   placeholder should have been round 0 (the repo's own AGENTS
   documents this FOD trap class).
4. The locale-to-callback coupling was invisible to me for the entire
   bump: I read the 1.20.0 release notes (Vietnamese listed), read the
   contract (which documents the invalid_redirect_uri breaker and pins
   a locale-derived count), and connected neither. The gate stayed
   green over a live sign-in breaker. Worst finding of the session.
5. Mechanics slop: the first prefetch-hash grep captured trailing
   punctuation into the transcript; the first raw-docs URL was a
   guessed path that 404'd (the constructed-URL fabrication class),
   and I still leaned on the summarizer afterward instead of finding
   the raw source immediately.
6. Evidence ordering: I worried about --turbopack vs --webpack
   compatibility from first principles BEFORE reading #574920's
   package.nix diff, which settled it in ten lines. Source-first, not
   reasoning-first.

## e) WHAT WE SHOULD IMPROVE

1. Make quote-verification mechanical: no version number or
   compatibility claim enters a ledger, contract msg, or CHANGELOG
   without a raw-source citation IN THE SAME COMMIT. The skill exists;
   the failure was sequencing, not knowledge.
2. App-bump checklist (the missing discipline): diff the locale set,
   the admin config schema (types.ts), and every locale- or
   schema-derived fleet surface (OIDC callback allowlist, provision
   arms) as a fixed step. The OIDC allowlist is locale-derived and the
   contract pins both sides independently - a split brain by design.
3. Gate the coupling: the callback invariant should carry the locale
   arithmetic against the app (an eval-level assert like
   version >= 1.20.0 implies count >= 30, or an explicit
   locale-count/comment pair), so an app bump cannot outrun the
   allowlist silently. IFD-free options exist; needs a small design
   decision.
4. Boot smoke belongs in the pre-switch ritual for webmail bumps
   (node server.js on a loopback port; /api/health, /plugin-sandbox,
   /pst-worker.js 200s) - the repo has verify-live for post-switch,
   nothing for pre-switch.
5. Zero-hash first for every FOD bump; old hashes in place are a
   silent-reuse hazard, not a discovery tool. Worth a line in AGENTS.
6. Mechanize the two watches (store survey, upstream releases) - the
   manual resurvey class is now the only thing keeping the overlay
   current, and it just took a full session.
7. The contract's "a new store release reds this gate" doctrine only
   fires on re-bundled bytes; new VERSIONS never red anything. Either
   a networked eval check or a cadence gate (survey age > 30 d).
8. Split-brain inventory: the pairing contract (0.16.6 / 1.18.0)
   now lives in four files. Acceptable shape: the nix-email README
   ledger owns the doctrine, everything else points at it with dates -
   the pbx contract msg should reference, not restate, on the next
   edit.
9. Scope discipline held this session (no pin advance, no SystemNix
   edits, no unrelated backlog harvesting) - keep that shape; the
   temptation to also advance to 0.16.27 was correctly declined (no
   webmail gain, SystemNix lockstep cost).

## f) NEXT - prioritized

P0 - this train's residue (the ship-stopper first):

1. Fix the vi callback: pocket-id desired.json callbacks 29 -> 30
   (+ webmail:/vi/auth/callback), contract invariant + msg to match,
   one commit (spec fully derived this session).
2. Boot smoke of bulwark-1.20.0 locally (health + sandbox + pst-worker
   routes).
3. Full pbx toplevel build.
4. Owner switch + verify-live webmail arms + the deploy-record ledger
   block (CHANGELOG tail doctrine).

P1 - ecosystem and upstream:
5. Watch NixOS/nixpkgs#574920; when merged, re-diff nixpkgs' bulwark
against the overlay (its 1.19.1 ships the dead-sandbox bug - the
overlay stays until the pin carries >= 1.20.0 WITH the pre-steps).
6. File the sandbox pre-steps comment on #574920 (owner-review-gated;
verify-before-filing + github-voice; evidence pack from this
session).
7. Watch nixpkgs for a stalwart_1_0 MODULE (none exists); on landing,
open the 1.0 track with the Bulwark-first preflight.
8. nix-email: truth-up the stale webui-1.0.10 references (vendored
module comment, README ledger) to the pin's 1.0.11.
9. nix-email: the 0.16.27 pin-advance decision (trigger conditions
already recorded in the watch row; SystemNix lockstep runbook).
10. Watch bulwark upstream for 1.20.x patch releases (1.20.0 is 2 days
old; the cadence is 2-5 days).

P1 - fleet hardening:
11. Mechanize the store survey (script + gate step).
12. Mechanize the upstream release watch (releases.atom vs overlay).
13. Gate the locale-callback coupling in the contract (design taste -
see e-3).
14. aarch64 build test of the new closure.
15. Post-switch: MemoryMax 1G observation under 1.20 (offline mode +
import + Redis-capable code paths).
16. Decide external-link-warning 2.0.0 link-check backends (g-2).
17. Revisit the removed external-mail-warning function via 1.20's
NATIVE Organisation External-label/confirm controls (owner ask
2026-10-29 predates 1.19's built-ins).
18. AI Assistant 2.2.1 owner review (the standing backlog ask).
19. structuredMailEnabled (booking/parcel cards) posture decision -
reads Authentication-Results; admin-off is available.
20. Wire /api/health/live + /api/health/ready (+ /api/metrics with a
token) into the monitor stack - consumer-side Gatus/SigNoz wiring,
MONITORING.md is nix-email's spec home.
21. Post-switch: check the 1.20 branding ?v= keys survived (upgrade
safe; the downgrade trap is documented).
22. Deploy-record ledger entry after a verified switch (deploy-
freshness baseline).

P2 - docs and process:
23. Harvest or annotate the 3 pre-existing audit-all items to re-green
the pbx docs battery (docs-health pass).
24. Record the zero-hash FOD habit in pbx AGENTS.md (next to the
existing FOD trap note).
25. Record the app-bump checklist (locales, config schema, callback
surfaces) in pbx AGENTS.md - a webmail section if none exists.
26. lessons.md candidate (crush-config, via commit): summarizer-quote-
into-ledger incident + the CA-FOD silent-reuse trap - both
generalize across projects.
27. Split-brain pass: consolidate the pairing contract to ONE
doctrinal home (nix-email ledger) + pointers elsewhere.
28. nix-email demo VM stays webmail-free (non-goal C34 stands) - no
action, recorded so nobody "fixes" it.
29. Next plugin survey: read manifests per bundle FIRST, encode after
(the ordering that was corrected today).
30. On the next app bump: diff .env.example + types.ts for REMOVED
config keys the fleet uses (none today; autoSsoEnabled +
stalwartAdminAccess verified present in 1.20.0).

## g) Questions for the owner (not derivable from any tree)

1. Switch timing: land the webmail closure on pbx as a single-purpose
   switch once the vi callback fix is in, or batch it into the next
   staging train? (The closure is built and gate-green; only the vi
   fix and your timing are missing.)
2. external-link-warning 2.0.0: stay trusted-list-only (all lookups
   default OFF, current posture), or wire one of the new backends -
   your own link-check endpoint (needs a service) or Google Safe
   Browsing (hash-prefix privacy, non-commercial terms)?
3. Stalwart 1.0 track: chase it when nixpkgs ships a 1.0 module (the
   Bulwark-first preflight and the useXForwarded ->
   clientIpSource/forwardedHops rename are now documented), or stay
   0.16.x through the winter?
