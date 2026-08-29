#!/usr/bin/env bash
set -euo pipefail

swift build
swift test --filter InspectorSnapshotTests
swift test --filter DevExperienceClosureTests

# The editor's three layers. The rewriter is pure logic, so it is checked on its
# own before anything that touches a file; the integration suite then drives the
# write route against a real project on disk.
swift test --filter SwiftSourceEditorTests
swift test --filter DevHTTPServerTests
swift test --filter SourceEditIntegrationTests

# `--once` exercises the asset and route surface without building or launching
# an application, which is what makes it safe to run in CI.
.build/debug/cider dev --path examples/rest-client-cider --once
