# Ancient Anguish Client — Store Listings (v6.11.0)

Paste each block into the matching field in App Store Connect (iOS), App Store Connect (macOS), or Google Play Console. Character counts follow each bounded field.

This document supersedes `App Store Listings v6.8.0.md`. The v6.7.0 and v6.8.0 archives are kept for reference.

v6.11.0 exists to address Apple's rejection of the v6.8.0 / v6.11.0 review cycle under **Guideline 2.3.2** (duplicate IAP promotional images) and **Guideline 3.1.2(c)** (missing functional Terms-of-Use / Privacy-policy surfacing). The three optional supporter subscriptions themselves are unchanged. See section 7 for the Resolution Center response.

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

A note: this is an independent third-party client for Ancient Anguish. The game itself has been continuously operated by its own team since 1991; we just built a comfortable doorway.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 — USD). They are purely cosmetic: nothing in the app is gated behind them. Payment is charged to your Apple ID at confirmation of purchase. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://samilamti.github.io/ancient-anguish-client/

Adventure awaits. See you in the realms.
```

### What's New in v6.11.0 (≤4000)

```
v6.11.0 — Polish on Support screen legal surfacing.

Terms of Use and Privacy Policy links are now visible at the top of the Support screen in addition to the existing disclosure at the bottom. Nothing else about the optional supporter tiers has changed — they remain purely cosmetic, and nothing in the client is gated behind them.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes (for App Review) — addendum for v6.11.0

```
v6.11.0 is a metadata + small-UI response to the v6.8.0 / v6.11.0 review rejections.

WHAT CHANGED
• The Support screen now renders a visible "Terms of Use · Privacy Policy" row directly below the intro card, above the three tier cards. Both links open in the system browser. The full auto-renewal disclosure (length, price, renewal terms, management path, Terms and Privacy links) remains present at the bottom of the same screen.
• The Terms of Use URL has been updated to Apple's standard EULA (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) in both the app and the App Store Connect App Information record.
• The three promotional images previously attached to pww_small, pww_medium, and pww_large have been removed from App Store Connect. These tiers are purely cosmetic and are not actively promoted on the Store; per Apple's guidance the promotional image slot may be left empty.

HOW TO REVIEW THE IN-APP PURCHASES
1. Launch the app and open Settings → Support Tiers.
2. At the top of the Support screen (directly below "Support the Client") are two tappable links: "Terms of Use" and "Privacy Policy".
3. Three subscription tiers (Small / Medium / Large) follow with prices loaded from StoreKit.
4. At the bottom of the screen, the full auto-renewal disclosure is present with the same Terms / Privacy links repeated inline.
5. Restore Purchases and Manage Subscription buttons sit between the tiers and the footer.

IMPORTANT CLARIFICATIONS
• Tiers are purely cosmetic. No functionality, theme, content, or feature is gated behind any tier.
• Subscription state is tracked locally only; losing local state triggers a fresh Restore on next launch.
• All three subscriptions live in a single subscription group so upgrade/downgrade between tiers works without cancelling.

CONTACT
For questions during review: https://anguish.org/connect.php
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

A note: this is an independent third-party client for Ancient Anguish. The game itself has been continuously operated by its own team since 1991; we just built a comfortable desk for it.

SUBSCRIPTION TERMS

Optional Support tiers are auto-renewable monthly subscriptions (Small $1.99, Medium $3.99, Large $5.99 — USD). They are purely cosmetic: nothing in the app is gated behind them. Payment is charged to your Apple ID at confirmation of purchase. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://samilamti.github.io/ancient-anguish-client/

Adventure awaits. See you in the realms.
```

### What's New in v6.11.0 (≤4000) — macOS

```
v6.11.0 — Polish on Support screen legal surfacing.

Terms of Use and Privacy Policy links are now visible at the top of the Support screen in addition to the existing disclosure at the bottom. Nothing else about the optional supporter tiers has changed — they remain purely cosmetic, and nothing in the app is gated behind them.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes — macOS addendum for v6.11.0

```
v6.11.0 is a metadata + small-UI response to the v6.8.0 / v6.11.0 review rejections.

WHAT CHANGED
• The Support screen now renders a visible "Terms of Use · Privacy Policy" row directly below the intro card, above the tier cards. Both links open in the system browser. The full auto-renewal disclosure remains present at the bottom of the same screen.
• The Terms of Use URL has been updated to Apple's standard EULA (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) in both the app and the App Store Connect App Information record.
• The three promotional images previously attached to pww_small / pww_medium / pww_large have been removed from App Store Connect per Apple's guidance — these cosmetic tiers are not actively promoted.

HOW TO REVIEW
1. Launch the app and open Settings → Support Tiers.
2. The top of the screen shows the intro card, followed immediately by tappable "Terms of Use" and "Privacy Policy" links.
3. Three tier cards follow with StoreKit-loaded prices.
4. The bottom of the screen carries the full auto-renewal disclosure plus the same legal links repeated inline.
5. All subscription UX (upgrade/downgrade, cancel, renew) is handled by the standard StoreKit sheet.

IMPORTANT CLARIFICATIONS
• Tiers are cosmetic only. Nothing in the app is gated behind them.
• The app is sandboxed (`com.apple.security.app-sandbox` = true); StoreKit runs under the default sandbox with no extra entitlements.
• All three subscriptions live in one subscription group so seamless upgrade/downgrade works correctly.

