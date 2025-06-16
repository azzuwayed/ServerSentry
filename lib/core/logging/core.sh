#!/usr/bin/env bash
#
# ServerSentry v2 - Core Logging Module
#
# This module provides the fundamental logging functions and core log processing

# Function: logging_core_init
# Description: Initialize core logging functionality with enhanced configuration
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_core_init
# Dependencies:
#   - util_error_validate_input
#   - LOG_DIR, LOG_FILE variables
logging_core_init() {
  # Initialize log level constants first (before any validation)
  if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARNING=2
    readonly LOG_LEVEL_ERROR=3
    readonly LOG_LEVEL_CRITICAL=4
    export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_CRITICAL
  fi

  # Set default log level if not already set
  if [[ -z "${CURRENT_LOG_LEVEL:-}" ]]; then
    CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO:-1}
    export CURRENT_LOG_LEVEL
  fi

  # Ensure LOG_DIR is set
  LOG_DIR="${LOG_DIR:-${SERVERSENTRY_LOGS_DIR:-${BASE_DIR}/logs}}"
  LOG_FILE="${LOG_FILE:-${LOG_DIR}/serversentry.log}"
  export LOG_DIR LOG_FILE

  # Validate that required directories exist (use basic validation if util functions not available)
  if [[ ! -d "$LOG_DIR" ]]; then
    if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
      echo "Error: Failed to create log directory: $LOG_DIR" >&2
      return 1
    fi
    chmod 755 "$LOG_DIR" 2>/dev/null
  fi

  # Create archive directory
  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    if ! mkdir -p "$archive_dir" 2>/dev/null; then
      echo "Warning: Failed to create archive directory: $archive_dir" >&2
    else
      chmod 755 "$archive_dir" 2>/dev/null
    fi
  fi

  # Initialize main log file
  if ! _logging_init_log_file "$LOG_FILE"; then
    echo "Error: Failed to initialize main log file: $LOG_FILE" >&2
    return 1
  fi

  return 0
}

# Function: logging_set_level
# Description: Set the current log level with validation and error handling
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
# Returns:
#   0 - success
#   1 - invalid log level
# Example:
#   logging_set_level "debug"
# Dependencies:
#   - util_error_validate_input
#   - LOG_LEVEL_* constants
logging_set_level() {
  local level="$1"

  if [[ -z "$level" ]]; then
    echo "Error: Log level is required" >&2
    return 1
  fi

  case "$level" in
  debug)
    CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG:-0}
    export CURRENT_LOG_LEVEL
    ;;
  info)
    CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO:-1}
    export CURRENT_LOG_LEVEL
    ;;
  warning)
    CURRENT_LOG_LEVEL=${LOG_LEVEL_WARNING:-2}
    export CURRENT_LOG_LEVEL
    ;;
  error)
    CURRENT_LOG_LEVEL=${LOG_LEVEL_ERROR:-3}
    export CURRENT_LOG_LEVEL
    ;;
  critical)
    CURRENT_LOG_LEVEL=${LOG_LEVEL_CRITICAL:-4}
    export CURRENT_LOG_LEVEL
    ;;
  *)
    echo "Error: Invalid log level '$level'. Valid levels: debug, info, warning, error, critical" >&2
    return 1
    ;;
  esac

  return 0
}

# Function: logging_get_level
# Description: Get the current log level name with validation
# Parameters: None
# Returns:
#   Current log level name via stdout
# Example:
#   current_level=$(logging_get_level)
# Dependencies:
#   - CURRENT_LOG_LEVEL variable
#   - LOG_LEVEL_* constants
logging_get_level() {
  case "${CURRENT_LOG_LEVEL:-1}" in
  "${LOG_LEVEL_DEBUG:-0}")
    echo "debug"
    ;;
  "${LOG_LEVEL_INFO:-1}")
    echo "info"
    ;;
  "${LOG_LEVEL_WARNING:-2}")
    echo "warning"
    ;;
  "${LOG_LEVEL_ERROR:-3}")
    echo "error"
    ;;
  "${LOG_LEVEL_CRITICAL:-4}")
    echo "critical"
    ;;
  *)
    echo "unknown"
    ;;
  esac
}

