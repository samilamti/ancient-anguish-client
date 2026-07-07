#!/usr/bin/env python3
"""Generate lib/core/known_locations.dart from the official accessible map.

Usage:
    python3 scripts/compass/gen_locations.py [path-to-accessiblemap.html]

Downloads https://ancient.anguish.org/gameplay/accessiblemap.html when no
local path is given. A snapshot of the page is kept next to this script so
regeneration works offline and diffs against upstream changes are visible.

The page lists every named location with map-room coordinates centered on
Tantallon (0, 0), x positive east, y positive north — the same coordinate
system the game reports through the CLIENT prompt line.
"""

import html
import re
import sys
import urllib.request
from pathlib import Path

PAGE_URL = "https://ancient.anguish.org/gameplay/accessiblemap.html"
REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = REPO_ROOT / "lib" / "core" / "known_locations.dart"
SNAPSHOT = Path(__file__).resolve().parent / "accessiblemap.html"

LOCATION_RE = re.compile(r"^(.*?)\s+(-?\d+),\s*(-?\d+)$")
SECTION_RE = re.compile(r'<a name="([a-z_]+)">([^<]+)</a>')

# Ordered (pattern, kind) rules — first match wins. Kind names must match
# the LocationKind enum in lib/models/known_location.dart.
KIND_RULES = [
    (
        r"\b(tomb|crypt|labyrinth|dungeon|ruins?|ruined|abandoned|shipwreck"
        r"|battlefield|haunted|excavation)\b",
        "ruin",
    ),
    (r"\bcity of\b", "city"),
    (r"\b(village|hamlet|thorp|community|commune)\b", "village"),
    (r"\b(bridge|ferry)\b", "bridge"),
    (r"\b(guild|academy|hall)\b", "hall"),
    (r"\b(temple|shrine|monastery|convent|monolith)\b", "temple"),
    (r"\b(caves?|caverns|tunnels?|mines?|quarry|pit|den)\b", "cave"),
    (r"\b(camp|encampment|steading|nomads)\b", "camp"),
    (
        r"\b(castle|fortress|stronghold|fort|palace|citadel|keep|tower)\b",
        "fortress",
    ),
    (r"\b(farm|garden|windmill|orchard|farmyard)\b", "farm"),
    (
        r"\b(inn|restaurant|house|home|cottage|manor|estates?"
        r"|dwelling|orphanage|igloo|hut|rest)\b",
        "dwelling",
    ),
    (
        r"\b(beach|island|isle|point|lighthouse|shipyard|sanctuary)\b",
        "coast",
    ),
    (
        r"\b(forest|woods?|glen|thicket|bog|preserve|grove|ring|mount)\b",
        "nature",
    ),
]


def classify(name: str) -> str:
    lowered = name.lower()
    for pattern, kind in KIND_RULES:
        if re.search(pattern, lowered):
            return kind
    return "landmark"


def display_name(name: str) -> str:
    """Compact label for the compass: drop articles and 'the X of' framing."""
    n = name.strip()
    n = re.sub(r"^(the|a|an)\s+", "", n, flags=re.IGNORECASE)
    m = re.match(
        r"^(?:city|village|hamlet|thorp|town|community|island state) of (.+)$",
        n,
        flags=re.IGNORECASE,
    )
    # Keep the full phrase when the remainder isn't a proper name
    # ("the hamlet of the sunbird tribe" reads wrong as "the sunbird tribe").
    if m and not m.group(1).lower().startswith("the "):
        return m.group(1)
    m = re.match(
        r"^(?:\w+ )?bridge across (?:the )?(?:river )?(.+?)(?: river)?$",
        n,
        flags=re.IGNORECASE,
    )
    if m:
        river = m.group(1)
        return f"{river[0].upper()}{river[1:]} bridge"
    return f"{n[0].upper()}{n[1:]}"


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main() -> None:
    if len(sys.argv) > 1:
        raw = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    elif SNAPSHOT.exists():
        raw = SNAPSHOT.read_text(encoding="utf-8", errors="replace")
    else:
        with urllib.request.urlopen(PAGE_URL) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        SNAPSHOT.write_text(raw, encoding="utf-8")

    locations = []
    section = None
    for line in raw.splitlines():
        header = SECTION_RE.search(line)
        if header:
            section = header.group(1)
            continue
        # Location lines only appear inside the per-region sections.
        if section in (None, "overview", "anguish", "islands", "infidian"):
            continue
        text = html.unescape(re.sub(r"<[^>]+>", "", line)).strip()
        m = LOCATION_RE.match(text)
        if not m:
            continue
        name, x, y = m.group(1).strip(), int(m.group(2)), int(m.group(3))
        locations.append((name, x, y, classify(name)))

    if len(locations) < 100:
        sys.exit(f"Parsed only {len(locations)} locations — page layout changed?")

    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "// Source: https://ancient.anguish.org/gameplay/accessiblemap.html",
        "// Regenerate with: python3 scripts/compass/gen_locations.py",
        "",
        "import '../models/known_location.dart';",
        "",
        "/// Every named location on the official map, in map-room coordinates",
        "/// centered on Tantallon (0, 0). x grows east, y grows north.",
        "const List<KnownLocation> kKnownLocations = [",
    ]
    for name, x, y, kind in locations:
        lines.append(
            f"  KnownLocation({dart_str(name)}, {dart_str(display_name(name))}, "
            f"{x}, {y}, LocationKind.{kind}),"
        )
    lines += ["];", ""]

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {len(locations)} locations to {OUT_PATH}")


if __name__ == "__main__":
    main()
