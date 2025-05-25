#!/usr/bin/env bash
#
# ServerSentry v2 - Comprehensive Error Handling
#
# This module provides advanced error handling, recovery, and user-friendly error reporting

# Error handling configuration
ERROR_HANDLING_ENABLED="${ERROR_HANDLING_ENABLED:-true}"
ERROR_LOG_FILE="${ERROR_LOG_FILE:-${BASE_DIR}/logs/error.log}"
ERROR_RECOVERY_ENABLED="${ERROR_RECOVERY_ENABLED:-true}"
ERROR_NOTIFICATION_ENABLED="${ERROR_NOTIFICATION_ENABLED:-true}"
ERROR_STACK_TRACE_ENABLED="${ERROR_STACK_TRACE_ENABLED:-true}"

# Error codes
declare -r ERROR_CODE_SUCCESS=0
declare -r ERROR_CODE_GENERAL=1
declare -r ERROR_CODE_INVALID_ARGUMENT=2
declare -r ERROR_CODE_FILE_NOT_FOUND=3
declare -r ERROR_CODE_PERMISSION_DENIED=4
declare -r ERROR_CODE_NETWORK_ERROR=5
declare -r ERROR_CODE_TIMEOUT=6
declare -r ERROR_CODE_CONFIGURATION_ERROR=7
declare -r ERROR_CODE_PLUGIN_ERROR=8
declare -r ERROR_CODE_DEPENDENCY_ERROR=9
declare -r ERROR_CODE_RESOURCE_EXHAUSTED=10
declare -r ERROR_CODE_CRITICAL_SYSTEM_ERROR=11

# Error severity levels
declare -r ERROR_SEVERITY_LOW=1
declare -r ERROR_SEVERITY_MEDIUM=2
declare -r ERROR_SEVERITY_HIGH=3
declare -r ERROR_SEVERITY_CRITICAL=4

# Error context tracking
declare -A ERROR_CONTEXT
declare -A ERROR_RECOVERY_STRATEGIES
declare -A ERROR_STATISTICS

# Source dependencies
if [[ -f "$BASE_DIR/lib/core/logging.sh" ]]; then
  source "$BASE_DIR/lib/core/logging.sh"
fi

# Initialize error handling system
# Returns:
#   0 - success
#   1 - failure
error_handling_init() {
  log_debug "Initializing error handling system"

  # Create error log directory
  local error_log_dir
  error_log_dir=$(dirname "$ERROR_LOG_FILE")
  if ! mkdir -p "$error_log_dir" 2>/dev/null; then
    echo "Warning: Failed to create error log directory: $error_log_dir" >&2
    return 1
  fi

  # Set up error traps
  if [[ "$ERROR_HANDLING_ENABLED" == "true" ]]; then
    trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
    trap 'error_exit_handler $?' EXIT
    set -eE # Exit on error and inherit ERR trap
  fi

  # Initialize error recovery strategies
  _init_error_recovery_strategies

  # Initialize error statistics
  ERROR_STATISTICS["total_errors"]=0
  ERROR_STATISTICS["recovered_errors"]=0
  ERROR_STATISTICS["critical_errors"]=0
  ERROR_STATISTICS["last_error_time"]=0

  log_debug "Error handling system initialized successfully"
  return 0
}

