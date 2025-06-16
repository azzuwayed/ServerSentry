#!/usr/bin/env bash
#
# ServerSentry v2 - Config Utils Tests
#
# Comprehensive test suite for lib/core/utils/config_utils.sh

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi

# Source the test framework
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "${SERVERSENTRY_ROOT}/lib/core/utils/config_utils.sh"
source "${SERVERSENTRY_ROOT}/lib/core/utils/validation_utils.sh"
source "${SERVERSENTRY_ROOT}/lib/core/logging.sh"

# Test configuration
TEST_CONFIG_DIR="${TEST_TEMP_DIR}/config"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/test_config.yaml"
TEST_ENV_CONFIG_FILE="${TEST_CONFIG_DIR}/env_config.yaml"

# Helper function to create test YAML config
create_test_yaml_config() {
  local config_file="$1"
  local config_type="${2:-basic}"

  mkdir -p "$(dirname "$config_file")"

  case "$config_type" in
  "basic")
    cat >"$config_file" <<'EOF'
# Basic test configuration
enabled: true
log_level: info
check_interval: 60
timeout: 30

# Nested configuration
database:
  host: localhost
  port: 5432
  name: serversentry
  ssl: false

# Array configuration
plugins:
  - name: cpu
    enabled: true
    threshold: 80
  - name: memory
    enabled: true
    threshold: 90

# Notification settings
notifications:
  email:
    enabled: true
    smtp_host: smtp.example.com
    smtp_port: 587
  teams:
    enabled: false
    webhook_url: ""
EOF
    ;;
  "complex")
    cat >"$config_file" <<'EOF'
# Complex nested configuration
server:
  name: "Test Server"
  environment: production
  features:
    monitoring: true
    alerting: true
    reporting: false

monitoring:
  cpu:
    enabled: true
    threshold: 85.5
    check_interval: 30
  memory:
    enabled: true
    threshold: 90
    check_interval: 60
  disk:
    enabled: true
    paths:
      - /
      - /var
      - /tmp
    threshold: 95

alerts:
  critical:
    enabled: true
    cooldown: 300
  warning:
    enabled: true
    cooldown: 600
  info:
    enabled: false
    cooldown: 900
EOF
    ;;
  "invalid")
    cat >"$config_file" <<'EOF'
# Invalid YAML configuration
enabled: true
invalid_yaml: [unclosed array
missing_value:
  nested:
    incomplete
EOF
    ;;
  "empty")
    touch "$config_file"
    ;;
  esac
}

# Helper function to create validation rules
create_validation_rules() {
  local rules_array_name="$1"

  eval "${rules_array_name}=(
        'enabled:required:'
        'log_level:log_level:'
        'check_interval:positive_numeric:'
        'timeout:range:1-300'
        'database.port:numeric:'
        'notifications.email.smtp_port:range:1-65535'
        'server.environment:enum:[development,staging,production]'
        'monitoring.cpu.threshold:range:0-100'
    )"
}

# Setup function
setup_config_utils_tests() {
  log_info "Setting up config utils tests..."

  # Create test directories
  mkdir -p "$TEST_CONFIG_DIR"

  # Create test configurations
  create_test_yaml_config "$TEST_CONFIG_FILE" "basic"
  create_test_yaml_config "${TEST_CONFIG_DIR}/complex_config.yaml" "complex"
  create_test_yaml_config "${TEST_CONFIG_DIR}/invalid_config.yaml" "invalid"
  create_test_yaml_config "${TEST_CONFIG_DIR}/empty_config.yaml" "empty"

  # Mock yq command for testing
  create_mock_command "yq" 'echo "enabled=true"; echo "log_level=info"; echo "database.host=localhost"'

  # Set up environment variables for testing
  export SERVERSENTRY_LOG_LEVEL="debug"
  export SERVERSENTRY_CHECK_INTERVAL="120"
  export SERVERSENTRY_DATABASE_HOST="override.example.com"
}

