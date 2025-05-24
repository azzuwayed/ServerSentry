#!/bin/bash
#
# ServerSentry v2 - Self-Diagnostics System
#
# This module provides comprehensive system health checks, configuration validation,
# dependency verification, and performance diagnostics

# Diagnostics configuration
DIAGNOSTICS_LOG_DIR="${BASE_DIR}/logs/diagnostics"
DIAGNOSTICS_REPORT_DIR="${BASE_DIR}/logs/diagnostics/reports"
DIAGNOSTICS_CONFIG_FILE="${BASE_DIR}/config/diagnostics.conf"

# Diagnostic levels
DIAGNOSTIC_LEVEL_INFO=0
DIAGNOSTIC_LEVEL_WARNING=1
DIAGNOSTIC_LEVEL_ERROR=2
DIAGNOSTIC_LEVEL_CRITICAL=3

# Initialize diagnostics system
init_diagnostics_system() {
  log_debug "Initializing self-diagnostics system"

  # Create directories if they don't exist
  for dir in "$DIAGNOSTICS_LOG_DIR" "$DIAGNOSTICS_REPORT_DIR"; do
    if [ ! -d "$dir" ]; then
      mkdir -p "$dir"
      log_debug "Created diagnostics directory: $dir"
    fi
  done

  # Create default diagnostics configuration
  create_default_diagnostics_config

  return 0
}

# Create default diagnostics configuration
create_default_diagnostics_config() {
  if [ ! -f "$DIAGNOSTICS_CONFIG_FILE" ]; then
    cat >"$DIAGNOSTICS_CONFIG_FILE" <<'EOF'
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
    log_debug "Created default diagnostics configuration"
  fi
}

# Parse diagnostics configuration
parse_diagnostics_config() {
  if [ ! -f "$DIAGNOSTICS_CONFIG_FILE" ]; then
    log_warning "Diagnostics config file not found: $DIAGNOSTICS_CONFIG_FILE"
    return 1
  fi

  # Source the configuration file
  source "$DIAGNOSTICS_CONFIG_FILE"

  # Set defaults for any missing values
  check_system_health="${check_system_health:-true}"
  check_configuration="${check_configuration:-true}"
  check_dependencies="${check_dependencies:-true}"
  check_performance="${check_performance:-true}"
  check_plugins="${check_plugins:-true}"
  check_notifications="${check_notifications:-true}"
  check_logs="${check_logs:-true}"
  check_permissions="${check_permissions:-true}"

  return 0
}

