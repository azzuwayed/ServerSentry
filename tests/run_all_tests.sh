#!/usr/bin/env bash
#
# ServerSentry v2 - Test Runner
#
# This script runs all test suites and provides a comprehensive report
# of test results, including security, functionality, and performance tests

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# Source standardized color functions
if [[ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]]; then
  source "$BASE_DIR/lib/ui/cli/colors.sh"
else
  # Fallback definitions if colors.sh not available
  print_success() { echo "✅ $*"; }
  print_error() { echo "❌ $*"; }
  print_warning() { echo "⚠️ $*"; }
  print_info() { echo "ℹ️ $*"; }
  print_header() { echo "$*"; }
  print_status() {
    shift
    echo "$*"
  }
  print_separator() { echo "═══════════════════════════════════════════════════════════════"; }
fi

# Test results tracking
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_SUITES=()

# Function to run a test suite
run_test_suite() {
  local test_name="$1"
  local test_script="$2"
  local test_type="$3"

  echo ""
  print_separator
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}Running $test_type: $test_name${RESET}"
  else
    echo "Running $test_type: $test_name"
  fi
  print_separator

  if [[ ! -f "$test_script" ]]; then
    print_error "Test script not found: $test_script"
    FAILED_SUITES+=("$test_name (script not found)")
    return 1
  fi

  if [[ ! -x "$test_script" ]]; then
    chmod +x "$test_script"
  fi

  local start_time=$(date +%s)
  local test_output
  local exit_code

  # Run the test and capture output
  if test_output=$("$test_script" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Parse test results from output
  local tests_run=$(echo "$test_output" | grep -o "Tests.*completed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
  local tests_passed=$(echo "$test_output" | grep -o "Tests passed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
  local tests_failed=$(echo "$test_output" | grep -o "Tests failed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")

  # Update totals
  TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
  TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
  TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))

  # Display results
  if [[ $exit_code -eq 0 ]]; then
    print_success "$test_name PASSED (${tests_run} tests, ${duration}s)"
    if [[ $tests_failed -gt 0 ]]; then
      print_warning "Warning: $tests_failed tests failed but suite passed"
    fi
  else
    print_error "$test_name FAILED (exit code: $exit_code, ${duration}s)"
    FAILED_SUITES+=("$test_name")

    # Show last few lines of output for failed tests
    print_warning "Last few lines of output:"
    echo "$test_output" | tail -10 | sed 's/^/  /'
  fi

  # Show detailed breakdown
  if [[ $tests_run -gt 0 ]]; then
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "   Tests: ${INFO_COLOR}$tests_run${RESET} | Passed: ${SUCCESS_COLOR}$tests_passed${RESET} | Failed: ${ERROR_COLOR}$tests_failed${RESET}"
    else
      echo "   Tests: $tests_run | Passed: $tests_passed | Failed: $tests_failed"
    fi
  fi

  return $exit_code
}

# Function to print summary
print_summary() {
  echo ""
  print_separator
  print_header "TEST SUITE SUMMARY REPORT" 64
  print_separator

  echo ""
  print_info "Overall Results:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "  Total Tests: ${INFO_COLOR}$TOTAL_TESTS${RESET}"
    echo -e "  Tests Passed: ${SUCCESS_COLOR}$TOTAL_PASSED${RESET}"
    echo -e "  Tests Failed: ${ERROR_COLOR}$TOTAL_FAILED${RESET}"
  else
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Tests Passed: $TOTAL_PASSED"
    echo "  Tests Failed: $TOTAL_FAILED"
  fi

  if [[ $TOTAL_TESTS -gt 0 ]]; then
    local success_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "  Success Rate: ${CYAN}${success_rate}%${RESET}"
    else
      echo "  Success Rate: ${success_rate}%"
    fi
  fi

  if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    echo ""
    print_success "🎉 ALL TEST SUITES PASSED! 🎉"
    print_success "ServerSentry v2 is ready for production!"
  else
    echo ""
    print_error "Failed Test Suites:"
    for suite in "${FAILED_SUITES[@]}"; do
      if [[ "$COLOR_SUPPORT" == "true" ]]; then
        echo -e "  ${ERROR_COLOR}• $suite${RESET}"
      else
        echo "  • $suite"
      fi
    done
    echo ""
    print_warning "Please fix the failing tests before deployment."
  fi
}

# Function to check prerequisites
check_prerequisites() {
  print_info "Checking prerequisites..."

  local missing_deps=()

  # Check for required commands
  for cmd in bash jq bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_error "Missing required dependencies:"
    for dep in "${missing_deps[@]}"; do
      if [[ "$COLOR_SUPPORT" == "true" ]]; then
        echo -e "  ${ERROR_COLOR}• $dep${RESET}"
      else
        echo "  • $dep"
      fi
    done
    print_warning "Please install missing dependencies and try again."
    return 1
  fi

  print_success "All prerequisites satisfied"
  return 0
}

