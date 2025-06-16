#!/usr/bin/env bash
#
# ServerSentry v2 - Teams Notification Provider Comprehensive Unit Tests
#
# Tests all Teams notification provider functions with extensive edge case coverage

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

# Source test framework first
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "$SERVERSENTRY_ROOT/lib/core/logging.sh"
source "$SERVERSENTRY_ROOT/lib/core/utils.sh"
source "$SERVERSENTRY_ROOT/lib/core/config.sh"

# Source the module under test
source "$SERVERSENTRY_ROOT/lib/notifications/teams/teams.sh"

# Test configuration
TEST_SUITE_NAME="Teams Notification Provider Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===



# === MOCK DATA GENERATORS ===

generate_valid_teams_response() {
  echo "1"
}

generate_error_teams_response() {
  echo "Invalid webhook URL"
}

generate_test_webhook_url() {
  echo "https://outlook.office.com/webhook/test-webhook-url"
}

generate_invalid_webhook_url() {
  echo "not-a-valid-webhook-url"
}

generate_test_json_metrics() {
  echo '{"cpu_usage": 85.5, "memory_usage": 70.2, "disk_usage": 45.8}'
}

generate_test_alert_data() {
  local status_code="${1:-2}"
  local status_message="${2:-High CPU usage detected}"
  local plugin_name="${3:-cpu}"
  local metrics="${4:-$(generate_test_json_metrics)}"

  echo "$status_code" "$status_message" "$plugin_name" "$metrics"
}

# === SETUP AND TEARDOWN ===

setup_teams_test() {
  setup_test_environment "teams_notification_test"

  # Reset Teams provider variables to defaults
  teams_webhook_url=""
  teams_notification_title="ServerSentry Alert"
  teams_enabled=false
  teams_timeout=30

  # Clean up any existing mocks
  cleanup_mocks
}

teardown_teams_test() {
  cleanup_test_environment
}

# === CORE FUNCTION TESTS ===

# Test 1: Provider info function
test_teams_provider_info() {
  setup_teams_test

  local info_output
  info_output=$(teams_provider_info)

  if assert_contains "$info_output" "Microsoft Teams" "Provider info should contain 'Microsoft Teams'" &&
    assert_contains "$info_output" "$TEAMS_PROVIDER_VERSION" "Provider info should contain version"; then
    test_pass "teams_provider_info returns correct information"
  else
    test_fail "teams_provider_info output: $info_output"
  fi

  teardown_teams_test
}

# Test 2: Provider configuration with valid webhook URL
test_teams_provider_configure_valid() {
  setup_teams_test

  # Create valid configuration
  local temp_config="$TEST_TEMP_DIR/teams_valid.conf"
  create_test_config "$temp_config" \
    "teams_webhook_url=\"$(generate_test_webhook_url)\"" \
    "teams_notification_title=\"Test Alert\"" \
    "teams_enabled=true" \
    "teams_timeout=45"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.teams.webhook_url") echo "$(generate_test_webhook_url)" ;;
    "notifications.teams.notification_title") echo "Test Alert" ;;
    "notifications.teams.enabled") echo "true" ;;
    "notifications.teams.timeout") echo "45" ;;
    *) echo "$2" ;;
  esac'

  if teams_provider_configure "$temp_config"; then
    if assert_equals "$(generate_test_webhook_url)" "$teams_webhook_url" "Webhook URL should be set" &&
      assert_equals "Test Alert" "$teams_notification_title" "Title should be set" &&
      assert_equals "true" "$teams_enabled" "Should be enabled" &&
      assert_equals "45" "$teams_timeout" "Timeout should be set"; then
      test_pass "teams_provider_configure loads valid configuration"
    else
      test_fail "Configuration not loaded correctly"
    fi
  else
    test_fail "teams_provider_configure failed with valid config"
  fi

  teardown_teams_test
}

# Test 3: Provider configuration with missing webhook URL
test_teams_provider_configure_missing_webhook() {
  setup_teams_test

  # Create configuration without webhook URL
  local temp_config="$TEST_TEMP_DIR/teams_missing_webhook.conf"
  create_test_config "$temp_config" \
    "teams_notification_title=\"Test Alert\"" \
    "teams_enabled=true"

  # Mock config_get_value function to return empty webhook
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.teams.webhook_url") echo "" ;;
    "notifications.teams.notification_title") echo "Test Alert" ;;
    "notifications.teams.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! teams_provider_configure "$temp_config"; then
    test_pass "teams_provider_configure correctly fails with missing webhook URL"
  else
    test_fail "teams_provider_configure should fail with missing webhook URL"
  fi

  teardown_teams_test
}

