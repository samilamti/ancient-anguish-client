---
name: apple-entitlements
description: Add or adjust macOS sandbox entitlements / iOS capabilities when a new feature needs platform permissions. Walks through the plist + entitlements edits, provisioning profile check, and local smoke build. Usage: /apple-entitlements
---

# Apple Entitlements Adjustment

When a new feature needs a platform permission (network, Keychain, file scope, StoreKit, push, camera, etc.) on iOS or macOS, update the entitlement/plist files in lock-step and verify locally before a CI build.

## When to invoke

- Adding anything that calls iCloud, Keychain, push notifications, StoreKit, HealthKit, Camera, Microphone, Photos, Contacts, Calendar, Location, Bluetooth, NFC, local networking, background modes, or expanded file access.
- App Review rejected a build citing a missing `NSUsageDescription` or mismatched entitlement.
- Moving code from debug-only (`DebugProfile.entitlements` permissive) to release (`Release.entitlements` stricter) and something no longer works.

## Files in play

- `macos/Runner/Release.entitlements` — macOS release sandbox. Currently permits app-sandbox, network.client, user-selected + downloads file scope.
- `macos/Runner/DebugProfile.entitlements` — macOS debug sandbox; usually a superset of Release.
- `ios/Runner/Info.plist` — iOS purpose strings (`NS*UsageDescription`) and declared capabilities.
- `ios/Runner/Runner.entitlements` — iOS entitlements file (may not exist yet; create if needed).
- `ios/Runner.xcodeproj/project.pbxproj` — capability entries (`com.apple.developer.*`). Sami usually edits these through Xcode, but Claude can patch directly with care.
- `AppStore Connect Stuff for Ancient Anguish Client/iOS_App_Store_Distribution.mobileprovision` — provisioning profile. If a new entitlement is added, the profile must be regenerated in the Apple Developer portal and this file replaced. CI will fail otherwise.

## Phase 1: Identify the entitlement

1. Ask Sami which capability is being added, in plain English ("StoreKit", "access ~/Music", "Keychain sharing").
2. Map to the exact Apple keys. Common MUD-client additions:
   | Capability                     | macOS entitlement key                                     | iOS key / Info.plist                                             |
   |--------------------------------|-----------------------------------------------------------|------------------------------------------------------------------|
   | Outbound TCP (MUD server)      | `com.apple.security.network.client`                       | none — allowed by default                                        |
   | Inbound server (listener)      | `com.apple.security.network.server`                       | `NSLocalNetworkUsageDescription` for local-net discovery         |
   | User-chosen file read/write    | `com.apple.security.files.user-selected.read-write`       | none — handled via UIDocumentPicker                              |
   | Downloads folder               | `com.apple.security.files.downloads.read-write`           | n/a                                                              |
   | Microphone                     | `com.apple.security.device.audio-input`                   | `NSMicrophoneUsageDescription`                                   |
   | Camera                         | `com.apple.security.device.camera`                        | `NSCameraUsageDescription`                                       |
   | Keychain sharing               | `keychain-access-groups`                                  | `keychain-access-groups` in Runner.entitlements                  |
   | StoreKit / IAP                 | (none — default sandbox is fine)                          | (capability added in Xcode under "In-App Purchase")              |
   | Associated domains             | `com.apple.developer.associated-domains`                  | same, in Runner.entitlements                                     |
   | Background audio               | `com.apple.security.device.audio-input` (if capturing)    | `UIBackgroundModes` → `audio`                                    |
3. If uncertain, cite the Apple docs URL and let Sami confirm before editing.

## Phase 2: Edit entitlements

1. **macOS release + debug entitlements** — keep them in sync. Add the new key with `<true/>` (or an array value as appropriate):
   ```xml
   <key>com.apple.security.network.server</key>
   <true/>
   ```
   Release.entitlements is the one shipped; DebugProfile.entitlements should be a permissive superset.

2. **iOS Info.plist** — add any `NSXxxUsageDescription` strings. Write user-facing copy, not developer jargon. Example:
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Ancient Anguish discovers MUD servers on your local network.</string>
   ```
   Respect Sami's "don't repeat Ancient Anguish in anguish.org copy" rule — but usage descriptions are fine to mention the product.

3. **iOS Runner.entitlements** — if the file doesn't exist, create it as a minimal plist and add a reference from `project.pbxproj` (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`). Ask Sami before touching the pbxproj directly.

## Phase 3: Provisioning profile

If the new entitlement is App Store-declared (`com.apple.developer.*`), the existing provisioning profile in `AppStore Connect Stuff for Ancient Anguish Client/` no longer covers it.

1. Tell Sami to regenerate the profile at https://developer.apple.com/account/resources/profiles/list (pick the matching App ID → Edit → ensure the new capability is checked → download the new .mobileprovision).
2. Replace the file in `AppStore Connect Stuff for Ancient Anguish Client/` with the fresh download.
3. Entitlements under `com.apple.security.*` (sandbox-only) do NOT require a profile regen.

## Phase 4: Local smoke build

1. `bash scripts/build.sh macos debug` — catches entitlement typos immediately (codesign fails loudly).
2. `bash scripts/run-macos.sh` — launch and exercise the feature. If the new entitlement is wrong, macOS will either refuse the action silently (sandbox deny printed to Console.app) or prompt the user for permission.
3. For iOS: `bash scripts/run-ios-sim.sh` — simulator ignores most entitlements, so also build to a physical device when possible: `flutter build ios --release --no-codesign` then open the IPA in Xcode and run on-device.

## Phase 5: Reviewer-notes impact

If the entitlement is user-visible (new permission prompt, new capability), note it in the current release's `App Store Listings v<version>.md` Reviewer Notes so App Review doesn't reject for undisclosed data collection. Specifically flag:

- What the permission is for, in one sentence.
- Whether any data leaves the device (for network, usually no — the MUD connection IS the data; no analytics).
- Where in the UI the user triggers it.

## Phase 6: Commit

- One commit, message: `Add <entitlement> for <feature>`.
- Include the Info.plist, entitlements files, and any pbxproj / profile changes together so CI doesn't flap.

## Error recovery

- **Codesign fails with "resource fork, Finder information, or similar detritus not allowed"**: unrelated; clean Frameworks with `scripts/ci/fix-framework-symlinks.sh` or `xattr -cr build/`.
- **ITMS-91053 privacy manifest error**: the new entitlement requires a line in `PrivacyInfo.xcprivacy`. Add the corresponding API reason string and redeploy.
- **App Review rejection citing missing purpose string**: add the `NS*UsageDescription`, bump patch, re-submit.
- **New capability not reflected in Xcode**: Xcode caches the provisioning profile. Close Xcode, delete `~/Library/MobileDevice/Provisioning Profiles/`, re-open.

## Critical files

- `macos/Runner/Release.entitlements` + `DebugProfile.entitlements`
- `ios/Runner/Info.plist` + (optional) `ios/Runner/Runner.entitlements`
- `AppStore Connect Stuff for Ancient Anguish Client/iOS_App_Store_Distribution.mobileprovision`
- Current `App Store Listings v<version>.md` for Reviewer Notes updates
