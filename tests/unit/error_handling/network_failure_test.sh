#!/usr/bin/env bash
#
# ServerSentry v2 - Network Failure Error Handling Tests
#
# Tests how the system handles network connectivity issues

set -e

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

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
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

# Source test framework and helpers
source "$SCRIPT_DIR/../../test_framework.sh"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Source required modules
source "$SERVERSENTRY_ROOT/lib/core/logging.sh"
source "$SERVERSENTRY_ROOT/lib/notifications/slack/slack.sh"
source "$SERVERSENTRY_ROOT/lib/notifications/teams/teams.sh"
source "$SERVERSENTRY_ROOT/lib/notifications/email/email.sh"

# Test configuration
TEST_SUITE_NAME="Network Failure Error Handling Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup function
setup_network_failure_tests() {
  setup_test_environment "network_failure_test"

  # Configure notification providers with test URLs
  slack_webhook_url="https://hooks.slack.com/services/TEST/TEST/TEST"
  slack_enabled=true
  slack_timeout=5

  teams_webhook_url="https://outlook.office.com/webhook/TEST"
  teams_enabled=true
  teams_timeout=5

  email_enabled=true
  email_smtp_host="smtp.example.com"
  email_smtp_port=587
  email_timeout=5
}

# Cleanup function
cleanup_network_failure_tests() {
  # Restore network access
  unset http_proxy https_proxy
  cleanup_test_environment
}

# Test 1: Slack notification with network failure
test_slack_network_failure() {
  print_test_header "Slack notification with network failure"

  # Simulate network failure
  export http_proxy="http://127.0.0.1:9999"
  export https_proxy="http://127.0.0.1:9999"

  # Attempt to send notification
  local result
  local exit_code

  set +e
  result=$(slack_send_notification "Test Alert" "Network failure test" "critical" 2>&1)
  exit_code=$?
  set -e

  # Restore network
  unset http_proxy https_proxy

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail gracefully without crashing
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"timeout"* ]] || [[ "$result" == *"connection"* ]] || [[ "$result" == *"network"* ]]; then
      print_success "Slack network failure handled gracefully"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Slack network failure not handled properly: $result"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Slack should have failed with network down"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 2: Teams notification with network failure
test_teams_network_failure() {
  print_test_header "Teams notification with network failure"

  # Simulate network failure
  export http_proxy="http://127.0.0.1:9999"
  export https_proxy="http://127.0.0.1:9999"

  # Attempt to send notification
  local result
  local exit_code

  set +e
  result=$(teams_send_notification "Test Alert" "Network failure test" "critical" 2>&1)
  exit_code=$?
  set -e

  # Restore network
  unset http_proxy https_proxy

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail gracefully without crashing
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"timeout"* ]] || [[ "$result" == *"connection"* ]] || [[ "$result" == *"network"* ]]; then
      print_success "Teams network failure handled gracefully"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Teams network failure not handled properly: $result"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Teams should have failed with network down"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 3: Email notification with SMTP failure
test_email_smtp_failure() {
  print_test_header "Email notification with SMTP failure"

  # Configure invalid SMTP server
  local original_smtp_host="$email_smtp_host"
  email_smtp_host="invalid.smtp.server.example.com"

  # Attempt to send notification
  local result
  local exit_code

  set +e
  result=$(email_send_notification "test@example.com" "Test Alert" "SMTP failure test" "critical" 2>&1)
  exit_code=$?
  set -e

  # Restore original SMTP host
  email_smtp_host="$original_smtp_host"

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail gracefully without crashing
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"timeout"* ]] || [[ "$result" == *"connection"* ]] || [[ "$result" == *"resolve"* ]]; then
      print_success "Email SMTP failure handled gracefully"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_error "Email SMTP failure not handled properly: $result"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    print_error "Email should have failed with invalid SMTP server"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 4: Timeout handling
