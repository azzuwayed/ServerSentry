#!/usr/bin/env bash
#
# ServerSentry v2 - Validation Utils Tests
#
# Comprehensive test suite for lib/core/utils/validation_utils.sh

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source the test framework
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "${BASE_DIR}/lib/core/utils/validation_utils.sh"
source "${BASE_DIR}/lib/core/logging.sh"

# Test configuration
TEST_FILES_DIR="${TEST_TEMP_DIR}/validation_files"
TEST_DIRS_DIR="${TEST_TEMP_DIR}/validation_dirs"

# Setup function
setup_validation_utils_tests() {
  log_info "Setting up validation utils tests..."

  # Create test directories and files
  mkdir -p "$TEST_FILES_DIR"
  mkdir -p "$TEST_DIRS_DIR"

  # Create test files with different permissions
  echo "test content" >"${TEST_FILES_DIR}/readable_file.txt"
  echo "test content" >"${TEST_FILES_DIR}/unreadable_file.txt"
  chmod 644 "${TEST_FILES_DIR}/readable_file.txt"
  chmod 000 "${TEST_FILES_DIR}/unreadable_file.txt"

  # Create test directories with different permissions
  mkdir -p "${TEST_DIRS_DIR}/accessible_dir"
  mkdir -p "${TEST_DIRS_DIR}/inaccessible_dir"
  chmod 755 "${TEST_DIRS_DIR}/accessible_dir"
  chmod 000 "${TEST_DIRS_DIR}/inaccessible_dir"

  # Create mock commands for testing
  create_mock_command "test_command" "echo 'test command available'"
  create_mock_command "failing_command" "exit 1"
}

# Cleanup function
cleanup_validation_utils_tests() {
  log_info "Cleaning up validation utils tests..."

  # Restore permissions for cleanup
  chmod 644 "${TEST_FILES_DIR}/unreadable_file.txt" 2>/dev/null || true
  chmod 755 "${TEST_DIRS_DIR}/inaccessible_dir" 2>/dev/null || true

  # Clean up mocks
  cleanup_mocks
}

# Test: util_require_param - Valid parameters
test_require_param_valid() {
  log_info "Testing required parameter validation with valid inputs..."

  # Test with valid non-empty string
  assert_success util_require_param "valid_value" "test_param"

  # Test with numeric value
  assert_success util_require_param "123" "numeric_param"

  # Test with boolean value
  assert_success util_require_param "true" "boolean_param"

  # Test with special characters
  assert_success util_require_param "value@#$%^&*()" "special_param"

  # Test with spaces
  assert_success util_require_param "value with spaces" "space_param"
}

# Test: util_require_param - Invalid parameters
test_require_param_invalid() {
  log_info "Testing required parameter validation with invalid inputs..."

  # Test with empty string
  assert_failure util_require_param "" "empty_param"

  # Test with null/unset variable
  local unset_var
  assert_failure util_require_param "$unset_var" "unset_param"

  # Test with whitespace only
  assert_failure util_require_param "   " "whitespace_param"
}

# Test: util_validate_numeric - Valid numbers
test_validate_numeric_valid() {
  log_info "Testing numeric validation with valid inputs..."

  # Test positive integers
  assert_success util_validate_numeric "123" "positive_int"
  assert_success util_validate_numeric "0" "zero"
  assert_success util_validate_numeric "999999" "large_number"

  # Test single digit
  assert_success util_validate_numeric "5" "single_digit"
}

# Test: util_validate_numeric - Invalid numbers
test_validate_numeric_invalid() {
  log_info "Testing numeric validation with invalid inputs..."

  # Test negative numbers
  assert_failure util_validate_numeric "-123" "negative_number"

  # Test decimal numbers
  assert_failure util_validate_numeric "123.45" "decimal_number"

  # Test non-numeric strings
  assert_failure util_validate_numeric "abc" "text_string"
  assert_failure util_validate_numeric "12a3" "mixed_string"
  assert_failure util_validate_numeric "1 2 3" "spaced_numbers"

  # Test empty string
  assert_failure util_validate_numeric "" "empty_string"

  # Test special characters
  assert_failure util_validate_numeric "12@34" "special_chars"
}

