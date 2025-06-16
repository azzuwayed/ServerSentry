#!/usr/bin/env bash
#
# ServerSentry v2 - Error Handlers Module
#
# This module provides error trap handlers, exit handlers, and core error processing

# Function: error_handlers_init
# Description: Initialize error handling system with comprehensive trap setup
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   error_handlers_init
# Dependencies:
#   - util_error_validate_input
#   - ERROR_HANDLING_ENABLED variable
error_handlers_init() {
  log_debug "Initializing error handling system" "error"

  # Validate that required directories exist
  local error_log_dir
  error_log_dir=$(dirname "${ERROR_LOG_FILE:-${BASE_DIR}/logs/error.log}")
  if ! util_error_validate_input "$error_log_dir" "error_log_dir" "directory"; then
    if ! mkdir -p "$error_log_dir" 2>/dev/null; then
      util_error_log_with_context "Failed to create error log directory: $error_log_dir" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "error"
      return 1
    fi
  fi

  # Set up error traps if enabled
  if [[ "${ERROR_HANDLING_ENABLED:-true}" == "true" ]]; then
    trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
    trap 'error_exit_handler $?' EXIT
    set -eE # Exit on error and inherit ERR trap
    log_debug "Error traps enabled successfully" "error"
  fi

  # Initialize error recovery strategies
  if ! util_error_safe_execute "_init_error_recovery_strategies" "Failed to initialize error recovery strategies" "" 1; then
    util_error_log_with_context "Error recovery initialization failed" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_WARNING" "error"
  fi

  # Initialize error statistics
  if ! _init_error_statistics; then
    util_error_log_with_context "Error statistics initialization failed" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_WARNING" "error"
  fi

  log_debug "Error handling system initialized successfully" "error"
  return 0
}

# Function: error_trap_handler
# Description: Main error trap handler with enhanced context and recovery
# Parameters:
#   $1 (numeric): exit code
#   $2 (numeric): line number
#   $3 (numeric): bash line number
#   $4 (string): command that failed
#   $5 (string): function stack
# Returns:
#   0 - error handled successfully
#   1 - error handling failed
# Example:
#   trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
# Dependencies:
#   - util_error_validate_input
#   - error_determine_severity
#   - error_create_context
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

  # Validate input parameters
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    echo "Error: Invalid exit code in error_trap_handler" >&2
    return 1
  fi

  # Update error statistics
  _update_error_statistics "total_errors"

  # Determine error severity
  local severity
  if ! severity=$(error_determine_severity "$exit_code" "$failed_command"); then
    severity="$ERROR_SEVERITY_MEDIUM"
    log_warning "Failed to determine error severity, using default: MEDIUM" "error"
  fi

  # Create comprehensive error context
  local error_context
  if ! error_context=$(error_create_context "$exit_code" "$line_number" "$bash_line_number" "$failed_command" "$function_stack" "$severity"); then
    util_error_log_with_context "Failed to create error context" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "error"
    return 1
  fi

  # Log the error with full context
  if ! error_log_with_context "$error_context"; then
    echo "Error: Failed to log error context" >&2
  fi

  # Attempt error recovery if enabled
  if [[ "${ERROR_RECOVERY_ENABLED:-true}" == "true" ]]; then
    if error_attempt_recovery "$exit_code" "$failed_command" "$error_context"; then
      _update_error_statistics "recovered_errors"
      log_info "Error recovery successful for: $failed_command" "error"

      # Re-enable error trap and continue
      trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
      return 0
    fi
  fi

  # Handle critical errors
  if [[ "$severity" -eq "$ERROR_SEVERITY_CRITICAL" ]]; then
    _update_error_statistics "critical_errors"
    if ! error_handle_critical "$error_context"; then
      echo "Error: Failed to handle critical error" >&2
    fi
  fi

  # Send error notification if enabled
  if [[ "${ERROR_NOTIFICATION_ENABLED:-true}" == "true" ]]; then
    if ! error_send_notification "$error_context"; then
      log_warning "Failed to send error notification" "error"
    fi
  fi

  # Re-enable error trap
  trap 'error_trap_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}"' ERR
  return 0
}

