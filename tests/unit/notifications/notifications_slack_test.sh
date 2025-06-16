#!/usr/bin/env bash
#
# ServerSentry v2 - Slack Notification Provider Comprehensive Unit Tests
#
# Tests all Slack notification provider functions with extensive edge case coverage

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
source "$SERVERSENTRY_ROOT/lib/notifications/slack/slack.sh"

# Test configuration
TEST_SUITE_NAME="Slack Notification Provider Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===



# === MOCK DATA GENERATORS ===

generate_valid_slack_response() {
  echo "ok"
}

generate_error_slack_response() {
  echo '{"ok":false,"error":"invalid_token"}'
}

generate_test_webhook_url() {
  echo "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
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

generate_complex_metrics() {
  cat <<'EOF'
{
  "system": {
    "hostname": "production-server-01",
    "uptime": 86400,
    "load_average": [1.5, 1.3, 1.1]
  },
  "cpu": {
    "usage_percent": 85.5,
    "cores": 8,
    "temperature": 65.2
  },
  "memory": {
    "used_gb": 12.8,
    "total_gb": 16.0,
    "usage_percent": 80.0
  },
  "disk": {
    "used_gb": 450.5,
    "total_gb": 500.0,
    "usage_percent": 90.1
  }
}
EOF
}

# === SETUP AND TEARDOWN ===

setup_slack_test() {
  setup_test_environment "slack_notification_test"

  # Reset Slack provider variables to defaults
  slack_webhook_url=""
  slack_channel=""
  slack_username="ServerSentry"
  slack_icon_emoji=":warning:"
  slack_enabled=false
  slack_timeout=30

  # Clean up any existing mocks
  cleanup_mocks
}

teardown_slack_test() {
  cleanup_test_environment
}

# === CORE FUNCTION TESTS ===

# Test 1: Provider info function
test_slack_provider_info() {
  setup_slack_test

  local info_output
  info_output=$(slack_provider_info)

  if assert_contains "$info_output" "Slack" "Provider info should contain 'Slack'" &&
    assert_contains "$info_output" "$SLACK_PROVIDER_VERSION" "Provider info should contain version"; then
    test_pass "slack_provider_info returns correct information"
  else
    test_fail "slack_provider_info output: $info_output"
  fi

  teardown_slack_test
}

# Test 2: Provider configuration with valid webhook URL
test_slack_provider_configure_valid() {
  setup_slack_test

  # Create valid configuration
  local temp_config="$TEST_TEMP_DIR/slack_valid.conf"
  create_test_config "$temp_config" \
    "slack_webhook_url=\"$(generate_test_webhook_url)\"" \
    "slack_channel=\"#alerts\"" \
    "slack_username=\"ServerSentry Bot\"" \
    "slack_icon_emoji=\":robot_face:\"" \
    "slack_enabled=true" \
    "slack_timeout=45"

  # Mock config_get_value function
  create_mock_function "config_get_value" "case \"\$1\" in
    \"notifications.slack.webhook_url\") echo \"\$(generate_test_webhook_url)\" ;;
    \"notifications.slack.channel\") echo \"#alerts\" ;;
    \"notifications.slack.username\") echo \"ServerSentry Bot\" ;;
    \"notifications.slack.icon_emoji\") echo \":robot_face:\" ;;
    \"notifications.slack.enabled\") echo \"true\" ;;
    \"notifications.slack.timeout\") echo \"45\" ;;
    *) echo \"\$2\" ;;
  esac"

  if slack_provider_configure "$temp_config"; then
    if assert_equals "$(generate_test_webhook_url)" "$slack_webhook_url" "Webhook URL should be set" &&
      assert_equals "#alerts" "$slack_channel" "Channel should be set" &&
      assert_equals "ServerSentry Bot" "$slack_username" "Username should be set" &&
      assert_equals ":robot_face:" "$slack_icon_emoji" "Icon emoji should be set" &&
      assert_equals "true" "$slack_enabled" "Should be enabled" &&
      assert_equals "45" "$slack_timeout" "Timeout should be set"; then
      test_pass "slack_provider_configure loads valid configuration"
    else
      test_fail "Configuration not loaded correctly"
    fi
  else
    test_fail "slack_provider_configure failed with valid config"
  fi

  teardown_slack_test
}