# Test: util_validate_positive_numeric - Valid positive numbers
test_validate_positive_numeric_valid() {
  log_info "Testing positive numeric validation with valid inputs..."

  # Test positive integers
  assert_success util_validate_positive_numeric "1" "one"
  assert_success util_validate_positive_numeric "123" "positive_int"
  assert_success util_validate_positive_numeric "999999" "large_positive"
}

# Test: util_validate_positive_numeric - Invalid positive numbers
test_validate_positive_numeric_invalid() {
  log_info "Testing positive numeric validation with invalid inputs..."

  # Test zero (not positive)
  assert_failure util_validate_positive_numeric "0" "zero"

  # Test negative numbers
  assert_failure util_validate_positive_numeric "-1" "negative_one"
  assert_failure util_validate_positive_numeric "-123" "negative_number"

  # Test non-numeric values
  assert_failure util_validate_positive_numeric "abc" "text_string"
  assert_failure util_validate_positive_numeric "12.5" "decimal"
}

# Test: util_validate_boolean - Valid boolean values
test_validate_boolean_valid() {
  log_info "Testing boolean validation with valid inputs..."

  # Test true/false
  assert_success util_validate_boolean "true" "true_value"
  assert_success util_validate_boolean "false" "false_value"
}

# Test: util_validate_boolean - Invalid boolean values
test_validate_boolean_invalid() {
  log_info "Testing boolean validation with invalid inputs..."

  # Test invalid boolean values
  assert_failure util_validate_boolean "True" "capitalized_true"
  assert_failure util_validate_boolean "FALSE" "uppercase_false"
  assert_failure util_validate_boolean "yes" "yes_value"
  assert_failure util_validate_boolean "no" "no_value"
  assert_failure util_validate_boolean "1" "numeric_one"
  assert_failure util_validate_boolean "0" "numeric_zero"
  assert_failure util_validate_boolean "" "empty_string"
  assert_failure util_validate_boolean "maybe" "invalid_string"
}

# Test: util_validate_file_exists - Valid files
test_validate_file_exists_valid() {
  log_info "Testing file existence validation with valid files..."

  # Test readable file
  assert_success util_validate_file_exists "${TEST_FILES_DIR}/readable_file.txt" "Readable file"

  # Test with default description
  assert_success util_validate_file_exists "${TEST_FILES_DIR}/readable_file.txt"
}

# Test: util_validate_file_exists - Invalid files
test_validate_file_exists_invalid() {
  log_info "Testing file existence validation with invalid files..."

  # Test non-existent file
  assert_failure util_validate_file_exists "/nonexistent/file.txt" "Non-existent file"

  # Test directory instead of file
  assert_failure util_validate_file_exists "$TEST_FILES_DIR" "Directory as file"

  # Test unreadable file (if permissions allow testing)
  if [[ -f "${TEST_FILES_DIR}/unreadable_file.txt" ]]; then
    assert_failure util_validate_file_exists "${TEST_FILES_DIR}/unreadable_file.txt" "Unreadable file"
  fi
}

# Test: util_validate_dir_exists - Valid directories
test_validate_dir_exists_valid() {
  log_info "Testing directory existence validation with valid directories..."

  # Test accessible directory
  assert_success util_validate_dir_exists "$TEST_DIRS_DIR/accessible_dir" "Accessible directory"

  # Test with default description
  assert_success util_validate_dir_exists "$TEST_DIRS_DIR"

  # Test root directory
  assert_success util_validate_dir_exists "/" "Root directory"
}

# Test: util_validate_dir_exists - Invalid directories
test_validate_dir_exists_invalid() {
  log_info "Testing directory existence validation with invalid directories..."

  # Test non-existent directory
  assert_failure util_validate_dir_exists "/nonexistent/directory" "Non-existent directory"

  # Test file instead of directory
  assert_failure util_validate_dir_exists "${TEST_FILES_DIR}/readable_file.txt" "File as directory"

  # Test inaccessible directory (if permissions allow testing)
  if [[ -d "${TEST_DIRS_DIR}/inaccessible_dir" ]]; then
    assert_failure util_validate_dir_exists "${TEST_DIRS_DIR}/inaccessible_dir" "Inaccessible directory"
  fi
}

