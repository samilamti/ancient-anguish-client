#!/usr/bin/env ruby
# Configure code signing on a single target/configuration in an Xcode project.
#
# Passing signing settings (PROVISIONING_PROFILE_SPECIFIER in particular) on
# the xcodebuild command line applies them to every target, including
# CocoaPods static libs and aggregate targets that can't carry a provisioning
# profile. Instead, write the settings directly into the Runner target's
# build configuration and leave the xcodebuild command line untouched.
#
# Usage:
#   configure-xcode-signing.rb <project_path> <target_name> <config_name> \
#     <team_id> <identity> <profile_name>
#
# Relies on the `xcodeproj` Ruby gem, which is installed by CocoaPods on
# macOS GitHub Actions runners.

require 'xcodeproj'

if ARGV.length != 6
  STDERR.puts "Usage: #{$PROGRAM_NAME} <project> <target> <config> <team_id> <identity> <profile_name>"
  exit 1
end

project_path, target_name, config_name, team_id, identity, profile_name = ARGV

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }
raise "Target '#{target_name}' not found in #{project_path}" unless target

changed = false
target.build_configurations.each do |config|
  next unless config.name == config_name

  config.build_settings['DEVELOPMENT_TEAM'] = team_id
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['CODE_SIGN_IDENTITY'] = identity
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = profile_name

  # Strip any SDK-conditional identity overrides — they fight with the
  # unconditional CODE_SIGN_IDENTITY we just set.
  config.build_settings.delete('CODE_SIGN_IDENTITY[sdk=iphoneos*]')
  config.build_settings.delete('CODE_SIGN_IDENTITY[sdk=macosx*]')

  changed = true
  puts "Configured #{target_name}/#{config_name}:"
  puts "  DEVELOPMENT_TEAM              = #{team_id}"
  puts "  CODE_SIGN_STYLE               = Manual"
  puts "  CODE_SIGN_IDENTITY            = #{identity}"
  puts "  PROVISIONING_PROFILE_SPECIFIER = #{profile_name}"
end

raise "Configuration '#{config_name}' not found on target '#{target_name}'" unless changed

project.save
