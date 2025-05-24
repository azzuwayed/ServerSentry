#!/bin/bash
#
# ServerSentry v2 - Self-Diagnostics System
#
# This module provides comprehensive system health checks, configuration validation,
# dependency verification, and performance diagnostics

# Source utilities
source "${BASE_DIR}/lib/core/logging.sh"
source "${BASE_DIR}/lib/core/utils.sh"

# Diagnostics configuration
DIAGNOSTICS_LOG_DIR="${BASE_DIR}/logs/diagnostics"
DIAGNOSTICS_REPORT_DIR="${BASE_DIR}/logs/diagnostics/reports"
DIAGNOSTICS_CONFIG_FILE="${BASE_DIR}/config/diagnostics.conf"
DIAGNOSTICS_NAMESPACE="diagnostics"

# Diagnostic levels
DIAGNOSTIC_LEVEL_INFO=0
DIAGNOSTIC_LEVEL_WARNING=1
DIAGNOSTIC_LEVEL_ERROR=2
DIAGNOSTIC_LEVEL_CRITICAL=3

# Diagnostic validation rules
declare -a DIAGNOSTICS_VALIDATION_RULES=(
  "check_system_health:boolean:"
  "check_configuration:boolean:"
  "check_dependencies:boolean:"
  "check_performance:boolean:"
  "check_plugins:boolean:"
  "check_notifications:boolean:"
  "check_logs:boolean:"
  "check_permissions:boolean:"
  "cpu_threshold_warning:positive_numeric:"
  "cpu_threshold_critical:positive_numeric:"
  "memory_threshold_warning:positive_numeric:"
  "memory_threshold_critical:positive_numeric:"
  "disk_threshold_warning:positive_numeric:"
  "disk_threshold_critical:positive_numeric:"
  "keep_reports_days:positive_numeric:"
)

# New standardized function: diagnostics_system_init
# Description: Initialize diagnostics system with proper validation and directory setup
# Returns:
#   0 - success
#   1 - failure
diagnostics_system_init() {
  log_debug "Initializing self-diagnostics system"

  # Create directories with secure permissions
  for dir in "$DIAGNOSTICS_LOG_DIR" "$DIAGNOSTICS_REPORT_DIR"; do
    if ! util_validate_dir_exists "$dir" "Diagnostics directory"; then
      log_info "Creating diagnostics directory: $dir"
      if ! create_secure_dir "$dir" 755; then
        log_error "Failed to create diagnostics directory: $dir"
        return 1
      fi
    fi
  done

  # Create default diagnostics configuration if needed
  if ! util_validate_file_exists "$DIAGNOSTICS_CONFIG_FILE" "Diagnostics configuration"; then
    log_info "Creating default diagnostics configuration"
    if ! diagnostics_create_default_config; then
      return 1
    fi
  fi

  log_debug "Self-diagnostics system initialized successfully"
  return 0
}

# New standardized function: diagnostics_create_default_config
# Description: Create default diagnostics configuration file with secure permissions
# Returns:
#   0 - success
#   1 - failure
diagnostics_create_default_config() {
  local template_content
  template_content=$(
    cat <<'EOF'
# ServerSentry Self-Diagnostics Configuration

# Enable/disable diagnostic categories
check_system_health=true
check_configuration=true
check_dependencies=true
check_performance=true
check_plugins=true
check_notifications=true
check_logs=true
check_permissions=true

# Performance thresholds
cpu_threshold_warning=80
cpu_threshold_critical=95
memory_threshold_warning=85
memory_threshold_critical=95
disk_threshold_warning=90
disk_threshold_critical=98

# System health checks
check_disk_space=true
check_memory_usage=true
check_load_average=true
check_running_processes=true
check_network_connectivity=true

# Configuration validation
validate_yaml_syntax=true
validate_required_fields=true
validate_file_permissions=true
validate_log_rotation=true

# Dependency checks
check_required_commands=true
check_optional_commands=true
check_system_packages=true

# Notification tests
test_notification_providers=false  # Set to true to test during diagnostics
notification_test_cooldown=3600    # Minimum seconds between notification tests

# Report settings
generate_detailed_reports=true
keep_reports_days=30
compress_old_reports=true
EOF
  )

  if ! util_config_create_default "$DIAGNOSTICS_CONFIG_FILE" "$template_content"; then
    return 1
  fi

  log_info "Default diagnostics configuration created: $DIAGNOSTICS_CONFIG_FILE"
  return 0
}

# New standardized function: diagnostics_load_config
# Description: Load and validate diagnostics configuration using unified utilities
# Returns:
#   0 - success
#   1 - failure
diagnostics_load_config() {
  log_debug "Loading diagnostics configuration"

  # Initialize diagnostics system
  if ! diagnostics_system_init; then
    return 1
  fi

  # Use cached configuration loading with shell-style config
  if ! _diagnostics_parse_shell_config "$DIAGNOSTICS_CONFIG_FILE" "$DIAGNOSTICS_NAMESPACE"; then
    log_error "Failed to load diagnostics configuration"
    return 1
  fi

  # Validate configuration values
  if ! util_config_validate_values DIAGNOSTICS_VALIDATION_RULES "$DIAGNOSTICS_NAMESPACE"; then
    log_error "Diagnostics configuration validation failed"
    return 1
  fi

  log_debug "Diagnostics configuration loaded and validated successfully"
  return 0
}

# Helper function: _diagnostics_parse_shell_config
# Description: Parse shell-style configuration file
# Parameters:
#   $1 - config file path
#   $2 - namespace
# Returns:
#   0 - success
#   1 - failure
_diagnostics_parse_shell_config() {
  local config_file="$1"
  local namespace="$2"

  if ! util_validate_file_exists "$config_file" "Configuration file"; then
    return 1
  fi

  # Source the configuration file in a subshell to capture variables
  local config_vars
  config_vars=$(
    set +e
    source "$config_file" 2>/dev/null
    set | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*=' | grep -v '^_'
  )

  # Set variables with namespace prefix
  while IFS='=' read -r key value; do
    if [[ -n "$key" && -n "$value" ]]; then
      # Remove quotes from value if present
      value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
      util_config_set_value "$key" "$value" "$namespace"
    fi
  done <<<"$config_vars"

  return 0
}

