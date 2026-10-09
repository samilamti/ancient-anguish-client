#!/usr/bin/env ruby
# Withdraw a version from App Review (iOS + macOS), so a newer one can be
# submitted in its place.
#
#   ruby scripts/asc/asc-withdraw.rb 6.46.0             # dry run: list what would be cancelled
#   ruby scripts/asc/asc-withdraw.rb 6.46.0 --apply     # cancel the review submissions
#
# Apple allows one version in flight per platform, so while 6.46.0 sits in
# WAITING_FOR_REVIEW a 6.47.0 cannot even be created. Cancelling the review
# submission returns the version to DEVELOPER_REJECTED, an editable state,
# which asc-release.rb then retargets to the new version string and reuses
# (screenshots and review contact carry over).
#
# Only submissions whose version matches the one named are touched; the
# version string is required on purpose, so this can never cancel "whatever
# happens to be in review". IN_REVIEW is included: Apple accepts a cancel
# there too, it just takes longer to settle.
require "optparse"
require "time"

ROOT = File.expand_path("../..", __dir__)
APP_ID = "6762239633"
OPEN_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES READY_FOR_REVIEW].freeze

opts = { apply: false, verbose: false }
parser = OptionParser.new do |o|
  o.banner = "Usage: asc-withdraw.rb <version> [--apply]"
  o.on("--apply", "cancel the submissions (default: report only)") { opts[:apply] = true }
  o.on("-v", "--verbose", "log every request") { opts[:verbose] = true }
end
parser.parse!
VERBOSE = opts[:verbose]
VERSION_STRING = ARGV.shift
abort parser.banner if VERSION_STRING.nil? || VERSION_STRING.empty?

require_relative "lib/asc_client"

subs = api(:get, "/v1/apps/#{APP_ID}/reviewSubmissions" \
                 "?filter[state]=#{OPEN_STATES.join(',')}" \
                 "&include=appStoreVersionForReview&limit=50")
versions = (subs["included"] || []).select { |r| r["type"] == "appStoreVersions" }
                                    .to_h { |r| [r["id"], r["attributes"]] }

targets = (subs["data"] || []).map do |s|
  vid = s.dig("relationships", "appStoreVersionForReview", "data", "id")
  v = versions[vid]
  next unless v && v["versionString"] == VERSION_STRING
  { id: s["id"], state: s["attributes"]["state"], platform: s["attributes"]["platform"],
    version_id: vid }
end.compact

if targets.empty?
  puts "No open review submission for #{VERSION_STRING}."
  exit 0
end

puts "Withdraw #{VERSION_STRING}#{opts[:apply] ? '' : ' (dry run)'}"
targets.each { |t| puts "  [#{t[:platform]}] submission #{t[:id][0, 8]} #{t[:state]}" }
exit 0 unless opts[:apply]

targets.each do |t|
  res = api(:patch, "/v1/reviewSubmissions/#{t[:id]}",
            { data: { type: "reviewSubmissions", id: t[:id], attributes: { canceled: true } } },
            false)
  abort "  ✗ cancel #{t[:platform]} → #{res['_code']}: #{res['_body']}" if res["_error"]
  puts "  → [#{t[:platform]}] cancel requested (#{res.dig('data', 'attributes', 'state')})"
end

# Settling is asynchronous. Wait for each version to become editable again,
# since that is the state the next submit actually needs.
deadline = Time.now + 240
pending = targets.dup
until pending.empty? || Time.now > deadline
  sleep 10
  pending.reject! do |t|
    state = api(:get, "/v1/appStoreVersions/#{t[:version_id]}")
              .dig("data", "attributes", "appStoreState")
    done = state == "DEVELOPER_REJECTED"
    puts "  ✓ [#{t[:platform]}] #{VERSION_STRING} is #{state}" if done
    done
  end
end
unless pending.empty?
  pending.each { |t| puts "  … [#{t[:platform]}] still settling; re-run to check" }
  exit 1
end
