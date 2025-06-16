#!/usr/bin/env bash
#
# ServerSentry v2 - Test Framework (Legacy Compatibility)
#
# This file provides backward compatibility for existing tests
# All functionality has been moved to the unified test framework

# Prevent multiple sourcing
if [[ "${TEST_FRAMEWORK_LOADED:-}" == "true" ]]; then
  return 0
fi
TEST_FRAMEWORK_LOADED=true
export TEST_FRAMEWORK_LOADED

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
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# Load unified test framework
if [[ -f "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh"
else
  echo "❌ ERROR: Unified test framework not found" >&2
  exit 1
fi

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi

# =============================================================================
# LEGACY COMPATIBILITY FUNCTIONS
# =============================================================================

# Global test counters for backward compatibility
GLOBAL_TESTS_RUN=0
GLOBAL_TESTS_PASSED=0
GLOBAL_TESTS_FAILED=0

# Legacy color definitions (delegated to unified framework)
if [[ "${COLOR_SUPPORT:-}" == "true" ]]; then
  # Colors are already defined by unified frameworks
  SUCCESS_COLOR="$GREEN"
  ERROR_COLOR="$RED"
  WARNING_COLOR="$YELLOW"
  INFO_COLOR="$BLUE"
  HEADER_COLOR="$PURPLE"
fi

# Legacy utility functions (provide fallbacks if not available)
if ! declare -f util_command_exists >/dev/null 2>&1; then
  util_command_exists() {
    command -v "$1" >/dev/null 2>&1
  }
fi

if ! declare -f get_timestamp >/dev/null 2>&1; then
  get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
  }
fi

if ! declare -f format_bytes >/dev/null 2>&1; then
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
fi

if ! declare -f compat_get_os >/dev/null 2>&1; then
  compat_get_os() {
    case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*) echo "linux" ;;
    CYGWIN* | MINGW* | MSYS*) echo "windows" ;;
    *) echo "unknown" ;;
    esac
  }
fi

# Legacy test suite functions
print_test_suite_header() {
  local suite_name="$1"
  echo ""
  print_separator
  print_header "TEST SUITE: $suite_name"
  print_separator
}

print_test_suite_summary() {
  local suite_name="$1"
  local tests_run="$2"
  local tests_passed="$3"
  local tests_failed="$4"

  echo ""
  print_separator
  print_header "SUMMARY: $suite_name"

  echo "Tests completed: $tests_run"
  echo "Tests passed: $tests_passed"
  echo "Tests failed: $tests_failed"

  # Update global counters
  GLOBAL_TESTS_RUN=$((GLOBAL_TESTS_RUN + tests_run))
  GLOBAL_TESTS_PASSED=$((GLOBAL_TESTS_PASSED + tests_passed))
  GLOBAL_TESTS_FAILED=$((GLOBAL_TESTS_FAILED + tests_failed))

  if [[ $tests_failed -eq 0 ]]; then
    print_success "All tests passed!"
  else
    print_error "$tests_failed test(s) failed"
  fi
  print_separator
}

# Legacy assertion functions (delegate to unified framework)
# Note: Most assertion functions are already provided by the unified framework
# We only need to provide any that have different signatures

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
  local message="${3:-String found when it should not be}"

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

# Legacy mock utilities
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

create_advanced_mock() {
  local function_name="$1"
  local mock_script="$2"

  eval "$function_name() { $mock_script; }"
}

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

# Legacy JSON utilities
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

# Legacy run_test function for backward compatibility
run_test() {
  local test_name="$1"
  local test_function="$2"

  echo "Running test: $test_name"

  if "$test_function"; then
    test_pass "$test_name"
    return 0
  else
    test_fail "$test_name"
    return 1
  fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export legacy functions for backward compatibility
export -f print_test_suite_header print_test_suite_summary
export -f assert_contains assert_not_contains assert_true assert_false
export -f assert_directory_exists assert_command_exists assert_exit_code
export -f assert_numeric_equals assert_numeric_greater assert_numeric_less
export -f create_mock_function create_mock_file remove_mock_file create_advanced_mock cleanup_mocks
export -f assert_json_valid assert_json_contains run_test
export -f util_command_exists get_timestamp format_bytes compat_get_os

# Export global variables
export GLOBAL_TESTS_RUN GLOBAL_TESTS_PASSED GLOBAL_TESTS_FAILED
export TEST_FRAMEWORK_LOADED

echo "✅ Legacy test framework loaded (delegating to unified framework)"
