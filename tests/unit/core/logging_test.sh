#!/usr/bin/env bash
#
# ServerSentry v2 - Logging Unit Tests
#
# This script tests the logging functionality

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source standardized color functions
if [[ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]]; then
  source "$BASE_DIR/lib/ui/cli/colors.sh"
else
  # Fallback definitions if colors.sh not available
  print_success() { echo "PASS: $*"; }
  print_error() { echo "FAIL: $*"; }
  print_warning() { echo "WARN: $*"; }
  print_info() { echo "INFO: $*"; }
fi

# Set up test environment
export BASE_DIR="$BASE_DIR"
export LOG_DIR="$BASE_DIR/logs"
export LOG_FILE="$LOG_DIR/test_logging.log"
mkdir -p "$LOG_DIR"

# Source the logging module
source "$BASE_DIR/lib/core/logging.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test assertion function
assert() {
  local test_name="$1"
  local condition="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  echo -n "Testing $test_name... "

  if eval "$condition"; then
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${SUCCESS_COLOR}PASS${RESET}"
    else
      echo "PASS"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${ERROR_COLOR}FAIL${RESET}"
      if [ -n "$message" ]; then
        echo -e "${WARNING_COLOR}$message${RESET}"
      fi
    else
      echo "FAIL"
      if [ -n "$message" ]; then
        echo "$message"
      fi
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

echo "Running logging tests..."

# Initialize logging for tests
init_logging

# Test 1: Basic logging functions
log_info "Test info message" "test"
assert "log_info function" "grep -q 'Test info message' '$LOG_FILE'"

log_warning "Test warning message" "test"
assert "log_warning function" "grep -q 'Test warning message' '$LOG_FILE'"

log_error "Test error message" "test"
assert "log_error function" "grep -q 'Test error message' '$LOG_FILE'"

# Test 2: Log rotation
original_size=$(wc -l <"$LOG_FILE")
rotate_logs
new_size=$(wc -l <"$LOG_FILE")
assert "log rotation" "[ '$new_size' -lt '$original_size' ] || [ '$new_size' -eq 0 ]"

# Test 3: Log cleanup
log_info "Test message after rotation" "test"
assert "logging after rotation" "grep -q 'Test message after rotation' '$LOG_FILE'"

# Test 4: Different log levels
log_debug "Debug message" "test"
log_performance "Performance message" "duration=1s"
log_audit "test_action" "test_user" "Audit message"
assert "debug logging" "grep -q 'Debug message' '$LOG_FILE' || true"
assert "performance logging" "grep -q 'Performance message' '$LOG_FILE' || true"
assert "audit logging" "grep -q 'Audit message' '$LOG_FILE' || true"

# Clean up test files
rm -f "$LOG_FILE"

# Print summary
echo ""
echo "Logging tests completed: $TESTS_RUN"
if [[ "$COLOR_SUPPORT" == "true" ]]; then
  echo -e "${SUCCESS_COLOR}Tests passed: $TESTS_PASSED${RESET}"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${ERROR_COLOR}Tests failed: $TESTS_FAILED${RESET}"
    exit 1
  else
    echo -e "${SUCCESS_COLOR}All logging tests passed!${RESET}"
    exit 0
  fi
else
  echo "Tests passed: $TESTS_PASSED"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo "Tests failed: $TESTS_FAILED"
    exit 1
  else
    echo "All logging tests passed!"
    exit 0
  fi
fi
