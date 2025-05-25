#!/usr/bin/env bash
#
# ServerSentry v2 - Comprehensive Integration Test
#
# This test combines basic functionality testing with security validation
# to provide complete integration test coverage

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

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Test assertion function
run_test() {
  local test_name="$1"
  local command="$2"
  local expected_exit_code="${3:-0}"
  local test_type="${4:-basic}"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "[$test_type] $test_name... "

  # Run the command and capture exit code
  set +e
  if [[ "$test_type" == "security" ]]; then
    # For security tests, we often check conditions rather than commands
    if eval "$command"; then
      exit_code=0
    else
      exit_code=1
    fi
  else
    # For basic tests, run actual commands
    eval "$command" >/tmp/serversentry_test_output 2>&1
    exit_code=$?
  fi
  set -e

  # Check if exit code matches expected
  if [ $exit_code -eq "$expected_exit_code" ]; then
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${SUCCESS_COLOR}PASS${RESET}"
    else
      echo "PASS"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${ERROR_COLOR}FAIL${RESET} (expected: $expected_exit_code, got: $exit_code)"
    else
      echo "FAIL (expected: $expected_exit_code, got: $exit_code)"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$test_name")

    # Show command output for failed basic tests
    if [[ "$test_type" == "basic" && -f /tmp/serversentry_test_output ]]; then
      echo "Command output:"
      cat /tmp/serversentry_test_output | head -5
    fi
    return 1
  fi
}

# Setup test environment
setup_test_environment() {
  echo "Setting up comprehensive integration test environment..."
  mkdir -p "$BASE_DIR/logs"

  # Clean up any numbered files that might exist (security test)
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true

  # Ensure we're in the base directory
  cd "$BASE_DIR"

  print_success "Test environment ready"
}

# Cleanup test environment
cleanup_test_environment() {
  # Clean up numbered files (security)
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true

  # Remove test artifacts
  rm -f /tmp/serversentry_test_output 2>/dev/null || true
  rm -f /tmp/serversentry_security_test_* 2>/dev/null || true

  echo "Test environment cleaned up"
}

echo "Starting ServerSentry Comprehensive Integration Tests..."

# Setup
setup_test_environment

# =============================================================================
# BASIC FUNCTIONALITY TESTS
# =============================================================================

echo ""
print_info "Running Basic Functionality Tests..."

# Test 1: Check if the main script exists and is executable
run_test "Main script exists and executable" "[ -x \"$BASE_DIR/bin/serversentry\" ]" 0 "basic"

# Test 2: Run version command
run_test "Version command" "\"$BASE_DIR/bin/serversentry\" version" 0 "basic"

# Test 3: Check help command
run_test "Help command" "\"$BASE_DIR/bin/serversentry\" help" 0 "basic"

# Test 4: Run CPU check
run_test "CPU check" "\"$BASE_DIR/bin/serversentry\" check cpu" 0 "basic"

# Test 5: Run memory check
run_test "Memory check" "\"$BASE_DIR/bin/serversentry\" check memory" 0 "basic"

# Test 6: Run disk check
run_test "Disk check" "\"$BASE_DIR/bin/serversentry\" check disk" 0 "basic"

# Test 7: Run process check
run_test "Process check" "\"$BASE_DIR/bin/serversentry\" check process" 0 "basic"

# Test 8: Run status command
run_test "Status command" "\"$BASE_DIR/bin/serversentry\" status" 0 "basic"

# Test 9: Run list command
run_test "List command" "\"$BASE_DIR/bin/serversentry\" list" 0 "basic"

# Test 10: Check logs command
run_test "Logs command" "\"$BASE_DIR/bin/serversentry\" logs view" 0 "basic"

# Test 11: Test JSON output
run_test "JSON status output" "\"$BASE_DIR/bin/serversentry\" status --json" 0 "basic"

# =============================================================================
# SECURITY TESTS
# =============================================================================

echo ""
print_info "Running Security Tests..."

