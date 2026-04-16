#!/usr/bin/env ruby
# Add a "Fix Framework Symlinks" Run Script build phase to the Runner target.
#
# Apple's App Store validator (ITMS-90291) requires every macOS .framework
# to follow the versioned-bundle pattern with top-level symlinks. Some
# Flutter/Dart frameworks (objective_c.framework) get embedded without them.
#
# This script injects a build phase that runs INSIDE xcodebuild's process
# (after embedding) to fix the symlinks before the archive is sealed.
#
# Usage:
#   add-framework-fix-build-phase.rb <project.xcodeproj>
#
# Safe to run multiple times — skips if the phase already exists.

require 'xcodeproj'

project_path = ARGV[0] || abort("Usage: #{$PROGRAM_NAME} <project.xcodeproj>")

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }
abort "Target 'Runner' not found" unless target

PHASE_NAME = 'Fix Framework Symlinks'

# Don't add twice
if target.shell_script_build_phases.any? { |p| p.name == PHASE_NAME }
  puts "#{PHASE_NAME} phase already exists — skipping"
  exit 0
end

phase = target.new_shell_script_build_phase(PHASE_NAME)
phase.shell_script = <<~'SCRIPT'
  # Fix versioned macOS framework bundle symlinks for App Store validation.
  # ITMS-90291 requires Resources (and other dirs) to be symlinks into
  # Versions/Current, not real directories.
  FW_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  [ -d "$FW_DIR" ] || exit 0

  for framework in "$FW_DIR"/*.framework; do
    [ -d "$framework" ] || continue
    name=$(basename "$framework" .framework)

    # ── Flat bundle: restructure into versioned layout ──
    if [ ! -d "$framework/Versions" ]; then
      [ -f "$framework/$name" ] || [ -d "$framework/Resources" ] || continue
      mkdir -p "$framework/Versions/A"
      for item in "$framework"/*; do
        [ "$(basename "$item")" = "Versions" ] && continue
        mv "$item" "$framework/Versions/A/"
      done
      (cd "$framework/Versions" && ln -s A Current)
      for item in "$framework/Versions/A"/*; do
        (cd "$framework" && ln -s "Versions/Current/$(basename "$item")" "$(basename "$item")")
      done
      echo "  Converted flat bundle: ${name}.framework"
      continue
    fi

    # ── Versioned bundle: ensure top-level symlinks ──
    cv=""
    for v in "$framework/Versions"/*; do
      vn=$(basename "$v"); [ "$vn" = "Current" ] && continue
      [ -d "$v" ] && cv="$vn" && break
    done
    [ -z "$cv" ] && continue

    [ -L "$framework/Versions/Current" ] || \
      (cd "$framework/Versions" && ln -sf "$cv" Current)

    for item_name in "$name" Resources Headers Modules; do
      [ -e "$framework/Versions/$cv/$item_name" ] || continue
      if [ ! -L "$framework/$item_name" ]; then
        rm -rf "$framework/$item_name"
        (cd "$framework" && ln -s "Versions/Current/$item_name" "$item_name")
        echo "  Fixed ${name}.framework/$item_name -> Versions/Current/$item_name"
      fi
    done
  done
SCRIPT

# Move to end of build phases (after Embed Frameworks)
target.build_phases.delete(phase)
target.build_phases << phase

project.save
puts "Added '#{PHASE_NAME}' build phase to Runner target (runs after Embed Frameworks)"
