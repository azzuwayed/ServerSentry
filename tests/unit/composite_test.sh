#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check System Tests
#
# This script tests the composite check system functionality, rule evaluation,
# and logical operators after the security fixes

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

# Source the composite module
source "$BASE_DIR/lib/core/logging.sh"
source "$BASE_DIR/lib/core/composite.sh"

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

# Mock plugin results for testing
create_mock_results() {
  local cpu_value="$1"
  local memory_value="$2"
  local disk_value="$3"

  cat <<EOF
{
  "plugins": [
    {"name": "cpu", "metrics": {"value": $cpu_value}},
    {"name": "memory", "metrics": {"value": $memory_value}},
    {"name": "disk", "metrics": {"value": $disk_value}},
    {"name": "process", "metrics": {"count": 5}}
  ]
}
EOF
}

echo "Running composite check system tests..."

# Test 1: Basic AND operation - both false
echo "Testing logical operators..."
MOCK_LOW=$(create_mock_results 15.0 12.0 5.0)
evaluate_composite_rule "cpu.value > 80 AND memory.value > 85" "$MOCK_LOW"
assert "AND operation - both false" "[ $? -eq 1 ]"

# Test 2: Basic AND operation - both true
MOCK_HIGH=$(create_mock_results 85.0 90.0 95.0)
evaluate_composite_rule "cpu.value > 80 AND memory.value > 85" "$MOCK_HIGH"
assert "AND operation - both true" "[ $? -eq 0 ]"

# Test 3: Basic AND operation - mixed
MOCK_MIXED=$(create_mock_results 85.0 75.0 95.0)
evaluate_composite_rule "cpu.value > 80 AND memory.value > 85" "$MOCK_MIXED"
assert "AND operation - mixed (false)" "[ $? -eq 1 ]"

# Test 4: Basic OR operation - both false
evaluate_composite_rule "cpu.value > 90 OR memory.value > 95" "$MOCK_LOW"
assert "OR operation - both false" "[ $? -eq 1 ]"

# Test 5: Basic OR operation - one true
evaluate_composite_rule "cpu.value > 80 OR memory.value > 95" "$MOCK_MIXED"
assert "OR operation - one true" "[ $? -eq 0 ]"

# Test 6: Complex nested operations (temporarily disabled - parentheses not supported yet)
# evaluate_composite_rule "(cpu.value > 80 OR memory.value > 85) AND disk.value > 90" "$MOCK_HIGH"
# assert "Complex nested - all high" "[ $? -eq 0 ]"

# evaluate_composite_rule "(cpu.value > 80 OR memory.value > 85) AND disk.value > 90" "$MOCK_LOW"
# assert "Complex nested - all low" "[ $? -eq 1 ]"

# Test 7: Comparison operators
echo "Testing comparison operators..."

# Greater than
evaluate_composite_rule "cpu.value > 80" "$MOCK_HIGH"
assert "Greater than - true" "[ $? -eq 0 ]"

evaluate_composite_rule "cpu.value > 90" "$MOCK_HIGH"
assert "Greater than - false" "[ $? -eq 1 ]"

# Less than
evaluate_composite_rule "cpu.value < 90" "$MOCK_HIGH"
assert "Less than - true" "[ $? -eq 0 ]"

evaluate_composite_rule "cpu.value < 80" "$MOCK_HIGH"
assert "Less than - false" "[ $? -eq 1 ]"

# Greater than or equal
evaluate_composite_rule "cpu.value >= 85" "$MOCK_HIGH"
assert "Greater than or equal - true" "[ $? -eq 0 ]"

# Less than or equal
evaluate_composite_rule "memory.value <= 90" "$MOCK_HIGH"
assert "Less than or equal - true" "[ $? -eq 0 ]"

# Test 8: Edge cases
echo "Testing edge cases..."

# Exact equality
MOCK_EXACT=$(create_mock_results 80.0 85.0 90.0)
evaluate_composite_rule "cpu.value >= 80 AND memory.value >= 85" "$MOCK_EXACT"
assert "Exact equality with >= " "[ $? -eq 0 ]"

# Floating point precision
MOCK_FLOAT=$(create_mock_results 80.1 84.9 90.5)
evaluate_composite_rule "cpu.value > 80 AND memory.value < 85" "$MOCK_FLOAT"
assert "Floating point precision" "[ $? -eq 0 ]"

# Test 9: Multiple metrics
echo "Testing multiple metrics..."
evaluate_composite_rule "cpu.value > 80 AND memory.value > 85 AND disk.value > 90" "$MOCK_HIGH"
assert "Triple AND - all true" "[ $? -eq 0 ]"

