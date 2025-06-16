#!/usr/bin/env bash
#
# ServerSentry v2 - Reset Functionality Test
#
# Tests the reset script functionality to ensure it properly cleans up the system

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

# Source test framework
source "$SCRIPT_DIR/../../test_framework.sh"

# Test configuration
TEST_NAME="reset_functionality"
RESET_SCRIPT="$SERVERSENTRY_ROOT/tests/reset_serversentry.sh"

# Setup function
setup_reset_functionality_tests() {
  log_info "Setting up reset functionality tests..."
  setup_test_environment "$TEST_NAME"
  log_info "Test environment created"
}

# Cleanup function
cleanup_reset_functionality_tests() {
  log_info "Cleaning up reset functionality tests..."

  # Clean up any remaining test files
  rm -f "$SERVERSENTRY_ROOT/serversentry.pid" 2>/dev/null || true
  rm -f "$SERVERSENTRY_ROOT/logs/serversentry.log" 2>/dev/null || true
  rm -f "$SERVERSENTRY_ROOT/logs/error.log" 2>/dev/null || true
  rm -f "$SERVERSENTRY_ROOT/tmp/plugin_test_cache" 2>/dev/null || true
  rm -f "$SERVERSENTRY_ROOT/tmp/temp_test_file" 2>/dev/null || true
  rm -f "$SERVERSENTRY_ROOT/config/test_config.yaml" 2>/dev/null || true

  cleanup_test_environment
}

# Test 1: Reset script exists and is executable
test_reset_script_exists() {
  log_info "Testing reset script existence and permissions..."

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -f "$RESET_SCRIPT" ]] && [[ -x "$RESET_SCRIPT" ]]; then
    print_success "Reset script exists and is executable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Reset script missing or not executable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 2: Reset script help functionality
test_reset_script_help() {
  log_info "Testing reset script help functionality..."

  TESTS_RUN=$((TESTS_RUN + 1))

  local help_output
  help_output=$("$RESET_SCRIPT" --help 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]] && [[ "$help_output" == *"Usage:"* ]] && [[ "$help_output" == *"--force"* ]]; then
    print_success "Reset script help functionality works"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Reset script help functionality failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 3: Reset script dry-run functionality
test_reset_script_dry_run() {
  log_info "Testing reset script dry-run functionality..."

  TESTS_RUN=$((TESTS_RUN + 1))

  # Create test files first
  echo "test content" >"$SERVERSENTRY_ROOT/logs/serversentry.log"
  echo "12345" >"$SERVERSENTRY_ROOT/serversentry.pid"

  local dry_run_output
  dry_run_output=$("$RESET_SCRIPT" --dry-run 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]] && [[ "$dry_run_output" == *"DRY RUN"* ]] && [[ "$dry_run_output" == *"no actual changes were made"* ]]; then
    # Verify files still exist after dry run
    if [[ -f "$SERVERSENTRY_ROOT/logs/serversentry.log" ]] && [[ -f "$SERVERSENTRY_ROOT/serversentry.pid" ]]; then
      print_success "Reset script dry-run functionality works correctly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Dry-run mode made actual changes"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Reset script dry-run failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Clean up test files
  rm -f "$SERVERSENTRY_ROOT/logs/serversentry.log" "$SERVERSENTRY_ROOT/serversentry.pid"
}

# Test 4: Reset script force mode (actual reset)
test_reset_script_force_mode() {
  log_info "Testing reset script force mode..."

  TESTS_RUN=$((TESTS_RUN + 1))

  # Create test files to be cleaned up
  echo "test log content" >"$SERVERSENTRY_ROOT/logs/serversentry.log"
  echo "test cache" >"$SERVERSENTRY_ROOT/tmp/plugin_test_cache"
  echo "12345" >"$SERVERSENTRY_ROOT/serversentry.pid"

  # Run reset in force mode
  local reset_output
  reset_output=$("$RESET_SCRIPT" --force 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]] && [[ "$reset_output" == *"Reset completed successfully"* ]]; then
    # Verify files were cleaned up
    local cleanup_success=true

    if [[ -f "$SERVERSENTRY_ROOT/serversentry.pid" ]]; then
      cleanup_success=false
    fi

    if [[ -s "$SERVERSENTRY_ROOT/logs/serversentry.log" ]]; then
      cleanup_success=false
    fi

    if [[ -f "$SERVERSENTRY_ROOT/tmp/plugin_test_cache" ]]; then
      cleanup_success=false
    fi

    if [[ "$cleanup_success" == "true" ]]; then
      print_success "Reset script force mode works correctly"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Reset script did not properly clean up files"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Reset script force mode failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 5: Wrapper script functionality
test_wrapper_script() {
  log_info "Testing wrapper script functionality..."

  TESTS_RUN=$((TESTS_RUN + 1))

  local wrapper_script="$SERVERSENTRY_ROOT/bin/reset"

  if [[ -f "$wrapper_script" ]] && [[ -x "$wrapper_script" ]]; then
    # Test wrapper help
    local wrapper_help
    wrapper_help=$("$wrapper_script" --help 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && [[ "$wrapper_help" == *"Usage:"* ]]; then
      print_success "Wrapper script functionality works"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Wrapper script help failed"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Wrapper script missing or not executable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Main test execution
main() {
  print_test_suite_header "Reset Functionality Tests"

  # Initialize test counters
  TESTS_RUN=0
  TESTS_PASSED=0
  TESTS_FAILED=0

  # Setup
  setup_reset_functionality_tests

  # Run tests
  test_reset_script_exists
  test_reset_script_help
  test_reset_script_dry_run
  test_reset_script_force_mode
  test_wrapper_script

  # Cleanup
  cleanup_reset_functionality_tests

  # Print summary
  print_test_suite_summary "$TEST_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Return appropriate exit code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