# New standardized function: diagnostics_run_full
# Description: Run complete diagnostic suite with enhanced error handling and reporting
# Returns:
#   0 - all checks passed
#   1 - warnings found
#   2 - errors found
#   3 - critical issues found
diagnostics_run_full() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local report_file="$DIAGNOSTICS_REPORT_DIR/full_diagnostic_$(date +%Y%m%d_%H%M%S).json"

  log_info "Running full system diagnostics..."

  # Load configuration
  if ! diagnostics_load_config; then
    log_error "Failed to load diagnostics configuration"
    return 2
  fi

  # Initialize report structure using JSON utilities
  local diagnostics_report
  diagnostics_report=$(util_json_create_object \
    "diagnostic_run" "$(util_json_create_object \
      "timestamp" "$timestamp" \
      "version" "2.0.0" \
      "hostname" "$(hostname)" \
      "user" "$(whoami)" \
      "working_directory" "$BASE_DIR")" \
    "results" "$(util_json_create_object \
      "system_health" "{}" \
      "configuration" "{}" \
      "dependencies" "{}" \
      "performance" "{}" \
      "plugins" "{}" \
      "notifications" "{}" \
      "logs" "{}" \
      "permissions" "{}")" \
    "summary" "$(util_json_create_object \
      "total_checks" "0" \
      "passed" "0" \
      "warnings" "0" \
      "errors" "0" \
      "critical" "0")")

  # Run diagnostic categories with enhanced error handling
  local total_checks=0 passed=0 warnings=0 errors=0 critical=0

  # System health diagnostics
  if [[ "$(util_config_get_value "check_system_health" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local health_results
    if health_results=$(diagnostics_check_system_health); then
      diagnostics_report=$(util_json_set_value "$diagnostics_report" ".results.system_health" "$health_results")
      _diagnostics_update_counters health_results total_checks passed warnings errors critical
    else
      log_error "System health diagnostics failed"
      errors=$((errors + 1))
      total_checks=$((total_checks + 1))
    fi
  fi

  # Configuration diagnostics
  if [[ "$(util_config_get_value "check_configuration" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local config_results
    if config_results=$(diagnostics_check_configuration); then
      diagnostics_report=$(util_json_set_value "$diagnostics_report" ".results.configuration" "$config_results")
      _diagnostics_update_counters config_results total_checks passed warnings errors critical
    else
      log_error "Configuration diagnostics failed"
      errors=$((errors + 1))
      total_checks=$((total_checks + 1))
    fi
  fi

  # Dependencies diagnostics
  if [[ "$(util_config_get_value "check_dependencies" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local deps_results
    if deps_results=$(diagnostics_check_dependencies); then
      diagnostics_report=$(util_json_set_value "$diagnostics_report" ".results.dependencies" "$deps_results")
      _diagnostics_update_counters deps_results total_checks passed warnings errors critical
    else
      log_error "Dependencies diagnostics failed"
      errors=$((errors + 1))
      total_checks=$((total_checks + 1))
    fi
  fi

  # Performance diagnostics
  if [[ "$(util_config_get_value "check_performance" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local perf_results
    if perf_results=$(diagnostics_check_performance); then
      diagnostics_report=$(util_json_set_value "$diagnostics_report" ".results.performance" "$perf_results")
      _diagnostics_update_counters perf_results total_checks passed warnings errors critical
    else
      log_error "Performance diagnostics failed"
      errors=$((errors + 1))
      total_checks=$((total_checks + 1))
    fi
  fi

  # Plugins diagnostics
  if [[ "$(util_config_get_value "check_plugins" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local plugin_results
    if plugin_results=$(diagnostics_check_plugins); then
      diagnostics_report=$(util_json_set_value "$diagnostics_report" ".results.plugins" "$plugin_results")
      _diagnostics_update_counters plugin_results total_checks passed warnings errors critical
    else
      log_error "Plugins diagnostics failed"
      errors=$((errors + 1))
      total_checks=$((total_checks + 1))
    fi
  fi

  # Update summary using JSON utilities
  diagnostics_report=$(util_json_set_value "$diagnostics_report" ".summary.total_checks" "$total_checks")
  diagnostics_report=$(util_json_set_value "$diagnostics_report" ".summary.passed" "$passed")
  diagnostics_report=$(util_json_set_value "$diagnostics_report" ".summary.warnings" "$warnings")
  diagnostics_report=$(util_json_set_value "$diagnostics_report" ".summary.errors" "$errors")
  diagnostics_report=$(util_json_set_value "$diagnostics_report" ".summary.critical" "$critical")

  # Save report with secure permissions
  if ! echo "$diagnostics_report" | util_json_format >"$report_file"; then
    log_error "Failed to save diagnostics report"
    return 2
  fi
  chmod 644 "$report_file"

  # Output summary
  log_info "Diagnostics Complete - Report saved to: $report_file"
  log_info "Summary: $total_checks total, $passed passed, $warnings warnings, $errors errors, $critical critical"

  # Return appropriate exit code
  if [[ "$critical" -gt 0 ]]; then
    return 3
  elif [[ "$errors" -gt 0 ]]; then
    return 2
  elif [[ "$warnings" -gt 0 ]]; then
    return 1
  else
    return 0
  fi
}

# Helper function: _diagnostics_update_counters
# Description: Update diagnostic counters from results
# Parameters:
#   $1 - results JSON variable name
#   $2-$6 - counter variable names (passed by reference)
_diagnostics_update_counters() {
  local -n results_ref="$1"
  local -n total_ref="$2"
  local -n passed_ref="$3"
  local -n warnings_ref="$4"
  local -n errors_ref="$5"
  local -n critical_ref="$6"

  if [[ -n "$results_ref" ]] && util_json_validate "$results_ref"; then
    local stats
    stats=$(util_json_get_value "$results_ref" ".summary" | tr '|' '\n')

    local r_total r_passed r_warnings r_errors r_critical
    r_total=$(echo "$stats" | util_json_get_value - ".total" 2>/dev/null || echo "0")
    r_passed=$(echo "$stats" | util_json_get_value - ".passed" 2>/dev/null || echo "0")
    r_warnings=$(echo "$stats" | util_json_get_value - ".warnings" 2>/dev/null || echo "0")
    r_errors=$(echo "$stats" | util_json_get_value - ".errors" 2>/dev/null || echo "0")
    r_critical=$(echo "$stats" | util_json_get_value - ".critical" 2>/dev/null || echo "0")

    total_ref=$((total_ref + r_total))
    passed_ref=$((passed_ref + r_passed))
    warnings_ref=$((warnings_ref + r_warnings))
    errors_ref=$((errors_ref + r_errors))
    critical_ref=$((critical_ref + r_critical))
  fi
}

# New standardized function: diagnostics_check_system_health
# Description: Check system health diagnostics with enhanced error handling
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
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

# Helper function: _diagnostics_count_result
# Description: Count diagnostic result levels
# Parameters:
#   $1 - check result JSON
#   $2-$6 - counter variable names (passed by reference)
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

# New standardized function: diagnostics_check_disk_space
# Description: Check disk space usage with configurable thresholds
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
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
  if ! util_validate_numeric "$usage" "disk usage"; then
    usage="0"
  fi

  # Get thresholds from configuration
  local warning_threshold critical_threshold
  warning_threshold=$(util_config_get_value "disk_threshold_warning" "90" "$DIAGNOSTICS_NAMESPACE")
  critical_threshold=$(util_config_get_value "disk_threshold_critical" "98" "$DIAGNOSTICS_NAMESPACE")

  # Determine status and level
  message="Disk usage: ${usage}%"
  if [[ "$usage" -ge "$critical_threshold" ]]; then
    level=3
    status="CRITICAL"
    message="Critical disk usage: ${usage}%"
  elif [[ "$usage" -ge "$warning_threshold" ]]; then
    level=1
    status="WARNING"
    message="High disk usage: ${usage}%"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "usage_percent" "$usage" \
    "warning_threshold" "$warning_threshold" \
    "critical_threshold" "$critical_threshold" \
    "path" "$BASE_DIR")

  local result
  result=$(util_json_create_object \
    "name" "disk_space" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_memory_usage
# Description: Check memory usage with cross-platform support
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_memory_usage() {
  local usage level=0 status="OK" message

  # Use cross-platform method to get memory usage
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS implementation
    usage=$(diagnostics_get_macos_memory_usage)
  elif command -v free >/dev/null 2>&1; then
    # Linux implementation
    local memory_info
    memory_info=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
    usage="$memory_info"
  else
    log_warning "Memory usage check not supported on this platform"
    usage="0"
  fi

  # Validate usage is numeric
  if ! util_validate_numeric "$usage" "memory usage"; then
    usage="0"
  fi

  # Get thresholds from configuration
  local warning_threshold critical_threshold
  warning_threshold=$(util_config_get_value "memory_threshold_warning" "85" "$DIAGNOSTICS_NAMESPACE")
  critical_threshold=$(util_config_get_value "memory_threshold_critical" "95" "$DIAGNOSTICS_NAMESPACE")

  # Determine status and level
  message="Memory usage: ${usage}%"
  if [[ "$usage" -ge "$critical_threshold" ]]; then
    level=3
    status="CRITICAL"
    message="Critical memory usage: ${usage}%"
  elif [[ "$usage" -ge "$warning_threshold" ]]; then
    level=1
    status="WARNING"
    message="High memory usage: ${usage}%"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "usage_percent" "$usage" \
    "warning_threshold" "$warning_threshold" \
    "critical_threshold" "$critical_threshold")

  local result
  result=$(util_json_create_object \
    "name" "memory_usage" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Helper function: diagnostics_get_macos_memory_usage
# Description: Get memory usage on macOS
# Returns:
#   Memory usage percentage via stdout
diagnostics_get_macos_memory_usage() {
  local vm_stat_output page_size
  vm_stat_output=$(vm_stat 2>/dev/null) || {
    echo "0"
    return
  }
  page_size=$(pagesize 2>/dev/null) || {
    echo "0"
    return
  }

  local pages_active pages_inactive pages_speculative pages_wired pages_free
  pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.' || echo "0")
  pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.' || echo "0")
  pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.' || echo "0")
  pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.' || echo "0")
  pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.' || echo "0")

  local total_pages used_pages usage
  total_pages=$((pages_active + pages_inactive + pages_speculative + pages_wired + pages_free))
  used_pages=$((pages_active + pages_inactive + pages_wired))

  if [[ "$total_pages" -gt 0 ]]; then
    usage=$(echo "scale=0; $used_pages * 100 / $total_pages" | bc 2>/dev/null || echo "0")
  else
    usage="0"
  fi

  echo "$usage"
}

# New standardized function: diagnostics_check_load_average
# Description: Check system load average
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_load_average() {
  local load_1min load_5min load_15min level=0 status="OK" message

  # Get load averages
  if command -v uptime >/dev/null 2>&1; then
    local uptime_output
    uptime_output=$(uptime 2>/dev/null)

    # Extract load averages (cross-platform)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS format: "load averages: 1.23 1.45 1.67"
      load_1min=$(echo "$uptime_output" | awk -F'load averages: ' '{print $2}' | awk '{print $1}' | tr -d ',' || echo "0.0")
      load_5min=$(echo "$uptime_output" | awk -F'load averages: ' '{print $2}' | awk '{print $2}' | tr -d ',' || echo "0.0")
      load_15min=$(echo "$uptime_output" | awk -F'load averages: ' '{print $2}' | awk '{print $3}' | tr -d ',' || echo "0.0")
    else
      # Linux format: "load average: 1.23, 1.45, 1.67"
      load_1min=$(echo "$uptime_output" | awk -F'load average: ' '{print $2}' | awk -F', ' '{print $1}' || echo "0.0")
      load_5min=$(echo "$uptime_output" | awk -F'load average: ' '{print $2}' | awk -F', ' '{print $2}' || echo "0.0")
      load_15min=$(echo "$uptime_output" | awk -F'load average: ' '{print $2}' | awk -F', ' '{print $3}' || echo "0.0")
    fi
  else
    log_warning "uptime command not available for load average check"
    load_1min="0.0"
    load_5min="0.0"
    load_15min="0.0"
  fi

  # Get CPU count for threshold calculation
  local cpu_count
  if command -v nproc >/dev/null 2>&1; then
    cpu_count=$(nproc 2>/dev/null || echo "1")
  elif [[ "$OSTYPE" == "darwin"* ]] && command -v sysctl >/dev/null 2>&1; then
    cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
  else
    cpu_count="1"
  fi

  # Calculate load percentage (1-minute load / CPU count * 100)
  local load_percent
  load_percent=$(echo "scale=0; $load_1min * 100 / $cpu_count" | bc 2>/dev/null || echo "0")

  # Determine status based on load percentage
  message="Load average: ${load_1min}, ${load_5min}, ${load_15min} (${load_percent}% of CPU capacity)"
  if [[ $(echo "$load_percent >= 200" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    level=3
    status="CRITICAL"
    message="Critical system load: ${load_1min} (${load_percent}% of CPU capacity)"
  elif [[ $(echo "$load_percent >= 100" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    level=1
    status="WARNING"
    message="High system load: ${load_1min} (${load_percent}% of CPU capacity)"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "load_1min" "$load_1min" \
    "load_5min" "$load_5min" \
    "load_15min" "$load_15min" \
    "cpu_count" "$cpu_count" \
    "load_percent" "$load_percent")

  local result
  result=$(util_json_create_object \
    "name" "load_average" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_configuration
# Description: Check configuration diagnostics with enhanced error handling
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
diagnostics_check_configuration() {
  log_debug "Running configuration diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # YAML syntax validation
  if [[ "$(util_config_get_value "validate_yaml_syntax" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local yaml_check
    if yaml_check=$(diagnostics_check_yaml_syntax); then
      checks+=("$yaml_check")
      _diagnostics_count_result "$yaml_check" total passed warnings errors critical
    else
      log_error "YAML syntax diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Required fields validation
  if [[ "$(util_config_get_value "validate_required_fields" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local fields_check
    if fields_check=$(diagnostics_check_required_fields); then
      checks+=("$fields_check")
      _diagnostics_count_result "$fields_check" total passed warnings errors critical
    else
      log_error "Required fields diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # File permissions validation
  if [[ "$(util_config_get_value "validate_file_permissions" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local perms_check
    if perms_check=$(diagnostics_check_file_permissions); then
      checks+=("$perms_check")
      _diagnostics_count_result "$perms_check" total passed warnings errors critical
    else
      log_error "File permissions diagnostic failed"
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

# New standardized function: diagnostics_check_yaml_syntax
# Description: Check YAML syntax validation for configuration files
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_yaml_syntax() {
  local level=0 status="OK" message="YAML syntax validation passed"
  local config_files=()
  local errors_found=()

  # Find all YAML configuration files
  if [[ -d "$CONFIG_DIR" ]]; then
    while IFS= read -r -d '' file; do
      config_files+=("$file")
    done < <(find "$CONFIG_DIR" -name "*.yaml" -o -name "*.yml" -print0 2>/dev/null)
  fi

  # Check main configuration file specifically
  if [[ -f "$MAIN_CONFIG" ]]; then
    config_files+=("$MAIN_CONFIG")
  fi

  # Validate each YAML file
  for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
      local validation_result
      if command -v yq >/dev/null 2>&1; then
        validation_result=$(yq eval '.' "$config_file" 2>&1)
        if [[ $? -ne 0 ]]; then
          errors_found+=("$config_file: $validation_result")
        fi
      elif command -v python3 >/dev/null 2>&1; then
        validation_result=$(python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>&1)
        if [[ $? -ne 0 ]]; then
          errors_found+=("$config_file: $validation_result")
        fi
      else
        # Basic syntax check - look for common YAML issues
        if grep -q $'\t' "$config_file"; then
          errors_found+=("$config_file: Contains tab characters (use spaces for indentation)")
        fi
      fi
    else
      errors_found+=("$config_file: File not found")
    fi
  done

  # Determine status based on errors found
  if [[ ${#errors_found[@]} -gt 0 ]]; then
    level=2
    status="ERROR"
    message="YAML syntax validation failed: ${#errors_found[@]} error(s) found"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "files_checked" "${#config_files[@]}" \
    "errors_found" "${#errors_found[@]}" \
    "error_details" "$(util_json_create_array "${errors_found[@]}")")

  local result
  result=$(util_json_create_object \
    "name" "yaml_syntax" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_required_fields
# Description: Check for required configuration fields
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_required_fields() {
  local level=0 status="OK" message="Required fields validation passed"
  local missing_fields=()

  # Define required fields for ServerSentry
  local required_fields=(
    "enabled"
    "log_level"
    "check_interval"
    "plugins_enabled"
  )

  # Check each required field
  for field in "${required_fields[@]}"; do
    local value
    value=$(config_get_value "$field" 2>/dev/null || echo "")
    if [[ -z "$value" ]]; then
      missing_fields+=("$field")
    fi
  done

  # Determine status based on missing fields
  if [[ ${#missing_fields[@]} -gt 0 ]]; then
    level=2
    status="ERROR"
    message="Required fields validation failed: ${#missing_fields[@]} field(s) missing"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "required_fields" "$(util_json_create_array "${required_fields[@]}")" \
    "missing_fields" "$(util_json_create_array "${missing_fields[@]}")" \
    "fields_checked" "${#required_fields[@]}" \
    "missing_count" "${#missing_fields[@]}")

  local result
  result=$(util_json_create_object \
    "name" "required_fields" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_file_permissions
# Description: Check file and directory permissions
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_file_permissions() {
  local level=0 status="OK" message="File permissions validation passed"
  local permission_issues=()

  # Define critical files and directories to check
  local critical_paths=(
    "$BASE_DIR:755:directory"
    "$CONFIG_DIR:755:directory"
    "$DIAGNOSTICS_LOG_DIR:755:directory"
    "$DIAGNOSTICS_REPORT_DIR:755:directory"
  )

  # Add configuration files if they exist
  if [[ -f "$MAIN_CONFIG" ]]; then
    critical_paths+=("$MAIN_CONFIG:644:file")
  fi
  if [[ -f "$DIAGNOSTICS_CONFIG_FILE" ]]; then
    critical_paths+=("$DIAGNOSTICS_CONFIG_FILE:644:file")
  fi

  # Check each path
  for path_spec in "${critical_paths[@]}"; do
    IFS=':' read -r path expected_perms type <<<"$path_spec"

    if [[ -e "$path" ]]; then
      local actual_perms
      actual_perms=$(stat -c "%a" "$path" 2>/dev/null || stat -f "%A" "$path" 2>/dev/null || echo "000")

      # Check if permissions are secure (not more permissive than expected)
      if [[ "$actual_perms" != "$expected_perms" ]]; then
        # For directories, check if they're at least as restrictive
        if [[ "$type" == "directory" && "$actual_perms" -gt "$expected_perms" ]]; then
          permission_issues+=("$path: $type has permissions $actual_perms (expected $expected_perms or more restrictive)")
        elif [[ "$type" == "file" && "$actual_perms" != "$expected_perms" ]]; then
          permission_issues+=("$path: $type has permissions $actual_perms (expected $expected_perms)")
        fi
      fi
    else
      permission_issues+=("$path: $type does not exist")
    fi
  done

  # Determine status based on permission issues
  if [[ ${#permission_issues[@]} -gt 0 ]]; then
    level=1
    status="WARNING"
    message="File permissions validation found ${#permission_issues[@]} issue(s)"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "paths_checked" "${#critical_paths[@]}" \
    "issues_found" "${#permission_issues[@]}" \
    "permission_issues" "$(util_json_create_array "${permission_issues[@]}")")

  local result
  result=$(util_json_create_object \
    "name" "file_permissions" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_dependencies
# Description: Check system dependencies with enhanced error handling
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
diagnostics_check_dependencies() {
  log_debug "Running dependencies diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Required commands check
  if [[ "$(util_config_get_value "check_required_commands" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local cmd_check
    if cmd_check=$(diagnostics_check_required_commands); then
      checks+=("$cmd_check")
      _diagnostics_count_result "$cmd_check" total passed warnings errors critical
    else
      log_error "Required commands diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Optional commands check
  if [[ "$(util_config_get_value "check_optional_commands" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local opt_cmd_check
    if opt_cmd_check=$(diagnostics_check_optional_commands); then
      checks+=("$opt_cmd_check")
      _diagnostics_count_result "$opt_cmd_check" total passed warnings errors critical
    else
      log_error "Optional commands diagnostic failed"
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

# New standardized function: diagnostics_check_required_commands
# Description: Check for required system commands
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_required_commands() {
  local level=0 status="OK" message="All required commands are available"
  local missing_commands=()
  local available_commands=()

  # Define required commands for ServerSentry operation
  local required_commands=(
    "ps" "grep" "awk" "sed" "tail" "head" "cat" "date" "find" "sort" "uniq"
    "chmod" "chown" "mkdir" "touch" "stat" "df" "uptime"
  )

  # Check each required command
  for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      available_commands+=("$cmd")
    else
      missing_commands+=("$cmd")
    fi
  done

  # Determine status based on missing commands
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    level=3
    status="CRITICAL"
    message="Missing required commands: ${missing_commands[*]}"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "required_commands" "$(util_json_create_array "${required_commands[@]}")" \
    "available_commands" "$(util_json_create_array "${available_commands[@]}")" \
    "missing_commands" "$(util_json_create_array "${missing_commands[@]}")" \
    "total_required" "${#required_commands[@]}" \
    "total_available" "${#available_commands[@]}" \
    "total_missing" "${#missing_commands[@]}")

  local result
  result=$(util_json_create_object \
    "name" "required_commands" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_optional_commands
# Description: Check for optional system commands that enhance functionality
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_optional_commands() {
  local level=0 status="OK" message="Optional commands status checked"
  local missing_commands=()
  local available_commands=()

  # Define optional commands that enhance ServerSentry functionality
  local optional_commands=(
    "jq" "yq" "bc" "curl" "wget" "dialog" "whiptail" "systemctl" "service"
    "crontab" "mail" "sendmail" "zip" "gzip" "tar" "rsync"
  )

  # Check each optional command
  for cmd in "${optional_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      available_commands+=("$cmd")
    else
      missing_commands+=("$cmd")
    fi
  done

  # Determine status based on missing commands
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    level=1
    status="WARNING"
    message="Some optional commands are missing: ${missing_commands[*]}"
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "optional_commands" "$(util_json_create_array "${optional_commands[@]}")" \
    "available_commands" "$(util_json_create_array "${available_commands[@]}")" \
    "missing_commands" "$(util_json_create_array "${missing_commands[@]}")" \
    "total_optional" "${#optional_commands[@]}" \
    "total_available" "${#available_commands[@]}" \
    "total_missing" "${#missing_commands[@]}")

  local result
  result=$(util_json_create_object \
    "name" "optional_commands" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_performance
# Description: Check system performance metrics
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
diagnostics_check_performance() {
  log_debug "Running performance diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Plugin performance check
  local plugin_perf_check
  if plugin_perf_check=$(diagnostics_check_plugin_performance); then
    checks+=("$plugin_perf_check")
    _diagnostics_count_result "$plugin_perf_check" total passed warnings errors critical
  else
    log_error "Plugin performance diagnostic failed"
    errors=$((errors + 1))
    total=$((total + 1))
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

# New standardized function: diagnostics_check_plugin_performance
# Description: Check plugin system performance
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_plugin_performance() {
  local level=0 status="OK" message="Plugin performance is acceptable"
  local performance_issues=()

  # Check if plugin system is available
  if ! declare -f plugin_list_loaded >/dev/null 2>&1; then
    level=1
    status="WARNING"
    message="Plugin system not available for performance testing"

    local result
    result=$(util_json_create_object \
      "name" "plugin_performance" \
      "level" "$level" \
      "status" "$status" \
      "message" "$message" \
      "details" "$(util_json_create_object "plugin_system_available" "false")" \
      "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

    echo "$result"
    return 0
  fi

  # Get loaded plugins
  local loaded_plugins
  loaded_plugins=$(plugin_list_loaded 2>/dev/null || echo "")

  if [[ -z "$loaded_plugins" ]]; then
    level=1
    status="WARNING"
    message="No plugins loaded for performance testing"
  else
    # Test plugin loading performance
    local start_time end_time duration
    start_time=$(date +%s%N 2>/dev/null || date +%s)

    # Simulate plugin operations
    plugin_list_loaded >/dev/null 2>&1

    end_time=$(date +%s%N 2>/dev/null || date +%s)

    # Calculate duration (in milliseconds)
    if [[ "$start_time" =~ [0-9]{19} ]]; then
      # Nanosecond precision available
      duration=$(((end_time - start_time) / 1000000))
    else
      # Second precision only
      duration=$(((end_time - start_time) * 1000))
    fi

    # Check performance thresholds
    if [[ "$duration" -gt 5000 ]]; then # 5 seconds
      level=2
      status="ERROR"
      message="Plugin operations are slow (${duration}ms)"
      performance_issues+=("Plugin operations taking ${duration}ms (threshold: 5000ms)")
    elif [[ "$duration" -gt 1000 ]]; then # 1 second
      level=1
      status="WARNING"
      message="Plugin operations are moderately slow (${duration}ms)"
      performance_issues+=("Plugin operations taking ${duration}ms (warning threshold: 1000ms)")
    fi
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "plugin_system_available" "true" \
    "loaded_plugins_count" "$(echo "$loaded_plugins" | wc -w 2>/dev/null || echo "0")" \
    "operation_duration_ms" "${duration:-0}" \
    "performance_issues" "$(util_json_create_array "${performance_issues[@]}")")

  local result
  result=$(util_json_create_object \
    "name" "plugin_performance" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# New standardized function: diagnostics_check_plugins
# Description: Check plugin system availability and status
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
diagnostics_check_plugins() {
  log_debug "Running plugins diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Plugin availability check
  local plugin_avail_check
  if plugin_avail_check=$(diagnostics_check_plugin_availability); then
    checks+=("$plugin_avail_check")
    _diagnostics_count_result "$plugin_avail_check" total passed warnings errors critical
  else
    log_error "Plugin availability diagnostic failed"
    errors=$((errors + 1))
    total=$((total + 1))
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

# New standardized function: diagnostics_check_plugin_availability
# Description: Check plugin availability and configuration
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
diagnostics_check_plugin_availability() {
  local level=0 status="OK" message="Plugin system is available and configured"
  local plugin_issues=()
  local available_plugins=()
  local loaded_plugins=()

  # Check if plugin directory exists
  local plugin_dir="${BASE_DIR}/lib/plugins"
  if [[ ! -d "$plugin_dir" ]]; then
    level=2
    status="ERROR"
    message="Plugin directory not found: $plugin_dir"
    plugin_issues+=("Plugin directory missing: $plugin_dir")
  else
    # Find available plugins
    while IFS= read -r -d '' plugin_file; do
      local plugin_name
      plugin_name=$(basename "$plugin_file" .sh)
      available_plugins+=("$plugin_name")
    done < <(find "$plugin_dir" -name "*.sh" -print0 2>/dev/null)

    # Check loaded plugins if plugin system is available
    if declare -f plugin_list_loaded >/dev/null 2>&1; then
      local loaded_list
      loaded_list=$(plugin_list_loaded 2>/dev/null || echo "")
      if [[ -n "$loaded_list" ]]; then
        IFS=' ' read -ra loaded_plugins <<<"$loaded_list"
      fi
    else
      plugin_issues+=("Plugin system functions not available")
      level=1
      status="WARNING"
    fi

    # Check if any plugins are available but none loaded
    if [[ ${#available_plugins[@]} -gt 0 && ${#loaded_plugins[@]} -eq 0 ]]; then
      level=1
      status="WARNING"
      message="Plugins available but none loaded"
      plugin_issues+=("${#available_plugins[@]} plugins available but none loaded")
    fi
  fi

  # Create result using JSON utilities
  local details
  details=$(util_json_create_object \
    "plugin_directory" "$plugin_dir" \
    "available_plugins" "$(util_json_create_array "${available_plugins[@]}")" \
    "loaded_plugins" "$(util_json_create_array "${loaded_plugins[@]}")" \
    "available_count" "${#available_plugins[@]}" \
    "loaded_count" "${#loaded_plugins[@]}" \
    "plugin_issues" "$(util_json_create_array "${plugin_issues[@]}")")

  local result
  result=$(util_json_create_object \
    "name" "plugin_availability" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "details" "$details" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Get diagnostic summary
get_diagnostic_summary() {
  local days="${1:-7}"

  echo "Diagnostic Summary (Last $days days):"
  echo "===================================="

  # Find recent diagnostic reports
  local report_count=0
  local total_issues=0

  for ((i = 0; i < days; i++)); do
    local check_date
    check_date=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-"${i}"d +%Y%m%d 2>/dev/null)

    for report in "$DIAGNOSTICS_REPORT_DIR"/full_diagnostic_${check_date}_*.json; do
      if [ -f "$report" ]; then
        report_count=$((report_count + 1))

        if command -v jq >/dev/null 2>&1; then
          local warnings errors critical
          warnings=$(jq -r '.summary.warnings' "$report" 2>/dev/null || echo "0")
          errors=$(jq -r '.summary.errors' "$report" 2>/dev/null || echo "0")
          critical=$(jq -r '.summary.critical' "$report" 2>/dev/null || echo "0")

          total_issues=$((total_issues + warnings + errors + critical))

          echo "$(basename "$report"): $warnings warnings, $errors errors, $critical critical"
        fi
      fi
    done
  done

  echo ""
  echo "Total reports: $report_count"
  echo "Total issues: $total_issues"

  if [ "$total_issues" -eq 0 ]; then
    echo "System health: GOOD"
  elif [ "$total_issues" -lt 5 ]; then
    echo "System health: FAIR"
  else
    echo "System health: NEEDS ATTENTION"
  fi
}

# Cleanup old diagnostic reports
cleanup_diagnostic_reports() {
  local days_to_keep="${1:-30}"

  log_debug "Cleaning up diagnostic reports older than $days_to_keep days"

  find "$DIAGNOSTICS_REPORT_DIR" -name "*.json" -type f -mtime +"$days_to_keep" -delete 2>/dev/null

  log_debug "Diagnostic report cleanup completed"
}

# Export functions for use by other modules
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f diagnostics_system_init
  export -f diagnostics_create_default_config
  export -f diagnostics_load_config
  export -f diagnostics_run_full
  export -f diagnostics_check_system_health
  export -f diagnostics_check_disk_space
  export -f diagnostics_check_memory_usage
  export -f diagnostics_check_load_average
  export -f diagnostics_check_configuration
  export -f diagnostics_check_yaml_syntax
  export -f diagnostics_check_required_fields
  export -f diagnostics_check_file_permissions
  export -f diagnostics_check_dependencies
  export -f diagnostics_check_required_commands
  export -f diagnostics_check_optional_commands
  export -f diagnostics_check_performance
  export -f diagnostics_check_plugin_performance
  export -f diagnostics_check_plugins
  export -f diagnostics_check_plugin_availability
  export -f diagnostics_get_summary
  export -f diagnostics_cleanup_reports

  # Export backward compatibility functions
  export -f init_diagnostics_system
  export -f create_default_diagnostics_config
  export -f parse_diagnostics_config
  export -f run_full_diagnostics
  export -f check_system_health_diagnostics
  export -f check_disk_space_diagnostic
  export -f check_memory_usage_diagnostic
  export -f check_load_average_diagnostic
  export -f check_configuration_diagnostics
  export -f check_yaml_syntax_diagnostic
  export -f check_required_fields_diagnostic
  export -f check_file_permissions_diagnostic
  export -f check_dependencies_diagnostics
  export -f check_required_commands_diagnostic
  export -f check_optional_commands_diagnostic
  export -f check_performance_diagnostics
  export -f check_plugin_performance_diagnostic
  export -f check_plugins_diagnostics
  export -f check_plugin_availability_diagnostic
  export -f get_diagnostic_summary
  export -f cleanup_diagnostic_reports
fi

# Helper function to safely format JSON arrays
format_json_array() {
  local -a array=("$@")
  if [ ${#array[@]} -eq 0 ]; then
    echo ""
  else
    printf '"%s",' "${array[@]}" | sed 's/,$//'
  fi
}

# New standardized function: diagnostics_get_summary
# Description: Get diagnostic summary from report file
# Parameters:
#   $1 - report file path (optional, uses latest if not provided)
# Returns:
#   Summary JSON via stdout
#   0 - success
#   1 - failure
diagnostics_get_summary() {
  local report_file="$1"

  # If no report file specified, find the latest one
  if [[ -z "$report_file" ]]; then
    if [[ -d "$DIAGNOSTICS_REPORT_DIR" ]]; then
      report_file=$(find "$DIAGNOSTICS_REPORT_DIR" -name "full_diagnostic_*.json" -type f 2>/dev/null | sort -r | head -1)
    fi
  fi

  # Validate report file exists
  if ! util_validate_file_exists "$report_file" "Diagnostics report"; then
    log_error "No diagnostics report found"
    return 1
  fi

  # Extract summary from report using JSON utilities
  local summary
  if summary=$(util_json_get_value "$(cat "$report_file")" ".summary" 2>/dev/null); then
    echo "$summary"
    return 0
  else
    log_error "Failed to extract summary from report: $report_file"
    return 1
  fi
}

# New standardized function: diagnostics_cleanup_reports
# Description: Clean up old diagnostic reports based on retention policy
# Returns:
#   0 - success
#   1 - failure
diagnostics_cleanup_reports() {
  log_debug "Cleaning up old diagnostic reports"

  if ! util_validate_dir_exists "$DIAGNOSTICS_REPORT_DIR" "Diagnostics report directory"; then
    log_warning "Diagnostics report directory not found: $DIAGNOSTICS_REPORT_DIR"
    return 1
  fi

  # Get retention days from configuration
  local keep_days
  keep_days=$(util_config_get_value "keep_reports_days" "30" "$DIAGNOSTICS_NAMESPACE")

  # Validate retention days is numeric
  if ! util_validate_numeric "$keep_days" "keep_reports_days"; then
    log_warning "Invalid keep_reports_days value: $keep_days, using default 30"
    keep_days="30"
  fi

  # Find and remove old reports
  local deleted_count=0
  while IFS= read -r -d '' report_file; do
    # Check if file is older than retention period
    local file_age_days
    if command -v stat >/dev/null 2>&1; then
      local file_time
      file_time=$(stat -c %Y "$report_file" 2>/dev/null || stat -f %m "$report_file" 2>/dev/null || echo "0")
      local current_time
      current_time=$(date +%s)
      file_age_days=$(((current_time - file_time) / 86400))

      if [[ "$file_age_days" -gt "$keep_days" ]]; then
        if rm "$report_file" 2>/dev/null; then
          log_debug "Deleted old diagnostic report: $report_file (${file_age_days} days old)"
          deleted_count=$((deleted_count + 1))
        else
          log_warning "Failed to delete old diagnostic report: $report_file"
        fi
      fi
    fi
  done < <(find "$DIAGNOSTICS_REPORT_DIR" -name "full_diagnostic_*.json" -type f -print0 2>/dev/null)

  log_info "Cleaned up $deleted_count old diagnostic reports (retention: $keep_days days)"
  return 0
}

# Helper function: _diagnostics_format_json_array
# Description: Format array elements as JSON array (fallback for older systems)
# Parameters:
#   $@ - array elements
# Returns:
#   JSON array string via stdout
_diagnostics_format_json_array() {
  local elements=("$@")
  local json_array="["

  for i in "${!elements[@]}"; do
    if [[ $i -gt 0 ]]; then
      json_array+=", "
    fi
    # Escape quotes and backslashes in the element
    local escaped_element
    escaped_element=$(echo "${elements[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    json_array+="\"$escaped_element\""
  done

  json_array+="]"
  echo "$json_array"
}

# =============================================================================
# BACKWARD COMPATIBILITY SECTION
# =============================================================================
# The following functions provide backward compatibility with the old naming
# convention. They are deprecated and will be removed in a future version.

# Deprecated: Use diagnostics_system_init instead
init_diagnostics_system() {
  log_warning "Function 'init_diagnostics_system' is deprecated. Use 'diagnostics_system_init' instead."
  diagnostics_system_init "$@"
}

# Deprecated: Use diagnostics_create_default_config instead
create_default_diagnostics_config() {
  log_warning "Function 'create_default_diagnostics_config' is deprecated. Use 'diagnostics_create_default_config' instead."
  diagnostics_create_default_config "$@"
}

# Deprecated: Use diagnostics_load_config instead
parse_diagnostics_config() {
  log_warning "Function 'parse_diagnostics_config' is deprecated. Use 'diagnostics_load_config' instead."
  diagnostics_load_config "$@"
}

# Deprecated: Use diagnostics_run_full instead
run_full_diagnostics() {
  log_warning "Function 'run_full_diagnostics' is deprecated. Use 'diagnostics_run_full' instead."
  diagnostics_run_full "$@"
}

# Deprecated: Use diagnostics_check_system_health instead
check_system_health_diagnostics() {
  log_warning "Function 'check_system_health_diagnostics' is deprecated. Use 'diagnostics_check_system_health' instead."
  diagnostics_check_system_health "$@"
}

# Deprecated: Use diagnostics_check_disk_space instead
check_disk_space_diagnostic() {
  log_warning "Function 'check_disk_space_diagnostic' is deprecated. Use 'diagnostics_check_disk_space' instead."
  diagnostics_check_disk_space "$@"
}

# Deprecated: Use diagnostics_check_memory_usage instead
check_memory_usage_diagnostic() {
  log_warning "Function 'check_memory_usage_diagnostic' is deprecated. Use 'diagnostics_check_memory_usage' instead."
  diagnostics_check_memory_usage "$@"
}

# Deprecated: Use diagnostics_check_load_average instead
check_load_average_diagnostic() {
  log_warning "Function 'check_load_average_diagnostic' is deprecated. Use 'diagnostics_check_load_average' instead."
  diagnostics_check_load_average "$@"
}

# Deprecated: Use diagnostics_check_configuration instead
check_configuration_diagnostics() {
  log_warning "Function 'check_configuration_diagnostics' is deprecated. Use 'diagnostics_check_configuration' instead."
  diagnostics_check_configuration "$@"
}

# Deprecated: Use diagnostics_check_yaml_syntax instead
check_yaml_syntax_diagnostic() {
  log_warning "Function 'check_yaml_syntax_diagnostic' is deprecated. Use 'diagnostics_check_yaml_syntax' instead."
  diagnostics_check_yaml_syntax "$@"
}

# Deprecated: Use diagnostics_check_required_fields instead
check_required_fields_diagnostic() {
  log_warning "Function 'check_required_fields_diagnostic' is deprecated. Use 'diagnostics_check_required_fields' instead."
  diagnostics_check_required_fields "$@"
}

# Deprecated: Use diagnostics_check_file_permissions instead
check_file_permissions_diagnostic() {
  log_warning "Function 'check_file_permissions_diagnostic' is deprecated. Use 'diagnostics_check_file_permissions' instead."
  diagnostics_check_file_permissions "$@"
}

# Deprecated: Use diagnostics_check_dependencies instead
check_dependencies_diagnostics() {
  log_warning "Function 'check_dependencies_diagnostics' is deprecated. Use 'diagnostics_check_dependencies' instead."
  diagnostics_check_dependencies "$@"
}

# Deprecated: Use diagnostics_check_required_commands instead
check_required_commands_diagnostic() {
  log_warning "Function 'check_required_commands_diagnostic' is deprecated. Use 'diagnostics_check_required_commands' instead."
  diagnostics_check_required_commands "$@"
}

# Deprecated: Use diagnostics_check_optional_commands instead
check_optional_commands_diagnostic() {
  log_warning "Function 'check_optional_commands_diagnostic' is deprecated. Use 'diagnostics_check_optional_commands' instead."
  diagnostics_check_optional_commands "$@"
}

# Deprecated: Use diagnostics_check_performance instead
check_performance_diagnostics() {
  log_warning "Function 'check_performance_diagnostics' is deprecated. Use 'diagnostics_check_performance' instead."
  diagnostics_check_performance "$@"
}

# Deprecated: Use diagnostics_check_plugin_performance instead
check_plugin_performance_diagnostic() {
  log_warning "Function 'check_plugin_performance_diagnostic' is deprecated. Use 'diagnostics_check_plugin_performance' instead."
  diagnostics_check_plugin_performance "$@"
}

# Deprecated: Use diagnostics_check_plugins instead
check_plugins_diagnostics() {
  log_warning "Function 'check_plugins_diagnostics' is deprecated. Use 'diagnostics_check_plugins' instead."
  diagnostics_check_plugins "$@"
}

# Deprecated: Use diagnostics_check_plugin_availability instead
check_plugin_availability_diagnostic() {
  log_warning "Function 'check_plugin_availability_diagnostic' is deprecated. Use 'diagnostics_check_plugin_availability' instead."
  diagnostics_check_plugin_availability "$@"
}

# Deprecated: Use diagnostics_get_summary instead
get_diagnostic_summary() {
  log_warning "Function 'get_diagnostic_summary' is deprecated. Use 'diagnostics_get_summary' instead."
  diagnostics_get_summary "$@"
}

# Deprecated: Use diagnostics_cleanup_reports instead
cleanup_diagnostic_reports() {
  log_warning "Function 'cleanup_diagnostic_reports' is deprecated. Use 'diagnostics_cleanup_reports' instead."
  diagnostics_cleanup_reports "$@"
}

# Deprecated: Use _diagnostics_format_json_array instead
format_json_array() {
  log_warning "Function 'format_json_array' is deprecated. Use '_diagnostics_format_json_array' instead."
  _diagnostics_format_json_array "$@"
}

# =============================================================================
# END OF BACKWARD COMPATIBILITY SECTION
# =============================================================================

log_debug "Diagnostics module loaded successfully"