# Function: error_exit_handler
# Description: Exit handler for cleanup and error summary generation
# Parameters:
#   $1 (numeric): exit code
# Returns:
#   0 - cleanup successful
#   1 - cleanup failed
# Example:
#   trap 'error_exit_handler $?' EXIT
# Dependencies:
#   - util_error_validate_input
#   - error_generate_summary
error_exit_handler() {
  local exit_code="$1"

  # Validate input
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    echo "Error: Invalid exit code in error_exit_handler" >&2
    return 1
  fi

  # Only run cleanup on non-zero exit codes
  if [[ "$exit_code" -ne 0 ]]; then
    log_debug "Running error exit cleanup (exit code: $exit_code)" "error"

    # Generate error summary with error handling
    if ! util_error_safe_execute "error_generate_summary" "Failed to generate error summary" "" 1; then
      log_warning "Error summary generation failed" "error"
    fi

    # Cleanup temporary files and resources
    if ! util_error_safe_execute "error_cleanup_on_exit" "Failed to cleanup on exit" "" 1; then
      log_warning "Exit cleanup failed" "error"
    fi

    log_debug "Error exit cleanup completed" "error"
  fi

  return 0
}

# Function: error_determine_severity
# Description: Determine error severity based on exit code and command with enhanced logic
# Parameters:
#   $1 (numeric): exit code
#   $2 (string): failed command
# Returns:
#   Severity level via stdout (1-4)
# Example:
#   severity=$(error_determine_severity 1 "rm -rf /tmp/file")
# Dependencies:
#   - util_error_validate_input
#   - ERROR_SEVERITY_* constants
error_determine_severity() {
  local exit_code="$1"
  local failed_command="$2"

  # Validate inputs
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    echo "$ERROR_SEVERITY_MEDIUM"
    return 1
  fi

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    echo "$ERROR_SEVERITY_MEDIUM"
    return 1
  fi

  # Critical system errors - highest priority
  if [[ "$exit_code" -eq "${ERROR_CODE_CRITICAL_SYSTEM_ERROR:-11}" ]] ||
    [[ "$failed_command" =~ (rm|mv|cp).*(-r|-rf).*/$ ]] ||
    [[ "$failed_command" =~ sudo.*rm ]] ||
    [[ "$failed_command" =~ shutdown|reboot|halt ]] ||
    [[ "$failed_command" =~ mkfs|fdisk|parted ]]; then
    echo "$ERROR_SEVERITY_CRITICAL"
    return 0
  fi

  # High severity errors
  if [[ "$exit_code" -eq "${ERROR_CODE_PERMISSION_DENIED:-4}" ]] ||
    [[ "$exit_code" -eq "${ERROR_CODE_RESOURCE_EXHAUSTED:-10}" ]] ||
    [[ "$exit_code" -eq "${ERROR_CODE_CONFIGURATION_ERROR:-7}" ]] ||
    [[ "$failed_command" =~ (plugin|notification|config) ]] ||
    [[ "$failed_command" =~ chmod.*-R ]] ||
    [[ "$failed_command" =~ chown.*-R ]]; then
    echo "$ERROR_SEVERITY_HIGH"
    return 0
  fi

  # Medium severity errors
  if [[ "$exit_code" -eq "${ERROR_CODE_NETWORK_ERROR:-5}" ]] ||
    [[ "$exit_code" -eq "${ERROR_CODE_TIMEOUT:-6}" ]] ||
    [[ "$exit_code" -eq "${ERROR_CODE_PLUGIN_ERROR:-8}" ]] ||
    [[ "$exit_code" -eq "${ERROR_CODE_DEPENDENCY_ERROR:-9}" ]] ||
    [[ "$failed_command" =~ (curl|wget|ssh|scp) ]]; then
    echo "$ERROR_SEVERITY_MEDIUM"
    return 0
  fi

  # Default to low severity
  echo "$ERROR_SEVERITY_LOW"
  return 0
}

# Function: error_get_severity_name
# Description: Convert severity level to human-readable name
# Parameters:
#   $1 (numeric): severity level (1-4)
# Returns:
#   Severity name via stdout
# Example:
#   name=$(error_get_severity_name 3)
# Dependencies:
#   - util_error_validate_input
#   - ERROR_SEVERITY_* constants
error_get_severity_name() {
  local severity="$1"

  if ! util_error_validate_input "$severity" "severity" "numeric"; then
    echo "UNKNOWN"
    return 1
  fi

  case "$severity" in
  "${ERROR_SEVERITY_LOW:-1}") echo "LOW" ;;
  "${ERROR_SEVERITY_MEDIUM:-2}") echo "MEDIUM" ;;
  "${ERROR_SEVERITY_HIGH:-3}") echo "HIGH" ;;
  "${ERROR_SEVERITY_CRITICAL:-4}") echo "CRITICAL" ;;
  *) echo "UNKNOWN" ;;
  esac

  return 0
}

