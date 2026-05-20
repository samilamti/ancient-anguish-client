# Chosen's MUD Client for Ancient Anguish — Store Listings (v6.12.0)

Paste each block into the matching field in App Store Connect (iOS), App Store Connect (macOS), or Google Play Console. Character counts follow each bounded field.

This document supersedes `App Store Listings v6.11.0.md`. The v6.7.0, v6.8.0, and v6.11.0 archives are kept for reference.

v6.12.0 exists to address Apple's rejection of the v6.11.0 review cycle (submission `5eebb436-9154-4e4e-9f62-d157bc9fcccd`, reviewed 2026-04-24) under **Guideline 3.1.2(c)** (subscription Terms / Privacy disclosure not visible enough at the purchase moment) and **Guideline 4.1(c)** (use of the "Ancient Anguish" brand name without documented approval). The three optional supporter subscriptions themselves are unchanged. See section 7 for the Resolution Center response.

---

## 1. Apple App Store — iOS (iPhone + iPad)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** Games → Role Playing
**Minimum iOS:** 13.0

All previously approved fields — app name, subtitle, promotional text, keywords, age-rating answers, support URLs — carry forward unchanged from v6.7.0. Two fields change below: the App Description and the What's New text.

### Description (≤4000) — iOS

```
A modern client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991 — built for iPhone and iPad.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA. Not a generic terminal with a MUD skin bolted on — a cockpit that knows how AA's prompt works, how its areas sound, and how its culture plays.

WHAT'S INSIDE

• A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI rendering with 16-color, 256-color, and 24-bit truecolor output. Bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy and clickable URLs.

• Game-state HUD — 30+ configurable elements across seven categories: vitals, combat (aim, attack, defend, wimpy), experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, smoke, poison, alignment, followers, and more). Pick what you want; the client rebuilds your prompt and syncs it to the MUD.

• Quick Commands — A customizable row of tap-to-send buttons with an icon catalog and a target picker drawn from recent words. Build your combat loop, a greetings set, or a utility strip and fire them with one tap.

• D-Pad — Eight-direction movement plus up, down, and look, laid out for thumb reach.

• Immersions — Client-side pattern rules that highlight, gag, or play sounds on matching text. Display only — never auto-send. Respects Ancient Anguish's no-bots rule by design.

• Aliases — Short keywords that expand into full commands with $0/$1/$2 variable substitution and ; chaining. Ships with sensible defaults. Recursion-safe.

• Area-based ambient music — The client detects your location from coordinates or room descriptions and crossfades between tracks. Add your own music per area.

• Chat and Tells windows — Floating, dockable, resizable. Tabs or independent panels. Autocomplete for recipients. Optional suppression from the main log so your adventure keeps its thread.

• Four themes — RPG Dark (gold on wood, the default), Classic Dark (green on black), High Contrast (yellow and cyan on black, built for low-vision players), and a fully editable Custom palette.

• Accessibility — Scalable fonts (8–32 pt), input-line wrap slider (0–200 chars), high-contrast theme, and native VoiceOver support.

PRIVACY

No analytics. No tracking. No ads. No third-party SDKs. Your character credentials, aliases, triggers, and settings stay on your device. The only network traffic is your single connection to the MUD server — you control the host.

FOR VETERANS

A real terminal, full ANSI with truecolor, GMCP and MCCP2/3 awareness, 5,000-line scrollback, pattern-matching triggers, aliases with variable substitution, and a configurable prompt that the client syncs for you.

FOR NEW PLAYERS

Ancient Anguish is free to play — always has been. Create a character in-game, follow the newbie area, and type `newbie hello!` to say hi. The community is famously welcoming.

A note: this is an independent third-party client for Ancient Anguish, developed in coordination with the AA team and promoted on the official Connect page at https://anguish.org/connect.php. The game itself has been continuously operated by its own team since 1991; we just built a comfortable doorway.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 — USD). They are purely cosmetic: nothing in the app is gated behind them. Payment is charged to your Apple ID at confirmation of purchase. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ancient-anguish.duckdns.org/privacy.html

Adventure awaits. See you in the realms.
```

### What's New in v6.12.0 (≤4000)

