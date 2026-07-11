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
# distribution certificates, human-named development certificates (e.g. a
# developer's own "Apple Development: Jane Doe"), and freshly minted API
# certificates (see RECENT_WINDOW) alone, and never fails the build — if
# anything goes wrong it logs a warning and exits 0, letting Archive be the
# source of truth.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID.

require_relative 'asc_api'
require 'time'

DEV_TYPES = %w[DEVELOPMENT IOS_DEVELOPMENT].freeze
# Apple names certificates minted through the API (i.e. by CI cloud signing)
# with these labels. Matched exactly, or with a trailing parenthesised
# qualifier — never as a loose substring — so a human-named certificate that
# merely mentions the phrase is never reaped.
API_CERT_NAMES = ['Created via API', 'Apple Development: Created via API'].freeze
# The certificates endpoint is account-wide: it also lists certs another
# pipeline on the team — or a concurrent run of this very workflow, since
# release.yml's concurrency group is per-ref (a tag push and a
# workflow_dispatch run in parallel) — minted moments ago and is about to
# sign with. Development certificates are valid for one year, so
# expirationDate minus CERT_VALIDITY approximates creation time; anything
# "created" within RECENT_WINDOW is left alone. The window comfortably covers
# a release run's Archive/Export phase, so the residual race is only a run
# still signing more than RECENT_WINDOW after it minted its certificate.
RECENT_WINDOW = 2 * 60 * 60
CERT_VALIDITY = 365 * 24 * 60 * 60

def warn_gh(message)
  puts "::warning::#{message}"
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
    path = next_page_path(body)
  end
  found.select do |cert|
    attributes = cert['attributes'] || {}
    DEV_TYPES.include?(attributes['certificateType']) &&
      api_minted?(attributes['name'].to_s) &&
      !recently_created?(attributes)
  end
end

def api_minted?(name)
  API_CERT_NAMES.any? { |exact| name == exact || name.start_with?("#{exact} (") }
end

# True when the certificate looks freshly minted (see RECENT_WINDOW above).
# An unparseable or missing expiry is treated as fresh — when in doubt,
# leave the certificate alone.
def recently_created?(attributes)
  Time.iso8601(attributes['expirationDate'].to_s) - CERT_VALIDITY > Time.now - RECENT_WINDOW
rescue ArgumentError
  true
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
  token = token_from_env
  certs = development_certificates(token)
  puts "Found #{certs.size} development certificate(s) to revoke."
  certs.each { |cert| revoke(token, cert) }
  puts 'Development certificate cleanup complete.'
rescue StandardError => e
  warn_gh("Certificate cleanup skipped: #{e.class}: #{e.message}")
end