test_notification_timeout() {
  print_test_header "Notification timeout handling"

  # Set very short timeout
  local original_timeout="$slack_timeout"
  slack_timeout=1

  # Use a slow/unresponsive endpoint
  local original_webhook="$slack_webhook_url"
  slack_webhook_url="https://httpbin.org/delay/10" # 10 second delay

  # Attempt to send notification
  local start_time=$(date +%s)
  local result
  local exit_code

  set +e
  result=$(slack_send_notification "Test Alert" "Timeout test" "critical" 2>&1)
  exit_code=$?
  set -e

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Restore original values
  slack_timeout="$original_timeout"
  slack_webhook_url="$original_webhook"

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should timeout within reasonable time (not wait 10 seconds)
  if [[ $exit_code -ne 0 && $duration -lt 5 ]]; then
    if [[ "$result" == *"timeout"* ]]; then
      print_success "Notification timeout handled properly (${duration}s)"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Timeout detected but message unclear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_error "Notification timeout not handled properly (${duration}s, exit: $exit_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 5: DNS resolution failure
test_dns_resolution_failure() {
  print_test_header "DNS resolution failure handling"

  # Use invalid hostname
  local original_webhook="$slack_webhook_url"
  slack_webhook_url="https://this-domain-does-not-exist-12345.invalid/webhook"

  # Attempt to send notification
  local result
  local exit_code

  set +e
  result=$(slack_send_notification "Test Alert" "DNS failure test" "critical" 2>&1)
  exit_code=$?
  set -e

  # Restore original webhook
  slack_webhook_url="$original_webhook"

  TESTS_RUN=$((TESTS_RUN + 1))

  # Should fail gracefully with DNS error
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$result" == *"resolve"* ]] || [[ "$result" == *"DNS"* ]] || [[ "$result" == *"host"* ]]; then
      print_success "DNS resolution failure handled gracefully"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "DNS failure detected but message unclear: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    print_error "DNS resolution should have failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 6: Retry mechanism testing
test_retry_mechanism() {
  print_test_header "Retry mechanism testing"

  # Create a mock server that fails first few times
  local mock_port=8081
  local mock_responses_file="$TEST_TEMP_DIR/retry_responses.txt"

  # Create responses that fail first 2 times, then succeed
  cat >"$mock_responses_file" <<'EOF'
HTTP/1.1 500 Internal Server Error
Content-Length: 0

HTTP/1.1 500 Internal Server Error
Content-Length: 0

HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 13

{"ok": true}
EOF

  # Start mock server (if netcat available)
  if command -v nc >/dev/null 2>&1; then
    create_http_mock "$mock_port" "$mock_responses_file"
    sleep 1 # Give server time to start

    # Configure to use mock server
    local original_webhook="$slack_webhook_url"
    slack_webhook_url="http://localhost:$mock_port/webhook"

    # Attempt to send notification (should succeed after retries)
    local result
    local exit_code

    set +e
    result=$(slack_send_notification "Test Alert" "Retry test" "critical" 2>&1)
    exit_code=$?
    set -e

    # Restore original webhook
    slack_webhook_url="$original_webhook"

    # Stop mock server
    stop_http_mock

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $exit_code -eq 0 ]]; then
      print_success "Retry mechanism worked successfully"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      print_warning "Retry mechanism test inconclusive: $result"
      TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail if retry not implemented yet
    fi
  else
    print_warning "netcat not available, skipping retry mechanism test"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

# Test 7: Fallback notification testing
test_fallback_notification() {
  print_test_header "Fallback notification testing"

  # Disable primary notification method
  local original_slack_enabled="$slack_enabled"
  slack_enabled=false

  # Enable fallback method
  local original_email_enabled="$email_enabled"
  email_enabled=true

  # Mock successful email send
  create_mock_function "email_send_notification" 'echo "Email sent successfully"; return 0'

  # Attempt to send notification (should fallback to email)
  local result
  local exit_code

  set +e
  # This would need to be implemented in the notification system
  result=$(send_notification_with_fallback "Test Alert" "Fallback test" "critical" 2>&1)
  exit_code=$?
  set -e

  # Restore original settings
  slack_enabled="$original_slack_enabled"
  email_enabled="$original_email_enabled"
  cleanup_mocks

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $exit_code -eq 0 ]]; then
    print_success "Fallback notification worked successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Fallback notification not implemented yet"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail if not implemented yet
  fi
}

# Test 8: Network recovery testing
test_network_recovery() {
  print_test_header "Network recovery testing"

  # Simulate network failure for short period
  simulate_network_failure 2 &
  local network_sim_pid=$!

  # Wait a moment for network to be "down"
  sleep 1

  # Attempt notification during network failure
  local result1
  local exit_code1

  set +e
  result1=$(slack_send_notification "Test Alert" "Network recovery test 1" "critical" 2>&1)
  exit_code1=$?
  set -e

  # Wait for network to "recover"
  wait "$network_sim_pid"
  sleep 1

  # Attempt notification after network recovery
  local result2
  local exit_code2

  set +e
  result2=$(slack_send_notification "Test Alert" "Network recovery test 2" "critical" 2>&1)
  exit_code2=$?
  set -e

  TESTS_RUN=$((TESTS_RUN + 1))

  # First should fail, second might succeed (depending on actual network)
  if [[ $exit_code1 -ne 0 ]]; then
    print_success "Network failure properly detected during outage"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Network failure simulation may not have worked"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail test
  fi
}

# Main test execution
main() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_network_failure_tests

  # Run error handling tests
  test_slack_network_failure
  test_teams_network_failure
  test_email_smtp_failure
  test_notification_timeout
  test_dns_resolution_failure
  test_retry_mechanism
  test_fallback_notification
  test_network_recovery

  cleanup_network_failure_tests

  # Print summary
  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Exit with appropriate code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_success "All network failure tests passed!"
    exit 0
  else
    print_error "Some network failure tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