# Test: util_validate_executable - Valid executables
test_validate_executable_valid() {
  log_info "Testing executable validation with valid commands..."

  # Test common system commands
  assert_success util_validate_executable "bash" "Bash shell"
  assert_success util_validate_executable "ls" "List command"
  assert_success util_validate_executable "cat" "Cat command"

  # Test mock command
  assert_success util_validate_executable "test_command" "Test command"
}

# Test: util_validate_executable - Invalid executables
test_validate_executable_invalid() {
  log_info "Testing executable validation with invalid commands..."

  # Test non-existent command
  assert_failure util_validate_executable "nonexistent_command_12345" "Non-existent command"

  # Test failing mock command
  assert_failure util_validate_executable "failing_command" "Failing command"
}

# Test: util_validate_ip_address - Valid IP addresses
test_validate_ip_address_valid() {
  log_info "Testing IP address validation with valid addresses..."

  # Test valid IPv4 addresses
  assert_success util_validate_ip_address "192.168.1.1" "Private IP"
  assert_success util_validate_ip_address "10.0.0.1" "Private IP 10.x"
  assert_success util_validate_ip_address "172.16.0.1" "Private IP 172.x"
  assert_success util_validate_ip_address "8.8.8.8" "Public DNS"
  assert_success util_validate_ip_address "127.0.0.1" "Localhost"
  assert_success util_validate_ip_address "0.0.0.0" "Zero IP"
  assert_success util_validate_ip_address "255.255.255.255" "Broadcast IP"
}

# Test: util_validate_ip_address - Invalid IP addresses
test_validate_ip_address_invalid() {
  log_info "Testing IP address validation with invalid addresses..."

  # Test invalid formats
  assert_failure util_validate_ip_address "192.168.1" "Incomplete IP"
  assert_failure util_validate_ip_address "192.168.1.1.1" "Too many octets"
  assert_failure util_validate_ip_address "192.168.1.256" "Octet too large"
  assert_failure util_validate_ip_address "192.168.1.-1" "Negative octet"
  assert_failure util_validate_ip_address "192.168.1.abc" "Non-numeric octet"
  assert_failure util_validate_ip_address "192.168.1." "Trailing dot"
  assert_failure util_validate_ip_address ".192.168.1.1" "Leading dot"
  assert_failure util_validate_ip_address "192..168.1.1" "Double dot"
  assert_failure util_validate_ip_address "" "Empty IP"
  assert_failure util_validate_ip_address "localhost" "Hostname instead of IP"
}

# Test: util_validate_port - Valid port numbers
test_validate_port_valid() {
  log_info "Testing port validation with valid ports..."

  # Test valid port ranges
  assert_success util_validate_port "1" "Port 1"
  assert_success util_validate_port "80" "HTTP port"
  assert_success util_validate_port "443" "HTTPS port"
  assert_success util_validate_port "8080" "Alt HTTP port"
  assert_success util_validate_port "65535" "Max port"
  assert_success util_validate_port "22" "SSH port"
  assert_success util_validate_port "3306" "MySQL port"
}

# Test: util_validate_port - Invalid port numbers
test_validate_port_invalid() {
  log_info "Testing port validation with invalid ports..."

  # Test invalid port numbers
  assert_failure util_validate_port "0" "Port 0"
  assert_failure util_validate_port "-1" "Negative port"
  assert_failure util_validate_port "65536" "Port too large"
  assert_failure util_validate_port "99999" "Way too large"
  assert_failure util_validate_port "abc" "Non-numeric port"
  assert_failure util_validate_port "80.5" "Decimal port"
  assert_failure util_validate_port "" "Empty port"
  assert_failure util_validate_port "8 0" "Spaced port"
}

# Test: util_validate_url - Valid URLs
test_validate_url_valid() {
  log_info "Testing URL validation with valid URLs..."

  # Test valid HTTP/HTTPS URLs
  assert_success util_validate_url "http://example.com" "HTTP URL"
  assert_success util_validate_url "https://example.com" "HTTPS URL"
  assert_success util_validate_url "http://localhost" "Localhost HTTP"
  assert_success util_validate_url "https://localhost:8080" "Localhost with port"
  assert_success util_validate_url "http://192.168.1.1" "IP URL"
  assert_success util_validate_url "https://example.com/path/to/resource" "URL with path"
  assert_success util_validate_url "http://example.com?param=value" "URL with query"
  assert_success util_validate_url "https://user:pass@example.com" "URL with auth"
}

