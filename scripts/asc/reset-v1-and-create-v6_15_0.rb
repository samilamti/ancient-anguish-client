#!/usr/bin/env ruby
# Delete the two REJECTED v1.0 App Store Connect submissions and re-create them
# as a fresh v6.15.0 pair (iOS + macOS), reading metadata from the listing
# markdown at the repo root and attaching the latest VALID v6.15.0 build per
# platform.
#
# Credentials follow the same pattern as scripts/testflight-status.rb:
#   - .p8 key auto-discovered at "AppStore Connect Stuff*/AuthKey_*.p8"
#     (override with ASC_KEY_PATH)
#   - Key ID derived from filename (override with ASC_KEY_ID)
#   - Issuer ID from env ASC_ISSUER_ID or .asc/issuer_id
#
# Usage:
#   ruby scripts/asc/reset-v1-and-create-v6_15_0.rb                 # dry-run (no mutations)
#   ruby scripts/asc/reset-v1-and-create-v6_15_0.rb --apply         # do it
#   ruby scripts/asc/reset-v1-and-create-v6_15_0.rb --apply --skip-screenshots
#   ruby scripts/asc/reset-v1-and-create-v6_15_0.rb --apply --skip-delete
#   ruby scripts/asc/reset-v1-and-create-v6_15_0.rb -v              # verbose request log

require "openssl"
require "json"
require "base64"
require "net/http"
require "uri"
require "optparse"
require "time"
require "digest"
require "fileutils"

# ---- Configuration ---------------------------------------------------------

ROOT = File.expand_path("../..", __dir__)
APP_ID = "6762239633"
VERSION_STRING = "6.15.0"
COPYRIGHT = "2026 Sami Xavier Lamti"
RELEASE_TYPE = "AFTER_APPROVAL"
LISTING_PATH = File.join(ROOT, "App Store Listings v6.15.0.md")
SNAPSHOT_DIR = File.join(ROOT, "screenshots", "v6.15.0")
SNAPSHOT_PATH = File.join(SNAPSHOT_DIR, ".snapshot-before-reset.json")
LOCALE = "en-US"

# (platform, screenshot display type, directory, filename suffix without timestamp/label)
SCREENSHOT_SLOTS = [
  { platform: "IOS",    type: "APP_IPHONE_65",         dir: File.join(ROOT, "screenshots", "ios"),    suffix: "-iphone-6.5.png" },
  { platform: "IOS",    type: "APP_IPAD_PRO_3GEN_129", dir: File.join(ROOT, "screenshots", "ios"),    suffix: "-ipad-13.png" },
  { platform: "MAC_OS", type: "APP_DESKTOP",           dir: File.join(ROOT, "screenshots", "macos"),  suffix: "-macos.png" },
]

# minOsVersion → platform disambiguator (Apple's API returns build records for
# both iOS and macOS under the same Universal-Purchase app; only minOsVersion
# distinguishes them for the same build number).
def platform_from_min_os(min_os)
  return "IOS"    if min_os.to_s.start_with?("13.")
  return "IOS"    if min_os.to_s.start_with?("14.") || min_os.to_s.start_with?("15.") || min_os.to_s.start_with?("16.") || min_os.to_s.start_with?("17.") || min_os.to_s.start_with?("18.") || min_os.to_s.start_with?("19.")
  return "MAC_OS" if min_os.to_s.start_with?("10.") || min_os.to_s.start_with?("11.") || min_os.to_s.start_with?("12.")
  nil
end

# ---- Options ---------------------------------------------------------------

opts = { apply: false, skip_delete: false, skip_screenshots: false, verbose: false }
OptionParser.new do |o|
  o.banner = "Usage: ruby #{File.basename(__FILE__)} [--apply] [--skip-delete] [--skip-screenshots] [--verbose]"
  o.on("--apply",            "Actually mutate ASC. Otherwise dry-run.") { opts[:apply] = true }
  o.on("--skip-delete",      "Skip the DELETE phase (use after a partial run).") { opts[:skip_delete] = true }
  o.on("--skip-screenshots", "Skip the screenshot upload phase.") { opts[:skip_screenshots] = true }
  o.on("-v", "--verbose",    "Log every request.") { opts[:verbose] = true }
  o.on("-h", "--help") { puts o; exit }
