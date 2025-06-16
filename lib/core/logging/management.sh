#!/usr/bin/env bash
#
# ServerSentry v2 - Log Management Module
#
# This module provides log rotation, cleanup, health monitoring, and status functions

# Source error utilities if available
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
elif [[ -f "${SERVERSENTRY_CORE_DIR}/utils.sh" ]]; then
  source "${SERVERSENTRY_CORE_DIR}/utils.sh"
else
  # Provide fallback function
  util_error_validate_input() {
    local value="$1"
    local param_name="$2"
    local validation_type="$3"

    case "$validation_type" in
    "required") [[ -n "$value" ]] ;;
    "numeric") [[ "$value" =~ ^[0-9]+$ ]] ;;
    "directory") [[ -d "$value" ]] ;;
    *) return 0 ;;
    esac
  }

  util_error_safe_execute() {
    local command="$1"
    eval "$command"
  }
fi

# Function: logging_management_init
# Description: Initialize log management system with configuration validation
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_management_init
# Dependencies:
#   - util_error_validate_input
#   - LOG_DIR variable
logging_management_init() {
  # Validate log directory exists and is writable
  if ! util_error_validate_input "$LOG_DIR" "LOG_DIR" "directory"; then
    echo "Error: Log directory not found or not accessible: $LOG_DIR" >&2
    return 1
  fi

  # Create archive directory if it doesn't exist
  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    if ! mkdir -p "$archive_dir" 2>/dev/null; then
      echo "Warning: Failed to create archive directory: $archive_dir" >&2
    else
      chmod 755 "$archive_dir" 2>/dev/null
    fi
  fi

  # Set default configuration values if not set
  export config_max_log_size="${config_max_log_size:-10485760}"   # 10MB default
  export config_max_log_archives="${config_max_log_archives:-10}" # Keep 10 archives

  return 0
}

# Function: logging_rotate
# Description: Rotate log files with enhanced error handling and compression
# Parameters:
#   $1 (string): log file path (optional, defaults to main log)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_rotate "/path/to/custom.log"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
#   - LOG_FILE, LOG_DIR variables
logging_rotate() {
  local log_file="${1:-${LOG_FILE}}"

  if ! util_error_validate_input "$log_file" "log_file" "required"; then
    echo "Error: Log file path is required" >&2
    return 1
  fi

  log_debug "Starting log rotation for: $log_file" "logging"

  # Create archive directory with secure permissions
  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    if ! mkdir -p "$archive_dir" 2>/dev/null; then
      log_error "Failed to create archive directory: $archive_dir" "logging"
      return 1
    fi
    chmod 755 "$archive_dir" 2>/dev/null
  fi

  # Check if log file exists and has content
  if [[ ! -f "$log_file" ]]; then
    log_debug "No log file to rotate: $log_file" "logging"
    return 0
  fi

  if [[ ! -s "$log_file" ]]; then
    log_debug "Log file is empty, skipping rotation: $log_file" "logging"
    return 0
  fi

  # Create timestamp for archive filename
  local timestamp
  timestamp=$(date "+%Y%m%d_%H%M%S")
  local log_basename
  log_basename=$(basename "$log_file" .log)
  local archive_file="${archive_dir}/${log_basename}_${timestamp}.log"

  # Compress and move the current log file
  log_info "Archiving log to ${archive_file}.gz" "logging"

  if command -v gzip >/dev/null 2>&1; then
    if ! util_error_safe_execute "gzip -c '$log_file' > '${archive_file}.gz'" "Failed to compress log file" "" 10; then
      log_error "Failed to compress log file: $log_file" "logging"
      return 1
    fi
  else
    # Fallback: just copy without compression
    if ! util_error_safe_execute "cp '$log_file' '$archive_file'" "Failed to archive log file" "" 5; then
      log_error "Failed to archive log file: $log_file" "logging"
      return 1
    fi
  fi

  # Clear the current log file
  if ! util_error_safe_execute "> '$log_file'" "Failed to clear current log file" "" 2; then
    log_error "Failed to clear current log file: $log_file" "logging"
    return 1
  fi

  # Set proper permissions on the new log file
  if ! chmod 644 "$log_file" 2>/dev/null; then
    log_warning "Failed to set permissions on log file: $log_file" "logging"
  fi

  # Clean up old archives
  local max_archives="${config_max_log_archives:-10}"
  if ! logging_cleanup_archives "$max_archives" "$log_basename"; then
    log_warning "Failed to cleanup old archives for: $log_basename" "logging"
  fi

  log_info "Log rotation completed successfully for: $log_file" "logging"
  return 0
}

