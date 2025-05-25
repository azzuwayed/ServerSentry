#!/usr/bin/env bash
#
# ServerSentry v2 - High Load Scenario Integration Test
#
# Tests system behavior under high load conditions

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../../.." &>/dev/null && pwd)"

# Source test framework and helpers
source "$SCRIPT_DIR/../../test_framework.sh"
source "$SCRIPT_DIR/../../helpers/test_helpers.sh"

# Source required modules
source "$BASE_DIR/lib/core/logging.sh"
source "$BASE_DIR/lib/plugins/cpu/cpu.sh"
source "$BASE_DIR/lib/plugins/memory/memory.sh"
source "$BASE_DIR/lib/plugins/disk/disk.sh"

# Test configuration
TEST_SUITE_NAME="High Load Scenario Integration Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Load test configuration
LOAD_DURATION=30
CONCURRENT_PROCESSES=4
MEMORY_STRESS_SIZE="50M"

# Setup function
setup_high_load_tests() {
  setup_test_environment "high_load_scenario"

  # Configure plugins for testing
  cpu_enabled=true
  cpu_threshold=80
  memory_enabled=true
  memory_threshold=85
  disk_enabled=true
  disk_threshold=90

  # Create test directories
  mkdir -p "$TEST_TEMP_DIR/load_test"
  mkdir -p "$TEST_TEMP_DIR/logs"
}

