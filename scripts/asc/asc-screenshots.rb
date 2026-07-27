#!/usr/bin/env ruby
# Inspect or replace the App Store screenshot sets for an app's *editable*
# version, per platform and display type.
#
# Unlike the one-shot release scripts next to it, this one is version-
# agnostic: it finds whichever AppStoreVersion is still editable and works on
# that. It never creates or submits a version.
#
# Credentials match the sibling scripts:
#   - .p8 auto-discovered at "<repo>/AppStore Connect Stuff*/AuthKey_*.p8"
#     (override with ASC_KEY_PATH); Key ID derived from the filename
#   - Issuer ID from ASC_ISSUER_ID or .asc/issuer_id
#
# Usage:
#   ruby scripts/asc/asc-screenshots.rb                    # show current state
#   ruby scripts/asc/asc-screenshots.rb --apply            # replace from disk
#   ruby scripts/asc/asc-screenshots.rb --platform IOS
#
# Source files are the newest timestamped capture per scene in
# screenshots/{ios,macos}/, matched by filename suffix. Ordering follows
# SCENE_ORDER so the store listing reads as a narrative.

require "openssl"
require "json"
require "base64"
require "net/http"
require "uri"
require "optparse"
require "time"
require "digest"

ROOT = File.expand_path("../..", __dir__)
APP_ID = "6762239633"

# Which local directory + filename suffix feeds each ASC display type.
SCREENSHOT_SLOTS = [
  { platform: "IOS",    type: "APP_IPHONE_65",
    dir: File.join(ROOT, "screenshots", "ios"),   suffix: "-iphone-6.5.png" },
  { platform: "IOS",    type: "APP_IPAD_PRO_3GEN_129",
    dir: File.join(ROOT, "screenshots", "ios"),   suffix: "-ipad-13.png" },
  { platform: "MAC_OS", type: "APP_DESKTOP",
    dir: File.join(ROOT, "screenshots", "macos"), suffix: "-macos.png" },
].freeze

# Narrative order for the listing. Scenes absent for a slot are skipped.
SCENE_ORDER = %w[terminal hints kill recent rules].freeze

options = { apply: false, platform: nil, verbose: false }
OptionParser.new do |o|
  o.on("--apply", "Perform the replacement (default: report only)") { options[:apply] = true }
  o.on("--platform PLATFORM", "IOS or MAC_OS (default: both)") { |v| options[:platform] = v }
  o.on("-v", "--verbose", "Log every request") { options[:verbose] = true }
end.parse!

# ---- Auth ------------------------------------------------------------------

def load_credentials
  key_path = ENV["ASC_KEY_PATH"]
  if key_path.nil? || key_path.empty?
    key_path = Dir.glob(File.join(ROOT, "AppStore Connect Stuff*", "AuthKey_*.p8")).first
  end
  abort "No .p8 key found. Set ASC_KEY_PATH." if key_path.nil? || !File.exist?(key_path)

  key_id = ENV["ASC_KEY_ID"]
  if key_id.nil? || key_id.empty?
    key_id = File.basename(key_path)[/AuthKey_(.+)\.p8/, 1]
  end
  abort "Could not derive Key ID from #{key_path}" if key_id.nil?

  issuer = ENV["ASC_ISSUER_ID"]
  if issuer.nil? || issuer.empty?
    issuer_file = File.join(ROOT, ".asc", "issuer_id")
    issuer = File.read(issuer_file).strip if File.exist?(issuer_file)
  end
  abort "No issuer id. Set ASC_ISSUER_ID or .asc/issuer_id." if issuer.nil? || issuer.empty?

  [key_path, key_id, issuer]
end

KEY_PATH, KEY_ID, ISSUER_ID = load_credentials

def bearer
  @bearer ||= begin
    now = Time.now.to_i
    header = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
    claims = { iss: ISSUER_ID, iat: now, exp: now + 1200,
               aud: "appstoreconnect-v1" }
    signing_input = [header, claims]
      .map { |part| Base64.urlsafe_encode64(JSON.dump(part), padding: false) }
      .join(".")
    key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
    der = key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
    # ASN.1 DER -> raw r||s, which is what JWS ES256 expects.
    r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
    sig = Base64.urlsafe_encode64(r + s, padding: false)
    "#{signing_input}.#{sig}"
  end
end

BASE = "https://api.appstoreconnect.apple.com"

