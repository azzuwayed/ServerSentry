#!/usr/bin/env bash
#
# ServerSentry v2 - Logging Configuration Module
#
# This module provides logging configuration management and component-specific settings

# Function: logging_config_init
# Description: Initialize logging configuration with comprehensive settings management
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_config_init
# Dependencies:
#   - util_error_validate_input
#   - BASE_DIR variable
logging_config_init() {
  # Load ServerSentry environment first (before any logging calls)
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

  # Initialize default paths
  LOG_DIR="${LOG_DIR:-${BASE_DIR}/logs}"
  LOG_FILE="${LOG_FILE:-${LOG_DIR}/serversentry.log}"
  export LOG_DIR LOG_FILE

  # Initialize log level constants (only if not already defined)
  if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARNING=2
    readonly LOG_LEVEL_ERROR=3
    readonly LOG_LEVEL_CRITICAL=4
  fi

  # Set default log level (preserve early setting if available)
  CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}
  export CURRENT_LOG_LEVEL

  # Initialize specialized log files
  PERFORMANCE_LOG="${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}"
  ERROR_LOG="${ERROR_LOG:-${LOG_DIR}/error.log}"
  AUDIT_LOG="${AUDIT_LOG:-${LOG_DIR}/audit.log}"
  SECURITY_LOG="${SECURITY_LOG:-${LOG_DIR}/security.log}"
  export PERFORMANCE_LOG ERROR_LOG AUDIT_LOG SECURITY_LOG

  # Initialize component log levels
  if ! _logging_init_component_levels; then
    log_warning "Failed to initialize component-specific log levels" "logging"
  fi

  # Initialize log format settings
  if ! _logging_init_format_settings; then
    log_warning "Failed to initialize log format settings" "logging"
  fi

  # Load configuration from config files if available
  if declare -f config_get_value >/dev/null 2>&1; then
    if ! logging_load_config; then
      echo "Warning: Failed to load logging configuration from config files" >&2
    fi
  fi

  # Now that everything is initialized, we can use logging functions
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Logging configuration system initialized successfully" "logging"
  fi
  return 0
}

# Function: logging_load_config
# Description: Load logging configuration from config files with enhanced validation
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_load_config
# Dependencies:
#   - config_get_value function
#   - logging_set_level function
logging_load_config() {
  if ! declare -f config_get_value >/dev/null 2>&1; then
    log_warning "Configuration system not available for loading logging config" "logging"
    return 1
  fi

  log_debug "Loading logging configuration from config files" "logging"

  # Load global log settings
  local config_level
  config_level=$(config_get_value "logging.global.default_level" "info")
  if [[ -n "$config_level" ]]; then
    if logging_set_level "$config_level"; then
      log_debug "Set global log level to: $config_level" "logging"
    else
      log_warning "Invalid log level in config: $config_level" "logging"
    fi
  fi

  # Load format settings
  LOG_FORMAT=$(config_get_value "logging.global.output_format" "standard")
  LOG_TIMESTAMP_FORMAT=$(config_get_value "logging.global.timestamp_format" "%Y-%m-%d %H:%M:%S")
  LOG_INCLUDE_CALLER=$(config_get_value "logging.global.include_caller" "false")
  export LOG_FORMAT LOG_TIMESTAMP_FORMAT LOG_INCLUDE_CALLER

  log_debug "Loaded format settings: format=$LOG_FORMAT, timestamp=$LOG_TIMESTAMP_FORMAT, caller=$LOG_INCLUDE_CALLER" "logging"

  # Load component-specific log levels
  if ! _logging_load_component_config; then
    log_warning "Failed to load component-specific logging configuration" "logging"
  fi

  # Load specialized log file paths and settings
  if ! _logging_load_specialized_config; then
    log_warning "Failed to load specialized logging configuration" "logging"
  fi

  # Load management settings
  if ! _logging_load_management_config; then
    log_warning "Failed to load logging management configuration" "logging"
  fi

  log_info "Logging configuration loaded successfully" "logging"
  return 0
}

