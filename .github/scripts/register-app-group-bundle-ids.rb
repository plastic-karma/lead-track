#!/usr/bin/env ruby
# frozen_string_literal: true

# Idempotently registers bundle IDs whose targets use App Groups and enables
# that capability through the App Store Connect API. Cloud signing with an API
# key cannot create these App IDs itself (the write fails with a bearer-token
# authentication error), so we pre-create them here. Assigning the actual group
# to each App ID is not supported by the public API and stays a one-time manual
# portal step. Never fails the build.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID.

require_relative 'asc_api'

BUNDLES = [
  {
    identifier: 'plastickarma.lead-track.watchkitapp.widget',
    name: 'lead-track Watch Widget'
  },
  {
    identifier: 'plastickarma.lead-track.share',
    name: 'lead-track Share Extension'
  }
].freeze

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

def existing_bundle_id(token, identifier)
  code, body = request(token, :get, "/v1/bundleIds?filter[identifier]=#{identifier}&limit=200")
  return nil unless code == 200

  data = JSON.parse(body)['data'] || []
  data.find { |bundle| bundle.dig('attributes', 'identifier') == identifier }
end

def create_bundle_id(token, definition)
  %w[UNIVERSAL IOS].each do |platform|
    payload = {
      data: {
        type: 'bundleIds',
        attributes: {
          identifier: definition[:identifier],
          name: definition[:name],
          platform: platform
        }
      }
    }
    code, body = request(token, :post, '/v1/bundleIds', payload)
    if code == 201
      puts "Registered bundle ID #{definition[:identifier]} (platform #{platform})."
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
  token = token_from_env
  BUNDLES.each do |definition|
    begin
      bundle = existing_bundle_id(token, definition[:identifier])
      if bundle
        puts "Bundle ID #{definition[:identifier]} already registered (id #{bundle['id']})."
      else
        bundle = create_bundle_id(token, definition)
      end
      enable_app_groups(token, bundle) if bundle
    rescue StandardError => e
      puts "::warning::Bundle ID #{definition[:identifier]} registration skipped: #{e.class}: #{e.message}"
    end
  end
rescue StandardError => e
  puts "::warning::Bundle ID registration skipped: #{e.class}: #{e.message}"
end
