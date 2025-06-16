#!/usr/bin/env bash
#
# ServerSentry v2 - System Health Diagnostics Module
#
# This module provides system health diagnostic functions

# Function: diagnostics_check_system_health
# Description: Comprehensive system health diagnostics with enhanced error handling
# Parameters: None
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
# Example:
#   health_results=$(diagnostics_check_system_health)
# Dependencies:
#   - util_error_validate_input
#   - util_json_create_object
#   - log_debug
diagnostics_check_system_health() {
  log_debug "Running system health diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Disk space check
  if [[ "$(util_config_get_value "check_disk_space" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local disk_check
    if disk_check=$(diagnostics_check_disk_space); then
      checks+=("$disk_check")
      _diagnostics_count_result "$disk_check" total passed warnings errors critical
    else
      log_error "Disk space diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Memory usage check
  if [[ "$(util_config_get_value "check_memory_usage" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local memory_check
    if memory_check=$(diagnostics_check_memory_usage); then
      checks+=("$memory_check")
      _diagnostics_count_result "$memory_check" total passed warnings errors critical
    else
      log_error "Memory usage diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Load average check
  if [[ "$(util_config_get_value "check_load_average" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local load_check
    if load_check=$(diagnostics_check_load_average); then
      checks+=("$load_check")
      _diagnostics_count_result "$load_check" total passed warnings errors critical
    else
      log_error "Load average diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Process health check
  if [[ "$(util_config_get_value "check_running_processes" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local process_check
    if process_check=$(diagnostics_check_running_processes); then
      checks+=("$process_check")
      _diagnostics_count_result "$process_check" total passed warnings errors critical
    else
      log_error "Process health diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Network connectivity check
  if [[ "$(util_config_get_value "check_network_connectivity" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local network_check
    if network_check=$(diagnostics_check_network_connectivity); then
      checks+=("$network_check")
      _diagnostics_count_result "$network_check" total passed warnings errors critical
    else
      log_error "Network connectivity diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Create JSON array from checks using utility functions
  local checks_json
  checks_json=$(util_json_create_array "${checks[@]}")

  # Create summary and final result
  local summary
  summary=$(util_json_create_object \
    "total" "$total" \
    "passed" "$passed" \
    "warnings" "$warnings" \
    "errors" "$errors" \
    "critical" "$critical")

  local result
  result=$(util_json_create_object \
    "checks" "$checks_json" \
    "summary" "$summary" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_disk_space
# Description: Check disk space usage with configurable thresholds
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   disk_result=$(diagnostics_check_disk_space)
# Dependencies:
#   - util_error_validate_input
#   - util_config_get_value
diagnostics_check_disk_space() {
  local usage level=0 status="OK" message

  # Get disk usage for the base directory
  if command -v df >/dev/null 2>&1; then
    usage=$(df "$BASE_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "0")
  else
    log_warning "df command not available for disk space check"
    usage="0"
  fi

  # Validate usage is numeric
  if ! util_error_validate_input "$usage" "disk_usage" "numeric"; then
    usage="0"
    level=1
    status="WARNING"
    message="Could not determine disk usage"
  else
    # Get thresholds from configuration
    local warning_threshold
    local critical_threshold
    warning_threshold=$(util_config_get_value "disk_threshold_warning" "90" "$DIAGNOSTICS_NAMESPACE")
    critical_threshold=$(util_config_get_value "disk_threshold_critical" "98" "$DIAGNOSTICS_NAMESPACE")

    # Determine status based on thresholds
    if [[ "$usage" -ge "$critical_threshold" ]]; then
      level=3
      status="CRITICAL"
      message="Critical disk space usage: ${usage}% (threshold: ${critical_threshold}%)"
    elif [[ "$usage" -ge "$warning_threshold" ]]; then
      level=1
      status="WARNING"
      message="High disk space usage: ${usage}% (threshold: ${warning_threshold}%)"
    else
      level=0
      status="OK"
      message="Disk space usage normal: ${usage}%"
    fi
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "disk_space" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "usage_percent" "$usage" \
      "warning_threshold" "${warning_threshold:-90}" \
      "critical_threshold" "${critical_threshold:-98}" \
      "path" "$BASE_DIR")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_memory_usage
# Description: Check system memory usage with configurable thresholds
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   memory_result=$(diagnostics_check_memory_usage)
# Dependencies:
#   - util_error_validate_input
#   - util_config_get_value
diagnostics_check_memory_usage() {
  local usage level=0 status="OK" message

  # Get memory usage based on OS
  case "$(uname -s)" in
  "Darwin")
    # macOS memory calculation
    if usage=$(diagnostics_get_macos_memory_usage); then
      log_debug "macOS memory usage: ${usage}%"
    else
      usage="0"
      level=1
      status="WARNING"
      message="Could not determine memory usage on macOS"
    fi
    ;;
  "Linux")
    # Linux memory calculation
    if command -v free >/dev/null 2>&1; then
      usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
    else
      usage="0"
      level=1
      status="WARNING"
      message="free command not available for memory check"
    fi
    ;;
  *)
    usage="0"
    level=1
    status="WARNING"
    message="Memory usage check not supported on this OS"
    ;;
  esac

  # Validate usage is numeric
  if ! util_error_validate_input "$usage" "memory_usage" "numeric"; then
    usage="0"
    level=1
    status="WARNING"
    message="Could not determine memory usage"
  else
    # Get thresholds from configuration
    local warning_threshold
    local critical_threshold
    warning_threshold=$(util_config_get_value "memory_threshold_warning" "85" "$DIAGNOSTICS_NAMESPACE")
    critical_threshold=$(util_config_get_value "memory_threshold_critical" "95" "$DIAGNOSTICS_NAMESPACE")

    # Determine status based on thresholds
    if [[ "$usage" -ge "$critical_threshold" ]]; then
      level=3
      status="CRITICAL"
      message="Critical memory usage: ${usage}% (threshold: ${critical_threshold}%)"
    elif [[ "$usage" -ge "$warning_threshold" ]]; then
      level=1
      status="WARNING"
      message="High memory usage: ${usage}% (threshold: ${warning_threshold}%)"
    else
      level=0
      status="OK"
      message="Memory usage normal: ${usage}%"
    fi
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "memory_usage" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "usage_percent" "$usage" \
      "warning_threshold" "${warning_threshold:-85}" \
      "critical_threshold" "${critical_threshold:-95}" \
      "os_type" "$(uname -s)")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_get_macos_memory_usage
# Description: Get memory usage percentage on macOS
# Parameters: None
# Returns:
#   Memory usage percentage via stdout
#   0 - success
#   1 - failure
# Example:
#   usage=$(diagnostics_get_macos_memory_usage)
# Dependencies:
#   - vm_stat command (macOS)
diagnostics_get_macos_memory_usage() {
  if ! command -v vm_stat >/dev/null 2>&1; then
    return 1
  fi

  # Get memory statistics from vm_stat
  local vm_output
  vm_output=$(vm_stat 2>/dev/null) || return 1

  # Extract memory values (pages)
  local page_size
  page_size=$(echo "$vm_output" | grep "page size" | awk '{print $8}' || echo "4096")

  local free_pages
  free_pages=$(echo "$vm_output" | grep "Pages free" | awk '{print $3}' | tr -d '.' || echo "0")

  local active_pages
  active_pages=$(echo "$vm_output" | grep "Pages active" | awk '{print $3}' | tr -d '.' || echo "0")

  local inactive_pages
  inactive_pages=$(echo "$vm_output" | grep "Pages inactive" | awk '{print $3}' | tr -d '.' || echo "0")

  local wired_pages
  wired_pages=$(echo "$vm_output" | grep "Pages wired down" | awk '{print $4}' | tr -d '.' || echo "0")

  # Calculate total and used memory
  local total_pages=$((free_pages + active_pages + inactive_pages + wired_pages))
  local used_pages=$((active_pages + inactive_pages + wired_pages))

  if [[ $total_pages -gt 0 ]]; then
    local usage_percent=$((used_pages * 100 / total_pages))
    echo "$usage_percent"
    return 0
  else
    return 1
  fi
}

# Function: diagnostics_check_load_average
# Description: Check system load average with configurable thresholds
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   load_result=$(diagnostics_check_load_average)
# Dependencies:
#   - util_error_validate_input
#   - util_config_get_value
diagnostics_check_load_average() {
  local load_avg level=0 status="OK" message

  # Get load average (1 minute)
  if command -v uptime >/dev/null 2>&1; then
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ' 2>/dev/null || echo "0.00")
  elif [[ -r /proc/loadavg ]]; then
    load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.00")
  else
    load_avg="0.00"
    level=1
    status="WARNING"
    message="Could not determine load average"
  fi

  # Validate load average is numeric
  if ! util_error_validate_input "$load_avg" "load_average" "numeric"; then
    load_avg="0.00"
    level=1
    status="WARNING"
    message="Could not determine load average"
  else
    # Get CPU count for threshold calculation
    local cpu_count
    if command -v nproc >/dev/null 2>&1; then
      cpu_count=$(nproc 2>/dev/null || echo "1")
    elif [[ -r /proc/cpuinfo ]]; then
      cpu_count=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    else
      cpu_count="1"
    fi

    # Calculate thresholds based on CPU count
    local warning_threshold
    local critical_threshold
    warning_threshold=$(echo "$cpu_count * 0.8" | bc -l 2>/dev/null || echo "$cpu_count")
    critical_threshold=$(echo "$cpu_count * 1.5" | bc -l 2>/dev/null || echo "$cpu_count")

    # Determine status based on thresholds
    if (($(echo "$load_avg > $critical_threshold" | bc -l 2>/dev/null || echo 0))); then
      level=3
      status="CRITICAL"
      message="Critical load average: $load_avg (threshold: $critical_threshold, CPUs: $cpu_count)"
    elif (($(echo "$load_avg > $warning_threshold" | bc -l 2>/dev/null || echo 0))); then
      level=1
      status="WARNING"
      message="High load average: $load_avg (threshold: $warning_threshold, CPUs: $cpu_count)"
    else
      level=0
      status="OK"
      message="Load average normal: $load_avg (CPUs: $cpu_count)"
    fi
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "load_average" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "load_1min" "$load_avg" \
      "cpu_count" "${cpu_count:-1}" \
      "warning_threshold" "${warning_threshold:-1.0}" \
      "critical_threshold" "${critical_threshold:-2.0}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_running_processes
# Description: Check for critical running processes
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   process_result=$(diagnostics_check_running_processes)
# Dependencies:
#   - ps command
diagnostics_check_running_processes() {
  local level=0 status="OK" message
  local process_count=0
  local critical_processes=()

  # Get total process count
  if command -v ps >/dev/null 2>&1; then
    process_count=$(ps aux 2>/dev/null | wc -l || echo "0")
    process_count=$((process_count - 1)) # Subtract header line
  else
    level=1
    status="WARNING"
    message="ps command not available for process check"
  fi

  # Check for critical system processes (basic check)
  local required_processes=("init" "kernel" "systemd")
  local missing_processes=()

  for proc in "${required_processes[@]}"; do
    if ! pgrep -f "$proc" >/dev/null 2>&1; then
      missing_processes+=("$proc")
    fi
  done

  # Determine status
  if [[ ${#missing_processes[@]} -gt 0 ]]; then
    level=2
    status="ERROR"
    message="Missing critical processes: ${missing_processes[*]}"
  elif [[ $process_count -lt 10 ]]; then
    level=1
    status="WARNING"
    message="Low process count: $process_count (may indicate system issues)"
  else
    level=0
    status="OK"
    message="Process health normal: $process_count processes running"
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "running_processes" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "total_processes" "$process_count" \
      "missing_critical" "${#missing_processes[@]}" \
      "critical_processes_checked" "${#required_processes[@]}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_network_connectivity
# Description: Check basic network connectivity
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   network_result=$(diagnostics_check_network_connectivity)
# Dependencies:
#   - ping command
diagnostics_check_network_connectivity() {
  local level=0 status="OK" message
  local connectivity_tests=()

  # Test local connectivity (localhost)
  local localhost_test=false
  if ping -c 1 -W 2 127.0.0.1 >/dev/null 2>&1; then
    localhost_test=true
    connectivity_tests+=("localhost:OK")
  else
    connectivity_tests+=("localhost:FAIL")
  fi

  # Test external connectivity (if enabled)
  local external_test=false
  if [[ "$(util_config_get_value "test_external_connectivity" "false" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
      external_test=true
      connectivity_tests+=("external:OK")
    else
      connectivity_tests+=("external:FAIL")
    fi
  fi

  # Determine overall status
  if [[ "$localhost_test" != true ]]; then
    level=3
    status="CRITICAL"
    message="Local network connectivity failed"
  elif [[ "$external_test" == false && "$(util_config_get_value "test_external_connectivity" "false" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    level=1
    status="WARNING"
    message="External network connectivity failed"
  else
    level=0
    status="OK"
    message="Network connectivity normal"
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "network_connectivity" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "localhost_test" "$localhost_test" \
      "external_test" "$external_test" \
      "tests_performed" "${#connectivity_tests[@]}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Helper function: _diagnostics_count_result
# Description: Count diagnostic result levels (internal helper)
# Parameters:
#   $1 - check result JSON
#   $2-$6 - counter variable names (passed by reference)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   _diagnostics_count_result "$check_result" total passed warnings errors critical
# Dependencies:
#   - util_json_get_value
_diagnostics_count_result() {
  local check_result="$1"
  local -n total_ref="$2"
  local -n passed_ref="$3"
  local -n warnings_ref="$4"
  local -n errors_ref="$5"
  local -n critical_ref="$6"

  if [[ -n "$check_result" ]] && util_json_validate "$check_result"; then
    local level
    level=$(util_json_get_value "$check_result" ".level" 2>/dev/null || echo "0")

    total_ref=$((total_ref + 1))
    case "$level" in
    0) passed_ref=$((passed_ref + 1)) ;;
    1) warnings_ref=$((warnings_ref + 1)) ;;
    2) errors_ref=$((errors_ref + 1)) ;;
    3) critical_ref=$((critical_ref + 1)) ;;
    esac
  fi
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f diagnostics_check_system_health
  export -f diagnostics_check_disk_space
  export -f diagnostics_check_memory_usage
  export -f diagnostics_check_load_average
  export -f diagnostics_check_running_processes
  export -f diagnostics_check_network_connectivity
  export -f diagnostics_get_macos_memory_usage
  export -f _diagnostics_count_result
fi