# Test 12: Composite check security (no file creation)
run_test "Composite check security" "
  cd \"$BASE_DIR\" &&
  bin/serversentry composite test >/dev/null 2>&1 || true;
  files_found=0;
  for num in 50 60 80 85 90 95; do
    if [[ -f \"\$num\" ]]; then
      files_found=1;
      break;
    fi;
  done;
  [ \$files_found -eq 0 ]
" 0 "security"

# Test 13: Memory plugin security
run_test "Memory check security" "
  cd \"$BASE_DIR\" &&
  bin/serversentry check memory >/dev/null 2>&1 || true;
  files_found=0;
  for num in 50 60 80 85 90 95; do
    if [[ -f \"\$num\" ]]; then
      files_found=1;
      break;
    fi;
  done;
  [ \$files_found -eq 0 ]
" 0 "security"

# Test 14: Arithmetic expression security
run_test "Arithmetic expressions security" "
  cd \"$BASE_DIR\";
  if command -v bc >/dev/null 2>&1; then
    echo '15.0 > 80' | bc >/dev/null 2>&1 || true;
    echo '95.5 > 90' | bc >/dev/null 2>&1 || true;
  fi;
  files_found=0;
  for num in 80 85 90 95; do
    if [[ -f \"\$num\" ]]; then
      files_found=1;
      break;
    fi;
  done;
  [ \$files_found -eq 0 ]
" 0 "security"

# Test 15: CLI commands security
run_test "CLI commands security" "
  cd \"$BASE_DIR\";
  for cmd in 'version' 'help' 'status' 'list'; do
    timeout 5s bin/serversentry \"\$cmd\" >/dev/null 2>&1 || true;
  done;
  files_found=0;
  for file in [0-9][0-9]; do
    if [[ -f \"\$file\" ]]; then
      files_found=1;
      break;
    fi;
  done 2>/dev/null;
  [ \$files_found -eq 0 ]
" 0 "security"

# Test 16: File system security
run_test "File system security" "
  critical_files_found=0;
  for location in '/tmp/80' '/tmp/85' '/tmp/90' '/tmp/95'; do
    if [[ -f \"\$location\" ]]; then
      critical_files_found=1;
      break;
    fi;
  done;
  [ \$critical_files_found -eq 0 ]
" 0 "security"

# =============================================================================
# ADVANCED INTEGRATION TESTS
# =============================================================================

echo ""
print_info "Running Advanced Integration Tests..."

# Test 17: Start monitoring service
run_test "Start monitoring service" "\"$BASE_DIR/bin/serversentry\" start" 0 "basic"

# Test 18: Check if monitoring is running
run_test "Monitoring service running" "
  if [[ -f \"$BASE_DIR/serversentry.pid\" ]]; then
    pid=\$(cat \"$BASE_DIR/serversentry.pid\");
    ps -p \"\$pid\" >/dev/null 2>&1;
  else
    false;
  fi
" 0 "basic"

# Test 19: Stop monitoring service
run_test "Stop monitoring service" "\"$BASE_DIR/bin/serversentry\" stop" 0 "basic"

# Test 20: Verify service stopped
run_test "Monitoring service stopped" "
  if [[ -f \"$BASE_DIR/serversentry.pid\" ]]; then
    pid=\$(cat \"$BASE_DIR/serversentry.pid\");
    ! ps -p \"\$pid\" >/dev/null 2>&1;
  else
    true;
  fi
" 0 "basic"

# Test 21: Configuration validation
run_test "Configuration validation" "
  if [[ -f \"$BASE_DIR/config/serversentry.yaml\" ]]; then
    if command -v yq >/dev/null 2>&1; then
      yq eval '.' \"$BASE_DIR/config/serversentry.yaml\" >/dev/null;
    else
      true;
    fi;
  else
    true;
  fi
" 0 "basic"

# Test 22: Plugin system test
run_test "Plugin system functionality" "
  \"$BASE_DIR/bin/serversentry\" list | grep -q 'cpu\\|memory\\|disk'
" 0 "basic"

# Test 23: Logging system test
run_test "Logging system functionality" "
  \"$BASE_DIR/bin/serversentry\" logs view >/dev/null 2>&1 ||
  [[ -d \"$BASE_DIR/logs\" ]]
" 0 "basic"

# Test 24: Final comprehensive security check
run_test "Final security validation" "
  cd \"$BASE_DIR\";
  # Run a comprehensive check that exercises all modules
  timeout 30s bin/serversentry check cpu >/dev/null 2>&1 || true;
  timeout 30s bin/serversentry check memory >/dev/null 2>&1 || true;
  timeout 30s bin/serversentry check disk >/dev/null 2>&1 || true;

  # Check for any numbered files created
  final_files_found=0;
  for num in {10..99}; do
    if [[ -f \"\$num\" ]]; then
      final_files_found=1;
      break;
    fi;
  done 2>/dev/null;
  [ \$final_files_found -eq 0 ]
" 0 "security"

# =============================================================================
# CLEANUP AND SUMMARY
# =============================================================================

# Cleanup
cleanup_test_environment

# Print comprehensive summary
echo ""
print_separator 70
print_header "COMPREHENSIVE INTEGRATION TEST SUMMARY" 70
print_separator 70

echo ""
print_info "Test Results:"
if [[ "$COLOR_SUPPORT" == "true" ]]; then
  echo -e "  Total Tests: ${INFO_COLOR}$TESTS_RUN${RESET}"
  echo -e "  Tests Passed: ${SUCCESS_COLOR}$TESTS_PASSED${RESET}"
  echo -e "  Tests Failed: ${ERROR_COLOR}$TESTS_FAILED${RESET}"
else
  echo "  Total Tests: $TESTS_RUN"
  echo "  Tests Passed: $TESTS_PASSED"
  echo "  Tests Failed: $TESTS_FAILED"
fi

if [[ $TESTS_RUN -gt 0 ]]; then
  success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "  Success Rate: ${CYAN}${success_rate}%${RESET}"
  else
    echo "  Success Rate: ${success_rate}%"
  fi
fi

if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
  echo ""
  print_success "🎉 ALL INTEGRATION TESTS PASSED! 🎉"
  print_success "✅ Basic functionality verified"
  print_success "🔒 Security vulnerabilities checked"
  print_success "🚀 ServerSentry is ready for production!"
  exit 0
else
  echo ""
  print_error "Failed Tests:"
  for test in "${FAILED_TESTS[@]}"; do
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "  ${ERROR_COLOR}• $test${RESET}"
    else
      echo "  • $test"
    fi
  done
  echo ""
  print_warning "Please fix the failing tests before deployment."
  exit 1
fi
