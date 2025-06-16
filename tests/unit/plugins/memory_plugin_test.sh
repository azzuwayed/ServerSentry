#!/usr/bin/env bash
#
# ServerSentry v2 - Memory Plugin Comprehensive Unit Tests
#
# Tests all memory plugin functions with extensive edge case coverage and error conditions
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
source "$SERVERSENTRY_ROOT/lib/plugins/memory/memory.sh"

# Test configuration
TEST_SUITE_NAME="Memory Plugin Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===



# === MOCK DATA GENERATORS ===

generate_proc_meminfo() {
  local total_kb="${1:-8388608}"     # 8GB default
  local available_kb="${2:-4194304}" # 4GB available
  local free_kb="${3:-2097152}"      # 2GB free
  local buffers_kb="${4:-524288}"    # 512MB buffers
  local cached_kb="${5:-1572864}"    # 1.5GB cached

  cat <<EOF
MemTotal:        $total_kb kB
MemFree:         $free_kb kB
MemAvailable:    $available_kb kB
Buffers:         $buffers_kb kB
Cached:          $cached_kb kB
SwapCached:            0 kB
Active:          3145728 kB
Inactive:        1048576 kB
Active(anon):    2097152 kB
Inactive(anon):   524288 kB
Active(file):    1048576 kB
Inactive(file):   524288 kB
Unevictable:           0 kB
Mlocked:               0 kB
SwapTotal:       2097152 kB
SwapFree:        2097152 kB
Dirty:              1024 kB
Writeback:             0 kB
AnonPages:       2097152 kB
Mapped:           524288 kB
Shmem:             65536 kB
EOF
}

generate_free_output() {
  local total="${1:-8388608}"
  local used="${2:-4194304}"
  local free="${3:-2097152}"
  local shared="${4:-65536}"
  local buffers="${5:-524288}"
  local cached="${6:-1572864}"
  local available="${7:-4194304}"

  cat <<EOF
              total        used        free      shared  buff/cache   available
Mem:        $total     $used     $free      $shared     $((buffers + cached))     $available
Swap:      2097152           0     2097152
EOF
}

generate_vm_stat_output() {
  local pages_free="${1:-512000}"
  local pages_active="${2:-1024000}"
  local pages_inactive="${3:-384000}"
  local pages_speculative="${4:-128000}"
  local pages_wired="${5:-256000}"

  cat <<EOF
Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                     $pages_free.
Pages active:                   $pages_active.
Pages inactive:                 $pages_inactive.
Pages speculative:              $pages_speculative.
Pages throttled:                        0.
Pages wired down:               $pages_wired.
Pages purgeable:                    12345.
"Translation faults":           123456789.
Pages copy-on-write:             12345678.
Pages zero filled:              987654321.
Pages reactivated:               12345678.
Pages purged:                     1234567.
File-backed pages:               1234567.
Anonymous pages:                 2345678.
Pages stored in compressor:       123456.
Pages occupied by compressor:      12345.
Decompressions:                   123456.
Compressions:                     654321.
Pageins:                         1234567.
Pageouts:                         123456.
Swapins:                               0.
Swapouts:                              0.
EOF
}

generate_compat_memory_info() {
  local total_mb="${1:-8192}"
  local used_mb="${2:-4096}"
  local free_mb="${3:-4096}"

  echo "total:$total_mb used:$used_mb free:$free_mb"
}

# === SETUP AND TEARDOWN ===

setup_memory_test() {
  setup_test_environment "memory_plugin_test"

  # Reset memory plugin variables to defaults
  memory_threshold=90
  memory_warning_threshold=80
  memory_check_interval=60
  memory_include_swap=true
  memory_include_buffers_cache=false

  # Clean up any existing mocks
  cleanup_mocks
}

teardown_memory_test() {
  cleanup_test_environment
}

# === TEST FUNCTIONS ===

# Test 1: Plugin info function
test_memory_plugin_info() {
  local info_output
  info_output=$(memory_plugin_info)

  if assert_contains "$info_output" "Memory Monitoring Plugin" "Plugin info should contain plugin name" &&
    assert_contains "$info_output" "$memory_plugin_version" "Plugin info should contain version"; then
    test_pass "memory_plugin_info returns correct information"
  else
    test_fail "memory_plugin_info output: $info_output"
  fi
}