# Main error trap handler
# Parameters:
#   $1 - exit code
#   $2 - line number
#   $3 - bash line number
#   $4 - command that failed
#   $5 - function stack
error_trap_handler() {
  local exit_code="$1"
  local line_number="$2"
  local bash_line_number="$3"
  local failed_command="$4"
  local function_stack="$5"

  # Avoid recursive error handling
  trap - ERR

  # Skip if exit code is 0 (success)
  [[ "$exit_code" -eq 0 ]] && return 0

  # Update error statistics
  ERROR_STATISTICS["total_errors"]=$((${ERROR_STATISTICS["total_errors"]} + 1))
  ERROR_STATISTICS["last_error_time"]=$(date +%s)

  # Determine error severity
  local severity
  severity=$(determine_error_severity "$exit_code" "$failed_command")

  # Create error context
  local error_context
  error_context=$(create_error_context "$exit_code" "$line_number" "$bash_line_number" "$failed_command" "$function_stack" "$severity")

  # Log the error
  log_error_with_context "$error_context"

  # Attempt error recovery
  if [[ "$ERROR_RECOVERY_ENABLED" == "true" ]]; then
    if attempt_error_recovery "$exit_code" "$failed_command" "$error_context"; then
      ERROR_STATISTICS["recovered_errors"]=$((${ERROR_STATISTICS["recovered_errors"]} + 1))
      log_info "Error recovery successful for: $failed_command"

      # Re-enable error trap and continue
      trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
      return 0
    fi
  fi

  # Handle critical errors
  if [[ "$severity" -eq "$ERROR_SEVERITY_CRITICAL" ]]; then
    ERROR_STATISTICS["critical_errors"]=$((${ERROR_STATISTICS["critical_errors"]} + 1))
    handle_critical_error "$error_context"
  fi

  # Send error notification if enabled
  if [[ "$ERROR_NOTIFICATION_ENABLED" == "true" ]]; then
    send_error_notification "$error_context"
  fi

  # Re-enable error trap
  trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
}

# Exit handler for cleanup
# Parameters:
#   $1 - exit code
error_exit_handler() {
  local exit_code="$1"

  # Only run cleanup on non-zero exit codes
  if [[ "$exit_code" -ne 0 ]]; then
    log_debug "Running error exit cleanup (exit code: $exit_code)"

    # Generate error summary
    generate_error_summary

    # Cleanup temporary files
    cleanup_on_error
  fi
}

# Determine error severity based on exit code and command
# Parameters:
#   $1 - exit code
#   $2 - failed command
# Returns:
#   Severity level via stdout
determine_error_severity() {
  local exit_code="$1"
  local failed_command="$2"

  # Critical system errors
  if [[ "$exit_code" -eq "$ERROR_CODE_CRITICAL_SYSTEM_ERROR" ]] ||
    [[ "$failed_command" =~ (rm|mv|cp).*(-r|-rf).*/$ ]] ||
    [[ "$failed_command" =~ sudo.*rm ]] ||
    [[ "$failed_command" =~ shutdown|reboot|halt ]]; then
    echo "$ERROR_SEVERITY_CRITICAL"
    return
  fi

  # High severity errors
  if [[ "$exit_code" -eq "$ERROR_CODE_PERMISSION_DENIED" ]] ||
    [[ "$exit_code" -eq "$ERROR_CODE_RESOURCE_EXHAUSTED" ]] ||
    [[ "$exit_code" -eq "$ERROR_CODE_CONFIGURATION_ERROR" ]] ||
    [[ "$failed_command" =~ (plugin|notification|config) ]]; then
    echo "$ERROR_SEVERITY_HIGH"
    return
  fi

  # Medium severity errors
  if [[ "$exit_code" -eq "$ERROR_CODE_NETWORK_ERROR" ]] ||
    [[ "$exit_code" -eq "$ERROR_CODE_TIMEOUT" ]] ||
    [[ "$exit_code" -eq "$ERROR_CODE_PLUGIN_ERROR" ]] ||
    [[ "$exit_code" -eq "$ERROR_CODE_DEPENDENCY_ERROR" ]]; then
    echo "$ERROR_SEVERITY_MEDIUM"
    return
  fi

  # Default to low severity
  echo "$ERROR_SEVERITY_LOW"
}

