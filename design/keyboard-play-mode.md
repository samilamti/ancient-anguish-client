# Keyboard play mode: design

Status: **Signed off by Sami, 2026-10-27.** Implementation follows the outline below.

Three parts: WASD movement, a WoW-style action bar on 1–0, and a `$target` that reliably names the right creature. They ship together because each one is weak alone: an action bar without a target is just aliases, and a target without a fast way to use it is a label.

## Decisions taken

| Question | Decision |
|---|---|
| Getting in and out of the mode | WoW chat model (below) |
| What "ignore" means once targeting exists | One list: ignored creatures lose the red link **and** are skipped by Tab and auto-target. They stay in the Kill picker. |
| Price | Free for everyone first. Revisit perks (extra bar, slot icons) once we see whether Mac players use it. |
| Duplicate creatures | AA accepts `kill orc 2`, so Tab cycles each one: `orc`, `orc 2`. |
| AA admins | No advance check needed: nothing here automates play beyond what aliases already do. |
| Extra movement keys | Keep Q/E/Z/C for the diagonals and R/F for up/down. |
| Second bar (Shift+1–0) | Not in v1. Kept as a possible supporter perk. |
| Phones | No play mode below 768pt. `$target` works everywhere, the Kill picker sets the target, and the 3 pinned D-pad slots can use it. Play mode is offered wherever a hardware keyboard is present (iPad, Android tablet, Mac, desktop). |

## 1. Play mode

### States

```
            Ctrl/Cmd+G or toolbar toggle
  TYPING  <------------------------------>  PLAY
  (today)                                    |  ^
                                       Enter |  | Enter (sends) / Esc on empty input
                                             v  |
                                       PLAY + input open
```