```
v6.12.0 — Stronger legal disclosure on the Support screen.

The Terms of Use and Privacy Policy links now appear inline on every Support tier card, directly above each Subscribe button — in addition to the existing banner above the tier list and the full disclosure footer below it. The optional supporter tiers themselves are unchanged: still purely cosmetic, still nothing gated behind them.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes (for App Review) — addendum for v6.12.0

```
v6.12.0 is a metadata + small-UI response to the v6.11.0 review rejection (submission 5eebb436-9154-4e4e-9f62-d157bc9fcccd, reviewed 2026-04-24).

WHAT CHANGED FOR GUIDELINE 3.1.2(c)
• Each Support tier card now renders an inline legal line — "Subscribing accepts the Terms of Use · Privacy Policy" — directly above its Subscribe button. Both phrases are individually tappable and open Apple's standard EULA and our hosted Privacy Policy in the system browser.
• The existing legal banner directly below the intro card has been promoted to a card-style row with an info icon and "Before you subscribe:" prefix, so it reads as a deliberate disclosure rather than a quiet caption.
• The full auto-renewal disclosure footer (length, price, renewal terms, management path, Terms / Privacy links repeated inline) remains present at the bottom of the same screen.
• Terms of Use URL: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ (Apple's published standard EULA).
• Privacy Policy URL: https://ancient-anguish.duckdns.org/privacy.html

GUIDELINE 4.1(c) — Authorization to use the Ancient Anguish name
This app is the official third-party client for the Ancient Anguish MUD. It is publicly promoted on the game's official Connect page at https://anguish.org/connect.php, and several Ancient Anguish staff members (Tuinn, Bytre, Jerusulum) actively contribute to its development. We have attached written approval from the Ancient Anguish development team confirming our use of the brand name; please see "AA Endorsement" in the App Review Information attachments.

HOW TO REVIEW THE IN-APP PURCHASES
1. Launch the app and open Settings → Support Tiers.
2. The Support screen renders, top to bottom: an intro card, a bordered banner with "Before you subscribe: Terms of Use · Privacy Policy", three tier cards (each with its own inline "Subscribing accepts the Terms of Use · Privacy Policy" line above its Subscribe button), Restore Purchases / Manage Subscription buttons, and the full auto-renewal disclosure footer with the same legal links repeated inline.
3. Every Terms / Privacy link opens in the system browser via url_launcher.

IMPORTANT CLARIFICATIONS
• Tiers are purely cosmetic. No functionality, theme, content, or feature is gated behind any tier.
• Subscription state is tracked locally only; losing local state triggers a fresh Restore on next launch.
• All three subscriptions live in a single subscription group so upgrade/downgrade between tiers works without cancelling.

CONTACT
For questions during review: https://ancient-anguish.duckdns.org/support.html
```

---

## 2. Mac App Store (macOS)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** `public.app-category.role-playing-games`

All previously approved fields carry forward unchanged from v6.7.0. Two fields change: the App Description and the What's New text.

### Description (≤4000) — macOS

```
A desktop client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA, designed for macOS from the window controls up. Pin Chat to one edge, Tells to another, keep the main terminal centered, and treat a second display like a wing of the realm.

WHAT'S INSIDE

• A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI rendering with 16-color, 256-color, and 24-bit truecolor output. Bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy, Shift-click extend, and a right-click context menu. Clickable URLs.

• Floating, dockable social windows — Chat and Tells as tabs or independent panels, resizable, positionable, and optionally hidden from the main game log so your adventure keeps its thread.

• Game-state HUD — 30+ configurable elements across seven categories: vitals, combat, experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, poison, alignment, followers, and more). Pick the elements you want; the client rebuilds your prompt string and syncs it to the MUD.

• Immersions — Client-side pattern rules that highlight, gag, or play sounds on matching text. Display only — never auto-send. Respects Ancient Anguish's no-bots rule by design.

• Aliases — Short keywords that expand into full commands with $0/$1/$2 variable substitution and ; chaining. Ships with sensible defaults. Recursion-safe.

• Area-based ambient music — The client detects your location from coordinates or room descriptions and crossfades between tracks. A compact audio bar gives you master volume, mute, and now-playing. Add your own music per area.

• Keyboard-first command input — Up/Down history with prefix-filtered search, Tab autocomplete from recent words, Escape to clear input, and the clipboard shortcuts you'd expect.

• Four themes — RPG Dark (gold on wood, the default), Classic Dark (green on black), High Contrast (yellow and cyan on black, built for low-vision players), and a fully editable Custom palette.

• Accessibility — Scalable fonts (8–32 pt), input-line wrap slider (0–200 chars), high-contrast theme, and native VoiceOver support.

PRIVACY

