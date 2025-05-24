#!/usr/bin/env bash
#
# ServerSentry v2 - Enhanced Test Framework
#
# Provides comprehensive testing utilities and functions for all test suites
# Refactored for better reliability, edge case coverage, and dependency management

# Prevent multiple sourcing
if [[ "${TEST_FRAMEWORK_LOADED:-}" == "true" ]]; then
  return 0
fi
TEST_FRAMEWORK_LOADED=true
export TEST_FRAMEWORK_LOADED

# Color definitions for test output with fallback support
# shellcheck disable=SC2034
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && command -v tput >/dev/null 2>&1; then
  COLOR_SUPPORT="true"
  RESET='\033[0m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
  BOLD='\033[1m'

  SUCCESS_COLOR="$GREEN"
  ERROR_COLOR="$RED"
  WARNING_COLOR="$YELLOW"
  INFO_COLOR="$CYAN"
  HEADER_COLOR="$PURPLE"
else
  COLOR_SUPPORT="false"
  RESET=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  PURPLE=""
  CYAN=""
  WHITE=""
  BOLD=""

  SUCCESS_COLOR=""
  ERROR_COLOR=""
  WARNING_COLOR=""
  INFO_COLOR=""
  HEADER_COLOR=""
fi

# Test result counters (global)
GLOBAL_TESTS_RUN=0
GLOBAL_TESTS_PASSED=0
GLOBAL_TESTS_FAILED=0

# Test environment variables
TEST_TEMP_DIR=""
TEST_LOG_FILE=""
TEST_START_TIME=""
TEST_DURATION=""
CAPTURED_LOG_FILE=""

# === ENHANCED UTILITY FUNCTIONS FOR TESTING ===

# Provide missing utility functions that tests depend on
util_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Basic logging functions for tests
log_debug() { echo "[DEBUG] $*" >&2; }
log_info() { echo "[INFO] $*" >&2; }
log_warning() { echo "[WARNING] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# Get timestamp function
get_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Format bytes function for tests
format_bytes() {
  local bytes="$1"
  local precision="${2:-2}"

  if [[ "$bytes" -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ "$bytes" -lt 1048576 ]]; then
    awk "BEGIN { printf \"%.${precision}f KB\", $bytes/1024 }"
  elif [[ "$bytes" -lt 1073741824 ]]; then
    awk "BEGIN { printf \"%.${precision}f MB\", $bytes/1048576 }"
  else
    awk "BEGIN { printf \"%.${precision}f GB\", $bytes/1073741824 }"
  fi
}

# Compatibility functions for OS detection
compat_get_os() {
  case "$(uname -s)" in
  Darwin*) echo "macos" ;;
  Linux*) echo "linux" ;;
  CYGWIN* | MINGW* | MSYS*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

# === TEST OUTPUT FUNCTIONS ===

print_success() {
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${SUCCESS_COLOR}✅ $*${RESET}"
  else
    echo "✅ $*"
  fi
}

print_error() {
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${ERROR_COLOR}❌ $*${RESET}"
  else
    echo "❌ $*"
  fi
}

print_warning() {
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${WARNING_COLOR}⚠️  $*${RESET}"
  else
    echo "⚠️ $*"
  fi
}

print_info() {
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}ℹ️  $*${RESET}"
  else
    echo "ℹ️ $*"
  fi
}

print_header() {
  local text="$1"
  local width="${2:-60}"

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${HEADER_COLOR}${BOLD}$text${RESET}"
  else
    echo "$text"
  fi
}

print_separator() {
  local width="${1:-60}"
  printf '%*s\n' "$width" '' | tr ' ' '='
}

print_test_header() {
  local test_name="$1"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "${INFO_COLOR}🔍 $test_name${RESET}"
  else
    echo "🔍 $test_name"
  fi
}

print_test_suite_header() {
  local suite_name="$1"
  echo ""
  print_separator 70
  print_header "TEST SUITE: $suite_name" 70
  print_separator 70
}

