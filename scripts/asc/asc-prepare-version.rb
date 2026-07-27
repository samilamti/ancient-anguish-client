#!/usr/bin/env ruby
# Upsert an editable AppStoreVersion (iOS + macOS) so metadata and
# screenshots can be edited. Creates the version in PREPARE_FOR_SUBMISSION
# and sets the en-US "What's New" text.
#
# It never submits anything for review, never attaches a build, and never
# touches a READY_FOR_SALE version.
#
# Credentials match the sibling scripts (.p8 under "AppStore Connect Stuff*",
# issuer from ASC_ISSUER_ID or .asc/issuer_id).
#
# Usage:
#   ruby scripts/asc/asc-prepare-version.rb 6.32.0            # dry run
#   ruby scripts/asc/asc-prepare-version.rb 6.32.0 --apply
#   ruby scripts/asc/asc-prepare-version.rb 6.32.0 --apply --platform IOS
#
# What's New copy lives in `App Store Whats New v<version>.md` at the repo
# root; without it the version is created but whatsNew is left alone.

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

options = { apply: false, platform: nil, verbose: false }
parser = OptionParser.new do |o|
  o.banner = "Usage: asc-prepare-version.rb <version> [--apply] [--platform IOS|MAC_OS]"
  o.on("--apply", "Perform the changes (default: report only)") { options[:apply] = true }
  o.on("--platform P", "Limit to one platform") { |v| options[:platform] = v }
  o.on("-v", "--verbose", "Log every request") { options[:verbose] = true }
end
parser.parse!
VERSION_STRING = ARGV.shift
abort parser.banner if VERSION_STRING.nil? || VERSION_STRING.empty?

WHATS_NEW_PATH = File.join(ROOT, "App Store Whats New v#{VERSION_STRING}.md")
WHATS_NEW = File.exist?(WHATS_NEW_PATH) ? File.read(WHATS_NEW_PATH, encoding: "UTF-8").strip : nil

# ---- Auth (same shape as asc-screenshots.rb) --------------------------------

def load_credentials
  key_path = ENV["ASC_KEY_PATH"]
  if key_path.nil? || key_path.empty?
    key_path = Dir.glob(File.join(ROOT, "AppStore Connect Stuff*", "AuthKey_*.p8")).first
  end
  abort "No .p8 key found. Set ASC_KEY_PATH." if key_path.nil? || !File.exist?(key_path)
  key_id = ENV["ASC_KEY_ID"]
  key_id = File.basename(key_path)[/AuthKey_(.+)\.p8/, 1] if key_id.nil? || key_id.empty?
  abort "Could not derive Key ID from #{key_path}" if key_id.nil?
  issuer = ENV["ASC_ISSUER_ID"]
  if issuer.nil? || issuer.empty?
    f = File.join(ROOT, ".asc", "issuer_id")
    issuer = File.read(f).strip if File.exist?(f)
  end
  abort "No issuer id. Set ASC_ISSUER_ID or .asc/issuer_id." if issuer.nil? || issuer.empty?
  [key_path, key_id, issuer]
end

KEY_PATH, KEY_ID, ISSUER_ID = load_credentials

def bearer
  @bearer ||= begin
    now = Time.now.to_i
    header = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
    claims = { iss: ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" }
    signing_input = [header, claims]
      .map { |p| Base64.urlsafe_encode64(JSON.dump(p), padding: false) }.join(".")
    key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
    der = key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
    r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
    "#{signing_input}.#{Base64.urlsafe_encode64(r + s, padding: false)}"
  end
end

BASE = "https://api.appstoreconnect.apple.com"

def api(method, path, body = nil)
  uri = URI("#{BASE}#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{bearer}"
  req["Content-Type"] = "application/json"
  req.body = JSON.dump(body) if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  warn "  #{method.to_s.upcase} #{path} -> #{res.code}" if $VERBOSE_HTTP
  unless res.code.to_i.between?(200, 299)
    abort "#{method.to_s.upcase} #{path} failed (#{res.code}): #{res.body}"
  end
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end
$VERBOSE_HTTP = options[:verbose]

# ---- Work ------------------------------------------------------------------

puts "App #{APP_ID} — version #{VERSION_STRING} — " \
     "#{options[:apply] ? 'APPLY' : 'DRY RUN (pass --apply to write)'}"
puts WHATS_NEW ? "What's New: #{WHATS_NEW.length} chars from #{File.basename(WHATS_NEW_PATH)}"
              : "What's New: (no file at #{File.basename(WHATS_NEW_PATH)} — leaving unset)"
puts

existing = (api(:get, "/v1/apps/#{APP_ID}/appStoreVersions?limit=200")["data"] || [])

PLATFORMS.each do |platform|
  next if options[:platform] && options[:platform] != platform

  match = existing.find do |v|
    v.dig("attributes", "platform") == platform &&
      v.dig("attributes", "versionString") == VERSION_STRING
  end

  if match
    state = match.dig("attributes", "appStoreState")
    puts "#{platform}: #{VERSION_STRING} already exists (#{state})"
    version_id = match["id"]
  else
    puts "#{platform}: create #{VERSION_STRING} (PREPARE_FOR_SUBMISSION)"
    next unless options[:apply]
    created = api(:post, "/v1/appStoreVersions", {
      data: {
        type: "appStoreVersions",
        attributes: {
          platform: platform,
          versionString: VERSION_STRING,
          copyright: COPYRIGHT,
          releaseType: RELEASE_TYPE,
        },
        relationships: { app: { data: { type: "apps", id: APP_ID } } },
      },
    })
    version_id = created.dig("data", "id")
    puts "   created #{version_id}"
  end

  next unless options[:apply] && version_id && WHATS_NEW

  locs = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations?limit=200")["data"] || []
  loc = locs.find { |l| l.dig("attributes", "locale") == LOCALE }
  if loc
    api(:patch, "/v1/appStoreVersionLocalizations/#{loc['id']}", {
      data: {
        type: "appStoreVersionLocalizations", id: loc["id"],
        attributes: { whatsNew: WHATS_NEW },
      },
    })
    puts "   #{LOCALE}: whatsNew updated"
  else
    api(:post, "/v1/appStoreVersionLocalizations", {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: { locale: LOCALE, whatsNew: WHATS_NEW },
        relationships: {
          appStoreVersion: { data: { type: "appStoreVersions", id: version_id } },
        },
      },
    })
    puts "   #{LOCALE}: localization created with whatsNew"
  end
end

puts
puts options[:apply] ? "Done. Nothing was submitted for review." : "Dry run only."