# Function to setup test environment
setup_test_environment() {
  print_info "Setting up test environment..."

  # Ensure log directory exists
  mkdir -p "$BASE_DIR/logs"

  # Clean up any previous test artifacts
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true
  rm -f "$BASE_DIR/logs/test_"* 2>/dev/null || true

  # Set test environment variables
  export SERVERSENTRY_TEST_MODE=1
  export BASE_DIR="$BASE_DIR"

  print_success "Test environment ready"
}

# Function to cleanup test environment
cleanup_test_environment() {
  print_info "Cleaning up test environment..."

  # Remove test artifacts
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true
  rm -f "$BASE_DIR/logs/test_"* 2>/dev/null || true

  # Unset test environment variables
  unset SERVERSENTRY_TEST_MODE

  print_success "Test environment cleaned"
}

# Main execution
main() {
  print_header "ServerSentry v2 - Comprehensive Test Suite" 64
  print_separator

  # Check prerequisites
  if ! check_prerequisites; then
    exit 1
  fi

  # Setup test environment
  setup_test_environment

  local start_time=$(date +%s)

  # Run unit tests
  echo ""
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}🧪 RUNNING UNIT TESTS${RESET}"
  else
    echo "🧪 RUNNING UNIT TESTS"
  fi
  run_test_suite "Security Tests" "$SCRIPT_DIR/unit/security_test.sh" "Security Unit Test"
  run_test_suite "Utils Tests" "$SCRIPT_DIR/unit/utils_test.sh" "Utilities Unit Test"
  run_test_suite "Composite Tests" "$SCRIPT_DIR/unit/composite_test.sh" "Composite System Unit Test"
  run_test_suite "Logging Tests" "$SCRIPT_DIR/unit/logging_test.sh" "Logging System Unit Test"

  # Run integration tests
  echo ""
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}🔗 RUNNING INTEGRATION TESTS${RESET}"
  else
    echo "🔗 RUNNING INTEGRATION TESTS"
  fi
  run_test_suite "Basic Integration" "$SCRIPT_DIR/integration/basic_test.sh" "Basic Integration Test"
  run_test_suite "Security Integration" "$SCRIPT_DIR/integration/security_integration_test.sh" "Security Integration Test"

  # Calculate total execution time
  local end_time=$(date +%s)
  local total_duration=$((end_time - start_time))

  # Cleanup test environment
  cleanup_test_environment

  # Print final summary
  print_summary

  echo ""
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}Total execution time: ${total_duration}s${RESET}"
  else
    echo "Total execution time: ${total_duration}s"
  fi

  # Exit with appropriate code
  if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# Handle script arguments
case "${1:-}" in
--help | -h)
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --help, -h        Show this help message"
  echo "  --security        Run only security tests"
  echo "  --unit            Run only unit tests"
  echo "  --integration     Run only integration tests"
  echo "  --verbose         Show detailed output"
  echo ""
  echo "Examples:"
  echo "  $0                Run all tests"
  echo "  $0 --security     Run only security tests"
  echo "  $0 --unit         Run only unit tests"
  exit 0
  ;;
--security)
  check_prerequisites && setup_test_environment
  run_test_suite "Security Tests" "$SCRIPT_DIR/unit/security_test.sh" "Security Unit Test"
  cleanup_test_environment
  print_summary
  ;;
--unit)
  check_prerequisites && setup_test_environment
  echo ""
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}🧪 RUNNING UNIT TESTS${RESET}"
  else
    echo "🧪 RUNNING UNIT TESTS"
  fi
  run_test_suite "Security Tests" "$SCRIPT_DIR/unit/security_test.sh" "Security Unit Test"
  run_test_suite "Utils Tests" "$SCRIPT_DIR/unit/utils_test.sh" "Utilities Unit Test"
  run_test_suite "Composite Tests" "$SCRIPT_DIR/unit/composite_test.sh" "Composite System Unit Test"
  run_test_suite "Logging Tests" "$SCRIPT_DIR/unit/logging_test.sh" "Logging System Unit Test"
  cleanup_test_environment
  print_summary
  ;;
--integration)
  check_prerequisites && setup_test_environment
  echo ""
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}🔗 RUNNING INTEGRATION TESTS${RESET}"
  else
    echo "🔗 RUNNING INTEGRATION TESTS"
  fi
  run_test_suite "Basic Integration" "$SCRIPT_DIR/integration/basic_test.sh" "Basic Integration Test"
  run_test_suite "Security Integration" "$SCRIPT_DIR/integration/security_integration_test.sh" "Security Integration Test"
  cleanup_test_environment
  print_summary
  ;;
"")
  # Run all tests (default)
  main
  ;;
*)
  echo "Unknown option: $1"
  echo "Use --help for usage information"
  exit 1
  ;;
esac
