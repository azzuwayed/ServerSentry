#!/usr/bin/env bash
#
# ServerSentry v2 - Email Notification Provider Comprehensive Unit Tests
#
# Tests all email notification provider functions with extensive edge case coverage

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
source "$SERVERSENTRY_ROOT/lib/notifications/email/email.sh"

# Test configuration
TEST_SUITE_NAME="Email Notification Provider Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===



# === MOCK DATA GENERATORS ===

generate_valid_smtp_config() {
  cat <<'EOF'
email_smtp_server="smtp.gmail.com"
email_smtp_port=587
email_username="test@example.com"
email_password="test_password"
email_from="serversentry@example.com"
email_to="admin@example.com"
email_use_tls=true
email_enabled=true
EOF
}

generate_invalid_smtp_config() {
  cat <<'EOF'
email_smtp_server=""
email_smtp_port=0
email_username=""
email_password=""
email_from=""
email_to=""
email_enabled=true
EOF
}

generate_test_email_content() {
  local status_code="${1:-2}"
  local status_message="${2:-High CPU usage detected}"
  local plugin_name="${3:-cpu}"

  cat <<EOF
Subject: [ServerSentry] Alert: $status_message
From: serversentry@example.com
To: admin@example.com

ServerSentry Alert

Status: $status_message
Plugin: $plugin_name
Time: $(date)

This is an automated alert from ServerSentry.
EOF
}

generate_test_alert_data() {
  local status_code="${1:-2}"
  local status_message="${2:-High CPU usage detected}"
  local plugin_name="${3:-cpu}"
  local metrics="${4:-{\"cpu_usage\": 85.5}}"

  echo "$status_code" "$status_message" "$plugin_name" "$metrics"
}

# === SETUP AND TEARDOWN ===

setup_email_test() {
  setup_test_environment "email_notification_test"

  # Reset email provider variables to defaults
  email_smtp_server=""
  email_smtp_port=587
  email_username=""
  email_password=""
  email_from=""
  email_to=""
  email_subject="[ServerSentry] Alert: {status}"
  email_use_tls=true
  email_enabled=false
  email_timeout=30

  # Clean up any existing mocks
  cleanup_mocks
}

teardown_email_test() {
  cleanup_test_environment
}

# === CORE FUNCTION TESTS ===

# Test 1: Provider info function
test_email_provider_info() {
  setup_email_test

  local info_output
  info_output=$(email_provider_info)

  if assert_contains "$info_output" "Email" "Provider info should contain 'Email'" &&
    assert_contains "$info_output" "$EMAIL_PROVIDER_VERSION" "Provider info should contain version"; then
    test_pass "email_provider_info returns correct information"
  else
    test_fail "email_provider_info output: $info_output"
  fi

  teardown_email_test
}

# Test 2: Provider configuration with valid SMTP settings
test_email_provider_configure_valid() {
  setup_email_test

  # Create valid configuration
  local temp_config="$TEST_TEMP_DIR/email_valid.conf"
  generate_valid_smtp_config >"$temp_config"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.email.smtp_server") echo "smtp.gmail.com" ;;
    "notifications.email.smtp_port") echo "587" ;;
    "notifications.email.username") echo "test@example.com" ;;
    "notifications.email.password") echo "test_password" ;;
    "notifications.email.from") echo "serversentry@example.com" ;;
    "notifications.email.to") echo "admin@example.com" ;;
    "notifications.email.use_tls") echo "true" ;;
    "notifications.email.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if email_provider_configure "$temp_config"; then
    if assert_equals "smtp.gmail.com" "$email_smtp_server" "SMTP server should be set" &&
      assert_equals "587" "$email_smtp_port" "SMTP port should be set" &&
      assert_equals "test@example.com" "$email_username" "Username should be set" &&
      assert_equals "admin@example.com" "$email_to" "To address should be set"; then
      test_pass "email_provider_configure loads valid configuration"
    else
      test_fail "Configuration not loaded correctly"
    fi
  else
    test_fail "email_provider_configure failed with valid config"
  fi

  teardown_email_test
}

