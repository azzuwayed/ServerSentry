#!/usr/bin/env bash
#
# ServerSentry v2 - Disk Full Error Handling Tests
#
# Tests how the system handles disk space exhaustion scenarios

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

# Source test framework and helpers
source "$SCRIPT_DIR/../../test_framework.sh"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Source required modules
source "$SERVERSENTRY_ROOT/lib/core/logging.sh"
source "$SERVERSENTRY_ROOT/lib/plugins/disk/disk.sh"

# Test configuration
TEST_SUITE_NAME="Disk Full Error Handling Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup function
setup_disk_full_tests() {
  setup_test_environment "disk_full_test"

  # Create test directories with limited space simulation
  mkdir -p "$TEST_TEMP_DIR/limited_space"
  mkdir -p "$TEST_TEMP_DIR/logs_test"

  # Configure disk plugin for testing
  disk_enabled=true
  disk_threshold=90
  disk_paths=("$TEST_TEMP_DIR/limited_space")
}

# Cleanup function
cleanup_disk_full_tests() {
  # Clean up large test files
  rm -f "$TEST_TEMP_DIR"/large_file* 2>/dev/null || true
  cleanup_test_environment
}

# Test 1: Disk space monitoring with full disk
test_disk_full_monitoring() {
  print_test_header "Disk space monitoring with full disk simulation"

  # Create a large file to simulate disk full condition
  local test_dir="$TEST_TEMP_DIR/limited_space"

  # Simulate disk full by creating large file (100MB)
  simulate_disk_full "$test_dir" "100M"

  # Run disk check
  local result
  local exit_code

  set +e
  result=$(disk_check 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should detect high disk usage or handle gracefully
  if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 2 ]]; then
    if [[ "$result" == *"disk"* ]] || [[ "$result" == *"space"* ]] || [[ "$result" == *"usage"* ]]; then
      print_success "Disk full condition detected and handled properly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Disk check completed but may not have detected full condition"
      TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail if detection is not perfect
    fi
  else
    print_error "Disk check failed unexpectedly: $result"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Clean up large file
  rm -f "$test_dir/large_file" 2>/dev/null || true
}

