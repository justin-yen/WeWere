#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wewere-session-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$TEST_DIR/module-cache" \
  WeWere/Services/AppEnvironment.swift WeWere/Services/AppNetwork.swift WeWere/Models/User.swift WeWere/Services/SessionCoordinator.swift WeWere/Services/APIClient.swift \
  Tests/Support/Secrets.swift Tests/SessionReliabilityTests.swift \
  -o "$TEST_DIR/session-tests"
"$TEST_DIR/session-tests"