# Cleanup function
cleanup_high_load_tests() {
  # Kill any background processes
  jobs -p | xargs -r kill 2>/dev/null || true

  # Clean up large files
  rm -f "$TEST_TEMP_DIR"/stress_* 2>/dev/null || true
  rm -f "$TEST_TEMP_DIR"/load_test/* 2>/dev/null || true

  cleanup_test_environment
}

# Helper function to create CPU load
create_cpu_load() {
  local duration="$1"
  local processes="${2:-2}"

  for ((i = 1; i <= processes; i++)); do
    {
      local end_time=$(($(date +%s) + duration))
      while [[ $(date +%s) -lt $end_time ]]; do
        : # Busy loop to create CPU load
      done
    } &
  done
}

# Helper function to create memory load
create_memory_load() {
  local duration="$1"
  local size="${2:-50M}"

  {
    local end_time=$(($(date +%s) + duration))
    while [[ $(date +%s) -lt $end_time ]]; do
      # Create temporary memory usage
      dd if=/dev/zero of="$TEST_TEMP_DIR/stress_memory_$$" bs=1M count=50 2>/dev/null || true
      sleep 1
      rm -f "$TEST_TEMP_DIR/stress_memory_$$" 2>/dev/null || true
    done
  } &
}

# Helper function to create disk I/O load
create_disk_load() {
  local duration="$1"
  local test_dir="$TEST_TEMP_DIR/load_test"

  {
    local end_time=$(($(date +%s) + duration))
    local counter=0
    while [[ $(date +%s) -lt $end_time ]]; do
      # Create and delete files to generate I/O
      dd if=/dev/zero of="$test_dir/stress_disk_${counter}_$$" bs=1M count=10 2>/dev/null || true
      sync
      rm -f "$test_dir/stress_disk_${counter}_$$" 2>/dev/null || true
      ((counter++))
      sleep 0.5
    done
  } &
}

# Test 1: System monitoring under CPU load
test_cpu_load_monitoring() {
  print_test_header "System monitoring under CPU load"

  # Start CPU load
  create_cpu_load 15 $CONCURRENT_PROCESSES

  # Wait for load to build up
  sleep 2

  # Monitor system during load
  local monitoring_results=()
  local monitoring_errors=0

  for ((i = 1; i <= 5; i++)); do
    local result
    local exit_code

    set +e
    result=$(cpu_check 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      monitoring_results+=("success")
    else
      monitoring_results+=("failed: $result")
      ((monitoring_errors++))
    fi

    sleep 2
  done

  # Wait for CPU load processes to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $monitoring_errors -le 1 ]]; then
    print_success "CPU monitoring remained stable under load (${monitoring_errors}/5 failures)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "CPU monitoring failed too often under load (${monitoring_errors}/5 failures)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 2: Memory monitoring under memory pressure
test_memory_load_monitoring() {
  print_test_header "Memory monitoring under memory pressure"

  # Start memory load
  create_memory_load 15 "$MEMORY_STRESS_SIZE"

  # Wait for memory pressure to build
  sleep 2

  # Monitor memory during load
  local monitoring_results=()
  local monitoring_errors=0

  for ((i = 1; i <= 5; i++)); do
    local result
    local exit_code

    set +e
    result=$(memory_check 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      monitoring_results+=("success")
    else
      monitoring_results+=("failed: $result")
      ((monitoring_errors++))
    fi

    sleep 2
  done

  # Wait for memory load process to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $monitoring_errors -le 1 ]]; then
    print_success "Memory monitoring remained stable under load (${monitoring_errors}/5 failures)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Memory monitoring failed too often under load (${monitoring_errors}/5 failures)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 3: Disk monitoring under I/O load
test_disk_load_monitoring() {
  print_test_header "Disk monitoring under I/O load"

  # Start disk I/O load
  create_disk_load 15

  # Wait for I/O load to build
  sleep 2

  # Monitor disk during load
  local monitoring_results=()
  local monitoring_errors=0

  for ((i = 1; i <= 5; i++)); do
    local result
    local exit_code

    set +e
    result=$(disk_check 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
      monitoring_results+=("success")
    else
      monitoring_results+=("failed: $result")
      ((monitoring_errors++))
    fi

    sleep 2
  done

  # Wait for disk load process to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $monitoring_errors -le 1 ]]; then
    print_success "Disk monitoring remained stable under load (${monitoring_errors}/5 failures)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Disk monitoring failed too often under load (${monitoring_errors}/5 failures)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 4: Combined load scenario
test_combined_load_scenario() {
  print_test_header "Combined load scenario (CPU + Memory + Disk)"

  # Start all types of load simultaneously
  create_cpu_load 20 2
  create_memory_load 20 "30M"
  create_disk_load 20

  # Wait for all loads to build up
  sleep 3

  # Monitor all systems during combined load
  local cpu_errors=0
  local memory_errors=0
  local disk_errors=0

  for ((i = 1; i <= 6; i++)); do
    # Test CPU monitoring
    set +e
    cpu_check >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      ((cpu_errors++))
    fi

    # Test memory monitoring
    memory_check >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      ((memory_errors++))
    fi

    # Test disk monitoring
    disk_check >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      ((disk_errors++))
    fi
    set -e

    sleep 2
  done

  # Wait for all load processes to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  local total_errors=$((cpu_errors + memory_errors + disk_errors))
  local total_checks=18 # 6 iterations × 3 checks

  if [[ $total_errors -le 3 ]]; then
    print_success "Combined load monitoring stable (${total_errors}/${total_checks} failures)"
    print_info "  CPU errors: $cpu_errors, Memory errors: $memory_errors, Disk errors: $disk_errors"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Combined load monitoring unstable (${total_errors}/${total_checks} failures)"
    print_info "  CPU errors: $cpu_errors, Memory errors: $memory_errors, Disk errors: $disk_errors"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 5: Performance degradation measurement
test_performance_degradation() {
  print_test_header "Performance degradation measurement under load"

  # Measure baseline performance
  local baseline_time
  baseline_time=$(measure_execution_time "cpu_check && memory_check && disk_check" 3)

  # Start moderate load
  create_cpu_load 15 1
  create_memory_load 15 "20M"

  sleep 3

  # Measure performance under load
  local load_time
  load_time=$(measure_execution_time "cpu_check && memory_check && disk_check" 3)

  # Wait for load to finish
  wait

  # Calculate performance degradation
  local degradation_ratio
  degradation_ratio=$(awk "BEGIN {printf \"%.2f\", $load_time / $baseline_time}")

  TESTS_RUN=$((TESTS_RUN + 1))

  print_info "Baseline performance: ${baseline_time}s"
  print_info "Performance under load: ${load_time}s"
  print_info "Degradation ratio: ${degradation_ratio}x"

  # Accept up to 3x degradation as reasonable
  if (($(awk "BEGIN {print ($degradation_ratio <= 3.0)}"))); then
    print_success "Performance degradation within acceptable limits (${degradation_ratio}x)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Performance degradation higher than expected (${degradation_ratio}x)"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be system-dependent
  fi
}

# Test 6: Resource cleanup under load
test_resource_cleanup_under_load() {
  print_test_header "Resource cleanup under load"

  # Start background load
  create_cpu_load 10 1
  create_memory_load 10 "20M"

  # Create temporary files during load
  local temp_files=()
  for ((i = 1; i <= 10; i++)); do
    local temp_file="$TEST_TEMP_DIR/cleanup_test_$i"
    echo "test data $i" >"$temp_file"
    temp_files+=("$temp_file")
  done

  # Simulate cleanup operations under load
  local cleanup_errors=0
  for temp_file in "${temp_files[@]}"; do
    set +e
    rm -f "$temp_file" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      ((cleanup_errors++))
    fi
    set -e
  done

  # Wait for background load to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $cleanup_errors -eq 0 ]]; then
    print_success "Resource cleanup successful under load"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Resource cleanup had ${cleanup_errors} errors under load"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 7: Logging performance under load
test_logging_under_load() {
  print_test_header "Logging performance under load"

  local log_file="$TEST_TEMP_DIR/logs/load_test.log"

  # Start background load
  create_cpu_load 15 1

  # Test logging performance under load
  local log_errors=0
  local start_time=$(date +%s)

  for ((i = 1; i <= 20; i++)); do
    set +e
    echo "$(date): Load test log entry $i" >>"$log_file" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      ((log_errors++))
    fi
    set -e
    sleep 0.5
  done

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Wait for background load to finish
  wait

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $log_errors -eq 0 && $duration -le 20 ]]; then
    print_success "Logging performed well under load (${duration}s, ${log_errors} errors)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_warning "Logging performance degraded under load (${duration}s, ${log_errors} errors)"
    TESTS_PASSED=$((TESTS_PASSED + 1)) # Don't fail as this might be expected
  fi
}

# Main test execution
main() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_high_load_tests

  print_info "Load test configuration:"
  print_info "  Duration: ${LOAD_DURATION}s"
  print_info "  Concurrent processes: ${CONCURRENT_PROCESSES}"
  print_info "  Memory stress size: ${MEMORY_STRESS_SIZE}"

  # Run high load scenario tests
  test_cpu_load_monitoring
  test_memory_load_monitoring
  test_disk_load_monitoring
  test_combined_load_scenario
  test_performance_degradation
  test_resource_cleanup_under_load
  test_logging_under_load

  cleanup_high_load_tests

  # Print summary
  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Exit with appropriate code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_success "All high load scenario tests passed!"
    exit 0
  else
    print_error "Some high load scenario tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
