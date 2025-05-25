#!/usr/bin/env bash
#
# ServerSentry v2 - JSON Utilities Comprehensive Unit Tests
#
# Tests all JSON utility functions with extensive edge case coverage

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source test framework first
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "$BASE_DIR/lib/core/logging.sh"

# Source the module under test
source "$BASE_DIR/lib/core/utils/json_utils.sh"

# Test configuration
TEST_SUITE_NAME="JSON Utilities Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===

test_pass() {
  local message="$1"
  print_success "$message"
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
}

test_fail() {
  local message="$1"
  print_error "$message"
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
}

# === MOCK DATA GENERATORS ===

generate_simple_json() {
  echo '{"name": "test", "value": 42, "enabled": true}'
}

generate_complex_json() {
  cat <<'EOF'
{
  "system": {
    "hostname": "server-01",
    "os": "linux",
    "uptime": 86400
  },
  "metrics": [
    {"name": "cpu", "value": 85.5, "unit": "%"},
    {"name": "memory", "value": 70.2, "unit": "%"},
    {"name": "disk", "value": 45.8, "unit": "%"}
  ],
  "alerts": {
    "critical": 2,
    "warning": 5,
    "info": 10
  },
  "metadata": {
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "2.0.0"
  }
}
EOF
}

generate_nested_array_json() {
  cat <<'EOF'
{
  "data": [
    {
      "id": 1,
      "items": [
        {"type": "cpu", "value": 85},
        {"type": "memory", "value": 70}
      ]
    },
    {
      "id": 2,
      "items": [
        {"type": "disk", "value": 45},
        {"type": "network", "value": 30}
      ]
    }
  ]
}
EOF
}

generate_invalid_json() {
  echo '{"invalid": "json", "missing": quote}'
}

generate_empty_json() {
  echo '{}'
}

generate_array_json() {
  echo '["item1", "item2", "item3", {"nested": "object"}]'
}

# === SETUP AND TEARDOWN ===

setup_json_test() {
  setup_test_environment "json_utils_test"
  cleanup_mocks
}

teardown_json_test() {
  cleanup_test_environment
}

# === JSON VALIDATION TESTS ===

# Test 1: Valid JSON validation
test_util_json_validate_valid() {
  setup_json_test

  local json_data
  json_data="$(generate_simple_json)"

  if util_json_validate "$json_data"; then
    test_pass "util_json_validate correctly validates simple JSON"
  else
    test_fail "util_json_validate should validate simple JSON"
  fi

  teardown_json_test
}

# Test 2: Complex JSON validation
test_util_json_validate_complex() {
  setup_json_test

  local json_data
  json_data="$(generate_complex_json)"

  if util_json_validate "$json_data"; then
    test_pass "util_json_validate correctly validates complex JSON"
  else
    test_fail "util_json_validate should validate complex JSON"
  fi

  teardown_json_test
}

# Test 3: Invalid JSON validation
test_util_json_validate_invalid() {
  setup_json_test

  local json_data
  json_data="$(generate_invalid_json)"

  if ! util_json_validate "$json_data"; then
    test_pass "util_json_validate correctly rejects invalid JSON"
  else
    test_fail "util_json_validate should reject invalid JSON"
  fi

  teardown_json_test
}

# Test 4: Empty JSON validation
test_util_json_validate_empty() {
  setup_json_test

  local json_data
  json_data="$(generate_empty_json)"

  if util_json_validate "$json_data"; then
    test_pass "util_json_validate correctly validates empty JSON object"
  else
    test_fail "util_json_validate should validate empty JSON object"
  fi

  teardown_json_test
}

# Test 5: Array JSON validation
test_util_json_validate_array() {
  setup_json_test

  local json_data
  json_data="$(generate_array_json)"

  if util_json_validate "$json_data"; then
    test_pass "util_json_validate correctly validates JSON array"
  else
    test_fail "util_json_validate should validate JSON array"
  fi

  teardown_json_test
}

# Test 6: Empty string validation
test_util_json_validate_empty_string() {
  setup_json_test

  if ! util_json_validate ""; then
    test_pass "util_json_validate correctly rejects empty string"
  else
    test_fail "util_json_validate should reject empty string"
  fi

  teardown_json_test
}

# === JSON ESCAPING TESTS ===

