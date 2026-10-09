# Shared App Store Connect client: credentials, ES256 JWT and a JSON API
# helper. Used by asc-release.rb and asc-withdraw.rb.
#
# Callers define ROOT (repo root) and VERBOSE before requiring this file.
require "openssl"
require "json"
require "base64"
require "net/http"
require "uri"

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
