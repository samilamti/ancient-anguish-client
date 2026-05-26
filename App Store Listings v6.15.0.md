# Chosen's MUD Client for Ancient Anguish — Store Listings (v6.15.0)

This is the canonical store listing for the **first public release** of the app on the Apple App Store and Mac App Store. It supersedes `App Store Listings v6.7.0.md`, `v6.8.0.md`, `v6.11.0.md`, and `v6.12.0.md`, which documented earlier draft submissions that were withdrawn before approval.

The two existing `versionString = "1.0"` records on App Store Connect (both `REJECTED`, created 2026-04-14) are being **deleted and recreated as `versionString = "6.15.0"`** to match the app's actual maturity. This document drives that recreation — the descriptions, keywords, URLs, and reviewer notes below are pushed via `scripts/asc/reset-v1-and-create-v6_15_0.rb`.

**Apple constraints honored throughout:**
- No `whatsNew` block (Apple 409s the field on a first-version submission).
- No `✦` or other fancy unicode in descriptions — `•` (U+2022) and `—` (em dash) only.
- Description ≤4000 chars, Promotional Text ≤170 chars, Keywords ≤100 chars, Subtitle ≤30 chars.
- `Ancient Anguish` is intentionally absent from the keywords list — Apple ignores keyword duplicates of the app name and subtitle.

---

## 1. Apple App Store — iOS (iPhone + iPad)

**App Name:** `Chosen's MUD Client`
**Subtitle:** `for Ancient Anguish`
**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Primary Category:** Games → Role Playing
**Minimum iOS:** 13.0

### Promotional Text

```
Ancient Anguish — one of the internet's longest-running fantasy worlds — has a new front door. Built from scratch for the AA community, with the realms waiting inside.
```

### Keywords

```
MUD,telnet,LPMud,text RPG,roleplay,fantasy,multiplayer,MMO,terminal,aliases,mudder,ansi
```

### Description

```
A modern client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991 — built for iPhone and iPad.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA — a cockpit that knows how its prompt works, how its areas sound, and how its culture plays.

WHAT'S INSIDE

• A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI 16/256/truecolor rendering with bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy and clickable URLs. Snaps to the bottom on every command you send.

• Tap-to-send links — Data-driven text link rules turn matched MUD output into tappable shortcuts. "The dark door is closed." becomes a tap that sends "open dark door". Edit rules in Settings with a live preview. Display only: nothing fires until you tap.

• Game-state HUD — 30+ configurable elements across vitals, combat (aim, attack, defend, wimpy), experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, poison, alignment, followers, and more). The client rebuilds your prompt and syncs it to the MUD.

• Mobile-first input — Eight-direction D-Pad with a door action, customizable Quick Commands with an icon catalog, and a history chip that re-sends any of your last five commands plus smart counterparts (enter ↔ leave, open ↔ close). Star up to three aliases for one-tap mobile slots; long-press a slot to edit.

• Triggers (Immersions) — Pattern-matched rules that highlight, gag, or play sounds on matching text. Display only — never auto-send. Respects Ancient Anguish's no-bots rule by design.

• Aliases — Short keywords that expand into full commands with $0/$1/$2 variable substitution and ; chaining. Ships with sensible defaults. Recursion-safe.

• Area-based ambient music — The client detects your location from coordinates or room descriptions and crossfades between tracks. Pick area tracks and battle themes from your native Apple Music library, or load your own files.

• Chat, Tells, Party, and Notes — Floating, dockable, resizable social panels. Tabs or independent windows. Autocomplete for recipients. Optionally hidden from the main log so your adventure keeps its thread.

• Themes & accessibility — RPG Dark (the default), Classic Dark, and High Contrast (built for low-vision players). Scalable fonts (8–32 pt), input-line wrap slider, and native VoiceOver support.

PRIVACY

No analytics. No tracking. No ads. No third-party SDKs. Credentials, aliases, triggers, and settings stay on your device. The only network traffic is your single connection to the MUD server — you control the host.

NEW PLAYERS

The MUD is free to play. Create a character, follow the newbie area, and type `newbie hello!` to say hi. The community is famously welcoming.

This is an independent third-party client, developed in coordination with the AA team and promoted on the official Connect page at https://anguish.org/connect.php. The game has been continuously operated by its own team since 1991.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 USD). Purely cosmetic — nothing is gated. Charged to your Apple ID at confirmation. Auto-renews unless cancelled 24h before period end. Manage anytime in Apple ID settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ancient-anguish.duckdns.org/privacy.html

Adventure awaits. See you in the realms.
```