# Test 7: Basic string escaping
test_util_json_escape_basic() {
  setup_json_test

  local input='Hello "World"'
  local expected='Hello \"World\"'
  local result

  result=$(util_json_escape "$input")

  if assert_equals "$expected" "$result" "Basic escaping should work"; then
    test_pass "util_json_escape handles basic quotes correctly"
  else
    test_fail "util_json_escape failed: expected '$expected', got '$result'"
  fi

  teardown_json_test
}

# Test 8: Backslash escaping
test_util_json_escape_backslash() {
  setup_json_test

  local input='Path\to\file'
  local expected='Path\\to\\file'
  local result

  result=$(util_json_escape "$input")

  if assert_equals "$expected" "$result" "Backslash escaping should work"; then
    test_pass "util_json_escape handles backslashes correctly"
  else
    test_fail "util_json_escape failed: expected '$expected', got '$result'"
  fi

  teardown_json_test
}

# Test 9: Newline and tab escaping
test_util_json_escape_special_chars() {
  setup_json_test

  local input=$'Line 1\nLine 2\tTabbed'
  local expected='Line 1\\nLine 2\\tTabbed'
  local result

  result=$(util_json_escape "$input")

  if assert_equals "$expected" "$result" "Special character escaping should work"; then
    test_pass "util_json_escape handles newlines and tabs correctly"
  else
    test_fail "util_json_escape failed: expected '$expected', got '$result'"
  fi

  teardown_json_test
}

# Test 10: Unicode character escaping
test_util_json_escape_unicode() {
  setup_json_test

  local input='Unicode: 🚨 警告 Тревога'
  local result

  result=$(util_json_escape "$input")

  # Unicode characters should be preserved (not escaped)
  if assert_contains "$result" "🚨" "Unicode should be preserved"; then
    test_pass "util_json_escape preserves Unicode characters"
  else
    test_fail "util_json_escape failed to preserve Unicode: got '$result'"
  fi

  teardown_json_test
}

# Test 11: Empty string escaping
test_util_json_escape_empty() {
  setup_json_test

  local result
  result=$(util_json_escape "")

  if assert_equals "" "$result" "Empty string should remain empty"; then
    test_pass "util_json_escape handles empty string correctly"
  else
    test_fail "util_json_escape failed with empty string: got '$result'"
  fi

  teardown_json_test
}

# === JSON VALUE EXTRACTION TESTS ===

# Test 12: Extract simple string value
test_util_json_get_value_string() {
  setup_json_test

  local json_data
  json_data="$(generate_simple_json)"
  local result

  result=$(util_json_get_value "$json_data" "name")

  if assert_equals "test" "$result" "Should extract string value"; then
    test_pass "util_json_get_value extracts string values correctly"
  else
    test_fail "util_json_get_value failed: expected 'test', got '$result'"
  fi

  teardown_json_test
}

# Test 13: Extract numeric value
test_util_json_get_value_number() {
  setup_json_test

  local json_data
  json_data="$(generate_simple_json)"
  local result

  result=$(util_json_get_value "$json_data" "value")

  if assert_equals "42" "$result" "Should extract numeric value"; then
    test_pass "util_json_get_value extracts numeric values correctly"
  else
    test_fail "util_json_get_value failed: expected '42', got '$result'"
  fi

  teardown_json_test
}

# Test 14: Extract boolean value
test_util_json_get_value_boolean() {
  setup_json_test

  local json_data
  json_data="$(generate_simple_json)"
  local result

  result=$(util_json_get_value "$json_data" "enabled")

  if assert_equals "true" "$result" "Should extract boolean value"; then
    test_pass "util_json_get_value extracts boolean values correctly"
  else
    test_fail "util_json_get_value failed: expected 'true', got '$result'"
  fi

  teardown_json_test
}

# Test 15: Extract nested value
test_util_json_get_value_nested() {
  setup_json_test

  local json_data
  json_data="$(generate_complex_json)"
  local result

  result=$(util_json_get_value "$json_data" "system.hostname")

  if assert_equals "server-01" "$result" "Should extract nested value"; then
    test_pass "util_json_get_value extracts nested values correctly"
  else
    test_fail "util_json_get_value failed: expected 'server-01', got '$result'"
  fi

  teardown_json_test
}

