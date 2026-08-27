#!/usr/bin/env ruby
# Ship the current version to the PUBLIC App Store (iOS + macOS).
#
# This is the every-release driver. It replaces the old copy-the-script-per-
# version habit (`create-v6_16_0.rb` and friends, kept only as history):
#
#   ruby scripts/asc/asc-release.rb                      # dry run, version from pubspec
#   ruby scripts/asc/asc-release.rb --apply              # stage the release, do not submit
#   ruby scripts/asc/asc-release.rb --apply --submit     # stage it and send to App Review
#   ruby scripts/asc/asc-release.rb 6.43.0 --apply --platform IOS
#
# Per platform it will:
#   1. retarget the editable AppStoreVersion to <version> (or create one)
#   2. set the en-US "What's New" from `App Store Whats New v<version>.md`
#   3. attach the newest VALID, unexpired build for that version + platform
#   4. PREFLIGHT every requirement Apple checks, and refuse to submit if one
#      is missing — a failed submit leaves a dangling reviewSubmission that
#      every later attempt then 409s against, so it is cheaper to catch first
#   5. submit for review, only with --submit
#
# Metadata that does not change per release (description, keywords, support
# URLs, review contact, screenshots) is deliberately left ALONE: it is carried
# forward on the version record Apple hands us. Use asc-screenshots.rb to
# replace shots and the Console for one-off copy edits.
#
# Credentials follow the sibling scripts: .p8 auto-discovered under
# "<repo>/AppStore Connect Stuff*/AuthKey_*.p8" (ASC_KEY_PATH overrides), Key
# ID from the filename (ASC_KEY_ID), issuer from ASC_ISSUER_ID or .asc/issuer_id.

require "openssl"
require "json"
require "base64"
require "net/http"
require "uri"
require "optparse"
require "time"

ROOT = File.expand_path("../..", __dir__)
APP_ID = "6762239633"
COPYRIGHT = "2026 Sami Xavier Lamti"
RELEASE_TYPE = "AFTER_APPROVAL"
LOCALE = "en-US"
PLATFORMS = %w[IOS MAC_OS].freeze

# States in which Apple still lets us edit a version record. Anything else
# (READY_FOR_SALE, WAITING_FOR_REVIEW, IN_REVIEW) must be left untouched.
EDITABLE_STATES = %w[
  PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED
  METADATA_REJECTED INVALID_BINARY
].freeze

# Screenshot sets Apple requires before it will accept a submission. An empty
# set is the single most common reason a submit fails late.
REQUIRED_SHOTS = {
  "IOS" => %w[APP_IPHONE_65 APP_IPAD_PRO_3GEN_129],
  "MAC_OS" => %w[APP_DESKTOP],
}.freeze

opts = { apply: false, submit: false, platform: nil, verbose: false }
parser = OptionParser.new do |o|
  o.banner = "Usage: asc-release.rb [version] [--apply] [--submit] [--platform IOS|MAC_OS]"
  o.on("--apply", "perform the changes (default: report only)") { opts[:apply] = true }
  o.on("--submit", "also send to App Review (requires --apply)") { opts[:submit] = true }
  o.on("--platform P", "limit to one platform") { |v| opts[:platform] = v }
  o.on("-v", "--verbose", "log every request") { opts[:verbose] = true }
end
parser.parse!

APPLY = opts[:apply]
SUBMIT = opts[:submit]
VERBOSE = opts[:verbose]
TAG = APPLY ? "" : " [dry-run]"

def pubspec_version
  line = File.readlines(File.join(ROOT, "pubspec.yaml")).find { |l| l.start_with?("version:") }
  line && line.split(":", 2)[1].strip.split("+").first
end

VERSION_STRING = (ARGV.shift || pubspec_version)
abort parser.banner if VERSION_STRING.nil? || VERSION_STRING.empty?
abort "--submit requires --apply" if SUBMIT && !APPLY

WHATS_NEW_PATH = File.join(ROOT, "App Store Whats New v#{VERSION_STRING}.md")
WHATS_NEW = File.exist?(WHATS_NEW_PATH) ? File.read(WHATS_NEW_PATH, encoding: "UTF-8").strip : nil

targets = opts[:platform] ? [opts[:platform]] : PLATFORMS

# ---- Credentials & JWT -----------------------------------------------------

