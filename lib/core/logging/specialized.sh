#!/usr/bin/env bash
#
# ServerSentry v2 - Specialized Logging Module
#
# This module provides specialized logging functions for different system components

# Function: logging_specialized_init
# Description: Initialize specialized logging files and configuration
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_specialized_init
# Dependencies:
#   - util_error_validate_input
#   - _logging_init_log_file
logging_specialized_init() {
  local success=true

  # Initialize specialized log files if enabled
  if declare -f config_get_value >/dev/null 2>&1; then
    # Performance log
    if [[ "$(config_get_value "logging.specialized.performance.enabled" "true")" == "true" ]]; then
      if ! _logging_init_log_file "${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}"; then
        echo "Warning: Failed to initialize performance log" >&2
        success=false
      fi
    fi

    # Error log
    if [[ "$(config_get_value "logging.specialized.error.enabled" "true")" == "true" ]]; then
      if ! _logging_init_log_file "${ERROR_LOG:-${LOG_DIR}/error.log}"; then
        echo "Warning: Failed to initialize error log" >&2
        success=false
      fi
    fi

    # Audit log
    if [[ "$(config_get_value "logging.specialized.audit.enabled" "true")" == "true" ]]; then
      if ! _logging_init_log_file "${AUDIT_LOG:-${LOG_DIR}/audit.log}"; then
        echo "Warning: Failed to initialize audit log" >&2
        success=false
      fi
    fi

    # Security log
    if [[ "$(config_get_value "logging.specialized.security.enabled" "true")" == "true" ]]; then
      if ! _logging_init_log_file "${SECURITY_LOG:-${LOG_DIR}/security.log}"; then
        echo "Warning: Failed to initialize security log" >&2
        success=false
      fi
    fi
  else
    # Fallback: create all specialized logs with default paths
    local default_logs=(
      "${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}"
      "${ERROR_LOG:-${LOG_DIR}/error.log}"
      "${AUDIT_LOG:-${LOG_DIR}/audit.log}"
      "${SECURITY_LOG:-${LOG_DIR}/security.log}"
    )

    for log_file in "${default_logs[@]}"; do
      if ! _logging_init_log_file "$log_file"; then
        echo "Warning: Failed to initialize specialized log: $log_file" >&2
        success=false
      fi
    done
  fi

  if [[ "$success" == "true" ]]; then
    return 0
  else
    return 1
  fi
}

# Function: log_performance
# Description: Log performance metrics with enhanced formatting and validation
# Parameters:
#   $1 (string): message
#   $2 (string): metrics (optional, JSON or key=value format)
#   $3 (string): operation (optional, operation name)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_performance "Database query completed" "duration=150ms,rows=42" "user_lookup"
# Dependencies:
#   - util_error_validate_input
#   - logging_core_log
#   - PERFORMANCE_LOG variable
log_performance() {
  local message="$1"
  local metrics="${2:-}"
  local operation="${3:-}"

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced performance message
  local full_message="$message"

  if [[ -n "$operation" ]]; then
    full_message="[$operation] $message"
  fi

  if [[ -n "$metrics" ]]; then
    full_message="$full_message | Metrics: $metrics"
  fi

  # Add timestamp for performance tracking
  local timestamp
  timestamp=$(date +%s.%3N 2>/dev/null || date +%s)
  full_message="$full_message | Timestamp: $timestamp"

  # Log to performance log
  if [[ -n "${PERFORMANCE_LOG:-}" ]]; then
    logging_core_log "${LOG_LEVEL_DEBUG:-0}" "PERF" "$full_message" "performance" "$PERFORMANCE_LOG"
  else
    logging_core_log "${LOG_LEVEL_DEBUG:-0}" "PERF" "$full_message" "performance"
  fi

  return 0
}

# Function: log_audit
# Description: Log audit events with enhanced security and compliance tracking
# Parameters:
#   $1 (string): action performed
#   $2 (string): user (optional, defaults to system)
#   $3 (string): details (optional, additional context)
#   $4 (string): resource (optional, affected resource)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_audit "config_changed" "admin" "log_level=debug" "/etc/serversentry.conf"
# Dependencies:
#   - util_error_validate_input
#   - logging_core_log
#   - AUDIT_LOG variable
log_audit() {
  local action="$1"
  local user="${2:-system}"
  local details="${3:-}"
  local resource="${4:-}"

  if ! util_error_validate_input "$action" "action" "required"; then
    return 1
  fi

  # Build comprehensive audit message
  local message="Action: $action | User: $user"

  if [[ -n "$resource" ]]; then
    message="$message | Resource: $resource"
  fi

  if [[ -n "$details" ]]; then
    message="$message | Details: $details"
  fi

  # Add session and process information for audit trail
  local session_id="${SESSION_ID:-$$}"
  local remote_addr="${SSH_CLIENT%% *}"
  [[ -n "$remote_addr" ]] && message="$message | RemoteAddr: $remote_addr"
  message="$message | SessionID: $session_id | PID: $$"

  # Log to audit log
  if [[ -n "${AUDIT_LOG:-}" ]]; then
    logging_core_log "${LOG_LEVEL_INFO:-1}" "AUDIT" "$message" "audit" "$AUDIT_LOG"
  else
    logging_core_log "${LOG_LEVEL_INFO:-1}" "AUDIT" "$message" "audit"
  fi

  return 0
}