# Function: logging_cleanup_archives
# Description: Clean up old log archives with enhanced filtering and validation
# Parameters:
#   $1 (numeric): maximum number of archives to keep (optional, defaults to 10)
#   $2 (string): log basename filter (optional, cleans all if not specified)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_cleanup_archives 5 "serversentry"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
#   - LOG_DIR variable
logging_cleanup_archives() {
  local max_archives="${1:-10}"
  local log_basename="${2:-}"

  if ! util_error_validate_input "$max_archives" "max_archives" "numeric"; then
    echo "Error: Max archives must be a number" >&2
    return 1
  fi

  local archive_dir="${LOG_DIR}/archive"
  if [[ ! -d "$archive_dir" ]]; then
    log_debug "Archive directory does not exist: $archive_dir" "logging"
    return 0
  fi

  # Build file pattern for cleanup
  local file_pattern="*.log*"
  if [[ -n "$log_basename" ]]; then
    file_pattern="${log_basename}_*.log*"
  fi

  # Count current archives
  local archive_count
  archive_count=$(find "$archive_dir" -name "$file_pattern" -type f 2>/dev/null | wc -l)

  if [[ "$archive_count" -le "$max_archives" ]]; then
    log_debug "Archive count ($archive_count) within limit ($max_archives) for pattern: $file_pattern" "logging"
    return 0
  fi

  # Calculate files to remove
  local files_to_remove=$((archive_count - max_archives))
  log_debug "Removing $files_to_remove old log archives matching: $file_pattern" "logging"

  # Find and remove the oldest files
  local cleanup_command="find '$archive_dir' -name '$file_pattern' -type f -print0 | xargs -0 ls -t | tail -n $files_to_remove | xargs -r rm"

  if util_error_safe_execute "$cleanup_command" "Failed to cleanup old archives" "" 10; then
    log_info "Successfully removed $files_to_remove old log archives" "logging"
  else
    log_warning "Failed to remove some old log archives" "logging"
    return 1
  fi

  return 0
}

# Function: logging_check_size
# Description: Check if log rotation is needed based on file size with enhanced validation
# Parameters:
#   $1 (string): log file path (optional, defaults to main log)
#   $2 (numeric): max size in bytes (optional, uses config default)
# Returns:
#   0 - rotation needed
#   1 - rotation not needed
#   2 - error checking size
# Example:
#   if logging_check_size "/path/to/log"; then echo "Rotation needed"; fi
# Dependencies:
#   - util_error_validate_input
#   - LOG_FILE variable
logging_check_size() {
  local log_file="${1:-${LOG_FILE}}"
  local max_size="${2:-${config_max_log_size:-10485760}}"

  if ! util_error_validate_input "$log_file" "log_file" "required"; then
    return 2
  fi

  if ! util_error_validate_input "$max_size" "max_size" "numeric"; then
    return 2
  fi

  if [[ ! -f "$log_file" ]]; then
    log_debug "Log file does not exist: $log_file" "logging"
    return 1
  fi

  # Get file size (cross-platform compatible)
  local current_size
  if command -v stat >/dev/null 2>&1; then
    # Try BSD stat first (macOS), then GNU stat (Linux)
    current_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
  else
    # Fallback using ls
    current_size=$(ls -l "$log_file" 2>/dev/null | awk '{print $5}' || echo "0")
  fi

  if [[ "$current_size" -ge "$max_size" ]]; then
    log_debug "Log file size ($current_size bytes) exceeds limit ($max_size bytes): $log_file" "logging"
    return 0
  else
    log_debug "Log file size ($current_size bytes) within limit ($max_size bytes): $log_file" "logging"
    return 1
  fi
}