# NB: positional args only. Under Ruby 2.6 (what macOS ships) a trailing
# symbol-keyed hash is folded into keyword parameters, so an `api(..., {data:
# ...})` call would be parsed as `data:` keyword and blow up.
def api(method, path, body = nil)
  uri = URI("#{BASE}#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post,
            patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{bearer}"
  req["Content-Type"] = "application/json"
  req.body = body.is_a?(String) ? body : JSON.dump(body) if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  warn "  #{method.to_s.upcase} #{path} -> #{res.code}" if $VERBOSE_HTTP
  unless res.code.to_i.between?(200, 299)
    abort "#{method.to_s.upcase} #{path} failed (#{res.code}): #{res.body}"
  end
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end
$VERBOSE_HTTP = options[:verbose]

# ---- Discovery -------------------------------------------------------------

EDITABLE_STATES = %w[
  PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED
  INVALID_BINARY WAITING_FOR_REVIEW
].freeze

def editable_versions
  data = api(:get, "/v1/apps/#{APP_ID}/appStoreVersions?limit=200&include=appStoreVersionLocalizations")["data"] || []
  data.select { |v| EDITABLE_STATES.include?(v.dig("attributes", "appStoreState")) }
end

def localizations_for(version_id)
  api(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations?limit=200")["data"] || []
end

def screenshot_sets_for(localization_id)
  api(:get, "/v1/appStoreVersionLocalizations/#{localization_id}/appScreenshotSets?limit=200")
end

# The screenshots in a set, queried through the set's own relationship.
# Reading them from an `include=appScreenshots` sidecar does NOT work: the
# included resources don't carry the owning-set relationship, so grouping by
# it silently yields zero — which is how a "0 on store" set turned out to
# already hold Apple's maximum of ten.
def screenshots_in(set_id)
  api(:get, "/v1/appScreenshotSets/#{set_id}/appScreenshots?limit=200")["data"] || []
end

# Newest capture per scene, ordered by SCENE_ORDER.
def local_shots(dir, suffix)
  return [] unless Dir.exist?(dir)
  by_scene = {}
  Dir.glob(File.join(dir, "*#{suffix}")).sort.each do |path|
    scene = File.basename(path)[/-demo-([a-z]+)#{Regexp.escape(suffix)}\z/, 1]
    next if scene.nil?
    by_scene[scene] = path # sorted ascending, so the last wins = newest
  end
  # `map { }.compact` rather than filter_map — macOS ships Ruby 2.6.
  SCENE_ORDER.map { |s| by_scene[s] }.compact
end

# ---- Upload ----------------------------------------------------------------

def upload_screenshot(set_id, path, position)
  bytes = File.binread(path)
  reservation = api(:post, "/v1/appScreenshots", {
    data: {
      type: "appScreenshots",
      attributes: { fileName: File.basename(path), fileSize: bytes.bytesize },
      relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } } },
    },
  })

  ops = reservation.dig("data", "attributes", "uploadOperations") || []
  ops.each do |op|
    uri = URI(op["url"])
    req = Net::HTTP::Put.new(uri)
    (op["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
    req.body = bytes[op["offset"], op["length"]]
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
    abort "Chunk upload failed (#{res.code}): #{res.body}" unless res.code.to_i.between?(200, 299)
  end

  id = reservation.dig("data", "id")
  api(:patch, "/v1/appScreenshots/#{id}", {
    data: {
      type: "appScreenshots", id: id,
      attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) },
    },
  })
  id
end

# ---- Main ------------------------------------------------------------------

puts "App #{APP_ID} — #{options[:apply] ? 'APPLY' : 'DRY RUN (pass --apply to write)'}"
puts

versions = editable_versions
if versions.empty?
  abort "No editable AppStoreVersion. Create one in App Store Connect (or via " \
        "the release script) before pushing screenshots."
end

versions.each do |version|
  platform = version.dig("attributes", "platform")
  next if options[:platform] && options[:platform] != platform
  vstring = version.dig("attributes", "versionString")
  state = version.dig("attributes", "appStoreState")
  puts "=== #{platform} #{vstring} (#{state}) ==="

  slots = SCREENSHOT_SLOTS.select { |s| s[:platform] == platform }
  if slots.empty?
    puts "  (no screenshot slots configured for this platform)"
    next
  end

  localizations_for(version["id"]).each do |loc|
    locale = loc.dig("attributes", "locale")
    puts "  locale #{locale}"
    sets = screenshot_sets_for(loc["id"])
    existing = {}
    (sets["data"] || []).each do |s|
      existing[s.dig("attributes", "screenshotDisplayType")] = s["id"]
    end

    slots.each do |slot|
      files = local_shots(slot[:dir], slot[:suffix])
      set_id = existing[slot[:type]]
      current = set_id ? screenshots_in(set_id) : []
      puts "    #{slot[:type]}: #{current.size} on store -> #{files.size} local"
      files.each { |f| puts "        #{File.basename(f)}" }
      next unless options[:apply]
      if files.empty?
        puts "        (nothing local; leaving store set untouched)"
        next
      end

      if set_id
        # Clear the set first. Apple caps a set at 10 and a freshly created
        # AppStoreVersion inherits the previous version's screenshots, so
        # appending would both duplicate and hit the cap mid-run.
        current.each do |shot|
          api(:delete, "/v1/appScreenshots/#{shot['id']}")
        end
        puts "        cleared #{current.size} existing" unless current.empty?
      else
        created = api(:post, "/v1/appScreenshotSets", {
          data: {
            type: "appScreenshotSets",
            attributes: { screenshotDisplayType: slot[:type] },
            relationships: {
              appStoreVersionLocalization: {
                data: { type: "appStoreVersionLocalizations", id: loc["id"] },
              },
            },
          },
        })
        set_id = created.dig("data", "id")
      end

      files.each_with_index do |path, i|
        print "        uploading #{File.basename(path)} ... "
        upload_screenshot(set_id, path, i)
        puts "ok"
      end
    end
  end
  puts
end

puts options[:apply] ? "Done." : "Dry run only — nothing was changed."