end.parse!

APPLY    = opts[:apply]
VERBOSE  = opts[:verbose]
DRY_TAG  = APPLY ? "" : " (dry-run)"

# ---- Credentials & JWT -----------------------------------------------------

def resolve_credentials
  key_path = ENV["ASC_KEY_PATH"]
  if key_path.nil? || key_path.empty?
    key_path = Dir.glob(File.join(ROOT, "AppStore Connect Stuff*", "AuthKey_*.p8")).first
  end
  abort "No .p8 key found. Set ASC_KEY_PATH or place AuthKey_<id>.p8 under AppStore Connect Stuff*/." if key_path.nil?
  abort "Key file does not exist: #{key_path}" unless File.exist?(key_path)

  key_id = ENV["ASC_KEY_ID"]
  if key_id.nil? || key_id.empty?
    m = File.basename(key_path).match(/AuthKey_([A-Z0-9]+)\.p8/)
    key_id = m && m[1]
  end
  abort "Could not determine ASC_KEY_ID" if key_id.nil? || key_id.empty?

  issuer_id = ENV["ASC_ISSUER_ID"]
  if issuer_id.nil? || issuer_id.empty?
    f = File.join(ROOT, ".asc", "issuer_id")
    issuer_id = File.read(f).strip if File.exist?(f)
  end
  abort "ASC_ISSUER_ID is not set (env var or .asc/issuer_id)." if issuer_id.nil? || issuer_id.empty?

  [key_path, key_id, issuer_id]
end

def b64url(s)
  Base64.urlsafe_encode64(s).gsub("=", "")
end

def ecdsa_der_to_jws(der)
  asn1 = OpenSSL::ASN1.decode(der)
  r = asn1.value[0].value.to_s(2)
  s = asn1.value[1].value.to_s(2)
  r = ("\x00".b * (32 - r.bytesize)) + r if r.bytesize < 32
  s = ("\x00".b * (32 - s.bytesize)) + s if s.bytesize < 32
  r + s
end

def make_jwt(key_pem, key_id, issuer_id)
  header  = { alg: "ES256", kid: key_id, typ: "JWT" }
  payload = { iss: issuer_id, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" }
  signing_input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"
  ec = OpenSSL::PKey::EC.new(key_pem)
  der = ec.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
  "#{signing_input}.#{b64url(ecdsa_der_to_jws(der))}"
end

KEY_PATH, KEY_ID, ISSUER_ID = resolve_credentials
JWT = make_jwt(File.read(KEY_PATH), KEY_ID, ISSUER_ID)

# ---- HTTP helpers ----------------------------------------------------------

API = "https://api.appstoreconnect.apple.com"

def http_request(method, url, body: nil, headers: {}, timeout: 60)
  uri = URI.parse(url.start_with?("http") ? url : "#{API}#{url}")
  klass = case method
          when :get    then Net::HTTP::Get
          when :post   then Net::HTTP::Post
          when :patch  then Net::HTTP::Patch
          when :delete then Net::HTTP::Delete
          when :put    then Net::HTTP::Put
          else raise "Unsupported method #{method}"
          end
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{JWT}" unless headers["Authorization"] == :none
  req["Accept"] = "application/json" unless headers["Accept"]
  headers.each do |k, v|
    next if v == :none
    req[k] = v
  end
  if body
    if body.is_a?(String)
      req.body = body
    else
      req["Content-Type"] ||= "application/json"
      req.body = JSON.dump(body)
    end
  end
  if VERBOSE
    sz = req.body ? " body=#{req.body.bytesize}B" : ""
    puts "  → #{method.to_s.upcase} #{uri.path}#{uri.query ? "?#{uri.query}" : ""}#{sz}"
  end
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: timeout, open_timeout: 15) { |h| h.request(req) }
end