# Test 2: Plugin configuration with valid config
test_memory_plugin_configure_valid() {
  local temp_config="$TEST_TEMP_DIR/valid_config.conf"
  create_test_config "$temp_config" \
    "memory_threshold=85" \
    "memory_warning_threshold=70" \
    "memory_include_swap=false" \
    "memory_include_buffers_cache=true"

  local original_threshold=$memory_threshold
  local original_warning=$memory_warning_threshold
  local original_swap=$memory_include_swap
  local original_buffers=$memory_include_buffers_cache

  if memory_plugin_configure "$temp_config"; then
    if assert_equals "85" "$memory_threshold" "memory_threshold should be 85" &&
      assert_equals "70" "$memory_warning_threshold" "memory_warning_threshold should be 70" &&
      assert_equals "false" "$memory_include_swap" "memory_include_swap should be false" &&
      assert_equals "true" "$memory_include_buffers_cache" "memory_include_buffers_cache should be true"; then
      test_pass "memory_plugin_configure loads valid configuration"
    else
      test_fail "Configuration not loaded correctly"
    fi
  else
    test_fail "memory_plugin_configure failed with valid config"
  fi

  # Restore original values
  memory_threshold=$original_threshold
  memory_warning_threshold=$original_warning
  memory_include_swap=$original_swap
  memory_include_buffers_cache=$original_buffers
}

# Test 3: Plugin configuration with invalid thresholds
test_memory_plugin_configure_invalid_thresholds() {
  local temp_config="$TEST_TEMP_DIR/invalid_config.conf"
  create_test_config "$temp_config" \
    "memory_threshold=150" \
    "memory_warning_threshold=200"

  local exit_code
  memory_plugin_configure "$temp_config" 2>/dev/null
  exit_code=$?

  if assert_exit_code 1 $exit_code "memory_plugin_configure should fail with invalid thresholds"; then
    test_pass "memory_plugin_configure handles invalid thresholds correctly"
  else
    test_fail "memory_plugin_configure should have failed with invalid thresholds"
  fi
}

# Test 4: Plugin configuration threshold swapping
test_memory_plugin_configure_threshold_swapping() {
  local temp_config="$TEST_TEMP_DIR/swap_config.conf"
  create_test_config "$temp_config" \
    "memory_threshold=70" \
    "memory_warning_threshold=85"

  local original_threshold=$memory_threshold
  local original_warning=$memory_warning_threshold

  memory_plugin_configure "$temp_config" 2>/dev/null

  if assert_equals "85" "$memory_threshold" "Thresholds should be swapped - critical should be 85" &&
    assert_equals "70" "$memory_warning_threshold" "Thresholds should be swapped - warning should be 70"; then
    test_pass "memory_plugin_configure swaps thresholds when warning > critical"
  else
    test_fail "Threshold swapping failed: threshold=$memory_threshold, warning=$memory_warning_threshold"
  fi

  # Restore original values
  memory_threshold=$original_threshold
  memory_warning_threshold=$original_warning
}

# Test 5: Memory check with compatibility layer
test_memory_plugin_check_compat_layer() {
  # Mock compatibility layer
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "6553" "1639" # ~80% usage
  }

  local output
  output=$(memory_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "memory_plugin_check should succeed" &&
    assert_json_valid "$output" "Output should be valid JSON"; then

    # Extract values using jq if available, otherwise basic checks
    if util_command_exists jq; then
      local usage_percent
      usage_percent=$(echo "$output" | jq -r '.metrics.usage_percent')
      if assert_equals "80.0" "$usage_percent" "Usage should be 80%"; then
        test_pass "memory_plugin_check with compatibility layer works correctly"
      else
        test_fail "Incorrect usage calculation: $usage_percent"
      fi
    else
      if assert_contains "$output" '"usage_percent": 80.0' "Output should contain 80% usage"; then
        test_pass "memory_plugin_check with compatibility layer works correctly"
      else
        test_fail "Output doesn't contain expected usage: $output"
      fi
    fi
  else
    test_fail "memory_plugin_check compat layer failed: exit_code=$exit_code, output='$output'"
  fi

  cleanup_mocks
}

