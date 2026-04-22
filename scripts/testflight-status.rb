#!/usr/bin/env ruby
# Query App Store Connect API for recent builds (TestFlight + App Store state).
#
# Credentials:
#   - .p8 key auto-discovered at "AppStore Connect Stuff for Ancient Anguish Client/AuthKey_*.p8"
#     (override with ASC_KEY_PATH env var).
#   - Key ID derived from the AuthKey_<KEYID>.p8 filename (override with ASC_KEY_ID env var).
#   - Issuer ID MUST be provided via env var ASC_ISSUER_ID, or a local untracked
#     file at ".asc/issuer_id" (one line, no newline).
#
# Usage:
#   ruby scripts/testflight-status.rb                    # most recent 10 builds
#   ruby scripts/testflight-status.rb --limit 5
#   ruby scripts/testflight-status.rb --version 6.10.0   # only builds for this version
#   ruby scripts/testflight-status.rb --json             # raw JSON output
require "openssl"
require "json"
require "base64"
require "net/http"
require "uri"
require "optparse"
require "time"

ROOT = File.expand_path("..", __dir__)
BUNDLE_ID_DEFAULT = "org.ancientanguish.ancientAnguishClient"

opts = { limit: 10, version: nil, bundle: BUNDLE_ID_DEFAULT, json: false }
OptionParser.new do |o|
  o.on("--limit N", Integer) { |v| opts[:limit] = v }
  o.on("--version V")        { |v| opts[:version] = v }
  o.on("--bundle ID")        { |v| opts[:bundle] = v }
  o.on("--json")             { opts[:json] = true }
end.parse!

# --- resolve credentials -----------------------------------------------------

key_path = ENV["ASC_KEY_PATH"]
if key_path.nil? || key_path.empty?
  found = Dir.glob(File.join(ROOT, "AppStore Connect Stuff*", "AuthKey_*.p8"))
  key_path = found.first
end
abort "No .p8 key found. Set ASC_KEY_PATH or place AuthKey_<id>.p8 under AppStore Connect Stuff/..." if key_path.nil?
abort "Key file does not exist: #{key_path}" unless File.exist?(key_path)

key_id = ENV["ASC_KEY_ID"]
if key_id.nil? || key_id.empty?
  m = File.basename(key_path).match(/AuthKey_([A-Z0-9]+)\.p8/)
  key_id = m && m[1]
end
abort "Could not determine ASC_KEY_ID" if key_id.nil? || key_id.empty?

issuer_id = ENV["ASC_ISSUER_ID"]
if issuer_id.nil? || issuer_id.empty?
  issuer_file = File.join(ROOT, ".asc", "issuer_id")
  issuer_id = File.read(issuer_file).strip if File.exist?(issuer_file)
end
if issuer_id.nil? || issuer_id.empty?
  abort <<~MSG
    ASC_ISSUER_ID is not set.

    Either export it in this shell:
      export ASC_ISSUER_ID=<uuid-from-appstoreconnect.apple.com/access/api>

    Or create a local untracked file:
      mkdir -p .asc && echo '<uuid>' > .asc/issuer_id
      echo '.asc/' >> .gitignore
  MSG
end

# --- JWT (ES256) -------------------------------------------------------------

def b64url(str)
  Base64.urlsafe_encode64(str).gsub("=", "")
end

def ecdsa_der_to_jws(der)
  # OpenSSL ECDSA signatures are DER(SEQUENCE { INTEGER r, INTEGER s }).
  # JWS ES256 needs the raw 32-byte r || s concatenation.
  asn1 = OpenSSL::ASN1.decode(der)
  r = asn1.value[0].value.to_s(2)
  s = asn1.value[1].value.to_s(2)
  r = ("\x00" * (32 - r.bytesize)) + r if r.bytesize < 32
  s = ("\x00" * (32 - s.bytesize)) + s if s.bytesize < 32
  r + s
end

