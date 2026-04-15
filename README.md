# Ancient Anguish Client

A cross-platform MUD client for [Ancient Anguish](http://ancient.anguish.org), built with Flutter. It provides a modern terminal interface with RPG-themed visuals, client-side automation (triggers and aliases), area-based ambient audio, and mobile-friendly controls.

## Features

- **Full telnet protocol** — RFC 854/855 implementation with automatic negotiation of NAWS, TTYPE, SGA, and ECHO. Recognizes GMCP, MCCP2/3, and other MUD extensions.
- **ANSI color rendering** — 16-color, 256-color, and 24-bit truecolor support with bold, italic, underline, strikethrough, and inverse styles.
- **Triggers** — Pattern-matched rules that highlight text, play sounds, or gag (suppress) lines. Triggers are client-side only and never auto-send commands (per Ancient Anguish rules).
- **Aliases** — Short keywords that expand into longer commands with variable substitution (`$0`, `$1`, `$2`, ...) and semicolon command chaining. Ships with useful defaults (`k` for kill, `ga` for get all, etc.).
- **Area detection & audio** — Determines the player's current area by coordinates or room description text patterns, then crossfades to area-specific background music.
- **Game state display** — Parses HP, SP, XP, coins, coordinates, class, and player name from the prompt and CLIENT line into a live status bar with vitals gauges.
- **Advanced Customization** — Choose from 30+ MUD prompt values (combat stats, XP tracking, survival needs, world info, etc.) to build a personalized HUD with dynamic panels that appear based on your selections.
- **Mobile controls** — D-Pad for directional movement and a quick-commands bar for common actions on touch devices.
- **Themes** — Three built-in themes: RPG Dark (gold and parchment), Classic Dark (green-on-black terminal), and High Contrast (accessibility).
- **Social windows** — Floating/dockable Chat and Tells panels with autocomplete recipient selection, lazy-loading message history, and alternating-row striping.
- **Text selection** — Drag-to-select terminal text with auto-copy, Shift+click extend, and right-click context menu.
- **Clickable links** — URLs in terminal output are detected and open in the system browser.
- **Web support** — Companion server (`server/`) provides a WebSocket-to-TCP proxy, per-user file storage, and JWT authentication for browser-based play.
- **Scrollback buffer** — 5,000-line terminal history.

## Supported Platforms

Android, iOS, macOS, Windows, Linux, and Web — anywhere Flutter runs.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK ^3.10.4)

## Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd "Ancient Anguish Client"

# Install dependencies
flutter pub get

# Run code generation (Riverpod, JSON serialization, Hive adapters)
dart run build_runner build --delete-conflicting-outputs