# Test 4: Provider configuration with invalid webhook URL
test_teams_provider_configure_invalid_webhook() {
  setup_teams_test

  # Create configuration with invalid webhook URL
  local temp_config="$TEST_TEMP_DIR/teams_invalid_webhook.conf"
  create_test_config "$temp_config" \
    "teams_webhook_url=\"$(generate_invalid_webhook_url)\"" \
    "teams_enabled=true"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.teams.webhook_url") echo "$(generate_invalid_webhook_url)" ;;
    "notifications.teams.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! teams_provider_configure "$temp_config"; then
    test_pass "teams_provider_configure correctly fails with invalid webhook URL"
  else
    test_fail "teams_provider_configure should fail with invalid webhook URL"
  fi

  teardown_teams_test
}

# Test 5: Successful notification sending
test_teams_provider_send_success() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Mock jq if available
  if command -v jq >/dev/null 2>&1; then
    create_mock_command "jq" "cpu_usage" 0
  fi

  local test_data
  test_data=($(generate_test_alert_data))

  if teams_provider_send "${test_data[@]}"; then
    test_pass "teams_provider_send succeeds with valid configuration and response"
  else
    test_fail "teams_provider_send should succeed with valid configuration"
  fi

  teardown_teams_test
}

# Test 6: Failed notification sending due to curl error
test_teams_provider_send_curl_failure() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock failed curl response
  create_mock_command "curl" "Connection failed" 1

  local test_data
  test_data=($(generate_test_alert_data))

  if ! teams_provider_send "${test_data[@]}"; then
    test_pass "teams_provider_send correctly fails when curl fails"
  else
    test_fail "teams_provider_send should fail when curl fails"
  fi

  teardown_teams_test
}

# Test 7: Failed notification sending due to Teams API error
test_teams_provider_send_api_error() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock Teams API error response
  create_mock_command "curl" "$(generate_error_teams_response)" 0

  local test_data
  test_data=($(generate_test_alert_data))

  if ! teams_provider_send "${test_data[@]}"; then
    test_pass "teams_provider_send correctly fails with Teams API error"
  else
    test_fail "teams_provider_send should fail with Teams API error"
  fi

  teardown_teams_test
}

# Test 8: Notification sending without curl command
test_teams_provider_send_no_curl() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock util_command_exists to return false for curl
  create_mock_function "util_command_exists" '[[ "$1" != "curl" ]]'

  local test_data
  test_data=($(generate_test_alert_data))

  if ! teams_provider_send "${test_data[@]}"; then
    test_pass "teams_provider_send correctly fails when curl is not available"
  else
    test_fail "teams_provider_send should fail when curl is not available"
  fi

  teardown_teams_test
}

# Test 9: Notification with different status codes
test_teams_provider_send_different_statuses() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  local status_codes=("0" "1" "2" "3")
  local status_messages=("OK" "WARNING" "CRITICAL" "UNKNOWN")

  for i in "${!status_codes[@]}"; do
    local status_code="${status_codes[$i]}"
    local status_message="${status_messages[$i]}"

    if teams_provider_send "$status_code" "$status_message" "test" '{}'; then
      test_pass "teams_provider_send handles status code $status_code correctly"
    else
      test_fail "teams_provider_send failed with status code $status_code"
    fi
  done

  teardown_teams_test
}

# Test 10: Notification with complex JSON metrics
test_teams_provider_send_complex_metrics() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Mock jq for JSON processing
  create_mock_command "jq" "." 0

  local complex_metrics='{"cpu": {"usage": 85.5, "cores": 4}, "memory": {"used": 8.5, "total": 16}, "disk": [{"path": "/", "usage": 45.8}]}'

  if teams_provider_send "2" "System alert" "system" "$complex_metrics"; then
    test_pass "teams_provider_send handles complex JSON metrics"
  else
    test_fail "teams_provider_send failed with complex JSON metrics"
  fi

  teardown_teams_test
}

# Test 11: Notification with invalid JSON metrics
test_teams_provider_send_invalid_json() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Mock jq to fail on invalid JSON
  create_mock_command "jq" "" 1

  local invalid_json='{"invalid": json}'

  if teams_provider_send "2" "System alert" "system" "$invalid_json"; then
    test_pass "teams_provider_send handles invalid JSON gracefully"
  else
    test_fail "teams_provider_send should handle invalid JSON gracefully"
  fi

  teardown_teams_test
}

# Test 12: Notification with empty metrics
test_teams_provider_send_empty_metrics() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  if teams_provider_send "1" "Warning message" "test" ""; then
    test_pass "teams_provider_send handles empty metrics"
  else
    test_fail "teams_provider_send failed with empty metrics"
  fi

  teardown_teams_test
}