def make_jwt(key_pem, key_id, issuer_id)
  header  = { alg: "ES256", kid: key_id, typ: "JWT" }
  payload = { iss: issuer_id, iat: Time.now.to_i, exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" }
  signing_input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"

  ec = OpenSSL::PKey::EC.new(key_pem)
  digest = OpenSSL::Digest::SHA256.new
  der = ec.dsa_sign_asn1(digest.digest(signing_input))
  sig = ecdsa_der_to_jws(der)

  "#{signing_input}.#{b64url(sig)}"
end

jwt = make_jwt(File.read(key_path), key_id, issuer_id)

# --- API helpers -------------------------------------------------------------

API = "https://api.appstoreconnect.apple.com/v1"

def api_get(path, jwt)
  uri = URI.parse(path.start_with?("http") ? path : "#{API}#{path}")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{jwt}"
  req["Accept"]        = "application/json"
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  unless res.code.to_i == 200
    abort "ASC API #{res.code}: #{res.body}"
  end
  JSON.parse(res.body)
end

# --- query -------------------------------------------------------------------

# 1. Find the app by bundle ID.
apps = api_get("/apps?filter[bundleId]=#{URI.encode_www_form_component(opts[:bundle])}", jwt)
app = apps.dig("data", 0)
abort "No app found for bundle ID #{opts[:bundle]}" if app.nil?
app_id = app["id"]

# 2. List recent builds for that app.
build_query = [
  "filter[app]=#{app_id}",
  "sort=-uploadedDate",
  "limit=#{opts[:limit]}",
  "include=buildBundles,preReleaseVersion,buildBetaDetail",
]
build_query << "filter[preReleaseVersion.version]=#{URI.encode_www_form_component(opts[:version])}" if opts[:version]
builds = api_get("/builds?#{build_query.join('&')}", jwt)

if opts[:json]
  puts JSON.pretty_generate(builds)
  exit
end

# 3. Pretty-print.

included = (builds["included"] || []).each_with_object({}) { |r, h| h["#{r['type']}/#{r['id']}"] = r }

puts "=== TestFlight / App Store build status ==="
puts "  app: #{app.dig('attributes', 'name')} (#{opts[:bundle]})"
puts ""

rows = (builds["data"] || []).map do |b|
  attrs = b["attributes"] || {}
  version_rel = b.dig("relationships", "preReleaseVersion", "data")
  version = version_rel && included["#{version_rel['type']}/#{version_rel['id']}"]&.dig("attributes", "version")
  beta_rel = b.dig("relationships", "buildBetaDetail", "data")
  beta = beta_rel && included["#{beta_rel['type']}/#{beta_rel['id']}"]&.dig("attributes")

  [
    version || "?",
    attrs["version"] || "?",                    # build number
    attrs["processingState"] || "?",
    (beta && beta["externalBuildState"]) || "-",
    (beta && beta["internalBuildState"]) || "-",
    attrs["uploadedDate"] || "?",
    attrs["expired"] ? "expired" : "",
  ]
end

if rows.empty?
  puts "  (no builds found)"
  exit
end

color = ->(state) do
  case state
  when /SUCCEEDED|APPROVED|READY_FOR_BETA_TESTING|IN_BETA_TESTING/ then "\e[32m"
  when /FAILED|REJECTED|INVALID/                                   then "\e[31m"
  when /PROCESSING|WAITING/                                        then "\e[36m"
  else "\e[0m"
  end
end

printf "  %-10s %-8s %-12s %-28s %-28s %-20s %s\n",
       "version", "build", "processing", "external", "internal", "uploaded", ""
rows.each do |version, build, proc_state, ext, int, uploaded, expired|
  uploaded_short = uploaded.sub(/T.*/, "")
  printf "  %-10s %-8s %s%-12s\e[0m %s%-28s\e[0m %s%-28s\e[0m %-20s %s\n",
         version, build,
         color.(proc_state), proc_state,
         color.(ext), ext,
         color.(int), int,
         uploaded_short, expired
end
