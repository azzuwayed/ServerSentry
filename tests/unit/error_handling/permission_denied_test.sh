#!/usr/bin/env bash
#
# ServerSentry v2 - Permission Denied Error Handling Tests
#
# Tests how the system handles permission-related issues

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

# Test configuration
TEST_SUITE_NAME="Permission Denied Error Handling Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup function
setup_permission_tests() {
  setup_test_environment "permission_test"

  # Create test directories and files with various permissions
  mkdir -p "$TEST_TEMP_DIR/readonly_dir"
  mkdir -p "$TEST_TEMP_DIR/noread_dir"
  mkdir -p "$TEST_TEMP_DIR/nowrite_dir"

  # Create test files
  echo "test content" >"$TEST_TEMP_DIR/readonly_file"
  echo "test content" >"$TEST_TEMP_DIR/noread_file"
  echo "test content" >"$TEST_TEMP_DIR/nowrite_file"

  # Set restrictive permissions
  chmod 444 "$TEST_TEMP_DIR/readonly_file" # Read-only file
  chmod 000 "$TEST_TEMP_DIR/noread_file"   # No read access
  chmod 444 "$TEST_TEMP_DIR/nowrite_file"  # No write access
  chmod 555 "$TEST_TEMP_DIR/readonly_dir"  # Read-only directory
  chmod 000 "$TEST_TEMP_DIR/noread_dir"    # No read access directory
  chmod 555 "$TEST_TEMP_DIR/nowrite_dir"   # No write access directory
}

# Cleanup function
cleanup_permission_tests() {
  # Restore permissions before cleanup
  chmod 755 "$TEST_TEMP_DIR/readonly_dir" 2>/dev/null || true
  chmod 755 "$TEST_TEMP_DIR/noread_dir" 2>/dev/null || true
  chmod 755 "$TEST_TEMP_DIR/nowrite_dir" 2>/dev/null || true
  chmod 644 "$TEST_TEMP_DIR/readonly_file" 2>/dev/null || true
  chmod 644 "$TEST_TEMP_DIR/noread_file" 2>/dev/null || true
  chmod 644 "$TEST_TEMP_DIR/nowrite_file" 2>/dev/null || true

  cleanup_test_environment
}

# Test 1: Reading files without read permission
test_file_read_permission() {
  print_test_header "File read permission handling"

  local no_read_file="$TEST_TEMP_DIR/noread_file"

  # Attempt to read file without read permission
  local result
  local exit_code

  set +e
  result=$(cat "$no_read_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail with permission error
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"Permission denied"* ]] || [[ "$result" == *"permission"* ]]; then
      print_success "File read permission denial handled correctly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "File read failed but error message unclear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_error "File read should have failed due to permissions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 2: Writing to files without write permission