# Test 6: Memory check with Linux /proc/meminfo
test_memory_plugin_check_linux_proc() {
  # Mock OS detection
  compat_get_os() {
    echo "linux"
  }

  # Mock compatibility layer to fail
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  # Create mock /proc/meminfo
  local proc_meminfo="$TEST_TEMP_DIR/proc_meminfo"
  generate_proc_meminfo "8388608" "2097152" "1048576" "524288" "1572864" >"$proc_meminfo"

  # Mock file readability and awk
  [[ -r /proc/meminfo ]] && {
    awk() {
      if [[ "$*" == *"/proc/meminfo"* ]]; then
        command awk "$@" "$proc_meminfo"
      else
        command awk "$@"
      fi
    }
  }

  local output
  output=$(memory_plugin_check)
  local exit_code=$?

  unset -f awk

  if assert_exit_code 0 $exit_code "memory_plugin_check should succeed" &&
    assert_json_valid "$output" "Output should be valid JSON"; then
    test_pass "memory_plugin_check with Linux /proc/meminfo works"
  else
    test_fail "memory_plugin_check Linux proc failed: exit_code=$exit_code"
  fi

  cleanup_mocks
}

# Test 7: Memory check with Linux free command
test_memory_plugin_check_linux_free() {
  # Mock OS detection
  compat_get_os() {
    echo "linux"
  }

  # Mock compatibility layer to fail
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  # Mock /proc/meminfo to not exist
  [[ -r /proc/meminfo ]] && {
    return 1
  }

  # Mock util_command_exists for free
  util_command_exists() {
    [[ "$1" == "free" ]]
  }

  # Mock free command
  mock_free "$(generate_free_output "8388608" "6291456" "1048576" "65536" "524288" "1572864" "2097152")"

  local output
  output=$(memory_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "memory_plugin_check should succeed" &&
    assert_json_valid "$output" "Output should be valid JSON"; then
    test_pass "memory_plugin_check with Linux free command works"
  else
    test_fail "memory_plugin_check Linux free failed: exit_code=$exit_code"
  fi

  cleanup_mocks
}

# Test 8: Memory check with macOS vm_stat and sysctl
test_memory_plugin_check_macos() {
  # Mock OS detection
  compat_get_os() {
    echo "macos"
  }

  # Mock compatibility layer to fail
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  # Mock util_command_exists
  util_command_exists() {
    [[ "$1" == "vm_stat" ]] || [[ "$1" == "sysctl" ]]
  }

  # Mock vm_stat and sysctl
  mock_vm_stat "$(generate_vm_stat_output "512000" "1024000" "384000" "128000" "256000")"
  mock_sysctl "4096" # page size

  # Override sysctl for different calls
  sysctl() {
    case "$*" in
    *hw.pagesize*) echo "4096" ;;
    *hw.memsize*) echo "8589934592" ;; # 8GB in bytes
    *) echo "unknown" ;;
    esac
  }

  local output
  output=$(memory_plugin_check)
  local exit_code=$?

  if assert_exit_code 0 $exit_code "memory_plugin_check should succeed" &&
    assert_json_valid "$output" "Output should be valid JSON"; then
    test_pass "memory_plugin_check with macOS vm_stat/sysctl works"
  else
    test_fail "memory_plugin_check macOS failed: exit_code=$exit_code"
  fi

  cleanup_mocks
}

# Test 9: Memory check status codes - OK
test_memory_plugin_check_status_ok() {
  # Mock compatibility layer with low usage
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "4096" "4096" # 50% usage
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_contains "$output" "status_code" "0" "Status code should be 0 (OK)"; then
    test_pass "memory_plugin_check returns OK status for normal usage"
  else
    test_fail "memory_plugin_check OK status test failed: $output"
  fi

  cleanup_mocks
}

# Test 10: Memory check status codes - WARNING
test_memory_plugin_check_status_warning() {
  # Mock compatibility layer with warning level usage
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "6963" "1229" # 85% usage (above 80% warning)
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_contains "$output" "status_code" "1" "Status code should be 1 (WARNING)"; then
    test_pass "memory_plugin_check returns WARNING status for elevated usage"
  else
    test_fail "memory_plugin_check WARNING status test failed: $output"
  fi

  cleanup_mocks
}

# Test 11: Memory check status codes - CRITICAL
test_memory_plugin_check_status_critical() {
  # Mock compatibility layer with critical level usage
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "7372" "820" # 90% usage (above 90% critical)
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_contains "$output" "status_code" "2" "Status code should be 2 (CRITICAL)"; then
    test_pass "memory_plugin_check returns CRITICAL status for high usage"
  else
    test_fail "memory_plugin_check CRITICAL status test failed: $output"
  fi

  cleanup_mocks
}