# Test 13: Provider test function
test_teams_provider_test() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  if teams_provider_test; then
    test_pass "teams_provider_test succeeds with valid configuration"
  else
    test_fail "teams_provider_test should succeed with valid configuration"
  fi

  teardown_teams_test
}

# Test 14: Provider validation with valid configuration
test_teams_provider_validate_valid() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true
  teams_timeout=30

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if teams_provider_validate; then
    test_pass "teams_provider_validate passes with valid configuration"
  else
    test_fail "teams_provider_validate should pass with valid configuration"
  fi

  teardown_teams_test
}

# Test 15: Provider validation with missing curl
test_teams_provider_validate_no_curl() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock util_command_exists to return false for curl
  create_mock_function "util_command_exists" '[[ "$1" != "curl" ]]'

  if ! teams_provider_validate; then
    test_pass "teams_provider_validate correctly fails when curl is missing"
  else
    test_fail "teams_provider_validate should fail when curl is missing"
  fi

  teardown_teams_test
}

# Test 16: Provider validation with invalid webhook URL
test_teams_provider_validate_invalid_webhook() {
  setup_teams_test

  # Configure Teams provider with invalid webhook
  teams_webhook_url="$(generate_invalid_webhook_url)"
  teams_enabled=true

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if ! teams_provider_validate; then
    test_pass "teams_provider_validate correctly fails with invalid webhook URL"
  else
    test_fail "teams_provider_validate should fail with invalid webhook URL"
  fi

  teardown_teams_test
}

# Test 17: Provider validation with disabled provider
test_teams_provider_validate_disabled() {
  setup_teams_test

  # Configure Teams provider as disabled
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=false

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if teams_provider_validate; then
    test_pass "teams_provider_validate passes even when provider is disabled"
  else
    test_fail "teams_provider_validate should pass even when provider is disabled"
  fi

  teardown_teams_test
}

# Test 18: Provider status function
test_teams_provider_status() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true
  teams_timeout=30

  # Mock util_command_exists
  create_mock_function "util_command_exists" '[[ "$1" == "curl" || "$1" == "jq" ]]'

  local status_output
  status_output=$(teams_provider_status)

  if assert_contains "$status_output" "Teams Provider Status" "Status should contain header" &&
    assert_contains "$status_output" "$TEAMS_PROVIDER_VERSION" "Status should contain version" &&
    assert_contains "$status_output" "Enabled: true" "Status should show enabled state" &&
    assert_contains "$status_output" "curl available: yes" "Status should show curl availability"; then
    test_pass "teams_provider_status returns correct status information"
  else
    test_fail "teams_provider_status output: $status_output"
  fi

  teardown_teams_test
}

# Test 19: Timeout configuration
test_teams_provider_timeout_configuration() {
  setup_teams_test

  # Test different timeout values
  local timeout_values=("10" "30" "60" "120")

  for timeout_val in "${timeout_values[@]}"; do
    # Configure Teams provider with specific timeout
    teams_webhook_url="$(generate_test_webhook_url)"
    teams_enabled=true
    teams_timeout="$timeout_val"

    # Mock successful curl response
    create_mock_command "curl" "$(generate_valid_teams_response)" 0

    local test_data
    test_data=($(generate_test_alert_data))

    if teams_provider_send "${test_data[@]}"; then
      test_pass "teams_provider_send works with timeout ${timeout_val}s"
    else
      test_fail "teams_provider_send failed with timeout ${timeout_val}s"
    fi
  done

  teardown_teams_test
}

# Test 20: Edge case - Very long message
test_teams_provider_send_long_message() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Create very long message
  local long_message=""
  for i in {1..100}; do
    long_message+="This is a very long message segment $i. "
  done

  if teams_provider_send "2" "$long_message" "test" '{}'; then
    test_pass "teams_provider_send handles very long messages"
  else
    test_fail "teams_provider_send failed with very long message"
  fi

  teardown_teams_test
}

# Test 21: Edge case - Special characters in message
test_teams_provider_send_special_characters() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Create message with special characters
  local special_message="Alert: CPU usage > 85% on server \"production-01\" at 12:34:56! Status: ⚠️"

  if teams_provider_send "2" "$special_message" "test" '{}'; then
    test_pass "teams_provider_send handles special characters"
  else
    test_fail "teams_provider_send failed with special characters"
  fi

  teardown_teams_test
}

