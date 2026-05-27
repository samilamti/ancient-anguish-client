#!/usr/bin/env ruby
# Create the v6.16.0 App Store Connect submission for iOS + macOS:
#   - upserts the v6.16.0 AppStoreVersion record per platform (creates if
#     missing, patches copyright/releaseType if present)
#   - upserts the en-US localization (description, keywords, promotionalText,
#     whatsNew, supportUrl, marketingUrl) — pulled from
#     `App Store Listings v6.16.0.md`
#   - attaches the latest VALID v6.16.0 build per platform (auto-discovered)
#   - upserts the App Review Details (reviewer notes, contact, demo account)
#   - reuses the v6.15.0 screenshot uploads — re-runs the upload phase against
#     `screenshots/v6.16.0/` if that directory exists; otherwise falls back to
#     `screenshots/v6.15.0/` so we don't blow away last release's shots
#
# Unlike scripts/asc/reset-v1-and-create-v6_15_0.rb this script does NOT
# delete or rename anything — v6.16.0 is a follow-on, not a reset.
#
# Credentials follow the same pattern as scripts/testflight-status.rb:
#   - .p8 key auto-discovered at "<repo>/AppStore Connect Stuff*/AuthKey_*.p8"
#     (override with ASC_KEY_PATH)
#   - Key ID derived from filename (override with ASC_KEY_ID)
#   - Issuer ID from env ASC_ISSUER_ID or .asc/issuer_id
#
# Usage:
#   ruby scripts/asc/create-v6_16_0.rb                 # dry-run (no mutations)
#   ruby scripts/asc/create-v6_16_0.rb --apply         # do it
#   ruby scripts/asc/create-v6_16_0.rb --apply --skip-screenshots
#   ruby scripts/asc/create-v6_16_0.rb -v              # verbose request log

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
VERSION_STRING = "6.16.0"
COPYRIGHT = "2026 Sami Xavier Lamti"
RELEASE_TYPE = "AFTER_APPROVAL"
LISTING_PATH = File.join(ROOT, "App Store Listings v6.16.0.md")
SNAPSHOT_DIR = File.join(ROOT, "screenshots", "v6.16.0")
SNAPSHOT_PATH = File.join(SNAPSHOT_DIR, ".snapshot-before-create.json")
LOCALE = "en-US"

# Screenshot lookup is preserved from the v6.15.0 flow: re-uses the prior
# release's shots when no v6.16.0 captures exist, since most screens look
# the same across this release. Only iPhone `06-social` is genuinely
# new and worth re-capturing — see listing markdown.
# Screenshots live in the unversioned `screenshots/{ios,macos}/` directories
# (the same layout the v6.15.0 script used). For v6.16.0 we re-upload the
# same set unless Sami captures new ones — the screenshot tool prefixes a
# timestamp to each file, so a re-capture supersedes the prior take.
SCREENSHOT_SLOTS = [
  { platform: "IOS",    type: "APP_IPHONE_65",         dir: File.join(ROOT, "screenshots", "ios"),    suffix: "-iphone-6.5.png" },
  { platform: "IOS",    type: "APP_IPAD_PRO_3GEN_129", dir: File.join(ROOT, "screenshots", "ios"),    suffix: "-ipad-13.png" },
  { platform: "MAC_OS", type: "APP_DESKTOP",           dir: File.join(ROOT, "screenshots", "macos"),  suffix: "-macos.png" },
]

# Resolves a build's platform via its preReleaseVersion (the
# /v1/builds endpoint doesn't expose platform directly on the build, but
# every build has a `preReleaseVersion` whose attributes include `platform`
# = "IOS" | "MAC_OS" | "TV_OS" | "VISION_OS").
def build_platform(build)
  prv_data = build.dig("relationships", "preReleaseVersion", "data")
  return nil unless prv_data
  prv = api(:get, "/v1/preReleaseVersions/#{prv_data['id']}")
  prv.dig("data", "attributes", "platform")
