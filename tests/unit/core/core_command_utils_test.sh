#!/usr/bin/env bash
#
# ServerSentry v2 - Command Utils Tests
#
# Comprehensive test suite for lib/core/utils/command_utils.sh

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source the test framework
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "${BASE_DIR}/lib/core/utils/command_utils.sh"
source "${BASE_DIR}/lib/core/logging.sh"

# Test configuration
TEST_SUITE_NAME="Command Utilities Tests"
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

# Setup function
setup_command_utils_tests() {
  setup_test_environment "command_utils_test"
  cleanup_mocks

  # Create test commands directory
  mkdir -p "$TEST_TEMP_DIR/test_commands"

  # Create test script files
  cat >"$TEST_TEMP_DIR/test_commands/success_command.sh" <<'EOF'
#!/bin/bash
echo "Success output"
exit 0
EOF

  cat >"$TEST_TEMP_DIR/test_commands/failure_command.sh" <<'EOF'
#!/bin/bash
echo "Error output" >&2
exit 1
EOF

  cat >"$TEST_TEMP_DIR/test_commands/slow_command.sh" <<'EOF'
#!/bin/bash
sleep 2
echo "Slow output"
exit 0
EOF

  cat >"$TEST_TEMP_DIR/test_commands/timeout_command.sh" <<'EOF'
#!/bin/bash
sleep 10
echo "This should timeout"
exit 0
EOF

  # Make scripts executable
  chmod +x "$TEST_TEMP_DIR/test_commands"/*.sh

  # Add test commands to PATH
  export PATH="$TEST_TEMP_DIR/test_commands:$PATH"
}

# Cleanup function
cleanup_command_utils_tests() {
  cleanup_test_environment
}

# === COMMAND EXECUTION TESTS ===

# Test 1: util_execute_command - Basic successful command
test_util_execute_command_success() {
  setup_command_utils_tests

  local result
  result=$(util_execute_command "echo 'test output'")

  if assert_equals "test output" "$result" "Command should return expected output"; then
    test_pass "util_execute_command executes successful commands correctly"
  else
    test_fail "util_execute_command failed with successful command: '$result'"
  fi

  cleanup_command_utils_tests
}

# Test 2: util_execute_command - Command with exit code
test_util_execute_command_exit_code() {
  setup_command_utils_tests

  # Test successful command exit code
  util_execute_command "true" >/dev/null
  local exit_code=$?

  if assert_equals "0" "$exit_code" "Successful command should return exit code 0"; then
    test_pass "util_execute_command returns correct exit code for successful commands"
  else
    test_fail "util_execute_command returned incorrect exit code: $exit_code"
  fi

  # Test failing command exit code
  util_execute_command "false" >/dev/null
  exit_code=$?

  if assert_equals "1" "$exit_code" "Failing command should return non-zero exit code"; then
    test_pass "util_execute_command returns correct exit code for failing commands"
  else
    test_fail "util_execute_command returned incorrect exit code for failure: $exit_code"
  fi

  cleanup_command_utils_tests
}

# Test 3: util_execute_command - Command with arguments
test_util_execute_command_with_args() {
  setup_command_utils_tests

  local result
  result=$(util_execute_command "echo" "arg1" "arg with spaces" "arg3")

  if assert_equals "arg1 arg with spaces arg3" "$result" "Command with arguments should work"; then
    test_pass "util_execute_command handles command arguments correctly"
  else
    test_fail "util_execute_command failed with arguments: '$result'"
  fi

  cleanup_command_utils_tests
}

# Test 4: util_execute_command_with_timeout - Basic timeout functionality
test_util_execute_command_with_timeout_success() {
  setup_command_utils_tests

  local result
  result=$(util_execute_command_with_timeout 5 "echo" "timeout test")

  if assert_equals "timeout test" "$result" "Command within timeout should succeed"; then
    test_pass "util_execute_command_with_timeout executes commands within timeout"
  else
    test_fail "util_execute_command_with_timeout failed: '$result'"
  fi

  cleanup_command_utils_tests
}

# Test 5: util_execute_command_with_timeout - Timeout enforcement
test_util_execute_command_with_timeout_enforcement() {
  setup_command_utils_tests

  local start_time end_time duration
  start_time=$(date +%s)

  # This should timeout after 2 seconds
  util_execute_command_with_timeout 2 "sleep" "5" >/dev/null 2>&1
  local exit_code=$?

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  if assert_true "[[ $exit_code -ne 0 ]]" "Timed out command should return non-zero exit code" &&
    assert_true "[[ $duration -le 4 ]]" "Command should be killed within timeout period"; then
    test_pass "util_execute_command_with_timeout enforces timeout correctly"
  else
    test_fail "util_execute_command_with_timeout failed timeout enforcement: exit=$exit_code, duration=${duration}s"
  fi

  cleanup_command_utils_tests
}

# Test 6: util_execute_command_safe - Safe command execution
test_util_execute_command_safe_basic() {
  setup_command_utils_tests

  local result exit_code
  result=$(util_execute_command_safe "echo 'safe output'" 2>/dev/null)
  exit_code=$?

  if assert_equals "0" "$exit_code" "Safe command should succeed" &&
    assert_equals "safe output" "$result" "Safe command should return output"; then
    test_pass "util_execute_command_safe executes safe commands correctly"
  else
    test_fail "util_execute_command_safe failed: exit=$exit_code, output='$result'"
  fi

  cleanup_command_utils_tests
}

# Test 7: util_execute_command_safe - Dangerous command prevention
test_util_execute_command_safe_dangerous() {
  setup_command_utils_tests

  # Test with potentially dangerous commands
  local dangerous_commands=("rm -rf /" "dd if=/dev/zero" "> /etc/passwd" ":(){ :|:& };:")

  for cmd in "${dangerous_commands[@]}"; do
    util_execute_command_safe "$cmd" >/dev/null 2>&1
    local exit_code=$?

    if assert_true "[[ $exit_code -ne 0 ]]" "Dangerous command should be rejected"; then
      test_pass "util_execute_command_safe rejects dangerous command: $cmd"
    else
      test_fail "util_execute_command_safe allowed dangerous command: $cmd"
    fi
  done

  cleanup_command_utils_tests
}

# Test 8: util_command_exists - Existing commands
test_util_command_exists_valid() {
  setup_command_utils_tests

  # Test with common system commands
  local common_commands=("echo" "cat" "ls" "grep" "awk")

  for cmd in "${common_commands[@]}"; do
    if util_command_exists "$cmd"; then
      test_pass "util_command_exists correctly identifies existing command: $cmd"
    else
      test_fail "util_command_exists failed to find existing command: $cmd"
    fi
  done

  cleanup_command_utils_tests
}

# Test 9: util_command_exists - Non-existing commands
test_util_command_exists_invalid() {
  setup_command_utils_tests

  # Test with non-existent commands
  local nonexistent_commands=("nonexistent_cmd_12345" "fake_command_xyz" "invalid_binary_abc")

  for cmd in "${nonexistent_commands[@]}"; do
    if ! util_command_exists "$cmd"; then
      test_pass "util_command_exists correctly identifies non-existing command: $cmd"
    else
      test_fail "util_command_exists incorrectly found non-existing command: $cmd"
    fi
  done

  cleanup_command_utils_tests
}

# Test 10: util_get_command_path - Getting full path
test_util_get_command_path_basic() {
  setup_command_utils_tests

  local echo_path
  echo_path=$(util_get_command_path "echo")

  if assert_not_empty "$echo_path" "Command path should not be empty" &&
    assert_file_exists "$echo_path" "Command path should exist" &&
    assert_contains "$echo_path" "echo" "Path should contain command name"; then
    test_pass "util_get_command_path returns correct path for existing commands"
  else
    test_fail "util_get_command_path failed: path='$echo_path'"
  fi

  cleanup_command_utils_tests
}

# Test 11: util_get_command_path - Non-existing command
test_util_get_command_path_nonexistent() {
  setup_command_utils_tests

  local nonexistent_path
  nonexistent_path=$(util_get_command_path "nonexistent_command_12345")

  if assert_equals "" "$nonexistent_path" "Non-existent command should return empty path"; then
    test_pass "util_get_command_path returns empty for non-existent commands"
  else
    test_fail "util_get_command_path returned path for non-existent command: '$nonexistent_path'"
  fi

  cleanup_command_utils_tests
}

# Test 12: util_validate_command - Command validation
test_util_validate_command_basic() {
  setup_command_utils_tests

  # Test valid commands
  if util_validate_command "echo test" &&
    util_validate_command "ls -la" &&
    util_validate_command "grep pattern file.txt"; then
    test_pass "util_validate_command accepts valid commands"
  else
    test_fail "util_validate_command rejected valid commands"
  fi

  cleanup_command_utils_tests
}

# Test 13: util_validate_command - Invalid commands
test_util_validate_command_invalid() {
  setup_command_utils_tests

  # Test invalid/dangerous commands
  local invalid_commands=(
    "rm -rf /"
    "> /etc/passwd"
    "dd if=/dev/zero of=/dev/sda"
    ":(){ :|:& };:"
    "chmod 777 /etc/shadow"
  )

  for cmd in "${invalid_commands[@]}"; do
    if ! util_validate_command "$cmd"; then
      test_pass "util_validate_command correctly rejects invalid command: $cmd"
    else
      test_fail "util_validate_command incorrectly accepted invalid command: $cmd"
    fi
  done

  cleanup_command_utils_tests
}

# Test 14: util_execute_background - Background execution
test_util_execute_background_basic() {
  setup_command_utils_tests

  local pid_file="$TEST_TEMP_DIR/bg_test.pid"
  local output_file="$TEST_TEMP_DIR/bg_output.txt"

  # Execute command in background
  util_execute_background "echo 'background test' > '$output_file'" "$pid_file"

  # Wait a moment for execution
  sleep 1

  if assert_file_exists "$pid_file" "PID file should be created" &&
    assert_file_exists "$output_file" "Output file should be created"; then

    local output
    output=$(cat "$output_file")

    if assert_equals "background test" "$output" "Background command should produce expected output"; then
      test_pass "util_execute_background executes commands in background"
    else
      test_fail "util_execute_background produced incorrect output: '$output'"
    fi
  else
    test_fail "util_execute_background failed to create expected files"
  fi

  cleanup_command_utils_tests
}

# Test 15: util_kill_process - Process termination
test_util_kill_process_basic() {
  setup_command_utils_tests

  # Start a long-running process
  sleep 30 &
  local test_pid=$!

  # Verify process is running
  if kill -0 "$test_pid" 2>/dev/null; then
    # Kill the process
    util_kill_process "$test_pid"

    # Wait a moment
    sleep 1

    # Verify process is terminated
    if ! kill -0 "$test_pid" 2>/dev/null; then
      test_pass "util_kill_process successfully terminates processes"
    else
      test_fail "util_kill_process failed to terminate process"
      kill -9 "$test_pid" 2>/dev/null # Cleanup
    fi
  else
    test_fail "Test process failed to start"
  fi

  cleanup_command_utils_tests
}

# Test 16: util_kill_process_tree - Process tree termination
test_util_kill_process_tree_basic() {
  setup_command_utils_tests

  # Start a process tree (parent with children)
  (
    sleep 30 &
    sleep 30 &
    sleep 30
  ) &
  local parent_pid=$!

  # Wait for children to start
  sleep 1

  # Kill the process tree
  util_kill_process_tree "$parent_pid"

  # Wait a moment
  sleep 1

  # Verify parent process is terminated
  if ! kill -0 "$parent_pid" 2>/dev/null; then
    test_pass "util_kill_process_tree successfully terminates process trees"
  else
    test_fail "util_kill_process_tree failed to terminate process tree"
    kill -9 "$parent_pid" 2>/dev/null # Cleanup
  fi

  cleanup_command_utils_tests
}

# Test 17: util_get_process_info - Process information retrieval
test_util_get_process_info_basic() {
  setup_command_utils_tests

  # Start a test process
  sleep 30 &
  local test_pid=$!

  # Get process info
  local process_info
  process_info=$(util_get_process_info "$test_pid")

  if assert_not_empty "$process_info" "Process info should not be empty" &&
    assert_contains "$process_info" "$test_pid" "Process info should contain PID" &&
    assert_contains "$process_info" "sleep" "Process info should contain command"; then
    test_pass "util_get_process_info retrieves process information correctly"
  else
    test_fail "util_get_process_info failed: '$process_info'"
  fi

  # Cleanup
  kill "$test_pid" 2>/dev/null

  cleanup_command_utils_tests
}

# Test 18: util_is_process_running - Process status check
test_util_is_process_running_basic() {
  setup_command_utils_tests

  # Start a test process
  sleep 30 &
  local test_pid=$!

  # Check if running
  if util_is_process_running "$test_pid"; then
    test_pass "util_is_process_running correctly identifies running processes"
  else
    test_fail "util_is_process_running failed to identify running process"
  fi

  # Kill the process
  kill "$test_pid" 2>/dev/null
  sleep 1

  # Check if not running
  if ! util_is_process_running "$test_pid"; then
    test_pass "util_is_process_running correctly identifies terminated processes"
  else
    test_fail "util_is_process_running incorrectly identified terminated process as running"
  fi

  cleanup_command_utils_tests
}

# Test 19: util_wait_for_process - Process completion waiting
test_util_wait_for_process_basic() {
  setup_command_utils_tests

  # Start a short process
  sleep 2 &
  local test_pid=$!

  local start_time end_time duration
  start_time=$(date +%s)

  # Wait for process completion
  util_wait_for_process "$test_pid" 5

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  if assert_true "[[ $duration -ge 1 && $duration -le 4 ]]" "Wait duration should be reasonable" &&
    ! util_is_process_running "$test_pid"; then
    test_pass "util_wait_for_process waits for process completion correctly"
  else
    test_fail "util_wait_for_process failed: duration=${duration}s"
  fi

  cleanup_command_utils_tests
}

# Test 20: util_wait_for_process - Timeout handling
test_util_wait_for_process_timeout() {
  setup_command_utils_tests

  # Start a long process
  sleep 30 &
  local test_pid=$!

  local start_time end_time duration
  start_time=$(date +%s)

  # Wait with short timeout
  util_wait_for_process "$test_pid" 2
  local exit_code=$?

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  if assert_true "[[ $exit_code -ne 0 ]]" "Wait should timeout" &&
    assert_true "[[ $duration -le 4 ]]" "Timeout should be enforced"; then
    test_pass "util_wait_for_process handles timeout correctly"
  else
    test_fail "util_wait_for_process timeout failed: exit=$exit_code, duration=${duration}s"
  fi

  # Cleanup
  kill "$test_pid" 2>/dev/null

  cleanup_command_utils_tests
}

# Test 21: util_capture_command_output - Output and error capture
test_util_capture_command_output_basic() {
  setup_command_utils_tests

  local stdout_file="$TEST_TEMP_DIR/stdout_test"
  local stderr_file="$TEST_TEMP_DIR/stderr_test"

  # Capture successful command output
  util_capture_command_output "echo 'stdout test'" "$stdout_file" "$stderr_file"

  if assert_file_exists "$stdout_file" "stdout file should exist" &&
    assert_file_exists "$stderr_file" "stderr file should exist"; then

    local stdout_content stderr_content
    stdout_content=$(cat "$stdout_file")
    stderr_content=$(cat "$stderr_file")

    if assert_equals "stdout test" "$stdout_content" "stdout should contain expected output" &&
      assert_equals "" "$stderr_content" "stderr should be empty for successful command"; then
      test_pass "util_capture_command_output captures output correctly"
    else
      test_fail "util_capture_command_output output mismatch: stdout='$stdout_content', stderr='$stderr_content'"
    fi
  else
    test_fail "util_capture_command_output failed to create output files"
  fi

  cleanup_command_utils_tests
}

# Test 22: util_capture_command_output - Error capture
test_util_capture_command_output_error() {
  setup_command_utils_tests

  local stdout_file="$TEST_TEMP_DIR/stdout_error_test"
  local stderr_file="$TEST_TEMP_DIR/stderr_error_test"

  # Capture command with error output
  util_capture_command_output "echo 'error test' >&2" "$stdout_file" "$stderr_file"

  if assert_file_exists "$stdout_file" "stdout file should exist" &&
    assert_file_exists "$stderr_file" "stderr file should exist"; then

    local stdout_content stderr_content
    stdout_content=$(cat "$stdout_file")
    stderr_content=$(cat "$stderr_file")

    if assert_equals "" "$stdout_content" "stdout should be empty for error command" &&
      assert_equals "error test" "$stderr_content" "stderr should contain error output"; then
      test_pass "util_capture_command_output captures error output correctly"
    else
      test_fail "util_capture_command_output error capture failed: stdout='$stdout_content', stderr='$stderr_content'"
    fi
  else
    test_fail "util_capture_command_output failed to create error output files"
  fi

  cleanup_command_utils_tests
}

# Test 23: util_execute_with_retry - Retry mechanism
test_util_execute_with_retry_success() {
  setup_command_utils_tests

  local attempt_count=0

  # Mock function that succeeds on first try
  test_success_command() {
    ((attempt_count++))
    echo "attempt $attempt_count"
    return 0
  }

  local result
  result=$(util_execute_with_retry 3 1 test_success_command)

  if assert_equals "attempt 1" "$result" "Should succeed on first attempt" &&
    assert_equals "1" "$attempt_count" "Should only make one attempt"; then
    test_pass "util_execute_with_retry succeeds without retries when command works"
  else
    test_fail "util_execute_with_retry unexpected behavior: result='$result', attempts=$attempt_count"
  fi

  cleanup_command_utils_tests
}

# Test 24: util_execute_with_retry - Retry on failure
test_util_execute_with_retry_failure() {
  setup_command_utils_tests

  local attempt_count=0

  # Mock function that fails twice then succeeds
  test_retry_command() {
    ((attempt_count++))
    if [[ $attempt_count -lt 3 ]]; then
      echo "attempt $attempt_count failed"
      return 1
    else
      echo "attempt $attempt_count succeeded"
      return 0
    fi
  }

  local result
  result=$(util_execute_with_retry 5 1 test_retry_command)

  if assert_equals "attempt 3 succeeded" "$result" "Should succeed on third attempt" &&
    assert_equals "3" "$attempt_count" "Should make three attempts"; then
    test_pass "util_execute_with_retry retries failed commands correctly"
  else
    test_fail "util_execute_with_retry retry failed: result='$result', attempts=$attempt_count"
  fi

  cleanup_command_utils_tests
}

# Test 25: util_execute_with_retry - Maximum retries exceeded
test_util_execute_with_retry_max_exceeded() {
  setup_command_utils_tests

  local attempt_count=0

  # Mock function that always fails
  test_fail_command() {
    ((attempt_count++))
    echo "attempt $attempt_count failed"
    return 1
  }

  util_execute_with_retry 3 1 test_fail_command >/dev/null 2>&1
  local exit_code=$?

  if assert_true "[[ $exit_code -ne 0 ]]" "Should fail after max retries" &&
    assert_equals "3" "$attempt_count" "Should make exactly 3 attempts"; then
    test_pass "util_execute_with_retry respects maximum retry limit"
  else
    test_fail "util_execute_with_retry max retries failed: exit=$exit_code, attempts=$attempt_count"
  fi

  cleanup_command_utils_tests
}

# Test 26: util_execute_parallel - Parallel command execution
test_util_execute_parallel_basic() {
  setup_command_utils_tests

  local commands=(
    "echo 'command 1'; sleep 1"
    "echo 'command 2'; sleep 1"
    "echo 'command 3'; sleep 1"
  )

  local start_time end_time duration
  start_time=$(date +%s)

  # Execute commands in parallel
  util_execute_parallel 3 "${commands[@]}"

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  # Should complete in roughly 1-2 seconds (parallel) rather than 3+ seconds (sequential)
  if assert_true "[[ $duration -le 3 ]]" "Parallel execution should be faster than sequential"; then
    test_pass "util_execute_parallel executes commands in parallel"
  else
    test_fail "util_execute_parallel took too long: ${duration}s"
  fi

  cleanup_command_utils_tests
}

# Test 27: Performance test - Command execution speed
test_util_command_performance() {
  setup_command_utils_tests

  # Test multiple rapid command executions
  local command_count=50

  measure_execution_time command_performance_test "$command_count"

  if assert_execution_time_under "5" "Multiple command executions should complete within 5 seconds"; then
    test_pass "Command utilities perform well with multiple executions"
  else
    test_fail "Command utilities performance issue: ${MEASURED_TIME}s"
  fi

  cleanup_command_utils_tests
}

# Helper function for performance test
command_performance_test() {
  local count="$1"
  for ((i = 1; i <= count; i++)); do
    util_execute_command "echo 'test $i'" >/dev/null || return 1
  done
  return 0
}

# Test 28: Edge cases and error conditions
test_util_command_edge_cases() {
  setup_command_utils_tests

  # Test empty command
  util_execute_command "" >/dev/null 2>&1
  local exit_code=$?
  if assert_true "[[ $exit_code -ne 0 ]]" "Empty command should fail"; then
    test_pass "Empty command handling works correctly"
  else
    test_fail "Empty command should have failed"
  fi

  # Test command with special characters
  local result
  result=$(util_execute_command "echo" "test@#\$%^&*()")
  if assert_equals "test@#\$%^&*()" "$result" "Special characters should be handled"; then
    test_pass "Special characters in commands work correctly"
  else
    test_fail "Special characters handling failed: '$result'"
  fi

  # Test very long command
  local long_arg
  long_arg=$(printf 'a%.0s' {1..1000})
  result=$(util_execute_command "echo" "$long_arg")
  if assert_equals "$long_arg" "$result" "Very long arguments should work"; then
    test_pass "Very long command arguments work correctly"
  else
    test_fail "Very long arguments failed"
  fi

  cleanup_command_utils_tests
}

# Test 29: Memory and resource efficiency
test_util_command_memory_efficiency() {
  setup_command_utils_tests

  # Test multiple operations without memory leaks
  for i in {1..20}; do
    util_execute_command "echo 'test $i'" >/dev/null
    util_command_exists "echo" >/dev/null
    util_get_command_path "echo" >/dev/null
  done

  # If we get here without hanging or crashing, consider it a success
  test_pass "Multiple command operations work without memory issues"

  cleanup_command_utils_tests
}

# Test 30: Signal handling and cleanup
test_util_command_signal_handling() {
  setup_command_utils_tests

  # Start a process that we'll interrupt
  (
    util_execute_command "sleep 10"
  ) &
  local test_pid=$!

  # Let it start
  sleep 1

  # Send interrupt signal
  kill -INT "$test_pid" 2>/dev/null

  # Wait for cleanup
  sleep 1

  # Check if properly cleaned up
  if ! kill -0 "$test_pid" 2>/dev/null; then
    test_pass "Signal handling and cleanup work correctly"
  else
    test_fail "Process cleanup failed after signal"
    kill -9 "$test_pid" 2>/dev/null # Force cleanup
  fi

  cleanup_command_utils_tests
}

# Main test execution
main() {
  log_info "Starting Command Utils comprehensive tests..."

  # Initialize test framework
  init_test_framework

  # Run all tests
  run_test test_util_execute_command_success
  run_test test_util_execute_command_exit_code
  run_test test_util_execute_command_with_args
  run_test test_util_execute_command_with_timeout_success
  run_test test_util_execute_command_with_timeout_enforcement
  run_test test_util_execute_command_safe_basic
  run_test test_util_execute_command_safe_dangerous
  run_test test_util_command_exists_valid
  run_test test_util_command_exists_invalid
  run_test test_util_get_command_path_basic
  run_test test_util_get_command_path_nonexistent
  run_test test_util_validate_command_basic
  run_test test_util_validate_command_invalid
  run_test test_util_execute_background_basic
  run_test test_util_kill_process_basic
  run_test test_util_kill_process_tree_basic
  run_test test_util_get_process_info_basic
  run_test test_util_is_process_running_basic
  run_test test_util_wait_for_process_basic
  run_test test_util_wait_for_process_timeout
  run_test test_util_capture_command_output_basic
  run_test test_util_capture_command_output_error
  run_test test_util_execute_with_retry_success
  run_test test_util_execute_with_retry_failure
  run_test test_util_execute_with_retry_max_exceeded
  run_test test_util_execute_parallel_basic
  run_test test_util_command_performance
  run_test test_util_command_edge_cases
  run_test test_util_command_memory_efficiency
  run_test test_util_command_signal_handling

  # Print results
  print_test_results

  log_info "Command Utils tests completed!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