print_test_suite_summary() {
  local suite_name="$1"
  local tests_run="$2"
  local tests_passed="$3"
  local tests_failed="$4"

  echo ""
  print_separator 50
  print_header "SUMMARY: $suite_name" 50

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "Tests completed: ${INFO_COLOR}$tests_run${RESET}"
    echo -e "Tests passed: ${SUCCESS_COLOR}$tests_passed${RESET}"
    echo -e "Tests failed: ${ERROR_COLOR}$tests_failed${RESET}"
  else
    echo "Tests completed: $tests_run"
    echo "Tests passed: $tests_passed"
    echo "Tests failed: $tests_failed"
  fi

  # Update global counters
  GLOBAL_TESTS_RUN=$((GLOBAL_TESTS_RUN + tests_run))
  GLOBAL_TESTS_PASSED=$((GLOBAL_TESTS_PASSED + tests_passed))
  GLOBAL_TESTS_FAILED=$((GLOBAL_TESTS_FAILED + tests_failed))

  if [[ $tests_failed -eq 0 ]]; then
    print_success "All tests passed!"
  else
    print_error "$tests_failed test(s) failed"
  fi
  print_separator 50
}

# === ENHANCED ASSERTION FUNCTIONS ===

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$not_expected" != "$actual" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Not expected: '$not_expected'"
    echo "  Actual:       '$actual'"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String not found}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Haystack: '$haystack'"
    echo "  Needle:   '$needle'"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String found when it shouldn\'t be}"

  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Haystack: '$haystack'"
    echo "  Needle:   '$needle'"
    return 1
  fi
}

assert_true() {
  local condition="$1"
  local message="${2:-Condition is false}"

  if [[ "$condition" == "true" ]] || [[ "$condition" == "1" ]] || [[ "$condition" -eq 1 ]] 2>/dev/null; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Condition: '$condition'"
    return 1
  fi
}

assert_false() {
  local condition="$1"
  local message="${2:-Condition is true}"

  if [[ "$condition" == "false" ]] || [[ "$condition" == "0" ]] || [[ "$condition" == "" ]] || [[ "$condition" -eq 0 ]] 2>/dev/null; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Condition: '$condition'"
    return 1
  fi
}