### Reviewer Notes

```
Chosen's MUD Client is a native iOS client for Ancient Anguish, a text-based multiplayer game (MUD) that has been publicly available since 1991 at ancient.anguish.org:2222.

This is the official third-party client for Ancient Anguish. The app is publicly promoted on the game's own Connect page (https://anguish.org/connect.php), and several Ancient Anguish staff members (Tuinn, Bytre, Jerusulum) actively contribute to its development. Written approval from the Ancient Anguish development team is attached under App Review Information → Attachments → "AA Endorsement".

HOW TO REVIEW THE APP
1. Launch the app. The default connection target is ancient.anguish.org:2222 (the live Ancient Anguish MUD).
2. Tap the link icon (top-right) and tap Connect. You will see the live game's login banner.
3. At the login prompt either type `guest` to log in as a read-only spectator without creating a character, or follow the in-game prompts to create a new character (free, no external account required).
4. The newbie area begins immediately after character creation. Typing `newbie hello!` greets the on-duty mentors.

HOW TO REVIEW THE IN-APP PURCHASES
1. From the main screen open Settings → Support Tiers.
2. The Support screen renders, top to bottom: intro card, bordered legal banner ("Before you subscribe: Terms of Use · Privacy Policy"), three tier cards (each with its own inline "Subscribing accepts the Terms of Use · Privacy Policy" line above its Subscribe button), Restore / Manage buttons, and a full auto-renewal disclosure footer with both legal links repeated inline.
3. Every Terms / Privacy link opens in the system browser via url_launcher.
4. The three Support tiers (Small $1.99, Medium $3.99, Large $5.99 monthly) are purely cosmetic. No feature, theme, or content is gated behind any tier. All three live in one subscription group so users can upgrade/downgrade between tiers without cancelling first.

IMPORTANT CLARIFICATIONS
• No account, payment, or external service is required to use the app or complete review. Gameplay content is delivered by the remote MUD server.
• The app itself has no ads, no analytics, no third-party SDKs, and no user tracking.
• iOS camera, microphone, and photo-library usage strings appear in Info.plist only because the file_picker plugin links those symbols at the framework level. The app itself never invokes camera, microphone, or photo-library APIs except when the user explicitly opens the standard system picker.
• The Apple Music picker (Settings → Areas → "Pick area music" / "Pick battle theme") is the standard MPMediaPickerController; it requires the user's explicit tap to open and never reads the library otherwise. Apple Music subscription tracks with no exportable asset are skipped with a visible warning rather than silently dropped.
• The app connects to a single outbound TCP socket — by default ancient.anguish.org:2222, or a host/port the user specifies. No other network connections are made.
• Triggers and Text Link Rules are display-only: they highlight, gag, or convert text into tappable shortcuts. They never auto-send commands to the server, respecting Ancient Anguish's no-bots rule.

CONTACT
For questions during review: https://ancient-anguish.duckdns.org/support.html
Developer email: sami.lamti@gmail.com
```

### Support URLs

- **Support URL:** `https://ancient-anguish.duckdns.org/support.html`
- **Marketing URL:** `https://ancient-anguish.duckdns.org/`
- **Privacy Policy URL:** `https://ancient-anguish.duckdns.org/privacy.html`

### Copyright

```
2026 Sami Xavier Lamti
```

### Release Type

`AFTER_APPROVAL` — auto-release once Apple approves.

---

## 2. Mac App Store (macOS)

**App Name:** `Chosen's MUD Client`
**Subtitle:** `for Ancient Anguish`
**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Primary Category:** `public.app-category.role-playing-games`
**Minimum macOS:** 10.15

### Promotional Text

```
Ancient Anguish — a fantasy world running since 1991 — with a real terminal, dockable Chat and Tells panels, and 30+ configurable HUD elements.
```