def api(method, path, body: nil, raise_on_error: true)
  res = http_request(method, path, body: body)
  code = res.code.to_i
  if code >= 400
    if raise_on_error
      abort "ASC API #{method.to_s.upcase} #{path} -> #{code}\n#{res.body}"
    else
      return { "_error" => true, "_code" => code, "_body" => res.body }
    end
  end
  return nil if code == 204 || res.body.nil? || res.body.empty?
  JSON.parse(res.body)
end

def dry_or_api(method, path, body: nil, summary:)
  if APPLY
    api(method, path, body: body)
  else
    puts "  [dry-run] #{method.to_s.upcase} #{path}  — #{summary}"
    nil
  end
end

# ---- Listing parser --------------------------------------------------------

def read_listing(path)
  raw = File.read(path, encoding: "UTF-8")
  sections = raw.split(/^## /m)
  out = {}
  sections.each do |sec|
    if sec.start_with?("1.")
      out["IOS"] = parse_section(sec)
    elsif sec.start_with?("2.")
      out["MAC_OS"] = parse_section(sec)
    end
  end
  abort "Listing parse failed: missing iOS section"   unless out["IOS"]
  abort "Listing parse failed: missing macOS section" unless out["MAC_OS"]
  out
end

def parse_section(sec)
  {
    description:      extract_block(sec, "Description")     || (abort "missing Description block"),
    keywords:         extract_block(sec, "Keywords")        || (abort "missing Keywords block"),
    promotionalText:  extract_block(sec, "Promotional Text")|| (abort "missing Promotional Text block"),
    reviewerNotes:    extract_block(sec, "Reviewer Notes")  || (abort "missing Reviewer Notes block"),
    supportUrl:       extract_url(sec, "Support URL"),
    marketingUrl:     extract_url(sec, "Marketing URL"),
    privacyPolicyUrl: extract_url(sec, "Privacy Policy URL"),
  }
end

def extract_block(sec, field)
  m = sec.match(/^###\s+#{Regexp.escape(field)}.*?\n```\s*\n(.*?)\n```/m)
  m && m[1]
end

def extract_url(sec, label)
  m = sec.match(/^\s*-\s+\*\*#{Regexp.escape(label)}:\*\*\s+`([^`]+)`/)
  m && m[1]
end

# ---- ASC queries -----------------------------------------------------------

def get_versions
  api(:get, "/v1/apps/#{APP_ID}/appStoreVersions?include=build,appStoreVersionLocalizations,appStoreReviewDetail&limit=200")
end

def find_versions_by_string(versions_json, version_string, state: nil)
  (versions_json["data"] || []).select do |v|
    a = v["attributes"]
    a["versionString"] == version_string && (state.nil? || a["appStoreState"] == state || a["appVersionState"] == state)
  end
end

def find_latest_build(platform, version_string: VERSION_STRING)
  q = [
    "filter[app]=#{APP_ID}",
    "filter[preReleaseVersion.version]=#{URI.encode_www_form_component(version_string)}",
    "filter[processingState]=VALID",
    "sort=-uploadedDate",
    "limit=20",
  ]
  res = api(:get, "/v1/builds?#{q.join('&')}")
  candidates = (res["data"] || []).select do |b|
    platform_from_min_os(b.dig("attributes", "minOsVersion")) == platform &&
      b.dig("attributes", "expired") != true
  end
  candidates.first
end

# ---- Phase: snapshot -------------------------------------------------------

def snapshot_state
  puts "\n=== Phase 1: snapshot existing state ==="
  FileUtils.mkdir_p(SNAPSHOT_DIR)
  versions = get_versions
  snap = { capturedAt: Time.now.utc.iso8601, app: APP_ID, versions: [] }
  (versions["data"] || []).each do |v|
    vid = v["id"]
    attrs = v["attributes"]
    locs = api(:get, "/v1/appStoreVersions/#{vid}/appStoreVersionLocalizations")
    rev = api(:get, "/v1/appStoreVersions/#{vid}/appStoreReviewDetail", raise_on_error: false)
    rev = nil if rev.is_a?(Hash) && rev["_error"]
    sets = []
    (locs["data"] || []).each do |loc|
      ss = api(:get, "/v1/appStoreVersionLocalizations/#{loc['id']}/appScreenshotSets")
      sets << { localizationId: loc["id"], data: ss["data"] }
    end
    build_rel = v.dig("relationships", "build", "data")
    snap[:versions] << {
      id: vid,
      platform: attrs["platform"],
      versionString: attrs["versionString"],
      appStoreState: attrs["appStoreState"],
      appVersionState: attrs["appVersionState"],
      copyright: attrs["copyright"],
      releaseType: attrs["releaseType"],
      attachedBuildId: build_rel && build_rel["id"],
      localizations: locs["data"],
      screenshotSets: sets,
      reviewDetail: rev && rev["data"],
    }
    puts "  snapshotted #{attrs['platform']} v#{attrs['versionString']} (#{attrs['appStoreState']}) — #{vid[0, 8]}"
  end
  File.write(SNAPSHOT_PATH, JSON.pretty_generate(snap))
  puts "  → wrote #{SNAPSHOT_PATH} (#{File.size(SNAPSHOT_PATH)} B)"
  snap
end

# ---- Phase: delete or rename v1.0 → 6.15.0 ---------------------------------
#
# Apple blocks DELETE on any appStoreVersion whose platform has had a build
# uploaded ("STATE_ERROR: A version cannot be deleted if any build has been
# uploaded for the platform"). For each REJECTED v1.0 record, we therefore:
#   1) Try DELETE.
#   2) On 409 STATE_ERROR, fall back to PATCH versionString = "6.15.0".
# Returns a map of platform → reused-version-id (set when we renamed instead
# of deleted; nil when we successfully deleted).

def delete_or_rename_v1(snap)
  puts "\n=== Phase 2: reset v1.0 records (delete → fallback rename)#{DRY_TAG} ==="
  reused = {}
  targets = snap[:versions].select { |v| v[:versionString] == "1.0" }
  if targets.empty?
    puts "  (no v1.0 records found)"
    return reused
  end
  targets.each do |v|
    plat = v[:platform]
    puts "  → attempting DELETE #{plat} v1.0 (#{v[:appStoreState]}) #{v[:id][0,8]}"
    if !APPLY
      puts "  [dry-run] would DELETE /v1/appStoreVersions/#{v[:id]} (will fall back to rename → #{VERSION_STRING} if Apple blocks)"
      next
    end
    res = api(:delete, "/v1/appStoreVersions/#{v[:id]}", raise_on_error: false)
    if res.is_a?(Hash) && res["_error"]
      if res["_code"] == 409 && res["_body"].include?("STATE_ERROR")
        puts "    ! DELETE blocked by Apple (#{res['_code']}): #{plat} has uploaded builds. Falling back to rename."
        body = { data: { type: "appStoreVersions", id: v[:id], attributes: { versionString: VERSION_STRING, copyright: COPYRIGHT, releaseType: RELEASE_TYPE } } }
        patched = api(:patch, "/v1/appStoreVersions/#{v[:id]}", body: body)
        puts "    ✓ renamed #{v[:id][0,8]} versionString=1.0 → #{VERSION_STRING}"
        reused[plat] = v[:id]
      else
        abort "ASC API DELETE returned #{res['_code']} — #{res['_body']}"
      end
    else
      puts "    ✓ deleted #{v[:id][0,8]}"
    end
  end
  reused
end

# ---- Phase: create version + localization ---------------------------------

def upsert_version(platform, listing_section, reused: {})
  # If Phase 2 renamed an existing v1.0 record for this platform, reuse it.
  if reused[platform]
    rid = reused[platform]
    puts "  ✓ reusing renamed record #{rid[0,8]} (was v1.0)"
    return rid
  end
  vers = get_versions
  existing = find_versions_by_string(vers, VERSION_STRING).find { |v| v.dig("attributes", "platform") == platform }
  if existing
    puts "  ✓ #{platform} v#{VERSION_STRING} already exists (#{existing['id'][0,8]}); will patch in place"
    patch_body = {
      data: {
        type: "appStoreVersions",
        id: existing["id"],
        attributes: { copyright: COPYRIGHT, releaseType: RELEASE_TYPE },
      },
    }
    dry_or_api(:patch, "/v1/appStoreVersions/#{existing['id']}", body: patch_body, summary: "patch copyright/releaseType")
    return existing["id"]
  end
  puts "  → POST /v1/appStoreVersions (#{platform} v#{VERSION_STRING})"
  body = {
    data: {
      type: "appStoreVersions",
      attributes: {
        platform: platform,
        versionString: VERSION_STRING,
        copyright: COPYRIGHT,
        releaseType: RELEASE_TYPE,
      },
      relationships: {
        app: { data: { type: "apps", id: APP_ID } },
      },
    },
  }
  res = dry_or_api(:post, "/v1/appStoreVersions", body: body, summary: "create #{platform} v#{VERSION_STRING}")
  res ? res.dig("data", "id") : "(dry-run-no-id)"
end

def upsert_localization(version_id, listing_section)
  attrs = {
    locale:           LOCALE,
    description:      listing_section[:description],
    keywords:         listing_section[:keywords],
    promotionalText:  listing_section[:promotionalText],
    supportUrl:       listing_section[:supportUrl],
    marketingUrl:     listing_section[:marketingUrl],
  }
  if version_id.start_with?("(dry-run")
    puts "    [dry-run] would POST /v1/appStoreVersionLocalizations (en-US) — desc=#{attrs[:description].length}c keywords=#{attrs[:keywords].length}c promo=#{attrs[:promotionalText].length}c support=#{attrs[:supportUrl]}"
    return "(dry-run-no-loc)"
  end
  locs = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")
  existing = (locs["data"] || []).find { |l| l.dig("attributes", "locale") == LOCALE }
  if existing
    puts "    ✓ localization en-US exists (#{existing['id'][0,8]}); patching"
    body = { data: { type: "appStoreVersionLocalizations", id: existing["id"], attributes: attrs.reject { |k, _| k == :locale } } }
    dry_or_api(:patch, "/v1/appStoreVersionLocalizations/#{existing['id']}", body: body, summary: "patch en-US localization")
    existing["id"]
  else
    puts "    → POST /v1/appStoreVersionLocalizations (en-US)"
    body = {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: attrs,
        relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } },
      },
    }
    res = dry_or_api(:post, "/v1/appStoreVersionLocalizations", body: body, summary: "create en-US localization")
    res ? res.dig("data", "id") : "(dry-run-no-loc)"
  end
