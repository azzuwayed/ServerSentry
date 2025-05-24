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

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}Running $test_type: $test_name${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

  if [[ ! -f "$test_script" ]]; then
    echo -e "${RED}❌ Test script not found: $test_script${NC}"
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
    echo -e "${GREEN}✅ $test_name PASSED${NC} (${tests_run} tests, ${duration}s)"
    if [[ $tests_failed -gt 0 ]]; then
      echo -e "${YELLOW}   ⚠️  Warning: $tests_failed tests failed but suite passed${NC}"
    fi
  else
    echo -e "${RED}❌ $test_name FAILED${NC} (exit code: $exit_code, ${duration}s)"
    FAILED_SUITES+=("$test_name")

    # Show last few lines of output for failed tests
    echo -e "${YELLOW}Last few lines of output:${NC}"
    echo "$test_output" | tail -10 | sed 's/^/  /'
  fi

  # Show detailed breakdown
  if [[ $tests_run -gt 0 ]]; then
    echo -e "   Tests: ${BLUE}$tests_run${NC} | Passed: ${GREEN}$tests_passed${NC} | Failed: ${RED}$tests_failed${NC}"
  fi

  return $exit_code
}

# Function to print summary
print_summary() {
  echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${PURPLE}               TEST SUITE SUMMARY REPORT${NC}"
  echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"

  echo -e "\n${BLUE}Overall Results:${NC}"
  echo -e "  Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
  echo -e "  Tests Passed: ${GREEN}$TOTAL_PASSED${NC}"
  echo -e "  Tests Failed: ${RED}$TOTAL_FAILED${NC}"

  if [[ $TOTAL_TESTS -gt 0 ]]; then
    local success_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    echo -e "  Success Rate: ${CYAN}${success_rate}%${NC}"
  fi

  if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 ALL TEST SUITES PASSED! 🎉${NC}"
    echo -e "${GREEN}ServerSentry v2 is ready for production!${NC}"
  else
    echo -e "\n${RED}❌ Failed Test Suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
      echo -e "  ${RED}• $suite${NC}"
    done
    echo -e "\n${YELLOW}⚠️  Please fix the failing tests before deployment.${NC}"
  fi
}

# Function to check prerequisites
check_prerequisites() {
  echo -e "${BLUE}Checking prerequisites...${NC}"

  local missing_deps=()

  # Check for required commands
  for cmd in bash jq bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing required dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
      echo -e "  ${RED}• $dep${NC}"
    done
    echo -e "${YELLOW}Please install missing dependencies and try again.${NC}"
    return 1
  fi

  echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
  return 0
}

# Function to setup test environment
setup_test_environment() {
  echo -e "${BLUE}Setting up test environment...${NC}"

  # Ensure log directory exists
  mkdir -p "$BASE_DIR/logs"

  # Clean up any previous test artifacts
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true
  rm -f "$BASE_DIR/logs/test_"* 2>/dev/null || true

  # Set test environment variables
  export SERVERSENTRY_TEST_MODE=1
  export BASE_DIR="$BASE_DIR"

  echo -e "${GREEN}✅ Test environment ready${NC}"
}

# Function to cleanup test environment
cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up test environment...${NC}"

  # Remove test artifacts
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true
  rm -f "$BASE_DIR/logs/test_"* 2>/dev/null || true

  # Unset test environment variables
  unset SERVERSENTRY_TEST_MODE

  echo -e "${GREEN}✅ Test environment cleaned${NC}"
}

# Main execution
main() {
  echo -e "${PURPLE}ServerSentry v2 - Comprehensive Test Suite${NC}"
  echo -e "${PURPLE}===========================================${NC}"

  # Check prerequisites
  if ! check_prerequisites; then
    exit 1
  fi

  # Setup test environment
  setup_test_environment

  local start_time=$(date +%s)

  # Run unit tests
  echo -e "\n${CYAN}🧪 RUNNING UNIT TESTS${NC}"
  run_test_suite "Security Tests" "$SCRIPT_DIR/unit/security_test.sh" "Security Unit Test"
  run_test_suite "Utils Tests" "$SCRIPT_DIR/unit/utils_test.sh" "Utilities Unit Test"
  run_test_suite "Composite Tests" "$SCRIPT_DIR/unit/composite_test.sh" "Composite System Unit Test"
  run_test_suite "Logging Tests" "$SCRIPT_DIR/unit/logging_test.sh" "Logging System Unit Test"

  # Run integration tests
  echo -e "\n${CYAN}🔗 RUNNING INTEGRATION TESTS${NC}"
  run_test_suite "Basic Integration" "$SCRIPT_DIR/integration/basic_test.sh" "Basic Integration Test"
  run_test_suite "Security Integration" "$SCRIPT_DIR/integration/security_integration_test.sh" "Security Integration Test"

  # Calculate total execution time
  local end_time=$(date +%s)
  local total_duration=$((end_time - start_time))

  # Cleanup test environment
  cleanup_test_environment

  # Print final summary
  print_summary

  echo -e "\n${BLUE}Total execution time: ${total_duration}s${NC}"

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
  echo -e "\n${CYAN}🧪 RUNNING UNIT TESTS${NC}"
  run_test_suite "Security Tests" "$SCRIPT_DIR/unit/security_test.sh" "Security Unit Test"
  run_test_suite "Utils Tests" "$SCRIPT_DIR/unit/utils_test.sh" "Utilities Unit Test"
  run_test_suite "Composite Tests" "$SCRIPT_DIR/unit/composite_test.sh" "Composite System Unit Test"
  run_test_suite "Logging Tests" "$SCRIPT_DIR/unit/logging_test.sh" "Logging System Unit Test"
  cleanup_test_environment
  print_summary
  ;;
--integration)
  check_prerequisites && setup_test_environment
  echo -e "\n${CYAN}🔗 RUNNING INTEGRATION TESTS${NC}"
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