# Create comprehensive error context
# Parameters:
#   $1 - exit code
#   $2 - line number
#   $3 - bash line number
#   $4 - failed command
#   $5 - function stack
#   $6 - severity
# Returns:
#   JSON error context via stdout
create_error_context() {
  local exit_code="$1"
  local line_number="$2"
  local bash_line_number="$3"
  local failed_command="$4"
  local function_stack="$5"
  local severity="$6"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local hostname
  hostname=$(hostname 2>/dev/null || echo "unknown")

  local user
  user=$(whoami 2>/dev/null || echo "unknown")

  local pwd
  pwd=$(pwd 2>/dev/null || echo "unknown")

  local error_message
  error_message=$(get_user_friendly_error_message "$exit_code" "$failed_command")

  # Create JSON context (using basic string concatenation for compatibility)
  local context="{
    \"timestamp\": \"$timestamp\",
    \"hostname\": \"$hostname\",
    \"user\": \"$user\",
    \"working_directory\": \"$pwd\",
    \"exit_code\": $exit_code,
    \"line_number\": $line_number,
    \"bash_line_number\": $bash_line_number,
    \"failed_command\": \"$(echo "$failed_command" | sed 's/"/\\"/g')\",
    \"function_stack\": \"$(echo "$function_stack" | sed 's/"/\\"/g')\",
    \"severity\": $severity,
    \"severity_name\": \"$(get_severity_name "$severity")\",
    \"error_message\": \"$(echo "$error_message" | sed 's/"/\\"/g')\",
    \"process_id\": $$,
    \"parent_process_id\": $PPID,
    \"bash_version\": \"$BASH_VERSION\",
    \"serversentry_version\": \"$(get_serversentry_version)\"
  }"

  # Add stack trace if enabled
  if [[ "$ERROR_STACK_TRACE_ENABLED" == "true" ]]; then
    local stack_trace
    stack_trace=$(generate_stack_trace)
    context=$(echo "$context" | sed 's/}$/,\"stack_trace\":\"'"$(echo "$stack_trace" | sed 's/"/\\"/g')"'\"}/')
  fi

  echo "$context"
}

# Generate stack trace
# Returns:
#   Stack trace via stdout
generate_stack_trace() {
  local stack_trace=""
  local i=1

  while [[ $i -lt ${#FUNCNAME[@]} ]]; do
    local func="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$((i - 1))]}"

    if [[ -n "$func" && "$func" != "main" ]]; then
      stack_trace+="  at $func ($file:$line)\\n"
    fi

    ((i++))
  done

  echo "$stack_trace"
}

# Get user-friendly error message
# Parameters:
#   $1 - exit code
#   $2 - failed command
# Returns:
#   User-friendly error message via stdout
get_user_friendly_error_message() {
  local exit_code="$1"
  local failed_command="$2"

  case "$exit_code" in
  "$ERROR_CODE_SUCCESS")
    echo "Operation completed successfully"
    ;;
  "$ERROR_CODE_GENERAL")
    echo "A general error occurred while executing: $failed_command"
    ;;
  "$ERROR_CODE_INVALID_ARGUMENT")
    echo "Invalid argument or parameter provided to: $failed_command"
    ;;
  "$ERROR_CODE_FILE_NOT_FOUND")
    echo "Required file or directory not found for: $failed_command"
    ;;
  "$ERROR_CODE_PERMISSION_DENIED")
    echo "Permission denied while executing: $failed_command. Check file permissions and user privileges."
    ;;
  "$ERROR_CODE_NETWORK_ERROR")
    echo "Network connectivity issue encountered during: $failed_command"
    ;;
  "$ERROR_CODE_TIMEOUT")
    echo "Operation timed out while executing: $failed_command"
    ;;
  "$ERROR_CODE_CONFIGURATION_ERROR")
    echo "Configuration error detected in: $failed_command. Please check your configuration files."
    ;;
  "$ERROR_CODE_PLUGIN_ERROR")
    echo "Plugin error occurred during: $failed_command. Check plugin configuration and dependencies."
    ;;
  "$ERROR_CODE_DEPENDENCY_ERROR")
    echo "Missing or incompatible dependency for: $failed_command"
    ;;
  "$ERROR_CODE_RESOURCE_EXHAUSTED")
    echo "System resources exhausted during: $failed_command. Check disk space, memory, and CPU usage."
    ;;
  "$ERROR_CODE_CRITICAL_SYSTEM_ERROR")
    echo "CRITICAL: System error detected in: $failed_command. Immediate attention required."
    ;;
  *)
    echo "Unknown error (code: $exit_code) occurred while executing: $failed_command"
    ;;
  esac
}