end

# ---- Options ---------------------------------------------------------------

opts = { apply: false, skip_screenshots: false, submit: false, verbose: false }
OptionParser.new do |o|
  o.on("--apply",            "actually mutate ASC")        { opts[:apply] = true }
  o.on("--skip-screenshots", "skip screenshot upload phase"){ opts[:skip_screenshots] = true }
  o.on("--submit",           "after upserting, also submit each version for App Review (requires --apply)") { opts[:submit] = true }
  o.on("-v", "--verbose",    "log full HTTP requests")     { opts[:verbose] = true }
end.parse!

APPLY = opts[:apply]
VERBOSE = opts[:verbose]
DRY_TAG = APPLY ? "" : " [dry-run]"

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

KEY_PATH, KEY_ID, ISSUER_ID = resolve_credentials

def b64url(s)
  Base64.urlsafe_encode64(s, padding: false)
end

def ecdsa_der_to_jws(der)
  asn = OpenSSL::ASN1.decode(der)
  r = asn.value[0].value.to_s(2).rjust(32, "\x00".b)
  s = asn.value[1].value.to_s(2).rjust(32, "\x00".b)
  r + s
end

def make_jwt(key_pem, key_id, issuer_id)
  header = { alg: "ES256", typ: "JWT", kid: key_id }
  claims = { iss: issuer_id, iat: Time.now.to_i, exp: Time.now.to_i + 19 * 60, aud: "appstoreconnect-v1" }
  signing_input = "#{b64url(JSON.dump(header))}.#{b64url(JSON.dump(claims))}"
  key = OpenSSL::PKey::EC.new(key_pem)
  digest = OpenSSL::Digest::SHA256.new.digest(signing_input)
  der = key.dsa_sign_asn1(digest)
  sig = ecdsa_der_to_jws(der)
  "#{signing_input}.#{b64url(sig)}"
end

JWT = make_jwt(File.read(KEY_PATH), KEY_ID, ISSUER_ID)

# ---- HTTP helpers ----------------------------------------------------------

API = "https://api.appstoreconnect.apple.com"

def http_request(method, url, body: nil, headers: {}, timeout: 60)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = timeout
  req_class = case method
              when :get    then Net::HTTP::Get
              when :post   then Net::HTTP::Post
              when :patch  then Net::HTTP::Patch
              when :put    then Net::HTTP::Put
              when :delete then Net::HTTP::Delete
              else abort "unsupported HTTP method: #{method}"
              end
  req = req_class.new(uri.request_uri)
  headers.each { |k, v| req[k] = v.to_s unless v == :none }
  if body
    req.body = body.is_a?(String) ? body : JSON.dump(body)
    req["Content-Type"] ||= "application/json"
  end
  if VERBOSE
    puts "    HTTP #{method.to_s.upcase} #{uri.request_uri}"
    puts "         #{req.body.to_s[0, 240]}" if req.body && method != :get
  end
  http.request(req)
end

def api(method, path, body: nil, raise_on_error: true)
  res = http_request(method, "#{API}#{path}", body: body, headers: { "Authorization" => "Bearer #{JWT}" })
  if res.code.to_i >= 400
    err = { "_error" => true, "_code" => res.code.to_i, "_body" => res.body.to_s }
    if raise_on_error
      abort "ASC API #{method.to_s.upcase} #{path} → #{res.code} #{res.body}"
    end
    return err
  end
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

def dry_or_api(method, path, body: nil, summary:)
  if APPLY
    api(method, path, body: body)
  else
    puts "    [dry-run] #{method.to_s.upcase} #{path} — #{summary}"
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
    whatsNew:         extract_whats_new(sec)                || (abort "missing What's New block"),
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

