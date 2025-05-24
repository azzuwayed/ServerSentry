#!/bin/bash
#
# ServerSentry v2 - Performance Utilities
#
# This module provides performance measurement and benchmarking utilities

# Performance tracking configuration
PERFORMANCE_LOG="${BASE_DIR}/logs/performance.log"
BENCHMARK_RESULTS="${BASE_DIR}/logs/benchmark_results.json"

# Create performance log directory
mkdir -p "${BASE_DIR}/logs" 2>/dev/null || true

# Check bash version for associative array support
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  declare -A PERFORMANCE_TIMERS
  declare -A PERFORMANCE_COUNTERS
  PERFORMANCE_TRACKING_SUPPORTED=true
else
  PERFORMANCE_TRACKING_SUPPORTED=false
fi

# Function: util_performance_timer_start
# Description: Start a performance timer
# Parameters:
#   $1 - timer name
# Returns:
#   0 - success
util_performance_timer_start() {
  local timer_name="$1"

  if ! util_require_param "$timer_name" "timer_name"; then
    return 1
  fi

  if [[ "$PERFORMANCE_TRACKING_SUPPORTED" == "true" ]]; then
    PERFORMANCE_TIMERS["${timer_name}_start"]=$(date +%s.%N 2>/dev/null || date +%s)
  fi

  return 0
}

# Function: util_performance_timer_stop
# Description: Stop a performance timer and return duration
# Parameters:
#   $1 - timer name
# Returns:
#   Duration in seconds via stdout
util_performance_timer_stop() {
  local timer_name="$1"

  if ! util_require_param "$timer_name" "timer_name"; then
    return 1
  fi

  if [[ "$PERFORMANCE_TRACKING_SUPPORTED" != "true" ]]; then
    echo "0"
    return 0
  fi

  local start_time="${PERFORMANCE_TIMERS["${timer_name}_start"]:-0}"
  if [[ "$start_time" == "0" ]]; then
    log_warning "Timer not started: $timer_name"
    echo "0"
    return 1
  fi

  local end_time
  end_time=$(date +%s.%N 2>/dev/null || date +%s)

  local duration
  if command -v bc >/dev/null 2>&1; then
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
  else
    duration=$(echo "$end_time - $start_time" | awk '{print $1}' 2>/dev/null || echo "0")
  fi

  # Log performance data
  log_performance "Timer completed" "name=$timer_name duration=${duration}s"

  echo "$duration"
  return 0
}