end

# ---- Phase: attach build ---------------------------------------------------

def attach_build(version_id, build)
  if build.nil?
    puts "    ! no VALID v#{VERSION_STRING} build to attach"
    return
  end
  bid = build["id"]
  puts "    → PATCH .../relationships/build = #{bid[0,8]} (build #{build.dig('attributes','version')}, uploaded #{build.dig('attributes','uploadedDate')})"
  return if version_id.start_with?("(dry-run")
  body = { data: { type: "builds", id: bid } }
  dry_or_api(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build", body: body, summary: "attach build #{build.dig('attributes','version')}")
end

# ---- Phase: review details -------------------------------------------------

def upsert_review_details(version_id, listing_section, snap)
  notes = listing_section[:reviewerNotes]
  existing_phone = snap[:versions].map { |v| v.dig(:reviewDetail, "attributes", "contactPhone") }.compact.first
  attrs = {
    contactFirstName: "Sami",
    contactLastName:  "Lamti",
    contactEmail:     "sami.lamti@gmail.com",
    contactPhone:     existing_phone,
    demoAccountName:     "guest",
    demoAccountPassword: "",
    demoAccountRequired: false,
    notes: notes,
  }
  if version_id.start_with?("(dry-run")
    puts "    [dry-run] would POST /v1/appStoreReviewDetails — contact=#{attrs[:contactFirstName]} #{attrs[:contactLastName]} <#{attrs[:contactEmail]}>  demoAccount=#{attrs[:demoAccountName].inspect}  notes_len=#{notes.length}"
    return
  end
  rd = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreReviewDetail", raise_on_error: false)
  rd = nil if rd.is_a?(Hash) && rd["_error"]
  if rd && rd.dig("data", "id")
    rdid = rd.dig("data", "id")
    puts "    ✓ reviewDetail exists (#{rdid[0,8]}); patching"
    body = { data: { type: "appStoreReviewDetails", id: rdid, attributes: attrs } }
    dry_or_api(:patch, "/v1/appStoreReviewDetails/#{rdid}", body: body, summary: "patch review details")
  else
    puts "    → POST /v1/appStoreReviewDetails"
    body = {
      data: {
        type: "appStoreReviewDetails",
        attributes: attrs,
        relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } },
      },
    }
    dry_or_api(:post, "/v1/appStoreReviewDetails", body: body, summary: "create review details")
  end