def load_credentials
  key_path = ENV["ASC_KEY_PATH"]
  if key_path.nil? || key_path.empty?
    key_path = Dir.glob(File.join(ROOT, "AppStore Connect Stuff*", "AuthKey_*.p8")).first
  end
  abort "No .p8 key found. Set ASC_KEY_PATH." if key_path.nil? || !File.exist?(key_path)
  key_id = ENV["ASC_KEY_ID"]
  key_id = File.basename(key_path)[/AuthKey_(.+)\.p8/, 1] if key_id.nil? || key_id.empty?
  issuer = ENV["ASC_ISSUER_ID"]
  if issuer.nil? || issuer.empty?
    f = File.join(ROOT, ".asc", "issuer_id")
    issuer = File.read(f).strip if File.exist?(f)
  end
  abort "ASC_ISSUER_ID not set and .asc/issuer_id missing" if issuer.nil? || issuer.empty?
  [File.read(key_path), key_id, issuer]
end

KEY_PEM, KEY_ID, ISSUER_ID = load_credentials

def b64url(str)
  Base64.urlsafe_encode64(str).gsub("=", "")
end

def ecdsa_der_to_jws(der)
  asn1 = OpenSSL::ASN1.decode(der)
  r = asn1.value[0].value.to_s(2)
  s = asn1.value[1].value.to_s(2)
  r = ("\x00" * (32 - r.bytesize)) + r if r.bytesize < 32
  s = ("\x00" * (32 - s.bytesize)) + s if s.bytesize < 32
  r + s
end