# Run complete diagnostic suite
run_full_diagnostics() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local report_file="$DIAGNOSTICS_REPORT_DIR/full_diagnostic_$(date +%Y%m%d_%H%M%S).json"

  log_info "Running full system diagnostics..."

  # Parse configuration
  parse_diagnostics_config

  # Initialize report structure
  local diagnostics_report
  diagnostics_report=$(
    cat <<EOF
{
  "diagnostic_run": {
    "timestamp": "$timestamp",
    "version": "2.0.0",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "working_directory": "$BASE_DIR"
  },
  "results": {
    "system_health": {},
    "configuration": {},
    "dependencies": {},
    "performance": {},
    "plugins": {},
    "notifications": {},
    "logs": {},
    "permissions": {}
  },
  "summary": {
    "total_checks": 0,
    "passed": 0,
    "warnings": 0,
    "errors": 0,
    "critical": 0
  }
}
EOF
  )

  # Run diagnostic categories
  local total_checks=0 passed=0 warnings=0 errors=0 critical=0

  if [ "$check_system_health" = "true" ]; then
    local health_results
    health_results=$(check_system_health_diagnostics)
    diagnostics_report=$(echo "$diagnostics_report" | jq ".results.system_health = $health_results")

    # Update counters
    local health_stats
    health_stats=$(echo "$health_results" | jq -r '.summary | "\(.total)|\(.passed)|\(.warnings)|\(.errors)|\(.critical)"')
    IFS='|' read -r h_total h_passed h_warnings h_errors h_critical <<<"$health_stats"

    total_checks=$((total_checks + h_total))
    passed=$((passed + h_passed))
    warnings=$((warnings + h_warnings))
    errors=$((errors + h_errors))
    critical=$((critical + h_critical))
  fi

  if [ "$check_configuration" = "true" ]; then
    local config_results
    config_results=$(check_configuration_diagnostics)
    diagnostics_report=$(echo "$diagnostics_report" | jq ".results.configuration = $config_results")

    local config_stats
    config_stats=$(echo "$config_results" | jq -r '.summary | "\(.total)|\(.passed)|\(.warnings)|\(.errors)|\(.critical)"')
    IFS='|' read -r c_total c_passed c_warnings c_errors c_critical <<<"$config_stats"

    total_checks=$((total_checks + c_total))
    passed=$((passed + c_passed))
    warnings=$((warnings + c_warnings))
    errors=$((errors + c_errors))
    critical=$((critical + c_critical))
  fi

  if [ "$check_dependencies" = "true" ]; then
    local deps_results
    deps_results=$(check_dependencies_diagnostics)
    diagnostics_report=$(echo "$diagnostics_report" | jq ".results.dependencies = $deps_results")

    local deps_stats
    deps_stats=$(echo "$deps_results" | jq -r '.summary | "\(.total)|\(.passed)|\(.warnings)|\(.errors)|\(.critical)"')
    IFS='|' read -r d_total d_passed d_warnings d_errors d_critical <<<"$deps_stats"

    total_checks=$((total_checks + d_total))
    passed=$((passed + d_passed))
    warnings=$((warnings + d_warnings))
    errors=$((errors + d_errors))
    critical=$((critical + d_critical))
  fi

  if [ "$check_performance" = "true" ]; then
    local perf_results
    perf_results=$(check_performance_diagnostics)
    diagnostics_report=$(echo "$diagnostics_report" | jq ".results.performance = $perf_results")

    local perf_stats
    perf_stats=$(echo "$perf_results" | jq -r '.summary | "\(.total)|\(.passed)|\(.warnings)|\(.errors)|\(.critical)"')
    IFS='|' read -r p_total p_passed p_warnings p_errors p_critical <<<"$perf_stats"

    total_checks=$((total_checks + p_total))
    passed=$((passed + p_passed))
    warnings=$((warnings + p_warnings))
    errors=$((errors + p_errors))
    critical=$((critical + p_critical))
  fi

  if [ "$check_plugins" = "true" ]; then
    local plugin_results
    plugin_results=$(check_plugins_diagnostics)
    diagnostics_report=$(echo "$diagnostics_report" | jq ".results.plugins = $plugin_results")

    local plugin_stats
    plugin_stats=$(echo "$plugin_results" | jq -r '.summary | "\(.total)|\(.passed)|\(.warnings)|\(.errors)|\(.critical)"')
    IFS='|' read -r pl_total pl_passed pl_warnings pl_errors pl_critical <<<"$plugin_stats"

    total_checks=$((total_checks + pl_total))
    passed=$((passed + pl_passed))
    warnings=$((warnings + pl_warnings))
    errors=$((errors + pl_errors))
    critical=$((critical + pl_critical))
  fi

  # Update summary
  diagnostics_report=$(echo "$diagnostics_report" | jq \
    ".summary.total_checks = $total_checks | 
     .summary.passed = $passed | 
     .summary.warnings = $warnings | 
     .summary.errors = $errors | 
     .summary.critical = $critical")

  # Save report
  echo "$diagnostics_report" >"$report_file"

  # Output summary
  echo "Diagnostics Complete - Report saved to: $report_file"
  echo "Summary: $total_checks total, $passed passed, $warnings warnings, $errors errors, $critical critical"

  # Return non-zero if there are errors or critical issues
  if [ "$critical" -gt 0 ]; then
    return 3
  elif [ "$errors" -gt 0 ]; then
    return 2
  elif [ "$warnings" -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Check system health diagnostics
check_system_health_diagnostics() {
  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Disk space check
  if [ "$check_disk_space" = "true" ]; then
    local disk_check
    disk_check=$(check_disk_space_diagnostic)
    checks+=("$disk_check")

    local level
    level=$(echo "$disk_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Memory usage check
  if [ "$check_memory_usage" = "true" ]; then
    local memory_info usage

    # Use cross-platform method to get memory usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      local vm_stat_output
      vm_stat_output=$(vm_stat)
      local page_size
      page_size=$(pagesize)

      local pages_active pages_inactive pages_speculative pages_wired pages_free
      pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
      pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
      pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')
      pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')
      pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')

      local total_pages used_pages
      total_pages=$((pages_active + pages_inactive + pages_speculative + pages_wired + pages_free))
      used_pages=$((pages_active + pages_inactive + pages_wired))

      if [ "$total_pages" -gt 0 ]; then
        usage=$(echo "scale=0; $used_pages * 100 / $total_pages" | bc 2>/dev/null || echo "0")
      else
        usage=0
      fi
    elif command -v free >/dev/null 2>&1; then
      # Linux
      memory_info=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
      usage=$(echo "$memory_info" | cut -d'.' -f1)
    else
      usage=0
    fi

    # Ensure usage is not empty and is a valid number
    if [ -z "$usage" ] || [ "$usage" = "" ] || ! [[ "$usage" =~ ^[0-9]+$ ]]; then
      usage="0"
    fi

    local level=0
    local status="OK"
    local message="Memory usage: ${usage}%"

    if [ "$usage" -ge "${memory_threshold_critical:-95}" ]; then
      level=3
      status="CRITICAL"
      message="Critical memory usage: ${usage}%"
    elif [ "$usage" -ge "${memory_threshold_warning:-85}" ]; then
      level=1
      status="WARNING"
      message="High memory usage: ${usage}%"
    fi

    local memory_check=$(
      cat <<EOF
{
  "name": "memory_usage",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "usage_percent": $usage,
    "warning_threshold": ${memory_threshold_warning:-85},
    "critical_threshold": ${memory_threshold_critical:-95}
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    )
    checks+=("$memory_check")

    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Load average check
  if [ "$check_load_average" = "true" ]; then
    local load_check
    load_check=$(check_load_average_diagnostic)
    checks+=("$load_check")

    local level
    level=$(echo "$load_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Create JSON array from checks
  local checks_json="[]"
  for check in "${checks[@]}"; do
    checks_json=$(echo "$checks_json" | jq ". += [$check]")
  done

  cat <<EOF
{
  "checks": $checks_json,
  "summary": {
    "total": $total,
    "passed": $passed,
    "warnings": $warnings,
    "errors": $errors,
    "critical": $critical
  }
}
EOF
}

# Individual diagnostic checks
check_disk_space_diagnostic() {
  local usage
  usage=$(df "$BASE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

  # Ensure usage is not empty and is a valid number
  if [ -z "$usage" ] || [ "$usage" = "" ] || ! [[ "$usage" =~ ^[0-9]+$ ]]; then
    usage="0"
  fi

  local level=0
  local status="OK"
  local message="Disk usage: ${usage}%"

  if [ "$usage" -ge "${disk_threshold_critical:-98}" ]; then
    level=3
    status="CRITICAL"
    message="Critical disk usage: ${usage}%"
  elif [ "$usage" -ge "${disk_threshold_warning:-90}" ]; then
    level=1
    status="WARNING"
    message="High disk usage: ${usage}%"
  fi

  cat <<EOF
{
  "name": "disk_space",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "usage_percent": $usage,
    "warning_threshold": ${disk_threshold_warning:-90},
    "critical_threshold": ${disk_threshold_critical:-98}
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

check_memory_usage_diagnostic() {
  local memory_info usage

  # Use cross-platform method to get memory usage
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    local vm_stat_output
    vm_stat_output=$(vm_stat)
    local page_size
    page_size=$(pagesize)

    local pages_active pages_inactive pages_speculative pages_wired pages_free
    pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
    pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
    pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')
    pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')
    pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')

    local total_pages used_pages
    total_pages=$((pages_active + pages_inactive + pages_speculative + pages_wired + pages_free))
    used_pages=$((pages_active + pages_inactive + pages_wired))

    if [ "$total_pages" -gt 0 ]; then
      usage=$(echo "scale=0; $used_pages * 100 / $total_pages" | bc 2>/dev/null || echo "0")
    else
      usage=0
    fi
  elif command -v free >/dev/null 2>&1; then
    # Linux
    memory_info=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    usage=$(echo "$memory_info" | cut -d'.' -f1)
  else
    usage=0
  fi

  # Ensure usage is not empty and is a valid number
  if [ -z "$usage" ] || [ "$usage" = "" ] || ! [[ "$usage" =~ ^[0-9]+$ ]]; then
    usage="0"
  fi

  local level=0
  local status="OK"
  local message="Memory usage: ${usage}%"

  if [ "$usage" -ge "${memory_threshold_critical:-95}" ]; then
    level=3
    status="CRITICAL"
    message="Critical memory usage: ${usage}%"
  elif [ "$usage" -ge "${memory_threshold_warning:-85}" ]; then
    level=1
    status="WARNING"
    message="High memory usage: ${usage}%"
  fi

  cat <<EOF
{
  "name": "memory_usage",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "usage_percent": $usage,
    "warning_threshold": ${memory_threshold_warning:-85},
    "critical_threshold": ${memory_threshold_critical:-95}
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

check_load_average_diagnostic() {
  local load_1min cpu_cores load_percent

  # Get load average (works on both Linux and macOS)
  load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' | sed 's/^[[:space:]]*//')

  # Default to 0 if load_1min is empty
  if [ -z "$load_1min" ] || [ "$load_1min" = "" ]; then
    load_1min="0.00"
  fi

  # Get CPU cores - use macOS compatible method
  if [[ "$OSTYPE" == "darwin"* ]]; then
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
  else
    cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
  fi

  # Ensure cpu_cores is not empty
  if [ -z "$cpu_cores" ] || [ "$cpu_cores" = "" ]; then
    cpu_cores="1"
  fi

  # Calculate load percentage
  load_percent=$(echo "scale=0; $load_1min * 100 / $cpu_cores" | bc 2>/dev/null || echo "0")

  # Ensure load_percent is not empty
  if [ -z "$load_percent" ] || [ "$load_percent" = "" ]; then
    load_percent="0"
  fi

  local level=0
  local status="OK"
  local message="Load average: $load_1min (${load_percent}% of $cpu_cores cores)"

  if [ "$load_percent" -ge "200" ]; then
    level=3
    status="CRITICAL"
    message="Critical load average: $load_1min (${load_percent}% of $cpu_cores cores)"
  elif [ "$load_percent" -ge "150" ]; then
    level=1
    status="WARNING"
    message="High load average: $load_1min (${load_percent}% of $cpu_cores cores)"
  fi

  cat <<EOF
{
  "name": "load_average",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "load_1min": "$load_1min",
    "cpu_cores": $cpu_cores,
    "load_percent": $load_percent
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Check configuration diagnostics
check_configuration_diagnostics() {
  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # YAML syntax validation
  if [ "$validate_yaml_syntax" = "true" ]; then
    local yaml_check
    yaml_check=$(check_yaml_syntax_diagnostic)
    checks+=("$yaml_check")

    local level
    level=$(echo "$yaml_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Required fields validation
  if [ "$validate_required_fields" = "true" ]; then
    local fields_check
    fields_check=$(check_required_fields_diagnostic)
    checks+=("$fields_check")

    local level
    level=$(echo "$fields_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # File permissions validation
  if [ "$validate_file_permissions" = "true" ]; then
    local perms_check
    perms_check=$(check_file_permissions_diagnostic)
    checks+=("$perms_check")

    local level
    level=$(echo "$perms_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Create JSON array from checks
  local checks_json="[]"
  for check in "${checks[@]}"; do
    checks_json=$(echo "$checks_json" | jq ". += [$check]")
  done

  cat <<EOF
{
  "checks": $checks_json,
  "summary": {
    "total": $total,
    "passed": $passed,
    "warnings": $warnings,
    "errors": $errors,
    "critical": $critical
  }
}
EOF
}

check_yaml_syntax_diagnostic() {
  local level=0
  local status="OK"
  local message="YAML configuration syntax is valid"

  if [ -f "$MAIN_CONFIG" ]; then
    if command -v yq >/dev/null 2>&1; then
      if ! yq eval . "$MAIN_CONFIG" >/dev/null 2>&1; then
        level=2
        status="ERROR"
        message="Invalid YAML syntax in configuration file"
      fi
    else
      level=1
      status="WARNING"
      message="Cannot validate YAML syntax (yq not available)"
    fi
  else
    level=2
    status="ERROR"
    message="Main configuration file not found: $MAIN_CONFIG"
  fi

  cat <<EOF
{
  "name": "yaml_syntax",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "config_file": "$MAIN_CONFIG",
    "yq_available": $(command -v yq >/dev/null 2>&1 && echo "true" || echo "false")
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

check_required_fields_diagnostic() {
  local level=0
  local status="OK"
  local message="All required configuration fields are present"
  local missing_fields=()

  if [ -f "$MAIN_CONFIG" ]; then
    local required_fields=("enabled" "log_level" "check_interval")
    for field in "${required_fields[@]}"; do
      if ! grep -q "^${field}:" "$MAIN_CONFIG"; then
        missing_fields+=("$field")
      fi
    done

    if [ ${#missing_fields[@]} -gt 0 ]; then
      level=2
      status="ERROR"
      message="Missing required configuration fields: ${missing_fields[*]}"
    fi
  else
    level=2
    status="ERROR"
    message="Configuration file not found"
  fi

  cat <<EOF
{
  "name": "required_fields",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "missing_fields": [$(format_json_array "${missing_fields[@]}")],
    "required_fields": ["enabled", "log_level", "check_interval"]
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

check_file_permissions_diagnostic() {
  local level=0
  local status="OK"
  local message="File permissions are correct"
  local permission_issues=()

  # Check main executable
  if [ ! -x "$BASE_DIR/bin/serversentry" ]; then
    permission_issues+=("Main executable not executable")
    level=2
  fi

  # Check log directory
  if [ ! -w "$BASE_DIR/logs" ]; then
    permission_issues+=("Log directory not writable")
    level=2
  fi

  # Check config directory
  if [ ! -r "$BASE_DIR/config" ]; then
    permission_issues+=("Config directory not readable")
    level=2
  fi

  if [ ${#permission_issues[@]} -gt 0 ]; then
    status="ERROR"
    message="File permission issues detected: ${permission_issues[*]}"
  fi

  cat <<EOF
{
  "name": "file_permissions",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "issues": [$(format_json_array "${permission_issues[@]}")],
    "checked_paths": ["$BASE_DIR/bin/serversentry", "$BASE_DIR/logs", "$BASE_DIR/config"]
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Check dependencies diagnostics
check_dependencies_diagnostics() {
  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Required commands check
  if [ "$check_required_commands" = "true" ]; then
    local cmd_check
    cmd_check=$(check_required_commands_diagnostic)
    checks+=("$cmd_check")

    local level
    level=$(echo "$cmd_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Optional commands check
  if [ "$check_optional_commands" = "true" ]; then
    local opt_cmd_check
    opt_cmd_check=$(check_optional_commands_diagnostic)
    checks+=("$opt_cmd_check")

    local level
    level=$(echo "$opt_cmd_check" | jq -r '.level')
    total=$((total + 1))
    case "$level" in
    0) passed=$((passed + 1)) ;;
    1) warnings=$((warnings + 1)) ;;
    2) errors=$((errors + 1)) ;;
    3) critical=$((critical + 1)) ;;
    esac
  fi

  # Create JSON array from checks
  local checks_json="[]"
  for check in "${checks[@]}"; do
    checks_json=$(echo "$checks_json" | jq ". += [$check]")
  done

  cat <<EOF
{
  "checks": $checks_json,
  "summary": {
    "total": $total,
    "passed": $passed,
    "warnings": $warnings,
    "errors": $errors,
    "critical": $critical
  }
}
EOF
}

check_required_commands_diagnostic() {
  local level=0
  local status="OK"
  local message="All required commands are available"
  local missing_commands=()

  local required_commands=("ps" "grep" "awk" "sed" "tail" "head" "cat" "date")
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done

  if [ ${#missing_commands[@]} -gt 0 ]; then
    level=3
    status="CRITICAL"
    message="Missing required commands: ${missing_commands[*]}"
  fi

  cat <<EOF
{
  "name": "required_commands",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "missing_commands": [$(format_json_array "${missing_commands[@]}")],
    "required_commands": [$(format_json_array "${required_commands[@]}")]
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

check_optional_commands_diagnostic() {
  local level=0
  local status="OK"
  local message="Optional commands status checked"
  local missing_commands=()
  local available_commands=()

  local optional_commands=("jq" "yq" "bc" "curl" "wget" "dialog" "whiptail")
  for cmd in "${optional_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      available_commands+=("$cmd")
    else
      missing_commands+=("$cmd")
    fi
  done

  if [ ${#missing_commands[@]} -gt 0 ]; then
    level=1
    status="WARNING"
    message="Some optional commands are missing: ${missing_commands[*]}"
  fi

  cat <<EOF
{
  "name": "optional_commands",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "available_commands": [$(format_json_array "${available_commands[@]}")],
    "missing_commands": [$(format_json_array "${missing_commands[@]}")],
    "optional_commands": [$(format_json_array "${optional_commands[@]}")]
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Check performance diagnostics
check_performance_diagnostics() {
  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Plugin execution time check
  local perf_check
  perf_check=$(check_plugin_performance_diagnostic)
  checks+=("$perf_check")

  local level
  level=$(echo "$perf_check" | jq -r '.level')
  total=$((total + 1))
  case "$level" in
  0) passed=$((passed + 1)) ;;
  1) warnings=$((warnings + 1)) ;;
  2) errors=$((errors + 1)) ;;
  3) critical=$((critical + 1)) ;;
  esac

  # Create JSON array from checks
  local checks_json="[]"
  for check in "${checks[@]}"; do
    checks_json=$(echo "$checks_json" | jq ". += [$check]")
  done

  cat <<EOF
{
  "checks": $checks_json,
  "summary": {
    "total": $total,
    "passed": $passed,
    "warnings": $warnings,
    "errors": $errors,
    "critical": $critical
  }
}
EOF
}

check_plugin_performance_diagnostic() {
  local level=0
  local status="OK"
  local message="Plugin performance is acceptable"

  # Time the plugin execution
  local start_time
  start_time=$(date +%s%N)

  local plugin_results
  plugin_results=$(run_all_plugin_checks 2>/dev/null)

  local end_time
  end_time=$(date +%s%N)

  local execution_time_ms
  execution_time_ms=$(echo "scale=0; ($end_time - $start_time) / 1000000" | bc 2>/dev/null || echo "0")

  if [ "$execution_time_ms" -gt "10000" ]; then
    level=2
    status="ERROR"
    message="Plugin execution is very slow: ${execution_time_ms}ms"
  elif [ "$execution_time_ms" -gt "5000" ]; then
    level=1
    status="WARNING"
    message="Plugin execution is slow: ${execution_time_ms}ms"
  else
    message="Plugin execution time: ${execution_time_ms}ms"
  fi

  cat <<EOF
{
  "name": "plugin_performance",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "execution_time_ms": $execution_time_ms,
    "warning_threshold_ms": 5000,
    "error_threshold_ms": 10000
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Check plugins diagnostics
check_plugins_diagnostics() {
  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # Plugin availability check
  local plugin_check
  plugin_check=$(check_plugin_availability_diagnostic)
  checks+=("$plugin_check")

  local level
  level=$(echo "$plugin_check" | jq -r '.level')
  total=$((total + 1))
  case "$level" in
  0) passed=$((passed + 1)) ;;
  1) warnings=$((warnings + 1)) ;;
  2) errors=$((errors + 1)) ;;
  3) critical=$((critical + 1)) ;;
  esac

  # Create JSON array from checks
  local checks_json="[]"
  for check in "${checks[@]}"; do
    checks_json=$(echo "$checks_json" | jq ". += [$check]")
  done

  cat <<EOF
{
  "checks": $checks_json,
  "summary": {
    "total": $total,
    "passed": $passed,
    "warnings": $warnings,
    "errors": $errors,
    "critical": $critical
  }
}
EOF
}

check_plugin_availability_diagnostic() {
  local level=0
  local status="OK"
  local message="Plugin system is functional"
  local available_plugins=()
  local failed_plugins=()

  # Check core plugins
  local core_plugins=("cpu" "memory" "disk" "process")
  for plugin in "${core_plugins[@]}"; do
    if [ -f "$BASE_DIR/lib/plugins/$plugin/$plugin.sh" ]; then
      available_plugins+=("$plugin")
    else
      failed_plugins+=("$plugin")
    fi
  done

  if [ ${#failed_plugins[@]} -gt 0 ]; then
    level=2
    status="ERROR"
    message="Missing core plugins: ${failed_plugins[*]}"
  fi

  cat <<EOF
{
  "name": "plugin_availability",
  "level": $level,
  "status": "$status",
  "message": "$message",
  "details": {
    "available_plugins": [$(format_json_array "${available_plugins[@]}")],
    "failed_plugins": [$(format_json_array "${failed_plugins[@]}")],
    "core_plugins": [$(format_json_array "${core_plugins[@]}")]
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
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
    check_date=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null)

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
  export -f init_diagnostics_system
  export -f run_full_diagnostics
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
