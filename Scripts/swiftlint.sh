#!/bin/bash

# Do NOT exit on error - we want warnings, not build failures
# set -e

echo "🔍 Running SwiftLint..."

# Check if SwiftLint is installed
if [ -f "/opt/homebrew/bin/swiftlint" ]; then
    SWIFTLINT_PATH="/opt/homebrew/bin/swiftlint"
    echo "✅ SwiftLint found at: $SWIFTLINT_PATH (Homebrew ARM)"
elif [ -f "/usr/local/bin/swiftlint" ]; then
    SWIFTLINT_PATH="/usr/local/bin/swiftlint"
    echo "✅ SwiftLint found at: $SWIFTLINT_PATH (Homebrew Intel)"
elif which swiftlint > /dev/null 2>&1; then
    SWIFTLINT_PATH=$(which swiftlint)
    echo "✅ SwiftLint found at: $SWIFTLINT_PATH"
else
    echo "⚠️ SwiftLint not found. Install with: brew install swiftlint"
    echo "⚠️ Skipping lint step..."
    exit 0
fi

# Change to project directory
cd "${SRCROOT}" || exit 0

# Check if config exists
if [ ! -f ".swiftlint.yml" ]; then
    echo "⚠️ .swiftlint.yml config not found, using defaults"
    "$SWIFTLINT_PATH" lint || true
else
    # Run SwiftLint - use || true to not fail the build on warnings
    "$SWIFTLINT_PATH" lint --config .swiftlint.yml || true
fi

echo "✅ SwiftLint completed!"
exit 0
