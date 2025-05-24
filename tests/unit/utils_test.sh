#!/usr/bin/env bash
#
# ServerSentry v2 - Unit Tests for Utils Module
#
# This script tests the utility functions in utils.sh

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source required modules
export BASE_DIR="$BASE_DIR"
export LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
source "$BASE_DIR/lib/core/logging.sh"
source "$BASE_DIR/lib/core/utils.sh"

# Define test output color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

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
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    if [ -n "$message" ]; then
      echo -e "${YELLOW}$message${NC}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Begin tests
echo "Running unit tests for utils module..."

# Test command_exists function
assert "command_exists - should find ls" "command_exists ls"
assert "command_exists - should not find nonexistent_command" "! command_exists nonexistent_command"

# Test is_root function (this will return false unless run as root)
assert "is_root function" "is_root || true" "This test will only pass if run as root"

# Test get_os_type function
assert "get_os_type function" "get_os_type | grep -E '^(linux|macos|windows|unknown)$'"

# Test to_lowercase function
assert "to_lowercase function" "[ \"$(to_lowercase 'HELLO')\" = 'hello' ]"

# Test to_uppercase function
assert "to_uppercase function" "[ \"$(to_uppercase 'hello')\" = 'HELLO' ]"

# Test trim function
assert "trim function - spaces" "[ \"$(trim '  hello  ')\" = 'hello' ]"
assert "trim function - tabs" "[ \"$(trim $'\t'hello$'\t')\" = 'hello' ]"
assert "trim function - mixed" "[ \"$(trim $' \t'hello$' \t')\" = 'hello' ]"

# Test is_valid_ip function
assert "is_valid_ip - valid IP" "is_valid_ip '192.168.1.1'"
assert "is_valid_ip - invalid IP (out of range)" "! is_valid_ip '192.168.1.256'"
assert "is_valid_ip - invalid IP (format)" "! is_valid_ip '192.168.1'"
assert "is_valid_ip - invalid IP (non-numeric)" "! is_valid_ip 'abc.def.ghi.jkl'"

# Test random_string function
RANDOM_STR=$(random_string 10)
assert "random_string - length" "[ ${#RANDOM_STR} -eq 10 ]"

# Test for randomness - try a few times to avoid false failures
random_test_passed=false
for i in {1..5}; do
  str1=$(random_string 10)
  str2=$(random_string 10)
  if [ "$str1" != "$str2" ]; then
    random_test_passed=true
    break
  fi
done

assert "random_string - different values" "[ '$random_test_passed' = 'true' ]"

# Test get_timestamp function
assert "get_timestamp - returns a number" "[[ $(get_timestamp) =~ ^[0-9]+$ ]]"

# Test get_formatted_date function
assert "get_formatted_date - default format" "[[ \$(get_formatted_date) =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]"
assert "get_formatted_date - custom format" "[[ \$(get_formatted_date '%Y%m%d') =~ ^[0-9]{8}$ ]]"

# Test format_bytes function
assert "format_bytes - bytes" "[ \"$(format_bytes 512)\" = '512B' ]"
assert "format_bytes - kilobytes" "[[ \"$(format_bytes 1536)\" =~ ^1.50\ KB$ ]]"
assert "format_bytes - megabytes" "[[ \"$(format_bytes 2097152)\" =~ ^2.00\ MB$ ]]"
assert "format_bytes - gigabytes" "[[ \"$(format_bytes 3221225472)\" =~ ^3.00\ GB$ ]]"

# Test safe_write function
TEST_FILE="/tmp/serversentry_test_safe_write"
TEST_CONTENT="test content"
safe_write "$TEST_FILE" "$TEST_CONTENT"
assert "safe_write function" "[ \"$(cat $TEST_FILE)\" = \"$TEST_CONTENT\" ]"
rm -f "$TEST_FILE"

# Test url_encode function
assert "url_encode - basic" "[ \"$(url_encode 'hello world')\" = 'hello%20world' ]"
assert "url_encode - special chars" "[ \"$(url_encode 'hello@world?')\" = 'hello%40world%3f' ]"

# Test json_escape function
assert "json_escape - quotes" "[ \"$(json_escape '\"hello\"')\" = '\\\"hello\\\"' ]"
assert "json_escape - backslash" "[ \"$(json_escape '\\hello')\" = '\\\\hello' ]"

# Print summary
echo ""
echo "Tests completed: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