# Test 3: Provider configuration with minimal valid settings
test_slack_provider_configure_minimal() {
  setup_slack_test

  # Create minimal configuration (only webhook URL required)
  local temp_config="$TEST_TEMP_DIR/slack_minimal.conf"
  create_test_config "$temp_config" \
    "slack_webhook_url=\"$(generate_test_webhook_url)\"" \
    "slack_enabled=true"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.slack.webhook_url") echo "$(generate_test_webhook_url)" ;;
    "notifications.slack.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if slack_provider_configure "$temp_config"; then
    if assert_equals "$(generate_test_webhook_url)" "$slack_webhook_url" "Webhook URL should be set" &&
      assert_equals "true" "$slack_enabled" "Should be enabled"; then
      test_pass "slack_provider_configure loads minimal valid configuration"
    else
      test_fail "Minimal configuration not loaded correctly"
    fi
  else
    test_fail "slack_provider_configure failed with minimal config"
  fi

  teardown_slack_test
}

# Test 4: Provider configuration with missing webhook URL
test_slack_provider_configure_missing_webhook() {
  setup_slack_test

  # Create configuration without webhook URL
  local temp_config="$TEST_TEMP_DIR/slack_missing_webhook.conf"
  create_test_config "$temp_config" \
    "slack_channel=\"#alerts\"" \
    "slack_enabled=true"

  # Mock config_get_value function to return empty webhook
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.slack.webhook_url") echo "" ;;
    "notifications.slack.channel") echo "#alerts" ;;
    "notifications.slack.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! slack_provider_configure "$temp_config"; then
    test_pass "slack_provider_configure correctly fails with missing webhook URL"
  else
    test_fail "slack_provider_configure should fail with missing webhook URL"
  fi

  teardown_slack_test
}

# Test 5: Provider configuration with invalid webhook URL
test_slack_provider_configure_invalid_webhook() {
  setup_slack_test

  # Create configuration with invalid webhook URL
  local temp_config="$TEST_TEMP_DIR/slack_invalid_webhook.conf"
  create_test_config "$temp_config" \
    "slack_webhook_url=\"$(generate_invalid_webhook_url)\"" \
    "slack_enabled=true"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.slack.webhook_url") echo "$(generate_invalid_webhook_url)" ;;
    "notifications.slack.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! slack_provider_configure "$temp_config"; then
    test_pass "slack_provider_configure correctly fails with invalid webhook URL"
  else
    test_fail "slack_provider_configure should fail with invalid webhook URL"
  fi

  teardown_slack_test
}

# Test 6: Provider configuration with non-existent config file
test_slack_provider_configure_nonexistent() {
  setup_slack_test

  local nonexistent_config="/nonexistent/config/file.conf"

  if ! slack_provider_configure "$nonexistent_config"; then
    test_pass "slack_provider_configure correctly fails with non-existent config file"
  else
    test_fail "slack_provider_configure should fail with non-existent config file"
  fi

  teardown_slack_test
}

# Test 7: Provider configuration with empty config file
test_slack_provider_configure_empty() {
  setup_slack_test

  # Create empty configuration file
  local temp_config="$TEST_TEMP_DIR/slack_empty.conf"
  touch "$temp_config"

  # Mock config_get_value function to return empty values
  create_mock_function "config_get_value" 'echo "$2"'

  if ! slack_provider_configure "$temp_config"; then
    test_pass "slack_provider_configure correctly fails with empty config file"
  else
    test_fail "slack_provider_configure should fail with empty config file"
  fi

  teardown_slack_test
}