# Function: logging_set_component_level
# Description: Set log level for a specific component with validation
# Parameters:
#   $1 (string): component name
#   $2 (string): log level (debug, info, warning, error, critical)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_set_component_level "plugins" "debug"
# Dependencies:
#   - util_error_validate_input
#   - COMPONENT_LOG_LEVELS array
logging_set_component_level() {
  local component="$1"
  local level="$2"

  if ! util_error_validate_input "$component" "component" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$level" "level" "required"; then
    return 1
  fi

  # Check if component logging is supported
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" != "true" ]]; then
    log_warning "Component-specific logging not supported (bash < 4.0)" "logging"
    return 1
  fi

  # Validate and convert level
  local level_value
  case "$level" in
  debug) level_value=$LOG_LEVEL_DEBUG ;;
  info) level_value=$LOG_LEVEL_INFO ;;
  warning) level_value=$LOG_LEVEL_WARNING ;;
  error) level_value=$LOG_LEVEL_ERROR ;;
  critical) level_value=$LOG_LEVEL_CRITICAL ;;
  *)
    log_error "Invalid log level '$level' for component '$component'" "logging"
    return 1
    ;;
  esac

  # Set component log level
  COMPONENT_LOG_LEVELS["$component"]=$level_value
  log_debug "Set component '$component' log level to: $level" "logging"
  return 0
}

# Function: logging_get_component_level
# Description: Get log level for a specific component
# Parameters:
#   $1 (string): component name
# Returns:
#   Component log level name via stdout
# Example:
#   level=$(logging_get_component_level "plugins")
# Dependencies:
#   - util_error_validate_input
#   - COMPONENT_LOG_LEVELS array
logging_get_component_level() {
  local component="$1"

  if ! util_error_validate_input "$component" "component" "required"; then
    echo "unknown"
    return 1
  fi

  # Check if component logging is supported
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" != "true" ]]; then
    logging_get_level
    return 0
  fi

  # Get component-specific level or fall back to global
  local level_value="${COMPONENT_LOG_LEVELS[$component]:-${CURRENT_LOG_LEVEL}}"

  case "$level_value" in
  $LOG_LEVEL_DEBUG) echo "debug" ;;
  $LOG_LEVEL_INFO) echo "info" ;;
  $LOG_LEVEL_WARNING) echo "warning" ;;
  $LOG_LEVEL_ERROR) echo "error" ;;
  $LOG_LEVEL_CRITICAL) echo "critical" ;;
  *) echo "unknown" ;;
  esac
}

# Function: logging_validate_config
# Description: Validate logging configuration settings with comprehensive checks
# Parameters: None
# Returns:
#   0 - configuration valid
#   1 - configuration has issues
# Example:
#   if logging_validate_config; then echo "Config valid"; fi
# Dependencies:
#   - util_error_validate_input
#   - LOG_DIR, LOG_FILE variables
logging_validate_config() {
  local issues=0
  local warnings=0

  log_debug "Validating logging configuration" "logging"

  # Validate log directory
  if ! util_error_validate_input "$LOG_DIR" "LOG_DIR" "directory"; then
    if [[ ! -d "$LOG_DIR" ]]; then
      log_error "Log directory does not exist: $LOG_DIR" "logging"
      ((issues++))
    fi
  fi

  # Validate log file path
  if ! util_error_validate_input "$LOG_FILE" "LOG_FILE" "required"; then
    log_error "Log file path is not set" "logging"
    ((issues++))
  else
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
      log_warning "Log file directory does not exist: $log_dir" "logging"
      ((warnings++))
    fi
  fi

  # Validate log level
  case "${CURRENT_LOG_LEVEL:-1}" in
  $LOG_LEVEL_DEBUG | $LOG_LEVEL_INFO | $LOG_LEVEL_WARNING | $LOG_LEVEL_ERROR | $LOG_LEVEL_CRITICAL) ;;
  *)
    log_error "Invalid current log level: ${CURRENT_LOG_LEVEL:-1}" "logging"
    ((issues++))
    ;;
  esac

  # Validate log format
  case "${LOG_FORMAT:-standard}" in
  standard | json | structured) ;;
  *)
    log_warning "Unknown log format: ${LOG_FORMAT:-standard}" "logging"
    ((warnings++))
    ;;
  esac

  # Validate specialized log files
  local specialized_logs=(
    "${PERFORMANCE_LOG:-}"
    "${ERROR_LOG:-}"
    "${AUDIT_LOG:-}"
    "${SECURITY_LOG:-}"
  )

  for log_file in "${specialized_logs[@]}"; do
    if [[ -n "$log_file" ]]; then
      local log_dir
      log_dir=$(dirname "$log_file")
      if [[ ! -d "$log_dir" ]]; then
        log_warning "Specialized log directory does not exist: $log_dir" "logging"
        ((warnings++))
      fi
    fi
  done

  # Validate component log levels if supported
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" == "true" ]]; then
    for component in "${!COMPONENT_LOG_LEVELS[@]}"; do
      local level="${COMPONENT_LOG_LEVELS[$component]}"
      case "$level" in
      $LOG_LEVEL_DEBUG | $LOG_LEVEL_INFO | $LOG_LEVEL_WARNING | $LOG_LEVEL_ERROR | $LOG_LEVEL_CRITICAL) ;;
      *)
        log_warning "Invalid log level for component '$component': $level" "logging"
        ((warnings++))
        ;;
      esac
    done
  fi

  # Validate management configuration
  if [[ -n "${config_max_log_size:-}" ]]; then
    if ! util_error_validate_input "${config_max_log_size}" "config_max_log_size" "numeric"; then
      log_warning "Invalid max log size configuration: ${config_max_log_size}" "logging"
      ((warnings++))
    fi
  fi

  if [[ -n "${config_max_log_archives:-}" ]]; then
    if ! util_error_validate_input "${config_max_log_archives}" "config_max_log_archives" "numeric"; then
      log_warning "Invalid max log archives configuration: ${config_max_log_archives}" "logging"
      ((warnings++))
    fi
  fi

  # Report validation results
  if [[ "$issues" -gt 0 ]]; then
    log_error "Logging configuration validation found $issues critical issues and $warnings warnings" "logging"
    return 1
  elif [[ "$warnings" -gt 0 ]]; then
    log_warning "Logging configuration validation found $warnings warnings" "logging"
    return 0
  else
    log_debug "Logging configuration validation passed" "logging"
    return 0
  fi
}