# Test 16: Extract array element
test_util_json_get_value_array_element() {
  setup_json_test

  local json_data
  json_data="$(generate_complex_json)"
  local result

  result=$(util_json_get_value "$json_data" "metrics[0].name")

  if assert_equals "cpu" "$result" "Should extract array element"; then
    test_pass "util_json_get_value extracts array elements correctly"
  else
    test_fail "util_json_get_value failed: expected 'cpu', got '$result'"
  fi

  teardown_json_test
}

# Test 17: Extract non-existent key
test_util_json_get_value_nonexistent() {
  setup_json_test

  local json_data
  json_data="$(generate_simple_json)"
  local result

  result=$(util_json_get_value "$json_data" "nonexistent")

  if assert_equals "" "$result" "Should return empty for non-existent key"; then
    test_pass "util_json_get_value handles non-existent keys correctly"
  else
    test_fail "util_json_get_value failed: expected empty, got '$result'"
  fi

  teardown_json_test
}

# Test 18: Extract from invalid JSON
test_util_json_get_value_invalid_json() {
  setup_json_test

  local json_data
  json_data="$(generate_invalid_json)"
  local result

  result=$(util_json_get_value "$json_data" "name")

  if assert_equals "" "$result" "Should return empty for invalid JSON"; then
    test_pass "util_json_get_value handles invalid JSON gracefully"
  else
    test_fail "util_json_get_value should return empty for invalid JSON, got '$result'"
  fi

  teardown_json_test
}

# === JSON CREATION TESTS ===

# Test 19: Create simple JSON object
test_util_json_create_object_simple() {
  setup_json_test

  local result
  result=$(util_json_create_object "name" "test" "value" "42" "enabled" "true")

  if assert_json_valid "$result" "Should create valid JSON" &&
    assert_json_contains_key "$result" "name" "Should contain name key" &&
    assert_json_value_equals "$result" "name" "test" "Should have correct name value"; then
    test_pass "util_json_create_object creates simple objects correctly"
  else
    test_fail "util_json_create_object failed: $result"
  fi

  teardown_json_test
}

# Test 20: Create JSON object with special characters
test_util_json_create_object_special_chars() {
  setup_json_test

  local result
  result=$(util_json_create_object "message" 'Alert: CPU > 85% on "server-01"!' "status" "critical")

  if assert_json_valid "$result" "Should create valid JSON with special characters"; then
    test_pass "util_json_create_object handles special characters correctly"
  else
    test_fail "util_json_create_object failed with special characters: $result"
  fi

  teardown_json_test
}

# Test 21: Create empty JSON object
test_util_json_create_object_empty() {
  setup_json_test

  local result
  result=$(util_json_create_object)

  if assert_json_valid "$result" "Should create valid empty JSON" &&
    assert_equals "{}" "$result" "Should be empty object"; then
    test_pass "util_json_create_object creates empty objects correctly"
  else
    test_fail "util_json_create_object failed with empty args: $result"
  fi

  teardown_json_test
}

# Test 22: Create JSON object with odd number of arguments
test_util_json_create_object_odd_args() {
  setup_json_test

  local result
  result=$(util_json_create_object "key1" "value1" "key2")

  # Should handle gracefully, possibly ignoring the last unpaired key
  if assert_json_valid "$result" "Should handle odd arguments gracefully"; then
    test_pass "util_json_create_object handles odd number of arguments"
  else
    test_fail "util_json_create_object failed with odd arguments: $result"
  fi

  teardown_json_test
}

# === JSON STATUS OBJECT TESTS ===

# Test 23: Create status object with all fields
test_util_json_create_status_object_complete() {
  setup_json_test

  local metrics='{"cpu": 85.5, "memory": 70.2}'
  local result

  result=$(util_json_create_status_object "2" "High CPU usage" "cpu" "$metrics")

  if assert_json_valid "$result" "Should create valid status JSON" &&
    assert_json_contains_key "$result" "status_code" "Should contain status_code" &&
    assert_json_contains_key "$result" "status_message" "Should contain status_message" &&
    assert_json_contains_key "$result" "plugin" "Should contain plugin" &&
    assert_json_contains_key "$result" "timestamp" "Should contain timestamp" &&
    assert_json_contains_key "$result" "metrics" "Should contain metrics"; then
    test_pass "util_json_create_status_object creates complete status objects"
  else
    test_fail "util_json_create_status_object failed: $result"
  fi

  teardown_json_test
}

