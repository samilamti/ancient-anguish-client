#!/usr/bin/env bash
# Repair missing symlinks inside macOS versioned framework bundles.
#
# Some Flutter/Dart frameworks (notably objective_c.framework) ship with
# a versioned-bundle layout but get embedded into the app without the
# top-level symlinks Apple's App Store validator requires:
#
#   Framework.framework/
#   ├── Framework        (symlink -> Versions/Current/Framework)
#   ├── Resources        (symlink -> Versions/Current/Resources)
#   ├── Headers          (symlink -> Versions/Current/Headers)   [if present]
#   ├── Modules          (symlink -> Versions/Current/Modules)   [if present]
#   └── Versions/
#       ├── A/
#       └── Current      (symlink -> A)
#
# App Store validation fails with ITMS-90291 when these are missing.
# This script walks every .framework bundle inside the given app and
# re-creates whichever symlinks are absent.
#
# Usage:
#   fix-framework-symlinks.sh <path-to-.app-or-directory-containing-frameworks>

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path-to-.app-or-frameworks-dir>"
  exit 1
fi

TARGET="$1"

# Resolve the Frameworks directory regardless of whether an .app bundle or
# a Frameworks directory was passed.
if [ -d "$TARGET/Contents/Frameworks" ]; then
  FRAMEWORKS_DIR="$TARGET/Contents/Frameworks"
elif [ -d "$TARGET" ] && [[ "$TARGET" == *Frameworks* ]]; then
  FRAMEWORKS_DIR="$TARGET"
else
  echo "No Frameworks directory found at $TARGET"
  exit 0
fi

echo "Scanning frameworks in: $FRAMEWORKS_DIR"

fix_symlink() {
  local framework_dir="$1"
  local link_name="$2"
  local link_target="$3"

  if [ -L "$framework_dir/$link_name" ]; then
    return 0  # Already present
  fi

  # Remove any non-symlink of the same name, then create the symlink
  if [ -e "$framework_dir/$link_name" ]; then
    echo "    WARNING: $link_name exists but is not a symlink — leaving it alone"
    return 0
  fi

  (cd "$framework_dir" && ln -s "$link_target" "$link_name")
  echo "    Created symlink: $link_name -> $link_target"
}

# Iterate all .framework bundles (shallow — nested frameworks are rare)
shopt -s nullglob
for framework in "$FRAMEWORKS_DIR"/*.framework; do
  [ -d "$framework" ] || continue
  name=$(basename "$framework" .framework)

  if [ ! -d "$framework/Versions" ]; then
    # Not a versioned bundle; nothing to do
    continue
  fi

  echo "  ${name}.framework (versioned bundle)"

  # Determine the "current" version directory (typically "A")
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
    (cd "$framework/Versions" && ln -s "$current_version" Current)
    echo "    Created symlink: Versions/Current -> $current_version"
  fi

  # Top-level binary symlink
  if [ -f "$framework/Versions/$current_version/$name" ]; then
    fix_symlink "$framework" "$name" "Versions/Current/$name"
  fi

  # Top-level Resources / Headers / Modules symlinks
  for dir_name in Resources Headers Modules; do
    if [ -d "$framework/Versions/$current_version/$dir_name" ]; then
      fix_symlink "$framework" "$dir_name" "Versions/Current/$dir_name"
    fi
  done
done

echo "Framework symlink repair complete"