# Cleanup function
cleanup_config_utils_tests() {
  log_info "Cleaning up config utils tests..."

  # Clean up environment variables
  unset SERVERSENTRY_LOG_LEVEL
  unset SERVERSENTRY_CHECK_INTERVAL
  unset SERVERSENTRY_DATABASE_HOST

  # Clean up mocks
  cleanup_mocks

  # Clear configuration cache if supported
  if [[ "$CACHE_SUPPORTED" == "true" ]]; then
    unset CONFIG_CACHE
    unset CONFIG_TIMESTAMPS
    declare -A CONFIG_CACHE
    declare -A CONFIG_TIMESTAMPS
  fi
}

# Test: util_config_parse_yaml - Basic parsing
test_config_parse_yaml_basic() {
  log_info "Testing basic YAML parsing..."

  # Test basic parsing
  assert_success util_config_parse_yaml "$TEST_CONFIG_FILE" "test_config"

  # Verify parsed values
  local enabled
  enabled=$(util_config_get_value "enabled" "" "test_config")
  assert_equals "true" "$enabled" "Basic boolean value"

  local log_level
  log_level=$(util_config_get_value "log_level" "" "test_config")
  assert_equals "info" "$log_level" "Basic string value"

  local check_interval
  check_interval=$(util_config_get_value "check_interval" "" "test_config")
  assert_equals "60" "$check_interval" "Basic numeric value"
}

# Test: util_config_parse_yaml - Nested values
test_config_parse_yaml_nested() {
  log_info "Testing nested YAML parsing..."

  assert_success util_config_parse_yaml "$TEST_CONFIG_FILE" "test_config"

  # Test nested values
  local db_host
  db_host=$(util_config_get_value "database.host" "" "test_config")
  assert_equals "localhost" "$db_host" "Nested string value"

  local db_port
  db_port=$(util_config_get_value "database.port" "" "test_config")
  assert_equals "5432" "$db_port" "Nested numeric value"

  local db_ssl
  db_ssl=$(util_config_get_value "database.ssl" "" "test_config")
  assert_equals "false" "$db_ssl" "Nested boolean value"
}

# Test: util_config_parse_yaml - Array values
test_config_parse_yaml_arrays() {
  log_info "Testing array YAML parsing..."

  assert_success util_config_parse_yaml "$TEST_CONFIG_FILE" "test_config"

  # Test array values
  local plugin_name_0
  plugin_name_0=$(util_config_get_value "plugins.0.name" "" "test_config")
  assert_equals "cpu" "$plugin_name_0" "First array element"

  local plugin_name_1
  plugin_name_1=$(util_config_get_value "plugins.1.name" "" "test_config")
  assert_equals "memory" "$plugin_name_1" "Second array element"

  local plugin_threshold_0
  plugin_threshold_0=$(util_config_get_value "plugins.0.threshold" "" "test_config")
  assert_equals "80" "$plugin_threshold_0" "Array element nested value"
}

# Test: util_config_parse_yaml - Complex configuration
test_config_parse_yaml_complex() {
  log_info "Testing complex YAML parsing..."

  local complex_config="${TEST_CONFIG_DIR}/complex_config.yaml"
  assert_success util_config_parse_yaml "$complex_config" "complex"

  # Test deeply nested values
  local server_name
  server_name=$(util_config_get_value "server.name" "" "complex")
  assert_equals "Test Server" "$server_name" "Quoted string value"

  local monitoring_enabled
  monitoring_enabled=$(util_config_get_value "server.features.monitoring" "" "complex")
  assert_equals "true" "$monitoring_enabled" "Deep nested boolean"

  local cpu_threshold
  cpu_threshold=$(util_config_get_value "monitoring.cpu.threshold" "" "complex")
  assert_equals "85.5" "$cpu_threshold" "Decimal numeric value"
}

