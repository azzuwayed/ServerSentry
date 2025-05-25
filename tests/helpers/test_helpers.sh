#!/usr/bin/env bash
#
# ServerSentry v2 - Enhanced Test Helpers
#
# Shared utilities and helpers for all test suites

# Prevent multiple sourcing
if [[ "${TEST_HELPERS_LOADED:-}" == "true" ]]; then
  return 0
fi
TEST_HELPERS_LOADED=true
export TEST_HELPERS_LOADED

# === ENHANCED MOCKING SYSTEM ===

# Create a mock HTTP server for testing external services
create_http_mock() {
  local port="${1:-8080}"
  local responses_file="${2:-}"
  local mock_pid_file="${TEST_TEMP_DIR}/mock_server.pid"

  # Simple HTTP mock server using netcat
  if command -v nc >/dev/null 2>&1; then
    {
      while true; do
        if [[ -f "$responses_file" ]]; then
          cat "$responses_file"
        else
          echo -e "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\n{\"ok\": true}"
        fi
      done | nc -l "$port"
    } &
    echo $! >"$mock_pid_file"
    echo "Mock HTTP server started on port $port (PID: $!)"
  else
    log_warning "netcat not available, skipping HTTP mock"
    return 1
  fi
}

# Stop mock HTTP server
stop_http_mock() {
  local mock_pid_file="${TEST_TEMP_DIR}/mock_server.pid"

  if [[ -f "$mock_pid_file" ]]; then
    local pid=$(cat "$mock_pid_file")
    if kill "$pid" 2>/dev/null; then
      log_info "Mock HTTP server stopped (PID: $pid)"
    fi
    rm -f "$mock_pid_file"
  fi
}

# Create mock service responses
create_mock_responses() {
  local service_name="$1"
  local response_type="${2:-success}"
  local responses_file="${TEST_TEMP_DIR}/${service_name}_responses.txt"

  case "$service_name" in
  "slack")
    case "$response_type" in
    "success")
      cat >"$responses_file" <<'EOF'
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 7

{"ok": true}
EOF
      ;;
    "error")
      cat >"$responses_file" <<'EOF'
HTTP/1.1 400 Bad Request
Content-Type: application/json
Content-Length: 35

{"ok": false, "error": "invalid_token"}
EOF
      ;;
    esac
    ;;
  "teams")
    case "$response_type" in
    "success")
      cat >"$responses_file" <<'EOF'
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 1

1
EOF
      ;;
    esac
    ;;
  esac

  echo "$responses_file"
}

# === TEST DATA GENERATORS ===

# Generate random configuration for property-based testing
generate_random_config() {
  local config_type="${1:-basic}"
  local config_file="${TEST_TEMP_DIR}/random_config_$(date +%s).yaml"

  case "$config_type" in
  "monitoring")
    cat >"$config_file" <<EOF
enabled: $(shuf -e true false -n 1)
log_level: $(shuf -e debug info warning error -n 1)
check_interval: $(shuf -i 30-300 -n 1)
timeout: $(shuf -i 10-120 -n 1)

monitoring:
  cpu:
    enabled: $(shuf -e true false -n 1)
    threshold: $(shuf -i 50-95 -n 1)
  memory:
    enabled: $(shuf -e true false -n 1)
    threshold: $(shuf -i 60-95 -n 1)
  disk:
    enabled: $(shuf -e true false -n 1)
    threshold: $(shuf -i 70-98 -n 1)
EOF
    ;;
  "notifications")
    cat >"$config_file" <<EOF
notifications:
  email:
    enabled: $(shuf -e true false -n 1)
    smtp_host: smtp$(shuf -i 1-5 -n 1).example.com
    smtp_port: $(shuf -e 25 587 465 -n 1)
  slack:
    enabled: $(shuf -e true false -n 1)
    channel: "#$(shuf -e alerts monitoring system -n 1)"
  teams:
    enabled: $(shuf -e true false -n 1)
EOF
    ;;
  esac

  echo "$config_file"
}