assert_file_exists() {
  local filepath="$1"
  local message="${2:-File does not exist}"

  if [[ -f "$filepath" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File: '$filepath'"
    return 1
  fi
}

assert_file_not_exists() {
  local filepath="$1"
  local message="${2:-File exists when it shouldn\'t}"

  if [[ ! -f "$filepath" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  File: '$filepath'"
    return 1
  fi
}

assert_directory_exists() {
  local dirpath="$1"
  local message="${2:-Directory does not exist}"

  if [[ -d "$dirpath" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Directory: '$dirpath'"
    return 1
  fi
}

assert_command_exists() {
  local command="$1"
  local message="${2:-Command does not exist}"

  if util_command_exists "$command"; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Command: '$command'"
    return 1
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local message="${3:-Exit code mismatch}"

  if [[ "$expected_code" -eq "$actual_code" ]]; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Expected exit code: $expected_code"
    echo "  Actual exit code:   $actual_code"
    return 1
  fi
}

assert_numeric_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Numeric values not equal}"

  if util_command_exists bc; then
    if [[ $(echo "$expected == $actual" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
      return 0
    fi
  else
    # Fallback for systems without bc
    if [[ "${expected%.*}" -eq "${actual%.*}" ]] 2>/dev/null; then
      return 0
    fi
  fi

  echo "ASSERTION FAILED: $message"
  echo "  Expected: $expected"
  echo "  Actual:   $actual"
  return 1
}

assert_numeric_greater() {
  local actual="$1"
  local threshold="$2"
  local message="${3:-Value not greater than threshold}"

  if util_command_exists bc; then
    if [[ $(echo "$actual > $threshold" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
      return 0
    fi
  else
    # Fallback for systems without bc
    if [[ "${actual%.*}" -gt "${threshold%.*}" ]] 2>/dev/null; then
      return 0
    fi
  fi

  echo "ASSERTION FAILED: $message"
  echo "  Value:     $actual"
  echo "  Threshold: $threshold"
  return 1
}

assert_numeric_less() {
  local actual="$1"
  local threshold="$2"
  local message="${3:-Value not less than threshold}"

  if util_command_exists bc; then
    if [[ $(echo "$actual < $threshold" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
      return 0
    fi
  else
    # Fallback for systems without bc
    if [[ "${actual%.*}" -lt "${threshold%.*}" ]] 2>/dev/null; then
      return 0
    fi
  fi

  echo "ASSERTION FAILED: $message"
  echo "  Value:     $actual"
  echo "  Threshold: $threshold"
  return 1
}

# === ENHANCED MOCK UTILITIES ===

create_mock_function() {
  local function_name="$1"
  local return_value="$2"
  local return_code="${3:-0}"

  eval "$function_name() { echo '$return_value'; return $return_code; }"
}

create_mock_file() {
  local filepath="$1"
  local content="$2"

  mkdir -p "$(dirname "$filepath")"
  echo "$content" >"$filepath"
}

remove_mock_file() {
  local filepath="$1"
  rm -f "$filepath"
}

# Enhanced mock for system commands with argument parsing
create_advanced_mock() {
  local function_name="$1"
  local mock_script="$2"

  eval "$function_name() { $mock_script; }"
}

# === TEST ENVIRONMENT UTILITIES ===

setup_test_environment() {
  local test_name="$1"

  # Create temporary directory for test
  TEST_TEMP_DIR=$(mktemp -d -t "${test_name}_XXXXXX")
  export TEST_TEMP_DIR

  # Set up test logging
  TEST_LOG_FILE="$TEST_TEMP_DIR/test.log"
  export TEST_LOG_FILE

  print_info "Test environment setup: $TEST_TEMP_DIR"
}

cleanup_test_environment() {
  if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
    print_info "Test environment cleaned up"
  fi

  # Clean up any mock functions
  cleanup_mocks
}

# Clean up mock functions
cleanup_mocks() {
  # List of common mock functions to clean up
  local mock_functions=(
    "iostat" "top" "uptime" "free" "vm_stat" "sysctl" "df" "du" "ps" "pgrep"
    "curl" "wget" "uname" "compat_get_memory_info" "compat_get_load_average"
  )

  for func in "${mock_functions[@]}"; do
    if declare -f "$func" >/dev/null 2>&1; then
      unset -f "$func"
    fi
  done
}

# === TIMER UTILITIES FOR PERFORMANCE TESTING ===

start_timer() {
  if util_command_exists date; then
    TEST_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
  else
    TEST_START_TIME=$(date +%s)
  fi
  export TEST_START_TIME
}

end_timer() {
  local end_time
  if util_command_exists date; then
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
  else
    end_time=$(date +%s)
  fi

  if util_command_exists bc; then
    TEST_DURATION=$(echo "$end_time - $TEST_START_TIME" | bc -l)
  else
    TEST_DURATION=$((end_time - ${TEST_START_TIME%.*}))
  fi
  export TEST_DURATION
}

assert_performance() {
  local max_duration="$1"
  local message="${2:-Performance test failed}"

  if [[ -z "${TEST_DURATION:-}" ]]; then
    echo "ASSERTION FAILED: $message - No duration recorded"
    return 1
  fi

  local comparison_result
  if util_command_exists bc; then
    comparison_result=$(echo "$TEST_DURATION <= $max_duration" | bc -l 2>/dev/null || echo "0")
  else
    # Fallback comparison
    if [[ "${TEST_DURATION%.*}" -le "${max_duration%.*}" ]]; then
      comparison_result=1
    else
      comparison_result=0
    fi
  fi

  if [[ "$comparison_result" -eq 1 ]]; then
    print_info "Performance: ${TEST_DURATION}s (under ${max_duration}s threshold)"
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Duration: ${TEST_DURATION}s"
    echo "  Max allowed: ${max_duration}s"
    return 1
  fi
}

# === JSON TESTING UTILITIES ===

assert_json_valid() {
  local json_string="$1"
  local message="${2:-Invalid JSON}"

  if util_command_exists jq; then
    if echo "$json_string" | jq . >/dev/null 2>&1; then
      return 0
    else
      echo "ASSERTION FAILED: $message"
      echo "  JSON: '$json_string'"
      return 1
    fi
  else
    # Basic JSON validation without jq
    if [[ "$json_string" == "{"*"}" ]] || [[ "$json_string" == "["*"]" ]]; then
      return 0
    else
      print_warning "jq not available, using basic JSON validation"
      echo "ASSERTION FAILED: $message"
      echo "  JSON: '$json_string'"
      return 1
    fi
  fi
}

assert_json_contains() {
  local json_string="$1"
  local key="$2"
  local expected_value="$3"
  local message="${4:-JSON key/value mismatch}"

  if util_command_exists jq; then
    local actual_value
    actual_value=$(echo "$json_string" | jq -r ".$key" 2>/dev/null)

    if [[ "$actual_value" == "$expected_value" ]]; then
      return 0
    else
      echo "ASSERTION FAILED: $message"
      echo "  Key: '$key'"
      echo "  Expected: '$expected_value'"
      echo "  Actual: '$actual_value'"
      return 1
    fi
  else
    # Basic key checking without jq
    if [[ "$json_string" == *"\"$key\""* ]]; then
      print_warning "jq not available, basic key presence check only"
      return 0
    else
      echo "ASSERTION FAILED: $message"
      echo "  Key: '$key' not found in JSON"
      return 1
    fi
  fi
}

# === CONFIGURATION TESTING UTILITIES ===

create_test_config() {
  local config_file="$1"
  shift
  local config_lines=("$@")

  mkdir -p "$(dirname "$config_file")"
  printf '%s\n' "${config_lines[@]}" >"$config_file"
}

# === ENHANCED NETWORK TESTING UTILITIES ===

# shellcheck disable=SC2317,SC2034
mock_curl() {
  local expected_url="$1"
  local response_code="${2:-200}"
  local response_body="${3:-OK}"

  curl() {
    local url=""
    local data=""
    local headers=()
    local method="GET"
    local write_out=""

    # Parse curl arguments
    while [[ $# -gt 0 ]]; do
      case $1 in
      -X | --request)
        method="$2"
        shift 2
        ;;
      -d | --data)
        data="$2"
        shift 2
        ;;
      -H | --header)
        headers+=("$2")
        shift 2
        ;;
      -s | --silent)
        shift
        ;;
      -o | --output)
        shift 2
        ;;
      -w | --write-out)
        write_out="$2"
        shift 2
        ;;
      *)
        url="$1"
        shift
        ;;
      esac
    done

    # Handle write-out format
    if [[ "$write_out" == "%{http_code}" ]]; then
      echo "$response_code"
      return 0
    fi

    # Simulate response
    if [[ "$url" == "$expected_url" ]] || [[ -z "$expected_url" ]]; then
      echo "$response_body"
      return 0
    else
      echo "Mock curl: unexpected URL '$url', expected '$expected_url'" >&2
      return 1
    fi
  }
}

# === ENHANCED SYSTEM MOCK UTILITIES ===

mock_ps() {
  local process_list="$1"
  ps() { echo "$process_list"; }
}

mock_pgrep() {
  local pgrep_output="$1"
  pgrep() { echo "$pgrep_output"; }
}

mock_top() {
  local top_output="$1"
  top() { echo "$top_output"; }
}

mock_uname() {
  local os_type="$1"
  uname() {
    if [[ "$1" == "-s" ]]; then
      echo "$os_type"
    else
      echo "Mock uname output"
    fi
  }
}

mock_df() {
  local df_output="$1"
  df() { echo "$df_output"; }
}

mock_du() {
  local du_output="$1"
  du() { echo "$du_output"; }
}

mock_free() {
  local free_output="$1"
  free() { echo "$free_output"; }
}

mock_vm_stat() {
  local vm_stat_output="$1"
  vm_stat() { echo "$vm_stat_output"; }
}

mock_sysctl() {
  local sysctl_output="$1"
  sysctl() { echo "$sysctl_output"; }
}

mock_iostat() {
  local iostat_output="$1"
  iostat() { echo "$iostat_output"; }
}

mock_uptime() {
  local uptime_output="$1"
  uptime() { echo "$uptime_output"; }
}

# === LOGGING TESTING UTILITIES ===

capture_logs() {
  local log_file="${1:-$TEST_TEMP_DIR/captured.log}"

  # Redirect stdout and stderr to log file
  exec 3>&1 4>&2
  exec 1>"$log_file" 2>&1

  export CAPTURED_LOG_FILE="$log_file"
}

stop_log_capture() {
  # Restore stdout and stderr
  exec 1>&3 2>&4
  exec 3>&- 4>&-
}

assert_log_contains() {
  local expected_text="$1"
  local log_file="${2:-$CAPTURED_LOG_FILE}"
  local message="${3:-Log does not contain expected text}"

  if [[ -f "$log_file" ]] && grep -q "$expected_text" "$log_file"; then
    return 0
  else
    echo "ASSERTION FAILED: $message"
    echo "  Expected text: '$expected_text'"
    if [[ -f "$log_file" ]]; then
      echo "  Log contents:"
      sed 's/^/    /' "$log_file"
    else
      echo "  Log file not found: '$log_file'"
    fi
    return 1
  fi
}

# === TEST EXECUTION HELPERS ===

run_test() {
  local test_function="$1"
  local test_name="${2:-$test_function}"

  print_test_header "$test_name"

  if "$test_function"; then
    print_success "PASSED: $test_name"
    return 0
  else
    print_error "FAILED: $test_name"
    return 1
  fi
}

# === GLOBAL TEST REPORTING ===

print_global_summary() {
  echo ""
  print_separator 70
  print_header "GLOBAL TEST SUMMARY" 70
  print_separator 70

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "Total tests run: ${INFO_COLOR}$GLOBAL_TESTS_RUN${RESET}"
    echo -e "Total tests passed: ${SUCCESS_COLOR}$GLOBAL_TESTS_PASSED${RESET}"
    echo -e "Total tests failed: ${ERROR_COLOR}$GLOBAL_TESTS_FAILED${RESET}"
  else
    echo "Total tests run: $GLOBAL_TESTS_RUN"
    echo "Total tests passed: $GLOBAL_TESTS_PASSED"
    echo "Total tests failed: $GLOBAL_TESTS_FAILED"
  fi

  if [[ $GLOBAL_TESTS_RUN -gt 0 ]]; then
    local success_rate=$((GLOBAL_TESTS_PASSED * 100 / GLOBAL_TESTS_RUN))
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "Success rate: ${CYAN}${success_rate}%${RESET}"
    else
      echo "Success rate: ${success_rate}%"
    fi
  fi

  if [[ $GLOBAL_TESTS_FAILED -eq 0 ]]; then
    print_success "🎉 ALL TESTS PASSED! 🎉"
  else
    print_error "❌ $GLOBAL_TESTS_FAILED test(s) failed"
  fi

  print_separator 70
}

# Export all functions for use in test scripts
export -f print_success print_error print_warning print_info print_header
export -f print_separator print_test_header print_test_suite_header print_test_suite_summary
export -f assert_equals assert_not_equals assert_contains assert_not_contains
export -f assert_true assert_false assert_file_exists assert_file_not_exists
export -f assert_directory_exists assert_command_exists assert_exit_code
export -f assert_numeric_equals assert_numeric_greater assert_numeric_less
export -f create_mock_function create_mock_file remove_mock_file create_advanced_mock
export -f setup_test_environment cleanup_test_environment cleanup_mocks
export -f start_timer end_timer assert_performance
export -f assert_json_valid assert_json_contains create_test_config
export -f mock_curl mock_ps mock_pgrep mock_top mock_uname mock_df mock_du mock_free mock_vm_stat
export -f mock_sysctl mock_iostat mock_uptime
export -f capture_logs stop_log_capture assert_log_contains print_global_summary
export -f run_test util_command_exists log_debug log_info log_warning log_error
export -f get_timestamp format_bytes compat_get_os
