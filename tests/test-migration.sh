#!/usr/bin/env bash
#
# Test Script for Bootstrap Migration
#
# This script tests the migrated bootstrap system

set -euo pipefail

echo "🧪 Testing ServerSentry Bootstrap Migration"
echo "=========================================="

# Test 1: Bootstrap Loading
echo ""
echo "Test 1: Bootstrap Loading"
echo "-------------------------"
unset SERVERSENTRY_ENV_LOADED
export SERVERSENTRY_AUTO_INIT=false
source serversentry-env.sh

if [[ "${SERVERSENTRY_ENV_LOADED:-}" == "true" ]]; then
  echo "✅ Bootstrap loaded successfully"
else
  echo "❌ Bootstrap failed to load"
  exit 1
fi

# Test 2: Environment Variables
echo ""
echo "Test 2: Environment Variables"
echo "-----------------------------"
if [[ -n "${SERVERSENTRY_ROOT:-}" ]]; then
  echo "✅ SERVERSENTRY_ROOT: $SERVERSENTRY_ROOT"
else
  echo "❌ SERVERSENTRY_ROOT not set"
  exit 1
fi

if [[ -n "${SERVERSENTRY_LIB_DIR:-}" ]]; then
  echo "✅ SERVERSENTRY_LIB_DIR: $SERVERSENTRY_LIB_DIR"
else
  echo "❌ SERVERSENTRY_LIB_DIR not set"
  exit 1
fi

# Test 3: Bootstrap Functions
echo ""
echo "Test 3: Bootstrap Functions"
echo "---------------------------"
if declare -f serversentry_init >/dev/null 2>&1; then
  echo "✅ serversentry_init function available"
else
  echo "❌ serversentry_init function missing"
  exit 1
fi

if declare -f serversentry_log >/dev/null 2>&1; then
  echo "✅ serversentry_log function available"
else
  echo "❌ serversentry_log function missing"
  exit 1
fi

# Test 4: Minimal Initialization
echo ""
echo "Test 4: Minimal Initialization"
echo "------------------------------"
if serversentry_init "minimal"; then
  echo "✅ Minimal initialization successful"
else
  echo "❌ Minimal initialization failed"
  exit 1
fi

# Test 5: Path Resolution
echo ""
echo "Test 5: Path Resolution"
echo "-----------------------"
test_path=$(serversentry_resolve_path "lib/core")
if [[ "$test_path" == "$SERVERSENTRY_CORE_DIR" ]]; then
  echo "✅ Path resolution working: $test_path"
else
  echo "❌ Path resolution failed: expected $SERVERSENTRY_CORE_DIR, got $test_path"
  exit 1
fi

# Test 6: Backward Compatibility
echo ""
echo "Test 6: Backward Compatibility"
echo "------------------------------"
if [[ "${BASE_DIR:-}" == "${SERVERSENTRY_ROOT:-}" ]]; then
  echo "✅ BASE_DIR backward compatibility working"
else
  echo "❌ BASE_DIR backward compatibility failed"
  exit 1
fi

# Test 7: Function Analysis Tools
echo ""
echo "Test 7: Function Analysis Tools"
echo "-------------------------------"
if ./tools/function-analysis/analyze.sh --help >/dev/null 2>&1; then
  echo "✅ Function analysis tools working"
else
  echo "❌ Function analysis tools failed"
  exit 1
fi

# Test 8: Example Script
echo ""
echo "Test 8: Example Script"
echo "----------------------"
if ./example-script.sh --test >/dev/null 2>&1; then
  echo "✅ Example script working"
else
  echo "❌ Example script failed"
  exit 1
fi

echo ""
echo "🎉 All Bootstrap Migration Tests Passed!"
echo "========================================"
echo ""
echo "Migration Summary:"
echo "• ✅ Bootstrap system working"
echo "• ✅ Environment variables set"
echo "• ✅ Core functions available"
echo "• ✅ Initialization working"
echo "• ✅ Path resolution working"
echo "• ✅ Backward compatibility working"
echo "• ✅ Function analysis tools working"
echo "• ✅ Example script working"
echo ""
echo "🚀 ServerSentry Bootstrap Migration: SUCCESSFUL"
