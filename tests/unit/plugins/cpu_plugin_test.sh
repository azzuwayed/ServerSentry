#!/usr/bin/env bash
#
# ServerSentry v2 - CPU Plugin Comprehensive Unit Tests
#
# Tests all CPU plugin functions with extensive edge case coverage and error conditions
# Refactored for better reliability and comprehensive testing

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

# Source the module under test
source "$SERVERSENTRY_ROOT/lib/plugins/cpu/cpu.sh"

# Test configuration
TEST_SUITE_NAME="CPU Plugin Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===



# === MOCK DATA GENERATORS ===

generate_iostat_output() {
  local idle_percent="${1:-20.0}"
  cat <<EOF
Device         tps     kB_read/s    kB_wrtn/s     kB_read    kB_wrtn
              0.00        0.00         0.00           0           0
              0.00        0.00         0.00           0      $idle_percent
EOF
}

generate_top_macos_output() {
  local cpu_usage="${1:-25.5}"
  cat <<EOF
Processes: 123 total, 2 running, 121 sleeping, 456 threads
Load Avg: 1.23, 1.45, 1.67  CPU usage: ${cpu_usage}% user, 10.2% sys, 64.3% idle
SharedLibs: 123M resident, 45M data, 12M linkedit.
EOF
}

generate_top_linux_output() {
  local cpu_usage="${1:-30.5}"
  cat <<EOF
top - 12:34:56 up 1 day,  2:34,  1 user,  load average: 0.12, 0.34, 0.56
Tasks: 123 total,   1 running, 122 sleeping,   0 stopped,   0 zombie
%Cpu(s): ${cpu_usage}%us,  5.0%sy,  0.0%ni, 64.5%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
EOF
}

generate_proc_stat_output() {
  local user="${1:-1000}"
  local nice="${2:-100}"
  local system="${3:-500}"
  local idle="${4:-8000}"
  local iowait="${5:-200}"
  local irq="${6:-50}"
  local softirq="${7:-25}"
  local steal="${8:-0}"

  cat <<EOF
cpu  $user $nice $system $idle $iowait $irq $softirq $steal
cpu0 $user $nice $system $idle $iowait $irq $softirq $steal
intr 123456789
ctxt 987654321
btime 1234567890
processes 12345
procs_running 2
procs_blocked 0
EOF
}

generate_uptime_output() {
  local load="${1:-1.23}"
  echo " 12:34:56 up 1 day,  2:34,  1 user,  load average: $load, 1.45, 1.67"
}

generate_sar_output() {
  local idle="${1:-75.0}"
  cat <<EOF
Linux 5.4.0 (hostname) 	01/01/2024 	_x86_64_	(4 CPU)

12:34:56 PM     CPU     %user     %nice   %system   %iowait    %steal     %idle
Average:        all      15.0       0.0      10.0       0.0       0.0     $idle
EOF
}

# === SETUP AND TEARDOWN ===

# shellcheck disable=SC2034
setup_cpu_test() {
  setup_test_environment "cpu_plugin_test"

  # Reset CPU plugin variables to defaults
  CPU_THRESHOLD=85
  CPU_WARNING_THRESHOLD=75
  CPU_CHECK_INTERVAL=30
  CPU_LOAD_THRESHOLD=10.0

  # Clean up any existing mocks
  cleanup_mocks
}

teardown_cpu_test() {
  cleanup_test_environment
}

# === TEST FUNCTIONS ===

# Test 1: Plugin info function
test_cpu_plugin_info() {
  local info_output
  info_output=$(cpu_plugin_info)

  if assert_contains "$info_output" "CPU Monitor" "Plugin info should contain 'CPU Monitor'" &&
    assert_contains "$info_output" "$CPU_PLUGIN_VERSION" "Plugin info should contain version"; then
    test_pass "cpu_plugin_info returns correct information"
  else
    test_fail "cpu_plugin_info output: $info_output"
  fi
}

# Test 2: Plugin configuration with valid config
test_cpu_plugin_configure_valid() {
  local temp_config="$TEST_TEMP_DIR/valid_config.conf"
  create_test_config "$temp_config" \
    "CPU_THRESHOLD=90" \
    "CPU_WARNING_THRESHOLD=75" \
    "CPU_CHECK_INTERVAL=60"

  local original_threshold=$CPU_THRESHOLD
  local original_warning=$CPU_WARNING_THRESHOLD

  if cpu_plugin_configure "$temp_config"; then
    if assert_equals "90" "$CPU_THRESHOLD" "CPU_THRESHOLD should be 90" &&
      assert_equals "75" "$CPU_WARNING_THRESHOLD" "CPU_WARNING_THRESHOLD should be 75"; then
      test_pass "cpu_plugin_configure loads valid configuration"
    else
      test_fail "Configuration not loaded correctly: CPU_THRESHOLD=$CPU_THRESHOLD, CPU_WARNING_THRESHOLD=$CPU_WARNING_THRESHOLD"
    fi
  else
    test_fail "cpu_plugin_configure failed with valid config"
  fi

  # Restore original values
  CPU_THRESHOLD=$original_threshold
  CPU_WARNING_THRESHOLD=$original_warning
}