# Function: logging_core_log
# Description: Enhanced internal log function with format support and component routing
# Parameters:
#   $1 (numeric): log level
#   $2 (string): level name
#   $3 (string): message
#   $4 (string): component (optional, defaults to "core")
#   $5 (string): log file (optional, defaults to main log)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_core_log 1 "INFO" "System started" "core"
# Dependencies:
#   - util_error_validate_input
#   - LOG_FORMAT, LOG_TIMESTAMP_FORMAT variables
logging_core_log() {
  local level="$1"
  local level_name="$2"
  local message="$3"
  local component="${4:-core}"
  local log_file="${5:-${LOG_FILE}}"

  # Basic validation (don't depend on util functions)
  if [[ -z "$level" || ! "$level" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if [[ -z "$level_name" ]]; then
    return 1
  fi

  if [[ -z "$message" ]]; then
    return 1
  fi

  # Check component-specific log level if available
  local effective_level="${CURRENT_LOG_LEVEL:-1}"
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" == "true" && -n "${COMPONENT_LOG_LEVELS[$component]:-}" ]]; then
    effective_level="${COMPONENT_LOG_LEVELS[$component]}"
  fi

  # Check if level is enabled
  if [[ "$level" -ge "$effective_level" ]]; then
    local timestamp
    timestamp=$(date +"${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")

    local log_entry
    case "${LOG_FORMAT:-standard}" in
    json)
      # Escape message for JSON
      local escaped_message
      escaped_message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
      log_entry=$(printf '{"timestamp":"%s","level":"%s","component":"%s","message":"%s"}' \
        "$timestamp" "$level_name" "$component" "$escaped_message")
      ;;
    structured)
      log_entry="timestamp=\"$timestamp\" level=\"$level_name\" component=\"$component\" message=\"$message\""
      ;;
    *)
      # Standard format
      if [[ "${LOG_INCLUDE_CALLER:-false}" == "true" ]]; then
        local caller_info=" [${FUNCNAME[4]:-main}:${BASH_LINENO[3]:-0}]"
        log_entry="[$timestamp] [$level_name] [$component]$caller_info $message"
      else
        log_entry="[$timestamp] [$level_name] [$component] $message"
      fi
      ;;
    esac

    # Write to log file with error handling
    if [[ -w "$log_file" ]] || [[ -w "$(dirname "$log_file")" ]]; then
      if ! echo "$log_entry" >>"$log_file" 2>/dev/null; then
        # Fallback: try to create the log file if it doesn't exist
        if [[ ! -f "$log_file" ]]; then
          if ! _logging_init_log_file "$log_file"; then
            echo "Warning: Failed to write to log file: $log_file" >&2
          else
            echo "$log_entry" >>"$log_file" 2>/dev/null
          fi
        fi
      fi
    fi

    # Output to appropriate streams based on level and current log level
    if [[ "${CURRENT_LOG_LEVEL:-1}" -le "$level" ]]; then
      if [[ "$level" -ge "${LOG_LEVEL_WARNING:-2}" ]]; then
        # Warning and above go to stderr
        echo "$log_entry" >&2
      else
        # Debug and info go to stdout
        echo "$log_entry"
      fi
    fi
  fi

  return 0
}

# Function: log_debug
# Description: Log debug message with component support and enhanced validation
# Parameters:
#   $1 (string): message
#   $2 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_debug "Processing started" "plugins"
# Dependencies:
#   - logging_core_log
#   - LOG_LEVEL_DEBUG constant
log_debug() {
  local message="$1"
  local component="${2:-core}"

  if [[ -n "$message" ]]; then
    logging_core_log "${LOG_LEVEL_DEBUG:-0}" "DEBUG" "$message" "$component"
  else
    return 1
  fi
}

# Function: log_info
# Description: Log info message with component support and enhanced validation
# Parameters:
#   $1 (string): message
#   $2 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_info "System initialized successfully" "core"
# Dependencies:
#   - logging_core_log
#   - LOG_LEVEL_INFO constant
log_info() {
  local message="$1"
  local component="${2:-core}"

  if [[ -n "$message" ]]; then
    logging_core_log "${LOG_LEVEL_INFO:-1}" "INFO" "$message" "$component"
  else
    return 1
  fi
}

# Function: log_warning
# Description: Log warning message with component support and enhanced validation
# Parameters:
#   $1 (string): message
#   $2 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_warning "Configuration file not found, using defaults" "config"
# Dependencies:
#   - logging_core_log
#   - LOG_LEVEL_WARNING constant
log_warning() {
  local message="$1"
  local component="${2:-core}"

  if [[ -n "$message" ]]; then
    logging_core_log "${LOG_LEVEL_WARNING:-2}" "WARNING" "$message" "$component"
  else
    return 1
  fi
}