# Test 12: Memory check with swap handling
test_memory_plugin_check_swap_handling() {
  # Enable swap monitoring
  memory_include_swap=true

  # Mock compatibility layer
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "4096" "4096"
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_valid "$output" "Output should be valid JSON" &&
    assert_contains "$output" '"swap_total"' "Output should contain swap information"; then
    test_pass "memory_plugin_check handles swap monitoring correctly"
  else
    test_fail "memory_plugin_check swap handling failed: $output"
  fi

  cleanup_mocks
}

# Test 13: Memory check with buffers/cache inclusion
test_memory_plugin_check_buffers_cache() {
  # Enable buffers/cache inclusion
  memory_include_buffers_cache=true

  # Mock OS detection
  compat_get_os() {
    echo "linux"
  }

  # Mock compatibility layer to fail
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  # Create mock /proc/meminfo with significant buffers/cache
  local proc_meminfo="$TEST_TEMP_DIR/proc_meminfo"
  generate_proc_meminfo "8388608" "2097152" "1048576" "1048576" "2097152" >"$proc_meminfo"

  # Mock file readability and awk
  [[ -r /proc/meminfo ]] && {
    awk() {
      if [[ "$*" == *"/proc/meminfo"* ]]; then
        command awk "$@" "$proc_meminfo"
      else
        command awk "$@"
      fi
    }
  }

  local output
  output=$(memory_plugin_check)

  unset -f awk

  if assert_json_valid "$output" "Output should be valid JSON"; then
    test_pass "memory_plugin_check handles buffers/cache inclusion correctly"
  else
    test_fail "memory_plugin_check buffers/cache test failed: $output"
  fi

  cleanup_mocks
}

# Test 14: Memory check error handling - no methods available
test_memory_plugin_check_error_no_methods() {
  # Mock OS detection to unsupported
  compat_get_os() {
    echo "unknown"
  }

  # Mock compatibility layer to fail
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_contains "$output" "status_code" "3" "Status code should be 3 (UNKNOWN/ERROR)"; then
    test_pass "memory_plugin_check handles unsupported OS correctly"
  else
    test_fail "memory_plugin_check error handling failed: $output"
  fi

  cleanup_mocks
}

# Test 15: Memory check with zero memory edge case
test_memory_plugin_check_zero_memory() {
  # Mock compatibility layer with zero values
  compat_get_memory_info() {
    echo "total:0 used:0 free:0"
  }

  local output
  output=$(memory_plugin_check)

  if assert_json_contains "$output" "status_code" "3" "Status code should be 3 for zero memory"; then
    test_pass "memory_plugin_check handles zero memory edge case"
  else
    test_fail "memory_plugin_check zero memory test failed: $output"
  fi

  cleanup_mocks
}

# Test 16: JSON output validation
test_memory_plugin_check_json_validation() {
  # Mock compatibility layer
  compat_get_memory_info() {
    generate_compat_memory_info "8192" "4096" "4096"
  }

  local output
  output=$(memory_plugin_check)

  # Validate JSON structure
  if assert_json_valid "$output" "Output should be valid JSON" &&
    assert_json_contains "$output" "plugin" "memory" "Should contain plugin name" &&
    assert_json_contains "$output" "metrics" "" "Should contain metrics object" &&
    assert_contains "$output" '"timestamp"' "Should contain timestamp"; then
    test_pass "memory_plugin_check produces valid JSON output"
  else
    test_fail "memory_plugin_check JSON validation failed: $output"
  fi

  cleanup_mocks
}

# === MAIN TEST EXECUTION ===

run_memory_plugin_tests() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_memory_test

  # Run all tests
  test_memory_plugin_info
  test_memory_plugin_configure_valid
  test_memory_plugin_configure_invalid_thresholds
  test_memory_plugin_configure_threshold_swapping
  test_memory_plugin_check_compat_layer
  test_memory_plugin_check_linux_proc
  test_memory_plugin_check_linux_free
  test_memory_plugin_check_macos
  test_memory_plugin_check_status_ok
  test_memory_plugin_check_status_warning
  test_memory_plugin_check_status_critical
  test_memory_plugin_check_swap_handling
  test_memory_plugin_check_buffers_cache
  test_memory_plugin_check_error_no_methods
  test_memory_plugin_check_zero_memory
  test_memory_plugin_check_json_validation

  teardown_memory_test

  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  return $TESTS_FAILED
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_memory_plugin_tests
  exit $?
fi