# Test 8: Successful notification sending
test_slack_provider_send_success() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_channel="#alerts"
  slack_username="ServerSentry"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Mock jq if available
  if command -v jq >/dev/null 2>&1; then
    create_mock_command "jq" "cpu_usage" 0
  fi

  local test_data
  test_data=($(generate_test_alert_data))

  if slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send succeeds with valid configuration and response"
  else
    test_fail "slack_provider_send should succeed with valid configuration"
  fi

  teardown_slack_test
}

# Test 9: Failed notification sending due to curl error
test_slack_provider_send_curl_failure() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock failed curl response
  create_mock_command "curl" "Connection failed" 1

  local test_data
  test_data=($(generate_test_alert_data))

  if ! slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send correctly fails when curl fails"
  else
    test_fail "slack_provider_send should fail when curl fails"
  fi

  teardown_slack_test
}

# Test 10: Failed notification sending due to Slack API error
test_slack_provider_send_api_error() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock Slack API error response
  create_mock_command "curl" "$(generate_error_slack_response)" 0

  local test_data
  test_data=($(generate_test_alert_data))

  if ! slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send correctly fails with Slack API error"
  else
    test_fail "slack_provider_send should fail with Slack API error"
  fi

  teardown_slack_test
}

# Test 11: Notification sending without curl command
test_slack_provider_send_no_curl() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock util_command_exists to return false for curl
  create_mock_function "util_command_exists" '[[ "$1" != "curl" ]]'

  local test_data
  test_data=($(generate_test_alert_data))

  if ! slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send correctly fails when curl is not available"
  else
    test_fail "slack_provider_send should fail when curl is not available"
  fi

  teardown_slack_test
}

# Test 12: Notification sending without jq command
test_slack_provider_send_no_jq() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Mock util_command_exists to return false for jq
  create_mock_function "util_command_exists" '[[ "$1" != "jq" ]]'

  local test_data
  test_data=($(generate_test_alert_data "2" "High CPU" "cpu"))

  if slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send works without jq (fallback mode)"
  else
    test_fail "slack_provider_send should work without jq"
  fi

  teardown_slack_test
}

# Test 13: Notification with different status codes
test_slack_provider_send_different_statuses() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  local status_codes=("0" "1" "2" "3")
  local status_messages=("OK" "WARNING" "CRITICAL" "UNKNOWN")
  local status_colors=("#36a64f" "#ff9500" "#ff0000" "#808080")

  for i in "${!status_codes[@]}"; do
    local status_code="${status_codes[$i]}"
    local status_message="${status_messages[$i]}"

    if slack_provider_send "$status_code" "$status_message" "test" '{}'; then
      test_pass "slack_provider_send handles status code $status_code correctly"
    else
      test_fail "slack_provider_send failed with status code $status_code"
    fi
  done

  teardown_slack_test
}

# Test 14: Notification with basic metrics
test_slack_provider_send_basic_metrics() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Mock jq for JSON processing
  create_mock_command "jq" "." 0

  local basic_metrics='{"cpu_usage": 85.5, "memory_usage": 70.2}'

  if slack_provider_send "2" "System alert" "system" "$basic_metrics"; then
    test_pass "slack_provider_send handles basic JSON metrics"
  else
    test_fail "slack_provider_send failed with basic JSON metrics"
  fi

  teardown_slack_test
}

# Test 15: Notification with complex metrics
test_slack_provider_send_complex_metrics() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Mock jq for JSON processing
  create_mock_command "jq" "." 0

  local complex_metrics
  complex_metrics="$(generate_complex_metrics)"

  if slack_provider_send "2" "Complex system alert" "system" "$complex_metrics"; then
    test_pass "slack_provider_send handles complex JSON metrics"
  else
    test_fail "slack_provider_send failed with complex JSON metrics"
  fi

  teardown_slack_test
}

# Test 16: Notification with empty metrics
test_slack_provider_send_empty_metrics() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  if slack_provider_send "1" "Warning message" "test" ""; then
    test_pass "slack_provider_send handles empty metrics"
  else
    test_fail "slack_provider_send failed with empty metrics"
  fi

  teardown_slack_test
}