No analytics. No tracking. No ads. No third-party SDKs. Your character credentials, aliases, triggers, and settings stay on your Mac via local Hive storage. The only network traffic is your single outbound connection to the MUD server — you control the host.

FOR VETERANS

A real terminal, full truecolor ANSI, GMCP and MCCP2/3 awareness, dockable panels you can hide or show without losing focus, and keyboard-forward everything. Aliases, triggers (Immersions, AA-flavored), and a 5,000-line scrollback underneath.

FOR NEW PLAYERS

Ancient Anguish is free to play — always has been. Create a character in-game, follow the newbie area, and type `newbie hello!` to say hi. The community is famously welcoming.

A note: this is an independent third-party client for Ancient Anguish, developed in coordination with the AA team and promoted on the official Connect page at https://anguish.org/connect.php. The game itself has been continuously operated by its own team since 1991; we just built a comfortable desk for it.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 — USD). They are purely cosmetic: nothing in the app is gated behind them. Payment is charged to your Apple ID at confirmation of purchase. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ancient-anguish.duckdns.org/privacy.html

Adventure awaits. See you in the realms.
```

### What's New in v6.12.0 (≤4000) — macOS

```
v6.12.0 — Stronger legal disclosure on the Support screen.

The Terms of Use and Privacy Policy links now appear inline on every Support tier card, directly above each Subscribe button — in addition to the existing banner above the tier list and the full disclosure footer below it. The optional supporter tiers themselves are unchanged: still purely cosmetic, still nothing gated behind them.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes — macOS addendum for v6.12.0

```
v6.12.0 is a metadata + small-UI response to the v6.11.0 review rejection (submission 5eebb436-9154-4e4e-9f62-d157bc9fcccd, reviewed 2026-04-24).

WHAT CHANGED FOR GUIDELINE 3.1.2(c)
• Each Support tier card now renders an inline legal line — "Subscribing accepts the Terms of Use · Privacy Policy" — directly above its Subscribe button. Both phrases are individually tappable and open Apple's standard EULA and our hosted Privacy Policy in the system browser.
• The existing legal banner directly below the intro card has been promoted to a bordered card with an info icon and "Before you subscribe:" prefix.
• The full auto-renewal disclosure footer remains present at the bottom of the same screen.
• Terms of Use URL: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
• Privacy Policy URL: https://ancient-anguish.duckdns.org/privacy.html

GUIDELINE 4.1(c) — Authorization to use the Ancient Anguish name
This app is the official third-party client for the Ancient Anguish MUD. It is publicly promoted on the game's official Connect page at https://anguish.org/connect.php, and several Ancient Anguish staff members actively contribute to its development. Written approval from the Ancient Anguish development team is attached under "App Review Information → Attachments → AA Endorsement".

HOW TO REVIEW
1. Launch the app and open Settings → Support Tiers.
2. The Support screen now renders, top to bottom: intro card, bordered legal banner ("Before you subscribe: Terms of Use · Privacy Policy"), three tier cards (each with its own inline "Subscribing accepts the Terms of Use · Privacy Policy" line above its Subscribe button), Restore / Manage buttons, and the full auto-renewal disclosure footer.
3. All subscription UX (upgrade/downgrade, cancel, renew) is handled by the standard StoreKit sheet.

IMPORTANT CLARIFICATIONS
• Tiers are cosmetic only. Nothing in the app is gated behind them.
• The app is sandboxed (`com.apple.security.app-sandbox` = true); StoreKit runs under the default sandbox with no extra entitlements.
• All three subscriptions live in one subscription group so seamless upgrade/downgrade works correctly.

CONTACT
For questions during review: https://ancient-anguish.duckdns.org/support.html
```

---

## 3. Google Play (Android)

Android is unchanged in v6.12.0. The in-app Support tiers are iOS/macOS only — Google Play does not offer the same auto-renewable subscription product for this release.

Fall back to the v6.7.0 listing document for Android copy.

---

## 4. In-App Purchases — iOS / macOS

Three subscriptions already registered in App Store Connect under **Monetization → Subscriptions**. All three live in the same subscription group named **Support** so users can upgrade/downgrade between them without cancelling. The existing product metadata (prices, localized names, descriptions, review screenshots) is correct as of v6.8.0 and carries forward unchanged in v6.12.0.

### Subscription Group

| Field              | Value                                             |
|--------------------|---------------------------------------------------|
| Reference Name     | Support                                           |
| Display Name       | Support                                           |
| Description        | Optional monthly supporter tiers for the client.  |