# Function: log_security
# Description: Log security events with enhanced threat detection and response
# Parameters:
#   $1 (string): security event type
#   $2 (string): severity (low, medium, high, critical)
#   $3 (string): details (optional, event details)
#   $4 (string): source (optional, event source)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_security "failed_login" "medium" "invalid_password" "192.168.1.100"
# Dependencies:
#   - util_error_validate_input
#   - logging_core_log
#   - SECURITY_LOG variable
log_security() {
  local event="$1"
  local severity="${2:-medium}"
  local details="${3:-}"
  local source="${4:-}"

  if ! util_error_validate_input "$event" "event" "required"; then
    return 1
  fi

  # Validate severity level
  case "$severity" in
  low | medium | high | critical) ;;
  *)
    echo "Warning: Invalid security severity '$severity', using 'medium'" >&2
    severity="medium"
    ;;
  esac

  # Build comprehensive security message
  local message="Security Event: $event | Severity: $severity"

  if [[ -n "$source" ]]; then
    message="$message | Source: $source"
  fi

  if [[ -n "$details" ]]; then
    message="$message | Details: $details"
  fi

  # Add security context information
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  message="$message | UTC: $timestamp"

  # Add process and user context for security analysis
  local current_user
  current_user=$(whoami 2>/dev/null || echo "unknown")
  message="$message | User: $current_user | PID: $$"

  # Map severity to log level
  local log_level="${LOG_LEVEL_WARNING:-2}"
  case "$severity" in
  low) log_level="${LOG_LEVEL_INFO:-1}" ;;
  medium) log_level="${LOG_LEVEL_WARNING:-2}" ;;
  high) log_level="${LOG_LEVEL_ERROR:-3}" ;;
  critical) log_level="${LOG_LEVEL_CRITICAL:-4}" ;;
  esac

  # Log to security log
  if [[ -n "${SECURITY_LOG:-}" ]]; then
    logging_core_log "$log_level" "SECURITY" "$message" "security" "$SECURITY_LOG"
  else
    logging_core_log "$log_level" "SECURITY" "$message" "security"
  fi

  return 0
}

# Function: log_plugin
# Description: Log plugin-related events with enhanced plugin context
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): plugin name (optional, defaults to "unknown")
#   $4 (string): plugin version (optional)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_plugin "info" "Plugin loaded successfully" "cpu_monitor" "1.2.3"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_plugin() {
  local level="$1"
  local message="$2"
  local plugin_name="${3:-unknown}"
  local plugin_version="${4:-}"

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced plugin message
  local full_message="[$plugin_name"
  if [[ -n "$plugin_version" ]]; then
    full_message="$full_message v$plugin_version"
  fi
  full_message="$full_message] $message"

  # Route to appropriate log function with plugins component
  case "$level" in
  debug)
    log_debug "$full_message" "plugins"
    ;;
  info)
    log_info "$full_message" "plugins"
    ;;
  warning)
    log_warning "$full_message" "plugins"
    ;;
  error)
    log_error "$full_message" "plugins"
    ;;
  critical)
    log_critical "$full_message" "plugins"
    ;;
  *)
    echo "Error: Invalid log level '$level' for plugin logging" >&2
    return 1
    ;;
  esac

  return 0
}

# Function: log_config
# Description: Log configuration-related events with enhanced config context
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): config section (optional)
#   $4 (string): config file (optional)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_config "warning" "Invalid value detected" "logging.level" "/etc/serversentry.conf"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_config() {
  local level="$1"
  local message="$2"
  local config_section="${3:-}"
  local config_file="${4:-}"

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced config message
  local full_message="$message"

  if [[ -n "$config_section" ]]; then
    full_message="[$config_section] $message"
  fi

  if [[ -n "$config_file" ]]; then
    local config_basename
    config_basename=$(basename "$config_file")
    full_message="$full_message (file: $config_basename)"
  fi

  # Route to appropriate log function with config component
  case "$level" in
  debug)
    log_debug "$full_message" "config"
    ;;
  info)
    log_info "$full_message" "config"
    ;;
  warning)
    log_warning "$full_message" "config"
    ;;
  error)
    log_error "$full_message" "config"
    ;;
  critical)
    log_critical "$full_message" "config"
    ;;
  *)
    echo "Error: Invalid log level '$level' for config logging" >&2
    return 1
    ;;
  esac

  return 0
}