# Test: util_validate_url - Invalid URLs
test_validate_url_invalid() {
  log_info "Testing URL validation with invalid URLs..."

  # Test invalid URL formats
  assert_failure util_validate_url "ftp://example.com" "FTP URL"
  assert_failure util_validate_url "example.com" "No protocol"
  assert_failure util_validate_url "www.example.com" "No protocol with www"
  assert_failure util_validate_url "file:///path/to/file" "File URL"
  assert_failure util_validate_url "" "Empty URL"
  assert_failure util_validate_url "http://" "Incomplete HTTP"
  assert_failure util_validate_url "https://" "Incomplete HTTPS"
}

# Test: util_validate_email - Valid email addresses
test_validate_email_valid() {
  log_info "Testing email validation with valid addresses..."

  # Test valid email formats
  assert_success util_validate_email "user@example.com" "Basic email"
  assert_success util_validate_email "test.user@example.com" "Email with dot"
  assert_success util_validate_email "user+tag@example.com" "Email with plus"
  assert_success util_validate_email "user123@example123.com" "Email with numbers"
  assert_success util_validate_email "user@subdomain.example.com" "Email with subdomain"
  assert_success util_validate_email "a@b.co" "Short email"
}

# Test: util_validate_email - Invalid email addresses
test_validate_email_invalid() {
  log_info "Testing email validation with invalid addresses..."

  # Test invalid email formats
  assert_failure util_validate_email "user" "No @ symbol"
  assert_failure util_validate_email "@example.com" "No user part"
  assert_failure util_validate_email "user@" "No domain part"
  assert_failure util_validate_email "user@example" "No TLD"
  assert_failure util_validate_email "user@@example.com" "Double @"
  assert_failure util_validate_email "user@.example.com" "Leading dot in domain"
  assert_failure util_validate_email "user@example..com" "Double dot in domain"
  assert_failure util_validate_email "" "Empty email"
  assert_failure util_validate_email "user name@example.com" "Space in user"
}

# Test: util_validate_log_level - Valid log levels
test_validate_log_level_valid() {
  log_info "Testing log level validation with valid levels..."

  # Test all valid log levels
  assert_success util_validate_log_level "debug" "Debug level"
  assert_success util_validate_log_level "info" "Info level"
  assert_success util_validate_log_level "warning" "Warning level"
  assert_success util_validate_log_level "error" "Error level"
  assert_success util_validate_log_level "critical" "Critical level"
}

# Test: util_validate_log_level - Invalid log levels
test_validate_log_level_invalid() {
  log_info "Testing log level validation with invalid levels..."

  # Test invalid log levels
  assert_failure util_validate_log_level "DEBUG" "Uppercase debug"
  assert_failure util_validate_log_level "INFO" "Uppercase info"
  assert_failure util_validate_log_level "warn" "Short warning"
  assert_failure util_validate_log_level "err" "Short error"
  assert_failure util_validate_log_level "fatal" "Fatal level"
  assert_failure util_validate_log_level "trace" "Trace level"
  assert_failure util_validate_log_level "" "Empty level"
  assert_failure util_validate_log_level "invalid" "Invalid level"
}

# Test: util_validate_string_length - Valid string lengths
test_validate_string_length_valid() {
  log_info "Testing string length validation with valid lengths..."

  # Test strings within valid range
  assert_success util_validate_string_length "hello" 1 10 "Short string"
  assert_success util_validate_string_length "hello world" 5 20 "Medium string"
  assert_success util_validate_string_length "a" 1 1 "Exact min length"
  assert_success util_validate_string_length "abcdefghij" 10 10 "Exact max length"

  # Test with longer strings
  local long_string
  long_string=$(printf 'a%.0s' {1..50})
  assert_success util_validate_string_length "$long_string" 1 100 "Long string"
}