# Function: error_get_user_friendly_message
# Description: Generate user-friendly error messages with enhanced context
# Parameters:
#   $1 (numeric): exit code
#   $2 (string): failed command
# Returns:
#   User-friendly error message via stdout
# Example:
#   message=$(error_get_user_friendly_message 2 "cat /nonexistent")
# Dependencies:
#   - util_error_validate_input
#   - ERROR_CODE_* constants
error_get_user_friendly_message() {
  local exit_code="$1"
  local failed_command="$2"

  # Validate inputs
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    echo "Unknown error occurred"
    return 1
  fi

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    echo "Error occurred in unknown command"
    return 1
  fi

  case "$exit_code" in
  "${ERROR_CODE_SUCCESS:-0}")
    echo "Operation completed successfully"
    ;;
  "${ERROR_CODE_GENERAL:-1}")
    echo "A general error occurred while executing: $failed_command"
    ;;
  "${ERROR_CODE_INVALID_ARGUMENT:-2}")
    echo "Invalid argument or parameter provided to: $failed_command"
    ;;
  "${ERROR_CODE_FILE_NOT_FOUND:-3}")
    echo "Required file or directory not found for: $failed_command"
    ;;
  "${ERROR_CODE_PERMISSION_DENIED:-4}")
    echo "Permission denied while executing: $failed_command. Check file permissions and user privileges."
    ;;
  "${ERROR_CODE_NETWORK_ERROR:-5}")
    echo "Network connectivity issue encountered during: $failed_command"
    ;;
  "${ERROR_CODE_TIMEOUT:-6}")
    echo "Operation timed out while executing: $failed_command"
    ;;
  "${ERROR_CODE_CONFIGURATION_ERROR:-7}")
    echo "Configuration error detected in: $failed_command. Please check your configuration files."
    ;;
  "${ERROR_CODE_PLUGIN_ERROR:-8}")
    echo "Plugin error occurred during: $failed_command. Check plugin configuration and dependencies."
    ;;
  "${ERROR_CODE_DEPENDENCY_ERROR:-9}")
    echo "Missing or incompatible dependency for: $failed_command"
    ;;
  "${ERROR_CODE_RESOURCE_EXHAUSTED:-10}")
    echo "System resources exhausted during: $failed_command. Check disk space, memory, and CPU usage."
    ;;
  "${ERROR_CODE_CRITICAL_SYSTEM_ERROR:-11}")
    echo "CRITICAL: System error detected in: $failed_command. Immediate attention required."
    ;;
  *)
    echo "Unknown error (code: $exit_code) occurred while executing: $failed_command"
    ;;
  esac

  return 0
}

# Internal function: Initialize error statistics
_init_error_statistics() {
  if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative array support
    declare -gA ERROR_STATISTICS=(
      ["total_errors"]=0
      ["recovered_errors"]=0
      ["critical_errors"]=0
      ["last_error_time"]=0
    )
  else
    # Fallback for older bash versions
    ERROR_STATISTICS_total_errors=0
    ERROR_STATISTICS_recovered_errors=0
    ERROR_STATISTICS_critical_errors=0
    ERROR_STATISTICS_last_error_time=0
  fi
  return 0
}

# Internal function: Update error statistics
_update_error_statistics() {
  local stat_name="$1"

  if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative array support
    ERROR_STATISTICS["$stat_name"]=$((${ERROR_STATISTICS["$stat_name"]} + 1))
    ERROR_STATISTICS["last_error_time"]=$(date +%s)
  else
    # Fallback for older bash versions
    case "$stat_name" in
    "total_errors")
      ERROR_STATISTICS_total_errors=$((ERROR_STATISTICS_total_errors + 1))
      ;;
    "recovered_errors")
      ERROR_STATISTICS_recovered_errors=$((ERROR_STATISTICS_recovered_errors + 1))
      ;;
    "critical_errors")
      ERROR_STATISTICS_critical_errors=$((ERROR_STATISTICS_critical_errors + 1))
      ;;
    esac
    ERROR_STATISTICS_last_error_time=$(date +%s)
  fi
  return 0
}

# Internal function: Initialize error recovery strategies
_init_error_recovery_strategies() {
  if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative array support
    declare -gA ERROR_RECOVERY_STRATEGIES=(
      ["file_not_found"]="create_missing_directories"
      ["permission_denied"]="fix_permissions"
      ["network_error"]="retry_with_backoff"
      ["timeout"]="retry_with_increased_timeout"
      ["configuration_error"]="reset_to_defaults"
      ["plugin_error"]="reload_plugin"
      ["dependency_error"]="install_dependencies"
      ["resource_exhausted"]="cleanup_resources"
    )
  else
    # Fallback for older bash versions - strategies will be handled in recovery module
    log_debug "Using fallback error recovery strategies for older bash" "error"
  fi
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f error_handlers_init
  export -f error_trap_handler
  export -f error_exit_handler
  export -f error_determine_severity
  export -f error_get_severity_name
  export -f error_get_user_friendly_message
fi
