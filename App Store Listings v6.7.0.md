# Ancient Anguish Client — Store Listings (v6.7.0)

Paste each block into the matching field in App Store Connect (iOS), App Store Connect (macOS), or Google Play Console. Character counts follow each bounded field.

This document supersedes the old `App Store Connect — Ancient Anguish 1.0 metadata.md` draft.

---

## 1. Apple App Store — iOS (iPhone + iPad)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** Games → Role Playing
**Minimum iOS:** 13.0

### App Name (≤30)

```
Ancient Anguish Client
```

_(22 chars)_

### Subtitle (≤30) — pick one

- **A** — `A modern gateway to the realms` _(30)_
- **B** — `Theatre of the mind, on the go` _(30)_
- **C** — `Modern client for a 1991 MUD` _(28)_

### Promotional Text (≤170)

```
Ancient Anguish — one of the internet's longest-running fantasy worlds — has a new front door. Built from scratch for the AA community, with the realms waiting inside.
```

_(167 chars)_

### Keywords (≤100, comma-separated, no spaces after commas, no duplicates of the app name)

```
MUD,telnet,LPMud,text RPG,roleplay,fantasy,multiplayer,MMO,terminal,triggers,aliases,mudder,ansi
```

_(96 chars — Apple ignores "Ancient Anguish" in keywords because the app name already covers it.)_

### Description (≤4000)

```
A modern client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991 — built for iPhone and iPad.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA. Not a generic terminal with a MUD skin bolted on — a cockpit that knows how AA's prompt works, how its areas sound, and how its culture plays.

WHAT'S INSIDE

• A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI rendering with 16-color, 256-color, and 24-bit truecolor output. Bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy and clickable URLs.

• Game-state HUD — 30+ configurable elements across seven categories: vitals, combat (aim, attack, defend, wimpy), experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, smoke, poison, alignment, followers, and more). Pick what you want; the client rebuilds your prompt and syncs it to the MUD.

• Quick Commands — A customizable row of tap-to-send buttons with an icon catalog and a target picker drawn from recent words. Build your combat loop, a greetings set, or a utility strip and fire them with one tap. New in v6.7.0.

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

Adventure awaits. See you in the realms.
```

### What's New in v6.7.0 (≤4000)

```
v6.7.0 — Quick Commands, mobile polish, and social windows fixed everywhere.

Quick Commands. A brand-new customizable row of tap-to-send buttons with an icon catalog. Build your combat loop, a greetings set, or a utility strip, set their targets from the recent-words picker, and fire them with one tap.

Mobile input polish. The keyboard now hides by default after you send a command, making room for Quick Commands and the D-Pad. A keyboard toggle lives as the first Quick Command, so it's always one tap away.

Social windows, fixed everywhere. The Chat and Tells panels now render correctly on iPhone and iPad (and on every other platform we ship to).

Under the hood. Version numbers are now driven from a single source of truth, so in-app, installer, and store versions stay in sync. Privacy purpose strings have been tightened so the App Review team can see exactly what we request and why.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes (for App Review)

```
Ancient Anguish Client is a native client for Ancient Anguish, a text-based multiplayer game (MUD) that has been publicly available since 1991 at ancient.anguish.org:2222.

HOW TO REVIEW
1. Launch the app. The default connection target is Ancient Anguish.
2. Tap Connect. You will see the live game's login banner.
3. At the login prompt, follow the in-game prompts to create a new character. Character creation is free and requires no external account.
4. The newbie area begins immediately after character creation and demonstrates core gameplay (movement, combat, communication). Typing `newbie hello!` greets the on-duty mentors.

IMPORTANT CLARIFICATIONS
- No account, payment, or external service is required for review. All gameplay content is delivered by the remote MUD server.
- The app itself has no ads, no analytics, no third-party SDKs, and no user tracking.
- iOS camera, microphone, and photo-library usage strings are present in Info.plist only because Flutter's file_picker plugin links those symbols at the framework level. The app itself never invokes camera, microphone, or photo-library APIs.
- The app connects to a single outbound TCP socket — by default ancient.anguish.org:2222, or a host/port the user specifies. No other network connections are made.

