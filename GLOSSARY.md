# Ancient Anguish Client — Glossary

A reference of domain-specific terminology used throughout the codebase.

---

## Telnet Protocol

Terms from the telnet protocol implementation (RFC 854/855). See `lib/protocol/telnet/`.

- **IAC** — Interpret As Command (byte 255). Marks the start of a telnet command sequence. Every telnet command begins with IAC.
- **WILL** — Sender agrees to (or offers to) perform an option.
- **WONT** — Sender refuses to perform an option.
- **DO** — Sender requests the other party to perform an option.
- **DONT** — Sender requests the other party to stop performing an option.
- **Negotiation** — The WILL/WONT/DO/DONT handshake used to agree on which telnet options are active for a session.
- **SB** — Subnegotiation Begin. Starts a data payload for a specific option (e.g., sending window size).
- **SE** — Subnegotiation End. Terminates a subnegotiation sequence.
- **Subnegotiation** — Option-specific data exchange between IAC SB and IAC SE (e.g., sending terminal dimensions or GMCP messages).
- **GA** — Go Ahead. Signals the other end that it may transmit. Mostly obsolete; suppressed via SGA.
- **EOR** — End of Record. Marks the end of a logical record in the data stream.
- **NOP** — No Operation. A keep-alive or padding command.
- **AYT** — Are You There. Requests a visible confirmation that the connection is alive.
- **IP** — Interrupt Process. Requests the server to interrupt the currently running process.
- **AO** — Abort Output. Requests the server to discard buffered output.
- **BRK** — Break. Sends a break signal.
- **EC** — Erase Character. Requests deletion of the last character sent.
- **EL** — Erase Line. Requests deletion of the current line.
- **SGA** — Suppress Go-Ahead (RFC 858). Disables the GA signal, enabling full-duplex communication. Nearly always active.
- **ECHO** — Echo option (RFC 857). When the server enables ECHO, the client stops local echo (used for password entry).
- **NAWS** — Negotiate About Window Size (RFC 1073). Sends the terminal's column and row dimensions to the server.
- **TTYPE** — Terminal Type (RFC 1091). Sends a terminal identifier string. This client sends `ANCIENT-ANGUISH-CLIENT`.
- **Linemode** — Linemode option (RFC 1184). Controls whether the client sends data line-by-line or character-by-character.
- **MCCP2** — MUD Client Compression Protocol version 2 (option 86). Compresses server-to-client data using zlib.
- **MCCP3** — MUD Client Compression Protocol version 3 (option 87). An updated compression protocol.
- **GMCP** — Generic MUD Communication Protocol (option 201, also called ATCP2). Sends structured out-of-band data (JSON) between client and server for game state, room info, etc.

---

## ANSI & Terminal Display

Terms related to text styling and terminal rendering. See `lib/protocol/ansi/` and `lib/core/theme/`.

- **ANSI escape sequence** — A special byte sequence starting with ESC (`\x1B`) used to control text formatting and cursor behavior.
- **CSI** — Control Sequence Introducer (`ESC[`). The prefix for most ANSI formatting commands.
- **SGR** — Select Graphic Rendition. The ANSI command (`ESC[...m`) that sets text attributes like color, bold, and underline.
- **Foreground** — The text color. Set via SGR codes 30–37 (standard), 90–97 (bright), 38;5;n (256-color), or 38;2;r;g;b (truecolor).
- **Background** — The color behind text. Set via SGR codes 40–47, 100–107, 48;5;n, or 48;2;r;g;b.
- **Bold** — Increased font weight (SGR code 1). Often also brightens the foreground color.
- **Dim** — Reduced intensity (SGR code 2).
- **Italic** — Italic text style (SGR code 3).
- **Underline** — Underlined text (SGR code 4).
- **Inverse** — Swaps foreground and background colors (SGR code 7).
- **Strikethrough** — Text with a horizontal line through it (SGR code 9).
- **Reset** — Clears all text attributes back to defaults (SGR code 0).
- **16-color palette** — The standard ANSI color set: 8 normal colors (black, red, green, yellow, blue, magenta, cyan, white) plus 8 bright variants.
- **256-color palette** — Extended color set: 16 standard + 216 colors from a 6×6×6 RGB cube + 24 grayscale shades. Selected via `38;5;n` / `48;5;n`.
- **Truecolor (24-bit)** — Full RGB color support. Selected via `38;2;r;g;b` / `48;2;r;g;b`.
- **StyledSpan** — A segment of text with associated style attributes (colors, bold, italic, etc.). Defined in `lib/protocol/ansi/styled_span.dart`.
- **StyledLine** — A complete line of terminal output composed of one or more StyledSpans.
- **Scrollback** — The buffer of previously displayed lines that the user can scroll through. Configured in `lib/core/constants.dart` (default: 10,000 lines).

---

## Game State & Vitals

Terms for character stats and game data parsed from MUD output. See `lib/models/game_state.dart` and `lib/services/parser/prompt_parser.dart`.