# Test: util_validate_string_length - Invalid string lengths
test_validate_string_length_invalid() {
  log_info "Testing string length validation with invalid lengths..."

  # Test strings too short
  assert_failure util_validate_string_length "hi" 5 10 "Too short"
  assert_failure util_validate_string_length "" 1 10 "Empty string"

  # Test strings too long
  assert_failure util_validate_string_length "hello world" 1 5 "Too long"

  local very_long_string
  very_long_string=$(printf 'a%.0s' {1..200})
  assert_failure util_validate_string_length "$very_long_string" 1 100 "Very long string"
}

# Test: util_validate_path_safe - Safe paths
test_validate_path_safe_valid() {
  log_info "Testing path safety validation with safe paths..."

  # Test safe relative paths
  assert_success util_validate_path_safe "file.txt" "Simple filename"
  assert_success util_validate_path_safe "dir/file.txt" "Relative path"
  assert_success util_validate_path_safe "dir/subdir/file.txt" "Nested relative path"
  assert_success util_validate_path_safe "./file.txt" "Current dir path"

  # Test absolute paths (should warn but pass)
  assert_success util_validate_path_safe "/etc/passwd" "Absolute path"
  assert_success util_validate_path_safe "/home/user/file.txt" "User absolute path"
}

# Test: util_validate_path_safe - Unsafe paths
test_validate_path_safe_invalid() {
  log_info "Testing path safety validation with unsafe paths..."

  # Test directory traversal attempts
  assert_failure util_validate_path_safe "../file.txt" "Parent directory"
  assert_failure util_validate_path_safe "../../etc/passwd" "Multiple parent dirs"
  assert_failure util_validate_path_safe "dir/../../../etc/passwd" "Mixed traversal"
  assert_failure util_validate_path_safe "dir\\..\\file.txt" "Windows-style traversal"
}

