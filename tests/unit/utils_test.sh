#!/usr/bin/env bash
#
# ServerSentry v2 - Utilities Unit Tests
#
# This script tests the utility functions in lib/core/utils/

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

# Source the modules we're testing
source "$BASE_DIR/lib/core/utils.sh"
source "$BASE_DIR/lib/core/utils/command_utils.sh"
source "$BASE_DIR/lib/core/utils/array_utils.sh"
source "$BASE_DIR/lib/core/utils/validation_utils.sh"
source "$BASE_DIR/lib/core/utils/json_utils.sh"

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
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${SUCCESS_COLOR}PASS${RESET}"
    else
      echo "PASS"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "${ERROR_COLOR}FAIL${RESET}"
      if [ -n "$message" ]; then
        echo -e "${WARNING_COLOR}$message${RESET}"
      fi
    else
      echo "FAIL"
      if [ -n "$message" ]; then
        echo "$message"
      fi
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

echo "Running utility function tests..."

# Test 1: Command existence checking
assert "util_command_exists with existing command" "util_command_exists bash"
assert "util_command_exists with non-existing command" "! util_command_exists nonexistent_command_xyz123"

# Test 2: Array utility functions
test_array=("item1" "item2" "item3")
assert "array_contains with existing item" "array_contains 'item2' \"\${test_array[@]}\""
assert "array_contains with non-existing item" "! array_contains 'item4' \"\${test_array[@]}\""

# Test 3: Validation functions
assert "validate_number with valid number" "validate_number '42'"
assert "validate_number with invalid number" "! validate_number 'not_a_number'"
assert "validate_email with valid email" "validate_email 'test@example.com'"
assert "validate_email with invalid email" "! validate_email 'invalid_email'"

# Test 4: JSON utility functions
test_json='{"key": "value", "number": 42}'
if util_command_exists jq; then
  assert "json_get_value with valid key" "[ \"\$(json_get_value 'key' \"\$test_json\")\" = 'value' ]"
  assert "json_get_value with number key" "[ \"\$(json_get_value 'number' \"\$test_json\")\" = '42' ]"
else
  echo "Skipping JSON tests (jq not available)"
fi

# Test 5: Utility helper functions
assert "is_function with existing function" "is_function 'assert'"
assert "is_function with non-existing function" "! is_function 'nonexistent_function'"

# Test 6: String utilities
assert "trim_whitespace function" "[ \"\$(trim_whitespace '  test  ')\" = 'test' ]"

# Test 7: File utilities
temp_test_file="/tmp/serversentry_test_file_$$"
echo "test content" >"$temp_test_file"
assert "file_exists with existing file" "file_exists '$temp_test_file'"
rm -f "$temp_test_file"
assert "file_exists with non-existing file" "! file_exists '$temp_test_file'"

# Print summary
echo ""
echo "Utils tests completed: $TESTS_RUN"
if [[ "$COLOR_SUPPORT" == "true" ]]; then
  echo -e "${SUCCESS_COLOR}Tests passed: $TESTS_PASSED${RESET}"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${ERROR_COLOR}Tests failed: $TESTS_FAILED${RESET}"
    exit 1
  else
    echo -e "${SUCCESS_COLOR}All utility tests passed!${RESET}"
    exit 0
  fi
else
  echo "Tests passed: $TESTS_PASSED"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo "Tests failed: $TESTS_FAILED"
    exit 1
  else
    echo "All utility tests passed!"
    exit 0
  fi
fi
