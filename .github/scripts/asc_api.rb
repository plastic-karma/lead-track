# frozen_string_literal: true

# Shared App Store Connect API plumbing for the release scripts: the host
# they all talk to and the ES256 JWT every request needs.
#
# Callers read API_KEY_PATH (the .p8 file), KEY_ID, and ISSUER_ID from the
# environment; `token_from_env` turns them into a ready bearer token.

require 'openssl'
require 'base64'
require 'json'
require 'net/http'

HOST = 'api.appstoreconnect.apple.com'

# Builds a short-lived ES256 JWT for the App Store Connect API.
def make_token(key, key_id, issuer_id)
  b64 = ->(bytes) { Base64.urlsafe_encode64(bytes).delete('=') }
  now = Time.now.to_i
  header = { alg: 'ES256', kid: key_id, typ: 'JWT' }
  claims = { iss: issuer_id, iat: now, exp: now + 1140, aud: 'appstoreconnect-v1' }
  signing_input = "#{b64.call(JSON.generate(header))}.#{b64.call(JSON.generate(claims))}"
  der = key.sign(OpenSSL::Digest.new('SHA256'), signing_input)
  parts = OpenSSL::ASN1.decode(der).value
  raw = parts[0].value.to_s(2).rjust(32, "\x00") + parts[1].value.to_s(2).rjust(32, "\x00")
  "#{signing_input}.#{b64.call(raw)}"
end

def token_from_env
  key = OpenSSL::PKey.read(File.read(ENV.fetch('API_KEY_PATH')))
  make_token(key, ENV.fetch('KEY_ID'), ENV.fetch('ISSUER_ID'))
end