# Generate test metrics data
generate_test_metrics() {
  local metric_type="${1:-system}"
  local values_range="${2:-normal}"

  case "$values_range" in
  "normal")
    local cpu_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 30 + 20}")
    local memory_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 40 + 30}")
    local disk_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 30 + 40}")
    ;;
  "high")
    local cpu_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 20 + 80}")
    local memory_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 15 + 85}")
    local disk_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 10 + 90}")
    ;;
  "critical")
    local cpu_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 5 + 95}")
    local memory_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 5 + 95}")
    local disk_usage=$(awk "BEGIN {printf \"%.1f\", rand() * 3 + 97}")
    ;;
  esac

  cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "test-server-$(shuf -i 1-10 -n 1)",
  "plugins": [
    {
      "name": "cpu",
      "status": 0,
      "metrics": {
        "usage_percent": $cpu_usage,
        "load_1m": $(awk "BEGIN {printf \"%.2f\", rand() * 2 + 0.5}"),
        "load_5m": $(awk "BEGIN {printf \"%.2f\", rand() * 1.5 + 0.3}"),
        "load_15m": $(awk "BEGIN {printf \"%.2f\", rand() * 1 + 0.2}")
      }
    },
    {
      "name": "memory",
      "status": 0,
      "metrics": {
        "usage_percent": $memory_usage,
        "used_gb": $(awk "BEGIN {printf \"%.1f\", $memory_usage * 16 / 100}"),
        "total_gb": 16.0,
        "available_gb": $(awk "BEGIN {printf \"%.1f\", 16 - ($memory_usage * 16 / 100)}")
      }
    },
    {
      "name": "disk",
      "status": 0,
      "metrics": {
        "usage_percent": $disk_usage,
        "used_gb": $(awk "BEGIN {printf \"%.1f\", $disk_usage * 500 / 100}"),
        "total_gb": 500.0,
        "available_gb": $(awk "BEGIN {printf \"%.1f\", 500 - ($disk_usage * 500 / 100)}")
      }
    }
  ]
}
EOF
}

# === PROPERTY-BASED TESTING ===