def bearer
  # Re-minted per call: a long screenshot-free run still outlives a 10-minute
  # token if Apple is slow, and a mid-run 401 reads like a bad key.
  header = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
  payload = { iss: ISSUER_ID, iat: Time.now.to_i, exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" }
  signing_input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"
  ec = OpenSSL::PKey::EC.new(KEY_PEM)
  der = ec.dsa_sign_asn1(OpenSSL::Digest::SHA256.new.digest(signing_input))
  "#{signing_input}.#{b64url(ecdsa_der_to_jws(der))}"
end

def api(method, path, body = nil, raise_on_error = true)
  uri = URI.parse(path.start_with?("http") ? path : "https://api.appstoreconnect.apple.com#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }[method]
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{bearer}"
  req["Accept"] = "application/json"
  if body
    req["Content-Type"] = "application/json"
    req.body = body.to_json
  end
  warn "    #{method.to_s.upcase} #{uri.path}#{uri.query ? "?#{uri.query}" : ""}" if VERBOSE
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 90) { |h| h.request(req) }
  parsed = res.body.to_s.empty? ? {} : (JSON.parse(res.body) rescue { "raw" => res.body })
  unless res.code.to_i.between?(200, 299)
    return { "_error" => true, "_code" => res.code.to_i, "_body" => res.body.to_s[0, 900] } unless raise_on_error
    abort "#{method.to_s.upcase} #{uri.path} → #{res.code}\n#{res.body.to_s[0, 900]}"
  end
  parsed
end

def mutate(method, path, body, summary)
  puts "    → #{summary}#{TAG}"
  return nil unless APPLY
  res = api(method, path, body, false)
  abort "    ✗ #{summary} → #{res['_code']}: #{res['_body']}" if res.is_a?(Hash) && res["_error"]
  res
end

# ---- Lookups ---------------------------------------------------------------

def all_versions
  api(:get, "/v1/apps/#{APP_ID}/appStoreVersions?limit=200")["data"] || []
end

def editable_version(versions, platform)
  versions.find do |v|
    a = v["attributes"]
    a["platform"] == platform && EDITABLE_STATES.include?(a["appStoreState"])
  end
end

def live_version(versions, platform)
  versions.find do |v|
    a = v["attributes"]
    a["platform"] == platform && a["appStoreState"] == "READY_FOR_SALE"
  end
end

def latest_build(platform)
  q = [
    "filter[app]=#{APP_ID}",
    "filter[preReleaseVersion.version]=#{URI.encode_www_form_component(VERSION_STRING)}",
    "filter[preReleaseVersion.platform]=#{platform}",
    "filter[processingState]=VALID",
    "sort=-uploadedDate",
    "limit=20",
  ]
  builds = api(:get, "/v1/builds?#{q.join('&')}")["data"] || []
  builds.reject { |b| b.dig("attributes", "expired") == true }.first
end

def localization(version_id)
  locs = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")["data"] || []
  locs.find { |l| l.dig("attributes", "locale") == LOCALE }
end

# Screenshot sets hang off the LOCALIZATION, not the version — and
# `?include=appScreenshots` reports an empty set because the included
# resources carry no owning-set relationship. Enumerate per set instead.
def screenshot_counts(localization_id)
  sets = api(:get, "/v1/appStoreVersionLocalizations/#{localization_id}/appScreenshotSets")["data"] || []
  counts = {}
  sets.each do |s|
    shots = api(:get, "/v1/appScreenshotSets/#{s['id']}/appScreenshots")["data"] || []
    counts[s.dig("attributes", "screenshotDisplayType")] = shots.length
  end
  counts
end

# ---- Phases ----------------------------------------------------------------

def retarget_version(versions, platform)
  existing = editable_version(versions, platform)
  if existing
    current = existing.dig("attributes", "versionString")
    if current == VERSION_STRING
      puts "    version record #{VERSION_STRING} already editable (#{existing.dig('attributes', 'appStoreState')})"
    else
      mutate(:patch, "/v1/appStoreVersions/#{existing['id']}", {
        data: { type: "appStoreVersions", id: existing["id"],
                attributes: { versionString: VERSION_STRING, copyright: COPYRIGHT, releaseType: RELEASE_TYPE } },
      }, "retarget editable #{platform} record #{current} → #{VERSION_STRING}")
    end
    return existing["id"]
  end

  res = mutate(:post, "/v1/appStoreVersions", {
    data: {
      type: "appStoreVersions",
      attributes: { platform: platform, versionString: VERSION_STRING,
                    copyright: COPYRIGHT, releaseType: RELEASE_TYPE },
      relationships: { app: { data: { type: "apps", id: APP_ID } } },
    },
  }, "create #{platform} version #{VERSION_STRING}")
  res ? res.dig("data", "id") : "(dry-run)"
end

def set_whats_new(version_id)
  if WHATS_NEW.nil?
    puts "    ! no #{File.basename(WHATS_NEW_PATH)} — leaving What's New unchanged"
    return
  end
  if WHATS_NEW.length > 4000
    abort "    ✗ What's New is #{WHATS_NEW.length} chars (limit 4000)"
  end
  return puts "    → set What's New (#{WHATS_NEW.length} chars)#{TAG}" if version_id.start_with?("(dry-run")

  loc = localization(version_id)
  abort "    ✗ no #{LOCALE} localization on #{version_id}" if loc.nil?
  if loc.dig("attributes", "whatsNew").to_s.strip == WHATS_NEW
    puts "    What's New already matches (#{WHATS_NEW.length} chars)"
    return
  end
  mutate(:patch, "/v1/appStoreVersionLocalizations/#{loc['id']}", {
    data: { type: "appStoreVersionLocalizations", id: loc["id"], attributes: { whatsNew: WHATS_NEW } },
  }, "set What's New (#{WHATS_NEW.length} chars)")
end

def attach_build(version_id, build)
  if build.nil?
    puts "    ! no VALID unexpired build for #{VERSION_STRING} — cannot attach"
    return false
  end
  puts "    build #{build.dig('attributes', 'version')} (uploaded #{build.dig('attributes', 'uploadedDate')})"
  return true if version_id.start_with?("(dry-run")
  mutate(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build", {
    data: { type: "builds", id: build["id"] },
  }, "attach build #{build.dig('attributes', 'version')}")
  true
end

# Everything Apple checks, checked before we ask. A submit that fails leaves a
# dangling open reviewSubmission which 409s every retry, so the cheap read
# beats the expensive write.
def preflight(version_id, platform)
  return ["(dry-run: version not created yet)"] if version_id.start_with?("(dry-run")
  problems = []

  ver = api(:get, "/v1/appStoreVersions/#{version_id}")
  state = ver.dig("data", "attributes", "appStoreState")
  problems << "version state is #{state}, not editable" unless EDITABLE_STATES.include?(state)

  build = api(:get, "/v1/appStoreVersions/#{version_id}/relationships/build", nil, false)
  problems << "no build attached" if build.is_a?(Hash) && build.dig("data", "id").nil?

  loc = localization(version_id)
  if loc.nil?
    problems << "no #{LOCALE} localization"
  else
    a = loc["attributes"]
    problems << "description is empty" if a["description"].to_s.strip.empty?
    problems << "keywords are empty" if a["keywords"].to_s.strip.empty?
    problems << "What's New is empty" if a["whatsNew"].to_s.strip.empty?
    counts = screenshot_counts(loc["id"])
    REQUIRED_SHOTS.fetch(platform, []).each do |type|
      n = counts[type].to_i
      problems << "screenshot set #{type} has #{n} shots" if n.zero?
    end
  end

  rd = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", nil, false)
  problems << "no App Review contact details" if rd.is_a?(Hash) && rd["data"].nil?

  problems