end

# ---- Phase: screenshots ----------------------------------------------------

# For each (platform, slot) combination, walk the screenshot directory and
# pick the most recent capture per label (alphabetical key after timestamp).
def collect_screenshots_for(slot_info)
  return [] unless File.directory?(slot_info[:dir])
  matches = Dir.glob(File.join(slot_info[:dir], "*#{slot_info[:suffix]}"))
  # Group by the "<label>" portion: filename is "<TS>-<label><suffix>" — strip TS and suffix
  groups = matches.group_by do |f|
    base = File.basename(f)
    # base: 20260418-075223-01-terminal-iphone-6.5.png (TS = "20260418-075223")
    body = base.sub(/\A\d{8}-\d{6}-/, "").sub(/#{Regexp.escape(slot_info[:suffix])}\z/, "")
    body
  end
  # Pick the newest mtime per label, sort by label name
  groups.sort_by { |label, _| label }.map { |label, files| [label, files.max_by { |f| File.mtime(f) }] }
end

def upload_screenshots_for(version_id, localization_id, platform)
  return if version_id.start_with?("(dry-run")
  slots = SCREENSHOT_SLOTS.select { |s| s[:platform] == platform }
  slots.each do |slot|
    items = collect_screenshots_for(slot)
    if items.empty?
      puts "    [#{slot[:type]}] no files in #{slot[:dir]}; skipping"
      next
    end
    # Find or create the screenshot set
    sets = api(:get, "/v1/appStoreVersionLocalizations/#{localization_id}/appScreenshotSets")
    set = (sets["data"] || []).find { |s| s.dig("attributes", "screenshotDisplayType") == slot[:type] }
    if set
      set_id = set["id"]
      puts "    [#{slot[:type]}] using existing set #{set_id[0,8]}"
    else
      puts "    [#{slot[:type]}] → POST appScreenshotSets"
      body = {
        data: {
          type: "appScreenshotSets",
          attributes: { screenshotDisplayType: slot[:type] },
          relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization_id } } },
        },
      }
      res = api(:post, "/v1/appScreenshotSets", body: body)
      set_id = res.dig("data", "id")
    end
    # Clear existing screenshots in this set (replace, since labels may differ)
    existing = api(:get, "/v1/appScreenshotSets/#{set_id}/appScreenshots")
    (existing["data"] || []).each do |sc|
      puts "      ✗ removing existing screenshot #{sc.dig('attributes','fileName')} (#{sc['id'][0,8]})"
      api(:delete, "/v1/appScreenshots/#{sc['id']}")
    end
    items.each do |label, file|
      puts "      ↑ #{label} ← #{File.basename(file)}"
      upload_single_screenshot(set_id, file)
    end
  end