CONTACT
For questions during review: https://anguish.org/connect.php
```

### Age-rating guidance (IARC questionnaire)

- **Cartoon or Fantasy Violence:** Infrequent/Mild — text descriptions of fantasy combat.
- **Realistic Violence:** None.
- **Sexual Content or Nudity:** None.
- **Profanity or Crude Humor:** Infrequent/Mild — occasional mild language may appear in public player chat.
- **Alcohol, Tobacco, or Drug Use / References:** Infrequent/Mild — in-game taverns and intoxication states (`drunk`, `smoke`).
- **Mature/Suggestive Themes:** None.
- **Horror/Fear Themes:** None.
- **Gambling (Simulated):** None.
- **Unrestricted Web Access:** No.
- **User-generated / unmoderated interaction:** Yes — public chat and tells; mute and report channels exist in-game.
- **Shares location/contact:** No.

Suggested Apple rating: **12+**.

### Support / Marketing URLs

- **Support URL:** `https://anguish.org/connect.php`
- **Marketing URL:** `https://anguish.org/connect.php`
- **Privacy Policy URL:** Use the draft at `Privacy Policy.md` in this folder. Recommend hosting at `https://anguish.org/client-privacy.html` (or similar subpath under the AA domain) and linking both store listings there.

---

## 2. Mac App Store (macOS)

**Bundle ID:** `org.ancientanguish.ancientAnguishClient`
**Category:** `public.app-category.role-playing-games`
**Minimum macOS:** per current build settings

### App Name (≤30)

```
Ancient Anguish Client
```

_(22 chars)_

### Subtitle (≤30) — pick one

- **A** — `A cockpit for a classic MUD` _(27)_
- **B** — `Telnet client for a 1991 MUD` _(28)_
- **C** — `Your desk, the realms' cockpit` _(30)_

### Promotional Text (≤170)

```
Ancient Anguish — a fantasy world running since 1991 — with a real terminal, dockable Chat and Tells panels, and 30+ configurable HUD elements.
```

_(143 chars)_

### Keywords (≤100, comma-separated, no spaces after commas)

```
MUD,telnet,LPMud,text RPG,roleplay,fantasy,multiplayer,MMO,terminal,triggers,aliases,mudder,ansi
```

_(96 chars)_

### Description (≤4000)

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

Adventure awaits. See you in the realms.
```

### What's New in v6.7.0 (≤4000) — macOS

```
v6.7.0 — Mac App Store launch, social windows fixed everywhere, and a cleaner release pipeline.

Mac App Store launch. The framework bundle has been repaired to resolve Apple's ITMS-90291, privacy purpose strings have been tightened, and the app category is set to Role-Playing Games.

Social windows, fixed everywhere. Chat and Tells panels now render correctly across every platform the app ships to, including macOS full-screen and multi-display setups.

Under the hood. Version numbers now flow from a single source of truth, so the in-app version, installer metadata, and store version stay in sync from here on out.

Thanks for being here. If something's off — or there's a feature you'd love — tap the feedback link in Settings. Every message is read.
```

### Reviewer Notes — macOS

```
Ancient Anguish Client (macOS) is a desktop client for Ancient Anguish, a text-based multiplayer game (MUD) that has been publicly available since 1991 at ancient.anguish.org:2222.

HOW TO REVIEW
1. Launch the app. The default connection target is Ancient Anguish.
2. Click Connect. The live game's login banner will appear.
3. Follow the in-game prompts to create a new character. Character creation is free and requires no external account.
4. The newbie area begins immediately after character creation and demonstrates core gameplay. Typing `newbie hello!` greets the on-duty mentors.

