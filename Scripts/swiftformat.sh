#!/bin/bash

# Do NOT exit on error - we want to continue build even if formatting fails
# set -e

echo "🎨 Running SwiftFormat..."

# Check if SwiftFormat is installed
if [ -f "/opt/homebrew/bin/swiftformat" ]; then
    SWIFTFORMAT_PATH="/opt/homebrew/bin/swiftformat"
    echo "✅ SwiftFormat found at: $SWIFTFORMAT_PATH (Homebrew ARM)"
elif [ -f "/usr/local/bin/swiftformat" ]; then
    SWIFTFORMAT_PATH="/usr/local/bin/swiftformat"
    echo "✅ SwiftFormat found at: $SWIFTFORMAT_PATH (Homebrew Intel)"
elif which swiftformat > /dev/null 2>&1; then
    SWIFTFORMAT_PATH=$(which swiftformat)
    echo "✅ SwiftFormat found at: $SWIFTFORMAT_PATH"
else
    echo "⚠️ SwiftFormat not found. Install with: brew install swiftformat"
    echo "⚠️ Skipping format step..."
    exit 0
fi

# Change to project directory
cd "${SRCROOT}" || exit 0

# Check if config exists
if [ ! -f ".swiftformat" ]; then
    echo "⚠️ .swiftformat config not found, using defaults"
    "$SWIFTFORMAT_PATH" . || true
else
    # Run SwiftFormat - use || true to not fail the build
    "$SWIFTFORMAT_PATH" . --config .swiftformat || true
fi

echo "✅ SwiftFormat completed!"
exit 0