- **HP** — Hit Points. The character's current health.
- **MaxHP** — Maximum Hit Points. The upper limit for HP.
- **SP** — Spell Points. The character's current magical energy (mana).
- **MaxSP** — Maximum Spell Points. The upper limit for SP.
- **XP** — Experience Points. A cumulative measure of the character's progress.
- **Coins** — The character's in-game currency.
- **PlayerName** — The character's name as reported by the server.
- **PlayerClass** — The character's class (e.g., fighter, mage).
- **Coordinates (X, Y)** — The character's position in the MUD world grid, used for area detection.
- **Prompt** — A special line of MUD output (typically at the end of each command response) that contains game state data like HP and SP.
- **Basic prompt pattern** — The standard prompt format: `HP/MaxHP:SP/MaxSP>` (e.g., `125/125:80/80>`).
- **CLIENT line** — An extended prompt format specific to Ancient Anguish: `CLIENT:X:{x}:Y:{y}:{name}:{class}:{coins}:{xp}`. Provides additional game state data for client-side features.
- **GameState** — The Dart model that aggregates all parsed vitals, coordinates, and character info.

---

## Client Automation

Terms for triggers and aliases that automate client-side behavior. See `lib/models/trigger_rule.dart`, `lib/models/alias_rule.dart`, and `lib/services/`.

- **Trigger** — A rule that watches MUD output for a regex pattern and performs a client-side action when matched. Triggers never auto-send commands to the server (per Ancient Anguish rules).
- **TriggerAction** — The action a trigger performs: `highlight`, `playSound`, `highlightAndSound`, or `gag`.
- **Pattern** — A regular expression used by a trigger to match text in MUD output.
- **Highlight** — A trigger action that colorizes matched text with a specified foreground, background, and/or bold style.
- **Gag** — A trigger action that suppresses (hides) a matching line from the terminal display.
- **playSound** — A trigger action that plays an audio file when the pattern matches.
- **highlightAndSound** — A trigger action that both highlights matched text and plays a sound.
- **highlightWholeLine** — A trigger option that applies highlighting to the entire line rather than just the matched text.
- **Alias** — A shortcut that expands a short keyword into one or more longer commands before sending to the server.
- **Keyword** — The short text the user types to activate an alias (e.g., `k` for kill).
- **Expansion** — The template that replaces the keyword. Supports variable substitution and semicolons for command chaining.
- **Variable substitution** — Placeholders in alias expansions: `$0` = all arguments after the keyword, `$1` = first argument, `$2` = second argument, etc.
- **Command chaining** — Using semicolons in an alias expansion to send multiple commands in sequence.
- **Recursion prevention** — Alias expansion enforces a maximum depth of 10 to prevent infinite loops.

---

## Areas & Audio

Terms for spatial detection and immersive audio. See `lib/models/area_config.dart`, `lib/services/area/`, and `lib/services/audio/`.

- **Area** — A named region of the MUD world defined by coordinate bounds and/or text patterns, optionally associated with background audio.
- **AreaBounds** — An axis-aligned bounding box (xMin, xMax, yMin, yMax) that defines an area's geographic extent.
- **Area detection** — The process of determining the player's current area. Uses coordinates first, then falls back to text pattern matching against room descriptions.
- **Area audio** — Background music or ambient sound that plays while the player is in a specific area.
- **Crossfade** — A smooth volume transition when switching between area audio tracks. Configured by duration in milliseconds.
- **Tantallon** — The main starting town in Ancient Anguish. Detected by coordinate bounds and text patterns like "Town Square" and "Main Street of Tantallon".
- **Wilderness** — Outdoor areas outside of towns. Detected by text patterns like "dusty road", "grassy plain", "forest path".

---

## Connection & Networking

Terms for socket management and connection lifecycle. See `lib/models/connection_info.dart` and `lib/services/connection/connection_service.dart`.

- **Socket** — The underlying TCP connection to the MUD server.
- **TCP** — Transmission Control Protocol. The transport layer used for telnet connections.
- **Host** — The server address. Default: `ancient.anguish.org`.
- **Port** — The server port number. Default: `2222`.
- **ConnectionStatus** — The state of the connection: `disconnected`, `connecting`, `connected`, `disconnecting`, or `error`.
- **Stream** — The Dart async stream of bytes received from the socket, processed through the telnet and ANSI parsers.
- **Timeout** — The connection attempt timeout (default: 15 seconds).
- **Reconnect** — Re-establishing the socket connection after a disconnect.

---

## Architecture

Terms describing the client's software architecture. See `lib/` directory structure.

- **Provider** — A Riverpod state container that manages reactive state and notifies the UI of changes. Found in `lib/providers/`.
- **Service** — A business-logic class that encapsulates a specific concern (connection, parsing, audio, etc.). Found in `lib/services/`.
- **Engine** — A core processing class that evaluates rules against input. The trigger engine matches patterns; the alias engine expands keywords. Found in `lib/services/trigger/` and `lib/services/alias/`.
- **Parser** — A class that transforms raw data into structured output. Includes the ANSI parser (escape sequences to styled spans), output parser (bytes to lines), and prompt parser (game state extraction). Found in `lib/protocol/ansi/` and `lib/services/parser/`.
- **Ring buffer** — A fixed-size circular buffer used for efficient scrollback storage. Defined in `lib/core/utils/ring_buffer.dart`.
- **Output processing pipeline** — The chain of transformations applied to incoming data: raw TCP bytes → UTF-8 decode → line splitting → telnet command extraction → ANSI parsing → StyledLines for display.
