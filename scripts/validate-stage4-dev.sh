#!/usr/bin/env bash
set -euo pipefail

swift build
swift test --filter InspectorSnapshotTests
swift test --filter DevExperienceClosureTests
.build/debug/cider dev --path examples/rest-client-cider --once
