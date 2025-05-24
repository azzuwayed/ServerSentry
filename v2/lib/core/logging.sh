#!/bin/bash
#
# ServerSentry v2 - Logging System
#
# This module handles logging for all components

# Prevent multiple sourcing
if [[ "${LOGGING_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
LOGGING_MODULE_LOADED=true
export LOGGING_MODULE_LOADED

# Logging configuration
LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/serversentry.log"
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Default log level
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
export CURRENT_LOG_LEVEL

# New standardized function: logging_init
# Description: Initialize logging system with proper validation and directory setup
# Returns:
#   0 - success
#   1 - failure
logging_init() {
  # Create log directory with secure permissions
  if [[ ! -d "$LOG_DIR" ]]; then
    if ! mkdir -p "$LOG_DIR"; then
      echo "Failed to create log directory: $LOG_DIR" >&2
      return 1
    fi
    chmod 755 "$LOG_DIR"
  fi

  # Create log file with secure permissions
  if [[ ! -f "$LOG_FILE" ]]; then
    if ! touch "$LOG_FILE"; then
      echo "Failed to create log file: $LOG_FILE" >&2
      return 1
    fi
    chmod 644 "$LOG_FILE"
  fi

  # Set log level from configuration if available
  if [[ -n "${config_log_level:-}" ]]; then
    logging_set_level "${config_log_level}"
  fi

  log_debug "Logging system initialized"
  return 0
}

# New standardized function: logging_set_level
# Description: Set the current log level with validation
# Parameters:
#   $1 - log level (debug, info, warning, error, critical)
# Returns:
#   0 - success
#   1 - invalid log level
logging_set_level() {
  local level="$1"

  case "$level" in
  debug)
    CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
    export CURRENT_LOG_LEVEL
    ;;
  info)
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
    export CURRENT_LOG_LEVEL
    ;;
  warning)
    CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING
    export CURRENT_LOG_LEVEL
    ;;
  error)
    CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
    export CURRENT_LOG_LEVEL
    ;;
  critical)
    CURRENT_LOG_LEVEL=$LOG_LEVEL_CRITICAL
    export CURRENT_LOG_LEVEL
    ;;
  *)
    echo "Invalid log level: $level, using default: info" >&2
    CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
    export CURRENT_LOG_LEVEL
    return 1
    ;;
  esac

  return 0
}

# New standardized function: logging_get_level
# Description: Get the current log level name
# Returns:
#   Current log level name via stdout
logging_get_level() {
  case "$CURRENT_LOG_LEVEL" in
  $LOG_LEVEL_DEBUG)
    echo "debug"
    ;;
  $LOG_LEVEL_INFO)
    echo "info"
    ;;
  $LOG_LEVEL_WARNING)
    echo "warning"
    ;;
  $LOG_LEVEL_ERROR)
    echo "error"
    ;;
  $LOG_LEVEL_CRITICAL)
    echo "critical"
    ;;
  *)
    echo "unknown"
    ;;
  esac
}

# New standardized function: logging_rotate
# Description: Rotate log files with enhanced error handling and cleanup
# Returns:
#   0 - success
#   1 - failure
logging_rotate() {
  log_debug "Starting log rotation"

  # Create archive directory with secure permissions
  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    if ! mkdir -p "$archive_dir"; then
      log_error "Failed to create archive directory: $archive_dir"
      return 1
    fi
    chmod 755 "$archive_dir"
  fi

  # Check if log file exists and has content
  if [[ ! -f "$LOG_FILE" ]]; then
    log_debug "No log file to rotate: $LOG_FILE"
    return 0
  fi

  if [[ ! -s "$LOG_FILE" ]]; then
    log_debug "Log file is empty, skipping rotation: $LOG_FILE"
    return 0
  fi

  # Create timestamp for archive filename
  local timestamp
  timestamp=$(date "+%Y%m%d_%H%M%S")
  local archive_file="${archive_dir}/serversentry_${timestamp}.log"

  # Compress and move the current log file
  log_info "Archiving log to ${archive_file}.gz"

  if command -v gzip >/dev/null 2>&1; then
    if ! gzip -c "$LOG_FILE" >"${archive_file}.gz"; then
      log_error "Failed to compress log file"
      return 1
    fi
  else
    # Fallback: just copy without compression
    if ! cp "$LOG_FILE" "$archive_file"; then
      log_error "Failed to archive log file"
      return 1
    fi
  fi

  # Clear the current log file
  if ! >"$LOG_FILE"; then
    log_error "Failed to clear current log file"
    return 1
  fi

  # Set proper permissions on the new log file
  chmod 644 "$LOG_FILE"

  # Clean up old archives (keep configurable number, default 10)
  local max_archives="${config_max_log_archives:-10}"
  logging_cleanup_archives "$max_archives"

  log_info "Log rotation completed successfully"
  return 0
}