end

def upload_single_screenshot(set_id, file_path)
  bytes = File.binread(file_path)
  md5_hex = Digest::MD5.hexdigest(bytes)
  body = {
    data: {
      type: "appScreenshots",
      attributes: {
        fileName: File.basename(file_path),
        fileSize: bytes.bytesize,
      },
      relationships: {
        appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } },
      },
    },
  }
  created = api(:post, "/v1/appScreenshots", body: body)
  scr_id  = created.dig("data", "id")
  ops     = created.dig("data", "attributes", "uploadOperations") || []
  ops.each_with_index do |op, idx|
    method = op["method"].downcase.to_sym
    url    = op["url"]
    headers = (op["requestHeaders"] || []).each_with_object({}) { |h, acc| acc[h["name"]] = h["value"] }
    headers["Authorization"] ||= :none
    offset = op["offset"].to_i
    length = op["length"].to_i
    chunk  = bytes.byteslice(offset, length)
    if VERBOSE
      puts "        chunk #{idx+1}/#{ops.length} #{method.to_s.upcase} #{url[0,60]}... (#{length} B)"
    end
    res = http_request(method, url, body: chunk, headers: headers, timeout: 120)
    unless res.code.to_i < 400
      abort "screenshot upload chunk #{idx+1} failed: #{res.code} #{res.body}"
    end
  end
  # Commit
  patch_body = { data: { type: "appScreenshots", id: scr_id, attributes: { uploaded: true, sourceFileChecksum: md5_hex } } }
  api(:patch, "/v1/appScreenshots/#{scr_id}", body: patch_body)