# Test 3: Plugin configuration with invalid thresholds
test_cpu_plugin_configure_invalid_thresholds() {
  local temp_config="$TEST_TEMP_DIR/invalid_config.conf"
  create_test_config "$temp_config" \
    "CPU_THRESHOLD=150" \
    "CPU_WARNING_THRESHOLD=200"

  local original_threshold=$CPU_THRESHOLD
  local original_warning=$CPU_WARNING_THRESHOLD

  cpu_plugin_configure "$temp_config" 2>/dev/null

  if assert_equals "85" "$CPU_THRESHOLD" "Invalid CPU_THRESHOLD should reset to default" &&
    assert_equals "75" "$CPU_WARNING_THRESHOLD" "Invalid CPU_WARNING_THRESHOLD should reset to default"; then
    test_pass "cpu_plugin_configure handles invalid thresholds correctly"
  else
    test_fail "Invalid thresholds not reset to defaults: CPU_THRESHOLD=$CPU_THRESHOLD, CPU_WARNING_THRESHOLD=$CPU_WARNING_THRESHOLD"
  fi

  # Restore original values
  CPU_THRESHOLD=$original_threshold
  CPU_WARNING_THRESHOLD=$original_warning
}

# Test 4: Plugin configuration threshold adjustment
test_cpu_plugin_configure_threshold_adjustment() {
  local temp_config="$TEST_TEMP_DIR/adjustment_config.conf"
  create_test_config "$temp_config" \
    "CPU_THRESHOLD=80" \
    "CPU_WARNING_THRESHOLD=85"

  local original_threshold=$CPU_THRESHOLD
  local original_warning=$CPU_WARNING_THRESHOLD

  cpu_plugin_configure "$temp_config" 2>/dev/null

  if assert_numeric_less "$CPU_WARNING_THRESHOLD" "$CPU_THRESHOLD" "Warning threshold should be less than critical"; then
    test_pass "Warning threshold adjusted to be less than critical threshold"
  else
    test_fail "Warning threshold not adjusted: WARNING=$CPU_WARNING_THRESHOLD, CRITICAL=$CPU_THRESHOLD"
  fi

  # Restore original values
  CPU_THRESHOLD=$original_threshold
  CPU_WARNING_THRESHOLD=$original_warning
}

