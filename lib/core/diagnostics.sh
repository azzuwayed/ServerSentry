#!/usr/bin/env bash
#
# ServerSentry v2 - Diagnostics Stub (Simplified Core Version)
#
# This is a simplified stub that provides basic diagnostics interface
# The full diagnostics system has been moved to optional plugins

# Prevent multiple sourcing
if [[ "${DIAGNOSTICS_STUB_LOADED:-}" == "true" ]]; then
  return 0
fi
DIAGNOSTICS_STUB_LOADED=true
export DIAGNOSTICS_STUB_LOADED

# Simple diagnostics configuration
DIAGNOSTICS_ENABLED="${DIAGNOSTICS_ENABLED:-true}"
DIAGNOSTICS_LOG_DIR="${BASE_DIR}/logs"

# Function: diagnostics_system_init
# Description: Initialize simplified diagnostics (stub version)
# Parameters: None
# Returns: 0 - success, 1 - failure
diagnostics_system_init() {
  if [[ "${DIAGNOSTICS_ENABLED}" == "true" ]]; then
    echo "INFO: Basic diagnostics enabled" >&2
  else
    echo "INFO: Diagnostics disabled" >&2
  fi
  return 0
}

# Function: diagnostics_run_full
# Description: Run basic system diagnostics (stub version)
# Parameters: None
# Returns: 0 - success, 1 - warnings, 2 - errors
diagnostics_run_full() {
  echo "Running basic system diagnostics..."

  local issues=0

  # Basic checks only
  echo "Checking basic system health..."

  # Check if base directory exists
  if [[ ! -d "${BASE_DIR}" ]]; then
    echo "ERROR: Base directory not found: ${BASE_DIR}"
    ((issues++))
  else
    echo "✅ Base directory: ${BASE_DIR}"
  fi

  # Check if logs directory exists
  if [[ ! -d "${DIAGNOSTICS_LOG_DIR}" ]]; then
    echo "WARNING: Logs directory not found: ${DIAGNOSTICS_LOG_DIR}"
    mkdir -p "${DIAGNOSTICS_LOG_DIR}" 2>/dev/null || ((issues++))
  else
    echo "✅ Logs directory: ${DIAGNOSTICS_LOG_DIR}"
  fi

  # Check basic commands
  local required_commands=("bash" "date" "whoami")
  for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "✅ Command available: $cmd"
    else
      echo "ERROR: Required command not found: $cmd"
      ((issues++))
    fi
  done

  # Basic disk space check
  if command -v df >/dev/null 2>&1; then
    local disk_usage
    disk_usage=$(df "${BASE_DIR}" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ -n "$disk_usage" && "$disk_usage" -gt 90 ]]; then
      echo "WARNING: Disk usage high: ${disk_usage}%"
      ((issues++))
    else
      echo "✅ Disk usage: ${disk_usage:-unknown}%"
    fi
  fi

  echo ""
  echo "Basic diagnostics completed."
  echo "Issues found: $issues"
  echo ""
  echo "For comprehensive diagnostics, install the diagnostics plugin."

  if [[ "$issues" -gt 2 ]]; then
    return 2 # errors
  elif [[ "$issues" -gt 0 ]]; then
    return 1 # warnings
  else
    return 0 # success
  fi
}

# Function: diagnostics_check_system_health
# Description: Basic system health check (stub version)
# Parameters: None
# Returns: JSON result via stdout
diagnostics_check_system_health() {
  echo '{"status": "basic", "message": "Install diagnostics plugin for comprehensive health checks"}'
}

# Function: diagnostics_check_configuration
# Description: Basic configuration check (stub version)
# Parameters: None
# Returns: JSON result via stdout
diagnostics_check_configuration() {
  echo '{"status": "basic", "message": "Install diagnostics plugin for comprehensive configuration validation"}'
}

# Function: diagnostics_check_dependencies
# Description: Basic dependency check (stub version)
# Parameters: None
# Returns: JSON result via stdout
diagnostics_check_dependencies() {
  local missing=0
  local required_commands=("bash" "date" "whoami")

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      ((missing++))
    fi
  done

  echo '{"status": "basic", "missing_commands": '$missing', "message": "Install diagnostics plugin for comprehensive dependency checks"}'
}

# Function: diagnostics_check_performance
# Description: Basic performance check (stub version)
# Parameters: None
# Returns: JSON result via stdout
diagnostics_check_performance() {
  echo '{"status": "basic", "message": "Install diagnostics plugin for comprehensive performance monitoring"}'
}

# Function: diagnostics_check_plugins
# Description: Basic plugin check (stub version)
# Parameters: None
# Returns: JSON result via stdout
diagnostics_check_plugins() {
  echo '{"status": "basic", "message": "Install diagnostics plugin for comprehensive plugin diagnostics"}'
}

# Backward compatibility stubs
diagnostics_load_config() {
  echo "INFO: Advanced diagnostics configuration not available in core. Install diagnostics plugin." >&2
  return 0
}

diagnostics_create_default_config() {
  echo "INFO: Advanced configuration not available in core. Install diagnostics plugin." >&2
  return 0
}

get_diagnostic_summary() {
  echo "Basic Diagnostic Summary:"
  echo "========================"
  echo "For detailed summaries, install the diagnostics plugin."
}

cleanup_diagnostic_reports() {
  echo "INFO: Report cleanup not available in core. Install diagnostics plugin." >&2
  return 0
}

# Export functions for backward compatibility
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f diagnostics_system_init
  export -f diagnostics_run_full
  export -f diagnostics_check_system_health
  export -f diagnostics_check_configuration
  export -f diagnostics_check_dependencies
  export -f diagnostics_check_performance
  export -f diagnostics_check_plugins
  export -f diagnostics_load_config
  export -f diagnostics_create_default_config
  export -f get_diagnostic_summary
  export -f cleanup_diagnostic_reports
fi

# Auto-initialize
if [[ "${DIAGNOSTICS_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if diagnostics_system_init; then
    export DIAGNOSTICS_SYSTEM_INITIALIZED=true
  fi
fi
