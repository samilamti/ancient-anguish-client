#!/usr/bin/env bash
# Repair macOS framework bundles to match Apple's required versioned layout.
#
# Apple's App Store validator (ITMS-90291) requires every macOS .framework
# to follow the versioned-bundle pattern:
#
#   Framework.framework/
#   ├── Framework        (symlink -> Versions/Current/Framework)
#   ├── Resources        (symlink -> Versions/Current/Resources)
#   └── Versions/
#       ├── A/
#       │   ├── Framework
#       │   └── Resources/
#       └── Current      (symlink -> A)
#
# Some Flutter/Dart frameworks (notably objective_c.framework) arrive as
# flat bundles or as versioned bundles with missing symlinks. This script
# handles both cases:
#
#   1. Flat bundles (no Versions/ dir) → converted to versioned layout
#   2. Versioned bundles with missing symlinks → symlinks added
#   3. Top-level items that are real files/dirs instead of symlinks →
#      moved into Versions/A/ and replaced with symlinks
#
# Usage:
#   fix-framework-symlinks.sh <path-to-.app-or-directory-containing-frameworks>

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path-to-.app-or-frameworks-dir>"
  exit 1
fi

TARGET="$1"

# Resolve the Frameworks directory
if [ -d "$TARGET/Contents/Frameworks" ]; then
  FRAMEWORKS_DIR="$TARGET/Contents/Frameworks"
elif [ -d "$TARGET" ] && [[ "$TARGET" == *Frameworks* ]]; then
  FRAMEWORKS_DIR="$TARGET"
else
  echo "No Frameworks directory found at $TARGET"
  exit 0
fi

echo "Scanning frameworks in: $FRAMEWORKS_DIR"

shopt -s nullglob
for framework in "$FRAMEWORKS_DIR"/*.framework; do
  [ -d "$framework" ] || continue
  name=$(basename "$framework" .framework)

  # ── Case 1: flat bundle → convert to versioned layout ──────────
  if [ ! -d "$framework/Versions" ]; then
    # Check if this looks like a framework at all (has a binary or Resources)
    has_binary=false
    has_resources=false
    [ -f "$framework/$name" ] && has_binary=true
    [ -d "$framework/Resources" ] && has_resources=true

    if ! $has_binary && ! $has_resources; then
      # Nothing recognizable; skip
      continue
    fi

    echo "  ${name}.framework (flat → converting to versioned)"

    # Create the versioned directory structure
    mkdir -p "$framework/Versions/A"

    # Move everything except Versions into Versions/A
    for item in "$framework"/*; do
      item_name=$(basename "$item")
      [ "$item_name" = "Versions" ] && continue
      mv "$item" "$framework/Versions/A/"
    done

    # Create Versions/Current symlink
    (cd "$framework/Versions" && ln -s A Current)

    # Create top-level symlinks for everything in Versions/A
    for item in "$framework/Versions/A"/*; do
      item_name=$(basename "$item")
      (cd "$framework" && ln -s "Versions/Current/$item_name" "$item_name")
      echo "    Created symlink: $item_name -> Versions/Current/$item_name"
    done
    continue
  fi

  # ── Case 2: versioned bundle → ensure symlinks exist ───────────
  echo "  ${name}.framework (versioned bundle)"

  # Find the real version directory (typically "A")
  current_version=""
  for v in "$framework/Versions"/*; do
    vname=$(basename "$v")
    [ "$vname" = "Current" ] && continue
    [ -d "$v" ] || continue
    current_version="$vname"
    break
  done

  if [ -z "$current_version" ]; then
    echo "    WARNING: no version directory found, skipping"
    continue
  fi

  # Versions/Current -> A
  if [ ! -L "$framework/Versions/Current" ]; then
    if [ -e "$framework/Versions/Current" ]; then
      rm -rf "$framework/Versions/Current"
    fi
    (cd "$framework/Versions" && ln -s "$current_version" Current)
    echo "    Created symlink: Versions/Current -> $current_version"
  fi

  # Fix each top-level item: binary, Resources, Headers, Modules
  items_to_fix=("$name" Resources Headers Modules)
  for item_name in "${items_to_fix[@]}"; do
    src="$framework/Versions/$current_version/$item_name"

    # The source must exist in the versioned directory
    [ -e "$src" ] || continue

    target_path="$framework/$item_name"

    if [ -L "$target_path" ]; then
      # Already a symlink; nothing to do
      continue
    fi

    if [ -e "$target_path" ]; then
      # Exists as a real file/dir — this is the problem Apple flags.
      # Move it into Versions/A if it's not already there, then symlink.
      if [ -e "$src" ]; then
        # Source already exists in Versions; just remove the top-level copy
        rm -rf "$target_path"
      else
        # Move it into Versions/A
        mv "$target_path" "$src"
      fi
    fi

    # Create the symlink
    (cd "$framework" && ln -s "Versions/Current/$item_name" "$item_name")
    echo "    Created symlink: $item_name -> Versions/Current/$item_name"
  done
done

echo "Framework symlink repair complete"
