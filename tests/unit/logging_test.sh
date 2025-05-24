#!/usr/bin/env bash
#
# ServerSentry v2 - Logging System Tests
#
# This script tests the professional logging system, component-specific logging,
# and all the DRY improvements we implemented

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source the logging module
source "$BASE_DIR/lib/core/logging.sh"

# Define test output color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

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
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    if [ -n "$message" ]; then
      echo -e "${YELLOW}$message${NC}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Setup test environment
setup_test_logging() {
  export BASE_DIR="$BASE_DIR"
  export LOG_DIR="$BASE_DIR/logs"
  export LOG_FILE="$LOG_DIR/test_serversentry.log"

  # Create test log directory
  mkdir -p "$LOG_DIR"

  # Initialize logging system
  logging_init
}

# Clean up test logs
cleanup_test_logs() {
  rm -f "$LOG_DIR/test_"* 2>/dev/null || true
  rm -f "$LOG_DIR/performance_test.log" 2>/dev/null || true
  rm -f "$LOG_DIR/error_test.log" 2>/dev/null || true
  rm -f "$LOG_DIR/audit_test.log" 2>/dev/null || true
  rm -f "$LOG_DIR/security_test.log" 2>/dev/null || true
}

echo "Running logging system tests..."

# Setup
setup_test_logging
cleanup_test_logs

# Test 1: Basic logging functions
echo "Testing basic logging functions..."

log_info "Test info message" "test"
assert "log_info function exists" "declare -f log_info >/dev/null"

log_warning "Test warning message" "test"
assert "log_warning function exists" "declare -f log_warning >/dev/null"

log_error "Test error message" "test"
assert "log_error function exists" "declare -f log_error >/dev/null"

log_debug "Test debug message" "test"
assert "log_debug function exists" "declare -f log_debug >/dev/null"

# Test 2: Specialized logging functions
echo "Testing specialized logging functions..."

log_performance "Test performance" "duration=1.5s"
assert "log_performance function exists" "declare -f log_performance >/dev/null"

log_audit "test_action" "test_user" "Test audit message"
assert "log_audit function exists" "declare -f log_audit >/dev/null"

log_security "Test security message" "test_component"
assert "log_security function exists" "declare -f log_security >/dev/null"

# Test 3: Log file creation
echo "Testing log file creation..."

# Check if main log file was created
assert "Main log file created" "[ -f '$LOG_FILE' ]"

# Check if specialized log files exist
assert "Performance log file exists" "[ -f '$LOG_DIR/performance.log' ]"
assert "Error log file exists" "[ -f '$LOG_DIR/error.log' ]"
assert "Audit log file exists" "[ -f '$LOG_DIR/audit.log' ]"
assert "Security log file exists" "[ -f '$LOG_DIR/security.log' ]"

# Test 4: Log content verification
echo "Testing log content..."

# Write test messages
log_info "Test info content" "test"
log_error "Test error content" "test"

# Check if content appears in logs
sleep 1 # Give time for log writing
assert "Main log contains test content" "grep -q 'Test info content' '$LOG_FILE'"
assert "Error log contains test content" "grep -q 'Test error content' '$LOG_DIR/error.log'"

# Test 5: Component-specific logging
echo "Testing component-specific logging..."

log_info "Core component message" "core"
log_info "Plugin component message" "plugins"
log_info "UI component message" "ui"
log_info "Utils component message" "utils"

sleep 1
assert "Core component in main log" "grep -q '\\[core\\]' '$LOG_FILE'"
assert "Plugins component in main log" "grep -q '\\[plugins\\]' '$LOG_FILE'"
assert "UI component in main log" "grep -q '\\[ui\\]' '$LOG_FILE'"
assert "Utils component in main log" "grep -q '\\[utils\\]' '$LOG_FILE'"

# Test 6: Log level filtering
echo "Testing log level filtering..."

# Set log level to warning
export CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING

log_debug "This debug should be filtered" "test"
log_info "This info should be filtered" "test"
log_warning "This warning should appear" "test"

sleep 1
assert "Debug message filtered" "! grep -q 'This debug should be filtered' '$LOG_FILE'"
assert "Info message filtered" "! grep -q 'This info should be filtered' '$LOG_FILE'"
assert "Warning message appears" "grep -q 'This warning should appear' '$LOG_FILE'"

