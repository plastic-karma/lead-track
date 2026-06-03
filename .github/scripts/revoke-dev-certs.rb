#!/usr/bin/env ruby
# frozen_string_literal: true

# Best-effort cleanup for the Release IPA workflow.
#
# Cloud signing (`xcodebuild -allowProvisioningUpdates`) mints a brand-new
# Apple Development certificate on every CI run, because each runner starts with
# an empty keychain. Apple caps the number of certificates per account, so after
# enough runs the Archive step fails with:
#
#   error: Your account has reached the maximum number of certificates.
#
# This script revokes the *auto-generated* development certificates that cloud
# signing leaves behind (Apple names them "Apple Development: Created via API")
# so Archive can mint a fresh one under the cap. It deliberately leaves
# distribution certificates and human-named development certificates (e.g. a
# developer's own "Apple Development: Jane Doe") alone, and never fails the
# build — if anything goes wrong it logs a warning and exits 0, letting Archive
# be the source of truth.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID.

require 'openssl'
require 'base64'
require 'json'
require 'net/http'

HOST = 'api.appstoreconnect.apple.com'
DEV_TYPES = %w[DEVELOPMENT IOS_DEVELOPMENT].freeze
# Apple labels certificates minted through the API (i.e. by CI cloud signing)
# with this exact name. Only those are safe to reap automatically.
API_CERT_NAME = 'Created via API'

def warn_gh(message)
  puts "::warning::#{message}"
end

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

def client
  http = Net::HTTP.new(HOST, 443)
  http.use_ssl = true
  http
end

def development_certificates(token)
  found = []
  path = '/v1/certificates?limit=200'
  while path
    response = client.get(path, 'Authorization' => "Bearer #{token}")
    unless response.code == '200'
      warn_gh("Listing certificates failed (HTTP #{response.code}): #{response.body}")
      break
    end
    body = JSON.parse(response.body)
    found.concat(body['data'] || [])
    nxt = body.dig('links', 'next')
    path = nxt&.sub("https://#{HOST}", '')
  end
  found.select do |cert|
    attributes = cert['attributes'] || {}
    DEV_TYPES.include?(attributes['certificateType']) &&
      attributes['name'].to_s.include?(API_CERT_NAME)
  end
end

def revoke(token, cert)
  identifier = cert['id']
  name = cert.dig('attributes', 'name')
  response = client.delete("/v1/certificates/#{identifier}", 'Authorization' => "Bearer #{token}")
  if response.code == '204'
    puts "Revoked development certificate #{identifier} (#{name})."
  else
    warn_gh("Failed to revoke #{identifier} (HTTP #{response.code}): #{response.body}")
  end
end

begin
  key = OpenSSL::PKey.read(File.read(ENV.fetch('API_KEY_PATH')))
  token = make_token(key, ENV.fetch('KEY_ID'), ENV.fetch('ISSUER_ID'))
  certs = development_certificates(token)
  puts "Found #{certs.size} development certificate(s) to revoke."
  certs.each { |cert| revoke(token, cert) }
  puts 'Development certificate cleanup complete.'
rescue StandardError => e
  warn_gh("Certificate cleanup skipped: #{e.class}: #{e.message}")
end
