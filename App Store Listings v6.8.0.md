# Ancient Anguish Client — Store Listings (v6.8.0)

Paste each block into the matching field in App Store Connect (iOS), App Store Connect (macOS), or Google Play Console. Character counts follow each bounded field.

This document supersedes `App Store Listings v6.7.0.md`. The v6.7.0 archive is kept for reference.

v6.8.0 adds three optional monthly supporter tiers on iOS and macOS. They are purely cosmetic — nothing is gated behind them. See the "In-App Purchases" and "Subscription Disclosure" sections at the bottom of this document for the product metadata and Apple-mandated disclosure copy.

---

## 1. Apple App Store — iOS (iPhone + iPad)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** Games → Role Playing
**Minimum iOS:** 13.0

### What's New in v6.8.0 (≤4000)

```
v6.8.0 — Optional Support tiers.

You can now chip in if you want to. Three optional monthly tiers — Small, Medium, and Large — live in Settings → Support. They're a quiet thank-you, not a paywall: nothing in the client is gated behind them, and everyone gets the same experience.

Everything else stays exactly as it was: a real terminal, 30+ HUD elements, Quick Commands, D-Pad, Immersions, aliases, area audio, floating Chat/Tells panels, four themes, no ads, no analytics, no tracking.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes (for App Review) — addendum for v6.8.0

```
v6.8.0 introduces three auto-renewable monthly subscriptions registered under a single subscription group called "Support":

• pww_small — $1.99 / month
• pww_medium — $3.99 / month
• pww_large — $5.99 / month

HOW TO REVIEW THE IN-APP PURCHASES
1. Launch the app and tap Settings → Support Tiers.
2. The Support screen shows the three tiers. Tap Subscribe on any tier to open the StoreKit sheet.
3. The screen also displays the Apple-mandated auto-renewal disclosure copy (length, price, renewal terms, management path, Terms / Privacy links).
4. Restore Purchases and Manage Subscription controls are both on the Support screen.

IMPORTANT CLARIFICATIONS
- Tiers are purely cosmetic. No functionality, theme, content, or feature is gated behind any tier. The client behaves identically with or without a subscription.
- Subscription state is tracked locally only (no server-side receipt validation). Losing local state simply triggers a fresh Restore on next launch.
- All three subscriptions are in a single subscription group, so users can upgrade/downgrade between tiers at any time without cancelling.
- No other changes to the app in this release. The core MUD client behaviour matches v6.7.0.

CONTACT
For questions during review: https://anguish.org/connect.php
```

(All fields from the v6.7.0 listing — app name, subtitle, promotional text, keywords, description, age-rating answers, support URLs — carry forward unchanged.)

---

## 2. Mac App Store (macOS)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** `public.app-category.role-playing-games`

### What's New in v6.8.0 (≤4000) — macOS

```
v6.8.0 — Optional Support tiers.

Three optional monthly supporter tiers — Small, Medium, and Large — are now available from Settings → Support. Nothing in the app is locked behind them. They're a quiet thank-you from anyone who wants to chip in for ongoing development.

The rest of the app is unchanged: real terminal with full ANSI truecolor, floating Chat/Tells panels, 30+ HUD elements, Immersions, aliases, area audio, four themes, and no analytics or tracking of any kind.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes — macOS addendum for v6.8.0

```
v6.8.0 introduces three auto-renewable monthly subscriptions registered under a single subscription group called "Support":

• pww_small — $1.99 / month
• pww_medium — $3.99 / month
• pww_large — $5.99 / month

HOW TO REVIEW
1. Launch the app and open Settings → Support Tiers.
2. The Support screen shows the three cards with prices loaded from StoreKit, the Apple-mandated auto-renewal disclosure copy, Restore Purchases, Manage Subscription, and Terms / Privacy links.
3. All subscription UX (upgrade/downgrade between tiers, cancel, renew) is handled by the standard StoreKit sheet.

IMPORTANT CLARIFICATIONS
- Tiers are cosmetic only. Nothing in the app is gated behind them.
- The app is sandboxed (`com.apple.security.app-sandbox` = true); StoreKit runs under the default sandbox with no extra entitlements.
- All three subscriptions live in one subscription group so seamless upgrade/downgrade works correctly.
- No other functional changes in this release.

CONTACT
For questions during review: https://anguish.org/connect.php
```

---

## 3. Google Play (Android)

Android is unchanged in v6.8.0. The in-app Support tiers are iOS/macOS only — Google Play does not offer the same auto-renewable subscription product for this release.

Fall back to the v6.7.0 listing document for Android copy.

---

## 4. In-App Purchases — iOS / macOS

Register each subscription in App Store Connect under **Monetization → Subscriptions**. All three must live in the same subscription group named **Support** so users can upgrade/downgrade between them without cancelling.

### Subscription Group

| Field              | Value                                             |
|--------------------|---------------------------------------------------|
| Reference Name     | Support                                           |
| Display Name       | Support                                           |
| Description        | Optional monthly supporter tiers for the client.  |

### Subscription 1 — Small (rank 1)