- **Off (today's behaviour):** the input bar has focus, every key types. Nothing changes for players who never switch it on.
- **Play:** the input bar is not focused. It turns into a strip with a green outline (the same green as the active toolbar toggle):
  `PLAY · WASD move · 1–0 bar · Tab target · Enter to type`.
- **Play with the input open:** pressing Enter focuses the input exactly as it works today. Enter sends the line and closes the input again. Esc clears the text if there is any; on an empty input it closes the input. This is the WoW chat loop: you are always one Enter away from typing.
- **Turning it on and off:** a desktop toolbar toggle (the `_ToolbarItem` `active:` style, next to Instant Triggers) and **Ctrl/Cmd+G**, bound both ways like every other chord. The setting persists across launches, because players who want it will want it every session.

### Keys in play mode

| Key | Action |
|---|---|
| W / A / S / D | `north` / `west` / `south` / `east` |
| Q / E / Z / C | `northwest` / `northeast` / `southwest` / `southeast` |
| R / F | `up` / `down` |
| 1 … 9, 0 | action bar slots 1–10 |
| Tab / Shift+Tab | next / previous target |
| T | `kill TARGET` (Sami, 2026-10-30) |
| X / Shift+T | ignore current target, move to the next |
| Esc | clear target |
| Enter | open the input |
| any other key | flash "Enter to type" on the strip; nothing is sent |

- Movement uses the full words, as the D-pad does, and goes through `gameStateProvider.recordDirectionalAttempt` like the D-pad, so the compass and `MovementTracker` see it.
- **Holding a movement key walks:** each OS key repeat sends the move again, so holding W keeps going north (Sami, 2026-10-27, after trying the first build). **Key repeat is ignored for everything else** (`KeyRepeatEvent` is dropped), so holding 1 must not spam a macro.
- Ctrl/Cmd chords keep working in play mode (they go to the HomeScreen `CallbackShortcuts` map as today).

### Where the keys are handled

A dedicated `Focus` around the terminal area holds focus in play mode and handles the keys above in `onKeyEvent`, returning `ignored` for anything with Ctrl/Cmd so global chords still bubble up. The `InputBar`'s `_handleKey` is untouched, apart from Enter/Esc telling the play-mode notifier to close the input when play mode is on.

## 2. Action bar

### Slots point to aliases

No new macro model. Each of the 10 slots holds an alias id (`AppSettings.actionBarAliasIds`, a `List<String?>` of length 10, persisted in settings.json next to `pinnedAliasIds`). A macro is just an alias whose expansion uses `;`:

```
fb   ->  kill $target;cast fireball $target
heal ->  cast cure light wounds;drink potion
```

That keeps one place to edit commands (the alias screen) and means anything that works in an alias works on the bar: `$0`/`$1` (empty here), `;` chains, nested aliases. Typing `fb` by hand does exactly what pressing its slot does.

### The bar on screen

- Desktop, play mode on: a row of 10 slots directly above the input strip. Each slot shows its key number and the alias keyword (`1 fb`). Empty slots show `+`. Click a slot to send it; right-click or long-press to assign an alias (a picker over the alias list, plus "New alias…").
- A slot whose expansion contains `$target` is dimmed while no target is set. Pressing it anyway sends nothing and puts a red local line in the terminal: `No target.`
- Play mode off: the bar is hidden.
- **Typed commands fill free slots** (Sami, 2026-10-30): a line typed and sent in play mode goes into the first slot that has neither an alias nor a command, unless it is already on the bar (as a command or as a slot alias's keyword). Movement and `#` commands are skipped. Once all ten slots are taken nothing more is added. Auto-filled slots are stored in `actionBarCommands` and shown in italics; assigning an alias or Clear slot replaces one.

### `$target` expansion

`AliasEngine.expand` gains one more variable, `$target`, read from the target notifier at expansion time. It is replaced before the `;` split, alongside `$0`/`$1`. If the line uses `$target` and there is none, the whole line is refused (no partial sends) with the `No target.` line. Every path that expands aliases gets it for free: typed input, bar slots, D-pad slots, link taps.

## 3. Targeting

### What a target is

A single creature keyword, the same string the red kill links use (`orc`, `hare`). It comes from places that already exist:

| Source | When |
|---|---|
| Tab / Shift+Tab | cycles through `roomTargetsProvider` in the order the room listed them, then the kill targets linked in the last 100 lines of output (what Ctrl/Cmd+K reaches, newest first; added 2026-10-30), **minus ignored keywords**. Duplicates get AA's ordinal: two orcs give `orc` then `orc 2`, and `$target` expands to `orc 2` so `kill $target` becomes `kill orc 2`. |
| Clicking a red kill link | sets the target to that keyword (the link still sends `kill …` as today) |
| Kill picker | choosing a creature sets the target |
| Fight starts | if no target is set, `BattleStats.target` (the opponent of record) becomes the target. That is a display name (`Ship rat`), so it is lowercased and reduced to its head noun (`rat`), the same way kill links pick a keyword. |

### Shown

A red chip at the left of the action bar: `🎯 orc`, with `Tab` printed faintly next to it when the room has more than one candidate. On phones the chip sits above the D-pad when a target is set. The keyword is also underlined in its kill links so you can see which creature in the room text it means.

### Cleared

- Esc in play mode;
- the target dies: a `BattleLineKind.resolution` line naming its keyword (`You killed Orc.`, `Orc died.`). With duplicates the line can't say which orc died, and AA renumbers the rest, so any death of that keyword clears the target and the player Tabs again;
- you enter a room whose target list doesn't contain it **and** you're not in a fight. In a fight the target is kept, so a creature that fled is still the target when you chase it.

### Ignoring

The point is to narrow the room down to the creatures you actually want: ignore the ones you've already identified as not targets, and what's left is the target set.

- **X** in play mode ignores the current target and moves to the next one. The snackbar with Undo is the same as the long-press flow today.
- Long-pressing a kill link → "Stop highlighting this" also removes it from the cycle (it's the same list).
- `ignoredKillTargets` keeps its name in settings.json, so existing lists carry over. The settings screen is renamed "Ignored targets" and its subtitle explains both effects.
- Ignored creatures stay in the Kill picker and can still be targeted from there or typed by hand. Ignoring means "don't offer this to me", never "I can't attack this".

## Fair play

Ancient Anguish forbids automated play. Every action here is **one keypress → one user-initiated dispatch**, exactly as an alias or a D-pad tap is today:

- no command is ever sent without a key or tap;
- holding a movement key walks at the OS key-repeat rate, one move per repeat the player is physically holding down; bar slots and target keys never repeat;
- the bar does not run `#N` repeats or trigger anything; local-only command triggers stay local-only and are not reachable from a slot;
- `$target` only names a creature; it never chooses to attack one.

Sami decided no advance check with an AA admin is needed, since this adds no automation beyond aliases.

## Implementation outline (after sign-off)

1. `roomTargetsProvider` keeps a count per keyword (it currently merges duplicates), so the cycle can offer `orc 2`.
2. `TargetNotifier` (`lib/providers/target_provider.dart`): current keyword, `next()`/`previous()` over room targets minus ignored, set from link/picker/battle, the clear rules above. Pure and unit-tested.
3. `$target` in `AliasEngine.expand`, refusing the line when unset.
4. `PlayModeNotifier`: off / play / play-with-input, persisted on/off.
5. Play-mode `Focus` + key map in HomeScreen; Ctrl/Cmd+G; toolbar toggle; Enter/Esc hooks in `InputBar`.
6. `actionBarAliasIds` setting, `ActionBar` widget, slot assignment picker.
7. Target chip (desktop bar + phone D-pad); kill-link click and Kill picker set the target; X/long-press ignore drops from the cycle.
8. About screen shortcut list updated.

Each step lands with tests; the classifier and ignore tests already in `test/providers/kill_target_links_test.dart` are the model.