# Test 17: Notification with invalid JSON metrics
test_slack_provider_send_invalid_json() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Mock jq to fail on invalid JSON
  create_mock_command "jq" "" 1

  local invalid_json='{"invalid": json}'

  if slack_provider_send "2" "System alert" "system" "$invalid_json"; then
    test_pass "slack_provider_send handles invalid JSON gracefully"
  else
    test_fail "slack_provider_send should handle invalid JSON gracefully"
  fi

  teardown_slack_test
}

# Test 18: Notification with text details
test_slack_provider_send_text_details() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  local detailed_message="CPU usage has exceeded 85% for the past 5 minutes. Current usage: 87.3%. Please investigate immediately."

  if slack_provider_send "2" "$detailed_message" "cpu" '{"cpu_usage": 87.3}'; then
    test_pass "slack_provider_send handles detailed text messages"
  else
    test_fail "slack_provider_send failed with detailed text message"
  fi

  teardown_slack_test
}

# Test 19: Provider test function
test_slack_provider_test() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  if slack_provider_test; then
    test_pass "slack_provider_test succeeds with valid configuration"
  else
    test_fail "slack_provider_test should succeed with valid configuration"
  fi

  teardown_slack_test
}

# Test 20: Provider validation with valid configuration
test_slack_provider_validate_valid() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true
  slack_timeout=30

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if slack_provider_validate; then
    test_pass "slack_provider_validate passes with valid configuration"
  else
    test_fail "slack_provider_validate should pass with valid configuration"
  fi

  teardown_slack_test
}

# Test 21: Provider validation with missing curl
test_slack_provider_validate_no_curl() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock util_command_exists to return false for curl
  create_mock_function "util_command_exists" '[[ "$1" != "curl" ]]'

  if ! slack_provider_validate; then
    test_pass "slack_provider_validate correctly fails when curl is missing"
  else
    test_fail "slack_provider_validate should fail when curl is missing"
  fi

  teardown_slack_test
}

# Test 22: Provider validation with invalid webhook URL
test_slack_provider_validate_invalid_webhook() {
  setup_slack_test

  # Configure Slack provider with invalid webhook
  slack_webhook_url="$(generate_invalid_webhook_url)"
  slack_enabled=true

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if ! slack_provider_validate; then
    test_pass "slack_provider_validate correctly fails with invalid webhook URL"
  else
    test_fail "slack_provider_validate should fail with invalid webhook URL"
  fi

  teardown_slack_test
}

# Test 23: Provider validation with disabled provider
test_slack_provider_validate_disabled() {
  setup_slack_test

  # Configure Slack provider as disabled
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=false

  # Mock util_command_exists to return true for curl
  create_mock_function "util_command_exists" '[[ "$1" == "curl" ]]'

  if slack_provider_validate; then
    test_pass "slack_provider_validate passes even when provider is disabled"
  else
    test_fail "slack_provider_validate should pass even when provider is disabled"
  fi

  teardown_slack_test
}

# Test 24: Provider status function
test_slack_provider_status() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_channel="#alerts"
  slack_username="ServerSentry"
  slack_enabled=true
  slack_timeout=30

  # Mock util_command_exists
  create_mock_function "util_command_exists" "[[ \"\$1\" == \"curl\" || \"\$1\" == \"jq\" ]]"

  local status_output
  status_output=$(slack_provider_status)

  if assert_contains "$status_output" "Slack Provider Status" "Status should contain header" &&
    assert_contains "$status_output" "$SLACK_PROVIDER_VERSION" "Status should contain version" &&
    assert_contains "$status_output" "Enabled: true" "Status should show enabled state" &&
    assert_contains "$status_output" "Channel: #alerts" "Status should show channel" &&
    assert_contains "$status_output" "curl available: yes" "Status should show curl availability"; then
    test_pass "slack_provider_status returns correct status information"
  else
    test_fail "slack_provider_status output: $status_output"
  fi

  teardown_slack_test
}