# Test: util_config_parse_yaml - Error handling
test_config_parse_yaml_errors() {
  log_info "Testing YAML parsing error handling..."

  # Test non-existent file
  assert_failure util_config_parse_yaml "/nonexistent/config.yaml" "test"

  # Test invalid YAML (should still work with basic parser)
  local invalid_config="${TEST_CONFIG_DIR}/invalid_config.yaml"
  # Basic parser is more forgiving, so this might succeed
  util_config_parse_yaml "$invalid_config" "invalid_test"

  # Test empty file
  local empty_config="${TEST_CONFIG_DIR}/empty_config.yaml"
  assert_success util_config_parse_yaml "$empty_config" "empty_test"
}

# Test: util_config_get_cached - Caching functionality
test_config_get_cached() {
  log_info "Testing configuration caching..."

  # Test cached loading
  local start_time
  start_time=$(date +%s)

  assert_success util_config_get_cached "$TEST_CONFIG_FILE" "cached_config" 300

  local end_time
  end_time=$(date +%s)

  # Verify configuration was loaded
  local enabled
  enabled=$(util_config_get_value "enabled" "" "cached_config")
  assert_equals "true" "$enabled" "Cached configuration value"

  # Test cache duration (basic check)
  assert_true "[[ $((end_time - start_time)) -lt 5 ]]" "Cache loading performance"
}

# Test: util_config_get_value - Basic value retrieval
test_config_get_value_basic() {
  log_info "Testing basic value retrieval..."

  # Set up test configuration
  util_config_set_value "test.key" "test_value" "get_test"
  util_config_set_value "test.number" "42" "get_test"
  util_config_set_value "test.boolean" "true" "get_test"

  # Test basic retrieval
  local value
  value=$(util_config_get_value "test.key" "" "get_test")
  assert_equals "test_value" "$value" "String value retrieval"

  value=$(util_config_get_value "test.number" "" "get_test")
  assert_equals "42" "$value" "Numeric value retrieval"

  value=$(util_config_get_value "test.boolean" "" "get_test")
  assert_equals "true" "$value" "Boolean value retrieval"
}

# Test: util_config_get_value - Default values
test_config_get_value_defaults() {
  log_info "Testing default value handling..."

  # Test with default value
  local value
  value=$(util_config_get_value "nonexistent.key" "default_value" "get_test")
  assert_equals "default_value" "$value" "Default value for missing key"

  # Test empty default
  value=$(util_config_get_value "nonexistent.key" "" "get_test")
  assert_equals "" "$value" "Empty default value"

  # Test with existing value (should ignore default)
  util_config_set_value "existing.key" "existing_value" "get_test"
  value=$(util_config_get_value "existing.key" "default_value" "get_test")
  assert_equals "existing_value" "$value" "Existing value ignores default"
}

# Test: util_config_get_value - Dot notation conversion
test_config_get_value_dot_notation() {
  log_info "Testing dot notation conversion..."

  # Test various dot notation patterns
  util_config_set_value "simple.key" "simple_value" "dot_test"
  util_config_set_value "deep.nested.key" "nested_value" "dot_test"
  util_config_set_value "array.0.item" "array_value" "dot_test"

  local value
  value=$(util_config_get_value "simple.key" "" "dot_test")
  assert_equals "simple_value" "$value" "Simple dot notation"

  value=$(util_config_get_value "deep.nested.key" "" "dot_test")
  assert_equals "nested_value" "$value" "Deep nested dot notation"

  value=$(util_config_get_value "array.0.item" "" "dot_test")
  assert_equals "array_value" "$value" "Array dot notation"
}

# Test: util_config_get_array - Array retrieval
test_config_get_array() {
  log_info "Testing array value retrieval..."

  # Set up array values
  util_config_set_value "test.array.0" "first" "array_test"
  util_config_set_value "test.array.1" "second" "array_test"
  util_config_set_value "test.array.2" "third" "array_test"

  # Test array retrieval
  local array_values
  array_values=$(util_config_get_array "test.array" "array_test")

  # Convert to array for testing
  local values_array=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && values_array+=("$line")
  done <<<"$array_values"

  assert_equals "3" "${#values_array[@]}" "Array length"
  assert_equals "first" "${values_array[0]}" "First array element"
  assert_equals "second" "${values_array[1]}" "Second array element"
  assert_equals "third" "${values_array[2]}" "Third array element"
}

