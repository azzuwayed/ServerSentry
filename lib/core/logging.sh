#!/usr/bin/env bash
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
# Set BASE_DIR fallback if not set
if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  export BASE_DIR
fi

LOG_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOG_DIR}/serversentry.log"

# Log level constants
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Default log level (preserve early setting if available)
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}
export CURRENT_LOG_LEVEL

# Specialized log files
PERFORMANCE_LOG="${LOG_DIR}/performance.log"
ERROR_LOG="${LOG_DIR}/error.log"
AUDIT_LOG="${LOG_DIR}/audit.log"
SECURITY_LOG="${LOG_DIR}/security.log"

# Component log levels (can be overridden by config)
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  # Modern bash with associative array support
  declare -A COMPONENT_LOG_LEVELS=(
    ["core"]=$LOG_LEVEL_INFO
    ["plugins"]=$LOG_LEVEL_INFO
    ["notifications"]=$LOG_LEVEL_INFO
    ["config"]=$LOG_LEVEL_WARNING
    ["utils"]=$LOG_LEVEL_WARNING
    ["ui"]=$LOG_LEVEL_INFO
    ["performance"]=$LOG_LEVEL_DEBUG
    ["security"]=$LOG_LEVEL_WARNING
  )
  COMPONENT_LOGGING_SUPPORTED=true
else
  # Fallback for older bash versions
  COMPONENT_LOGGING_SUPPORTED=false
fi

# Log format settings
LOG_FORMAT="${LOG_FORMAT:-standard}"
LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
LOG_INCLUDE_CALLER="${LOG_INCLUDE_CALLER:-false}"

# New standardized function: logging_init
# Description: Initialize logging system with comprehensive configuration support
# Returns:
#   0 - success
#   1 - failure
logging_init() {
  # Create main log directory with secure permissions
  if [[ ! -d "$LOG_DIR" ]]; then
    if ! mkdir -p "$LOG_DIR"; then
      echo "Failed to create log directory: $LOG_DIR" >&2
      return 1
    fi
    chmod 755 "$LOG_DIR"
  fi

  # Create archive directory
  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    mkdir -p "$archive_dir" 2>/dev/null
    chmod 755 "$archive_dir" 2>/dev/null
  fi

  # Initialize main log file
  if ! _init_log_file "$LOG_FILE"; then
    return 1
  fi

  # Load logging configuration from config if available
  if declare -f config_get_value >/dev/null 2>&1; then
    _load_logging_config
  fi

  # Initialize specialized log files if enabled
  _init_specialized_logs

  # Log system initialization (only if not in quiet mode)
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le $LOG_LEVEL_DEBUG ]]; then
    log_debug "Logging system initialized with comprehensive configuration"
    log_debug "Main log: $LOG_FILE"
    log_debug "Log level: $(logging_get_level)"
    log_debug "Format: $LOG_FORMAT"
  fi

  return 0
}

# Internal function: Initialize a log file with proper permissions
_init_log_file() {
  local log_file="$1"
  local permissions="${2:-644}"

  if [[ ! -f "$log_file" ]]; then
    if ! touch "$log_file"; then
      echo "Failed to create log file: $log_file" >&2
      return 1
    fi
  fi
  chmod "$permissions" "$log_file" 2>/dev/null
  return 0
}