# Test: util_sanitize_input - Input sanitization
test_sanitize_input() {
  log_info "Testing input sanitization..."

  # Test normal input (should remain unchanged)
  local result
  result=$(util_sanitize_input "normal text")
  assert_equals "normal text" "$result" "Normal text unchanged"

  # Test input with control characters
  result=$(util_sanitize_input $'text\nwith\tcontrol\rcharacters')
  assert_equals "textwithcontrolcharacters" "$result" "Control characters removed"

  # Test very long input (should be truncated)
  local long_input
  long_input=$(printf 'a%.0s' {1..2000})
  result=$(util_sanitize_input "$long_input")
  local result_length=${#result}
  assert_true "[[ $result_length -le 1024 ]]" "Long input truncated to 1024 chars"

  # Test input with special characters (should remain)
  result=$(util_sanitize_input "text@#$%^&*()")
  assert_equals "text@#$%^&*()" "$result" "Special characters preserved"

  # Test empty input
  result=$(util_sanitize_input "")
  assert_equals "" "$result" "Empty input handled"
}

# Test: util_sanitize_path - Path sanitization
test_sanitize_path() {
  log_info "Testing path sanitization..."

  # Test normal path (should remain unchanged)
  local result
  result=$(util_sanitize_path "normal/path/file.txt")
  assert_equals "normal/path/file.txt" "$result" "Normal path unchanged"

  # Test path with dangerous characters
  result=$(util_sanitize_path "path;with&dangerous|chars\$()")
  assert_equals "pathwithdangerouschars" "$result" "Dangerous characters removed"

  # Test path with multiple slashes
  result=$(util_sanitize_path "path//with///multiple////slashes")
  assert_equals "path/with/multiple/slashes" "$result" "Multiple slashes normalized"

  # Test path with mixed dangerous chars and slashes
  result=$(util_sanitize_path "path//with;&dangerous//chars")
  assert_equals "path/with/dangerous/chars" "$result" "Mixed cleanup"

  # Test empty path
  result=$(util_sanitize_path "")
  assert_equals "" "$result" "Empty path handled"
}

# Test: Edge cases and boundary conditions
test_validation_edge_cases() {
  log_info "Testing validation edge cases..."

  # Test very large numbers
  assert_success util_validate_numeric "999999999999999999" "Very large number"
  assert_success util_validate_positive_numeric "999999999999999999" "Very large positive"

  # Test boundary port numbers
  assert_success util_validate_port "1" "Min port"
  assert_success util_validate_port "65535" "Max port"

  # Test boundary IP octets
  assert_success util_validate_ip_address "0.0.0.0" "Min IP"
  assert_success util_validate_ip_address "255.255.255.255" "Max IP"

  # Test string length boundaries
  assert_success util_validate_string_length "a" 1 1 "Min/max same"
  assert_failure util_validate_string_length "ab" 1 1 "Exceeds min/max same"

  # Test Unicode characters in sanitization
  local unicode_input="测试 🚀 ñoño"
  local sanitized
  sanitized=$(util_sanitize_input "$unicode_input")
  assert_not_empty "$sanitized" "Unicode input sanitized"
}

# Test: Performance with large inputs
test_validation_performance() {
  log_info "Testing validation performance with large inputs..."

  # Test large string validation performance
  local large_string
  large_string=$(printf 'a%.0s' {1..10000})

  local start_time
  start_time=$(get_timestamp_ms)

  util_validate_string_length "$large_string" 1 20000 "Large string"

  local end_time
  end_time=$(get_timestamp_ms)
  local duration=$((end_time - start_time))

  # Should complete quickly (under 1 second)
  assert_true "[[ $duration -lt 1000 ]]" "Large string validation performance: ${duration}ms"

  # Test sanitization performance
  start_time=$(get_timestamp_ms)

  util_sanitize_input "$large_string" >/dev/null

  end_time=$(get_timestamp_ms)
  duration=$((end_time - start_time))

  assert_true "[[ $duration -lt 1000 ]]" "Large input sanitization performance: ${duration}ms"
}

# Test: Multiple validation combinations
test_validation_combinations() {
  log_info "Testing validation function combinations..."

  # Test combining multiple validations
  local test_value="123"
  assert_success util_require_param "$test_value" "combo_test"
  assert_success util_validate_numeric "$test_value" "combo_test"
  assert_success util_validate_positive_numeric "$test_value" "combo_test"

  # Test port validation (combines numeric and range)
  assert_success util_validate_port "8080" "combo_port"

  # Test email with length validation
  local email="test@example.com"
  assert_success util_validate_email "$email" "combo_email"
  assert_success util_validate_string_length "$email" 5 50 "combo_email"

  # Test URL with sanitization
  local url="https://example.com/path"
  assert_success util_validate_url "$url" "combo_url"
  local sanitized_url
  sanitized_url=$(util_sanitize_input "$url")
  assert_equals "$url" "$sanitized_url" "URL sanitization preserves valid URL"
}

# Main test execution
main() {
  log_info "Starting Validation Utils comprehensive tests..."

  # Initialize test framework
  init_test_framework

  # Set up test environment
  setup_validation_utils_tests

  # Run all tests
  run_test test_require_param_valid
  run_test test_require_param_invalid
  run_test test_validate_numeric_valid
  run_test test_validate_numeric_invalid
  run_test test_validate_positive_numeric_valid
  run_test test_validate_positive_numeric_invalid
  run_test test_validate_boolean_valid
  run_test test_validate_boolean_invalid
  run_test test_validate_file_exists_valid
  run_test test_validate_file_exists_invalid
  run_test test_validate_dir_exists_valid
  run_test test_validate_dir_exists_invalid
  run_test test_validate_executable_valid
  run_test test_validate_executable_invalid
  run_test test_validate_ip_address_valid
  run_test test_validate_ip_address_invalid
  run_test test_validate_port_valid
  run_test test_validate_port_invalid
  run_test test_validate_url_valid
  run_test test_validate_url_invalid
  run_test test_validate_email_valid
  run_test test_validate_email_invalid
  run_test test_validate_log_level_valid
  run_test test_validate_log_level_invalid
  run_test test_validate_string_length_valid
  run_test test_validate_string_length_invalid
  run_test test_validate_path_safe_valid
  run_test test_validate_path_safe_invalid
  run_test test_sanitize_input
  run_test test_sanitize_path
  run_test test_validation_edge_cases
  run_test test_validation_performance
  run_test test_validation_combinations

  # Clean up
  cleanup_validation_utils_tests

  # Print results
  print_test_results

  log_info "Validation Utils tests completed!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