# New standardized function: logging_cleanup_archives
# Description: Clean up old log archives
# Parameters:
#   $1 - maximum number of archives to keep (defaults to 10)
# Returns:
#   0 - success
logging_cleanup_archives() {
  local max_archives="${1:-10}"
  local archive_dir="${LOG_DIR}/archive"

  if [[ ! -d "$archive_dir" ]]; then
    return 0
  fi

  # Count current archives
  local archive_count
  archive_count=$(find "$archive_dir" -name "serversentry_*.log*" -type f | wc -l)

  if [[ "$archive_count" -le "$max_archives" ]]; then
    log_debug "Archive count ($archive_count) within limit ($max_archives)"
    return 0
  fi

  # Remove oldest archives
  local files_to_remove=$((archive_count - max_archives))
  log_debug "Removing $files_to_remove old log archives"

  # Find and remove the oldest files
  find "$archive_dir" -name "serversentry_*.log*" -type f -print0 |
    xargs -0 ls -t |
    tail -n "$files_to_remove" |
    xargs -r rm

  log_debug "Log archive cleanup completed"
  return 0
}

# Enhanced internal log function with better error handling
_log() {
  local level="$1"
  local level_name="$2"
  local message="$3"

  # Validate parameters
  if [[ -z "$message" ]]; then
    return 1
  fi

  # Check if level is enabled
  if [[ "$level" -ge "$CURRENT_LOG_LEVEL" ]]; then
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_entry="[$timestamp] [$level_name] $message"

    # Write to log file with error handling
    if [[ -w "$LOG_FILE" ]]; then
      echo "$log_entry" >>"$LOG_FILE" 2>/dev/null
    fi

    # Output to appropriate streams
    if [[ "$level" -ge "$LOG_LEVEL_WARNING" ]]; then
      # Warning and above go to stderr
      echo "$log_entry" >&2
    else
      # Debug and info go to stdout
      echo "$log_entry"
    fi
  fi

  return 0
}

# Enhanced logging functions with validation
log_debug() {
  [[ -n "$1" ]] && _log "$LOG_LEVEL_DEBUG" "DEBUG" "$1"
}

log_info() {
  [[ -n "$1" ]] && _log "$LOG_LEVEL_INFO" "INFO" "$1"
}

log_warning() {
  [[ -n "$1" ]] && _log "$LOG_LEVEL_WARNING" "WARNING" "$1"
}

log_error() {
  [[ -n "$1" ]] && _log "$LOG_LEVEL_ERROR" "ERROR" "$1"
}

log_critical() {
  [[ -n "$1" ]] && _log "$LOG_LEVEL_CRITICAL" "CRITICAL" "$1"
}

# New utility functions for enhanced logging

# Function: log_with_context
# Description: Log with caller context information
# Parameters:
#   $1 - log level
#   $2 - message
#   $3 - context (optional)
log_with_context() {
  local level="$1"
  local message="$2"
  local context="${3:-}"

  local caller_function="${FUNCNAME[2]}"
  local caller_line="${BASH_LINENO[1]}"

  local full_message="$message"
  if [[ -n "$context" ]]; then
    full_message="$message [$context]"
  fi
  full_message="$full_message (${caller_function}:${caller_line})"

  case "$level" in
  debug)
    log_debug "$full_message"
    ;;
  info)
    log_info "$full_message"
    ;;
  warning)
    log_warning "$full_message"
    ;;
  error)
    log_error "$full_message"
    ;;
  critical)
    log_critical "$full_message"
    ;;
  esac
}

# Function: logging_check_size
# Description: Check if log rotation is needed based on file size
# Returns:
#   0 - rotation needed
#   1 - rotation not needed
logging_check_size() {
  local max_size="${config_max_log_size:-10485760}" # 10MB default

  if [[ ! -f "$LOG_FILE" ]]; then
    return 1
  fi

  local current_size
  current_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

  if [[ "$current_size" -ge "$max_size" ]]; then
    return 0
  else
    return 1
  fi
}

# === BACKWARD COMPATIBILITY FUNCTIONS ===

# Backward compatibility: init_logging
init_logging() {
  log_warning "Function init_logging() is deprecated, use logging_init() instead"
  logging_init "$@"
}

# Backward compatibility: rotate_logs
rotate_logs() {
  log_warning "Function rotate_logs() is deprecated, use logging_rotate() instead"
  logging_rotate "$@"
}

# Export new standardized functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_init
  export -f logging_set_level
  export -f logging_get_level
  export -f logging_rotate
  export -f logging_cleanup_archives
  export -f log_debug
  export -f log_info
  export -f log_warning
  export -f log_error
  export -f log_critical
  export -f log_with_context
  export -f logging_check_size

  # Export backward compatibility functions
  export -f init_logging
  export -f rotate_logs
fi

# Initialize logging on module load
logging_init