# Function: logging_get_config_summary
# Description: Get comprehensive logging configuration summary
# Parameters: None
# Returns:
#   Configuration summary via stdout
# Example:
#   summary=$(logging_get_config_summary)
# Dependencies:
#   - logging_get_level
#   - logging_get_component_level
logging_get_config_summary() {
  echo "=== ServerSentry Logging Configuration Summary ==="
  echo ""

  echo "Global Settings:"
  echo "  Log Level: $(logging_get_level)"
  echo "  Log Format: ${LOG_FORMAT:-standard}"
  echo "  Timestamp Format: ${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
  echo "  Include Caller: ${LOG_INCLUDE_CALLER:-false}"
  echo ""

  echo "File Paths:"
  echo "  Main Log: ${LOG_FILE}"
  echo "  Log Directory: ${LOG_DIR}"
  echo "  Performance Log: ${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}"
  echo "  Error Log: ${ERROR_LOG:-${LOG_DIR}/error.log}"
  echo "  Audit Log: ${AUDIT_LOG:-${LOG_DIR}/audit.log}"
  echo "  Security Log: ${SECURITY_LOG:-${LOG_DIR}/security.log}"
  echo ""

  echo "Component Log Levels:"
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" == "true" ]]; then
    local components=("core" "plugins" "notifications" "config" "utils" "ui" "performance" "security")
    for component in "${components[@]}"; do
      local level
      level=$(logging_get_component_level "$component")
      printf "  %-12s: %s\n" "$component" "$level"
    done
  else
    echo "  Component-specific logging not supported (bash < 4.0)"
    echo "  All components use global level: $(logging_get_level)"
  fi
  echo ""

  echo "Management Settings:"
  echo "  Max Log Size: $(logging_format_bytes "${config_max_log_size:-10485760}")"
  echo "  Max Archives: ${config_max_log_archives:-10}"
  echo ""

  echo "System Information:"
  echo "  Bash Version: ${BASH_VERSION}"
  echo "  Component Logging Supported: ${COMPONENT_LOGGING_SUPPORTED:-false}"
  echo "  Configuration System Available: $(declare -f config_get_value >/dev/null 2>&1 && echo "true" || echo "false")"
}

# Internal function: Initialize component log levels
_logging_init_component_levels() {
  # Check bash version for associative array support
  if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative array support
    declare -gA COMPONENT_LOG_LEVELS=(
      ["core"]=$LOG_LEVEL_INFO
      ["plugins"]=$LOG_LEVEL_INFO
      ["notifications"]=$LOG_LEVEL_INFO
      ["config"]=$LOG_LEVEL_WARNING
      ["utils"]=$LOG_LEVEL_WARNING
      ["ui"]=$LOG_LEVEL_INFO
      ["performance"]=$LOG_LEVEL_DEBUG
      ["security"]=$LOG_LEVEL_WARNING
      ["system"]=$LOG_LEVEL_INFO
      ["network"]=$LOG_LEVEL_INFO
      ["logging"]=$LOG_LEVEL_WARNING
    )
    COMPONENT_LOGGING_SUPPORTED=true
    export COMPONENT_LOGGING_SUPPORTED
    log_debug "Initialized component-specific log levels (modern bash)" "logging"
  else
    # Fallback for older bash versions
    COMPONENT_LOGGING_SUPPORTED=false
    export COMPONENT_LOGGING_SUPPORTED
    log_debug "Component-specific logging not supported (bash < 4.0)" "logging"
  fi
  return 0
}

