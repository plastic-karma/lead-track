#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only diagnostic for cloud-signing failures: prints every bundle ID in
# the account matching the app's prefix, with its capabilities and the
# provisioning profiles attached to it. Never fails the build.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID.

require_relative 'asc_api'

PREFIX = 'plastickarma.lead-track'

def get_json(token, path)
  http = Net::HTTP.new(HOST, 443)
  http.use_ssl = true
  response = http.get(path, 'Authorization' => "Bearer #{token}")
  return JSON.parse(response.body) if response.code == '200'

  puts "  (HTTP #{response.code} for #{path}: #{response.body[0, 300]})"
  nil
end

def paged(token, path)
  items = []
  while path
    body = get_json(token, path)
    break unless body

    items.concat(body['data'] || [])
    path = body.dig('links', 'next')&.sub("https://#{HOST}", '')
  end
  items
end

def describe(token, bundle)
  attrs = bundle['attributes']
  puts "#{attrs['identifier']}  (name: #{attrs['name']}, platform: #{attrs['platform']}, id: #{bundle['id']})"
  caps = paged(token, "/v1/bundleIds/#{bundle['id']}/bundleIdCapabilities")
  caps.each do |cap|
    settings = cap.dig('attributes', 'settings')
    puts "  capability: #{cap.dig('attributes', 'capabilityType')}  settings: #{settings.inspect}"
  end
  puts '  capability: (none)' if caps.empty?
  profiles = paged(token, "/v1/bundleIds/#{bundle['id']}/profiles?limit=200")
  profiles.each do |profile|
    a = profile['attributes']
    puts "  profile: #{a['name']}  [#{a['profileType']}, #{a['profileState']}, expires #{a['expirationDate']}]"
  end
  puts '  profile: (none)' if profiles.empty?
end

begin
  token = token_from_env
  bundles = paged(token, '/v1/bundleIds?limit=200')
  matching = bundles.select { |b| b.dig('attributes', 'identifier').to_s.start_with?(PREFIX) }
  puts "#{matching.size} bundle ID(s) matching '#{PREFIX}*':"
  matching.each { |bundle| describe(token, bundle) }
rescue StandardError => e
  puts "::warning::Diagnostics skipped: #{e.class}: #{e.message}"
end
