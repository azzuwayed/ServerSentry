#!/bin/bash
#
# Integration Test: Refactored Core Modules
#
# This test verifies that the refactored core modules work correctly
# with the new standardized function names and utility integrations

set -eo pipefail

# Test setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(dirname "$(dirname "$TEST_DIR")")"
TEST_LOG_FILE="/tmp/serversentry_test.log"
TEST_CONFIG_FILE="/tmp/serversentry_test_config.yaml"
TEST_PLUGIN_DIR="/tmp/serversentry_test_plugins"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test framework functions
test_log() {
  echo -e "${GREEN}[TEST]${NC} $1"
}

test_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

test_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  ((TESTS_RUN++))

  if [[ "$expected" == "$actual" ]]; then
    ((TESTS_PASSED++))
    test_log "✓ $test_name"
    return 0
  else
    ((TESTS_FAILED++))
    test_error "✗ $test_name"
    test_error "  Expected: '$expected'"
    test_error "  Actual: '$actual'"
    return 1
  fi
}

assert_success() {
  local command="$1"
  local test_name="$2"

  ((TESTS_RUN++))

  local output
  local exit_code
  output=$(eval "$command" 2>&1)
  exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    ((TESTS_PASSED++))
    test_log "✓ $test_name"
    return 0
  else
    ((TESTS_FAILED++))
    test_error "✗ $test_name"
    test_error "  Command failed: $command"
    test_error "  Exit code: $exit_code"
    test_error "  Output: $output"
    return 1
  fi
}

assert_function_exists() {
  local func_name="$1"
  local test_name="$2"

  ((TESTS_RUN++))

  if declare -f "$func_name" >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    test_log "✓ $test_name"
    return 0
  else
    ((TESTS_FAILED++))
    test_error "✗ $test_name"
    test_error "  Function '$func_name' does not exist"
    return 1
  fi
}

# Setup test environment
setup_test_environment() {
  test_log "Setting up test environment..."

  # Set test environment variables BEFORE creating any files
  export BASE_DIR="$BASE_DIR"
  export LOG_FILE="$TEST_LOG_FILE"
  export CONFIG_DIR="$(dirname "$TEST_CONFIG_FILE")"
  export MAIN_CONFIG="$TEST_CONFIG_FILE"
  export PLUGIN_DIR="$TEST_PLUGIN_DIR"

  # Create test config
  cat >"$TEST_CONFIG_FILE" <<EOF
# Test Configuration
enabled: true
log_level: debug
check_interval: 30
plugins_enabled: []
notification_enabled: false
max_log_size: 1048576
max_log_archives: 5
EOF

  # Create test plugin directory and plugin
  mkdir -p "$TEST_PLUGIN_DIR/test_plugin"
  cat >"$TEST_PLUGIN_DIR/test_plugin/test_plugin.sh" <<'EOF'
#!/bin/bash

test_plugin_plugin_info() {
    echo "Test Plugin for Integration Testing"
}

test_plugin_plugin_configure() {
    local config_file="$1"
    # Simple configuration logic
    return 0
}

test_plugin_plugin_check() {
    local result='{"status_code": 0, "status_message": "OK", "metrics": {"test_value": 42}}'
    echo "$result"
    return 0
}
EOF

  chmod 755 "$TEST_PLUGIN_DIR/test_plugin/test_plugin.sh"

  test_log "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
  test_log "Cleaning up test environment..."

  rm -f "$TEST_LOG_FILE" "$TEST_CONFIG_FILE"
  rm -rf "$TEST_PLUGIN_DIR"

  # Clear test environment variables
  unset LOG_FILE CONFIG_DIR MAIN_CONFIG PLUGIN_DIR

  test_log "Test environment cleanup complete"
}

# Test utility functions
test_utilities() {
  test_log "Testing utility functions..."

  # Set BASE_DIR before sourcing utilities
  export BASE_DIR="$BASE_DIR"

  # Source utilities
  source "$BASE_DIR/lib/core/utils.sh"

  # Test validation utilities
  assert_function_exists "util_require_param" "util_require_param function exists"
  assert_function_exists "util_validate_numeric" "util_validate_numeric function exists"
  assert_function_exists "util_validate_boolean" "util_validate_boolean function exists"

  # Test JSON utilities
  assert_function_exists "util_json_set_value" "util_json_set_value function exists"
  assert_function_exists "util_json_get_value" "util_json_get_value function exists"
  assert_function_exists "util_json_validate" "util_json_validate function exists"

  # Test array utilities
  assert_function_exists "util_array_contains" "util_array_contains function exists"
  assert_function_exists "util_array_add_unique" "util_array_add_unique function exists"

  # Test config utilities
  assert_function_exists "util_config_parse_yaml" "util_config_parse_yaml function exists"
  assert_function_exists "util_config_get_cached" "util_config_get_cached function exists"

  # Test actual utility functionality with proper JSON path syntax
  local test_json='{"test": "value", "number": 42}'
  local extracted_value
  extracted_value=$(util_json_get_value "$test_json" ".test")
  assert_equals "value" "$extracted_value" "JSON value extraction works"

  local extracted_number
  extracted_number=$(util_json_get_value "$test_json" ".number")
  assert_equals "42" "$extracted_number" "JSON number extraction works"
}