# Test: util_config_get_array - Empty array
test_config_get_array_empty() {
  log_info "Testing empty array retrieval..."

  # Test non-existent array
  local array_values
  array_values=$(util_config_get_array "nonexistent.array" "array_test")

  assert_equals "" "$array_values" "Empty array result"
}

# Test: util_config_set_value - Basic setting
test_config_set_value_basic() {
  log_info "Testing basic value setting..."

  # Test setting various types
  assert_success util_config_set_value "set.string" "test_string" "set_test"
  assert_success util_config_set_value "set.number" "123" "set_test"
  assert_success util_config_set_value "set.boolean" "false" "set_test"

  # Verify values were set
  local value
  value=$(util_config_get_value "set.string" "" "set_test")
  assert_equals "test_string" "$value" "String value setting"

  value=$(util_config_get_value "set.number" "" "set_test")
  assert_equals "123" "$value" "Numeric value setting"

  value=$(util_config_get_value "set.boolean" "" "set_test")
  assert_equals "false" "$value" "Boolean value setting"
}

# Test: util_config_set_value - Special characters
test_config_set_value_special_chars() {
  log_info "Testing value setting with special characters..."

  # Test special characters
  assert_success util_config_set_value "special.spaces" "value with spaces" "special_test"
  assert_success util_config_set_value "special.quotes" 'value "with" quotes' "special_test"
  assert_success util_config_set_value "special.symbols" "value@#$%^&*()" "special_test"

  # Verify special character handling
  local value
  value=$(util_config_get_value "special.spaces" "" "special_test")
  assert_equals "value with spaces" "$value" "Spaces in value"

  value=$(util_config_get_value "special.quotes" "" "special_test")
  assert_equals 'value "with" quotes' "$value" "Quotes in value"

  value=$(util_config_get_value "special.symbols" "" "special_test")
  assert_equals "value@#$%^&*()" "$value" "Symbols in value"
}

# Test: util_config_set_value - Overwriting values
test_config_set_value_overwrite() {
  log_info "Testing value overwriting..."

  # Set initial value
  util_config_set_value "overwrite.test" "initial_value" "overwrite_test"

  local value
  value=$(util_config_get_value "overwrite.test" "" "overwrite_test")
  assert_equals "initial_value" "$value" "Initial value"

  # Overwrite value
  util_config_set_value "overwrite.test" "new_value" "overwrite_test"

  value=$(util_config_get_value "overwrite.test" "" "overwrite_test")
  assert_equals "new_value" "$value" "Overwritten value"
}

# Test: util_config_validate_values - Validation rules
test_config_validate_values() {
  log_info "Testing configuration validation..."

  # Set up test configuration
  util_config_set_value "enabled" "true" "validation_test"
  util_config_set_value "log_level" "info" "validation_test"
  util_config_set_value "check_interval" "60" "validation_test"
  util_config_set_value "timeout" "30" "validation_test"
  util_config_set_value "database.port" "5432" "validation_test"

  # Create validation rules
  local validation_rules=()
  create_validation_rules "validation_rules"

  # Test successful validation
  assert_success util_config_validate_values "validation_rules" "validation_test"
}

# Test: util_config_validate_values - Validation failures
test_config_validate_values_failures() {
  log_info "Testing configuration validation failures..."

  # Set up invalid configuration
  util_config_set_value "enabled" "" "invalid_test"          # Missing required
  util_config_set_value "log_level" "invalid" "invalid_test" # Invalid log level
  util_config_set_value "check_interval" "-5" "invalid_test" # Negative number
  util_config_set_value "timeout" "500" "invalid_test"       # Out of range

  # Create validation rules
  local validation_rules=()
  create_validation_rules "validation_rules"

  # Test validation failure
  assert_failure util_config_validate_values "validation_rules" "invalid_test"
}