IMPORTANT CLARIFICATIONS
- No account, payment, or external service is required for review. Gameplay content is delivered by the remote MUD server.
- The app has no ads, no analytics, no third-party SDKs, and no user tracking.
- The app is sandboxed with only the standard outgoing-network entitlement. It connects to a single outbound TCP socket — by default ancient.anguish.org:2222, or a host/port the user specifies.
- v6.7.0 resolves ITMS-90291 (framework bundle) and sets the app category to public.app-category.role-playing-games.

CONTACT
For questions during review: https://anguish.org/connect.php
```

---

## 3. Google Play (Android)

**Category:** Role Playing
**Minimum Android:** per current `minSdkVersion` (Java 17 target)

### App title (≤30)

```
Ancient Anguish Client
```

_(22 chars)_

### Short description (≤80)

```
A modern client for Ancient Anguish — the text MUD running since 1991.
```

_(70 chars)_

### Full description (≤4000)

```
A modern client for Ancient Anguish — the text-based multiplayer fantasy world that's been running continuously since 1991 — built for Android phones and tablets.

If you've played AA before, welcome home. If you haven't: a MUD (Multi-User Dungeon) is a text-driven online game where words do the work pictures do in most games. You read a room, decide what to do, and type a command. It's theatre of the mind, with thousands of other players writing the scenes with you.

This client is a purpose-built front end for AA. Not a generic terminal with a MUD skin bolted on — a cockpit that knows how AA's prompt works, how its areas sound, and how its culture plays.

WHAT'S INSIDE

★ A real terminal — Full telnet with automatic negotiation (NAWS, TTYPE, SGA, ECHO). GMCP- and MCCP-aware. ANSI rendering with 16-color, 256-color, and 24-bit truecolor output. Bold, italic, underline, strikethrough, inverse. 5,000-line scrollback with drag-to-select auto-copy and clickable URLs.

★ Game-state HUD — 30+ configurable elements across seven categories: vitals, combat (aim, attack, defend, wimpy), experience (lifetime and session XP-per-minute), character, wealth, world (game time, reboot countdown), and survival (hunger, thirst, drunk, smoke, poison, alignment, followers, and more). Pick what you want; the client rebuilds your prompt and syncs it to the MUD.

★ Quick Commands — A customizable row of tap-to-send buttons with an icon catalog and a target picker drawn from recent words. Build your combat loop, a greetings set, or a utility strip and fire them with one tap. New in v6.7.0.

★ D-Pad — Eight-direction movement plus up, down, and look, laid out for thumb reach.

★ Immersions — Client-side pattern rules that highlight, gag, or play sounds on matching text. Display only — never auto-send. Respects Ancient Anguish's no-bots rule by design.

★ Aliases — Short keywords that expand into full commands with $0/$1/$2 variable substitution and ; chaining. Ships with sensible defaults. Recursion-safe.

★ Area-based ambient music — The client detects your location from coordinates or room descriptions and crossfades between tracks. Add your own music per area.

★ Chat and Tells windows — Floating, dockable, resizable. Tabs or independent panels. Autocomplete for recipients. Optional suppression from the main log so your adventure keeps its thread.

★ Four themes — RPG Dark (gold on wood, the default), Classic Dark (green on black), High Contrast (yellow and cyan on black, built for low-vision players), and a fully editable Custom palette.

★ Accessibility — Scalable fonts (8–32 pt), input-line wrap slider (0–200 chars), high-contrast theme, and native TalkBack support.

PRIVACY

No analytics. No tracking. No ads. No third-party SDKs. Your character credentials, aliases, triggers, and settings stay on your device via local Hive storage. The only permission the app requests is INTERNET, and the only network traffic is your single outbound connection to the MUD server — you control the host.

FOR VETERANS

A real terminal, full truecolor ANSI, GMCP and MCCP2/3 awareness, 5,000-line scrollback, pattern-matching triggers, aliases with variable substitution, and a configurable prompt the client syncs for you.

FOR NEW PLAYERS