### Keywords

```
MUD,telnet,LPMud,text RPG,roleplay,fantasy,multiplayer,MMO,terminal,aliases,mudder,ansi
```

### Description

```
A desktop client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA, designed for macOS from the window controls up. Pin Chat to one edge, Tells to another, keep the main terminal centered, and treat a second display like a wing of the realm.

WHAT'S INSIDE

• A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI 16/256/truecolor with bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy, Shift-click extend, right-click menu, and clickable URLs. Snaps to the bottom on every command you send.

• Tap-to-send links — Data-driven text link rules turn matched MUD output into one-click shortcuts. "The dark door is closed." becomes a click that sends "open dark door". Edit rules in Settings with a live preview. Display only: nothing fires until you click.

• Floating, dockable social windows — Chat, Tells, Party, and Notes as tabs or independent panels. Resizable, positionable, and optionally hidden from the main game log so your adventure keeps its thread. Cmd+1–4 jumps between tabs.

• Game-state HUD — 30+ configurable elements across vitals, combat, experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, poison, alignment, followers, and more). The client rebuilds your prompt string and syncs it to the MUD.

• Triggers (Immersions) — Pattern-matched rules that highlight, gag, or play sounds on matching text. Display only — never auto-send. Respects Ancient Anguish's no-bots rule by design.

• Aliases — Short keywords that expand into full commands with $0/$1/$2 variable substitution and ; chaining. Ships with sensible defaults. Recursion-safe.

• Area-based ambient music — The client detects your location from coordinates or room descriptions and crossfades between tracks. A compact audio bar gives you master volume, mute, and now-playing. Add your own music per area.

• Keyboard-first command input — Up/Down history with prefix-filtered search, Tab autocomplete from recent words, Escape to clear input, and the clipboard shortcuts you'd expect.

• Themes & accessibility — RPG Dark (the default), Classic Dark, and High Contrast (built for low-vision players). Scalable fonts (8–32 pt), input-line wrap slider, and native VoiceOver support.

PRIVACY

No analytics. No tracking. No ads. No third-party SDKs. Credentials, aliases, triggers, and settings stay on your Mac via local Hive storage. The only network traffic is your single outbound connection to the MUD server — you control the host.

NEW PLAYERS

The MUD is free to play. Create a character, follow the newbie area, and type `newbie hello!` to say hi. The community is famously welcoming.

This is an independent third-party client, developed in coordination with the AA team and promoted on the official Connect page at https://anguish.org/connect.php. The game has been continuously operated by its own team since 1991.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 USD). Purely cosmetic — nothing is gated. Charged to your Apple ID at confirmation. Auto-renews unless cancelled 24h before period end. Manage anytime in Apple ID settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ancient-anguish.duckdns.org/privacy.html

Adventure awaits. See you in the realms.
```

### Reviewer Notes