# Internal function: Initialize log format settings
_logging_init_format_settings() {
  # Set default format settings
  LOG_FORMAT="${LOG_FORMAT:-standard}"
  LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
  LOG_INCLUDE_CALLER="${LOG_INCLUDE_CALLER:-false}"
  export LOG_FORMAT LOG_TIMESTAMP_FORMAT LOG_INCLUDE_CALLER

  log_debug "Initialized log format settings: format=$LOG_FORMAT, timestamp=$LOG_TIMESTAMP_FORMAT, caller=$LOG_INCLUDE_CALLER" "logging"
  return 0
}

# Internal function: Load component-specific configuration
_logging_load_component_config() {
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" != "true" ]]; then
    return 0
  fi

  local components=("core" "plugins" "notifications" "config" "utils" "ui" "performance" "security" "system" "network" "logging")
  local loaded_count=0

  for component in "${components[@]}"; do
    local level
    level=$(config_get_value "logging.components.$component" "")
    if [[ -n "$level" ]]; then
      case "$level" in
      debug) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_DEBUG ;;
      info) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_INFO ;;
      warning) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_WARNING ;;
      error) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_ERROR ;;
      critical) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_CRITICAL ;;
      *)
        log_warning "Invalid log level for component '$component': $level" "logging"
        continue
        ;;
      esac
      ((loaded_count++))
      log_debug "Loaded component log level: $component=$level" "logging"
    fi
  done

  log_debug "Loaded $loaded_count component-specific log levels" "logging"
  return 0
}

# Internal function: Load specialized log configuration
_logging_load_specialized_config() {
  # Update specialized log file paths from config
  local performance_log
  performance_log=$(config_get_value "logging.specialized.performance.file" "")
  if [[ -n "$performance_log" ]]; then
    [[ "$performance_log" != /* ]] && performance_log="${BASE_DIR}/$performance_log"
    PERFORMANCE_LOG="$performance_log"
    export PERFORMANCE_LOG
  fi

  local error_log
  error_log=$(config_get_value "logging.specialized.error.file" "")
  if [[ -n "$error_log" ]]; then
    [[ "$error_log" != /* ]] && error_log="${BASE_DIR}/$error_log"
    ERROR_LOG="$error_log"
    export ERROR_LOG
  fi

  local audit_log
  audit_log=$(config_get_value "logging.specialized.audit.file" "")
  if [[ -n "$audit_log" ]]; then
    [[ "$audit_log" != /* ]] && audit_log="${BASE_DIR}/$audit_log"
    AUDIT_LOG="$audit_log"
    export AUDIT_LOG
  fi

  local security_log
  security_log=$(config_get_value "logging.specialized.security.file" "")
  if [[ -n "$security_log" ]]; then
    [[ "$security_log" != /* ]] && security_log="${BASE_DIR}/$security_log"
    SECURITY_LOG="$security_log"
    export SECURITY_LOG
  fi

  log_debug "Loaded specialized log file paths from configuration" "logging"
  return 0
}

# Internal function: Load management configuration
_logging_load_management_config() {
  # Load log rotation settings
  local max_size
  max_size=$(config_get_value "logging.file.max_size" "")
  if [[ -n "$max_size" && "$max_size" =~ ^[0-9]+$ ]]; then
    config_max_log_size="$max_size"
    export config_max_log_size
    log_debug "Loaded max log size: $max_size bytes" "logging"
  fi

  local max_archives
  max_archives=$(config_get_value "logging.file.max_archives" "")
  if [[ -n "$max_archives" && "$max_archives" =~ ^[0-9]+$ ]]; then
    config_max_log_archives="$max_archives"
    export config_max_log_archives
    log_debug "Loaded max log archives: $max_archives" "logging"
  fi

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_config_init
  export -f logging_load_config
  export -f logging_set_component_level
  export -f logging_get_component_level
  export -f logging_validate_config
  export -f logging_get_config_summary
fi