# Launch the app
flutter run
```

On launch, tap the link icon in the toolbar to connect to `ancient.anguish.org:2222`.

## Project Structure

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # Root widget, theme selection
├── core/
│   ├── constants.dart                 # Server defaults, terminal defaults, audio defaults
│   ├── theme/
│   │   ├── app_theme.dart             # RPG Dark, Classic Dark, High Contrast themes
│   │   └── terminal_colors.dart       # Full ANSI color palette (16 + 256 + truecolor)
│   └── utils/
│       └── ring_buffer.dart           # Fixed-size circular buffer for scrollback
├── models/
│   ├── alias_rule.dart                # Alias definition with variable substitution
│   ├── area_config.dart               # Area bounds, area audio configuration
│   ├── connection_info.dart           # Host/port and ConnectionStatus enum
│   ├── game_state.dart                # HP, SP, XP, coords, combat, survival, world info
│   ├── prompt_element.dart            # Prompt element definitions and metadata
│   └── trigger_rule.dart              # Trigger patterns, actions, highlight options
├── protocol/
│   ├── telnet/
│   │   ├── telnet_protocol.dart       # Telnet state machine (byte-level IAC parsing)
│   │   ├── telnet_option.dart         # Telnet command and option constants
│   │   └── telnet_events.dart         # TelnetEvent class hierarchy
│   └── ansi/
│       ├── ansi_parser.dart           # SGR escape sequence parser
│       └── styled_span.dart           # StyledSpan / StyledLine models
├── services/
│   ├── connection/
│   │   └── connection_service.dart    # TCP socket lifecycle, auto-negotiation
│   ├── parser/
│   │   ├── output_parser.dart         # UTF-8 decode → line split → ANSI parse
│   │   └── prompt_parser.dart         # Prompt and CLIENT line extraction
│   ├── prompt/
│   │   └── prompt_command_builder.dart # Dynamic prompt command and regex builder
│   ├── trigger/
│   │   └── trigger_engine.dart        # Trigger matching, highlighting, gagging
│   ├── alias/
│   │   └── alias_engine.dart          # Alias expansion with recursion prevention
│   ├── area/
│   │   └── area_detector.dart         # Coordinate + text-based area detection
│   ├── audio/
│   │   ├── audio_service.dart         # Playback engine with crossfade
│   │   └── area_audio_manager.dart    # Switches tracks when the player moves areas
│   └── logging/
│       └── log_service.dart           # Application logging
├── providers/                         # Riverpod state management
│   ├── connection_provider.dart
│   ├── game_state_provider.dart
│   ├── prompt_config_provider.dart    # Dynamic prompt command/regex from user selections
│   ├── trigger_provider.dart
│   ├── alias_provider.dart
│   ├── audio_provider.dart
│   └── settings_provider.dart
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # Main game screen
    │   ├── settings_screen.dart       # General settings
    │   ├── advanced_customization_screen.dart  # Prompt element selection UI
    │   ├── trigger_settings_screen.dart
    │   ├── alias_settings_screen.dart
    │   └── about_screen.dart
    └── widgets/
        ├── terminal/
        │   ├── terminal_view.dart     # Scrollable styled-line renderer
        │   └── input_bar.dart         # Command input with history
        ├── status/
        │   ├── status_bar.dart        # HP/SP/XP display + dynamic panels
        │   ├── vitals_gauge.dart      # Animated health/mana bars
        │   ├── combat_stats_panel.dart # Aim/attack/defend display
        │   ├── xp_tracker_panel.dart  # XP rates and session tracking
        │   ├── character_card_panel.dart # Level/race/class/age card
        │   ├── wimpy_indicator.dart   # Wimpy HP threshold badge
        │   ├── wealth_display.dart    # Coins and bank balance
        │   ├── world_clock_panel.dart # Game time and reboot countdown
        │   └── survival_panel.dart    # Hunger/thirst/poison indicators
        ├── audio/
        │   └── audio_controls.dart    # Volume and track controls
        ├── mobile/
        │   ├── d_pad.dart             # Directional movement pad
        │   └── quick_commands.dart    # Tap-to-send common commands
        └── common/

assets/
├── data/
│   └── area_definitions.json          # Area configs (Tantallon, Northern Plains, etc.)
└── fonts/
    └── JetBrainsMono-*.ttf            # Monospace terminal font
```

## Architecture

The client follows a layered architecture:

1. **Protocol layer** (`lib/protocol/`) — Parses raw TCP bytes into telnet events and ANSI-styled text. The telnet state machine handles IAC command sequences, option negotiation, and subnegotiation. The ANSI parser converts SGR escape codes into `StyledSpan` objects with color and formatting attributes.

2. **Service layer** (`lib/services/`) — Business logic that sits between the protocol layer and the UI. The connection service manages the TCP socket and auto-responds to telnet negotiations. The output parser chains UTF-8 decoding, line splitting, and ANSI parsing into a pipeline. The trigger and alias engines evaluate user-defined rules against input/output.

3. **State layer** (`lib/providers/`) — Riverpod providers expose reactive state to the UI. Each concern (connection status, game state, triggers, aliases, audio, settings) has its own provider.

4. **UI layer** (`lib/ui/`) — Flutter widgets that render the terminal, status bar, controls, and settings screens. The terminal view renders `StyledLine` objects with proper ANSI colors and attributes.

### Data Flow