### Subscription 1 — Small (rank 1)

| Field                                       | Value                                                                |
|---------------------------------------------|----------------------------------------------------------------------|
| Product ID                                  | `pww_small`                                                          |
| Reference Name                              | Small                                                                |
| Subscription Duration                       | 1 month                                                              |
| Price (USD)                                 | $1.99                                                                |
| Localized Display Name (en-US)              | Small                                                                |
| Localized Description (en-US, ≤45)          | A small monthly nod to the developer.                                |
| Promotional Image (1024×1024 PNG, sRGB)     | Not submitted (deleted in App Store Connect per Apple guidance — the three cosmetic tiers are not actively promoted on the Store). |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`                              |
| Review Notes                                | "Purely cosmetic thank-you tier."                                    |
| Tax Category                                | App Store Software                                                   |
| Family Shareable                            | Off                                                                  |

### Subscription 2 — Medium (rank 2)

| Field                                       | Value                                                                |
|---------------------------------------------|----------------------------------------------------------------------|
| Product ID                                  | `pww_medium`                                                         |
| Reference Name                              | Medium                                                               |
| Subscription Duration                       | 1 month                                                              |
| Price (USD)                                 | $3.99                                                                |
| Localized Display Name (en-US)              | Medium                                                               |
| Localized Description (en-US, ≤45)          | Helps cover signing and account fees.                                |
| Promotional Image (1024×1024 PNG, sRGB)     | Not submitted (deleted in App Store Connect per Apple guidance — the three cosmetic tiers are not actively promoted on the Store). |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`                              |
| Review Notes                                | "Purely cosmetic thank-you tier."                                    |
| Tax Category                                | App Store Software                                                   |
| Family Shareable                            | Off                                                                  |

### Subscription 3 — Large (rank 3)

| Field                                       | Value                                                                |
|---------------------------------------------|----------------------------------------------------------------------|
| Product ID                                  | `pww_large`                                                          |
| Reference Name                              | Large                                                                |
| Subscription Duration                       | 1 month                                                              |
| Price (USD)                                 | $5.99                                                                |
| Localized Display Name (en-US)              | Large                                                                |
| Localized Description (en-US, ≤45)          | Powers new features and release sprints.                             |
| Promotional Image (1024×1024 PNG, sRGB)     | Not submitted (deleted in App Store Connect per Apple guidance — the three cosmetic tiers are not actively promoted on the Store). |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`                              |
| Review Notes                                | "Purely cosmetic thank-you tier."                                    |
| Tax Category                                | App Store Software                                                   |
| Family Shareable                            | Off                                                                  |

---

## 5. Subscription Disclosure (auto-renewal copy)

Apple App Review Guideline 3.1.2 requires every auto-renewable subscription surface the following disclosures **in-app** (before purchase) and **in the App Store Connect subscription description**. The in-app version is rendered by `_LegalFooter` in `lib/ui/screens/support_screen.dart`, with additional inline legal lines on each tier card via `_TierLegalLine`. Paste this block verbatim into the Localized Description longer-form field.

```
Support Tiers are optional monthly subscriptions that help fund client development.

• Length: Monthly (auto-renewing)
• Small $1.99 / Medium $3.99 / Large $5.99 per month (USD)
• Payment is charged to your Apple ID at confirmation of purchase.
• Auto-renews unless cancelled at least 24 hours before the end of the current period.
• Account will be charged for renewal within 24 hours prior to the end of the current period at the same tier price.
• Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use:     https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy:   https://ancient-anguish.duckdns.org/privacy.html
```

**App Store Connect App Information fields (both iOS and macOS records):**

| Field               | Value                                                                      |
|---------------------|----------------------------------------------------------------------------|
| Terms of Use URL    | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`        |
| Privacy Policy URL  | `https://ancient-anguish.duckdns.org/privacy.html`                                      |

The Terms of Use URL is Apple's published standard EULA; no custom hosting is required. If a custom EULA is ever needed in the future, upload it to the per-record "EULA" field in App Store Connect and update both the constants at the top of `lib/ui/screens/support_screen.dart` and the App Store Connect App Information field in lock-step.

---

## 6. Screenshot shot list for v6.12.0

The v6.8.0 shot list still applies. One image should be recaptured to reflect the new layout:

### Recapture — all platforms where the Support screen was shown