# Get severity name from level
# Parameters:
#   $1 - severity level
# Returns:
#   Severity name via stdout
get_severity_name() {
  local severity="$1"

  case "$severity" in
  "$ERROR_SEVERITY_LOW") echo "LOW" ;;
  "$ERROR_SEVERITY_MEDIUM") echo "MEDIUM" ;;
  "$ERROR_SEVERITY_HIGH") echo "HIGH" ;;
  "$ERROR_SEVERITY_CRITICAL") echo "CRITICAL" ;;
  *) echo "UNKNOWN" ;;
  esac
}

# Log error with full context
# Parameters:
#   $1 - error context JSON
log_error_with_context() {
  local error_context="$1"

  # Extract key information for logging
  local exit_code severity_name failed_command error_message
  exit_code=$(echo "$error_context" | grep -o '"exit_code": [0-9]*' | cut -d' ' -f2 || echo "unknown")
  severity_name=$(echo "$error_context" | grep -o '"severity_name": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
  failed_command=$(echo "$error_context" | grep -o '"failed_command": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
  error_message=$(echo "$error_context" | grep -o '"error_message": "[^"]*"' | cut -d'"' -f4 || echo "unknown")

  # Log to main log
  log_error "[$severity_name] Error $exit_code: $error_message"
  log_debug "Failed command: $failed_command"

  # Log full context to error log file
  if [[ -w "$(dirname "$ERROR_LOG_FILE")" ]]; then
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") ERROR_CONTEXT: $error_context" >>"$ERROR_LOG_FILE"
  fi
}

# Initialize error recovery strategies
_init_error_recovery_strategies() {
  # File/directory recovery strategies
  ERROR_RECOVERY_STRATEGIES["file_not_found"]="create_missing_directories"
  ERROR_RECOVERY_STRATEGIES["permission_denied"]="fix_permissions"
  ERROR_RECOVERY_STRATEGIES["network_error"]="retry_with_backoff"
  ERROR_RECOVERY_STRATEGIES["timeout"]="retry_with_increased_timeout"
  ERROR_RECOVERY_STRATEGIES["configuration_error"]="reset_to_defaults"
  ERROR_RECOVERY_STRATEGIES["plugin_error"]="reload_plugin"
  ERROR_RECOVERY_STRATEGIES["dependency_error"]="install_dependencies"
  ERROR_RECOVERY_STRATEGIES["resource_exhausted"]="cleanup_resources"
}

# Attempt error recovery
# Parameters:
#   $1 - exit code
#   $2 - failed command
#   $3 - error context
# Returns:
#   0 - recovery successful
#   1 - recovery failed
attempt_error_recovery() {
  local exit_code="$1"
  local failed_command="$2"
  local error_context="$3"

  log_debug "Attempting error recovery for exit code: $exit_code"

  case "$exit_code" in
  "$ERROR_CODE_FILE_NOT_FOUND")
    return $(recover_file_not_found "$failed_command")
    ;;
  "$ERROR_CODE_PERMISSION_DENIED")
    return $(recover_permission_denied "$failed_command")
    ;;
  "$ERROR_CODE_NETWORK_ERROR")
    return $(recover_network_error "$failed_command")
    ;;
  "$ERROR_CODE_TIMEOUT")
    return $(recover_timeout "$failed_command")
    ;;
  "$ERROR_CODE_CONFIGURATION_ERROR")
    return $(recover_configuration_error "$failed_command")
    ;;
  "$ERROR_CODE_PLUGIN_ERROR")
    return $(recover_plugin_error "$failed_command")
    ;;
  "$ERROR_CODE_DEPENDENCY_ERROR")
    return $(recover_dependency_error "$failed_command")
    ;;
  "$ERROR_CODE_RESOURCE_EXHAUSTED")
    return $(recover_resource_exhausted "$failed_command")
    ;;
  *)
    log_debug "No recovery strategy available for exit code: $exit_code"
    return 1
    ;;
  esac
}