# "What's New" header includes a version suffix (e.g. "What's New in v6.16.0").
# Match by prefix so the script doesn't need to track the version separately.
# `.*?` with the /m flag spans the blank line between the header and the
# fenced code block.
def extract_whats_new(sec)
  m = sec.match(/^###\s+What's New.*?\n```\s*\n(.*?)\n```/m)
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
    "filter[preReleaseVersion.platform]=#{platform}",
    "filter[processingState]=VALID",
    "sort=-uploadedDate",
    "limit=20",
  ]
  res = api(:get, "/v1/builds?#{q.join('&')}")
  candidates = (res["data"] || []).reject do |b|
    b.dig("attributes", "expired") == true
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
      reviewDetail: rev && rev["data"],
    }
    puts "  snapshotted #{attrs['platform']} v#{attrs['versionString']} (#{attrs['appStoreState']}) — #{vid[0, 8]}"
  end
  File.write(SNAPSHOT_PATH, JSON.pretty_generate(snap))
  puts "  → wrote #{SNAPSHOT_PATH} (#{File.size(SNAPSHOT_PATH)} B)"
  snap
end

# ---- Phase: upsert version + localization ---------------------------------

def upsert_version(platform)
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
    whatsNew:         listing_section[:whatsNew],
    supportUrl:       listing_section[:supportUrl],
    marketingUrl:     listing_section[:marketingUrl],
  }
  if version_id.start_with?("(dry-run")
    puts "    [dry-run] would POST /v1/appStoreVersionLocalizations (en-US) — desc=#{attrs[:description].length}c keywords=#{attrs[:keywords].length}c promo=#{attrs[:promotionalText].length}c whatsNew=#{attrs[:whatsNew].length}c support=#{attrs[:supportUrl]}"
    return "(dry-run-no-loc)"
  end
  locs = api(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")
  existing = (locs["data"] || []).find { |l| l.dig("attributes", "locale") == LOCALE }
  if existing
    puts "    ✓ localization en-US exists (#{existing['id'][0,8]}); patching"
    body = { data: { type: "appStoreVersionLocalizations", id: existing["id"], attributes: attrs.reject { |k, _| k == :locale } } }
    dry_or_api(:patch, "/v1/appStoreVersionLocalizations/#{existing['id']}", body: body, summary: "patch en-US localization (incl. whatsNew)")
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

# ---- Phase: submit for review ----------------------------------------------
#
# Modern flow (post-2022): /v1/reviewSubmissions is a container that can hold
# multiple submission items (AppStoreVersion, IAPs, in-app events). PATCH
# submitted=true on the reviewSubmission to actually send it to Apple. A new
# submission cannot be opened while a prior one for the same app+platform is
# still in flight, so this is idempotent in practice — if a submission
# already exists for v6.16.0 we leave it alone.

def submit_for_review(version_id, platform)
  return if version_id.start_with?("(dry-run")
  puts "    → POST /v1/reviewSubmissions (#{platform})"
  rs = api(:post, "/v1/reviewSubmissions", body: {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: platform },
      relationships: { app: { data: { type: "apps", id: APP_ID } } },
    },
  }, raise_on_error: false)
  if rs.is_a?(Hash) && rs["_error"]
    if rs["_code"] == 409
      puts "    ! reviewSubmission already exists for #{platform} (409 — leaving as-is)"
      return
    end
    abort "reviewSubmission POST → #{rs['_code']}: #{rs['_body']}"
  end
  rsid = rs.dig("data", "id")
  puts "    ✓ reviewSubmission #{rsid[0,8]} created"

  puts "    → POST /v1/reviewSubmissionItems linking AppStoreVersion #{version_id[0,8]}"
  it = api(:post, "/v1/reviewSubmissionItems", body: {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: rsid } },
        appStoreVersion:  { data: { type: "appStoreVersions",  id: version_id } },
      },
    },
  }, raise_on_error: false)
  if it.is_a?(Hash) && it["_error"]
    abort "reviewSubmissionItems POST → #{it['_code']}: #{it['_body']}"
  end

  puts "    → PATCH /v1/reviewSubmissions/#{rsid[0,8]} submitted=true"
  sub = api(:patch, "/v1/reviewSubmissions/#{rsid}", body: {
    data: { type: "reviewSubmissions", id: rsid, attributes: { submitted: true } },
  }, raise_on_error: false)
  if sub.is_a?(Hash) && sub["_error"]
    abort "reviewSubmission PATCH → #{sub['_code']}: #{sub['_body']}"
  end
  state = sub.dig("data", "attributes", "state") || "(unknown)"
  puts "    ✓ submitted — reviewSubmission state=#{state}"
