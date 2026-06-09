#!/usr/bin/env ruby
# frozen_string_literal: true

# Idempotently registers the watch widget bundle ID and enables its App Groups
# capability via the App Store Connect API. Cloud signing with an API key
# cannot do this when the target's entitlements request an app group (the App
# ID write fails with a bearer-token authentication error), so we pre-create
# it here. Assigning the actual group to the App ID is not supported by the
# public API and stays a one-time manual portal step. Never fails the build.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID.

require 'openssl'
require 'base64'
require 'json'
require 'net/http'

HOST = 'api.appstoreconnect.apple.com'
IDENTIFIER = 'plastickarma.lead-track.watchkitapp.widget'
NAME = 'lead-track Watch Widget'

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

def request(token, method, path, payload = nil)
  http = Net::HTTP.new(HOST, 443)
  http.use_ssl = true
  headers = { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
  response =
    case method
    when :get then http.get(path, headers)
    when :post then http.post(path, JSON.generate(payload), headers)
    end
  [response.code.to_i, response.body.to_s]
end

def existing_bundle_id(token)
  code, body = request(token, :get, "/v1/bundleIds?filter[identifier]=#{IDENTIFIER}&limit=200")
  return nil unless code == 200

  data = JSON.parse(body)['data'] || []
  data.find { |b| b.dig('attributes', 'identifier') == IDENTIFIER }
end

def create_bundle_id(token)
  %w[UNIVERSAL IOS].each do |platform|
    payload = {
      data: {
        type: 'bundleIds',
        attributes: { identifier: IDENTIFIER, name: NAME, platform: platform }
      }
    }
    code, body = request(token, :post, '/v1/bundleIds', payload)
    if code == 201
      puts "Registered bundle ID #{IDENTIFIER} (platform #{platform})."
      return JSON.parse(body)['data']
    end
    puts "Create with platform #{platform} -> HTTP #{code}: #{body[0, 300]}"
  end
  nil
end

def enable_app_groups(token, bundle)
  payload = {
    data: {
      type: 'bundleIdCapabilities',
      attributes: { capabilityType: 'APP_GROUPS', settings: nil },
      relationships: {
        bundleId: { data: { type: 'bundleIds', id: bundle['id'] } }
      }
    }
  }
  code, body = request(token, :post, '/v1/bundleIdCapabilities', payload)
  if code == 201
    puts 'Enabled APP_GROUPS capability (group assignment still needs the portal).'
  else
    puts "Enabling APP_GROUPS -> HTTP #{code}: #{body[0, 300]}"
  end
end

begin
  key = OpenSSL::PKey.read(File.read(ENV.fetch('API_KEY_PATH')))
  token = make_token(key, ENV.fetch('KEY_ID'), ENV.fetch('ISSUER_ID'))
  bundle = existing_bundle_id(token)
  if bundle
    puts "Bundle ID #{IDENTIFIER} already registered (id #{bundle['id']})."
  else
    bundle = create_bundle_id(token)
  end
  enable_app_groups(token, bundle) if bundle
rescue StandardError => e
  puts "::warning::Bundle ID registration skipped: #{e.class}: #{e.message}"
end