# Test logging system
test_logging_system() {
  test_log "Testing logging system..."

  # Source logging
  source "$BASE_DIR/lib/core/logging.sh"

  # Test new standardized functions exist
  assert_function_exists "logging_init" "logging_init function exists"
  assert_function_exists "logging_set_level" "logging_set_level function exists"
  assert_function_exists "logging_get_level" "logging_get_level function exists"
  assert_function_exists "logging_rotate" "logging_rotate function exists"

  # Test backward compatibility functions exist
  assert_function_exists "init_logging" "init_logging backward compatibility exists"
  assert_function_exists "rotate_logs" "rotate_logs backward compatibility exists"

  # Test logging initialization
  assert_success "logging_init" "Logging system initialization"

  # Test log level setting
  if logging_set_level debug; then
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    test_log "✓ Set log level to debug"
  else
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    test_error "✗ Set log level to debug"
  fi

  # Debug the log level issue
  test_log "Debug: CURRENT_LOG_LEVEL after set: $CURRENT_LOG_LEVEL"
  test_log "Debug: logging_get_level after set: $(logging_get_level)"

  local current_level
  current_level=$(logging_get_level)
  test_log "Debug: current_level variable: '$current_level'"
  assert_equals "debug" "$current_level" "Log level setting verification"

  # Test basic logging functions
  assert_success "log_info 'Test info message'" "Log info message"
  assert_success "log_debug 'Test debug message'" "Log debug message"
  assert_success "log_warning 'Test warning message'" "Log warning message"
}

# Test configuration system
test_configuration_system() {
  test_log "Testing configuration system..."

  # Source configuration (this will also source utilities)
  source "$BASE_DIR/lib/core/config.sh"

  # Test new standardized functions exist
  assert_function_exists "config_init" "config_init function exists"
  assert_function_exists "config_load" "config_load function exists"
  assert_function_exists "config_get_value" "config_get_value function exists"
  assert_function_exists "config_set_value" "config_set_value function exists"
  assert_function_exists "config_validate" "config_validate function exists"

  # Test backward compatibility functions exist
  assert_function_exists "init_config" "init_config backward compatibility exists"
  assert_function_exists "load_config" "load_config backward compatibility exists"
  assert_function_exists "get_config" "get_config backward compatibility exists"

  # Clear any existing configuration cache
  unset CONFIG_CACHE CONFIG_TIMESTAMPS 2>/dev/null || true
  declare -g -A CONFIG_CACHE 2>/dev/null || true
  declare -g -A CONFIG_TIMESTAMPS 2>/dev/null || true

  # Test configuration initialization
  assert_success "config_init" "Configuration system initialization"

  # Test configuration loading
  if config_load; then
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    test_log "✓ Configuration loading"
  else
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    test_error "✗ Configuration loading"
  fi

  # Debug: Show what config file is being used
  test_log "Debug: Using config file: $MAIN_CONFIG"
  test_log "Debug: Config file exists: $([ -f "$MAIN_CONFIG" ] && echo "yes" || echo "no")"
  if [ -f "$MAIN_CONFIG" ]; then
    test_log "Debug: Config file contents:"
    cat "$MAIN_CONFIG" | head -10
  fi

  # Test configuration value retrieval
  test_log "Debug: config_enabled variable: '${config_enabled:-unset}'"
  test_log "Debug: Available config vars: $(set | grep '^config_' | head -3)"
  local enabled_value
  enabled_value=$(config_get_value "enabled" "false")
  test_log "Debug: enabled_value retrieved: '$enabled_value'"
  assert_equals "true" "$enabled_value" "Configuration value retrieval"

  local log_level_value
  log_level_value=$(config_get_value "log_level" "info")
  test_log "Debug: Retrieved log_level value: '$log_level_value'"
  assert_equals "debug" "$log_level_value" "Configuration log level retrieval"

  # Test configuration validation
  assert_success "config_validate" "Configuration validation"
}

