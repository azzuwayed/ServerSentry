#!/usr/bin/env bash
#
# ServerSentry v2 - Basic Integration Test
#
# This script tests the basic functionality of ServerSentry v2

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Set up test environment
echo "Setting up test environment..."
mkdir -p "$BASE_DIR/logs"

# Define test output color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test function
run_test() {
  local test_name="$1"
  local command="$2"
  local expected_exit_code="${3:-0}"

  echo -n "Running test: $test_name... "

  # Run the command and capture exit code
  set +e
  eval "$command" >/tmp/serversentry_test_output 2>&1
  local exit_code=$?
  set -e

  # Check if exit code matches expected
  if [ $exit_code -eq "$expected_exit_code" ]; then
    echo -e "${GREEN}PASS${NC}"
    return 0
  else
    echo -e "${RED}FAIL${NC} (expected: $expected_exit_code, got: $exit_code)"
    echo -e "${YELLOW}Command output:${NC}"
    cat /tmp/serversentry_test_output
    return 1
  fi
}

# Run the tests
echo "Starting tests..."

# Test 1: Check if the main script exists and is executable
run_test "Main script exists" "[ -x \"$BASE_DIR/bin/serversentry\" ]"

# Test 2: Run version command
run_test "Version command" "\"$BASE_DIR/bin/serversentry\" version"

# Test 3: Check help command
run_test "Help command" "\"$BASE_DIR/bin/serversentry\" help"

# Test 4: Run CPU check
run_test "CPU check" "\"$BASE_DIR/bin/serversentry\" check cpu"

# Test 5: Run memory check
run_test "Memory check" "\"$BASE_DIR/bin/serversentry\" check memory"

# Test 6: Run disk check
run_test "Disk check" "\"$BASE_DIR/bin/serversentry\" check disk"

# Test 7: Run process check (may fail if no processes configured)
run_test "Process check" "\"$BASE_DIR/bin/serversentry\" check process" 0

# Test 8: Run status command
run_test "Status command" "\"$BASE_DIR/bin/serversentry\" status"

# Test 9: Run list command
run_test "List command" "\"$BASE_DIR/bin/serversentry\" list"

# Test 10: Check logs command
run_test "Logs command" "\"$BASE_DIR/bin/serversentry\" logs view"

# Test 11: Start monitoring (this will run in background)
run_test "Start monitoring" "\"$BASE_DIR/bin/serversentry\" start"

# Test 12: Check if monitoring is running
run_test "Check monitoring running" "[ -f \"$BASE_DIR/serversentry.pid\" ] && ps -p \$(cat \"$BASE_DIR/serversentry.pid\") > /dev/null"

# Test 13: Stop monitoring
run_test "Stop monitoring" "\"$BASE_DIR/bin/serversentry\" stop"

# Clean up test environment
echo "Cleaning up test environment..."
rm -f /tmp/serversentry_test_output

echo "All tests completed!"