- `support-hero.png` — the Support screen now shows (a) the strengthened bordered legal banner between the intro card and the first tier card, and (b) the inline "Subscribing accepts the Terms of Use · Privacy Policy" line on each tier card directly above its Subscribe button. If this screenshot was included in any of the iOS / iPad / macOS screenshot slots for the previous release, recapture it using `AA_SUB_SEED=hero`.

```bash
# macOS
bash scripts/run-macos.sh --dart-define=AA_SUB_SEED=hero
bash scripts/app-store-screenshots.sh macos support-hero

# iPhone 6.9"
bash scripts/run-ios-sim.sh "iPhone 16 Pro Max"
flutter run -d "iPhone 16 Pro Max" --dart-define=AA_SUB_SEED=hero
bash scripts/app-store-screenshots.sh iphone-6.9 support-hero

# iPad 13"
bash scripts/run-ios-sim.sh "iPad Pro 13-inch (M4)"
flutter run -d "iPad Pro 13-inch (M4)" --dart-define=AA_SUB_SEED=hero
bash scripts/app-store-screenshots.sh ipad-13 support-hero
```

---

## 7. Resolution Center reply (v6.11.0 rejection response)

Paste this into the reply on the rejected v6.11.0 submission. Attach the new screen recording from `screenshots/review-response/v6.12.0-subscription-links.mov` and confirm the AA endorsement letter is attached under App Review Information.

```
Thank you for the additional review. v6.12.0 addresses both items.

Guideline 3.1.2(c) — Subscription information

We've strengthened the legal disclosure inside the purchase flow itself, so the Terms of Use and Privacy Policy are visible at the moment of purchase, not just adjacent to it.

In-app changes (v6.12.0):
• Each Support tier card now renders an inline line directly above its Subscribe button: "Subscribing accepts the Terms of Use · Privacy Policy". Both phrases are individually tappable and open Apple's standard EULA and our hosted Privacy Policy in the system browser.
• The legal banner directly below the intro card has been promoted to a bordered card with an info icon and a "Before you subscribe:" prefix, so the disclosure reads as deliberate rather than incidental.
• The full auto-renewal disclosure footer (length, price, renewal terms, management path) remains at the bottom of the same screen with both legal links repeated inline.
• Path to reach: launch the app → Settings → Support Tiers.

App Store metadata:
• The App Description (iOS and macOS) continues to include a "SUBSCRIPTION TERMS" paragraph with functional links to the Terms of Use (Apple's standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) and the Privacy Policy (https://ancient-anguish.duckdns.org/privacy.html).
• The Terms of Use URL field in App Information for both iOS and macOS records is set to Apple's standard EULA.
• The Privacy Policy URL field in App Information for both records is set to https://ancient-anguish.duckdns.org/privacy.html.

A short screen recording demonstrating the strengthened in-app disclosure is attached.

Guideline 4.1(c) — Use of the Ancient Anguish name

This app is the official third-party client for the Ancient Anguish MUD. We are not a copycat: the game itself has been continuously operated by its own team since 1991, our app exists in coordination with that team, and it is publicly promoted on the official Ancient Anguish Connect page (https://anguish.org/connect.php) as a recommended client. Several Ancient Anguish staff members (Tuinn, Bytre, Jerusulum) actively contribute to the app's development.

We have attached written approval from the Ancient Anguish development team under App Review Information → Attachments ("AA Endorsement"). It confirms our authorization to use the name "Ancient Anguish" in the app's title and metadata.

Please let us know if any further evidence would help close this thread out. Thank you.
```

---

## 7b. Resolution Center reply (v6.12.0 — Guideline 1.5 Safety rejection)

After the 3.1.2(c) / 4.1(c) reply above was accepted, the v6.12.0 review cycle was rejected under **Guideline 1.5 — Safety** with the note that the configured Support URL (`https://anguish.org/connect.php`) did not direct users to a page where they could ask questions or request support — that URL is the MUD's own "authorized clients" promotion page, not a support page for the client app.

Resolution: the client app's Support, Privacy Policy, and Marketing URLs all now point at a dedicated static site at `https://ancient-anguish.duckdns.org/`, hosted by the developer. The support page contains the developer's contact email, a Discord invite, and a FAQ covering connection, character creation, subscription management, accessibility, bug reporting, and feature requests.

Paste the following into the Resolution Center reply for the v6.12.0 / 1.5 rejection.