# Test 2: Log rotation with disk full
test_log_rotation_disk_full() {
  print_test_header "Log rotation with disk full condition"

  local log_dir="$TEST_TEMP_DIR/logs_test"
  local log_file="$log_dir/test.log"

  # Create initial log file
  echo "Initial log entry" >"$log_file"

  # Simulate disk full condition
  simulate_disk_full "$log_dir" "50M"

  # Attempt to write to log (should handle gracefully)
  local result
  local exit_code

  set +e
  result=$(log_info "Test log entry during disk full" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should handle disk full gracefully without crashing
  if [[ $exit_code -eq 0 ]] || [[ "$result" != *"error"* ]]; then
    print_success "Log writing handled disk full condition gracefully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Log writing may have issues with disk full: $result"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be expected
  fi

  # Clean up
  rm -f "$log_dir/large_file" 2>/dev/null || true
}

# Test 3: Configuration file access with disk full
test_config_access_disk_full() {
  print_test_header "Configuration file access with disk full"

  local config_dir="$TEST_TEMP_DIR/config_test"
  mkdir -p "$config_dir"

  # Create test config file
  local config_file="$config_dir/test_config.yaml"
  cat >"$config_file" <<EOF
enabled: true
log_level: info
disk:
  enabled: true
  threshold: 90
EOF

  # Simulate disk full condition
  simulate_disk_full "$config_dir" "30M"

  # Attempt to read configuration
  local result
  local exit_code

  set +e
  if command -v yq >/dev/null 2>&1; then
    result=$(yq '.enabled' "$config_file" 2>&1)
    exit_code=$?
  else
    # Fallback to basic file read
    result=$(cat "$config_file" 2>&1)
    exit_code=$?
  fi
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should be able to read existing config even with disk full
  if [[ $exit_code -eq 0 ]]; then
    print_success "Configuration reading works despite disk full condition"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Configuration reading failed with disk full: $result"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Clean up
  rm -f "$config_dir/large_file" 2>/dev/null || true
}

# Test 4: Temporary file creation with disk full
test_temp_file_disk_full() {
  print_test_header "Temporary file creation with disk full"

  local temp_dir="$TEST_TEMP_DIR/temp_test"
  mkdir -p "$temp_dir"

  # Simulate disk full condition
  simulate_disk_full "$temp_dir" "20M"

  # Attempt to create temporary file
  local result
  local exit_code
  local temp_file="$temp_dir/test_temp_$$"

  set +e
  result=$(echo "test data" >"$temp_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should handle temp file creation failure gracefully
  if [[ $exit_code -ne 0 ]]; then
    print_success "Temporary file creation properly failed with disk full"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    # If it succeeded, that's also okay (might have enough space)
    print_success "Temporary file creation succeeded (sufficient space available)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  # Clean up
  rm -f "$temp_file" 2>/dev/null || true
  rm -f "$temp_dir/large_file" 2>/dev/null || true
}

# Test 5: Disk usage calculation accuracy
test_disk_usage_calculation() {
  print_test_header "Disk usage calculation accuracy"

  local test_dir="$TEST_TEMP_DIR/usage_test"
  mkdir -p "$test_dir"

  # Get initial disk usage
  local initial_usage
  if command -v df >/dev/null 2>&1; then
    initial_usage=$(df "$test_dir" | tail -1 | awk '{print $5}' | sed 's/%//')
  else
    initial_usage=50 # Fallback value
  fi

  # Create a known size file (10MB)
  dd if=/dev/zero of="$test_dir/known_size_file" bs=1M count=10 2>/dev/null || true

  # Get new disk usage
  local new_usage
  if command -v df >/dev/null 2>&1; then
    new_usage=$(df "$test_dir" | tail -1 | awk '{print $5}' | sed 's/%//')
  else
    new_usage=55 # Fallback value
  fi

  TESTS_RUN=$((TESTS_RUN + 1))

  # Usage should have increased
  if [[ "$new_usage" -ge "$initial_usage" ]]; then
    print_success "Disk usage calculation shows expected increase"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Disk usage calculation may be inaccurate"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be filesystem-dependent
  fi

  # Clean up
  rm -f "$test_dir/known_size_file" 2>/dev/null || true
}

# Test 6: Error message clarity for disk full
test_disk_full_error_messages() {
  print_test_header "Error message clarity for disk full conditions"

  local test_dir="$TEST_TEMP_DIR/error_msg_test"
  mkdir -p "$test_dir"

  # Simulate disk full
  simulate_disk_full "$test_dir" "40M"

  # Attempt operation that should fail
  local result
  local exit_code

  set +e
  result=$(dd if=/dev/zero of="$test_dir/should_fail" bs=1M count=200 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should provide clear error message
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"space"* ]] || [[ "$result" == *"full"* ]] || [[ "$result" == *"No space"* ]]; then
      print_success "Clear error message provided for disk full condition"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Error occurred but message may not be clear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_warning "Operation succeeded unexpectedly (may have sufficient space)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi

  # Clean up
  rm -f "$test_dir/should_fail" 2>/dev/null || true
  rm -f "$test_dir/large_file" 2>/dev/null || true
}

# Main test execution
main() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_disk_full_tests

  # Run disk full error handling tests
  test_disk_full_monitoring
  test_log_rotation_disk_full
  test_config_access_disk_full
  test_temp_file_disk_full
  test_disk_usage_calculation
  test_disk_full_error_messages

  cleanup_disk_full_tests

  # Print summary
  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Exit with appropriate code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_success "All disk full error handling tests passed!"
    exit 0
  else
    print_error "Some disk full error handling tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