# Test 3: Provider configuration with missing SMTP server
test_email_provider_configure_missing_smtp() {
  setup_email_test

  # Create configuration without SMTP server
  local temp_config="$TEST_TEMP_DIR/email_missing_smtp.conf"
  create_test_config "$temp_config" \
    "email_username=\"test@example.com\"" \
    "email_to=\"admin@example.com\"" \
    "email_enabled=true"

  # Mock config_get_value function to return empty SMTP server
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.email.smtp_server") echo "" ;;
    "notifications.email.username") echo "test@example.com" ;;
    "notifications.email.to") echo "admin@example.com" ;;
    "notifications.email.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! email_provider_configure "$temp_config"; then
    test_pass "email_provider_configure correctly fails with missing SMTP server"
  else
    test_fail "email_provider_configure should fail with missing SMTP server"
  fi

  teardown_email_test
}

# Test 4: Provider configuration with invalid email addresses
test_email_provider_configure_invalid_emails() {
  setup_email_test

  # Create configuration with invalid email addresses
  local temp_config="$TEST_TEMP_DIR/email_invalid_emails.conf"
  create_test_config "$temp_config" \
    "email_smtp_server=\"smtp.gmail.com\"" \
    "email_from=\"invalid-email\"" \
    "email_to=\"also-invalid\"" \
    "email_enabled=true"

  # Mock config_get_value function
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.email.smtp_server") echo "smtp.gmail.com" ;;
    "notifications.email.from") echo "invalid-email" ;;
    "notifications.email.to") echo "also-invalid" ;;
    "notifications.email.enabled") echo "true" ;;
    *) echo "$2" ;;
  esac'

  if ! email_provider_configure "$temp_config"; then
    test_pass "email_provider_configure correctly fails with invalid email addresses"
  else
    test_fail "email_provider_configure should fail with invalid email addresses"
  fi

  teardown_email_test
}

# Test 5: Successful email sending
test_email_provider_send_success() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_smtp_port=587
  email_username="test@example.com"
  email_password="test_password"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent successfully" 0

  # Mock sendmail if mail is not available
  create_mock_command "sendmail" "" 0

  local test_data
  test_data=($(generate_test_alert_data))

  if email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send succeeds with valid configuration"
  else
    test_fail "email_provider_send should succeed with valid configuration"
  fi

  teardown_email_test
}

# Test 6: Failed email sending due to missing mail command
test_email_provider_send_no_mail_command() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock util_command_exists to return false for mail commands
  create_mock_function "util_command_exists" '[[ "$1" != "mail" && "$1" != "sendmail" && "$1" != "msmtp" ]]'

  local test_data
  test_data=($(generate_test_alert_data))

  if ! email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send correctly fails when no mail command is available"
  else
    test_fail "email_provider_send should fail when no mail command is available"
  fi

  teardown_email_test
}

# Test 7: Email sending with different mail commands
test_email_provider_send_different_commands() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  local mail_commands=("mail" "sendmail" "msmtp")

  for cmd in "${mail_commands[@]}"; do
    # Mock only the current command as available
    create_mock_function "util_command_exists" "[[ \"\$1\" == \"$cmd\" ]]"
    create_mock_command "$cmd" "Message sent via $cmd" 0

    local test_data
    test_data=($(generate_test_alert_data))

    if email_provider_send "${test_data[@]}"; then
      test_pass "email_provider_send works with $cmd command"
    else
      test_fail "email_provider_send failed with $cmd command"
    fi

    cleanup_mocks
  done

  teardown_email_test
}

# Test 8: Email sending with different status codes
test_email_provider_send_different_statuses() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent" 0

  local status_codes=("0" "1" "2" "3")
  local status_messages=("OK" "WARNING" "CRITICAL" "UNKNOWN")

  for i in "${!status_codes[@]}"; do
    local status_code="${status_codes[$i]}"
    local status_message="${status_messages[$i]}"

    if email_provider_send "$status_code" "$status_message" "test" '{}'; then
      test_pass "email_provider_send handles status code $status_code correctly"
    else
      test_fail "email_provider_send failed with status code $status_code"
    fi
  done

  teardown_email_test
}

# Test 9: Email with complex metrics
test_email_provider_send_complex_metrics() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent" 0

  local complex_metrics='{"cpu": {"usage": 85.5, "cores": 4}, "memory": {"used": 8.5, "total": 16}}'

  if email_provider_send "2" "System alert" "system" "$complex_metrics"; then
    test_pass "email_provider_send handles complex metrics"
  else
    test_fail "email_provider_send failed with complex metrics"
  fi

  teardown_email_test
}