```
Thank you for the follow-up. v6.12.0 now addresses Guideline 1.5.

Guideline 1.5 — Support URL

The configured Support URL previously pointed at the MUD's own "authorized clients" promotion page (https://anguish.org/connect.php) rather than a page where users can ask questions or request support. We have now stood up a dedicated support site for the client at https://ancient-anguish.duckdns.org/.

Updates in App Store Connect (both iOS and macOS App Information records):
• Support URL → https://ancient-anguish.duckdns.org/support.html
• Marketing URL → https://ancient-anguish.duckdns.org/
• Privacy Policy URL → https://ancient-anguish.duckdns.org/privacy.html

The support page (https://ancient-anguish.duckdns.org/support.html) contains:
• A Contact section with the developer's email (sami.lamti@gmail.com) and a Discord invite for the client's community.
• A FAQ covering: connecting to the MUD, creating a character, managing or cancelling a Support tier subscription, the Restore Purchases flow, on-screen keyboard behaviour, theme and font-size controls, map rendering, VoiceOver / screen-reader support, reporting bugs, and submitting feature requests.
• A pointer to the game itself (anguish.org) for game-specific questions, with a clear note that the app developer is a separate party from the MUD's operators.

The privacy policy is published at https://ancient-anguish.duckdns.org/privacy.html (previously hosted via GitHub Pages) and is the same plain-English policy you have already reviewed — same protections, same wording, new canonical host.

No code or binary changes were required to address Guideline 1.5; this resubmission carries the existing v6.12.0 binary. The in-app Support screen's Privacy Policy link has been updated in-source to the new URL and will be picked up in the next regular build, but the legal link is already valid in the current binary because both URLs are operational.

Please let us know if any further detail would help close this out. Thank you.
```

---

## 8. Verification checklist for v6.12.0

### Code-side

- [ ] `lib/ui/screens/support_screen.dart` — `_LegalLinksRow` rendered as a bordered card with info icon and "Before you subscribe:" prefix.
- [ ] `lib/ui/screens/support_screen.dart` — `_TierLegalLine` rendered above the Subscribe button on each of the three tier cards.
- [ ] `lib/ui/screens/about_screen.dart` — version label reads `v6.12.0`.
- [ ] `flutter analyze` is clean.
- [ ] `flutter test` passes.
- [ ] Manual walkthrough on macOS: Settings → Support → banner card visible at top, inline disclosure visible on every tier card, all link taps open the correct URL, footer disclosure intact.
- [ ] Manual walkthrough on iPhone 16 Pro Max simulator: link banner + per-tier inline disclosure both visible without scrolling on first render; no Wrap overflow at narrow widths.
- [ ] Screen recording saved at `screenshots/review-response/v6.12.0-subscription-links.mov`.

### App Store Connect — iOS record

- [ ] App Description updated with the new "SUBSCRIPTION TERMS" block (carries forward from v6.11.0 — verify it's still present).
- [ ] What's New in v6.12.0 pasted.
- [ ] Reviewer Notes addendum (v6.12.0) pasted.
- [ ] App Information → Terms of Use URL = Apple's standard EULA URL.
- [ ] App Information → Support URL = `https://ancient-anguish.duckdns.org/support.html`.
- [ ] App Information → Privacy Policy URL = `https://ancient-anguish.duckdns.org/privacy.html`.
- [ ] App Review Information → Attachments → "AA Endorsement" PDF uploaded (`screenshots/review-response/aa-endorsement.pdf`).

### App Store Connect — macOS record

- [ ] App Description updated with the new "SUBSCRIPTION TERMS" block (carries forward from v6.11.0).
- [ ] What's New in v6.12.0 pasted.
- [ ] Reviewer Notes addendum (v6.12.0) pasted.
- [ ] App Information → Terms of Use URL = Apple's standard EULA URL.
- [ ] App Information → Support URL = `https://ancient-anguish.duckdns.org/support.html`.
- [ ] App Information → Privacy Policy URL = `https://ancient-anguish.duckdns.org/privacy.html`.
- [ ] App Review Information → Attachments → "AA Endorsement" PDF uploaded.

### Resubmission

- [ ] Reply pasted into the Resolution Center conversation.
- [ ] Screen recording (`v6.12.0-subscription-links.mov`) attached to the reply.
- [ ] AA endorsement letter received from the Ancient Anguish team and saved to `screenshots/review-response/aa-endorsement.pdf`.
- [ ] New build uploaded with all three IAPs still attached to the same submission.
- [ ] Sandbox tester validates purchase end-to-end before final Submit.
