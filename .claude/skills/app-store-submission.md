---
name: app-store-submission
description: End-to-end App Store submission workflow — listing doc, screenshots, release tag, CI upload monitoring, TestFlight state check. Chains off the `release` skill. Usage: /app-store-submission [version]
---

# App Store Submission

Orchestrate a full App Store / TestFlight submission for iOS and macOS (Android is handled by CI separately). Picks up where the `release` skill finishes — `release` handles commits + tag + push; this skill handles the actual store-facing deliverables.

## Prerequisites

- `release` skill has already run (or will run) and produced a `v<version>` tag on `main`.
- `.asc/issuer_id` or `ASC_ISSUER_ID` is configured. If missing, stop and walk Sami through `/testflight-status` first so the credential file exists.
- A screenshot shot list for this version exists in `App Store Listings v<version>.md` under "Screenshot shot list". If that doc doesn't exist yet, run Phase 1 first.

## Phase 1: Listing document

1. Ask for version if not provided. Strip leading `v`.
2. Check if `App Store Listings v<version>.md` already exists.
3. If it doesn't, invoke `/app-store-listing`. Review the draft with Sami before continuing — the reviewer notes and What's New blocks are the high-risk sections.
4. Confirm the doc is committed (run `git status`). If not, commit it as `Add v<version> store listing`.

## Phase 2: Screenshots

1. **Read the shot list** from the listing doc's "Screenshot shot list" section.
2. **For each row** (device slot × label × seed value):
   - Boot the sim if it's an iOS slot: `bash scripts/run-ios-sim.sh "<device-name>"`.
   - For macOS: `bash scripts/run-macos.sh --dart-define=AA_SUB_SEED=<seed>`.
   - Launch the app with the seed flag. Wait ~5 s for the UI to settle.
   - Capture: `bash scripts/app-store-screenshots.sh <slot> <label>`.
   - Verify the output dimensions match the App Store slot (the script warns via `sips`).
3. **Review with Sami** — show the list of captured files. If any look wrong, redo that slot only. Do NOT commit screenshots until Sami OKs the set.
4. **Commit** the approved screenshots: `git add screenshots/{ios,macos}/<ts>-*` + `Add v<version> App Store screenshots`.

## Phase 3: CI upload monitoring

Assume the `release` skill already tagged and pushed. If not, run it now.

1. `bash scripts/ci-status.sh v<version> --watch` — waits until all platform jobs complete.
2. If the `Release` workflow fails, read the failing job log with `gh run view <id> --log-failed` and diagnose. Common causes: signing cert expired, provisioning profile mismatch, bundle ID drift. Fix, commit, and re-tag with `v<version>.1` (tags are immutable).
3. If the Release workflow succeeds, iOS and macOS IPAs have been uploaded to App Store Connect via `xcrun altool`. Proceed to Phase 4.

## Phase 4: TestFlight processing

Apple needs 5–30 minutes after altool upload to transcode and process the build.

1. `ruby scripts/testflight-status.rb --version <version>` — check state.
2. Poll every few minutes. Expected progression:
   - `processingState: PROCESSING` → `VALID`
   - `externalBuildState: PROCESSING_EXCEPTION` (rare — means Apple rejected the binary)
   - `externalBuildState: WAITING_FOR_BETA_REVIEW` → `IN_BETA_TESTING` (ready for testers)
3. If `processingState` stays `PROCESSING` for >1 hour, flag it — usually it's a missing privacy manifest or an ITMS-9XXX email arrived in Sami's inbox. Check email for ITMS messages.
4. Once `IN_BETA_TESTING`, TestFlight external testers can install. Tell Sami: "Build v<version> is live on TestFlight."

## Phase 5: Submit for review (manual gate)

ASC API can technically submit for review, but the step involves legal attestations — keep this manual.

1. Open https://appstoreconnect.apple.com → Apps → Ancient Anguish → (version row) → Add for Review.
2. Remind Sami to:
   - Paste the "What's New in v<version>" copy from the listing doc into the version What's New field.
   - Paste the Reviewer Notes addendum into App Review Information → Notes.
   - Upload the IAP Review Screenshot from `screenshots/ios/` if Section 4 of the listing doc references new/changed subscriptions.
   - Attach any newly captured App Store screenshots to each device slot.
3. Confirm the Age Rating and Export Compliance answers still match the v6.8.0 listing doc.
4. Hit **Submit for Review**.

## Phase 6: Post-submission

1. Tell Sami the typical review window (24–48 h for a non-IAP update, 48–72 h for an IAP-bearing update).
2. Suggest: "I'll monitor with `ruby scripts/testflight-status.rb --version <version>` when you ping me. Apple emails you on state change."
3. If the build goes `PENDING_DEVELOPER_RELEASE` (manual release mode), remind Sami to release from ASC after approval. If it's phased release, no action needed.

## Error recovery

- **Phase 2 launcher won't boot the sim**: check `xcrun simctl list runtimes`; the iOS 18.6 runtime must be installed for iPhone 14 Plus (see `memory/reference_screenshot_capture.md`).
- **Phase 3 CI Release job shows skipped Android**: expected if `PLAY_SERVICE_ACCOUNT_JSON` isn't set (see `2e58794` — Android signing is conditional on Play secrets).
- **Phase 4 rejection email (ITMS-9XXX)**: do NOT bump the tag. Fix the referenced issue, commit, and re-tag as the next patch version.
- **Phase 5 missing screenshot slot**: ASC will block submission. Re-run Phase 2 for only the missing slot.

## Critical files

- `App Store Listings v<version>.md` — source of truth for this release's copy and shot list.
- `.github/workflows/release.yml` lines 452–461 and 760–769 — canonical altool invocations, mirrored by the ASC API calls in the status script.
- `AppStore Connect Stuff for Ancient Anguish Client/AuthKey_*.p8` — API key; never commit.
- `.asc/issuer_id` — local-only credential file; gitignored.
- `scripts/app-store-screenshots.sh`, `scripts/ci-status.sh`, `scripts/testflight-status.rb` — workhorses for each phase.

## Memory crosslinks

- `memory/ci_apple_signing.md` — cert + keychain nuances, ITMS gotchas.
- `memory/ci_release_pipeline.md` — overall CI flow; complements Phase 3.
- `memory/reference_screenshot_capture.md` — macOS capture gotcha + `AA_SUB_SEED` seed values.
