#!/usr/bin/env bash
#
# ServerSentry Test Framework Core
#
# Unified test framework that provides common testing utilities
# to eliminate duplication across test files.

# Prevent multiple sourcing
if [[ "${TEST_FRAMEWORK_CORE_LOADED:-}" == "true" ]]; then
  return 0
fi
TEST_FRAMEWORK_CORE_LOADED=true
export TEST_FRAMEWORK_CORE_LOADED

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

# =============================================================================
# TEST FRAMEWORK CONFIGURATION
# =============================================================================

# Test counters
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
TEST_TOTAL=0

# Test timing
TEST_START_TIME=""
TEST_END_TIME=""

# Test environment
TEST_TEMP_DIR=""
TEST_LOG_FILE=""
TEST_CONFIG_FILE=""

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# =============================================================================
# CORE TEST FUNCTIONS
# =============================================================================

# Function: test_pass
# Description: Mark a test as passed
# Parameters:
#   $1 (string): test name
#   $2 (string): optional message

# Function: test_fail
# Description: Mark a test as failed
# Parameters:
#   $1 (string): test name
#   $2 (string): optional error message

# Function: test_skip
# Description: Mark a test as skipped
# Parameters:
#   $1 (string): test name
#   $2 (string): reason for skipping
test_skip() {
  local test_name="$1"
  local reason="${2:-No reason provided}"

  ((TEST_SKIPPED++))
  ((TEST_TOTAL++))

  echo -e "${YELLOW}⏭️  SKIP${NC}: $test_name - $reason"
}

# Function: assert
# Description: Basic assertion function
# Parameters:
#   $1 (string): condition to test
#   $2 (string): test name
#   $3 (string): optional error message

# Function: assert_equals
# Description: Assert two values are equal
# Parameters:
#   $1 (string): expected value
#   $2 (string): actual value
#   $3 (string): test name
assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  if [[ "$expected" == "$actual" ]]; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "Expected '$expected', got '$actual'"
    return 1
  fi
}

# Function: assert_not_equals
# Description: Assert two values are not equal
# Parameters:
#   $1 (string): unexpected value
#   $2 (string): actual value
#   $3 (string): test name
assert_not_equals() {
  local unexpected="$1"
  local actual="$2"
  local test_name="$3"

  if [[ "$unexpected" != "$actual" ]]; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "Expected not '$unexpected', but got '$actual'"
    return 1
  fi
}

# Function: assert_file_exists
# Description: Assert a file exists
# Parameters:
#   $1 (string): file path
#   $2 (string): test name
assert_file_exists() {
  local file_path="$1"
  local test_name="$2"

  if [[ -f "$file_path" ]]; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "File does not exist: $file_path"
    return 1
  fi
}

# Function: assert_file_not_exists
# Description: Assert a file does not exist
# Parameters:
#   $1 (string): file path
#   $2 (string): test name
assert_file_not_exists() {
  local file_path="$1"
  local test_name="$2"

  if [[ ! -f "$file_path" ]]; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "File should not exist: $file_path"
    return 1
  fi
}

# Function: assert_command_success
# Description: Assert a command succeeds (exit code 0)
# Parameters:
#   $1 (string): command to run
#   $2 (string): test name
assert_command_success() {
  local command="$1"
  local test_name="$2"

  if eval "$command" >/dev/null 2>&1; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "Command failed: $command"
    return 1
  fi
}

# Function: assert_command_failure
# Description: Assert a command fails (non-zero exit code)
# Parameters:
#   $1 (string): command to run
#   $2 (string): test name
assert_command_failure() {
  local command="$1"
  local test_name="$2"

  if ! eval "$command" >/dev/null 2>&1; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name" "Command should have failed: $command"
    return 1
  fi
}

# =============================================================================
# TEST ENVIRONMENT MANAGEMENT
# =============================================================================

# Function: setup_test_environment
# Description: Set up test environment with temporary directories and files
# Parameters:
#   $1 (string): test suite name

# Function: cleanup_test_environment
# Description: Clean up test environment
# Parameters: None

# Function: create_test_config
# Description: Create a test configuration file
# Parameters:
#   $1 (string): config content (YAML)

# =============================================================================
# TEST REPORTING
# =============================================================================

# Function: print_test_header
# Description: Print a formatted test header
# Parameters:
#   $1 (string): test suite name

# Function: print_test_summary
# Description: Print test results summary
# Parameters: None
print_test_summary() {
  TEST_END_TIME=$(date +%s)
  local duration=$((TEST_END_TIME - TEST_START_TIME))

  echo ""
  echo -e "${WHITE}============================================================${NC}"
  echo -e "${WHITE}📊 TEST RESULTS SUMMARY${NC}"
  echo -e "${WHITE}============================================================${NC}"
  echo -e "${GREEN}✅ Passed: $TEST_PASSED${NC}"
  echo -e "${RED}❌ Failed: $TEST_FAILED${NC}"
  echo -e "${YELLOW}⏭️  Skipped: $TEST_SKIPPED${NC}"
  echo -e "${WHITE}📈 Total: $TEST_TOTAL${NC}"
  echo -e "${BLUE}⏱️  Duration: ${duration}s${NC}"
  echo ""

  if [[ $TEST_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    return 0
  else
    echo -e "${RED}💥 SOME TESTS FAILED!${NC}"
    return 1
  fi
}

# =============================================================================
# PERFORMANCE TESTING
# =============================================================================

# Function: start_timer
# Description: Start a performance timer
# Parameters:
#   $1 (string): timer name

# Function: end_timer
# Description: End a performance timer and return duration
# Parameters:
#   $1 (string): timer name
# Returns: Duration in milliseconds via stdout

# Function: assert_performance
# Description: Assert that an operation completes within a time limit
# Parameters:
#   $1 (string): command to run
#   $2 (numeric): max duration in milliseconds
#   $3 (string): test name

# =============================================================================
# MOCK AND STUB UTILITIES
# =============================================================================

# Function: mock_command
# Description: Create a mock command that returns specific output
# Parameters:
#   $1 (string): command name
#   $2 (string): mock output
#   $3 (numeric): mock exit code (default: 0)
mock_command() {
  local command_name="$1"
  local mock_output="$2"
  local mock_exit_code="${3:-0}"

  if [[ -z "$TEST_TEMP_DIR" ]]; then
    echo "❌ ERROR: Test environment not set up" >&2
    return 1
  fi

  local mock_script="${TEST_TEMP_DIR}/mock_${command_name}"

  cat >"$mock_script" <<EOF
#!/usr/bin/env bash
echo "$mock_output"
exit $mock_exit_code
EOF

  chmod +x "$mock_script"
  export PATH="${TEST_TEMP_DIR}:$PATH"

  echo -e "${BLUE}🎭 Created mock for command: $command_name${NC}"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export all test framework functions
export -f test_pass test_fail test_skip
export -f assert assert_equals assert_not_equals
export -f assert_file_exists assert_file_not_exists
export -f assert_command_success assert_command_failure
export -f setup_test_environment cleanup_test_environment create_test_config
export -f print_test_header print_test_summary
export -f start_timer end_timer assert_performance
export -f mock_command

# Export test variables
export TEST_PASSED TEST_FAILED TEST_SKIPPED TEST_TOTAL
export TEST_START_TIME TEST_END_TIME
export TEST_TEMP_DIR TEST_LOG_FILE TEST_CONFIG_FILE