# Function: logging_check_health
# Description: Comprehensive log system health check with detailed reporting
# Parameters: None
# Returns:
#   0 - healthy
#   1 - warnings detected
#   2 - critical issues detected
# Example:
#   health_status=$(logging_check_health)
# Dependencies:
#   - util_error_validate_input
#   - LOG_FILE, LOG_DIR variables
logging_check_health() {
  local issues=0
  local warnings=0
  local health_report=""

  log_debug "Starting comprehensive logging system health check" "logging"

  # Check if main log file is writable
  if [[ ! -w "$LOG_FILE" ]]; then
    if [[ ! -w "$(dirname "$LOG_FILE")" ]]; then
      health_report+="CRITICAL: Main log file and directory not writable: $LOG_FILE\n"
      ((issues++))
    else
      health_report+="WARNING: Main log file not writable but directory is: $LOG_FILE\n"
      ((warnings++))
    fi
  fi

  # Check disk usage for log directory
  if command -v df >/dev/null 2>&1; then
    local log_disk_usage
    log_disk_usage=$(df "$LOG_DIR" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")

    if [[ "$log_disk_usage" =~ ^[0-9]+$ ]]; then
      local threshold
      if declare -f config_get_value >/dev/null 2>&1; then
        threshold=$(config_get_value "logging.advanced.monitoring.disk_usage_threshold" "85")
      else
        threshold=85
      fi

      if [[ "$log_disk_usage" -ge "$threshold" ]]; then
        if [[ "$log_disk_usage" -ge 95 ]]; then
          health_report+="CRITICAL: Log disk usage critically high: ${log_disk_usage}%\n"
          ((issues++))
        else
          health_report+="WARNING: Log disk usage high: ${log_disk_usage}% (threshold: ${threshold}%)\n"
          ((warnings++))
        fi
      fi
    fi
  fi

  # Check log file sizes against rotation thresholds
  local max_size="${config_max_log_size:-10485760}"
  local log_files=("$LOG_FILE")

  # Add specialized logs if they exist
  [[ -n "${PERFORMANCE_LOG:-}" && -f "${PERFORMANCE_LOG}" ]] && log_files+=("${PERFORMANCE_LOG}")
  [[ -n "${ERROR_LOG:-}" && -f "${ERROR_LOG}" ]] && log_files+=("${ERROR_LOG}")
  [[ -n "${AUDIT_LOG:-}" && -f "${AUDIT_LOG}" ]] && log_files+=("${AUDIT_LOG}")
  [[ -n "${SECURITY_LOG:-}" && -f "${SECURITY_LOG}" ]] && log_files+=("${SECURITY_LOG}")

  for log_file in "${log_files[@]}"; do
    if [[ -f "$log_file" ]]; then
      if logging_check_size "$log_file" "$max_size"; then
        local current_size
        current_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
        local formatted_size
        formatted_size=$(logging_format_bytes "$current_size")
        health_report+="INFO: Log file approaching rotation size: $(basename "$log_file") ($formatted_size)\n"
      fi

      # Check if log file is writable
      if [[ ! -w "$log_file" ]]; then
        health_report+="WARNING: Specialized log file not writable: $(basename "$log_file")\n"
        ((warnings++))
      fi
    fi
  done

  # Check archive directory
  local archive_dir="${LOG_DIR}/archive"
  if [[ -d "$archive_dir" ]]; then
    if [[ ! -w "$archive_dir" ]]; then
      health_report+="WARNING: Archive directory not writable: $archive_dir\n"
      ((warnings++))
    fi

    # Check number of archives
    local archive_count
    archive_count=$(find "$archive_dir" -name "*.log*" -type f 2>/dev/null | wc -l)
    local max_archives="${config_max_log_archives:-10}"

    if [[ "$archive_count" -gt "$max_archives" ]]; then
      health_report+="INFO: Archive count ($archive_count) exceeds configured limit ($max_archives)\n"
    fi
  else
    health_report+="WARNING: Archive directory does not exist: $archive_dir\n"
    ((warnings++))
  fi

  # Check log rotation configuration
  if ! command -v gzip >/dev/null 2>&1; then
    health_report+="WARNING: gzip not available, log compression disabled\n"
    ((warnings++))
  fi

  # Output health report
  if [[ -n "$health_report" ]]; then
    echo -e "$health_report"
  fi

  # Return status based on issues found
  if [[ "$issues" -gt 0 ]]; then
    log_error "Logging system health check found $issues critical issues and $warnings warnings" "logging"
    return 2
  elif [[ "$warnings" -gt 0 ]]; then
    log_warning "Logging system health check found $warnings warnings" "logging"
    return 1
  else
    log_debug "Logging system health check passed" "logging"
    return 0
  fi
}

# Function: logging_get_status
# Description: Get comprehensive logging system status with enhanced information
# Parameters: None
# Returns:
#   Status information via stdout
# Example:
#   status=$(logging_get_status)
# Dependencies:
#   - logging_get_level
#   - LOG_FILE, LOG_DIR variables
logging_get_status() {
  echo "=== ServerSentry Logging System Status ==="
  echo "Main Log File: ${LOG_FILE}"
  echo "Log Directory: ${LOG_DIR}"
  echo "Log Level: $(logging_get_level)"
  echo "Log Format: ${LOG_FORMAT:-standard}"
  echo "Timestamp Format: ${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
  echo "Include Caller: ${LOG_INCLUDE_CALLER:-false}"
  echo ""

  echo "Specialized Logs:"
  echo "  Performance: ${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}"
  echo "  Error: ${ERROR_LOG:-${LOG_DIR}/error.log}"
  echo "  Audit: ${AUDIT_LOG:-${LOG_DIR}/audit.log}"
  echo "  Security: ${SECURITY_LOG:-${LOG_DIR}/security.log}"
  echo ""

  echo "Configuration:"
  echo "  Max Log Size: $(logging_format_bytes "${config_max_log_size:-10485760}")"
  echo "  Max Archives: ${config_max_log_archives:-10}"
  echo ""

  echo "Component Log Levels:"
  if [[ "${COMPONENT_LOGGING_SUPPORTED:-false}" == "true" && -n "${COMPONENT_LOG_LEVELS[*]:-}" ]]; then
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

  # Log file sizes and status
  echo "Log File Status:"
  local log_files=(
    "$LOG_FILE:Main"
    "${PERFORMANCE_LOG:-${LOG_DIR}/performance.log}:Performance"
    "${ERROR_LOG:-${LOG_DIR}/error.log}:Error"
    "${AUDIT_LOG:-${LOG_DIR}/audit.log}:Audit"
    "${SECURITY_LOG:-${LOG_DIR}/security.log}:Security"
  )

  for log_entry in "${log_files[@]}"; do
    local log_file="${log_entry%:*}"
    local log_type="${log_entry#*:}"

    if [[ -f "$log_file" ]]; then
      local size
      size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
      local formatted_size
      formatted_size=$(logging_format_bytes "$size")
      local writable="No"
      [[ -w "$log_file" ]] && writable="Yes"
      printf "  %-12s: %s (Writable: %s)\n" "$log_type" "$formatted_size" "$writable"
    else
      printf "  %-12s: Not found\n" "$log_type"
    fi
  done
  echo ""

  # Archive information
  local archive_dir="${LOG_DIR}/archive"
  if [[ -d "$archive_dir" ]]; then
    local archive_count
    archive_count=$(find "$archive_dir" -name "*.log*" -type f 2>/dev/null | wc -l)
    echo "Archive Status:"
    echo "  Directory: $archive_dir"
    echo "  Archive Count: $archive_count"
    echo "  Max Archives: ${config_max_log_archives:-10}"

    if [[ "$archive_count" -gt 0 ]]; then
      local total_archive_size
      total_archive_size=$(find "$archive_dir" -name "*.log*" -type f -exec stat -f%z {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
      echo "  Total Archive Size: $(logging_format_bytes "$total_archive_size")"
    fi
  else
    echo "Archive Status: Directory not found"
  fi
}

# Function: logging_format_bytes
# Description: Format byte count into human-readable format
# Parameters:
#   $1 (numeric): byte count
# Returns:
#   Formatted size string via stdout
# Example:
#   size=$(logging_format_bytes 1048576)  # Returns "1.0M"
# Dependencies:
#   - util_error_validate_input
logging_format_bytes() {
  local bytes="$1"

  if ! util_error_validate_input "$bytes" "bytes" "numeric"; then
    echo "0B"
    return 1
  fi

  if [[ "$bytes" -eq 0 ]]; then
    echo "0B"
  elif [[ "$bytes" -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ "$bytes" -lt 1048576 ]]; then
    echo "$(echo "scale=1; $bytes / 1024" | bc 2>/dev/null || echo "$((bytes / 1024))")K"
  elif [[ "$bytes" -lt 1073741824 ]]; then
    echo "$(echo "scale=1; $bytes / 1048576" | bc 2>/dev/null || echo "$((bytes / 1048576))")M"
  else
    echo "$(echo "scale=1; $bytes / 1073741824" | bc 2>/dev/null || echo "$((bytes / 1073741824))")G"
  fi
}

# Function: logging_auto_rotate
# Description: Automatically rotate logs based on size thresholds
# Parameters: None
# Returns:
#   0 - success (rotation performed or not needed)
#   1 - failure
# Example:
#   logging_auto_rotate
# Dependencies:
#   - logging_check_size
#   - logging_rotate
logging_auto_rotate() {
  local rotated_count=0
  local failed_count=0

  log_debug "Starting automatic log rotation check" "logging"

  # Check main log file
  if logging_check_size "$LOG_FILE"; then
    if logging_rotate "$LOG_FILE"; then
      ((rotated_count++))
      log_info "Auto-rotated main log file: $LOG_FILE" "logging"
    else
      ((failed_count++))
      log_error "Failed to auto-rotate main log file: $LOG_FILE" "logging"
    fi
  fi

  # Check specialized log files
  local specialized_logs=(
    "${PERFORMANCE_LOG:-}"
    "${ERROR_LOG:-}"
    "${AUDIT_LOG:-}"
    "${SECURITY_LOG:-}"
  )

  for log_file in "${specialized_logs[@]}"; do
    if [[ -n "$log_file" && -f "$log_file" ]]; then
      if logging_check_size "$log_file"; then
        if logging_rotate "$log_file"; then
          ((rotated_count++))
          log_info "Auto-rotated specialized log: $(basename "$log_file")" "logging"
        else
          ((failed_count++))
          log_error "Failed to auto-rotate specialized log: $(basename "$log_file")" "logging"
        fi
      fi
    fi
  done

  if [[ "$rotated_count" -gt 0 ]]; then
    log_info "Auto-rotation completed: $rotated_count files rotated, $failed_count failures" "logging"
  else
    log_debug "Auto-rotation check completed: no rotation needed" "logging"
  fi

  return "$failed_count"
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f logging_management_init
  export -f logging_rotate
  export -f logging_cleanup_archives
  export -f logging_check_size
  export -f logging_check_health
  export -f logging_get_status
  export -f logging_format_bytes
  export -f logging_auto_rotate
fi
