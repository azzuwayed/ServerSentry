#!/usr/bin/env bash
#
# ServerSentry v2 - Performance Benchmark Tests
#
# Tests performance characteristics of core components

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source test framework and helpers
source "$SCRIPT_DIR/../test_framework.sh"
source "$SCRIPT_DIR/../helpers/test_helpers.sh"

# Source required modules
source "$BASE_DIR/lib/core/logging.sh"
source "$BASE_DIR/lib/core/utils/config_utils.sh"
source "$BASE_DIR/lib/plugins/cpu/cpu.sh"
source "$BASE_DIR/lib/plugins/memory/memory.sh"

# Test configuration
TEST_SUITE_NAME="Performance Benchmark Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Performance thresholds (in seconds)
CONFIG_PARSE_THRESHOLD=0.100
PLUGIN_EXECUTION_THRESHOLD=0.500
JSON_PROCESSING_THRESHOLD=0.050

# Setup function
setup_performance_tests() {
  setup_test_environment "performance_benchmark"

  # Create test configuration files
  cp "$SCRIPT_DIR/../fixtures/configs/test_config_basic.yaml" "$TEST_CONFIG_DIR/benchmark_config.yaml"

  # Generate test data
  generate_test_metrics "system" "normal" >"$TEST_TEMP_DIR/test_metrics.json"
}

# Cleanup function
cleanup_performance_tests() {
  cleanup_test_environment
}