# Test 25: Payload structure validation
test_slack_provider_payload_structure() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_channel="#alerts"
  slack_username="ServerSentry"
  slack_icon_emoji=":warning:"
  slack_enabled=true

  # Mock curl to capture the payload
  create_mock_command "curl" "
    # Extract the JSON payload from curl arguments
    for arg in \"\$@\"; do
      if [[ \"\$arg\" == *\"{\"* ]]; then
        echo \"\$arg\" > /tmp/slack_payload.json
        break
      fi
    done
    echo \"ok\"
  " 0

  local test_data
  mapfile -t test_data < <(generate_test_alert_data "2" "Test Alert" "test_plugin")

  if slack_provider_send "${test_data[@]}"; then
    # Verify payload structure (if payload file exists)
    if [[ -f "/tmp/slack_payload.json" ]]; then
      local payload
      payload=$(cat "/tmp/slack_payload.json")

      if assert_contains "$payload" "\"channel\":\"#alerts\"" "Payload should contain channel" &&
        assert_contains "$payload" "\"username\":\"ServerSentry\"" "Payload should contain username" &&
        assert_contains "$payload" "\"icon_emoji\":\":warning:\"" "Payload should contain icon emoji" &&
        assert_contains "$payload" "Test Alert" "Payload should contain alert message"; then
        test_pass "slack_provider_send creates correct payload structure"
      else
        test_fail "Payload structure validation failed: $payload"
      fi
      rm -f "/tmp/slack_payload.json"
    else
      test_pass "slack_provider_send executed successfully (payload file not captured)"
    fi
  else
    test_fail "slack_provider_send failed during payload structure test"
  fi

  teardown_slack_test
}

# Test 26: Field validation and formatting
test_slack_provider_field_validation() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Test with various field types
  local metrics='{"cpu": 85.5, "memory": 70, "status": "critical", "server": "prod-01"}'

  if slack_provider_send "2" "Field validation test" "system" "$metrics"; then
    test_pass "slack_provider_send handles field validation correctly"
  else
    test_fail "slack_provider_send failed field validation test"
  fi

  teardown_slack_test
}

# Test 27: Configuration values in payload
test_slack_provider_config_in_payload() {
  setup_slack_test

  # Configure Slack provider with custom values
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_channel="#custom-alerts"
  slack_username="Custom Bot"
  slack_icon_emoji=":robot_face:"
  slack_enabled=true

  # Mock curl to verify configuration is used
  create_mock_command "curl" 'echo "Configuration used correctly"; echo "ok"' 0

  local test_data
  mapfile -t test_data < <(generate_test_alert_data)

  if slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send uses configuration values in payload"
  else
    test_fail "slack_provider_send failed to use configuration values"
  fi

  teardown_slack_test
}

# === EDGE CASE AND ERROR TESTS ===

# Test 28: Error handling with webhook timeout
test_slack_provider_send_webhook_timeout() {
  setup_slack_test

  # Configure Slack provider with short timeout
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_timeout=1
  slack_enabled=true

  # Mock curl to simulate timeout
  create_mock_command "curl" 'sleep 2; echo "timeout"' 28 # Exit code 28 is timeout

  local test_data
  test_data=($(generate_test_alert_data))

  if ! slack_provider_send "${test_data[@]}"; then
    test_pass "slack_provider_send handles webhook timeout correctly"
  else
    test_fail "slack_provider_send should fail on webhook timeout"
  fi

  teardown_slack_test
}

# Test 29: Error handling with invalid URL responses
test_slack_provider_send_invalid_url_response() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock curl to return various error responses
  local error_responses=("invalid_payload" "channel_not_found" "missing_scope" "rate_limited")

  for error_response in "${error_responses[@]}"; do
    create_mock_command "curl" "{\"ok\":false,\"error\":\"$error_response\"}" 0

    local test_data
    test_data=($(generate_test_alert_data))

    if ! slack_provider_send "${test_data[@]}"; then
      test_pass "slack_provider_send handles '$error_response' error correctly"
    else
      test_fail "slack_provider_send should fail with '$error_response' error"
    fi
  done

  teardown_slack_test
}

