#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "SwiftData migration tests require macOS." >&2
  exit 2
fi

run_fixture() (
  local version="$1"
  local test_name="$2"
  local fixture_log
  fixture_log="$(mktemp "${TMPDIR:-/tmp}/lead-track-migration.XXXXXX")"
  trap 'rm -f "$fixture_log"' EXIT

  LEADTRACK_MIGRATION_FIXTURE_VERSION="$version" \
    swift test --filter "$test_name" 2>&1 | tee "$fixture_log"
  grep -Fq "Test run with 1 test passed" "$fixture_log"
)

run_fixture v1 "syntheticV1SchemaMigratesThroughV3WithItsGraphIntact"
run_fixture v2 "syntheticShippedV2SchemaMigratesToV3AndKeepsItsRank"