# Test 5: CPU usage with iostat
test_get_cpu_usage_iostat() {
  # Mock iostat command
  mock_iostat "$(generate_iostat_output "25.0")"

  # Mock util_command_exists to return true for iostat only
  # shellcheck disable=SC2317
  util_command_exists() {
    [[ "$1" == "iostat" ]]
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed" &&
    assert_equals "75" "$cpu_usage" "CPU usage should be 75% (100-25)"; then
    test_pass "get_cpu_usage with iostat returns correct value"
  else
    test_fail "get_cpu_usage iostat failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 6: CPU usage with top (macOS)
test_get_cpu_usage_top_macos() {
  # Mock commands
  # shellcheck disable=SC2317
  util_command_exists() {
    [[ "$1" == "top" ]]
  }

  mock_uname "Darwin"
  mock_top "$(generate_top_macos_output "35.2")"

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed" &&
    assert_equals "35.2" "$cpu_usage" "CPU usage should be 35.2%"; then
    test_pass "get_cpu_usage with top (macOS) returns correct value"
  else
    test_fail "get_cpu_usage top macOS failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 7: CPU usage with top (Linux)
test_get_cpu_usage_top_linux() {
  # Mock commands
  # shellcheck disable=SC2317
  util_command_exists() {
    [[ "$1" == "top" ]]
  }

  mock_uname "Linux"
  mock_top "$(generate_top_linux_output "42.8")"

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed" &&
    assert_equals "42.8" "$cpu_usage" "CPU usage should be 42.8%"; then
    test_pass "get_cpu_usage with top (Linux) returns correct value"
  else
    test_fail "get_cpu_usage top Linux failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 8: CPU usage with /proc/stat
test_get_cpu_usage_proc_stat() {
  # Mock commands to not exist
  # shellcheck disable=SC2317
  util_command_exists() {
    false
  }

  # Create mock /proc/stat file
  local proc_stat_file="$TEST_TEMP_DIR/proc_stat"
  mkdir -p "$(dirname "$proc_stat_file")"
  generate_proc_stat_output 1000 100 500 7000 200 50 25 0 >"$proc_stat_file"
  generate_proc_stat_output 1100 110 550 7100 220 55 30 0 >>"$proc_stat_file"

  # Mock file readability check
  [[ -r /proc/stat ]] && {
    # Override awk to read from our test file
    # shellcheck disable=SC2317
    awk() {
      if [[ "$*" == *"/proc/stat"* ]]; then
        command awk "$@" "$proc_stat_file"
      else
        command awk "$@"
      fi
    }
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  # Clean up mock
  unset -f awk

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed with /proc/stat"; then
    test_pass "get_cpu_usage with /proc/stat works"
  else
    test_fail "get_cpu_usage /proc/stat failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 9: CPU usage with sar
# shellcheck disable=SC2317
test_get_cpu_usage_sar() {
  # Mock commands
  util_command_exists() {
    [[ "$1" == "sar" ]]
  }

  # Mock sar command
  sar() {
    generate_sar_output "70.5"
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed" &&
    assert_equals "29.5" "$cpu_usage" "CPU usage should be 29.5% (100-70.5)"; then
    test_pass "get_cpu_usage with sar returns correct value"
  else
    test_fail "get_cpu_usage sar failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 10: CPU usage fallback to load average
# shellcheck disable=SC2317
test_get_cpu_usage_load_fallback() {
  # Mock all commands to not exist except get_load_average
  util_command_exists() {
    false
  }

  # Mock get_load_average function
  get_load_average() {
    echo "2.5"
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed with load fallback" &&
    assert_equals "25.0" "$cpu_usage" "CPU usage should be 25.0% (2.5 * 10)"; then
    test_pass "get_cpu_usage fallback to load average works"
  else
    test_fail "get_cpu_usage load fallback failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 11: CPU usage error handling
# shellcheck disable=SC2317
test_get_cpu_usage_error_handling() {
  # Mock all commands to not exist and no fallback
  util_command_exists() {
    false
  }

  get_load_average() {
    return 1
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 1 $exit_code "get_cpu_usage should fail when no methods available"; then
    test_pass "get_cpu_usage error handling works correctly"
  else
    test_fail "get_cpu_usage should have failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 12: CPU usage over 100% capping
# shellcheck disable=SC2317
test_get_cpu_usage_over_100_percent() {
  # Mock iostat to return impossible value
  mock_iostat "$(
    echo "Device         tps     kB_read/s    kB_wrtn/s     kB_read    kB_wrtn"
    echo "              0.00        0.00         0.00           0      -50.0"
  )"

  util_command_exists() {
    [[ "$1" == "iostat" ]]
  }

  local cpu_usage
  cpu_usage=$(get_cpu_usage)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_cpu_usage should succeed" &&
    assert_equals "100.0" "$cpu_usage" "CPU usage should be capped at 100%"; then
    test_pass "get_cpu_usage caps values over 100%"
  else
    test_fail "get_cpu_usage over 100% test failed: exit_code=$exit_code, cpu_usage='$cpu_usage'"
  fi

  cleanup_mocks
}

# Test 13: Load average with uptime
# shellcheck disable=SC2317
test_get_load_average_uptime() {
  util_command_exists() {
    [[ "$1" == "uptime" ]]
  }

  mock_uptime "$(generate_uptime_output "3.45")"

  local load_avg
  load_avg=$(get_load_average)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "get_load_average should succeed" &&
    assert_equals "3.45" "$load_avg" "Load average should be 3.45"; then
    test_pass "get_load_average with uptime returns correct value"
  else
    test_fail "get_load_average uptime failed: exit_code=$exit_code, load_avg='$load_avg'"
  fi

  cleanup_mocks
}

# Test 14: Load average with /proc/loadavg
# shellcheck disable=SC2317
test_get_load_average_proc() {
  util_command_exists() {
    false
  }

  # Create mock /proc/loadavg file
  local proc_loadavg="$TEST_TEMP_DIR/proc_loadavg"
  echo "2.15 1.98 1.76 3/123 12345" >"$proc_loadavg"

  # Mock file readability and awk
  [[ -r /proc/loadavg ]] && {
    awk() {
      if [[ "$*" == *"/proc/loadavg"* ]]; then
        command awk "$@" "$proc_loadavg"
      else
        command awk "$@"
      fi
    }
  }

  local load_avg
  load_avg=$(get_load_average)
  local exit_code=$?

  unset -f awk

  if assert_exit_code 0 $exit_code "get_load_average should succeed" &&
    assert_equals "2.15" "$load_avg" "Load average should be 2.15"; then
    test_pass "get_load_average with /proc/loadavg returns correct value"
  else
    test_fail "get_load_average /proc/loadavg failed: exit_code=$exit_code, load_avg='$load_avg'"
  fi

  cleanup_mocks
}

# Test 15: CPU plugin check - OK status
# shellcheck disable=SC2317
test_cpu_plugin_check_ok() {
  # Mock get_cpu_usage to return normal value
  get_cpu_usage() {
    echo "45.5"
  }

  get_load_average() {
    echo "1.23"
  }

  local output
  output=$(cpu_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "cpu_plugin_check should succeed" &&
    assert_contains "$output" "STATUS=OK" "Status should be OK" &&
    assert_contains "$output" "VALUE=45.5" "Value should be included" &&
    assert_contains "$output" "LOAD_AVERAGE=1.23" "Load average should be included"; then
    test_pass "cpu_plugin_check returns OK status for normal usage"
  else
    test_fail "cpu_plugin_check OK test failed: exit_code=$exit_code, output='$output'"
  fi

  cleanup_mocks
}

# Test 16: CPU plugin check - WARNING status
# shellcheck disable=SC2317
test_cpu_plugin_check_warning() {
  # Mock get_cpu_usage to return warning level value
  get_cpu_usage() {
    echo "78.0"
  }

  get_load_average() {
    echo "2.45"
  }

  local output
  output=$(cpu_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "cpu_plugin_check should succeed" &&
    assert_contains "$output" "STATUS=WARNING" "Status should be WARNING" &&
    assert_contains "$output" "Elevated CPU usage: 78.0%" "Warning message should be included"; then
    test_pass "cpu_plugin_check returns WARNING status for elevated usage"
  else
    test_fail "cpu_plugin_check WARNING test failed: exit_code=$exit_code, output='$output'"
  fi

  cleanup_mocks
}

# Test 17: CPU plugin check - CRITICAL status
# shellcheck disable=SC2317
test_cpu_plugin_check_critical() {
  # Mock get_cpu_usage to return critical level value
  get_cpu_usage() {
    echo "92.5"
  }

  get_load_average() {
    echo "5.67"
  }

  local output
  output=$(cpu_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "cpu_plugin_check should succeed" &&
    assert_contains "$output" "STATUS=CRITICAL" "Status should be CRITICAL" &&
    assert_contains "$output" "High CPU usage: 92.5%" "Critical message should be included"; then
    test_pass "cpu_plugin_check returns CRITICAL status for high usage"
  else
    test_fail "cpu_plugin_check CRITICAL test failed: exit_code=$exit_code, output='$output'"
  fi

  cleanup_mocks
}

# Test 18: CPU plugin check - ERROR status
# shellcheck disable=SC2317
test_cpu_plugin_check_error() {
  # Mock get_cpu_usage to fail
  get_cpu_usage() {
    return 1
  }

  local output
  output=$(cpu_plugin_check)
  local exit_code=$?

  if assert_exit_code 1 $exit_code "cpu_plugin_check should fail" &&
    assert_contains "$output" "STATUS=ERROR" "Status should be ERROR" &&
    assert_contains "$output" "Failed to retrieve CPU usage" "Error message should be included"; then
    test_pass "cpu_plugin_check returns ERROR status when CPU usage retrieval fails"
  else
    test_fail "cpu_plugin_check ERROR test failed: exit_code=$exit_code, output='$output'"
  fi

  cleanup_mocks
}

# === MAIN TEST EXECUTION ===

run_cpu_plugin_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_cpu_test

  # Run all tests
  test_cpu_plugin_info
  test_cpu_plugin_configure_valid
  test_cpu_plugin_configure_invalid_thresholds
  test_cpu_plugin_configure_threshold_adjustment
  test_get_cpu_usage_iostat
  test_get_cpu_usage_top_macos
  test_get_cpu_usage_top_linux
  test_get_cpu_usage_proc_stat
  test_get_cpu_usage_sar
  test_get_cpu_usage_load_fallback
  test_get_cpu_usage_error_handling
  test_get_cpu_usage_over_100_percent
  test_get_load_average_uptime
  test_get_load_average_proc
  test_cpu_plugin_check_ok
  test_cpu_plugin_check_warning
  test_cpu_plugin_check_critical
  test_cpu_plugin_check_error

  teardown_cpu_test

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  return $TESTS_FAILED
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_cpu_plugin_tests
  exit $?
fi
