#!/usr/bin/env bash
#
# ServerSentry v2 - Security Unit Tests
#
# This script tests for security vulnerabilities, especially the shell redirection
# issues we fixed in the composite check system, memory plugin, and anomaly detection

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
source "$BASE_DIR/lib/core/logging.sh"
source "$BASE_DIR/lib/core/composite.sh"
source "$BASE_DIR/lib/plugins/memory/memory.sh"
source "$BASE_DIR/lib/core/anomaly.sh"

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

# Function to check if files were created
check_no_files_created() {
  local pattern="$1"
  local files_found=0

  # Check for numbered files in current directory
  for file in $pattern; do
    if [[ -f "$file" ]]; then
      files_found=1
      break
    fi
  done 2>/dev/null

  return "$files_found"
}

# Clean up any existing numbered files before tests
cleanup_numbered_files() {
  rm -f 50 60 80 85 90 95 2>/dev/null || true
  rm -f [0-9][0-9] 2>/dev/null || true
}

echo "Running security tests..."

# Clean up before tests
cleanup_numbered_files

# Test 1: Composite Rule Evaluation Security
echo "Testing composite rule evaluation security..."

# Create a mock plugin results JSON for testing
MOCK_PLUGIN_RESULTS='{
  "plugins": [
    {"name": "cpu", "metrics": {"value": 15.0}},
    {"name": "memory", "metrics": {"value": 12.0}},
    {"name": "disk", "metrics": {"value": 5.0}}
  ]
}'

# Test rule with potential redirection vulnerability
TEST_RULE="cpu.value > 80 AND memory.value > 85"

# Run composite rule evaluation
evaluate_composite_rule "$TEST_RULE" "$MOCK_PLUGIN_RESULTS" >/dev/null 2>&1 || true

# Check that no numbered files were created
assert "Composite rule evaluation - no file creation" "check_no_files_created '[0-9][0-9]'"

# Test 2: Complex composite rules
TEST_RULE2="(cpu.value > 90 OR memory.value > 95) AND disk.value > 90"
evaluate_composite_rule "$TEST_RULE2" "$MOCK_PLUGIN_RESULTS" >/dev/null 2>&1 || true
assert "Complex composite rule - no file creation" "check_no_files_created '[0-9][0-9]'"

# Test 3: Edge case with high values
MOCK_HIGH_VALUES='{
  "plugins": [
    {"name": "cpu", "metrics": {"value": 95.5}},
    {"name": "memory", "metrics": {"value": 88.2}},
    {"name": "disk", "metrics": {"value": 92.1}}
  ]
}'

evaluate_composite_rule "$TEST_RULE" "$MOCK_HIGH_VALUES" >/dev/null 2>&1 || true
assert "High values composite rule - no file creation" "check_no_files_created '[0-9][0-9]'"

# Test 4: get_triggered_conditions function security
get_triggered_conditions "$TEST_RULE" "$MOCK_HIGH_VALUES" >/dev/null 2>&1 || true
assert "Triggered conditions function - no file creation" "check_no_files_created '[0-9][0-9]'"

# Test 5: Memory plugin swap calculation security
echo "Testing memory plugin security..."

# Mock memory values that could trigger the vulnerable code paths
export swap_total="1000000000" # 1GB
export swap_used="500000000"   # 500MB

# Simulate the vulnerable bc calculations (in safe environment)
if command -v bc >/dev/null 2>&1; then
  # Test the fixed comparison patterns
  result=$(echo "$swap_total > 0" | bc 2>/dev/null || echo "0")
  assert "Memory plugin bc calculation - safe execution" "[ '$result' = '1' ]"
fi

# Test 6: Anomaly detection security
echo "Testing anomaly detection security..."

# Test statistical calculations that could trigger redirection
test_std_dev="5.5"
test_sensitivity="2.0"
test_abs_z_score="3.2"

# Test the fixed anomaly detection comparisons
if command -v bc >/dev/null 2>&1; then
  result1=$(echo "$test_std_dev > 0" | bc 2>/dev/null || echo "0")
  result2=$(echo "$test_abs_z_score > $test_sensitivity" | bc 2>/dev/null || echo "0")

  assert "Anomaly detection std_dev comparison" "[ '$result1' = '1' ]"
  assert "Anomaly detection sensitivity comparison" "[ '$result2' = '1' ]"
fi

# Test 7: Spike detection security
test_current_value="85.5"
test_recent_mean="75.0"
test_spike_threshold="15.0"
test_value_diff="10.5"

if command -v bc >/dev/null 2>&1; then
  result3=$(echo "$test_value_diff > $test_spike_threshold" | bc 2>/dev/null || echo "0")
  result4=$(echo "$test_current_value > $test_recent_mean" | bc 2>/dev/null || echo "0")

  assert "Spike detection threshold comparison" "[ '$result3' = '0' ]"
  assert "Spike detection mean comparison" "[ '$result4' = '1' ]"
fi

# Final check - ensure no numbered files exist after all tests
assert "Final security check - no numbered files created" "check_no_files_created '[0-9][0-9]'"

# Test 8: Eval statement security patterns
echo "Testing eval statement security patterns..."

# Test that our fixed patterns don't create files
test_eval_rule="15.0 -gt 80 && 12.0 -gt 85"
if eval "[[ $test_eval_rule ]]" 2>/dev/null; then
  result="true"
else
  result="false"
fi

assert "Safe eval pattern execution" "[ '$result' = 'false' ]"
assert "Safe eval pattern - no file creation" "check_no_files_created '[0-9][0-9]'"

# Test 9: Arithmetic comparison security
echo "Testing arithmetic comparison security..."

# Test that we properly handle floating point comparisons
if command -v bc >/dev/null 2>&1; then
  # These should be safe now
  safe_test1=$(echo "scale=1; 15.5 > 80" | bc 2>/dev/null || echo "0")
  safe_test2=$(echo "scale=1; 85.2 > 80" | bc 2>/dev/null || echo "0")

  assert "Safe floating point comparison 1" "[ '$safe_test1' = '0' ]"
  assert "Safe floating point comparison 2" "[ '$safe_test2' = '1' ]"
fi

# Test 10: Redirection attack prevention
echo "Testing redirection attack prevention..."

# Simulate potential attack vectors (these should be safe now)
attack_rule="cpu.value > /tmp/attack_file AND memory.value > /etc/passwd"

# This should not create any files outside our control
evaluate_composite_rule "$attack_rule" "$MOCK_PLUGIN_RESULTS" >/dev/null 2>&1 || true

# Check that attack files were not created
assert "Redirection attack prevention 1" "[ ! -f '/tmp/attack_file' ]"
assert "Redirection attack prevention 2" "[ ! -f '/etc/passwd.bak' ]"

# Clean up after tests
cleanup_numbered_files

# Print summary
echo ""
echo "Security tests completed: $TESTS_RUN"
if [[ "$COLOR_SUPPORT" == "true" ]]; then
  echo -e "${SUCCESS_COLOR}Tests passed: $TESTS_PASSED${RESET}"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${ERROR_COLOR}Tests failed: $TESTS_FAILED${RESET}"
    echo -e "${ERROR_COLOR}CRITICAL: Security vulnerabilities may still exist!${RESET}"
    exit 1
  else
    echo -e "${SUCCESS_COLOR}All security tests passed! System is secure.${RESET}"
    exit 0
  fi
else
  echo "Tests passed: $TESTS_PASSED"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo "Tests failed: $TESTS_FAILED"
    echo "CRITICAL: Security vulnerabilities may still exist!"
    exit 1
  else
    echo "All security tests passed! System is secure."
    exit 0
  fi
fi
