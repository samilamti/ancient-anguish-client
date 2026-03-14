---
name: add-area-config
description: Add or update area configuration (coordinates, background image, music) in the unified Area Configuration.md file. Usage: /add-area-config <area-name>
---

# Add Area Configuration

Add or update an area's configuration in the unified `Area Configuration.md` file, which lives at `{appDocuments}/AncientAnguishClient/Area Configuration.md`.

## Context

The unified area config uses heading-per-area Markdown format. Each area has subsections for Coordinates, Backgrounds, and Music. The file also has a `# Battle Themes` section at the end.

Key file: `lib/services/config/unified_area_config_manager.dart` (parsing/saving logic).

## Steps

1. **Gather info from user** (if not provided):
   - Area name (must match what `AreaDetector` or coordinate config returns)
   - Coordinates (x, y) — optional, only if the area has a fixed coordinate
   - Background image path(s) — file path to image(s) for terminal background
   - Music track path(s) — file path to audio file(s) for area music
   - Whether it's a town area (affects music delay behavior)

2. **Find the config file**
   - Read `UnifiedAreaConfigManager` to understand the exact file format
   - The file path uses `path_provider`'s `getApplicationDocumentsDirectory()` + `AncientAnguishClient/Area Configuration.md`

3. **Check area_definitions.json** (`assets/data/area_definitions.json`)
   - Verify the area name exists in the definitions
   - If adding a town, check/set the `theme: "town"` field
   - Show the user existing coordinate bounds if any

4. **Edit the config file**
   - If area heading exists: update its subsections
   - If new area: add a new `## <Area Name>` section with subsections
   - Multiple backgrounds/music: list one per line under the subsection
   - Format:
     ```
     ## Area Name
     ### Coordinates
     x, y
     ### Backgrounds
     C:\path\to\image1.jpg
     C:\path\to\image2.jpg
     ### Music
     C:\path\to\track1.mp3
     C:\path\to\track2.mp3
     ```

5. **Validate**
   - Verify referenced files exist on disk
   - Run `flutter analyze` to catch any issues
   - Remind user to restart the app or trigger a config reload for changes to take effect

## Multi-track Behavior

- Areas with 1 music track: loops continuously
- Areas with 2+ music tracks: plays sequentially (non-looping), advances on track finish via `advanceMusicCycle()`
- Town areas have a 5-second delay before music starts (prevents rapid switching through portals)

## Reference Files

- Config manager: `lib/services/config/unified_area_config_manager.dart`
- Area detector: `lib/services/area/area_detector.dart`
- Area definitions: `assets/data/area_definitions.json`
- Audio provider: `lib/providers/audio_provider.dart` (town delay, playlist logic)