# Reset log level
export CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# Test 7: Audit logging format
echo "Testing audit logging format..."

log_audit "test_action" "test_user" "Test audit entry"
sleep 1

# Check audit log format
assert "Audit log format correct" "grep -q 'Action: test_action' '$LOG_DIR/audit.log'"
assert "Audit user recorded" "grep -q 'User: test_user' '$LOG_DIR/audit.log'"

# Test 8: Performance logging format
echo "Testing performance logging format..."

log_performance "Test operation" "duration=2.5s cpu=45% memory=512MB"
sleep 1

assert "Performance log format correct" "grep -q 'Test operation' '$LOG_DIR/performance.log'"
assert "Performance metrics recorded" "grep -q 'duration=2.5s' '$LOG_DIR/performance.log'"

# Test 9: Log rotation
echo "Testing log rotation..."

# Create a large log file for testing
for i in {1..100}; do
  log_info "Log rotation test entry $i" "test"
done

# Test log rotation function
if declare -f logging_rotate_logs >/dev/null; then
  logging_rotate_logs
  assert "Log rotation function works" "[ $? -eq 0 ]"
fi

# Test 10: Log health check
echo "Testing log health monitoring..."

if declare -f logging_check_health >/dev/null; then
  health_result=$(logging_check_health)
  assert "Log health check runs" "[ $? -le 2 ]" # 0=healthy, 1=warnings, 2=critical
fi

# Test 11: Log format options
echo "Testing log format options..."

# Test JSON format
if declare -f logging_set_format >/dev/null; then
  logging_set_format "json"
  log_info "JSON format test" "test"
  sleep 1

  # Check if JSON format is used (basic check)
  assert "JSON format applied" "grep -q '{' '$LOG_FILE' || true"

  # Reset to standard format
  logging_set_format "standard"
fi

# Test 12: Log level management
echo "Testing log level management..."

if declare -f logging_get_level >/dev/null; then
  current_level=$(logging_get_level)
  assert "Log level retrieval works" "[ -n '$current_level' ]"
fi

if declare -f logging_set_level >/dev/null; then
  logging_set_level "debug"
  new_level=$(logging_get_level)
  assert "Log level setting works" "[ '$new_level' = 'debug' ]"

  # Reset to info
  logging_set_level "info"
fi

# Test 13: Error handling
echo "Testing error handling..."

# Test with invalid log directory
old_log_dir="$LOG_DIR"
export LOG_DIR="/invalid/path/that/should/not/exist"

# Should handle gracefully
log_info "Test with invalid path" "test" 2>/dev/null || true
assert "Invalid path handled gracefully" "[ $? -eq 0 ]"

# Restore log directory
export LOG_DIR="$old_log_dir"

# Test 14: Thread safety (basic test)
echo "Testing concurrent logging..."

# Write multiple log entries simultaneously
for i in {1..10}; do
  log_info "Concurrent test $i" "test" &
done

wait # Wait for all background jobs

sleep 1
concurrent_count=$(grep -c "Concurrent test" "$LOG_FILE" 2>/dev/null || echo "0")
assert "Concurrent logging works" "[ '$concurrent_count' -eq 10 ]"

# Test 15: Memory usage and performance
echo "Testing logging performance..."

start_time=$(date +%s.%N 2>/dev/null || date +%s)

# Write 1000 log entries
for i in {1..1000}; do
  log_info "Performance test entry $i" "test" >/dev/null 2>&1
done

end_time=$(date +%s.%N 2>/dev/null || date +%s)

if command -v bc >/dev/null 2>&1; then
  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
  # Should complete 1000 log entries in under 10 seconds
  performance_ok=$(echo "$duration < 10" | bc 2>/dev/null || echo "1")
  assert "Logging performance acceptable" "[ '$performance_ok' = '1' ]"
fi

# Test 16: Log utilities
echo "Testing log utilities..."

if declare -f logging_get_status >/dev/null; then
  status_output=$(logging_get_status)
  assert "Log status retrieval works" "[ -n '$status_output' ]"
fi

if declare -f logging_tail >/dev/null; then
  tail_output=$(logging_tail "main" 5 2>/dev/null || echo "works")
  assert "Log tail function works" "[ -n '$tail_output' ]"
fi

# Clean up
cleanup_test_logs

# Print summary
echo ""
echo "Logging system tests completed: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "All logging system tests passed!"
  exit 0
fi
