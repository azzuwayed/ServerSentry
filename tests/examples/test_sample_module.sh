
# Load unified test framework
if [[ -f "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh"
fi

#!/usr/bin/env bash
#
# Test Script for Sample Module
#
# This script demonstrates comprehensive testing practices for ServerSentry modules
# including function testing, error path testing, and integration testing.

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration
TEST_PASSED=0
TEST_FAILED=0
TEST_TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test utility functions
test_start() {
  local test_name="$1"
  echo -e "${BLUE}Testing: $test_name${NC}"
  TEST_TOTAL=$((TEST_TOTAL + 1))
}



test_warning() {
  local message="$1"
  echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
}

# Source the sample module
if [[ -f "$TEST_DIR/sample_module.sh" ]]; then
  source "$TEST_DIR/sample_module.sh"
else
  echo -e "${RED}Error: Sample module not found at $TEST_DIR/sample_module.sh${NC}"
  exit 1
fi

# Test 1: Module Initialization
test_module_initialization() {
  test_start "Module Initialization"

  # Test successful initialization
  if sample_module_init; then
    test_pass "Module initialization succeeded"
  else
    test_fail "Module initialization failed"
    return 1
  fi

  # Verify directories were created
  local dirs=("$SAMPLE_CONFIG_DIR" "$SAMPLE_DATA_DIR" "$SAMPLE_CACHE_DIR")
  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      test_pass "Directory created: $dir"
    else
      test_fail "Directory not created: $dir"
    fi
  done

  # Test error case - invalid parameters
  if sample_module_init "invalid_param" 2>/dev/null; then
    test_fail "Module init should reject invalid parameters"
  else
    test_pass "Module init correctly rejects invalid parameters"
  fi

  return 0
}

# Test 2: Configuration Management
test_configuration_management() {
  test_start "Configuration Management"

  # Test default config creation
  if sample_create_default_config; then
    test_pass "Default configuration creation succeeded"
  else
    test_fail "Default configuration creation failed"
    return 1
  fi

  # Verify config file exists
  local config_file="$SAMPLE_CONFIG_DIR/sample.conf"
  if [[ -f "$config_file" ]]; then
    test_pass "Configuration file created: $config_file"
  else
    test_fail "Configuration file not created: $config_file"
    return 1
  fi

  # Test config value retrieval
  local timeout_value
  timeout_value=$(sample_get_config_value "timeout" "30")
  if [[ "$timeout_value" == "30" ]]; then
    test_pass "Configuration value retrieval works"
  else
    test_fail "Configuration value retrieval failed: expected 30, got $timeout_value"
  fi

  # Test default fallback
  local nonexistent_value
  nonexistent_value=$(sample_get_config_value "nonexistent_key" "default_value")
  if [[ "$nonexistent_value" == "default_value" ]]; then
    test_pass "Default value fallback works"
  else
    test_fail "Default value fallback failed: expected default_value, got $nonexistent_value"
  fi

  # Test invalid key validation
  if sample_get_config_value "invalid-key!" "default" 2>/dev/null; then
    test_fail "Should reject invalid configuration keys"
  else
    test_pass "Correctly rejects invalid configuration keys"
  fi

  return 0
}

# Test 3: Input Validation
test_input_validation() {
  test_start "Input Validation"

  # Test valid email
  if sample_validate_input_data "user@example.com" "email"; then
    test_pass "Valid email validation"
  else
    test_fail "Valid email validation failed"
  fi

  # Test invalid email
  if sample_validate_input_data "invalid-email" "email" 2>/dev/null; then
    test_fail "Should reject invalid email"
  else
    test_pass "Correctly rejects invalid email"
  fi

  # Test valid URL
  if sample_validate_input_data "https://example.com" "url"; then
    test_pass "Valid URL validation"
  else
    test_fail "Valid URL validation failed"
  fi

  # Test invalid URL
  if sample_validate_input_data "not-a-url" "url" 2>/dev/null; then
    test_fail "Should reject invalid URL"
  else
    test_pass "Correctly rejects invalid URL"
  fi

  # Test valid number
  if sample_validate_input_data "123.45" "number"; then
    test_pass "Valid number validation"
  else
    test_fail "Valid number validation failed"
  fi

  # Test invalid number
  if sample_validate_input_data "not-a-number" "number" 2>/dev/null; then
    test_fail "Should reject invalid number"
  else
    test_pass "Correctly rejects invalid number"
  fi

  # Test alphanumeric validation
  if sample_validate_input_data "test_data-123" "alphanumeric"; then
    test_pass "Valid alphanumeric validation"
  else
    test_fail "Valid alphanumeric validation failed"
  fi

  # Test file validation (create a test file)
  local test_file="/tmp/test_sample_file_$$"
  echo "test content" >"$test_file"

  if sample_validate_input_data "$test_file" "file"; then
    test_pass "Valid file validation"
  else
    test_fail "Valid file validation failed"
  fi

  # Clean up test file
  rm -f "$test_file"

  # Test nonexistent file
  if sample_validate_input_data "/nonexistent/file" "file" 2>/dev/null; then
    test_fail "Should reject nonexistent file"
  else
    test_pass "Correctly rejects nonexistent file"
  fi

  # Test empty input
  if sample_validate_input_data "" "email" 2>/dev/null; then
    test_fail "Should reject empty input"
  else
    test_pass "Correctly rejects empty input"
  fi

  # Test invalid validation type
  if sample_validate_input_data "test" "invalid_type" 2>/dev/null; then
    test_fail "Should reject invalid validation type"
  else
    test_pass "Correctly rejects invalid validation type"
  fi

  return 0
}

# Test 4: Data Processing
test_data_processing() {
  test_start "Data Processing"

  # Test standard processing
  local result
  result=$(sample_process_data_batch "test1,test2,test3" "standard" 2)
  if [[ -n "$result" ]]; then
    test_pass "Standard data processing succeeded"

    # Verify JSON output
    if echo "$result" | grep -q '"processed_data"'; then
      test_pass "JSON output format correct"
    else
      test_fail "JSON output format incorrect"
    fi
  else
    test_fail "Standard data processing failed"
  fi

  # Test advanced processing
  result=$(sample_process_data_batch "test1,test2" "advanced")
  if [[ -n "$result" ]]; then
    test_pass "Advanced data processing succeeded"
  else
    test_fail "Advanced data processing failed"
  fi

  # Test minimal processing
  result=$(sample_process_data_batch "test1,test2" "minimal")
  if [[ -n "$result" ]]; then
    test_pass "Minimal data processing succeeded"
  else
    test_fail "Minimal data processing failed"
  fi

  # Test file input (create test file)
  local test_data_file="/tmp/test_data_$$"
  echo "file1,file2,file3" >"$test_data_file"

  result=$(sample_process_data_batch "$test_data_file" "standard")
  if [[ -n "$result" ]]; then
    test_pass "File input processing succeeded"
  else
    test_fail "File input processing failed"
  fi

  # Clean up test file
  rm -f "$test_data_file"

  # Test invalid processing mode
  if sample_process_data_batch "test" "invalid_mode" 2>/dev/null; then
    test_fail "Should reject invalid processing mode"
  else
    test_pass "Correctly rejects invalid processing mode"
  fi

  # Test invalid batch size
  if sample_process_data_batch "test" "standard" "invalid_size" 2>/dev/null; then
    test_fail "Should reject invalid batch size"
  else
    test_pass "Correctly rejects invalid batch size"
  fi

  # Test empty data
  if sample_process_data_batch "" "standard" 2>/dev/null; then
    test_fail "Should reject empty data"
  else
    test_pass "Correctly rejects empty data"
  fi

  return 0
}

# Test 5: Cache Operations
test_cache_operations() {
  test_start "Cache Operations"

  # Test cache miss (first call)
  local cache_key="test_cache_$$"
  local result
  result=$(sample_cache_operation "$cache_key" "echo 'cached_result'" 300)

  if [[ "$result" == "cached_result" ]]; then
    test_pass "Cache miss operation succeeded"
  else
    test_fail "Cache miss operation failed: expected 'cached_result', got '$result'"
  fi

  # Test cache hit (second call)
  result=$(sample_cache_operation "$cache_key" "echo 'should_not_execute'" 300)

  if [[ "$result" == "cached_result" ]]; then
    test_pass "Cache hit operation succeeded"
  else
    test_fail "Cache hit operation failed: expected 'cached_result', got '$result'"
  fi

  # Test cache expiration (TTL = 1 second)
  local expire_key="expire_test_$$"
  result=$(sample_cache_operation "$expire_key" "echo 'first_result'" 1)
  sleep 2
  result=$(sample_cache_operation "$expire_key" "echo 'second_result'" 1)

  if [[ "$result" == "second_result" ]]; then
    test_pass "Cache expiration works correctly"
  else
    test_fail "Cache expiration failed: expected 'second_result', got '$result'"
  fi

  # Test invalid cache key
  if sample_cache_operation "invalid-key!" "echo test" 2>/dev/null; then
    test_fail "Should reject invalid cache key"
  else
    test_pass "Correctly rejects invalid cache key"
  fi

  # Test invalid TTL
  if sample_cache_operation "test" "echo test" "invalid_ttl" 2>/dev/null; then
    test_fail "Should reject invalid TTL"
  else
    test_pass "Correctly rejects invalid TTL"
  fi

  return 0
}

# Test 6: Cache Cleanup
test_cache_cleanup() {
  test_start "Cache Cleanup"

  # Create some test cache files
  local test_cache_dir="$SAMPLE_CACHE_DIR"
  local old_cache="$test_cache_dir/old_cache.cache"
  local old_time="$test_cache_dir/old_cache.time"
  local new_cache="$test_cache_dir/new_cache.cache"
  local new_time="$test_cache_dir/new_cache.time"

  # Create old cache (2 hours ago)
  echo "old_data" >"$old_cache"
  echo "$(($(date +%s) - 7200))" >"$old_time"

  # Create new cache (now)
  echo "new_data" >"$new_cache"
  echo "$(date +%s)" >"$new_time"

  # Run cleanup with 1 hour max age
  if sample_cleanup_cache 3600 100; then
    test_pass "Cache cleanup succeeded"

    # Verify old cache was removed
    if [[ ! -f "$old_cache" ]]; then
      test_pass "Old cache file removed"
    else
      test_fail "Old cache file not removed"
    fi

    # Verify new cache was kept
    if [[ -f "$new_cache" ]]; then
      test_pass "New cache file preserved"
    else
      test_fail "New cache file incorrectly removed"
    fi
  else
    test_fail "Cache cleanup failed"
  fi

  # Clean up test files
  rm -f "$new_cache" "$new_time"

  # Test invalid parameters
  if sample_cleanup_cache "invalid_age" 2>/dev/null; then
    test_fail "Should reject invalid max age"
  else
    test_pass "Correctly rejects invalid max age"
  fi

  if sample_cleanup_cache 3600 "invalid_size" 2>/dev/null; then
    test_fail "Should reject invalid max size"
  else
    test_pass "Correctly rejects invalid max size"
  fi

  return 0
}

# Test 7: Module Status
test_module_status() {
  test_start "Module Status"

  # Test status retrieval
  local status
  status=$(sample_get_module_status)

  if [[ -n "$status" ]]; then
    test_pass "Module status retrieval succeeded"

    # Verify JSON format
    if echo "$status" | grep -q '"sample_module_status"'; then
      test_pass "Status JSON format correct"
    else
      test_fail "Status JSON format incorrect"
    fi

    # Verify required fields
    local required_fields=("enabled" "configuration" "directories" "cache" "constants" "timestamp")
    for field in "${required_fields[@]}"; do
      if echo "$status" | grep -q "\"$field\""; then
        test_pass "Status contains required field: $field"
      else
        test_fail "Status missing required field: $field"
      fi
    done
  else
    test_fail "Module status retrieval failed"
  fi

  # Test with invalid parameters
  if sample_get_module_status "invalid_param" 2>/dev/null; then
    test_fail "Should reject invalid parameters"
  else
    test_pass "Correctly rejects invalid parameters"
  fi

  return 0
}

# Test 8: Error Handling
test_error_handling() {
  test_start "Error Handling"

  # Test functions with wrong parameter counts
  local functions=(
    "sample_module_init invalid_param"
    "sample_create_default_config invalid_param"
    "sample_get_config_value"
    "sample_validate_input_data single_param"
    "sample_process_data_batch"
    "sample_cache_operation single_param"
    "sample_get_module_status invalid_param"
  )

  for func_call in "${functions[@]}"; do
    if eval "$func_call" 2>/dev/null; then
      test_fail "Function should reject invalid parameter count: $func_call"
    else
      test_pass "Function correctly rejects invalid parameter count: $func_call"
    fi
  done

  return 0
}

# Test 9: Integration Test
test_integration() {
  test_start "Integration Test"

  # Test complete workflow
  local workflow_success=true

  # 1. Initialize module
  if ! sample_module_init; then
    workflow_success=false
    test_fail "Integration: Module initialization failed"
  fi

  # 2. Create configuration
  if ! sample_create_default_config; then
    workflow_success=false
    test_fail "Integration: Configuration creation failed"
  fi

  # 3. Get configuration value
  local timeout
  timeout=$(sample_get_config_value "timeout" "30")
  if [[ -z "$timeout" ]]; then
    workflow_success=false
    test_fail "Integration: Configuration retrieval failed"
  fi

  # 4. Validate some data
  if ! sample_validate_input_data "test@example.com" "email"; then
    workflow_success=false
    test_fail "Integration: Data validation failed"
  fi

  # 5. Process data
  local processed
  processed=$(sample_process_data_batch "test1,test2" "standard")
  if [[ -z "$processed" ]]; then
    workflow_success=false
    test_fail "Integration: Data processing failed"
  fi

  # 6. Cache operation
  local cached
  cached=$(sample_cache_operation "integration_test" "echo 'integration_result'" 300)
  if [[ "$cached" != "integration_result" ]]; then
    workflow_success=false
    test_fail "Integration: Cache operation failed"
  fi

  # 7. Get status
  local status
  status=$(sample_get_module_status)
  if [[ -z "$status" ]]; then
    workflow_success=false
    test_fail "Integration: Status retrieval failed"
  fi

  # 8. Cleanup
  if ! sample_cleanup_cache 3600 100; then
    workflow_success=false
    test_fail "Integration: Cache cleanup failed"
  fi

  if [[ "$workflow_success" == "true" ]]; then
    test_pass "Complete integration workflow succeeded"
  else
    test_fail "Integration workflow had failures"
  fi

  return 0
}

# Main test execution
main() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}ServerSentry Sample Module Test Suite${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo

  # Run all tests
  test_module_initialization
  test_configuration_management
  test_input_validation
  test_data_processing
  test_cache_operations
  test_cache_cleanup
  test_module_status
  test_error_handling
  test_integration

  # Print summary
  echo
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}Test Summary${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "Total Tests: $TEST_TOTAL"
  echo -e "${GREEN}Passed: $TEST_PASSED${NC}"
  echo -e "${RED}Failed: $TEST_FAILED${NC}"

  if [[ $TEST_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}❌ Some tests failed!${NC}"
    exit 1
  fi
}

# Run tests
main "$@"
