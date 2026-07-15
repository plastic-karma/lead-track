#!/usr/bin/env ruby
# frozen_string_literal: true

# Best-effort cleanup for the Release IPA workflow's TestFlight publish.
#
# Beta App Review (external TestFlight) allows only ONE build per marketing
# version to sit in review at a time. If a previous build is still
# WAITING_FOR_REVIEW or IN_REVIEW, submitting the freshly uploaded build fails
# with:
#
#   You can only submit one build from version 1.0.1 to Beta App Review.
#   Once the build you submitted is approved, you can submit additional builds.
#
# This script expires any build OF THE VERSION BEING UPLOADED that is
# currently waiting for / in Beta App Review (PATCH /v1/builds/{id}
# { expired: true }), freeing the slot so the new build can be submitted. The
# review lock is per marketing version, so builds of other versions — e.g. a
# 1.0.1 legitimately sitting in review while 1.1.0 ships — do not block this
# submission and are never touched. It also never touches an APPROVED build
# that testers are actually using, and never fails the build: on any error it
# logs a warning and exits 0, leaving the upload as the source of truth.
#
# Reads: API_KEY_PATH (the .p8 file), KEY_ID, ISSUER_ID, and RELEASE_VERSION
# (the marketing version this run uploads — resolved by the workflow from
# MARKETING_VERSION or the archived app's Info.plist). When RELEASE_VERSION
# is blank the script skips entirely rather than guess at scope.

require_relative 'asc_api'
require 'uri'

BUNDLE_ID = 'plastickarma.lead-track'
# Beta review states that hold the "one build in review per version" lock.
BLOCKING_STATES = %w[WAITING_FOR_REVIEW IN_REVIEW].freeze

def warn_gh(message)
  puts "::warning::#{message}"
end

def client
  http = Net::HTTP.new(HOST, 443)
  http.use_ssl = true
  http
end

def get_json(token, path)
  response = client.get(path, 'Authorization' => "Bearer #{token}")
  unless response.code == '200'
    warn_gh("GET #{path} failed (HTTP #{response.code}): #{response.body}")
    return nil
  end
  JSON.parse(response.body)
end

def app_id(token)
  body = get_json(token, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}&limit=1")
  body && body['data']&.first&.fetch('id', nil)
end

# Maps a betaAppReviewSubmission id -> betaReviewState from an `included` array.
def submission_states(included)
  states = {}
  (included || []).each do |item|
    next unless item['type'] == 'betaAppReviewSubmissions'

    states[item['id']] = item.dig('attributes', 'betaReviewState')
  end
  states
end

# Builds of the given marketing version whose beta-review submission is
# waiting for or in review.
def builds_in_review(token, app, version)
  path = "/v1/builds?filter[app]=#{app}" \
         "&filter[preReleaseVersion.version]=#{URI.encode_www_form_component(version)}" \
         '&include=betaAppReviewSubmission&limit=200'
  blocking = []
  while path
    body = get_json(token, path)
    break unless body

    states = submission_states(body['included'])
    (body['data'] || []).each do |build|
      sid = build.dig('relationships', 'betaAppReviewSubmission', 'data', 'id')
      blocking << build if sid && BLOCKING_STATES.include?(states[sid])
    end
    path = next_page_path(body)
  end
  blocking
end

def expire(token, build)
  identifier = build['id']
  version = build.dig('attributes', 'version')
  payload = { data: { type: 'builds', id: identifier, attributes: { expired: true } } }
  response = client.patch(
    "/v1/builds/#{identifier}",
    JSON.generate(payload),
    'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json'
  )
  if response.code == '200'
    puts "Expired build #{identifier} (build #{version}) that was in Beta App Review."
  else
    warn_gh("Failed to expire #{identifier} (HTTP #{response.code}): #{response.body}")
  end
end

def expire_in_review_builds(version)
  token = token_from_env
  app = app_id(token)
  return warn_gh("No app found for bundle ID #{BUNDLE_ID}; skipping expire step.") if app.nil?

  builds = builds_in_review(token, app, version)
  puts "Found #{builds.size} build(s) of version #{version} in Beta App Review to expire."
  builds.each { |build| expire(token, build) }
  puts 'Beta App Review cleanup complete.'
end

begin
  version = ENV['RELEASE_VERSION'].to_s.strip
  if version.empty?
    warn_gh('RELEASE_VERSION is empty — cannot scope expiry to the uploaded version; skipping expire step.')
  else
    expire_in_review_builds(version)
  end
rescue StandardError => e
  warn_gh("Build expiry skipped: #{e.class}: #{e.message}")
end