CONTACT
For questions during review: https://anguish.org/connect.php
```

---

## 3. Google Play (Android)

Android is unchanged in v6.11.0. The in-app Support tiers are iOS/macOS only — Google Play does not offer the same auto-renewable subscription product for this release.

Fall back to the v6.7.0 listing document for Android copy.

---

## 4. In-App Purchases — iOS / macOS

Three subscriptions already registered in App Store Connect under **Monetization → Subscriptions**. All three live in the same subscription group named **Support** so users can upgrade/downgrade between them without cancelling. The existing product metadata (prices, localized names, descriptions, review screenshots) is correct as of v6.8.0 and carries forward unchanged in v6.11.0.

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

Apple App Review Guideline 3.1.2 requires every auto-renewable subscription surface the following disclosures **in-app** (before purchase) and **in the App Store Connect subscription description**. The in-app version is rendered by `_LegalFooter` in `lib/ui/screens/support_screen.dart`. Paste this block verbatim into the Localized Description longer-form field.

```
Support Tiers are optional monthly subscriptions that help fund client development.

• Length: Monthly (auto-renewing)
• Small $1.99 / Medium $3.99 / Large $5.99 per month (USD)
• Payment is charged to your Apple ID at confirmation of purchase.
• Auto-renews unless cancelled at least 24 hours before the end of the current period.
• Account will be charged for renewal within 24 hours prior to the end of the current period at the same tier price.
• Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use:     https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy:   https://samilamti.github.io/ancient-anguish-client/
```

**App Store Connect App Information fields (both iOS and macOS records):**

| Field               | Value                                                                      |
|---------------------|----------------------------------------------------------------------------|
| Terms of Use URL    | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`        |
| Privacy Policy URL  | `https://samilamti.github.io/ancient-anguish-client/`                      |

The Terms of Use URL is Apple's published standard EULA; no custom hosting is required. If a custom EULA is ever needed in the future, upload it to the per-record "EULA" field in App Store Connect and update both the constants at the top of `lib/ui/screens/support_screen.dart` and the App Store Connect App Information field in lock-step.

---

## 6. Screenshot shot list for v6.11.0

The v6.8.0 shot list still applies. One image should be recaptured to reflect the new layout:

### Recapture — all platforms where the Support screen was shown

- `support-hero.png` — the Support screen now shows the new legal-links row between the intro card and the first tier card. If this screenshot was included in any of the iOS / iPad / macOS screenshot slots for the previous release, recapture it using `AA_SUB_SEED=hero`.

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

Paste this into the reply on the rejected v6.11.0 submission. Attach the screen recording from `screenshots/review-response/v6.11.0-subscription-links.mov`.

```
Thank you for the detailed feedback. v6.11.0 now addresses both issues.

Guideline 2.3.2 — Duplicate promotional images
We removed the promotional images previously attached to pww_small, pww_medium, and pww_large in App Store Connect. These three supporter tiers are purely cosmetic (nothing in the app is gated behind them) and we do not currently plan to promote them on the Store, so per your guidance we deleted the images rather than producing unique ones.

Guideline 3.1.2(c) — Subscription information

In-app:
• The Support screen now shows a visible "Terms of Use · Privacy Policy" row directly below the intro card, above the three tier cards. Both links open in the system browser.
• The full auto-renewal disclosure (length, price per tier, renewal terms, management path) remains at the bottom of the same screen with the same two links repeated inline.
• To reach the Support screen: launch the app → Settings → Support Tiers.

App Store metadata:
• The Terms of Use URL field on both the iOS and macOS App Information records has been updated to Apple's standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
• The App Description (iOS and macOS) now includes a "SUBSCRIPTION TERMS" paragraph with functional links to both the Terms of Use (Apple's standard EULA) and the Privacy Policy (https://samilamti.github.io/ancient-anguish-client/).

A short screen recording demonstrating the in-app Terms of Use and Privacy Policy links is attached.
```

---

## 8. Verification checklist for v6.11.0

### Code-side

- [ ] `lib/ui/screens/support_screen.dart` — `_termsUrl` constant now points to Apple's standard EULA.
- [ ] `lib/ui/screens/support_screen.dart` — `_LegalLinksRow` renders between `_IntroCard` and the first tier card.
- [ ] `flutter analyze` is clean.
- [ ] `flutter test` passes.
- [ ] Manual walkthrough on macOS: Settings → Support → links visible at top and bottom, both tap and open in browser.
- [ ] Manual walkthrough on iPhone 16 Pro Max simulator: link row visible on first render without scrolling.
- [ ] Screen recording saved at `screenshots/review-response/v6.11.0-subscription-links.mov`.

### App Store Connect — iOS record

- [ ] Promotional images removed from pww_small, pww_medium, pww_large.
- [ ] App Description updated with the new "SUBSCRIPTION TERMS" block.
- [ ] What's New in v6.11.0 pasted.
- [ ] Reviewer Notes addendum pasted.
- [ ] App Information → Terms of Use URL = Apple's standard EULA URL.
- [ ] App Information → Privacy Policy URL = `https://samilamti.github.io/ancient-anguish-client/`.

### App Store Connect — macOS record

- [ ] Promotional images removed from pww_small, pww_medium, pww_large (if attached on the macOS record as well).
- [ ] App Description updated with the new "SUBSCRIPTION TERMS" block.
- [ ] What's New in v6.11.0 pasted.
- [ ] Reviewer Notes addendum pasted.
- [ ] App Information → Terms of Use URL = Apple's standard EULA URL.
- [ ] App Information → Privacy Policy URL = `https://samilamti.github.io/ancient-anguish-client/`.

### Resubmission

- [ ] Reply pasted into the Resolution Center conversation.
- [ ] Screen recording attached to the reply.
- [ ] New build uploaded (if code changes went in) with all three IAPs still attached to the same submission.
- [ ] Sandbox tester validates purchase end-to-end before final Submit.