```
Server  ──TCP──▶  ConnectionService  ──TelnetEvents──▶  OutputParser
                                                            │
                                              StyledLines + GameState
                                                            │
                                              ▼             ▼
                                        TriggerEngine   Providers
                                              │             │
                                     highlight/gag     notify UI
                                              │             │
                                              ▼             ▼
                                         TerminalView   StatusBar
```

User commands flow in the reverse direction:

```
InputBar  ──text──▶  AliasEngine  ──expanded commands──▶  ConnectionService  ──TCP──▶  Server
```

## Configuration

### Triggers

Triggers match regex patterns against incoming MUD output and perform client-side actions. Configure them from the toolbar (highlight icon) or in code via `TriggerRule`.

| Action              | Description                                       |
|---------------------|---------------------------------------------------|
| `highlight`         | Colorize matched text (foreground, background, bold) |
| `playSound`         | Play an audio file on match                       |
| `highlightAndSound` | Both highlight and play sound                     |
| `gag`               | Suppress the line from display                    |

Triggers never send commands to the server. This is enforced by design to comply with Ancient Anguish rules.

### Aliases

Aliases expand a short keyword into a longer command before it is sent to the server. Configure them from the toolbar (short text icon) or in code via `AliasRule`.

**Variable substitution:**
- `$0` — everything after the keyword
- `$1`, `$2`, ... — individual space-separated arguments

**Default aliases:**

| Keyword | Expansion              | Description                     |
|---------|------------------------|---------------------------------|
| `ga`    | `get all`              | Pick up all items               |
| `gac`   | `get all from corpse`  | Loot a corpse                   |
| `sc`    | `score`                | Show character score             |
| `eq`    | `equipment`            | Show worn equipment              |
| `hp`    | `health`               | Show health status               |
| `k`     | `kill $1`              | Kill a target (e.g., `k goblin`) |
| `c`     | `cast $0`              | Cast a spell (e.g., `c fireball at goblin`) |

### Prompt Setup

The client automatically configures your in-game prompt on login. By default it requests HP, Max HP, SP, Max SP, and coordinates — the minimum needed for the status bar and area detection.

**Advanced Customization** (Settings > Advanced Customization) lets you add more prompt elements. The client dynamically builds and sends the `prompt set` command based on your selections, and new HUD panels appear for each category:

| Category   | Elements                                      | HUD Panel              |
|------------|-----------------------------------------------|------------------------|
| Combat     | Aim, Attack, Defend, Wimpy, Wimpy Dir         | Combat readiness       |
| Experience | XP/min, Session XP, Session XP/min            | XP tracker with trends |
| Character  | Level, Race, Class, Age                       | Character card         |
| Wealth     | Coins, Banks                                  | Wealth display         |
| World      | Game Time, Reboot                             | World clock            |
| Survival   | Hunger, Thirst, Drunk, Poison, etc. (donator) | Color-coded conditions |

The prompt command is resent automatically if you change your selections while connected.

### Themes

Three themes are available in Settings:

- **RPG Dark** — Gold and parchment tones on dark wood. The default.
- **Classic Dark** — Green-on-black classic terminal look.
- **High Contrast** — Yellow and cyan on black for accessibility.

## Dependencies

| Package              | Purpose                     |
|----------------------|-----------------------------|
| `flutter_riverpod`   | Reactive state management   |
| `go_router`          | Navigation                  |
| `just_audio`         | Audio playback              |
| `audio_session`      | Audio session management    |
| `hive_ce`            | Local persistence (NoSQL)   |
| `json_annotation`    | JSON serialization          |
| `path_provider`      | Platform-specific file paths|
| `equatable`          | Value equality              |

Dev dependencies: `build_runner`, `riverpod_generator`, `json_serializable`, `hive_ce_generator`.

## Glossary

See [GLOSSARY.md](GLOSSARY.md) for a full reference of domain-specific terminology used in the codebase, covering telnet protocol, ANSI rendering, game state, client automation, areas, and architecture.

## License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for details.