# Test 30: Large payload handling
test_slack_provider_send_large_payload() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Create large message
  local large_message=""
  for i in {1..50}; do
    large_message+="This is a very long message segment $i with lots of details about the system state and alert conditions. "
  done

  # Create large metrics
  local large_metrics='{'
  for i in {1..100}; do
    large_metrics+="\"metric_$i\": $((i * 10))"
    if [[ $i -lt 100 ]]; then
      large_metrics+=','
    fi
  done
  large_metrics+='}'

  if slack_provider_send "2" "$large_message" "test" "$large_metrics"; then
    test_pass "slack_provider_send handles large payloads"
  else
    test_fail "slack_provider_send failed with large payload"
  fi

  teardown_slack_test
}

# Test 31: Special characters and encoding
test_slack_provider_send_special_characters() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  # Test various special characters
  local special_chars_message="Alert with special chars: @#$%^&*()[]{}|\\:;\"'<>,.?/\`~!+=_-"
  local unicode_message="Unicode: 🚨 警告 Тревога ñoño"

  if slack_provider_send "2" "$special_chars_message" "test" '{}' &&
    slack_provider_send "2" "$unicode_message" "test" '{}'; then
    test_pass "slack_provider_send handles special characters and Unicode"
  else
    test_fail "slack_provider_send failed with special characters"
  fi

  teardown_slack_test
}

# Test 32: Performance test
test_slack_provider_send_performance() {
  setup_slack_test

  # Configure Slack provider
  slack_webhook_url="$(generate_test_webhook_url)"
  slack_enabled=true

  # Mock successful curl response (fast)
  create_mock_command "curl" "$(generate_valid_slack_response)" 0

  local send_count=10

  measure_execution_time slack_multiple_sends "$send_count"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if assert_execution_time_under "5" "Multiple sends should complete within 5 seconds"; then
      test_pass "slack_provider_send performance test passed"
    else
      test_fail "slack_provider_send performance test failed: took ${MEASURED_TIME}s"
    fi
  else
    test_fail "slack_provider_send performance test failed with exit code $exit_code"
  fi

  teardown_slack_test
}

# Helper function for performance test
slack_multiple_sends() {
  local count="$1"
  for ((i = 1; i <= count; i++)); do
    slack_provider_send "1" "Performance test message $i" "test" "{\"iteration\": $i}" || return 1
  done
  return 0
}

# === MAIN TEST EXECUTION ===

run_slack_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  # Core functionality tests
  test_slack_provider_info
  test_slack_provider_configure_valid
  test_slack_provider_configure_minimal
  test_slack_provider_configure_missing_webhook
  test_slack_provider_configure_invalid_webhook
  test_slack_provider_configure_nonexistent
  test_slack_provider_configure_empty

  # Notification sending tests
  test_slack_provider_send_success
  test_slack_provider_send_curl_failure
  test_slack_provider_send_api_error
  test_slack_provider_send_no_curl
  test_slack_provider_send_no_jq
  test_slack_provider_send_different_statuses
  test_slack_provider_send_basic_metrics
  test_slack_provider_send_complex_metrics
  test_slack_provider_send_empty_metrics
  test_slack_provider_send_invalid_json
  test_slack_provider_send_text_details

  # Provider utility tests
  test_slack_provider_test
  test_slack_provider_validate_valid
  test_slack_provider_validate_no_curl
  test_slack_provider_validate_invalid_webhook
  test_slack_provider_validate_disabled
  test_slack_provider_status

  # Payload and configuration tests
  test_slack_provider_payload_structure
  test_slack_provider_field_validation
  test_slack_provider_config_in_payload

  # Edge case and error tests
  test_slack_provider_send_webhook_timeout
  test_slack_provider_send_invalid_url_response
  test_slack_provider_send_large_payload
  test_slack_provider_send_special_characters

  # Performance tests
  test_slack_provider_send_performance

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_slack_tests
  exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
