# Chosen's MUD Client for Ancient Anguish — Store Listings (v6.16.0)

This is the v6.16.0 store listing for the iOS and Mac App Stores. It supersedes `App Store Listings v6.15.0.md`, which drove the first public release.

v6.16.0 is a follow-on release: same app, same IAPs, same entitlements, same review surface. The only ASC-side changes are (1) a new `AppStoreVersion` record per platform, (2) a `whatsNew` block summarising what changed since v6.15.0, and (3) attaching the v6.16.0 build. Description, keywords, support URLs, copyright, age rating, and App Privacy carry over unchanged.

**Apple constraints honored throughout:**
- `whatsNew` IS valid this release (it's a follow-on, not a first version — Apple's 409 on first submissions doesn't apply).
- No `✦` or other fancy unicode anywhere — `•` (U+2022) and `—` (em dash) only.
- Description ≤4000 chars, Promotional Text ≤170 chars, Keywords ≤100 chars, Subtitle ≤30 chars, `whatsNew` ≤4000 chars.

---

## 1. Apple App Store — iOS (iPhone + iPad)

**App Name:** `Chosen's MUD Client`
**Subtitle:** `for Ancient Anguish`
**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Primary Category:** Games → Role Playing
**Minimum iOS:** 13.0

### What's New in v6.16.0

```
Mobile-focused update.

• Social windows on phones — Chat, Tells, Party, and Notes now have their own buttons in the top bar. Tap one to open a fullscreen tabbed panel; close to return to the terminal.

• Tap to connect — The red/green dot beside your character name is now the connect/disconnect control. Red taps connect; green taps disconnect. The standalone Connect button has been retired.

• Hide-keyboard button — A new icon in the D-Pad's floor column dismisses the on-screen keyboard without leaving the input bar.

• Cleaner top bar — Removed the Clear button (the output buffer is now smaller, so it's no longer needed). History and About moved to the Settings drawer.

• Plus: live-tail terminal view with a dedicated History screen for older output; Cmd/Ctrl+L on hardware keyboards fires the most recently rendered text link; login polish (scrollable alt list, last-played marker, larger per-character delete icon, "You are already playing!" now confirms automatically when reconnecting from a different device).
```

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
Follow-on release to v6.15.0. No new in-app purchases, no new entitlements, no new capabilities. The v6.15.0 reviewer notes (Aug 2026 submission) still apply — same Ancient Anguish endorsement, same Support Tier IAP flow, same single-outbound-TCP-socket networking, same "guest" login path for spectator review. v6.16.0 changes are mobile UI polish: a tappable connection-status indicator, on-device Social Window access for phones, a keyboard-hide button on the D-Pad, and a few login dialog improvements.

REVIEW PATH (same as v6.15.0)
1. Launch the app. Default target: ancient.anguish.org:2222.
2. Tap the red dot beside the character name (top-left of the title bar) to connect — the dot replaces the prior Connect toolbar button. The dot turns green when connected; tap it again to disconnect.
3. At the login prompt either type `guest` to spectate, or follow the in-game prompts to create a free character.
4. The newbie area begins immediately after character creation. Typing `newbie hello!` greets the on-duty mentors.

IAPS UNCHANGED
The three Support tiers (Small $1.99, Medium $3.99, Large $5.99 monthly) remain in subscription group `Support`. Settings → Support Tiers still renders the same legal banner, per-card inline disclosures, Restore / Manage buttons, and auto-renewal footer. No feature, theme, or content is gated behind any tier.

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

### What's New in v6.16.0

```
Terminal and login polish.

• Live-tail terminal — The main view now shows only the live tail of output. A new History screen keeps the full scrollback at hand without the live view jumping around when you scroll back.

• Cmd+L fires the most recent text link — Hit Cmd+L to send the command behind the most recently rendered tappable link, without reaching for the mouse.

• Login polish — The alt list scrolls, the most recently played character is highlighted, and the per-character delete affordance is a larger, easier-to-hit trash icon. "You are already playing!" now confirms automatically when reconnecting from a different device, so you're not kicked back to the prompt.

• Tap-to-connect — The red/green status dot beside your character name is now the connect/disconnect control. Replaces the standalone Connect toolbar button.
```

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
Follow-on release to v6.15.0. No new in-app purchases, no new entitlements, no new capabilities. The v6.15.0 reviewer notes still apply — same Ancient Anguish endorsement, same Support Tier IAP flow, same sandboxed single-outbound-TCP-socket networking, same "guest" login path for spectator review. v6.16.0 changes are terminal and login UI polish: a live-tail main view with separate History screen, Cmd+L shortcut for the most recently rendered text link, login dialog improvements, and a tappable connection-status indicator that replaces the toolbar Connect button.

REVIEW PATH (same as v6.15.0)
1. Launch the app. Default target: ancient.anguish.org:2222.
2. Click the red dot beside the character name (top-left of the title bar) to connect — the dot replaces the prior Connect toolbar button. The dot turns green when connected; click it again to disconnect.
3. At the login prompt either type `guest` to spectate, or follow the in-game prompts to create a free character.
4. The newbie area begins immediately after character creation. Typing `newbie hello!` greets the on-duty mentors.

IAPS UNCHANGED
The three Support tiers (Small $1.99, Medium $3.99, Large $5.99 monthly) remain in subscription group `Support`. All subscription UX (upgrade/downgrade, cancel, renew) is handled by the standard StoreKit sheet. No feature, theme, or content is gated behind any tier.

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

Unchanged from v6.15.0 — the contact record persists at the app level, not the version level.

---

## 4. In-App Purchases — unchanged from v6.15.0

Subscription group `Support` with three monthly auto-renewing tiers (`pww_small` $1.99, `pww_medium` $3.99, `pww_large` $5.99). App-level, not version-level — they carry forward automatically. No changes required.

---

## 5. Screenshot shot list — v6.16.0

The v6.15.0 screenshots remain valid for most shots. The one that should be re-captured is `06-social` on iPhone, because the Social Window UX is now tab-buttons-in-the-top-bar + fullscreen-panel rather than docked. Everything else looks the same on screen.

If Sami doesn't recapture, the v6.15.0 takes get reused automatically (the upload script picks the most recent capture per label). That's acceptable — the docked-Social shot was a desktop-style framing anyway, and the new mobile fullscreen behavior is easy enough to convey in the What's New copy.

### iPhone 6.5" (APP_IPHONE_65 / 1284×2778) — iPhone 14 Plus simulator

Re-capture only:
- `06-social` — top bar with the four new social tab buttons visible (Chat / Tells / Party / Notes), one tab tapped showing the fullscreen tabbed panel.

Optional adds (only if Sami wants to showcase the new affordances):
- `07-status-dot` — the red/green connection dot beside the player name, clearly tappable.
- `08-kbd-hide` — D-Pad floor column with 🔼 Up / 🔽 Down / Hide-Keyboard stack visible.

### iPad 13" — unchanged

### macOS — unchanged

### Capture sequence

Same as v6.15.0 — see `App Store Listings v6.15.0.md` section 5 for the full command list. To re-capture only `06-social`:

```bash
./scripts/run-ios-sim.sh "iPhone 14 Plus"
flutter run -d "iPhone 14 Plus" --dart-define=AA_SUB_SEED=hero
# Drive the app to the social tabbed panel state, then:
bash scripts/app-store-screenshots.sh iphone-6.5 06-social
```

---

## 6. Apple-side things the API cannot touch (verify in ASC web UI before clicking Submit)

These are all app-level — they survived the v6.15.0 submission and carry forward to v6.16.0 unchanged:

- **App Privacy nutrition label** — "Data not collected". No API.
- **Age Rating** — 12+ with cartoon-violence + occasional language. Unchanged.
- **App Information → Privacy Policy URL** = `https://ancient-anguish.duckdns.org/privacy.html`. Unchanged.
- **App Information → Terms of Use URL** = `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`. Unchanged.
- **App Review Information → Attachments → "AA Endorsement"** — persisted from v6.15.0. Confirm the version page shows the attachment after the create script runs; re-upload via web UI drag-drop if not.

---

## 7. Verification checklist

After the driver script's `--apply` completes:

- [ ] Both v6.16.0 records (iOS + macOS) exist in ASC with `state = PREPARE_FOR_SUBMISSION` or `READY_FOR_SUBMISSION`.
- [ ] Each record has the v6.16.0 build attached (build number from CI run_number — should be `40` per the TestFlight status, but the script picks the latest VALID v6.16.0 build automatically).
- [ ] Each record's `whatsNew` field renders without an invalid-character warning.
- [ ] Screenshots appear in alphabetical order of label.
- [ ] App Privacy, Age Rating, and "AA Endorsement" attachment are all visible on each version page.
- [ ] Click "Add for Review" → "Submit for Review" on each record.
