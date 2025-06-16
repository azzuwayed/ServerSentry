#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check Configuration
#
# This module handles configuration parsing and default creation for composite checks

# Prevent multiple sourcing
if [[ "${COMPOSITE_CONFIG_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPOSITE_CONFIG_MODULE_LOADED=true
export COMPOSITE_CONFIG_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Search upward for bootstrap
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      export SERVERSENTRY_QUIET=true
      export SERVERSENTRY_AUTO_INIT=false
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done
fi

# Configuration directories
COMPOSITE_CONFIG_DIR="${COMPOSITE_CONFIG_DIR:-${BASE_DIR}/config/composite}"
COMPOSITE_RESULTS_DIR="${COMPOSITE_RESULTS_DIR:-${BASE_DIR}/logs/composite}"

# Function: composite_config_init
# Description: Initialize composite configuration system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   composite_config_init
# Dependencies:
#   - util_create_secure_dir
composite_config_init() {
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing composite configuration system" "composite"
  fi

  # Create directories if they don't exist
  if declare -f util_create_secure_dir >/dev/null 2>&1; then
    if ! util_create_secure_dir "$COMPOSITE_CONFIG_DIR" "755"; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Failed to create composite config directory: $COMPOSITE_CONFIG_DIR" "composite"
      fi
      return 1
    fi

    if ! util_create_secure_dir "$COMPOSITE_RESULTS_DIR" "755"; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Failed to create composite results directory: $COMPOSITE_RESULTS_DIR" "composite"
      fi
      return 1
    fi
  else
    # Fallback directory creation
    if [[ ! -d "$COMPOSITE_CONFIG_DIR" ]]; then
      mkdir -p "$COMPOSITE_CONFIG_DIR" || return 1
    fi
    if [[ ! -d "$COMPOSITE_RESULTS_DIR" ]]; then
      mkdir -p "$COMPOSITE_RESULTS_DIR" || return 1
    fi
  fi

  # Create default composite checks if they don't exist
  composite_config_create_defaults

  return 0
}

# Function: composite_config_create_defaults
# Description: Create default composite check configuration files
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   composite_config_create_defaults
# Dependencies: None
composite_config_create_defaults() {
  # High resource usage composite check
  local high_usage_check="$COMPOSITE_CONFIG_DIR/high_resource_usage.conf"
  if [[ ! -f "$high_usage_check" ]]; then
    cat >"$high_usage_check" <<'EOF'
# High Resource Usage Composite Check
# Triggers when CPU > 80% AND Memory > 85%

name="High Resource Usage Alert"
description="Alerts when both CPU and memory are critically high"
enabled=true
severity=2
cooldown=300

# Rule: CPU > 80% AND Memory > 85%
rule="cpu.value > 80 AND memory.value > 85"

# Notification settings
notify_on_trigger=true
notify_on_recovery=true
notification_message="Critical: High resource usage detected - CPU: {cpu.value}%, Memory: {memory.value}%"
EOF
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Created default high resource usage composite check" "composite"
    fi
  fi

  # System overload composite check
  local overload_check="$COMPOSITE_CONFIG_DIR/system_overload.conf"
  if [[ ! -f "$overload_check" ]]; then
    cat >"$overload_check" <<'EOF'
# System Overload Composite Check
# Triggers when (CPU > 90% OR Memory > 95%) AND Disk > 90%

name="System Overload Alert"
description="Alerts when system is critically overloaded"
enabled=true
severity=2
cooldown=600

# Rule: (CPU > 90% OR Memory > 95%) AND Disk > 90%
rule="(cpu.value > 90 OR memory.value > 95) AND disk.value > 90"

# Notification settings
notify_on_trigger=true
notify_on_recovery=true
notification_message="CRITICAL: System overload detected - CPU: {cpu.value}%, Memory: {memory.value}%, Disk: {disk.value}%"
EOF
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Created default system overload composite check" "composite"
    fi
  fi

  # Maintenance mode composite check
  local maintenance_check="$COMPOSITE_CONFIG_DIR/maintenance_mode.conf"
  if [[ ! -f "$maintenance_check" ]]; then
    cat >"$maintenance_check" <<'EOF'
# Maintenance Mode Composite Check
# Only alerts on critical issues during maintenance

name="Maintenance Mode Alert"
description="Reduced sensitivity alerts for maintenance periods"
enabled=false
severity=2
cooldown=900

# Rule: CPU > 95% OR Memory > 98% OR Disk > 95%
rule="cpu.value > 95 OR memory.value > 98 OR disk.value > 95"

# Notification settings
notify_on_trigger=true
notify_on_recovery=false
notification_message="MAINTENANCE ALERT: Critical threshold exceeded - {triggered_conditions}"
EOF
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Created default maintenance mode composite check" "composite"
    fi
  fi

  return 0
}

# Function: composite_config_parse
# Description: Parse composite check configuration file
# Parameters:
#   $1 (string): configuration file path
# Returns:
#   0 - success (sets global variables)
#   1 - failure
# Example:
#   composite_config_parse "/path/to/config.conf"
# Dependencies:
#   - util_error_validate_input
composite_config_parse() {
  if ! util_error_validate_input "composite_config_parse" "1" "$#"; then
    return 1
  fi

  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Composite config file not found: $config_file" "composite"
    fi
    return 1
  fi

  # Clear previous values
  unset name description enabled severity cooldown rule
  unset notify_on_trigger notify_on_recovery notification_message

  # Source the configuration file safely
  if ! source "$config_file"; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Failed to source composite config file: $config_file" "composite"
    fi
    return 1
  fi

  # Validate required fields
  if [[ -z "$name" ]] || [[ -z "$rule" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Composite check missing required fields (name, rule): $config_file" "composite"
    fi
    return 1
  fi

  # Set defaults for optional fields
  enabled="${enabled:-true}"
  severity="${severity:-1}"
  cooldown="${cooldown:-300}"
  notify_on_trigger="${notify_on_trigger:-true}"
  notify_on_recovery="${notify_on_recovery:-false}"

  return 0
}

# Function: composite_config_list
# Description: List all composite check configurations
# Parameters: None
# Returns:
#   Configuration list via stdout
# Example:
#   composite_config_list
# Dependencies: None
composite_config_list() {
  echo "Composite Checks:"
  echo "=================="

  for config_file in "$COMPOSITE_CONFIG_DIR"/*.conf; do
    if [[ -f "$config_file" ]]; then
      if composite_config_parse "$config_file"; then
        local status
        if [[ "$enabled" == "true" ]]; then
          status="✅ Enabled"
        else
          status="❌ Disabled"
        fi

        echo "Name: $name"
        echo "Status: $status"
        echo "Rule: $rule"
        echo "Severity: $severity"
        echo "Cooldown: ${cooldown}s"
        echo "Config: $(basename "$config_file")"
        echo "---"
      fi
    fi
  done
}

# Function: composite_config_validate
# Description: Validate a composite check configuration
# Parameters:
#   $1 (string): configuration file path
# Returns:
#   0 - valid configuration
#   1 - invalid configuration
# Example:
#   composite_config_validate "/path/to/config.conf"
# Dependencies:
#   - composite_config_parse
composite_config_validate() {
  if ! util_error_validate_input "composite_config_validate" "1" "$#"; then
    return 1
  fi

  local config_file="$1"

  # Parse configuration
  if ! composite_config_parse "$config_file"; then
    return 1
  fi

  # Additional validation
  if ! [[ "$severity" =~ ^[0-9]+$ ]] || [[ "$severity" -lt 0 ]] || [[ "$severity" -gt 3 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Invalid severity level: $severity (must be 0-3)" "composite"
    fi
    return 1
  fi

  if ! [[ "$cooldown" =~ ^[0-9]+$ ]] || [[ "$cooldown" -lt 0 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Invalid cooldown value: $cooldown (must be >= 0)" "composite"
    fi
    return 1
  fi

  # Validate rule syntax (basic check)
  if [[ -z "$rule" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Empty rule in configuration: $config_file" "composite"
    fi
    return 1
  fi

  return 0
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f composite_config_init
  export -f composite_config_create_defaults
  export -f composite_config_parse
  export -f composite_config_list
  export -f composite_config_validate
fi
