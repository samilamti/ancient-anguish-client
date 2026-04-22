---
name: mobile-defaults
description: Apply MUD-safe mobile input defaults (autocorrect off, numeric keyboards where appropriate, tap-outside dismissal) when adding text inputs. Prevents the post-TestFlight autocorrect/keyboard regression cycle. Usage: /mobile-defaults
---

# Mobile Input Defaults

Any new `TextField` / `TextFormField` / `EditableText` in this project must thread the user's mobile-input preference through rather than accept Flutter's defaults. Flutter's defaults enable autocorrect, suggestions, smart dashes and smart quotes — all of which mangle MUD command input (`kill orc 2` becomes `kill orc 2.`, `north` gets autocapitalized, etc.).

## The single source of truth

`lib/providers/settings_provider.dart` exposes a `mobileInput` record on the settings state:

```dart
final mib = ref.watch(settingsProvider).mobileInput;
// mib.autocorrect           — false unless user opted in
// mib.enableSuggestions     — false unless user opted in
// mib.smartDashesType       — SmartDashesType.disabled unless user opted in
// mib.smartQuotesType       — SmartQuotesType.disabled unless user opted in
```

The user opts in via Settings → "Mobile auto-correct" (stored as `mobileAutoCorrectEnabled`, default `false`).

## What every new text input MUST include

```dart
final mib = ref.watch(settingsProvider).mobileInput;

TextField(
  autocorrect:       mib.autocorrect,
  enableSuggestions: mib.enableSuggestions,
  smartDashesType:   mib.smartDashesType,
  smartQuotesType:   mib.smartQuotesType,
  // ...
)
```

Do NOT hard-code `autocorrect: false`. The user has chosen a setting; respect it.

## Additional defaults by field type

| Use case                          | Extra parameters                                                                 |
|-----------------------------------|----------------------------------------------------------------------------------|
| MUD command bar (main input)      | `textInputAction: TextInputAction.send`, `keyboardType: TextInputType.text`, `textCapitalization: TextCapitalization.none` |
| Numeric command (damage, count)   | `keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` |
| Alias / trigger pattern           | `textCapitalization: TextCapitalization.none`, mono font, multi-line if pattern needs newlines |
| Password / credentials            | `obscureText: true`, do NOT override autocorrect (the platform handles secure inputs) |
| Chat / tell composer              | `textCapitalization: TextCapitalization.sentences` is OK, still respect `mib.autocorrect` |
| Search / filter                   | `textInputAction: TextInputAction.search`                                        |

## Keyboard dismissal

Mobile keyboards are persistent — users expect tap-outside to dismiss. If the new input lives inside a scrollable/modal screen, wrap the screen body in:

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => FocusScope.of(context).unfocus(),
  child: /* existing content */,
)
```

Alternatively, use the project's existing `hideKeyboardOnMobile` setting (see `lib/providers/settings_provider.dart`) which already drives this behavior for the main input bar — prefer that path when the input is part of the main terminal.

## Tap targets and safe area

- Minimum tap target is 44×44 logical points (Apple HIG). Wrap icon buttons in `IconButton` (defaults to 48) rather than bare `InkWell`.
- Wrap scaffolds with `SafeArea(minimum: EdgeInsets.only(bottom: 8))` if the input sits at the bottom of the screen — otherwise the Android nav gesture area eats taps.
- Use `MediaQuery.viewInsetsOf(context).bottom` to pad above the keyboard on screens that are not `Scaffold(resizeToAvoidBottomInset: true)`.

## D-Pad / mobile-only widgets

Anything under `lib/ui/widgets/mobile/` is rendered only on mobile. Keep the contents touch-friendly:
- Icons at ≥ 24 sp so they render cleanly at 3× density.
- Colors that pass contrast in both light and dark themes (use `Theme.of(context).colorScheme` values, not hardcoded hex).
- When adding a new D-Pad button, update the D-Pad emoji memory entry if the selection rule changes.

## Verification

After adding a new input:

1. `flutter analyze --fatal-infos` — catches missing required params.
2. Run on an iOS simulator: `bash scripts/run-ios-sim.sh`, exercise the input with autocorrect toggled both on and off via Settings. Confirm Flutter does NOT insert suggestions when the setting is off.
3. Run on Android emulator similarly.
4. If the input is a major one (main command bar, social composer), capture a screenshot with `bash scripts/screenshot.sh` so the TestFlight build has the current state documented.

## Reference existing inputs

Use these as copy-the-pattern templates — not as ones to modify:

- `lib/ui/widgets/terminal/input_bar.dart` — main command input (the canonical example)
- `lib/ui/widgets/social/social_input_bar.dart` — chat/tells composer
- `lib/ui/widgets/mobile/target_picker_sheet.dart` — modal picker input
- `lib/ui/screens/auth_screen.dart` — credentials + regular text mix

## Common mistakes

- **Hardcoding `autocorrect: false`** — breaks the user's opt-in.
- **Forgetting `enableSuggestions: mib.enableSuggestions`** — autocorrect off but suggestions still appear on Android.
- **Adding `textCapitalization: TextCapitalization.words`** on a MUD input — servers are case-sensitive.
- **Forgetting `smartDashesType`/`smartQuotesType`** — iOS will still replace `"` with `"` in command text.
- **Using `onEditingComplete` without `onSubmitted`** — breaks the send-on-return flow on iOS.