# Function: log_notification
# Description: Log notification events with enhanced provider and delivery context
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): provider (optional, notification provider)
#   $4 (string): recipient (optional, notification recipient)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_notification "info" "Alert sent successfully" "webhook" "admin@example.com"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_notification() {
  local level="$1"
  local message="$2"
  local provider="${3:-}"
  local recipient="${4:-}"

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced notification message
  local full_message="$message"

  if [[ -n "$provider" ]]; then
    full_message="[$provider] $message"
  fi

  if [[ -n "$recipient" ]]; then
    # Mask sensitive recipient information for privacy
    local masked_recipient
    if [[ "$recipient" =~ ^[^@]+@[^@]+$ ]]; then
      # Email address - mask middle part
      masked_recipient="${recipient:0:2}***@${recipient##*@}"
    elif [[ "$recipient" =~ ^[+]?[0-9]{10,}$ ]]; then
      # Phone number - mask middle digits
      masked_recipient="${recipient:0:3}***${recipient: -3}"
    else
      # Other recipient types - mask middle part
      local len=${#recipient}
      if [[ $len -gt 6 ]]; then
        masked_recipient="${recipient:0:2}***${recipient: -2}"
      else
        masked_recipient="***"
      fi
    fi
    full_message="$full_message (to: $masked_recipient)"
  fi

  # Route to appropriate log function with notifications component
  case "$level" in
  debug)
    log_debug "$full_message" "notifications"
    ;;
  info)
    log_info "$full_message" "notifications"
    ;;
  warning)
    log_warning "$full_message" "notifications"
    ;;
  error)
    log_error "$full_message" "notifications"
    ;;
  critical)
    log_critical "$full_message" "notifications"
    ;;
  *)
    echo "Error: Invalid log level '$level' for notification logging" >&2
    return 1
    ;;
  esac

  return 0
}

# Function: log_system
# Description: Log system-level events with enhanced system context
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): subsystem (optional, system subsystem)
#   $4 (string): metrics (optional, system metrics)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_system "warning" "High CPU usage detected" "monitoring" "cpu=85%,load=2.5"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_system() {
  local level="$1"
  local message="$2"
  local subsystem="${3:-}"
  local metrics="${4:-}"

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced system message
  local full_message="$message"

  if [[ -n "$subsystem" ]]; then
    full_message="[$subsystem] $message"
  fi

  if [[ -n "$metrics" ]]; then
    full_message="$full_message | Metrics: $metrics"
  fi

  # Add system context
  local hostname
  hostname=$(hostname 2>/dev/null || echo "unknown")
  full_message="$full_message | Host: $hostname"

  # Route to appropriate log function with system component
  case "$level" in
  debug)
    log_debug "$full_message" "system"
    ;;
  info)
    log_info "$full_message" "system"
    ;;
  warning)
    log_warning "$full_message" "system"
    ;;
  error)
    log_error "$full_message" "system"
    ;;
  critical)
    log_critical "$full_message" "system"
    ;;
  *)
    echo "Error: Invalid log level '$level' for system logging" >&2
    return 1
    ;;
  esac

  return 0
}

# Function: log_network
# Description: Log network-related events with enhanced network context
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): endpoint (optional, network endpoint)
#   $4 (string): protocol (optional, network protocol)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_network "error" "Connection timeout" "api.example.com:443" "HTTPS"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_network() {
  local level="$1"
  local message="$2"
  local endpoint="${3:-}"
  local protocol="${4:-}"

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$message" "message" "required"; then
    return 1
  fi

  # Build enhanced network message
  local full_message="$message"

  if [[ -n "$endpoint" ]]; then
    full_message="$full_message | Endpoint: $endpoint"
  fi

  if [[ -n "$protocol" ]]; then
    full_message="$full_message | Protocol: $protocol"
  fi

  # Route to appropriate log function with network component
  case "$level" in
  debug)
    log_debug "$full_message" "network"
    ;;
  info)
    log_info "$full_message" "network"
    ;;
  warning)
    log_warning "$full_message" "network"
    ;;
  error)
    log_error "$full_message" "network"
    ;;
  critical)
    log_critical "$full_message" "network"
    ;;
  *)
    echo "Error: Invalid log level '$level' for network logging" >&2
    return 1
    ;;
  esac

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_specialized_init
  export -f log_performance
  export -f log_audit
  export -f log_security
  export -f log_plugin
  export -f log_config
  export -f log_notification
  export -f log_system
  export -f log_network
fi
