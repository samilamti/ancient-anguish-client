---
description: Review uncommitted or latest-commit Flutter changes against a mobile UI checklist (autocorrect, keyboard dismiss, numeric inputs, safe area, tap targets). Flags issues before they surface on TestFlight.
---

# /mobile-ui-audit

Run through the code changed on this branch or in the most recent commit and flag mobile-unsafe patterns before Sami ships to TestFlight.

## Steps

1. **Pick the change set:**
   - If `git status --porcelain` shows uncommitted changes, audit those.
   - Else audit the most recent commit: `git diff HEAD~1..HEAD -- 'lib/**/*.dart'`.
   - If neither matches, ask Sami which commit range to audit.

2. **Focus on Dart UI code only.** Skip `test/`, `.github/`, docs, `android/`, `ios/`, `macos/` — those aren't mobile UI in the Flutter sense.

3. **For each changed UI file, check:**

   **Text inputs** (`TextField`, `TextFormField`, `EditableText`, any `CupertinoTextField`):
   - Respects `mib.autocorrect` / `mib.enableSuggestions` / `mib.smartDashesType` / `mib.smartQuotesType` from `settingsProvider` — never hardcoded.
   - `textCapitalization` is `none` for MUD commands / aliases / patterns; `sentences` only if prose.
   - `keyboardType` matches the input: `text` for commands, `number` for numeric, `emailAddress` for email, `visiblePassword` for revealable passwords.
   - `textInputAction` set (`send`, `done`, `next`, `search`) — not left as default `TextInputAction.unspecified`.
   - If it's a main input bar and the screen has other focusable content, a tap-outside-to-dismiss gesture or `hideKeyboardOnMobile` hookup is wired.

   **Buttons and tap targets:**
   - Icon-only actions use `IconButton` (48×48) not bare `InkWell`/`GestureDetector`.
   - `InkWell` or `GestureDetector` that IS a tap target has an enclosing box ≥ 44×44.
   - No `MaterialTapTargetSize.shrinkWrap` without justification.

   **Layout:**
   - Bottom-anchored inputs use `SafeArea` or `MediaQuery.viewInsetsOf(context).bottom` so Android gesture nav doesn't eat the control.
   - Scrollables use `ClampingScrollPhysics` or default platform physics, not a hardcoded bouncing override that breaks Material.
   - Fixed widths measured in logical points, not device pixels — no hardcoded `1284` or similar.

   **Theme / contrast:**
   - Colors come from `Theme.of(context).colorScheme` or a project-defined theme token, not hardcoded hex.
   - If the change introduces light/dark variants, both branches exist.

   **Platform-specific widgets:**
   - `Platform.isIOS` / `Platform.isAndroid` checks are grouped — ideally via an existing helper, not scattered.
   - Anything under `lib/ui/widgets/mobile/` should render only on mobile (`ResponsiveLayout` or similar guard in the caller).

4. **Emit a report** with the following structure:

   ```
   === /mobile-ui-audit ===
   change set: <branch uncommitted> | <sha1..sha2>
   files reviewed: N

   - [file:line] FINDING: short description
     → fix: one-liner recommendation

   - [file:line] OK: notes a correctly-applied pattern (helpful reinforcement)
   ```

5. **Prioritize** findings:
   - **Ship-blocker** — will definitely regress on TestFlight (autocorrect on MUD input, sub-44 tap targets on primary action, missing safe area on critical bottom bar).
   - **Fix before submission** — will be noticed by App Review or users (hardcoded colors, platform-specific copy leak).
   - **Nice-to-fix** — minor polish.

6. If Sami wants, apply the ship-blocker fixes directly by delegating to the `mobile-defaults` skill. Otherwise leave the report and stop.

## Reference

- `.claude/skills/mobile-defaults.md` — canonical patterns this audit enforces.
- `lib/ui/widgets/terminal/input_bar.dart` — gold-standard input example.
- `lib/providers/settings_provider.dart` `mobileInput` getter — the single source of truth for autocorrect/suggestions.
- Project memory `feedback_mac_shortcuts_use_cmd.md` — Cmd vs Opt on macOS shortcuts (adjacent concern).

## Notes

- Don't flag issues in code that wasn't changed in the audited range — scope matters.
- If a file already had the issue before this change set, note it but mark as "pre-existing" rather than blocking.
- If Sami runs this right before tagging, pair with `/app-store-listing` so the What's New copy reflects any fixes landed.