# Test 22: Edge case - Unicode characters
test_teams_provider_send_unicode_characters() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  # Create message with Unicode characters
  local unicode_message="系统警告: CPU使用率过高 🚨 Тревога: высокая загрузка ЦП"

  if teams_provider_send "2" "$unicode_message" "test" '{}'; then
    test_pass "teams_provider_send handles Unicode characters"
  else
    test_fail "teams_provider_send failed with Unicode characters"
  fi

  teardown_teams_test
}

# Test 23: Configuration file loading precedence
test_teams_provider_configure_precedence() {
  setup_teams_test

  # Create configuration file
  local temp_config="$TEST_TEMP_DIR/teams_precedence.conf"
  create_test_config "$temp_config" \
    "teams_webhook_url=\"file://config-from-file\"" \
    "teams_notification_title=\"File Title\""

  # Mock config_get_value to return different values
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.teams.webhook_url") echo "config://config-from-global" ;;
    "notifications.teams.notification_title") echo "Global Title" ;;
    *) echo "$2" ;;
  esac'

  if teams_provider_configure "$temp_config"; then
    # Global config should take precedence over file config
    if assert_equals "config://config-from-global" "$teams_webhook_url" "Global config should take precedence"; then
      test_pass "teams_provider_configure respects configuration precedence"
    else
      test_fail "Configuration precedence not working correctly"
    fi
  else
    test_fail "teams_provider_configure failed with precedence test"
  fi

  teardown_teams_test
}

# Test 24: Performance test - Multiple rapid sends
test_teams_provider_send_performance() {
  setup_teams_test

  # Configure Teams provider
  teams_webhook_url="$(generate_test_webhook_url)"
  teams_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_teams_response)" 0

  local send_count=10
  local successful_sends=0

  measure_execution_time teams_multiple_sends "$send_count"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if assert_execution_time_under "5" "Multiple sends should complete within 5 seconds"; then
      test_pass "teams_provider_send performance test passed"
    else
      test_fail "teams_provider_send performance test failed: took ${MEASURED_TIME}s"
    fi
  else
    test_fail "teams_provider_send performance test failed with exit code $exit_code"
  fi

  teardown_teams_test
}

# Helper function for performance test
teams_multiple_sends() {
  local count="$1"
  for ((i = 1; i <= count; i++)); do
    teams_provider_send "1" "Test message $i" "test" '{}' || return 1
  done
  return 0
}

# === INTEGRATION TESTS ===

# Test 25: Integration with actual webhook server
test_teams_provider_integration() {
  setup_teams_test

  # Start test webhook server
  local test_port=8080
  if start_test_webhook_server "$test_port" "1"; then
    # Configure Teams provider to use test server
    teams_webhook_url="http://localhost:$test_port/webhook"
    teams_enabled=true

    # Clear webhook requests log
    clear_webhook_requests

    # Send notification
    if teams_provider_send "2" "Integration test message" "test" '{"test": true}'; then
      # Check if webhook received the request
      local webhook_requests
      webhook_requests=$(get_webhook_requests)

      if assert_contains "$webhook_requests" "Integration test message" "Webhook should receive the message"; then
        test_pass "teams_provider_send integration test passed"
      else
        test_fail "Webhook did not receive expected content: $webhook_requests"
      fi
    else
      test_fail "teams_provider_send failed in integration test"
    fi

    # Stop test webhook server
    stop_test_webhook_server
  else
    test_fail "Could not start test webhook server for integration test"
  fi

  teardown_teams_test
}

# === MAIN TEST EXECUTION ===

run_teams_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  # Core functionality tests
  test_teams_provider_info
  test_teams_provider_configure_valid
  test_teams_provider_configure_missing_webhook
  test_teams_provider_configure_invalid_webhook

  # Notification sending tests
  test_teams_provider_send_success
  test_teams_provider_send_curl_failure
  test_teams_provider_send_api_error
  test_teams_provider_send_no_curl
  test_teams_provider_send_different_statuses
  test_teams_provider_send_complex_metrics
  test_teams_provider_send_invalid_json
  test_teams_provider_send_empty_metrics

  # Provider utility tests
  test_teams_provider_test
  test_teams_provider_validate_valid
  test_teams_provider_validate_no_curl
  test_teams_provider_validate_invalid_webhook
  test_teams_provider_validate_disabled
  test_teams_provider_status

  # Configuration and edge case tests
  test_teams_provider_timeout_configuration
  test_teams_provider_send_long_message
  test_teams_provider_send_special_characters
  test_teams_provider_send_unicode_characters
  test_teams_provider_configure_precedence

  # Performance tests
  test_teams_provider_send_performance

  # Integration tests
  test_teams_provider_integration

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_teams_tests
  exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