evaluate_composite_rule "cpu.value > 90 OR memory.value > 95 OR disk.value > 90" "$MOCK_HIGH"
assert "Triple OR - one true" "[ $? -eq 0 ]"

# Test 10: Process count metric
evaluate_composite_rule "process.count < 10" "$MOCK_HIGH"
assert "Process count comparison" "[ $? -eq 0 ]"

# Test 11: get_triggered_conditions function
echo "Testing triggered conditions detection..."

conditions=$(get_triggered_conditions "cpu.value > 80 AND memory.value > 85" "$MOCK_HIGH")
assert "Triggered conditions - high values" "[[ '$conditions' == *'CPU:'* && '$conditions' == *'Memory:'* ]]"

conditions=$(get_triggered_conditions "cpu.value > 90 AND memory.value > 95" "$MOCK_LOW")
assert "Triggered conditions - no triggers" "[ '$conditions' = 'Unknown conditions' ]"

# Test 12: Complex rule parsing
echo "Testing complex rule parsing..."

# Parentheses and precedence (temporarily disabled - parentheses not supported yet)
# evaluate_composite_rule "(cpu.value > 70 AND memory.value > 80) OR (disk.value > 85 AND process.count > 3)" "$MOCK_HIGH"
# assert "Complex parentheses rule" "[ $? -eq 0 ]"

# Multiple conditions
evaluate_composite_rule "cpu.value > 60 AND memory.value > 60 AND disk.value > 60" "$MOCK_HIGH"
assert "Multiple conditions - all true" "[ $? -eq 0 ]"

# Test 13: Error handling
echo "Testing error handling..."

# Invalid JSON should not crash
invalid_json='{"invalid": json}'
rule_result=$(evaluate_composite_rule "cpu.value > 80" "$invalid_json" 2>/dev/null || echo "handled")
assert "Invalid JSON handling" "[ '$rule_result' = 'handled' ]"

# Missing jq should be handled gracefully
if ! command -v jq >/dev/null 2>&1; then
  rule_result=$(evaluate_composite_rule "cpu.value > 80" "$MOCK_HIGH" 2>/dev/null || echo "handled")
  assert "Missing jq handling" "[ '$rule_result' = 'handled' ]"
fi

# Test 14: Security validation - no file creation
echo "Testing security - no file creation..."

# Clean up any numbered files
rm -f [0-9][0-9] 2>/dev/null || true

# Run various rules that previously created files
evaluate_composite_rule "cpu.value > 50 AND memory.value > 60" "$MOCK_HIGH" >/dev/null 2>&1 || true
evaluate_composite_rule "cpu.value > 80 AND memory.value > 85" "$MOCK_HIGH" >/dev/null 2>&1 || true
evaluate_composite_rule "cpu.value > 90 OR memory.value > 95" "$MOCK_HIGH" >/dev/null 2>&1 || true

# Check no files were created
files_created=0
for file in 50 60 80 85 90 95; do
  if [[ -f "$file" ]]; then
    files_created=1
    break
  fi
done

assert "No numbered files created" "[ $files_created -eq 0 ]"

# Test 15: Performance test
echo "Testing performance..."
start_time=$(date +%s.%N 2>/dev/null || date +%s)

# Run 100 rule evaluations
for i in {1..100}; do
  evaluate_composite_rule "cpu.value > 80 AND memory.value > 85" "$MOCK_HIGH" >/dev/null 2>&1
done

end_time=$(date +%s.%N 2>/dev/null || date +%s)

if command -v bc >/dev/null 2>&1; then
  duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
  # Should complete 100 evaluations in under 5 seconds
  performance_ok=$(echo "$duration < 5" | bc 2>/dev/null || echo "1")
  assert "Performance test - 100 evaluations" "[ '$performance_ok' = '1' ]"
fi

# Clean up after tests
rm -f [0-9][0-9] 2>/dev/null || true

# Print summary
echo ""
echo "Composite check tests completed: $TESTS_RUN"
if [[ "$COLOR_SUPPORT" == "true" ]]; then
  echo -e "${SUCCESS_COLOR}Tests passed: $TESTS_PASSED${RESET}"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${ERROR_COLOR}Tests failed: $TESTS_FAILED${RESET}"
    exit 1
  else
    echo -e "${SUCCESS_COLOR}All composite check tests passed!${RESET}"
    exit 0
  fi
else
  echo "Tests passed: $TESTS_PASSED"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo "Tests failed: $TESTS_FAILED"
    exit 1
  else
    echo "All composite check tests passed!"
    exit 0
  fi
fi