end

def submit_for_review(version_id, platform)
  puts "    → submit #{platform} for App Review#{TAG}"
  return if !APPLY || version_id.start_with?("(dry-run")

  rs = api(:post, "/v1/reviewSubmissions", {
    data: { type: "reviewSubmissions", attributes: { platform: platform },
            relationships: { app: { data: { type: "apps", id: APP_ID } } } },
  }, false)
  if rs.is_a?(Hash) && rs["_error"]
    # Only one open submission per app+platform: adopt the existing one rather
    # than failing, so a re-run after a partial failure completes the job.
    abort "    ✗ reviewSubmissions POST → #{rs['_code']}: #{rs['_body']}" unless rs["_code"] == 409
    open = (api(:get, "/v1/apps/#{APP_ID}/reviewSubmissions?filter[state]=READY_FOR_REVIEW&limit=50")["data"] || [])
           .find { |s| s.dig("attributes", "platform") == platform }
    abort "    ✗ 409 on create but no open READY_FOR_REVIEW submission found" if open.nil?
    puts "    adopting open reviewSubmission #{open['id'][0, 8]}"
    rsid = open["id"]
  else
    rsid = rs.dig("data", "id")
    puts "    reviewSubmission #{rsid[0, 8]} created"
  end

  it = api(:post, "/v1/reviewSubmissionItems", {
    data: { type: "reviewSubmissionItems",
            relationships: {
              reviewSubmission: { data: { type: "reviewSubmissions", id: rsid } },
              appStoreVersion: { data: { type: "appStoreVersions", id: version_id } },
            } },
  }, false)
  if it.is_a?(Hash) && it["_error"] && it["_code"] != 409
    abort "    ✗ reviewSubmissionItems POST → #{it['_code']}: #{it['_body']}"
  end

  sub = api(:patch, "/v1/reviewSubmissions/#{rsid}", {
    data: { type: "reviewSubmissions", id: rsid, attributes: { submitted: true } },
  }, false)
  abort "    ✗ reviewSubmissions PATCH → #{sub['_code']}: #{sub['_body']}" if sub.is_a?(Hash) && sub["_error"]
  puts "    ✓ submitted — state=#{sub.dig('data', 'attributes', 'state')}"
end

# ---- Run -------------------------------------------------------------------

puts "App Store release #{VERSION_STRING}#{APPLY ? '' : ' (dry run)'}"
puts "  app #{APP_ID} · platforms #{targets.join(', ')} · submit=#{SUBMIT}"
puts "  What's New: #{WHATS_NEW ? "#{WHATS_NEW.length} chars from #{File.basename(WHATS_NEW_PATH)}" : 'MISSING'}"

versions = all_versions
blocked = false

targets.each do |platform|
  puts "\n[#{platform}]"
  live = live_version(versions, platform)
  puts "    live: #{live ? live.dig('attributes', 'versionString') : '(none)'}"

  version_id = retarget_version(versions, platform)
  set_whats_new(version_id)
  attach_build(version_id, latest_build(platform))

  problems = preflight(version_id, platform)
  if problems.empty?
    puts "    ✓ preflight clean"
  elsif APPLY
    blocked = true
    problems.each { |p| puts "    ✗ #{p}" }
  else
    # Nothing above was actually written, so these describe the record as it
    # stands now — the staged changes are what fix them.
    puts "    - preflight (pre-change state): #{problems.join('; ')}"
  end
end

if SUBMIT
  if blocked
    puts "\nNOT submitting — preflight found problems above."
    exit 1
  end
  versions = all_versions
  targets.each do |platform|
    puts "\n[#{platform}] submitting"
    v = editable_version(versions, platform)
    abort "no editable #{platform} version to submit" if v.nil?
    submit_for_review(v["id"], platform)
  end
  puts "\nSubmitted for review. Apple will email on state changes; releaseType=#{RELEASE_TYPE}."
else
  puts APPLY ? "\nStaged. Re-run with --submit to send to App Review." : "\nDry run only."
end