# Test 24: Create status object without metrics
test_util_json_create_status_object_no_metrics() {
  setup_json_test

  local result
  result=$(util_json_create_status_object "0" "System OK" "system")

  if assert_json_valid "$result" "Should create valid status JSON without metrics" &&
    assert_json_value_equals "$result" "status_code" "0" "Should have correct status code" &&
    assert_json_value_equals "$result" "status_message" "System OK" "Should have correct message"; then
    test_pass "util_json_create_status_object creates objects without metrics"
  else
    test_fail "util_json_create_status_object failed without metrics: $result"
  fi

  teardown_json_test
}

# Test 25: Create status object with invalid metrics JSON
test_util_json_create_status_object_invalid_metrics() {
  setup_json_test

  local invalid_metrics='{"invalid": json}'
  local result

  result=$(util_json_create_status_object "1" "Warning" "test" "$invalid_metrics")

  if assert_json_valid "$result" "Should create valid status JSON even with invalid metrics"; then
    test_pass "util_json_create_status_object handles invalid metrics gracefully"
  else
    test_fail "util_json_create_status_object failed with invalid metrics: $result"
  fi

  teardown_json_test
}

# === JSON ARRAY OPERATIONS TESTS ===

# Test 26: Create JSON array
test_util_json_create_array() {
  setup_json_test

  local result
  result=$(util_json_create_array "item1" "item2" "item3")

  if assert_json_valid "$result" "Should create valid JSON array" &&
    assert_contains "$result" "item1" "Should contain first item" &&
    assert_contains "$result" "item2" "Should contain second item" &&
    assert_contains "$result" "item3" "Should contain third item"; then
    test_pass "util_json_create_array creates arrays correctly"
  else
    test_fail "util_json_create_array failed: $result"
  fi

  teardown_json_test
}

# Test 27: Create empty JSON array
test_util_json_create_array_empty() {
  setup_json_test

  local result
  result=$(util_json_create_array)

  if assert_json_valid "$result" "Should create valid empty array" &&
    assert_equals "[]" "$result" "Should be empty array"; then
    test_pass "util_json_create_array creates empty arrays correctly"
  else
    test_fail "util_json_create_array failed with no args: $result"
  fi

  teardown_json_test
}

# Test 28: Add to JSON array
test_util_json_array_add() {
  setup_json_test

  local array='["item1", "item2"]'
  local result

  result=$(util_json_array_add "$array" "item3")

  if assert_json_valid "$result" "Should create valid array after addition" &&
    assert_contains "$result" "item3" "Should contain new item"; then
    test_pass "util_json_array_add adds items correctly"
  else
    test_fail "util_json_array_add failed: $result"
  fi

  teardown_json_test
}

# === PERFORMANCE TESTS ===

# Test 29: Performance with large JSON
test_util_json_performance_large() {
  setup_json_test

  # Create large JSON object
  local large_json='{'
  for i in {1..1000}; do
    large_json+='"key'$i'":"value'$i'"'
    if [[ $i -lt 1000 ]]; then
      large_json+=','
    fi
  done
  large_json+='}'

  measure_execution_time util_json_validate "$large_json"

  if assert_execution_time_under "1" "Large JSON validation should complete within 1 second"; then
    test_pass "util_json_validate performs well with large JSON"
  else
    test_fail "util_json_validate performance issue with large JSON: ${MEASURED_TIME}s"
  fi

  teardown_json_test
}

# Test 30: Performance with multiple operations
test_util_json_performance_multiple() {
  setup_json_test

  local json_data
  json_data="$(generate_complex_json)"

  measure_execution_time json_multiple_operations "$json_data"

  if assert_execution_time_under "1" "Multiple operations should complete within 1 second"; then
    test_pass "JSON utilities perform well with multiple operations"
  else
    test_fail "JSON utilities performance issue: ${MEASURED_TIME}s"
  fi

  teardown_json_test
}

# Helper function for performance test
json_multiple_operations() {
  local json_data="$1"

  for i in {1..100}; do
    util_json_validate "$json_data" || return 1
    util_json_get_value "$json_data" "system.hostname" || return 1
    util_json_escape "test string $i" || return 1
  done
  return 0
}

# === EDGE CASE TESTS ===