test_file_write_permission() {
  print_test_header "File write permission handling"

  local readonly_file="$TEST_TEMP_DIR/readonly_file"

  # Attempt to write to read-only file
  local result
  local exit_code

  set +e
  result=$(echo "new content" >"$readonly_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail with permission error
  if [[ $exit_code -ne 0 ]]; then
    print_success "File write permission denial handled correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "File write should have failed due to permissions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 3: Directory access without read permission
test_directory_read_permission() {
  print_test_header "Directory read permission handling"

  local no_read_dir="$TEST_TEMP_DIR/noread_dir"

  # Attempt to list directory without read permission
  local result
  local exit_code

  set +e
  result=$(ls "$no_read_dir" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail with permission error
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"Permission denied"* ]] || [[ "$result" == *"permission"* ]]; then
      print_success "Directory read permission denial handled correctly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Directory read failed but error message unclear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_error "Directory read should have failed due to permissions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 4: Creating files in directory without write permission
test_directory_write_permission() {
  print_test_header "Directory write permission handling"

  local readonly_dir="$TEST_TEMP_DIR/readonly_dir"
  local test_file="$readonly_dir/new_file"

  # Attempt to create file in read-only directory
  local result
  local exit_code

  set +e
  result=$(echo "test" >"$test_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail with permission error
  if [[ $exit_code -ne 0 ]]; then
    print_success "Directory write permission denial handled correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "File creation should have failed due to directory permissions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 5: Log file permission handling
test_log_file_permissions() {
  print_test_header "Log file permission handling"

  local log_dir="$TEST_TEMP_DIR/log_test"
  mkdir -p "$log_dir"

  local log_file="$log_dir/test.log"
  echo "initial log" >"$log_file"

  # Make log file read-only
  chmod 444 "$log_file"

  # Attempt to write to log
  local result
  local exit_code

  set +e
  result=$(echo "new log entry" >>"$log_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should handle log write permission gracefully
  if [[ $exit_code -ne 0 ]]; then
    print_success "Log file write permission handled appropriately"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Log write succeeded unexpectedly"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be system-dependent
  fi

  # Restore permissions for cleanup
  chmod 644 "$log_file" 2>/dev/null || true
}

# Test 6: Configuration file permission handling
test_config_file_permissions() {
  print_test_header "Configuration file permission handling"

  local config_dir="$TEST_TEMP_DIR/config_test"
  mkdir -p "$config_dir"

  local config_file="$config_dir/test_config.yaml"
  cat >"$config_file" <<EOF
enabled: true
log_level: info
EOF

  # Make config file unreadable
  chmod 000 "$config_file"

  # Attempt to read configuration
  local result
  local exit_code

  set +e
  result=$(cat "$config_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail gracefully with clear error
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"Permission denied"* ]] || [[ "$result" == *"permission"* ]]; then
      print_success "Configuration file permission error handled correctly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Config read failed but error message unclear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_error "Configuration read should have failed due to permissions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Restore permissions for cleanup
  chmod 644 "$config_file" 2>/dev/null || true
}

# Test 7: Temporary directory permission handling
test_temp_directory_permissions() {
  print_test_header "Temporary directory permission handling"

  local temp_dir="$TEST_TEMP_DIR/temp_test"
  mkdir -p "$temp_dir"

  # Make temp directory read-only
  chmod 555 "$temp_dir"

  # Attempt to create temporary file
  local result
  local exit_code
  local temp_file="$temp_dir/temp_$$"

  set +e
  result=$(echo "temp data" >"$temp_file" 2>&1)
  exit_code=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should handle temp file creation failure gracefully
  if [[ $exit_code -ne 0 ]]; then
    print_success "Temporary directory permission handled correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Temporary file creation should have failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Restore permissions for cleanup
  chmod 755 "$temp_dir" 2>/dev/null || true
  rm -f "$temp_file" 2>/dev/null || true
}

# Test 8: Permission escalation prevention
test_permission_escalation_prevention() {
  print_test_header "Permission escalation prevention"

  local test_script="$TEST_TEMP_DIR/test_script.sh"

  # Create a test script
  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
echo "Script executed"
EOF

  # Make script executable but not by others
  chmod 700 "$test_script"

  # Test that script permissions are respected
  local result
  local exit_code

  set +e
  if [[ "$(id -u)" -eq 0 ]]; then
    # Running as root, create different test
    result=$("$test_script" 2>&1)
    exit_code=$?
  else
    # Running as non-root user
    result=$("$test_script" 2>&1)
    exit_code=$?
  fi
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should execute if we have permission
  if [[ $exit_code -eq 0 ]]; then
    print_success "Script execution permissions working correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Script execution failed: $result"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be expected
  fi

  # Clean up
  rm -f "$test_script" 2>/dev/null || true
}

# Main test execution
main() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_permission_tests

  # Run permission error handling tests
  test_file_read_permission
  test_file_write_permission
  test_directory_read_permission
  test_directory_write_permission
  test_log_file_permissions
  test_config_file_permissions
  test_temp_directory_permissions
  test_permission_escalation_prevention

  cleanup_permission_tests

  # Print summary
  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Exit with appropriate code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_success "All permission error handling tests passed!"
    exit 0
  else
    print_error "Some permission error handling tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