# Test 10: Email with special characters in subject and body
test_email_provider_send_special_characters() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent" 0

  # Create message with special characters
  local special_message="Alert: CPU usage > 85% on server \"production-01\" at 12:34:56!"

  if email_provider_send "2" "$special_message" "test" '{}'; then
    test_pass "email_provider_send handles special characters"
  else
    test_fail "email_provider_send failed with special characters"
  fi

  teardown_email_test
}

# Test 11: Email with Unicode characters
test_email_provider_send_unicode_characters() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent" 0

  # Create message with Unicode characters
  local unicode_message="系统警告: CPU使用率过高 🚨 Тревога: высокая загрузка ЦП"

  if email_provider_send "2" "$unicode_message" "test" '{}'; then
    test_pass "email_provider_send handles Unicode characters"
  else
    test_fail "email_provider_send failed with Unicode characters"
  fi

  teardown_email_test
}

# Test 12: Provider test function
test_email_provider_test() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Test message sent" 0

  if email_provider_test; then
    test_pass "email_provider_test succeeds with valid configuration"
  else
    test_fail "email_provider_test should succeed with valid configuration"
  fi

  teardown_email_test
}

# Test 13: Provider validation with valid configuration
test_email_provider_validate_valid() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_smtp_port=587
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock util_command_exists to return true for mail
  create_mock_function "util_command_exists" '[[ "$1" == "mail" ]]'

  if email_provider_validate; then
    test_pass "email_provider_validate passes with valid configuration"
  else
    test_fail "email_provider_validate should pass with valid configuration"
  fi

  teardown_email_test
}

# Test 14: Provider validation with missing mail command
test_email_provider_validate_no_mail() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock util_command_exists to return false for all mail commands
  create_mock_function "util_command_exists" 'false'

  if ! email_provider_validate; then
    test_pass "email_provider_validate correctly fails when no mail command is available"
  else
    test_fail "email_provider_validate should fail when no mail command is available"
  fi

  teardown_email_test
}

# Test 15: Provider validation with invalid email addresses
test_email_provider_validate_invalid_emails() {
  setup_email_test

  # Configure email provider with invalid emails
  email_smtp_server="smtp.gmail.com"
  email_from="invalid-email"
  email_to="also-invalid"
  email_enabled=true

  # Mock util_command_exists to return true for mail
  create_mock_function "util_command_exists" '[[ "$1" == "mail" ]]'

  if ! email_provider_validate; then
    test_pass "email_provider_validate correctly fails with invalid email addresses"
  else
    test_fail "email_provider_validate should fail with invalid email addresses"
  fi

  teardown_email_test
}

# Test 16: Provider status function
test_email_provider_status() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_smtp_port=587
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock util_command_exists
  create_mock_function "util_command_exists" '[[ "$1" == "mail" ]]'

  local status_output
  status_output=$(email_provider_status)

  if assert_contains "$status_output" "Email Provider Status" "Status should contain header" &&
    assert_contains "$status_output" "$EMAIL_PROVIDER_VERSION" "Status should contain version" &&
    assert_contains "$status_output" "Enabled: true" "Status should show enabled state" &&
    assert_contains "$status_output" "SMTP Server: smtp.gmail.com" "Status should show SMTP server"; then
    test_pass "email_provider_status returns correct status information"
  else
    test_fail "email_provider_status output: $status_output"
  fi

  teardown_email_test
}

# Test 17: Multiple recipients
test_email_provider_send_multiple_recipients() {
  setup_email_test

  # Configure email provider with multiple recipients
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin1@example.com,admin2@example.com,admin3@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent to multiple recipients" 0

  local test_data
  test_data=($(generate_test_alert_data))

  if email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send handles multiple recipients"
  else
    test_fail "email_provider_send failed with multiple recipients"
  fi

  teardown_email_test
}

# Test 18: Custom subject template
test_email_provider_send_custom_subject() {
  setup_email_test

  # Configure email provider with custom subject
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_subject="[ALERT] {plugin} - {status}"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent with custom subject" 0

  local test_data
  test_data=($(generate_test_alert_data "2" "High CPU" "cpu"))

  if email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send handles custom subject template"
  else
    test_fail "email_provider_send failed with custom subject template"
  fi

  teardown_email_test
}

