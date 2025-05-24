#!/bin/bash
#
# ServerSentry v2 - Logging System
#
# This module handles logging for all components

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

# Initialize logging system
init_logging() {
  # Create log directory if it doesn't exist
  if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || return 1
  fi

  # Create log file if it doesn't exist
  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" || return 1
  fi

  # Set log level from configuration if available
  if [ -n "${config_log_level:-}" ]; then
    case "${config_log_level}" in
    debug)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
      ;;
    info)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
      ;;
    warning)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING
      ;;
    error)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
      ;;
    critical)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_CRITICAL
      ;;
    *)
      echo "Invalid log level: ${config_log_level}, using default: info" >&2
      CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
      ;;
    esac
  fi

  log_debug "Logging system initialized"

  return 0
}

# Internal log function
_log() {
  local level="$1"
  local level_name="$2"
  local message="$3"

  # Check if level is enabled
  if [ "$level" -ge "$CURRENT_LOG_LEVEL" ]; then
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_entry="[$timestamp] [$level_name] $message"

    # Write to log file
    echo "$log_entry" >>"$LOG_FILE"

    # Also print to stderr for warning and above
    if [ "$level" -ge "$LOG_LEVEL_WARNING" ]; then
      echo "$log_entry" >&2
    fi

    # Also print to stdout for debug and info
    if [ "$level" -lt "$LOG_LEVEL_WARNING" ]; then
      echo "$log_entry"
    fi
  fi
}

# Debug log
log_debug() {
  _log "$LOG_LEVEL_DEBUG" "DEBUG" "$1"
}

# Info log
log_info() {
  _log "$LOG_LEVEL_INFO" "INFO" "$1"
}

# Warning log
log_warning() {
  _log "$LOG_LEVEL_WARNING" "WARNING" "$1"
}

# Error log
log_error() {
  _log "$LOG_LEVEL_ERROR" "ERROR" "$1"
}

# Critical log
log_critical() {
  _log "$LOG_LEVEL_CRITICAL" "CRITICAL" "$1"
}

# Rotate logs
rotate_logs() {
  log_debug "Rotating logs"

  # Create archive directory if it doesn't exist
  local archive_dir="${LOG_DIR}/archive"
  if [ ! -d "$archive_dir" ]; then
    mkdir -p "$archive_dir" || return 1
  fi

  # Create timestamp for archive filename
  local timestamp=$(date "+%Y%m%d_%H%M%S")
  local archive_file="${archive_dir}/serversentry_${timestamp}.log"

  # Compress and move the current log file
  if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    log_info "Archiving log to $archive_file"
    gzip -c "$LOG_FILE" >"${archive_file}.gz" || return 1

    # Clear the current log file
    >"$LOG_FILE"

    # Remove old archives (keep last 10)
    ls -t "${archive_dir}"/*.gz | tail -n +11 | xargs -r rm
  fi

  return 0
}

# Initialize logging on module load
init_logging