# Internal function: Load logging configuration from config
_load_logging_config() {
  # Load global log settings
  local config_level
  config_level=$(config_get_value "logging.global.default_level" "info")
  if [[ -n "$config_level" ]]; then
    logging_set_level "$config_level"
  fi

  # Load format settings
  LOG_FORMAT=$(config_get_value "logging.global.output_format" "standard")
  LOG_TIMESTAMP_FORMAT=$(config_get_value "logging.global.timestamp_format" "%Y-%m-%d %H:%M:%S")
  LOG_INCLUDE_CALLER=$(config_get_value "logging.global.include_caller" "false")

  # Load component-specific log levels
  local components=("core" "plugins" "notifications" "config" "utils" "ui" "performance" "security")
  for component in "${components[@]}"; do
    local level
    level=$(config_get_value "logging.components.$component" "")
    if [[ -n "$level" && "$COMPONENT_LOGGING_SUPPORTED" == "true" ]]; then
      case "$level" in
      debug) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_DEBUG ;;
      info) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_INFO ;;
      warning) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_WARNING ;;
      error) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_ERROR ;;
      critical) COMPONENT_LOG_LEVELS["$component"]=$LOG_LEVEL_CRITICAL ;;
      esac
    fi
  done

  # Update specialized log file paths from config
  PERFORMANCE_LOG=$(config_get_value "logging.specialized.performance.file" "$PERFORMANCE_LOG")
  ERROR_LOG=$(config_get_value "logging.specialized.error.file" "$ERROR_LOG")
  AUDIT_LOG=$(config_get_value "logging.specialized.audit.file" "$AUDIT_LOG")
  SECURITY_LOG=$(config_get_value "logging.specialized.security.file" "$SECURITY_LOG")

  # Make paths absolute if they're relative
  [[ "$PERFORMANCE_LOG" != /* ]] && PERFORMANCE_LOG="${BASE_DIR}/$PERFORMANCE_LOG"
  [[ "$ERROR_LOG" != /* ]] && ERROR_LOG="${BASE_DIR}/$ERROR_LOG"
  [[ "$AUDIT_LOG" != /* ]] && AUDIT_LOG="${BASE_DIR}/$AUDIT_LOG"
  [[ "$SECURITY_LOG" != /* ]] && SECURITY_LOG="${BASE_DIR}/$SECURITY_LOG"
}

# Internal function: Initialize specialized log files
_init_specialized_logs() {
  # Check if specialized logging is enabled
  if declare -f config_get_value >/dev/null 2>&1; then
    # Performance log
    if [[ "$(config_get_value "logging.specialized.performance.enabled" "true")" == "true" ]]; then
      _init_log_file "$PERFORMANCE_LOG"
    fi

    # Error log
    if [[ "$(config_get_value "logging.specialized.error.enabled" "true")" == "true" ]]; then
      _init_log_file "$ERROR_LOG"
    fi

    # Audit log
    if [[ "$(config_get_value "logging.specialized.audit.enabled" "true")" == "true" ]]; then
      _init_log_file "$AUDIT_LOG"
    fi

    # Security log
    if [[ "$(config_get_value "logging.specialized.security.enabled" "true")" == "true" ]]; then
      _init_log_file "$SECURITY_LOG"
    fi
  else
    # Fallback: create all specialized logs
    _init_log_file "$PERFORMANCE_LOG"
    _init_log_file "$ERROR_LOG"
    _init_log_file "$AUDIT_LOG"
    _init_log_file "$SECURITY_LOG"
  fi
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
    log_error "Archive directory does not exist: $archive_dir"
    return 1
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

# Enhanced internal log function with format support and specialized routing
_log() {
  local level="$1"
  local level_name="$2"
  local message="$3"
  local component="${4:-core}"
  local log_file="${5:-$LOG_FILE}"

  # Validate parameters
  if [[ -z "$message" ]]; then
    return 1
  fi

  # Check component-specific log level if available
  local effective_level="$CURRENT_LOG_LEVEL"
  if [[ "$COMPONENT_LOGGING_SUPPORTED" == "true" && -n "${COMPONENT_LOG_LEVELS[$component]:-}" ]]; then
    effective_level="${COMPONENT_LOG_LEVELS[$component]}"
  fi

  # Check if level is enabled
  if [[ "$level" -ge "$effective_level" ]]; then
    local timestamp
    timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")

    local log_entry
    case "$LOG_FORMAT" in
    json)
      log_entry=$(printf '{"timestamp":"%s","level":"%s","component":"%s","message":"%s"}' \
        "$timestamp" "$level_name" "$component" "$(echo "$message" | sed 's/"/\\"/g')")
      ;;
    structured)
      log_entry="timestamp=\"$timestamp\" level=\"$level_name\" component=\"$component\" message=\"$message\""
      ;;
    *)
      # Standard format
      if [[ "$LOG_INCLUDE_CALLER" == "true" ]]; then
        local caller_info=" [${FUNCNAME[3]:-main}:${BASH_LINENO[2]:-0}]"
        log_entry="[$timestamp] [$level_name] [$component]$caller_info $message"
      else
        log_entry="[$timestamp] [$level_name] [$component] $message"
      fi
      ;;
    esac

    # Write to log file with error handling
    if [[ -w "$log_file" ]]; then
      echo "$log_entry" >>"$log_file" 2>/dev/null
    fi

    # Output to appropriate streams (suppress if in quiet mode)
    if [[ "${CURRENT_LOG_LEVEL:-1}" -le "$level" ]]; then
      if [[ "$level" -ge "$LOG_LEVEL_WARNING" ]]; then
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

# Enhanced logging functions with component support
log_debug() {
  local message="$1"
  local component="${2:-core}"
  [[ -n "$message" ]] && _log "$LOG_LEVEL_DEBUG" "DEBUG" "$message" "$component"
}

log_info() {
  local message="$1"
  local component="${2:-core}"
  [[ -n "$message" ]] && _log "$LOG_LEVEL_INFO" "INFO" "$message" "$component"
}

log_warning() {
  local message="$1"
  local component="${2:-core}"
  [[ -n "$message" ]] && _log "$LOG_LEVEL_WARNING" "WARNING" "$message" "$component"
}

log_error() {
  local message="$1"
  local component="${2:-core}"
  [[ -n "$message" ]] && _log "$LOG_LEVEL_ERROR" "ERROR" "$message" "$component" "$ERROR_LOG"
}

log_critical() {
  local message="$1"
  local component="${2:-core}"
  [[ -n "$message" ]] && _log "$LOG_LEVEL_CRITICAL" "CRITICAL" "$message" "$component" "$ERROR_LOG"
}

# Specialized logging functions
log_performance() {
  local message="$1"
  local metrics="${2:-}"
  local full_message="$message"
  if [[ -n "$metrics" ]]; then
    full_message="$message | Metrics: $metrics"
  fi
  [[ -n "$message" ]] && _log "$LOG_LEVEL_DEBUG" "PERF" "$full_message" "performance" "$PERFORMANCE_LOG"
}

log_audit() {
  local action="$1"
  local user="${2:-system}"
  local details="${3:-}"
  local message="Action: $action | User: $user"
  if [[ -n "$details" ]]; then
    message="$message | Details: $details"
  fi
  _log "$LOG_LEVEL_INFO" "AUDIT" "$message" "audit" "$AUDIT_LOG"
}

log_security() {
  local event="$1"
  local severity="${2:-medium}"
  local details="${3:-}"
  local message="Security Event: $event | Severity: $severity"
  if [[ -n "$details" ]]; then
    message="$message | $details"
  fi

  # Map severity to log level
  local level="$LOG_LEVEL_WARNING"
  case "$severity" in
  low) level="$LOG_LEVEL_INFO" ;;
  medium) level="$LOG_LEVEL_WARNING" ;;
  high) level="$LOG_LEVEL_ERROR" ;;
  critical) level="$LOG_LEVEL_CRITICAL" ;;
  esac

  _log "$level" "SECURITY" "$message" "security" "$SECURITY_LOG"
}

# Component-specific logging helpers
log_plugin() {
  local level="$1"
  local message="$2"
  local plugin_name="${3:-unknown}"
  local full_message="[$plugin_name] $message"

  case "$level" in
  debug) log_debug "$full_message" "plugins" ;;
  info) log_info "$full_message" "plugins" ;;
  warning) log_warning "$full_message" "plugins" ;;
  error) log_error "$full_message" "plugins" ;;
  critical) log_critical "$full_message" "plugins" ;;
  esac
}

log_config() {
  local level="$1"
  local message="$2"

  case "$level" in
  debug) log_debug "$message" "config" ;;
  info) log_info "$message" "config" ;;
  warning) log_warning "$message" "config" ;;
  error) log_error "$message" "config" ;;
  critical) log_critical "$message" "config" ;;
  esac
}

log_notification() {
  local level="$1"
  local message="$2"
  local provider="${3:-}"
  local full_message="$message"
  if [[ -n "$provider" ]]; then
    full_message="[$provider] $message"
  fi

  case "$level" in
  debug) log_debug "$full_message" "notifications" ;;
  info) log_info "$full_message" "notifications" ;;
  warning) log_warning "$full_message" "notifications" ;;
  error) log_error "$full_message" "notifications" ;;
  critical) log_critical "$full_message" "notifications" ;;
  esac
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

# Function: logging_check_health
# Description: Check log system health and disk usage
# Returns:
#   0 - healthy
#   1 - warnings detected
#   2 - critical issues detected
logging_check_health() {
  local issues=0
  local warnings=0

  # Check if main log file is writable
  if [[ ! -w "$LOG_FILE" ]]; then
    log_error "Main log file is not writable: $LOG_FILE" "logging"
    ((issues++))
  fi

  # Check disk usage for log directory
  local log_disk_usage
  if command -v df >/dev/null 2>&1; then
    log_disk_usage=$(df "$LOG_DIR" | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    local threshold=$(config_get_value "logging.advanced.monitoring.disk_usage_threshold" "85")

    if [[ "$log_disk_usage" -ge "$threshold" ]]; then
      log_warning "Log disk usage is high: ${log_disk_usage}% (threshold: ${threshold}%)" "logging"
      ((warnings++))
    fi
  fi

  # Check log file sizes
  local max_size=$(config_get_value "logging.file.max_size" "10485760")
  if [[ -f "$LOG_FILE" ]]; then
    local current_size
    current_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ "$current_size" -ge "$max_size" ]]; then
      log_info "Main log file is approaching rotation size: $(format_bytes "$current_size")" "logging"
    fi
  fi

  # Check if specialized logs are accessible
  for log_file in "$PERFORMANCE_LOG" "$ERROR_LOG" "$AUDIT_LOG" "$SECURITY_LOG"; do
    if [[ -f "$log_file" && ! -w "$log_file" ]]; then
      log_warning "Specialized log file is not writable: $log_file" "logging"
      ((warnings++))
    fi
  done

  # Return status based on issues found
  if [[ "$issues" -gt 0 ]]; then
    return 2 # Critical issues
  elif [[ "$warnings" -gt 0 ]]; then
    return 1 # Warnings
  else
    return 0 # Healthy
  fi
}

# Function: logging_get_status
# Description: Get comprehensive logging system status
# Returns:
#   Status information via stdout
logging_get_status() {
  echo "=== ServerSentry Logging System Status ==="
  echo "Main Log File: $LOG_FILE"
  echo "Log Level: $(logging_get_level)"
  echo "Log Format: $LOG_FORMAT"
  echo "Timestamp Format: $LOG_TIMESTAMP_FORMAT"
  echo ""

  echo "Specialized Logs:"
  echo "  Performance: $PERFORMANCE_LOG"
  echo "  Error: $ERROR_LOG"
  echo "  Audit: $AUDIT_LOG"
  echo "  Security: $SECURITY_LOG"
  echo ""

  echo "Component Log Levels:"
  if [[ "$COMPONENT_LOGGING_SUPPORTED" == "true" ]]; then
    for component in "${!COMPONENT_LOG_LEVELS[@]}"; do
      local level_name
      case "${COMPONENT_LOG_LEVELS[$component]}" in
      0) level_name="debug" ;;
      1) level_name="info" ;;
      2) level_name="warning" ;;
      3) level_name="error" ;;
      4) level_name="critical" ;;
      *) level_name="unknown" ;;
      esac
      printf "  %-12s: %s\n" "$component" "$level_name"
    done
  else
    echo "  Component-specific logging not supported (bash < 4.0)"
    echo "  All components use global level: $(logging_get_level)"
  fi
  echo ""

  # Log file sizes
  echo "Log File Sizes:"
  for log_file in "$LOG_FILE" "$PERFORMANCE_LOG" "$ERROR_LOG" "$AUDIT_LOG" "$SECURITY_LOG"; do
    if [[ -f "$log_file" ]]; then
      local size
      size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
      local formatted_size
      formatted_size=$(format_bytes "$size")
      printf "  %-20s: %s\n" "$(basename "$log_file")" "$formatted_size"
    fi
  done
}

# Export all logging functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_init
  export -f logging_set_level
  export -f logging_get_level
  export -f logging_rotate
  export -f logging_cleanup_archives
  export -f logging_check_health
  export -f logging_get_status
  export -f log_debug
  export -f log_info
  export -f log_warning
  export -f log_error
  export -f log_critical
  export -f log_performance
  export -f log_audit
  export -f log_security
  export -f log_plugin
  export -f log_config
  export -f log_notification
  export -f log_with_context
  export -f logging_check_size
fi

# Initialize logging on module load
logging_init