# Test: util_config_validate_values - Enum validation
test_config_validate_values_enum() {
  log_info "Testing enum validation..."

  # Test valid enum value
  util_config_set_value "server.environment" "production" "enum_test"

  local enum_rules=(
    "server.environment:enum:[development,staging,production]"
  )

  assert_success util_config_validate_values "enum_rules" "enum_test"

  # Test invalid enum value
  util_config_set_value "server.environment" "invalid_env" "enum_test"
  assert_failure util_config_validate_values "enum_rules" "enum_test"
}

# Test: util_config_validate_values - Range validation
test_config_validate_values_range() {
  log_info "Testing range validation..."

  # Test valid range value
  util_config_set_value "monitoring.cpu.threshold" "85" "range_test"

  local range_rules=(
    "monitoring.cpu.threshold:range:0-100"
  )

  assert_success util_config_validate_values "range_rules" "range_test"

  # Test out of range value
  util_config_set_value "monitoring.cpu.threshold" "150" "range_test"
  assert_failure util_config_validate_values "range_rules" "range_test"
}

# Test: util_config_load_env_overrides - Environment overrides
test_config_load_env_overrides() {
  log_info "Testing environment variable overrides..."

  # Set up base configuration
  util_config_set_value "log_level" "info" "env_test"
  util_config_set_value "check_interval" "60" "env_test"
  util_config_set_value "database.host" "localhost" "env_test"

  # Load environment overrides
  assert_success util_config_load_env_overrides "SERVERSENTRY" "env_test"

  # Verify overrides were applied
  local log_level
  log_level=$(util_config_get_value "log_level" "" "env_test")
  assert_equals "debug" "$log_level" "Environment log_level override"

  local check_interval
  check_interval=$(util_config_get_value "check_interval" "" "env_test")
  assert_equals "120" "$check_interval" "Environment check_interval override"

  local db_host
  db_host=$(util_config_get_value "database.host" "" "env_test")
  assert_equals "override.example.com" "$db_host" "Environment database.host override"
}

# Test: util_config_create_default - Default config creation
test_config_create_default() {
  log_info "Testing default configuration creation..."

  local default_config="${TEST_CONFIG_DIR}/default_config.yaml"
  local template_content="enabled: true
log_level: info
check_interval: 60"

  # Test creating default configuration
  assert_success util_config_create_default "$default_config" "$template_content"

  # Verify file was created
  assert_file_exists "$default_config" "Default config file created"

  # Verify content
  local content
  content=$(cat "$default_config")
  assert_contains "$content" "enabled: true" "Default config content"
  assert_contains "$content" "log_level: info" "Default config content"
}

# Test: util_config_create_default - Directory creation
test_config_create_default_mkdir() {
  log_info "Testing default configuration with directory creation..."

  local new_dir="${TEST_CONFIG_DIR}/new/nested/dir"
  local new_config="${new_dir}/config.yaml"
  local template_content="test: value"

  # Test creating config in non-existent directory
  assert_success util_config_create_default "$new_config" "$template_content"

  # Verify directory and file were created
  assert_dir_exists "$new_dir" "New directory created"
  assert_file_exists "$new_config" "Config file in new directory"
}

# Test: Performance with large configuration
test_config_performance_large() {
  log_info "Testing performance with large configuration..."

  local large_config="${TEST_CONFIG_DIR}/large_config.yaml"

  # Create large configuration
  {
    echo "# Large configuration file"
    for i in {1..100}; do
      echo "section_${i}:"
      for j in {1..10}; do
        echo "  key_${j}: value_${i}_${j}"
      done
    done
  } >"$large_config"

  # Test parsing performance
  local start_time
  start_time=$(get_timestamp_ms)

  assert_success util_config_parse_yaml "$large_config" "large_test"

  local end_time
  end_time=$(get_timestamp_ms)
  local duration=$((end_time - start_time))

  # Should complete within reasonable time (5 seconds)
  assert_true "[[ $duration -lt 5000 ]]" "Large config parsing performance: ${duration}ms"

  # Verify some values were parsed
  local value
  value=$(util_config_get_value "section_1.key_1" "" "large_test")
  assert_equals "value_1_1" "$value" "Large config value retrieval"
}