# Recovery strategy: File not found
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_file_not_found() {
  local failed_command="$1"

  # Extract file/directory path from command
  local path
  if [[ "$failed_command" =~ (mkdir|touch|cat|ls|cd).*[[:space:]]([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[2]}"
  elif [[ "$failed_command" =~ source[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[1]}"
  else
    log_debug "Cannot extract path from command: $failed_command"
    return 1
  fi

  # Try to create parent directories
  local parent_dir
  parent_dir=$(dirname "$path" 2>/dev/null)

  if [[ -n "$parent_dir" && "$parent_dir" != "." ]]; then
    log_debug "Creating missing directory: $parent_dir"
    if mkdir -p "$parent_dir" 2>/dev/null; then
      log_info "Successfully created missing directory: $parent_dir"
      return 0
    fi
  fi

  return 1
}

# Recovery strategy: Permission denied
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_permission_denied() {
  local failed_command="$1"

  # Extract file path from command
  local path
  if [[ "$failed_command" =~ (chmod|chown|mkdir|touch|cat|ls).*[[:space:]]([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[2]}"
  else
    log_debug "Cannot extract path from command: $failed_command"
    return 1
  fi

  # Try to fix common permission issues
  if [[ -e "$path" ]]; then
    log_debug "Attempting to fix permissions for: $path"

    # Try to make readable/writable for owner
    if chmod u+rw "$path" 2>/dev/null; then
      log_info "Successfully fixed permissions for: $path"
      return 0
    fi
  fi

  return 1
}

# Recovery strategy: Network error
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_network_error() {
  local failed_command="$1"

  log_debug "Attempting network error recovery with retry"

  # Simple retry with exponential backoff
  local max_retries=3
  local retry_delay=1

  for ((i = 1; i <= max_retries; i++)); do
    log_debug "Network retry attempt $i/$max_retries"
    sleep "$retry_delay"

    # Re-execute the command (simplified approach)
    if eval "$failed_command" 2>/dev/null; then
      log_info "Network recovery successful on attempt $i"
      return 0
    fi

    retry_delay=$((retry_delay * 2))
  done

  log_debug "Network recovery failed after $max_retries attempts"
  return 1
}

# Recovery strategy: Timeout
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_timeout() {
  local failed_command="$1"

  log_debug "Attempting timeout recovery with increased timeout"

  # Try with timeout command if available
  if command -v timeout >/dev/null 2>&1; then
    # Increase timeout and retry
    local extended_timeout=60

    if timeout "$extended_timeout" bash -c "$failed_command" 2>/dev/null; then
      log_info "Timeout recovery successful with extended timeout"
      return 0
    fi
  fi

  return 1
}

# Recovery strategy: Configuration error
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_configuration_error() {
  local failed_command="$1"

  log_debug "Attempting configuration error recovery"

  # Try to reload configuration
  if declare -f config_reload >/dev/null 2>&1; then
    if config_reload 2>/dev/null; then
      log_info "Configuration recovery successful - config reloaded"
      return 0
    fi
  fi

  return 1
}

# Recovery strategy: Plugin error
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_plugin_error() {
  local failed_command="$1"

  log_debug "Attempting plugin error recovery"

  # Extract plugin name from command
  local plugin_name
  if [[ "$failed_command" =~ ([a-zA-Z0-9_]+)_plugin_ ]]; then
    plugin_name="${BASH_REMATCH[1]}"

    log_debug "Attempting to reload plugin: $plugin_name"

    # Try to reload the plugin
    if declare -f plugin_load >/dev/null 2>&1; then
      if plugin_load "$plugin_name" 2>/dev/null; then
        log_info "Plugin recovery successful - reloaded: $plugin_name"
        return 0
      fi
    fi
  fi

  return 1
}

# Recovery strategy: Dependency error
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_dependency_error() {
  local failed_command="$1"

  log_debug "Attempting dependency error recovery"

  # Check for common missing commands and suggest installation
  local missing_cmd
  if [[ "$failed_command" =~ command[[:space:]]+not[[:space:]]+found.*([a-zA-Z0-9_-]+) ]]; then
    missing_cmd="${BASH_REMATCH[1]}"
  elif [[ "$failed_command" =~ ([a-zA-Z0-9_-]+):[[:space:]]+command[[:space:]]+not[[:space:]]+found ]]; then
    missing_cmd="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$missing_cmd" ]]; then
    log_warning "Missing dependency detected: $missing_cmd"
    log_info "Please install the required dependency: $missing_cmd"

    # Try to suggest installation command based on system
    suggest_dependency_installation "$missing_cmd"
  fi

  return 1 # Cannot auto-install dependencies
}

# Recovery strategy: Resource exhausted
# Parameters:
#   $1 - failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
recover_resource_exhausted() {
  local failed_command="$1"

  log_debug "Attempting resource exhaustion recovery"

  # Clean up temporary files
  if cleanup_temporary_files; then
    log_info "Cleaned up temporary files to free resources"

    # Retry the command
    if eval "$failed_command" 2>/dev/null; then
      log_info "Resource recovery successful after cleanup"
      return 0
    fi
  fi

  return 1
}

# Suggest dependency installation
# Parameters:
#   $1 - missing command
suggest_dependency_installation() {
  local missing_cmd="$1"

  # Detect package manager and suggest installation
  if command -v apt-get >/dev/null 2>&1; then
    log_info "Suggested fix: sudo apt-get install $missing_cmd"
  elif command -v yum >/dev/null 2>&1; then
    log_info "Suggested fix: sudo yum install $missing_cmd"
  elif command -v brew >/dev/null 2>&1; then
    log_info "Suggested fix: brew install $missing_cmd"
  elif command -v pacman >/dev/null 2>&1; then
    log_info "Suggested fix: sudo pacman -S $missing_cmd"
  else
    log_info "Please install the missing dependency: $missing_cmd"
  fi
}

# Handle critical errors
# Parameters:
#   $1 - error context
handle_critical_error() {
  local error_context="$1"

  log_critical "CRITICAL ERROR DETECTED - System may be unstable"

  # Extract critical information
  local failed_command
  failed_command=$(echo "$error_context" | grep -o '"failed_command": "[^"]*"' | cut -d'"' -f4 || echo "unknown")

  # Perform emergency cleanup
  emergency_cleanup

  # Create critical error report
  create_critical_error_report "$error_context"

  # Notify administrators immediately
  send_critical_error_notification "$error_context"
}

# Emergency cleanup for critical errors
emergency_cleanup() {
  log_debug "Performing emergency cleanup"

  # Stop any running background processes
  if [[ -f "$BASE_DIR/tmp/serversentry.pid" ]]; then
    local pid
    pid=$(cat "$BASE_DIR/tmp/serversentry.pid" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      log_debug "Stopping ServerSentry process: $pid"
      kill -TERM "$pid" 2>/dev/null || true
    fi
  fi

  # Clean up lock files
  rm -f "$BASE_DIR/tmp"/*.lock 2>/dev/null || true

  # Clean up temporary files
  cleanup_temporary_files
}

# Create critical error report
# Parameters:
#   $1 - error context
create_critical_error_report() {
  local error_context="$1"
  local report_file="$BASE_DIR/logs/critical_error_$(date +%Y%m%d_%H%M%S).json"

  # Create comprehensive error report
  local report="{
    \"report_type\": \"critical_error\",
    \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"serversentry_version\": \"$(get_serversentry_version)\",
    \"system_info\": $(get_system_info_json),
    \"error_context\": $error_context,
    \"error_statistics\": $(get_error_statistics_json),
    \"system_state\": $(get_system_state_json)
  }"

  if echo "$report" >"$report_file" 2>/dev/null; then
    log_info "Critical error report created: $report_file"
  else
    log_error "Failed to create critical error report"
  fi
}

# Send error notification
# Parameters:
#   $1 - error context
send_error_notification() {
  local error_context="$1"

  # Extract severity for notification filtering
  local severity
  severity=$(echo "$error_context" | grep -o '"severity": [0-9]*' | cut -d' ' -f2 || echo "1")

  # Only send notifications for medium severity and above
  if [[ "$severity" -ge "$ERROR_SEVERITY_MEDIUM" ]]; then
    log_debug "Sending error notification for severity level: $severity"

    # Use notification system if available
    if declare -f send_notification >/dev/null 2>&1; then
      local error_message
      error_message=$(echo "$error_context" | grep -o '"error_message": "[^"]*"' | cut -d'"' -f4 || echo "Unknown error")

      send_notification "error" "ServerSentry Error" "$error_message" 2>/dev/null || true
    fi
  fi
}

# Send critical error notification
# Parameters:
#   $1 - error context
send_critical_error_notification() {
  local error_context="$1"

  log_debug "Sending critical error notification"

  # Use notification system if available
  if declare -f send_notification >/dev/null 2>&1; then
    local error_message
    error_message=$(echo "$error_context" | grep -o '"error_message": "[^"]*"' | cut -d'"' -f4 || echo "Critical system error")

    send_notification "critical" "ServerSentry CRITICAL ERROR" "URGENT: $error_message" 2>/dev/null || true
  fi

  # Also try to send email if configured
  if declare -f send_email_notification >/dev/null 2>&1; then
    send_email_notification "critical" "ServerSentry CRITICAL ERROR" "$error_context" 2>/dev/null || true
  fi
}

# Cleanup temporary files
cleanup_temporary_files() {
  local temp_dirs=("$BASE_DIR/tmp" "/tmp/serversentry_$$")
  local cleaned=false

  for temp_dir in "${temp_dirs[@]}"; do
    if [[ -d "$temp_dir" ]]; then
      # Clean files older than 1 hour
      if find "$temp_dir" -type f -mmin +60 -delete 2>/dev/null; then
        cleaned=true
      fi
    fi
  done

  if [[ "$cleaned" == "true" ]]; then
    log_debug "Cleaned up temporary files"
    return 0
  else
    return 1
  fi
}

# Cleanup on error
cleanup_on_error() {
  log_debug "Running error cleanup procedures"

  # Clean up temporary files
  cleanup_temporary_files

  # Remove lock files
  rm -f "$BASE_DIR/tmp"/*.lock 2>/dev/null || true

  # Clean up plugin cache
  rm -f "$BASE_DIR/tmp/plugin_"* 2>/dev/null || true
}

# Generate error summary
generate_error_summary() {
  local total_errors="${ERROR_STATISTICS["total_errors"]}"
  local recovered_errors="${ERROR_STATISTICS["recovered_errors"]}"
  local critical_errors="${ERROR_STATISTICS["critical_errors"]}"

  if [[ "$total_errors" -gt 0 ]]; then
    log_info "Error Summary: Total: $total_errors, Recovered: $recovered_errors, Critical: $critical_errors"

    # Calculate recovery rate
    if [[ "$total_errors" -gt 0 ]]; then
      local recovery_rate
      recovery_rate=$(((recovered_errors * 100) / total_errors))
      log_info "Error recovery rate: ${recovery_rate}%"
    fi
  fi
}

# Get system info as JSON
get_system_info_json() {
  local hostname
  hostname=$(hostname 2>/dev/null || echo "unknown")

  local os_info
  os_info=$(uname -a 2>/dev/null || echo "unknown")

  local uptime
  uptime=$(uptime 2>/dev/null || echo "unknown")

  echo "{
    \"hostname\": \"$hostname\",
    \"os_info\": \"$(echo "$os_info" | sed 's/"/\\"/g')\",
    \"uptime\": \"$(echo "$uptime" | sed 's/"/\\"/g')\",
    \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
  }"
}

# Get error statistics as JSON
get_error_statistics_json() {
  echo "{
    \"total_errors\": ${ERROR_STATISTICS["total_errors"]},
    \"recovered_errors\": ${ERROR_STATISTICS["recovered_errors"]},
    \"critical_errors\": ${ERROR_STATISTICS["critical_errors"]},
    \"last_error_time\": ${ERROR_STATISTICS["last_error_time"]}
  }"
}

# Get system state as JSON
get_system_state_json() {
  local disk_usage
  disk_usage=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' || echo "unknown")

  local memory_usage
  memory_usage=$(free -m 2>/dev/null | awk 'NR==2{printf "%.1f%%", $3*100/$2}' || echo "unknown")

  local load_average
  load_average=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^[[:space:]]*//' || echo "unknown")

  echo "{
    \"disk_usage\": \"$disk_usage\",
    \"memory_usage\": \"$memory_usage\",
    \"load_average\": \"$(echo "$load_average" | sed 's/"/\\"/g')\",
    \"process_count\": $(ps aux 2>/dev/null | wc -l || echo "0")
  }"
}

# Get ServerSentry version
get_serversentry_version() {
  if [[ -f "$BASE_DIR/VERSION" ]]; then
    cat "$BASE_DIR/VERSION" 2>/dev/null || echo "unknown"
  else
    echo "2.0.0"
  fi
}

# Utility function: Throw custom error
# Parameters:
#   $1 - error code
#   $2 - error message
#   $3 - severity (optional, defaults to medium)
throw_error() {
  local error_code="$1"
  local error_message="$2"
  local severity="${3:-$ERROR_SEVERITY_MEDIUM}"

  log_error "$error_message"

  # Create custom error context
  local error_context
  error_context=$(create_error_context "$error_code" "${BASH_LINENO[0]}" "${BASH_LINENO[0]}" "$error_message" "${FUNCNAME[*]}" "$severity")

  # Log with context
  log_error_with_context "$error_context"

  # Send notification if severity is high enough
  if [[ "$severity" -ge "$ERROR_SEVERITY_HIGH" ]]; then
    send_error_notification "$error_context"
  fi

  exit "$error_code"
}

# Utility function: Safe command execution with error handling
# Parameters:
#   $1 - command to execute
#   $2 - error message (optional)
#   $3 - recovery strategy (optional)
# Returns:
#   Command exit code
safe_execute() {
  local command="$1"
  local error_message="${2:-Failed to execute command}"
  local recovery_strategy="${3:-}"

  log_debug "Safely executing: $command"

  # Execute command and capture result
  local exit_code=0
  eval "$command" || exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    log_error "$error_message: $command (exit code: $exit_code)"

    # Attempt recovery if strategy provided
    if [[ -n "$recovery_strategy" ]] && declare -f "$recovery_strategy" >/dev/null 2>&1; then
      log_debug "Attempting recovery with strategy: $recovery_strategy"
      if "$recovery_strategy" "$command"; then
        log_info "Recovery successful, retrying command"
        eval "$command" || exit_code=$?
      fi
    fi
  fi

  return "$exit_code"
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f error_handling_init
  export -f throw_error
  export -f safe_execute
  export -f get_user_friendly_error_message
  export -f cleanup_temporary_files
fi