# Test plugin system
test_plugin_system() {
  test_log "Testing plugin system..."

  # Source plugin system
  source "$BASE_DIR/lib/core/plugin.sh"

  # Test new standardized functions exist
  assert_function_exists "plugin_system_init" "plugin_system_init function exists"
  assert_function_exists "plugin_load" "plugin_load function exists"
  assert_function_exists "plugin_validate_interface" "plugin_validate_interface function exists"
  assert_function_exists "plugin_register" "plugin_register function exists"
  assert_function_exists "plugin_run_check" "plugin_run_check function exists"
  assert_function_exists "plugin_is_loaded" "plugin_is_loaded function exists"
  assert_function_exists "plugin_list_loaded" "plugin_list_loaded function exists"

  # Test backward compatibility functions exist
  assert_function_exists "init_plugin_system" "init_plugin_system backward compatibility exists"
  assert_function_exists "load_plugin" "load_plugin backward compatibility exists"
  assert_function_exists "run_plugin_check" "run_plugin_check backward compatibility exists"

  # Test plugin system initialization
  test_log "Debug: Available functions before plugin_system_init:"
  declare -F | grep plugin || test_log "Debug: No plugin functions before init"

  if plugin_system_init; then
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    test_log "✓ Plugin system initialization"

    test_log "Debug: Available functions after plugin_system_init:"
    declare -F | grep test_plugin || test_log "Debug: No test_plugin functions after init"
  else
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    test_error "✗ Plugin system initialization"
  fi

  # Test plugin loading
  test_log "Debug: About to test plugin loading"
  if plugin_load test_plugin; then
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    test_log "✓ Plugin loading"

    # Check if plugin functions are now available
    test_log "Debug: Checking functions after plugin_load"
    declare -F | grep test_plugin || test_log "Debug: No test_plugin functions found"
  else
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    test_error "✗ Plugin loading"
  fi

  # Test plugin status checking
  assert_success "plugin_is_loaded test_plugin" "Plugin loaded status check"

  # Test plugin check execution
  test_log "Debug: Testing plugin function availability"
  if declare -f test_plugin_plugin_check >/dev/null 2>&1; then
    test_log "Debug: test_plugin_plugin_check function is available"
  else
    test_log "Debug: test_plugin_plugin_check function is NOT available"
  fi

  local check_result
  check_result=$(plugin_run_check test_plugin false)
  test_log "Debug: Plugin check result: '$check_result'"

  local status_code
  if command -v jq >/dev/null 2>&1; then
    status_code=$(echo "$check_result" | jq -r '.status_code' 2>/dev/null || echo "error")
  else
    # Fallback method to extract status_code from JSON without jq
    status_code=$(echo "$check_result" | sed -n 's/.*"status_code"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
    if [[ -z "$status_code" ]]; then
      status_code="error"
    fi
  fi
  test_log "Debug: Extracted status code: '$status_code'"
  assert_equals "0" "$status_code" "Plugin check execution"

  # Test plugin listing
  local plugin_list
  plugin_list=$(plugin_list_loaded)
  assert_success "[[ '$plugin_list' == *'test_plugin'* ]]" "Plugin listing contains test plugin"
}

# Test integration between modules
test_module_integration() {
  test_log "Testing module integration..."

  # Test that config values are accessible from plugin system
  local enabled_from_plugin
  enabled_from_plugin=$(config_get_value "enabled" "false")
  assert_equals "true" "$enabled_from_plugin" "Config accessible from plugin context"

  # Test that logging works from all modules
  assert_success "log_info 'Integration test message'" "Logging works in integration context"

  # Test that plugins can use utilities
  local json_test='{"integration": "test"}'
  local integration_value
  integration_value=$(util_json_get_value "$json_test" ".integration")
  assert_equals "test" "$integration_value" "Utilities accessible from plugin context"
}

# Test backward compatibility
test_backward_compatibility() {
  test_log "Testing backward compatibility..."

  # Test that old function names still work (they should show deprecation warnings)
  assert_success "init_config >/dev/null 2>&1" "Backward compatibility: init_config"
  assert_success "load_config >/dev/null 2>&1" "Backward compatibility: load_config"
  assert_success "init_plugin_system >/dev/null 2>&1" "Backward compatibility: init_plugin_system"
  assert_success "init_logging >/dev/null 2>&1" "Backward compatibility: init_logging"

  # Test that old function results are the same as new functions
  local old_config_value
  old_config_value=$(get_config "enabled" "false" 2>/dev/null)
  local new_config_value
  new_config_value=$(config_get_value "enabled" "false")
  assert_equals "$old_config_value" "$new_config_value" "Backward compatibility: config value consistency"
}

# Run all tests
run_all_tests() {
  test_log "Starting ServerSentry v2 Refactoring Integration Tests"
  echo "=================================================="

  setup_test_environment

  test_utilities
  echo ""

  test_logging_system
  echo ""

  test_configuration_system
  echo ""

  test_plugin_system
  echo ""

  test_module_integration
  echo ""

  test_backward_compatibility
  echo ""

  cleanup_test_environment

  # Print test summary
  echo "=================================================="
  test_log "Test Summary:"
  echo "  Tests Run: $TESTS_RUN"
  echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    echo "The refactoring was successful and maintains backward compatibility."
    return 0
  else
    echo -e "\n${RED}❌ Some tests failed!${NC}"
    echo "Please review the failed tests and fix the issues."
    return 1
  fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_all_tests
fi