# Test: Edge cases and error conditions
test_config_edge_cases() {
  log_info "Testing configuration edge cases..."

  # Test empty key
  util_config_set_value "" "empty_key_value" "edge_test"
  local value
  value=$(util_config_get_value "" "" "edge_test")
  # Should handle gracefully

  # Test very long key
  local long_key="very.long.nested.key.with.many.levels.that.goes.on.and.on"
  util_config_set_value "$long_key" "long_key_value" "edge_test"
  value=$(util_config_get_value "$long_key" "" "edge_test")
  assert_equals "long_key_value" "$value" "Very long key handling"

  # Test very long value
  local long_value
  long_value=$(printf 'a%.0s' {1..1000})
  util_config_set_value "long.value" "$long_value" "edge_test"
  value=$(util_config_get_value "long.value" "" "edge_test")
  assert_equals "$long_value" "$value" "Very long value handling"

  # Test Unicode characters
  util_config_set_value "unicode.test" "测试值 🚀 ñoño" "edge_test"
  value=$(util_config_get_value "unicode.test" "" "edge_test")
  assert_equals "测试值 🚀 ñoño" "$value" "Unicode value handling"
}

# Test: Configuration namespace isolation
test_config_namespace_isolation() {
  log_info "Testing configuration namespace isolation..."

  # Set same key in different namespaces
  util_config_set_value "test.key" "namespace1_value" "ns1"
  util_config_set_value "test.key" "namespace2_value" "ns2"

  # Verify isolation
  local value1
  value1=$(util_config_get_value "test.key" "" "ns1")
  assert_equals "namespace1_value" "$value1" "Namespace 1 isolation"

  local value2
  value2=$(util_config_get_value "test.key" "" "ns2")
  assert_equals "namespace2_value" "$value2" "Namespace 2 isolation"
}

# Test: Configuration with yq vs basic parser
test_config_parser_comparison() {
  log_info "Testing yq vs basic parser comparison..."

  # Test with yq mock
  assert_success util_config_parse_yaml "$TEST_CONFIG_FILE" "yq_test"

  # Remove yq mock to test basic parser
  cleanup_mocks
  create_mock_command "yq" "exit 1" # Make yq fail

  assert_success util_config_parse_yaml "$TEST_CONFIG_FILE" "basic_test"

  # Both should parse basic values successfully
  local yq_value
  yq_value=$(util_config_get_value "enabled" "" "yq_test")
  local basic_value
  basic_value=$(util_config_get_value "enabled" "" "basic_test")

  # Both parsers should handle basic values
  assert_not_empty "$yq_value" "yq parser result"
  assert_not_empty "$basic_value" "basic parser result"
}

# Main test execution
main() {
  log_info "Starting Config Utils comprehensive tests..."

  # Initialize test framework
  init_test_framework

  # Set up test environment
  setup_config_utils_tests

  # Run all tests
  run_test test_config_parse_yaml_basic
  run_test test_config_parse_yaml_nested
  run_test test_config_parse_yaml_arrays
  run_test test_config_parse_yaml_complex
  run_test test_config_parse_yaml_errors
  run_test test_config_get_cached
  run_test test_config_get_value_basic
  run_test test_config_get_value_defaults
  run_test test_config_get_value_dot_notation
  run_test test_config_get_array
  run_test test_config_get_array_empty
  run_test test_config_set_value_basic
  run_test test_config_set_value_special_chars
  run_test test_config_set_value_overwrite
  run_test test_config_validate_values
  run_test test_config_validate_values_failures
  run_test test_config_validate_values_enum
  run_test test_config_validate_values_range
  run_test test_config_load_env_overrides
  run_test test_config_create_default
  run_test test_config_create_default_mkdir
  run_test test_config_performance_large
  run_test test_config_edge_cases
  run_test test_config_namespace_isolation
  run_test test_config_parser_comparison

  # Clean up
  cleanup_config_utils_tests

  # Print results
  print_test_results

  log_info "Config Utils tests completed!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