# Function: log_error
# Description: Log error message with component support and specialized routing
# Parameters:
#   $1 (string): message
#   $2 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_error "Failed to connect to database" "core"
# Dependencies:
#   - logging_core_log
#   - LOG_LEVEL_ERROR constant
#   - ERROR_LOG variable
log_error() {
  local message="$1"
  local component="${2:-core}"

  if [[ -n "$message" ]]; then
    # Log to both main log and error log
    logging_core_log "${LOG_LEVEL_ERROR:-3}" "ERROR" "$message" "$component"

    # Also log to specialized error log if different from main log
    if [[ -n "${ERROR_LOG:-}" && "$ERROR_LOG" != "${LOG_FILE:-}" ]]; then
      logging_core_log "${LOG_LEVEL_ERROR:-3}" "ERROR" "$message" "$component" "$ERROR_LOG"
    fi
  else
    return 1
  fi
}

# Function: log_critical
# Description: Log critical message with component support and specialized routing
# Parameters:
#   $1 (string): message
#   $2 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_critical "System failure detected" "core"
# Dependencies:
#   - logging_core_log
#   - LOG_LEVEL_CRITICAL constant
#   - ERROR_LOG variable
log_critical() {
  local message="$1"
  local component="${2:-core}"

  if [[ -n "$message" ]]; then
    # Log to both main log and error log
    logging_core_log "${LOG_LEVEL_CRITICAL:-4}" "CRITICAL" "$message" "$component"

    # Also log to specialized error log if different from main log
    if [[ -n "${ERROR_LOG:-}" && "$ERROR_LOG" != "${LOG_FILE:-}" ]]; then
      logging_core_log "${LOG_LEVEL_CRITICAL:-4}" "CRITICAL" "$message" "$component" "$ERROR_LOG"
    fi
  else
    return 1
  fi
}

# Function: log_with_context
# Description: Log with enhanced caller context information
# Parameters:
#   $1 (string): log level (debug, info, warning, error, critical)
#   $2 (string): message
#   $3 (string): context (optional)
#   $4 (string): component (optional, defaults to "core")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   log_with_context "error" "Database connection failed" "retry_attempt_3" "database"
# Dependencies:
#   - util_error_validate_input
#   - log_* functions
log_with_context() {
  local level="$1"
  local message="$2"
  local context="${3:-}"
  local component="${4:-core}"

  if [[ -z "$level" ]]; then
    return 1
  fi

  if [[ -z "$message" ]]; then
    return 1
  fi

  # Get caller information
  local caller_function="${FUNCNAME[2]:-main}"
  local caller_line="${BASH_LINENO[1]:-0}"

  # Build enhanced message with context
  local full_message="$message"
  if [[ -n "$context" ]]; then
    full_message="$message [$context]"
  fi
  full_message="$full_message (${caller_function}:${caller_line})"

  # Route to appropriate log function
  case "$level" in
  debug)
    log_debug "$full_message" "$component"
    ;;
  info)
    log_info "$full_message" "$component"
    ;;
  warning)
    log_warning "$full_message" "$component"
    ;;
  error)
    log_error "$full_message" "$component"
    ;;
  critical)
    log_critical "$full_message" "$component"
    ;;
  *)
    echo "Error: Invalid log level '$level'" >&2
    return 1
    ;;
  esac
}

# Internal function: Initialize a log file with proper permissions
_logging_init_log_file() {
  local log_file="$1"
  local permissions="${2:-644}"

  if [[ -z "$log_file" ]]; then
    return 1
  fi

  # Create parent directory if it doesn't exist
  local log_dir
  log_dir=$(dirname "$log_file")
  if [[ ! -d "$log_dir" ]]; then
    if ! mkdir -p "$log_dir" 2>/dev/null; then
      echo "Error: Failed to create log directory: $log_dir" >&2
      return 1
    fi
  fi

  # Create log file if it doesn't exist
  if [[ ! -f "$log_file" ]]; then
    if ! touch "$log_file" 2>/dev/null; then
      echo "Error: Failed to create log file: $log_file" >&2
      return 1
    fi
  fi

  # Set proper permissions
  if ! chmod "$permissions" "$log_file" 2>/dev/null; then
    echo "Warning: Failed to set permissions on log file: $log_file" >&2
  fi

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_core_init
  export -f logging_set_level
  export -f logging_get_level
  export -f logging_core_log
  export -f log_debug
  export -f log_info
  export -f log_warning
  export -f log_error
  export -f log_critical
  export -f log_with_context
fi