# Run property-based test
test_property() {
  local property_name="$1"
  local test_function="$2"
  local iterations="${3:-10}"
  local passed=0
  local failed=0

  log_info "Running property-based test: $property_name ($iterations iterations)"

  for ((i = 1; i <= iterations; i++)); do
    if $test_function "$i"; then
      ((passed++))
    else
      ((failed++))
      log_warning "Property test failed on iteration $i"
    fi
  done

  log_info "Property test results: $passed passed, $failed failed"

  if [[ $failed -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# === PERFORMANCE TESTING UTILITIES ===

# Measure execution time
measure_execution_time() {
  local command="$1"
  local iterations="${2:-1}"
  local total_time=0

  for ((i = 1; i <= iterations; i++)); do
    local start_time=$(date +%s.%N)
    eval "$command" >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
    total_time=$(awk "BEGIN {printf \"%.3f\", $total_time + $duration}")
  done

  local average_time=$(awk "BEGIN {printf \"%.3f\", $total_time / $iterations}")
  echo "$average_time"
}

# Memory usage monitoring
monitor_memory_usage() {
  local pid="$1"
  local duration="${2:-10}"
  local interval="${3:-1}"
  local max_memory=0

  for ((i = 0; i < duration; i += interval)); do
    if kill -0 "$pid" 2>/dev/null; then
      local memory_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
      if [[ -n "$memory_kb" && "$memory_kb" -gt "$max_memory" ]]; then
        max_memory="$memory_kb"
      fi
    else
      break
    fi
    sleep "$interval"
  done

  echo "$max_memory"
}

# === ERROR SIMULATION ===

# Simulate network failure
simulate_network_failure() {
  local duration="${1:-5}"

  # Block network access by redirecting to localhost
  export http_proxy="http://127.0.0.1:9999"
  export https_proxy="http://127.0.0.1:9999"

  sleep "$duration"

  unset http_proxy
  unset https_proxy
}

# Simulate disk full condition
simulate_disk_full() {
  local test_dir="${1:-$TEST_TEMP_DIR}"
  local size="${2:-100M}"

  # Create a large file to fill up space
  dd if=/dev/zero of="$test_dir/large_file" bs=1M count=100 2>/dev/null || true
}

# Simulate high CPU load
simulate_cpu_load() {
  local duration="${1:-10}"
  local processes="${2:-2}"

  for ((i = 1; i <= processes; i++)); do
    {
      local end_time=$(($(date +%s) + duration))
      while [[ $(date +%s) -lt $end_time ]]; do
        : # Busy loop
      done
    } &
  done

  wait
}

# === TEST ENVIRONMENT UTILITIES ===

# Create isolated test environment
create_isolated_environment() {
  local env_name="$1"
  local env_dir="${TEST_TEMP_DIR}/${env_name}"

  mkdir -p "$env_dir"/{bin,lib,config,logs,tmp}

  # Create minimal PATH
  export TEST_PATH="$env_dir/bin:$PATH"
  export TEST_CONFIG_DIR="$env_dir/config"
  export TEST_LOG_DIR="$env_dir/logs"

  echo "$env_dir"
}

# Cleanup isolated environment
cleanup_isolated_environment() {
  local env_dir="$1"

  if [[ -d "$env_dir" ]]; then
    rm -rf "$env_dir"
  fi

  unset TEST_PATH TEST_CONFIG_DIR TEST_LOG_DIR
}

# === PARALLEL TEST EXECUTION ===

# Run tests in parallel
run_tests_parallel() {
  local max_jobs="${1:-4}"
  shift
  local test_files=("$@")
  local job_count=0
  local pids=()
  local results=()

  for test_file in "${test_files[@]}"; do
    if [[ $job_count -ge $max_jobs ]]; then
      # Wait for a job to complete
      wait "${pids[0]}"
      local exit_code=$?
      results+=("${test_file}:${exit_code}")
      pids=("${pids[@]:1}")
      ((job_count--))
    fi

    # Start new test
    "$test_file" &
    pids+=($!)
    ((job_count++))
  done

  # Wait for remaining jobs
  for pid in "${pids[@]}"; do
    wait "$pid"
    local exit_code=$?
    results+=("${test_files[$((${#results[@]}))]}:${exit_code}")
  done

  # Print results
  for result in "${results[@]}"; do
    echo "$result"
  done
}

# === COVERAGE TRACKING ===

# Track function calls for coverage
track_function_calls() {
  local function_name="$1"
  local coverage_file="${TEST_TEMP_DIR}/coverage.log"

  echo "$(date '+%Y-%m-%d %H:%M:%S') $function_name" >>"$coverage_file"
}

# Generate coverage report
generate_coverage_report() {
  local coverage_file="${TEST_TEMP_DIR}/coverage.log"
  local report_file="${TEST_TEMP_DIR}/coverage_report.html"

  if [[ ! -f "$coverage_file" ]]; then
    log_warning "No coverage data found"
    return 1
  fi

  # Simple coverage report
  cat >"$report_file" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ServerSentry Test Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .covered { background-color: #d4edda; }
        .uncovered { background-color: #f8d7da; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>ServerSentry Test Coverage Report</h1>
    <h2>Function Call Summary</h2>
    <table>
        <tr><th>Function</th><th>Call Count</th></tr>
EOF

  # Count function calls
  if [[ -f "$coverage_file" ]]; then
    awk '{print $3}' "$coverage_file" | sort | uniq -c | sort -nr |
      while read count function; do
        echo "        <tr><td>$function</td><td>$count</td></tr>" >>"$report_file"
      done
  fi

  cat >>"$report_file" <<'EOF'
    </table>
</body>
</html>
EOF

  log_info "Coverage report generated: $report_file"
}

# === CLEANUP ===

# Enhanced cleanup for test helpers
cleanup_test_helpers() {
  stop_http_mock

  # Clean up any background processes
  jobs -p | xargs -r kill 2>/dev/null || true

  # Clean up temporary files
  rm -f "${TEST_TEMP_DIR}"/mock_* 2>/dev/null || true
  rm -f "${TEST_TEMP_DIR}"/random_* 2>/dev/null || true
  rm -f "${TEST_TEMP_DIR}"/large_file 2>/dev/null || true
}

# Register cleanup function
trap cleanup_test_helpers EXIT