end

# ---- Phase: screenshots ----------------------------------------------------

def collect_screenshots_for(slot_info)
  return [] unless File.directory?(slot_info[:dir])
  matches = Dir.glob(File.join(slot_info[:dir], "*#{slot_info[:suffix]}"))
  groups = matches.group_by do |f|
    base = File.basename(f)
    body = base.sub(/\A\d{8}-\d{6}-/, "").sub(/#{Regexp.escape(slot_info[:suffix])}\z/, "")
    body
  end
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
      attributes: { fileName: File.basename(file_path), fileSize: bytes.bytesize },
      relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } } },
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
  patch_body = { data: { type: "appScreenshots", id: scr_id, attributes: { uploaded: true, sourceFileChecksum: md5_hex } } }
  api(:patch, "/v1/appScreenshots/#{scr_id}", body: patch_body)
end

# ---- Main ------------------------------------------------------------------

puts "=== create-v6_16_0.rb ==="
puts "  ROOT: #{ROOT}"
puts "  APP_ID: #{APP_ID}"
puts "  VERSION: #{VERSION_STRING}"
puts "  LISTING: #{LISTING_PATH}"
puts "  KEY_ID: #{KEY_ID}"
puts "  ISSUER_ID: #{ISSUER_ID[0,8]}…"
puts "  Mode: #{APPLY ? "APPLY (mutating)" : "dry-run (no mutations)"}"
puts "  skip_screenshots=#{opts[:skip_screenshots]}  verbose=#{VERBOSE}"

abort "Listing file not found: #{LISTING_PATH}" unless File.exist?(LISTING_PATH)
listing = read_listing(LISTING_PATH)
puts "\nParsed listing — sections present: #{listing.keys.inspect}"
puts "  iOS    whatsNew: #{listing['IOS'][:whatsNew].length}c"
puts "  macOS  whatsNew: #{listing['MAC_OS'][:whatsNew].length}c"

snap = snapshot_state

%w[IOS MAC_OS].each do |platform|
  puts "\n=== Phase 2+3: upsert version + localization (#{platform})#{DRY_TAG} ==="
  vid = upsert_version(platform)
  locid = upsert_localization(vid, listing[platform])

  puts "\n=== Phase 4: attach build (#{platform})#{DRY_TAG} ==="
  build = find_latest_build(platform)
  attach_build(vid, build)

  puts "\n=== Phase 5: review details (#{platform})#{DRY_TAG} ==="
  upsert_review_details(vid, listing[platform], snap)

  unless opts[:skip_screenshots]
    puts "\n=== Phase 6: screenshots (#{platform})#{DRY_TAG} ==="
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

  if opts[:submit]
    puts "\n=== Phase 7: submit for App Review (#{platform})#{DRY_TAG} ==="
    if APPLY
      submit_for_review(vid, platform)
    else
      puts "    [dry-run] would POST /v1/reviewSubmissions + reviewSubmissionItems + PATCH submitted=true"
    end
  end
end

puts "\n=== Done#{DRY_TAG} ==="
unless APPLY
  puts "Re-run with --apply to execute. Pass --submit to also send each version to App Review (otherwise the records stay in PREPARE_FOR_SUBMISSION and you click Submit in the ASC web UI)."
end