Ancient Anguish is free to play — always has been. Create a character in-game, follow the newbie area, and type `newbie hello!` to say hi. The community is famously kind.

A note: this is an independent third-party client for Ancient Anguish. The game itself has been continuously operated by its own team since 1991; we just made a comfortable doorway.

Adventure awaits. See you in the realms.
```

### What's new / release notes (≤500)

```
v6.7.0 — Quick Commands, mobile polish, social windows fixed everywhere.

• Quick Commands: a customizable row of tap-to-send buttons with an icon catalog and a target picker. Build your combat loop or utility strip and fire them with one tap.
• The keyboard now hides by default after you send, giving Quick Commands and the D-Pad room to breathe.
• Chat and Tells panels render correctly on every device.
• Cleaner release pipeline under the hood.

Thanks for being here.
```

_(~465 chars)_

### Google Play content-rating questionnaire — recommended answers

- **Violence:** Yes — fantasy/cartoon violence described in text (no visuals).
- **Sexual content:** No.
- **Language:** Yes — infrequent/mild language can appear in public player chat.
- **Controlled substances:** References — in-game taverns and intoxication states (`drunk`, `smoke`) appear in text.
- **Social elements:** Users interact (public chat, tells); user-generated text content.
- **Shares user location:** No.
- **Digital purchases:** No.
- **Gambling (real or simulated):** No.

Suggested IARC rating: **Teen**.

### Recommended Play category

`Role Playing`

### Play Store Data Safety form — recommended answers

- **Data collected:** None.
- **Data shared with third parties:** None.
- **Is data encrypted in transit?** Yes (you control this; if you enable TLS/telnet-TLS, declare yes; if plaintext telnet, declare "Data is not encrypted in transit" — be honest about what the default connection does).
- **Can users request data deletion?** Not applicable (no user data leaves the device; uninstalling removes all local data).
- **Target audience:** Teen — not designed for children under 13.

---

## 4. Screenshot shot list

For each shot, the brief specifies: **theme**, **status bar**, **keyboard visible?**, and an overlay **caption** sized for the platform. Capture on real devices or simulators with the app pre-configured to the described state.

### iPhone (6.7" required, 6.9" nice-to-have) — 6 shots

1. **Connection / welcome banner**
   - Theme: RPG Dark
   - Status bar: shown (clean time + signal)
   - Keyboard: hidden
   - Shot: first few lines of the AA login banner after Connect is tapped.
   - Caption (≤20): **Welcome home.**

2. **Active combat, vitals gauges live**
   - Theme: RPG Dark
   - Status bar: shown
   - Keyboard: hidden
   - Shot: a combat round with colored ANSI output, HP/SP gauges animating at the top.
   - Caption: **Full color. Live HUD.**

3. **Quick Commands in action**
   - Theme: RPG Dark
   - Status bar: shown
   - Keyboard: hidden
   - Shot: thumb hovering over a Quick Command; the resulting command visible in the terminal above.
   - Caption: **One-tap cockpit.**

4. **D-Pad navigation**
   - Theme: RPG Dark
   - Status bar: shown
   - Keyboard: hidden
   - Shot: D-Pad visible, a just-entered room description filling the terminal.
   - Caption: **Built for thumbs.**

5. **Advanced Customization — HUD element picker**
   - Theme: RPG Dark
   - Status bar: shown
   - Keyboard: hidden
   - Shot: Survival + Combat categories expanded with a mix of elements toggled on.
   - Caption: **30+ HUD elements.**

6. **Chat + Tells floating panels**
   - Theme: RPG Dark
   - Status bar: shown
   - Keyboard: hidden
   - Shot: Chat panel docked lower-left, Tells panel floating; main terminal visible behind.
   - Caption: **Keep your thread.**

### iPad (13") — 5 shots

1. **Full cockpit overview** — main terminal center, Chat docked left, Tells docked right, HUD expanded across the top.
   - Theme: RPG Dark · Status bar: shown · Keyboard: hidden
   - Caption: **A real cockpit.**

2. **Immersions editor, regex rule being built**
   - Theme: RPG Dark · Status bar: shown · Keyboard: hidden
   - Caption: **Pattern-match anything.**

3. **Area audio bar visible, player moving between regions**
   - Theme: RPG Dark · Status bar: shown · Keyboard: hidden
   - Caption: **The realms have a soundtrack.**

4. **Aliases list with defaults and a custom alias**
   - Theme: RPG Dark · Status bar: shown · Keyboard: hidden
   - Caption: **Shortcuts you write.**

5. **High Contrast theme**
   - Theme: High Contrast · Status bar: shown · Keyboard: hidden
   - Caption: **Built to be readable.**

### macOS (2880×1800 required) — 5 shots

1. **Desktop cockpit with Chat and Tells docked at window edges, HUD across the top**
   - Theme: RPG Dark
   - Caption: **A real cockpit.**

2. **Immersions editor, regex rule with color-highlight preview**
   - Theme: RPG Dark
   - Caption: **Pattern-match anything.**

3. **Custom theme with user-edited colors in the picker**
   - Theme: Custom (with a visible palette) — show picker open
   - Caption: **Make it yours.**

4. **Area audio bar, now-playing track visible**
   - Theme: RPG Dark
   - Caption: **Music for every region.**

5. **Full-window Classic Dark theme, keyboard-driven session in progress**
   - Theme: Classic Dark
   - Caption: **Green-on-black, the way it was.**

### Android phone (1080×1920 or higher) — 6 shots

Mirror the iPhone list, with platform-appropriate captions (Google Play allows longer caption metadata per image description, so lean into clarity over brevity).

1. **Connection / welcome banner** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "Welcome home to Ancient Anguish."
2. **Active combat, vitals gauges live** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "Full truecolor ANSI and a live HUD."
3. **Quick Commands in action** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "Build your cockpit. One-tap attacks."
4. **D-Pad navigation** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "Eight-way movement built for thumbs."
5. **Advanced Customization — HUD element picker** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "30+ configurable HUD elements."
6. **Chat + Tells floating panels** — Theme RPG Dark, status bar shown, keyboard hidden. Caption: "Chat and Tells without losing your place."

### Android tablet — 4 shots

Mirror the iPad list.

1. **Full cockpit overview** — RPG Dark, status bar shown, keyboard hidden. Caption: "A proper cockpit for the realms."
2. **Immersions editor** — RPG Dark, status bar shown, keyboard hidden. Caption: "Pattern-match anything."
3. **Area audio bar** — RPG Dark, status bar shown, keyboard hidden. Caption: "The realms have a soundtrack."
4. **High Contrast theme** — High Contrast, status bar shown, keyboard hidden. Caption: "Built to be readable."

---

## Verification checklist

Before submitting each listing, confirm:

- [ ] **Character counts:** Name ≤30, subtitle ≤30, promo ≤170, keywords ≤100, Play short ≤80, Play release notes ≤500, descriptions ≤4000.
- [ ] **No `Ancient Anguish` duplicates** in iOS or macOS keywords (app name already covers it).
- [ ] **macOS copy contains no iPhone/iPad references.**
- [ ] **Android copy contains no Apple/App Store/iPhone/iPad references.**
- [ ] **Triggers/Immersions are described as display-only** (highlight, gag, sound). No auto-send language anywhere.
- [ ] **Privacy claims match reality**: no analytics, local-only storage, single outbound TCP socket.
- [ ] **Reviewer notes explain**: (a) no account/payment required, (b) iOS camera/mic/photo purpose strings are `file_picker`-driven placeholders, (c) the app connects to a live public MUD server.
- [ ] **Features listed only if in the inventory** in the briefing.
- [ ] **Tone test:** read the description aloud. If it sounds like a press release, send it back.
- [ ] **Paste-test** each block in the relevant store console as a draft before publishing.