# Test 31: Very deep nesting
test_util_json_deep_nesting() {
  setup_json_test

  local deep_json='{"a":{"b":{"c":{"d":{"e":{"f":"deep_value"}}}}}}'

  if util_json_validate "$deep_json"; then
    local result
    result=$(util_json_get_value "$deep_json" "a.b.c.d.e.f")

    if assert_equals "deep_value" "$result" "Should extract deeply nested value"; then
      test_pass "JSON utilities handle deep nesting correctly"
    else
      test_fail "Failed to extract deeply nested value: got '$result'"
    fi
  else
    test_fail "Deep nesting JSON validation failed"
  fi

  teardown_json_test
}

# Test 32: JSON with null values
test_util_json_null_values() {
  setup_json_test

  local json_with_null='{"name": "test", "value": null, "enabled": true}'

  if util_json_validate "$json_with_null"; then
    local result
    result=$(util_json_get_value "$json_with_null" "value")

    if assert_equals "null" "$result" "Should handle null values"; then
      test_pass "JSON utilities handle null values correctly"
    else
      test_fail "Failed to handle null value: got '$result'"
    fi
  else
    test_fail "JSON with null values validation failed"
  fi

  teardown_json_test
}

# Test 33: JSON with numeric edge cases
test_util_json_numeric_edge_cases() {
  setup_json_test

  local json_with_numbers='{"zero": 0, "negative": -42, "float": 3.14159, "scientific": 1.23e-4}'

  if util_json_validate "$json_with_numbers"; then
    test_pass "JSON utilities handle numeric edge cases correctly"
  else
    test_fail "JSON with numeric edge cases validation failed"
  fi

  teardown_json_test
}

# === FALLBACK TESTS (WITHOUT JQ) ===

# Test 34: Validation without jq
test_util_json_validate_without_jq() {
  setup_json_test

  # Mock util_command_exists to return false for jq
  create_mock_function "util_command_exists" '[[ "$1" != "jq" ]]'

  local json_data
  json_data="$(generate_simple_json)"

  if util_json_validate "$json_data"; then
    test_pass "util_json_validate works without jq (fallback mode)"
  else
    test_fail "util_json_validate should work without jq"
  fi

  teardown_json_test
}

# Test 35: Value extraction without jq
test_util_json_get_value_without_jq() {
  setup_json_test

  # Mock util_command_exists to return false for jq
  create_mock_function "util_command_exists" '[[ "$1" != "jq" ]]'

  local json_data='{"name": "test", "value": 42}'
  local result

  result=$(util_json_get_value "$json_data" "name")

  if assert_equals "test" "$result" "Should extract value without jq"; then
    test_pass "util_json_get_value works without jq (fallback mode)"
  else
    test_fail "util_json_get_value fallback failed: expected 'test', got '$result'"
  fi

  teardown_json_test
}

# === MAIN TEST EXECUTION ===

run_json_utils_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  # JSON validation tests
  test_util_json_validate_valid
  test_util_json_validate_complex
  test_util_json_validate_invalid
  test_util_json_validate_empty
  test_util_json_validate_array
  test_util_json_validate_empty_string

  # JSON escaping tests
  test_util_json_escape_basic
  test_util_json_escape_backslash
  test_util_json_escape_special_chars
  test_util_json_escape_unicode
  test_util_json_escape_empty

  # JSON value extraction tests
  test_util_json_get_value_string
  test_util_json_get_value_number
  test_util_json_get_value_boolean
  test_util_json_get_value_nested
  test_util_json_get_value_array_element
  test_util_json_get_value_nonexistent
  test_util_json_get_value_invalid_json

  # JSON creation tests
  test_util_json_create_object_simple
  test_util_json_create_object_special_chars
  test_util_json_create_object_empty
  test_util_json_create_object_odd_args

  # JSON status object tests
  test_util_json_create_status_object_complete
  test_util_json_create_status_object_no_metrics
  test_util_json_create_status_object_invalid_metrics

  # JSON array operations tests
  test_util_json_create_array
  test_util_json_create_array_empty
  test_util_json_array_add

  # Performance tests
  test_util_json_performance_large
  test_util_json_performance_multiple

  # Edge case tests
  test_util_json_deep_nesting
  test_util_json_null_values
  test_util_json_numeric_edge_cases

  # Fallback tests
  test_util_json_validate_without_jq
  test_util_json_get_value_without_jq

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_json_utils_tests
  exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
