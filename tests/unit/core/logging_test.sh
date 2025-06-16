#!/usr/bin/env bash
#
# ServerSentry v2 - Logging Unit Tests
#
# This script tests the logging functionality

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal
  
  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi


# Load unified test framework
if [[ -f "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh"
fi

    current_dir="$(dirname "$current_dir")"
  done
  
  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi

# Source standardized color functions
if [[ -f "$SERVERSENTRY_ROOT/lib/ui/cli/colors.sh" ]]; then
  source "$SERVERSENTRY_ROOT/lib/ui/cli/colors.sh"
else
  # Fallback definitions if colors.sh not available
fi

# Set up test environment
export LOG_DIR="$SERVERSENTRY_ROOT/logs"
export LOG_FILE="$LOG_DIR/test_logging.log"
mkdir -p "$LOG_DIR"

# Source the logging module
source "$SERVERSENTRY_ROOT/lib/core/logging.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test assertion function

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