# Function: util_performance_measure
# Description: Measure performance of a command or function
# Parameters:
#   $1 - operation name
#   $@ - command to execute
# Returns:
#   Command output via stdout, logs performance
util_performance_measure() {
  local operation_name="$1"
  shift
  local command=("$@")

  if ! util_require_param "$operation_name" "operation_name"; then
    return 1
  fi

  if [[ "${#command[@]}" -eq 0 ]]; then
    log_error "No command provided for performance measurement"
    return 1
  fi

  local start_time
  start_time=$(date +%s.%N 2>/dev/null || date +%s)

  # Execute command and capture result
  local result
  local exit_code
  if result=$("${command[@]}" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  local end_time
  end_time=$(date +%s.%N 2>/dev/null || date +%s)

  local duration
  if command -v bc >/dev/null 2>&1; then
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
  else
    duration=$(echo "$end_time - $start_time" | awk '{print $1}' 2>/dev/null || echo "0")
  fi

  # Log performance data
  log_performance "Command execution measured" "operation=$operation_name duration=${duration}s exit_code=$exit_code"

  # Output result
  echo "$result"
  return "$exit_code"
}

# Function: util_performance_counter_increment
# Description: Increment a performance counter
# Parameters:
#   $1 - counter name
#   $2 - increment value (optional, defaults to 1)
# Returns:
#   0 - success
util_performance_counter_increment() {
  local counter_name="$1"
  local increment="${2:-1}"

  if ! util_require_param "$counter_name" "counter_name"; then
    return 1
  fi

  if [[ "$PERFORMANCE_TRACKING_SUPPORTED" == "true" ]]; then
    PERFORMANCE_COUNTERS["$counter_name"]="$((${PERFORMANCE_COUNTERS["$counter_name"]:-0} + increment))"
  fi

  return 0
}

# Function: util_performance_counter_get
# Description: Get current value of a performance counter
# Parameters:
#   $1 - counter name
# Returns:
#   Counter value via stdout
util_performance_counter_get() {
  local counter_name="$1"

  if ! util_require_param "$counter_name" "counter_name"; then
    return 1
  fi

  if [[ "$PERFORMANCE_TRACKING_SUPPORTED" == "true" ]]; then
    echo "${PERFORMANCE_COUNTERS["$counter_name"]:-0}"
  else
    echo "0"
  fi
}

# Function: util_performance_benchmark_system
# Description: Run comprehensive system performance benchmark
# Returns:
#   Benchmark results JSON via stdout
util_performance_benchmark_system() {
  log_info "Running system performance benchmark"

  local benchmark_start
  benchmark_start=$(date +%s.%N 2>/dev/null || date +%s)

  # CPU benchmark - simple calculation test
  local cpu_start
  cpu_start=$(date +%s.%N 2>/dev/null || date +%s)

  local cpu_result=0
  for ((i = 1; i <= 1000; i++)); do
    ((cpu_result += i))
  done

  local cpu_end
  cpu_end=$(date +%s.%N 2>/dev/null || date +%s)
  local cpu_duration
  cpu_duration=$(echo "$cpu_end - $cpu_start" | bc -l 2>/dev/null || echo "0")

  # Memory benchmark - array operations
  local mem_start
  mem_start=$(date +%s.%N 2>/dev/null || date +%s)

  local test_array=()
  for ((i = 1; i <= 100; i++)); do
    test_array+=("test_$i")
  done

  local mem_end
  mem_end=$(date +%s.%N 2>/dev/null || date +%s)
  local mem_duration
  mem_duration=$(echo "$mem_end - $mem_start" | bc -l 2>/dev/null || echo "0")

  # I/O benchmark - file operations
  local io_start
  io_start=$(date +%s.%N 2>/dev/null || date +%s)

  local test_file
  test_file=$(create_temp_file "benchmark")
  for ((i = 1; i <= 50; i++)); do
    echo "test line $i" >>"$test_file"
  done
  local file_content
  file_content=$(cat "$test_file")
  rm -f "$test_file"

  local io_end
  io_end=$(date +%s.%N 2>/dev/null || date +%s)
  local io_duration
  io_duration=$(echo "$io_end - $io_start" | bc -l 2>/dev/null || echo "0")

  # Command execution benchmark
  local cmd_start
  cmd_start=$(date +%s.%N 2>/dev/null || date +%s)

  local os_type
  os_type=$(get_os_type)
  local timestamp
  timestamp=$(get_timestamp)

  local cmd_end
  cmd_end=$(date +%s.%N 2>/dev/null || date +%s)
  local cmd_duration
  cmd_duration=$(echo "$cmd_end - $cmd_start" | bc -l 2>/dev/null || echo "0")

  local benchmark_end
  benchmark_end=$(date +%s.%N 2>/dev/null || date +%s)
  local total_duration
  total_duration=$(echo "$benchmark_end - $benchmark_start" | bc -l 2>/dev/null || echo "0")

  # Create benchmark results JSON
  local results_json
  results_json=$(
    util_json_create_object \
      "timestamp=$timestamp" \
      "total_duration=$total_duration" \
      "cpu_benchmark=$cpu_duration" \
      "memory_benchmark=$mem_duration" \
      "io_benchmark=$io_duration" \
      "command_benchmark=$cmd_duration" \
      "system_type=$os_type"
  )

  # Save results to file
  echo "$results_json" >"$BENCHMARK_RESULTS"

  # Log benchmark completion
  log_performance "System benchmark completed" "total_duration=${total_duration}s cpu=${cpu_duration}s mem=${mem_duration}s io=${io_duration}s cmd=${cmd_duration}s"

  echo "$results_json"
  return 0
}

# Function: util_performance_get_stats
# Description: Get performance statistics summary
# Returns:
#   Performance stats JSON via stdout
util_performance_get_stats() {
  local stats_json="{"

  # Get recent performance data from log
  if [[ -f "$PERFORMANCE_LOG" ]]; then
    local total_operations
    total_operations=$(grep -c "MEASURE\|TIMER" "$PERFORMANCE_LOG" 2>/dev/null || echo "0")

    local avg_duration="0"
    if [[ "$total_operations" -gt 0 ]] && command -v awk >/dev/null 2>&1; then
      avg_duration=$(grep "duration=" "$PERFORMANCE_LOG" |
        awk -F'duration=' '{print $2}' |
        awk -F's' '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}' 2>/dev/null || echo "0")
    fi

    stats_json+="\"total_operations\":$total_operations,"
    stats_json+="\"average_duration\":$avg_duration,"
  else
    stats_json+="\"total_operations\":0,"
    stats_json+="\"average_duration\":0,"
  fi

  # Add counter data if available
  if [[ "$PERFORMANCE_TRACKING_SUPPORTED" == "true" ]]; then
    stats_json+="\"counters\":{"
    local first=true
    for counter in "${!PERFORMANCE_COUNTERS[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        stats_json+=","
      fi
      stats_json+="\"$counter\":${PERFORMANCE_COUNTERS[$counter]}"
    done
    stats_json+="},"
  else
    stats_json+="\"counters\":{},"
  fi

  # Add latest benchmark results if available
  if [[ -f "$BENCHMARK_RESULTS" ]]; then
    local benchmark_data
    benchmark_data=$(cat "$BENCHMARK_RESULTS" 2>/dev/null || echo "{}")
    stats_json+="\"latest_benchmark\":$benchmark_data"
  else
    stats_json+="\"latest_benchmark\":{}"
  fi

  stats_json+="}"
  echo "$stats_json"
}

# Function: util_performance_cleanup_logs
# Description: Clean up old performance logs
# Parameters:
#   $1 - days to keep (defaults to 7)
# Returns:
#   0 - success
util_performance_cleanup_logs() {
  local days_to_keep="${1:-7}"

  if [[ -f "$PERFORMANCE_LOG" ]]; then
    local cutoff_date
    cutoff_date=$(date -d "$days_to_keep days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    local temp_log
    temp_log=$(create_temp_file "perf_cleanup")

    if awk -v cutoff="$cutoff_date" '$0 > cutoff' "$PERFORMANCE_LOG" >"$temp_log" 2>/dev/null; then
      mv "$temp_log" "$PERFORMANCE_LOG"
      log_debug "Cleaned up performance logs older than $days_to_keep days"
    else
      rm -f "$temp_log"
    fi
  fi

  return 0
}

# Function: util_performance_optimize_startup
# Description: Run startup optimization sequence
# Returns:
#   0 - success
util_performance_optimize_startup() {
  log_debug "Running startup performance optimizations"

  # Pre-cache common commands
  if declare -f util_optimize_common_commands >/dev/null 2>&1; then
    util_optimize_common_commands
  fi

  # Clean up old cache entries
  if declare -f util_command_cache_cleanup >/dev/null 2>&1; then
    util_command_cache_cleanup 3600 # 1 hour
  fi

  # Initialize performance counters
  util_performance_counter_increment "startup_optimizations" 1

  log_debug "Startup optimizations completed"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_performance_timer_start
  export -f util_performance_timer_stop
  export -f util_performance_measure
  export -f util_performance_counter_increment
  export -f util_performance_counter_get
  export -f util_performance_benchmark_system
  export -f util_performance_get_stats
  export -f util_performance_cleanup_logs
  export -f util_performance_optimize_startup
fi
