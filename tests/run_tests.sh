#!/usr/bin/env bash
#
# ServerSentry v2 - Simple Test Runner
#
# Simple wrapper for the enhanced test runner for backward compatibility

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Check if enhanced runner exists
if [[ ! -f "$SCRIPT_DIR/run_enhanced_tests.sh" ]]; then
  echo "❌ Enhanced test runner not found: $SCRIPT_DIR/run_enhanced_tests.sh"
  exit 1
fi

# If no arguments provided, run all tests with default settings
if [[ $# -eq 0 ]]; then
  echo "🚀 Running all ServerSentry tests..."
  exec "$SCRIPT_DIR/run_enhanced_tests.sh"
else
  # Pass all arguments to enhanced runner
  exec "$SCRIPT_DIR/run_enhanced_tests.sh" "$@"
fi