# Test 19: SMTP authentication
test_email_provider_send_smtp_auth() {
  setup_email_test

  # Configure email provider with SMTP authentication
  email_smtp_server="smtp.gmail.com"
  email_smtp_port=587
  email_username="test@example.com"
  email_password="test_password"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_use_tls=true
  email_enabled=true

  # Mock msmtp command (supports SMTP auth)
  create_mock_function "util_command_exists" '[[ "$1" == "msmtp" ]]'
  create_mock_command "msmtp" "Message sent via SMTP auth" 0

  local test_data
  test_data=($(generate_test_alert_data))

  if email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send handles SMTP authentication"
  else
    test_fail "email_provider_send failed with SMTP authentication"
  fi

  teardown_email_test
}

# Test 20: Performance test - Multiple rapid sends
test_email_provider_send_performance() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command
  create_mock_command "mail" "Message sent" 0

  local send_count=5

  measure_execution_time email_multiple_sends "$send_count"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if assert_execution_time_under "3" "Multiple email sends should complete within 3 seconds"; then
      test_pass "email_provider_send performance test passed"
    else
      test_fail "email_provider_send performance test failed: took ${MEASURED_TIME}s"
    fi
  else
    test_fail "email_provider_send performance test failed with exit code $exit_code"
  fi

  teardown_email_test
}

# Helper function for performance test
email_multiple_sends() {
  local count="$1"
  for ((i = 1; i <= count; i++)); do
    email_provider_send "1" "Test message $i" "test" '{}' || return 1
  done
  return 0
}

# Test 21: Email template processing
test_email_provider_template_processing() {
  setup_email_test

  # Configure email provider
  email_smtp_server="smtp.gmail.com"
  email_from="serversentry@example.com"
  email_to="admin@example.com"
  email_enabled=true

  # Mock successful mail command and capture the email content
  create_mock_command "mail" "Template processed correctly" 0

  # Mock hostname command
  create_mock_command "hostname" "test-server" 0

  local test_data
  test_data=($(generate_test_alert_data "2" "High CPU usage" "cpu"))

  if email_provider_send "${test_data[@]}"; then
    test_pass "email_provider_send processes templates correctly"
  else
    test_fail "email_provider_send failed to process templates"
  fi

  teardown_email_test
}

# Test 22: Configuration precedence
test_email_provider_configure_precedence() {
  setup_email_test

  # Create configuration file
  local temp_config="$TEST_TEMP_DIR/email_precedence.conf"
  create_test_config "$temp_config" \
    "email_smtp_server=\"file-smtp.example.com\"" \
    "email_from=\"file@example.com\""

  # Mock config_get_value to return different values (global config)
  create_mock_function "config_get_value" 'case "$1" in
    "notifications.email.smtp_server") echo "global-smtp.example.com" ;;
    "notifications.email.from") echo "global@example.com" ;;
    *) echo "$2" ;;
  esac'

  if email_provider_configure "$temp_config"; then
    # Global config should take precedence over file config
    if assert_equals "global-smtp.example.com" "$email_smtp_server" "Global config should take precedence"; then
      test_pass "email_provider_configure respects configuration precedence"
    else
      test_fail "Configuration precedence not working correctly"
    fi
  else
    test_fail "email_provider_configure failed with precedence test"
  fi

  teardown_email_test
}

# === MAIN TEST EXECUTION ===

run_email_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  # Core functionality tests
  test_email_provider_info
  test_email_provider_configure_valid
  test_email_provider_configure_missing_smtp
  test_email_provider_configure_invalid_emails

  # Email sending tests
  test_email_provider_send_success
  test_email_provider_send_no_mail_command
  test_email_provider_send_different_commands
  test_email_provider_send_different_statuses
  test_email_provider_send_complex_metrics
  test_email_provider_send_special_characters
  test_email_provider_send_unicode_characters

  # Provider utility tests
  test_email_provider_test
  test_email_provider_validate_valid
  test_email_provider_validate_no_mail
  test_email_provider_validate_invalid_emails
  test_email_provider_status

  # Advanced feature tests
  test_email_provider_send_multiple_recipients
  test_email_provider_send_custom_subject
  test_email_provider_send_smtp_auth
  test_email_provider_template_processing
  test_email_provider_configure_precedence

  # Performance tests
  test_email_provider_send_performance

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_email_tests
  exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