end

# ---- Main ------------------------------------------------------------------

puts "=== reset-v1-and-create-v6_15_0.rb ==="
puts "  ROOT: #{ROOT}"
puts "  APP_ID: #{APP_ID}"
puts "  VERSION: #{VERSION_STRING}"
puts "  LISTING: #{LISTING_PATH}"
puts "  KEY_ID: #{KEY_ID}"
puts "  ISSUER_ID: #{ISSUER_ID[0,8]}…"
puts "  Mode: #{APPLY ? "APPLY (mutating)" : "dry-run (no mutations)"}"
puts "  skip_delete=#{opts[:skip_delete]}  skip_screenshots=#{opts[:skip_screenshots]}  verbose=#{VERBOSE}"

abort "Listing file not found: #{LISTING_PATH}" unless File.exist?(LISTING_PATH)
listing = read_listing(LISTING_PATH)
puts "\nParsed listing — sections present: #{listing.keys.inspect}"

snap = snapshot_state

reused = opts[:skip_delete] ? {} : delete_or_rename_v1(snap)

%w[IOS MAC_OS].each do |platform|
  puts "\n=== Phase 3+4: upsert version + localization (#{platform})#{DRY_TAG} ==="
  vid = upsert_version(platform, listing[platform], reused: reused)
  locid = upsert_localization(vid, listing[platform])

  puts "\n=== Phase 5: attach build (#{platform})#{DRY_TAG} ==="
  build = find_latest_build(platform)
  attach_build(vid, build)

  puts "\n=== Phase 6: review details (#{platform})#{DRY_TAG} ==="
  upsert_review_details(vid, listing[platform], snap)

  unless opts[:skip_screenshots]
    puts "\n=== Phase 7: screenshots (#{platform})#{DRY_TAG} ==="
    if APPLY
      upload_screenshots_for(vid, locid, platform)
    else
      slots = SCREENSHOT_SLOTS.select { |s| s[:platform] == platform }
      slots.each do |slot|
        items = collect_screenshots_for(slot)
        puts "  [#{slot[:type]}] would upload #{items.length} screenshot(s) from #{slot[:dir]}"
        items.each { |label, f| puts "    - #{label} ← #{File.basename(f)}" }
      end
    end
  end
end

puts "\n=== Done#{DRY_TAG} ==="
unless APPLY
  puts "Re-run with --apply to execute. Defaults to --skip-screenshots NOT set; pass --skip-screenshots to skip the upload phase if you haven't captured them yet."
end