| Field                                       | Value                                           |
|---------------------------------------------|-------------------------------------------------|
| Product ID                                  | `pww_small`                                     |
| Reference Name                              | Small                                           |
| Subscription Duration                       | 1 month                                         |
| Price (USD)                                 | $1.99                                           |
| Localized Display Name (en-US)              | Small                                           |
| Localized Description (en-US, ≤45)          | A small monthly nod to the developer.           |
| Promotional Image (1024×1024 PNG, sRGB)     | `screenshots/iap/pww_small.png` (design task)   |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`         |
| Review Notes                                | "Purely cosmetic thank-you tier."               |
| Tax Category                                | App Store Software                              |
| Family Shareable                            | Off                                             |

### Subscription 2 — Medium (rank 2)

| Field                                       | Value                                           |
|---------------------------------------------|-------------------------------------------------|
| Product ID                                  | `pww_medium`                                    |
| Reference Name                              | Medium                                          |
| Subscription Duration                       | 1 month                                         |
| Price (USD)                                 | $3.99                                           |
| Localized Display Name (en-US)              | Medium                                          |
| Localized Description (en-US, ≤45)          | Helps cover signing and account fees.           |
| Promotional Image (1024×1024 PNG, sRGB)     | `screenshots/iap/pww_medium.png` (design task)  |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`         |
| Review Notes                                | "Purely cosmetic thank-you tier."               |
| Tax Category                                | App Store Software                              |
| Family Shareable                            | Off                                             |

### Subscription 3 — Large (rank 3)

| Field                                       | Value                                           |
|---------------------------------------------|-------------------------------------------------|
| Product ID                                  | `pww_large`                                     |
| Reference Name                              | Large                                           |
| Subscription Duration                       | 1 month                                         |
| Price (USD)                                 | $5.99                                           |
| Localized Display Name (en-US)              | Large                                           |
| Localized Description (en-US, ≤45)          | Powers new features and release sprints.        |
| Promotional Image (1024×1024 PNG, sRGB)     | `screenshots/iap/pww_large.png` (design task)   |
| Review Screenshot (≥640×920)                | `screenshots/ios/<ts>-support-hero.png`         |
| Review Notes                                | "Purely cosmetic thank-you tier."               |
| Tax Category                                | App Store Software                              |
| Family Shareable                            | Off                                             |

---

## 5. Subscription Disclosure (auto-renewal copy)

Apple App Review Guideline 3.1.2 requires every auto-renewable subscription surface the following disclosures **in-app** (before purchase) and **in the App Store Connect subscription description**. The in-app version is rendered by `_LegalFooter` in `lib/ui/screens/support_screen.dart`. Paste this block verbatim into the Localized Description longer-form field and the App Store Connect "Terms of Use" plain-text field if required.

```
Support Tiers are optional monthly subscriptions that help fund client development.

• Length: Monthly (auto-renewing)
• Small $1.99 / Medium $3.99 / Large $5.99 per month (USD)
• Payment is charged to your Apple ID at confirmation of purchase.
• Auto-renews unless cancelled at least 24 hours before the end of the current period.
• Account will be charged for renewal within 24 hours prior to the end of the current period at the same tier price.
• Manage or cancel anytime from your Apple ID subscription settings.

Terms of Use:     https://anguish.org/connect.php
Privacy Policy:   https://anguish.org/privacy.html
```

**App Store Connect App Information fields (both iOS and macOS records):**

| Field               | Value                                 |
|---------------------|---------------------------------------|
| Terms of Use URL    | `https://anguish.org/connect.php`     |
| Privacy Policy URL  | `https://anguish.org/privacy.html`    |

Both URLs must return 200 and contain at minimum: subscription terms, renewal policy, cancellation instructions, and a plain-English privacy statement. If you would prefer a dedicated Terms URL instead of reusing `connect.php`, update both the constants at the top of `lib/ui/screens/support_screen.dart` and the App Store Connect fields in lock-step.

---

## 6. Screenshot shot list for v6.8.0

The existing v6.7.0 shot list still applies. Add these captures for the new Support screen:

### iPhone 6.9" (1320×2868) — iPhone 16 Pro Max
- `support-hero.png` — all three tier cards visible, no active tier
- `support-active.png` — Medium tier shown as Active (gold border, "Active" chip)

### iPhone 6.5" (1284×2778) — iPhone 14 Plus
- `support-hero.png` — same framing as 6.9"

### iPad 13" (2064×2752) — iPad Pro 13-inch (M4)
- `support-hero.png` — centered cards at 600px max width, generous margin

### macOS 16:10 (2880×1800 typical)
- `support-hero.png` — full app window, Settings → Support Tiers navigated, centered cards

### Deterministic capture
All captures above should run with `--dart-define=AA_SUB_SEED=true` so the tier cards render populated prices and (for `support-active`) the "Active" badge without needing a live StoreKit connection or Sandbox tester account.

```bash
# iOS 6.9"
bash scripts/run-ios-sim.sh "iPhone 16 Pro Max"
flutter run -d "iPhone 16 Pro Max" --dart-define=AA_SUB_SEED=true
bash scripts/screenshot.sh ios support-hero

# iPad 13"
bash scripts/run-ios-sim.sh "iPad Pro 13-inch (M4)"
flutter run -d "iPad Pro 13-inch (M4)" --dart-define=AA_SUB_SEED=true
bash scripts/screenshot.sh ios support-hero

# macOS
flutter run -d macos --dart-define=AA_SUB_SEED=true
bash scripts/screenshot.sh macos support-hero
```

---

## Verification checklist for v6.8.0

- [ ] Three subscriptions registered in App Store Connect under a single "Support" group (ranks 1/2/3).
- [ ] Each subscription has localized Display Name, Description, Tax Category, and Review Screenshot attached.
- [ ] Auto-renewal disclosure copy pasted into each subscription's long-form description.
- [ ] App-level Terms of Use URL and Privacy Policy URL set on both iOS and macOS records.
- [ ] Privacy policy hosted URL actually loads and describes the subscription.
- [ ] 1024×1024 promotional images produced for each tier (design task, out of scope for code change).
- [ ] Support screen captured at all four App Store device slots under seed mode.
- [ ] New build uploaded with the three IAPs attached in the same review submission (do not ship the IAPs in a separate review cycle).
- [ ] Sandbox tester account validates a purchase end-to-end before submission.
