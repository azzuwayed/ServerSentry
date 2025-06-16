#!/usr/bin/env bash
#
# ServerSentry v2 - Self-Diagnostics System
#
# This module provides comprehensive system health checks, configuration validation,
# dependency verification, and performance diagnostics

# Source utilities and modular diagnostics
source "${BASE_DIR}/lib/core/logging.sh"
source "${BASE_DIR}/lib/core/utils.sh"
source "${BASE_DIR}/lib/plugins/diagnostics/system_health.sh"
source "${BASE_DIR}/lib/plugins/diagnostics/configuration.sh"

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

# Function: diagnostics_plugin_init
# Description: Initialize full diagnostics system with proper validation and directory setup
# Returns:
#   0 - success
#   1 - failure
diagnostics_plugin_init() {
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

# Function: diagnostics_create_default_config
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

# Function: diagnostics_load_config
# Description: Load and validate diagnostics configuration using unified utilities
# Returns:
#   0 - success
#   1 - failure
diagnostics_load_config() {
  log_debug "Loading diagnostics configuration"

  # Initialize diagnostics system
  if ! diagnostics_plugin_init; then
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

# Function: diagnostics_plugin_run_full
# Description: Run complete diagnostic suite with enhanced error handling and reporting
# Returns:
#   0 - all checks passed
#   1 - warnings found
#   2 - errors found
#   3 - critical issues found
diagnostics_plugin_run_full() {
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

  # System health diagnostics (using modular function)
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

  # Configuration diagnostics (using modular function)
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

# NOTE: System health and configuration functions have been moved to modular files:
# - lib/core/diagnostics/system_health.sh
# - lib/core/diagnostics/configuration.sh

# Remaining functions that haven't been modularized yet:

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

# Export plugin functions (avoid conflicts with core stubs)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f diagnostics_plugin_init
  export -f diagnostics_create_default_config
  export -f diagnostics_load_config
  export -f diagnostics_plugin_run_full
  export -f diagnostics_get_summary
  export -f diagnostics_cleanup_reports
  export -f format_json_array
  export -f _diagnostics_parse_shell_config
  export -f _diagnostics_update_counters

  # Note: get_diagnostic_summary and cleanup_diagnostic_reports are handled by core stubs
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