# Performance test assertion
assert_performance() {
  local test_name="$1"
  local actual_time="$2"
  local threshold="$3"
  local message="${4:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  print_test_header "$test_name"

  if (($(awk "BEGIN {print ($actual_time <= $threshold)}"))); then
    print_success "Performance test passed: ${actual_time}s <= ${threshold}s"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    print_error "Performance test failed: ${actual_time}s > ${threshold}s"
    if [[ -n "$message" ]]; then
      print_warning "$message"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Test 1: Configuration parsing performance
test_config_parsing_performance() {
  local config_file="$TEST_CONFIG_DIR/benchmark_config.yaml"
  local iterations=10

  # Warm up
  util_config_parse_yaml "$config_file" "warmup_config" >/dev/null 2>&1 || true

  # Measure performance
  local execution_time
  execution_time=$(measure_execution_time "util_config_parse_yaml '$config_file' 'benchmark_config'" "$iterations")

  assert_performance "Configuration parsing" "$execution_time" "$CONFIG_PARSE_THRESHOLD" \
    "Config parsing should be fast for responsive system startup"
}

# Test 2: CPU plugin performance
test_cpu_plugin_performance() {
  local iterations=5

  # Warm up
  cpu_check >/dev/null 2>&1 || true

  # Measure performance
  local execution_time
  execution_time=$(measure_execution_time "cpu_check" "$iterations")

  assert_performance "CPU plugin execution" "$execution_time" "$PLUGIN_EXECUTION_THRESHOLD" \
    "CPU monitoring should complete quickly to avoid system impact"
}

# Test 3: Memory plugin performance
test_memory_plugin_performance() {
  local iterations=5

  # Warm up
  memory_check >/dev/null 2>&1 || true

  # Measure performance
  local execution_time
  execution_time=$(measure_execution_time "memory_check" "$iterations")

  assert_performance "Memory plugin execution" "$execution_time" "$PLUGIN_EXECUTION_THRESHOLD" \
    "Memory monitoring should complete quickly to avoid system impact"
}

# Test 4: JSON processing performance
test_json_processing_performance() {
  local test_json="$TEST_TEMP_DIR/test_metrics.json"
  local iterations=20

  # Test JSON parsing with jq
  if command -v jq >/dev/null 2>&1; then
    local execution_time
    execution_time=$(measure_execution_time "jq '.plugins[0].metrics.usage_percent' '$test_json'" "$iterations")

    assert_performance "JSON processing" "$execution_time" "$JSON_PROCESSING_THRESHOLD" \
      "JSON processing should be fast for real-time monitoring"
  else
    print_warning "jq not available, skipping JSON processing test"
    TESTS_RUN=$((TESTS_RUN + 1))
  fi
}

# Test 5: Memory usage during operations
test_memory_usage() {
  local max_memory_kb=10240 # 10MB threshold

  print_test_header "Memory usage during operations"

  # Start a background process that runs multiple checks
  {
    for i in {1..10}; do
      cpu_check >/dev/null 2>&1 || true
      memory_check >/dev/null 2>&1 || true
      sleep 0.1
    done
  } &

  local bg_pid=$!
  local memory_usage
  memory_usage=$(monitor_memory_usage "$bg_pid" 5 0.5)

  wait "$bg_pid"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$memory_usage" -le "$max_memory_kb" ]]; then
    print_success "Memory usage test passed: ${memory_usage}KB <= ${max_memory_kb}KB"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Memory usage test failed: ${memory_usage}KB > ${max_memory_kb}KB"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 6: Concurrent execution performance
test_concurrent_execution() {
  local concurrent_jobs=4
  local iterations=3

  print_test_header "Concurrent execution performance"

  # Create test scripts for parallel execution
  local test_scripts=()
  for ((i = 1; i <= concurrent_jobs; i++)); do
    local script_file="$TEST_TEMP_DIR/concurrent_test_$i.sh"
    cat >"$script_file" <<'EOF'
#!/usr/bin/env bash
for j in {1..5}; do
  echo "test output" >/dev/null
  sleep 0.1
done
EOF
    chmod +x "$script_file"
    test_scripts+=("$script_file")
  done

  # Measure sequential execution
  local start_time=$(date +%s.%N)
  for script in "${test_scripts[@]}"; do
    "$script"
  done
  local sequential_time=$(date +%s.%N)
  local sequential_duration=$(awk "BEGIN {printf \"%.3f\", $sequential_time - $start_time}")

  # Measure parallel execution
  start_time=$(date +%s.%N)
  for script in "${test_scripts[@]}"; do
    "$script" &
  done
  wait
  local parallel_time=$(date +%s.%N)
  local parallel_duration=$(awk "BEGIN {printf \"%.3f\", $parallel_time - $start_time}")

  # Calculate speedup
  local speedup=$(awk "BEGIN {printf \"%.2f\", $sequential_duration / $parallel_duration}")

  TESTS_RUN=$((TESTS_RUN + 1))

  print_info "Sequential execution: ${sequential_duration}s"
  print_info "Parallel execution: ${parallel_duration}s"
  print_info "Speedup: ${speedup}x"

  # Expect at least 2x speedup for 4 concurrent jobs
  if (($(awk "BEGIN {print ($speedup >= 2.0)}"))); then
    print_success "Concurrent execution test passed: ${speedup}x speedup"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Concurrent execution test failed: ${speedup}x speedup < 2.0x"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 7: Load testing with multiple metrics
test_load_performance() {
  local load_duration=10
  local check_interval=0.5
  local max_avg_time=0.200

  print_test_header "Load testing with continuous monitoring"

  local total_checks=0
  local total_time=0
  local start_time=$(date +%s)
  local end_time=$((start_time + load_duration))

  while [[ $(date +%s) -lt $end_time ]]; do
    local check_start=$(date +%s.%N)

    # Simulate monitoring check
    cpu_check >/dev/null 2>&1 || true
    memory_check >/dev/null 2>&1 || true

    local check_end=$(date +%s.%N)
    local check_duration=$(awk "BEGIN {printf \"%.3f\", $check_end - $check_start}")

    total_time=$(awk "BEGIN {printf \"%.3f\", $total_time + $check_duration}")
    ((total_checks++))

    sleep "$check_interval"
  done

  local avg_time=$(awk "BEGIN {printf \"%.3f\", $total_time / $total_checks}")

  TESTS_RUN=$((TESTS_RUN + 1))

  print_info "Total checks: $total_checks"
  print_info "Average check time: ${avg_time}s"

  if (($(awk "BEGIN {print ($avg_time <= $max_avg_time)}"))); then
    print_success "Load performance test passed: ${avg_time}s <= ${max_avg_time}s"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_error "Load performance test failed: ${avg_time}s > ${max_avg_time}s"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Main test execution
main() {
  print_test_suite_header "$TEST_SUITE_NAME"

  setup_performance_tests

  # Run performance tests
  test_config_parsing_performance
  test_cpu_plugin_performance
  test_memory_plugin_performance
  test_json_processing_performance
  test_memory_usage
  test_concurrent_execution
  test_load_performance

  cleanup_performance_tests

  # Print summary
  print_test_suite_summary "$TEST_SUITE_NAME" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

  # Exit with appropriate code
  if [[ $TESTS_FAILED -eq 0 ]]; then
    print_success "All performance benchmarks passed!"
    exit 0
  else
    print_error "Some performance benchmarks failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