```
Chosen's MUD Client (macOS) is a native desktop client for Ancient Anguish, a text-based multiplayer game (MUD) that has been publicly available since 1991 at ancient.anguish.org:2222.

This is the official third-party client for Ancient Anguish. The app is publicly promoted on the game's own Connect page (https://anguish.org/connect.php), and several Ancient Anguish staff members (Tuinn, Bytre, Jerusulum) actively contribute to its development. Written approval from the Ancient Anguish development team is attached under App Review Information → Attachments → "AA Endorsement".

HOW TO REVIEW THE APP
1. Launch the app. The default connection target is ancient.anguish.org:2222 (the live Ancient Anguish MUD).
2. Click the link icon in the toolbar and click Connect. The live game's login banner will appear.
3. At the login prompt either type `guest` to log in as a read-only spectator without creating a character, or follow the in-game prompts to create a new character (free, no external account required).
4. The newbie area begins immediately after character creation. Typing `newbie hello!` greets the on-duty mentors.

HOW TO REVIEW THE IN-APP PURCHASES
1. From the main screen open Settings → Support Tiers.
2. The Support screen renders, top to bottom: intro card, bordered legal banner ("Before you subscribe: Terms of Use · Privacy Policy"), three tier cards (each with its own inline "Subscribing accepts the Terms of Use · Privacy Policy" line above its Subscribe button), Restore / Manage buttons, and a full auto-renewal disclosure footer with both legal links repeated inline.
3. All subscription UX (upgrade/downgrade, cancel, renew) is handled by the standard StoreKit sheet.
4. The three Support tiers (Small $1.99, Medium $3.99, Large $5.99 monthly) are purely cosmetic. No feature, theme, or content is gated behind any tier. All three live in one subscription group.

IMPORTANT CLARIFICATIONS
• No account, payment, or external service is required to use the app or complete review. Gameplay content is delivered by the remote MUD server.
• The app is sandboxed (com.apple.security.app-sandbox = true); StoreKit runs under the default sandbox with no extra entitlements.
• The app has no ads, no analytics, no third-party SDKs, and no user tracking.
• The app connects to a single outbound TCP socket — by default ancient.anguish.org:2222, or a host/port the user specifies. No other network connections are made.
• Triggers and Text Link Rules are display-only: they highlight, gag, or convert text into tappable shortcuts. They never auto-send commands to the server, respecting Ancient Anguish's no-bots rule.

CONTACT
For questions during review: https://ancient-anguish.duckdns.org/support.html
Developer email: sami.lamti@gmail.com
```

### Support URLs

- **Support URL:** `https://ancient-anguish.duckdns.org/support.html`
- **Marketing URL:** `https://ancient-anguish.duckdns.org/`
- **Privacy Policy URL:** `https://ancient-anguish.duckdns.org/privacy.html`

### Copyright

```
2026 Sami Xavier Lamti
```

### Release Type

`AFTER_APPROVAL`

---

## 3. App Review Contact

| Field             | Value                              |
|-------------------|------------------------------------|
| First name        | Sami                               |
| Last name         | Lamti                              |
| Phone (E.164)     | _(fill from existing record — preserved from the v1.0 review details if present in the snapshot JSON)_ |
| Email             | sami.lamti@gmail.com               |
| Demo account name | guest                              |
| Demo account pw   | _(empty — `guest` is a passwordless read-only login)_ |
| Demo required     | false                              |

---

## 4. In-App Purchases — unchanged from v6.12.0

Subscription group `Support` with three monthly auto-renewing tiers (`pww_small` $1.99, `pww_medium` $3.99, `pww_large` $5.99) already registered in App Store Connect. They survive the version-record delete because they are app-level, not version-level. No changes required in this resubmission.

See `App Store Listings v6.12.0.md` section 4 for the full IAP metadata reference (product IDs, ranks, descriptions, review screenshot path).

---

## 5. Screenshot shot list — v6.15.0

### iPhone 6.5" (APP_IPHONE_65 / 1284×2778) — iPhone 14 Plus simulator

Run `bash scripts/run-ios-sim.sh "iPhone 14 Plus"` then capture with `bash scripts/app-store-screenshots.sh iphone-6.5 <label>` per shot. Name the labels to sort alphabetically into the order Apple shows them:

1. `01-terminal` — connected to AA, RPG Dark theme, login banner visible, status bar shown.
2. `02-hud` — combat round, HP/SP gauges populated, dynamic panels (Combat + Survival) visible.
3. `03-links` — a "The dark door is closed." line rendered as a tappable link in the terminal; finger or pointer hovering above the link.
4. `04-history` — input bar's history sheet open, showing last 5 commands and a smart counterpart (enter ↔ leave).
5. `05-aliases` — D-Pad with three pinned-alias slots populated; bottom of screen.
6. `06-social` — Chat / Tells / Party / Notes tabbed view docked, terminal still visible above.

### iPad 13" (APP_IPAD_PRO_3GEN_129 / 2064×2752) — iPad Pro 13-inch (M4) simulator

Run `bash scripts/run-ios-sim.sh "iPad Pro 13-inch (M4)"` then `bash scripts/app-store-screenshots.sh ipad-13 <label>`:

1. `01-cockpit` — full landscape cockpit: terminal center, Chat docked left, Tells docked right, HUD across top.
2. `02-links` — Settings → Configuration → Text Link Rules editor open, with the live preview showing a matched rule.
3. `03-audio` — area-audio bar visible, now-playing track + Apple Music library picker entry point visible in Areas settings.
4. `04-immersions` — Immersions editor with a regex rule being built and the highlight preview visible.
5. `05-themes` — High Contrast theme active, full-screen.

### macOS (APP_DESKTOP / 2880×1800) — `bash scripts/run-macos.sh` then `bash scripts/app-store-screenshots.sh macos <label>`

1. `01-desktop` — full window with Chat / Tells docked at edges, HUD across the top, RPG Dark.
2. `02-immersions` — Immersions editor with a regex rule and color-highlight preview.
3. `03-custom-theme` — Custom theme palette picker open with user-edited colors.
4. `04-audio` — Area audio bar visible with now-playing track in the bottom bar.
5. `05-classic` — Classic Dark theme, terminal-focused session in progress.

### Capture sequence

```bash
# iPhone 6.5"
./scripts/run-ios-sim.sh "iPhone 14 Plus"
# (in another shell, with the sim booted)
flutter run -d "iPhone 14 Plus" --dart-define=AA_SUB_SEED=hero
# Then for each label, set the app to the right state and capture:
bash scripts/app-store-screenshots.sh iphone-6.5 01-terminal
bash scripts/app-store-screenshots.sh iphone-6.5 02-hud
# ...

# iPad 13"
./scripts/run-ios-sim.sh "iPad Pro 13-inch (M4)"
flutter run -d "iPad Pro 13-inch (M4)" --dart-define=AA_SUB_SEED=hero
bash scripts/app-store-screenshots.sh ipad-13 01-cockpit
# ...

# macOS
bash scripts/run-macos.sh --dart-define=AA_SUB_SEED=hero
bash scripts/app-store-screenshots.sh macos 01-desktop
# ...
```

The driver script reads from `screenshots/ios/`, `screenshots/ipad/`, and `screenshots/macos/`, taking the **most recently captured file per label** (the screenshot tool prefixes a timestamp, so a re-capture supersedes the prior take). Files are uploaded in alphabetical order of label, which is why the labels are zero-padded.

---

## 6. Apple-side things the API cannot touch (verify in ASC web UI before clicking Submit)

These live at the app level, not the version level, so they survived the v1.0 delete — but Sami should confirm each one is in place before submitting:

- **App Privacy nutrition label** — App Information → App Privacy. Should say "Data not collected" (per the actual app behavior; see Reviewer Notes). No API.
- **Age Rating** — App Information → Age Rating. Existing answers from v1.0 carry forward; verify the questionnaire still says "12+" with cartoon-violence + occasional language disclosures. Some attributes are enums vs booleans in non-obvious ways (e.g. `gamblingSimulated` is ENUM with NONE/INFREQUENT/FREQUENT, `healthOrWellnessTopics` is BOOLEAN despite intuition).
- **App Information → Localizable Information → Privacy Policy URL** = `https://ancient-anguish.duckdns.org/privacy.html`.
- **App Information → General Information → Terms of Use URL** = `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`.
- **App Review Information → Attachments → "AA Endorsement"** PDF, sourced from `screenshots/review-response/aa-endorsement.pdf`. The DELETE may not preserve this attachment; re-upload via web UI drag-drop if the version page shows no attachment after the script runs.

---

## 7. Verification checklist

After the driver script's `--apply` completes:

- [ ] Re-run the driver with no flags (pure dry-run). Both 6.15.0 records appear with state `READY_FOR_SUBMISSION` and the latest VALID v6.15.0 build attached.
- [ ] `git status` shows only this listing markdown and `scripts/asc/reset-v1-and-create-v6_15_0.rb` as new; everything else untouched.
- [ ] ASC web UI: open both records, confirm description renders with no invalid-character warning, no truncation at 4000 chars.
- [ ] ASC web UI: confirm screenshots appear in the alphabetical order of their labels (01, 02, 03, ...).
- [ ] ASC web UI: confirm App Privacy + Age Rating + AA Endorsement attachment are all present (see section 6).
- [ ] Click "Add for Review" → "Submit for Review" on each record.
