#!/bin/bash
# Guards the watchOS 8.0 / Series 3 floor.
#
# Xcode builds against the newest SDK, so a watchOS 10-only API compiles fine
# here and only fails on an older watch. Type-checking against
# armv7k-apple-watchos8.0 catches that at desk time.
#
#   ./scripts/test-watchos8-compatibility.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/DoremiTeacher.xcodeproj/project.pbxproj"

if ! grep -q 'WATCHOS_DEPLOYMENT_TARGET = 8.0;' "$PROJECT"; then
  echo "Expected the watchOS deployment target to remain at 8.0." >&2
  exit 1
fi

if ! grep -q 'armv7k' "$PROJECT"; then
  echo "Expected the app target to include the Series 3 armv7k architecture." >&2
  exit 1
fi

# APIs that compile against the current SDK but need watchOS 10 at runtime.
for symbol in '#Preview' 'containerRelativeFrame' 'onChange\(of:.*initial:' 'NavigationStack'; do
  if grep -rqE "$symbol" "$ROOT/DoremiTeacher"/*.swift; then
    echo "Found $symbol, which requires a newer watchOS and breaks the Series 3 floor." >&2
    exit 1
  fi
done

xcrun swiftc \
  -typecheck \
  -parse-as-library \
  -swift-version 5 \
  -module-cache-path "${TMPDIR:-/tmp}/doremiteacher-watchos8-module-cache" \
  -sdk "$(xcrun --sdk watchos --show-sdk-path)" \
  -target armv7k-apple-watchos8.0 \
  "$ROOT/DoremiTeacher"/*.swift

echo "watchOS 8.0 armv7k compatibility check passed."
