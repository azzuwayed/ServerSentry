#!/usr/bin/env bash
#
# ServerSentry v2 - Error Handling System (Modular)
#
# This module orchestrates all error handling components through modular architecture

# Source core utilities first
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
else
  echo "Error: Core error utilities not found" >&2
  exit 1
fi

# Source modular error handling components
source "${BASE_DIR}/lib/core/error/handlers.sh"
source "${BASE_DIR}/lib/core/error/recovery.sh"
source "${BASE_DIR}/lib/core/error/context.sh"
source "${BASE_DIR}/lib/core/error/notification.sh"

# Error code constants for backward compatibility
readonly ERROR_CODE_SUCCESS=0
readonly ERROR_CODE_GENERAL=1
readonly ERROR_CODE_INVALID_ARGUMENT=2
readonly ERROR_CODE_FILE_NOT_FOUND=3
readonly ERROR_CODE_PERMISSION_DENIED=4
readonly ERROR_CODE_NETWORK_ERROR=5
readonly ERROR_CODE_TIMEOUT=6
readonly ERROR_CODE_CONFIGURATION_ERROR=7
readonly ERROR_CODE_PLUGIN_ERROR=8
readonly ERROR_CODE_DEPENDENCY_ERROR=9
readonly ERROR_CODE_RESOURCE_EXHAUSTED=10
readonly ERROR_CODE_CRITICAL_SYSTEM_ERROR=11

# Error severity constants for backward compatibility
readonly ERROR_SEVERITY_LOW=1
readonly ERROR_SEVERITY_MEDIUM=2
readonly ERROR_SEVERITY_HIGH=3
readonly ERROR_SEVERITY_CRITICAL=4

# Function: error_handling_init
# Description: Initialize the complete error handling system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   error_handling_init
# Dependencies:
#   - error_handlers_init
error_handling_init() {
  echo "DEBUG: Initializing modular error handling system" >&2

  # Initialize error handlers (traps, statistics, etc.)
  if ! error_handlers_init; then
    echo "Error: Failed to initialize error handlers" >&2
    return 1
  fi

  # Set global error handling configuration
  ERROR_HANDLING_ENABLED="${ERROR_HANDLING_ENABLED:-true}"
  ERROR_RECOVERY_ENABLED="${ERROR_RECOVERY_ENABLED:-true}"
  ERROR_NOTIFICATION_ENABLED="${ERROR_NOTIFICATION_ENABLED:-true}"
  ERROR_STACK_TRACE_ENABLED="${ERROR_STACK_TRACE_ENABLED:-true}"
  ERROR_NOTIFICATION_THRESHOLD="${ERROR_NOTIFICATION_THRESHOLD:-2}"

  # Set default log file if not configured
  ERROR_LOG_FILE="${ERROR_LOG_FILE:-${BASE_DIR}/logs/error.log}"

  echo "INFO: Modular error handling system initialized successfully" >&2
  return 0
}

# Function: throw_error
# Description: Throw an error with specified code and message (backward compatibility)
# Parameters:
#   $1 (numeric): error code
#   $2 (string): error message
#   $3 (string): failed command (optional)
# Returns:
#   Exits with specified error code
# Example:
#   throw_error 3 "File not found" "cat /missing/file"
# Dependencies:
#   - util_error_validate_input
#   - error_create_context
throw_error() {
  local error_code="$1"
  local error_message="$2"
  local failed_command="${3:-unknown}"

  # Validate inputs
  if ! util_error_validate_input "$error_code" "error_code" "numeric"; then
    echo "Error: Invalid error code in throw_error" >&2
    exit 1
  fi

  if ! util_error_validate_input "$error_message" "error_message" "required"; then
    echo "Error: Invalid error message in throw_error" >&2
    exit 1
  fi

  # Determine severity
  local severity
  severity=$(error_determine_severity "$error_code" "$failed_command")

  # Create error context
  local error_context
  error_context=$(error_create_context "$error_code" "${BASH_LINENO[0]}" "${BASH_LINENO[0]}" "$failed_command" "${FUNCNAME[*]}" "$severity")

  # Log the error
  if ! error_log_with_context "$error_context"; then
    echo "Error: Failed to log error context" >&2
  fi

  # Send notification if enabled
  if [[ "${ERROR_NOTIFICATION_ENABLED:-true}" == "true" ]]; then
    if ! error_send_notification "$error_context"; then
      echo "Warning: Failed to send error notification" >&2
    fi
  fi

  # Handle critical errors
  if [[ "$severity" -eq "$ERROR_SEVERITY_CRITICAL" ]]; then
    if ! error_handle_critical "$error_context"; then
      echo "Error: Failed to handle critical error" >&2
    fi
  fi

  # Exit with the specified error code
  exit "$error_code"
}

# Function: safe_execute
# Description: Execute command safely with error handling (backward compatibility)
# Parameters:
#   $1 (string): command to execute
#   $2 (string): error message on failure (optional)
#   $3 (numeric): timeout in seconds (optional)
# Returns:
#   0 - command succeeded
#   1 - command failed
# Example:
#   safe_execute "ls /tmp" "Failed to list directory"
# Dependencies:
#   - util_error_safe_execute
safe_execute() {
  local command="$1"
  local error_message="${2:-Command execution failed}"
  local timeout="${3:-30}"

  # Use the enhanced safe execute from utils
  util_error_safe_execute "$command" "$error_message" "" "$timeout"
}

# Function: cleanup_temporary_files
# Description: Clean up temporary files (backward compatibility)
# Parameters: None
# Returns:
#   0 - cleanup successful
#   1 - cleanup failed
# Example:
#   cleanup_temporary_files
# Dependencies:
#   - _cleanup_temporary_files from recovery module
cleanup_temporary_files() {
  echo "DEBUG: Cleaning up temporary files" >&2

  # Use the internal cleanup function from recovery module
  if declare -f _cleanup_temporary_files >/dev/null 2>&1; then
    _cleanup_temporary_files
  else
    # Fallback cleanup
    local temp_dirs=("/tmp" "${BASE_DIR}/tmp")
    for temp_dir in "${temp_dirs[@]}"; do
      if [[ -d "$temp_dir" && -w "$temp_dir" ]]; then
        find "$temp_dir" -name "serversentry_*" -type f -mtime +1 -delete 2>/dev/null
      fi
    done
  fi
}

# Function: cleanup_on_error
# Description: Perform cleanup when an error occurs (backward compatibility)
# Parameters: None
# Returns:
#   0 - cleanup successful
#   1 - cleanup failed
# Example:
#   cleanup_on_error
# Dependencies:
#   - cleanup_temporary_files
cleanup_on_error() {
  echo "DEBUG: Performing error cleanup" >&2

  # Clean temporary files
  if ! cleanup_temporary_files; then
    echo "WARNING: Failed to clean temporary files during error cleanup" >&2
  fi

  # Sync filesystems if possible
  if command -v sync >/dev/null 2>&1; then
    sync 2>/dev/null || true
  fi

  return 0
}

# Function: error_cleanup_on_exit
# Description: Cleanup function for exit handler (backward compatibility)
# Parameters: None
# Returns:
#   0 - cleanup successful
#   1 - cleanup failed
# Example:
#   error_cleanup_on_exit
# Dependencies:
#   - cleanup_on_error
error_cleanup_on_exit() {
  cleanup_on_error
}

# Function: generate_error_summary
# Description: Generate error summary (backward compatibility)
# Parameters: None
# Returns:
#   Error summary via stdout
# Example:
#   summary=$(generate_error_summary)
# Dependencies:
#   - error_get_error_statistics_json
generate_error_summary() {
  local stats
  stats=$(error_get_error_statistics_json)

  if [[ "$stats" != "{}" ]]; then
    echo "Error Summary:"
    echo "$stats" | sed 's/[{}"]//g; s/,/\n/g; s/:/: /g'
  else
    echo "No error statistics available"
  fi
}

# Function: error_generate_summary
# Description: Generate error summary (backward compatibility alias)
# Parameters: None
# Returns:
#   Error summary via stdout
# Example:
#   error_generate_summary
# Dependencies:
#   - generate_error_summary
error_generate_summary() {
  generate_error_summary
}

# Function: get_system_state_json
# Description: Get system state in JSON format (backward compatibility)
# Parameters: None
# Returns:
#   System state JSON via stdout
# Example:
#   state=$(get_system_state_json)
# Dependencies:
#   - error_get_system_info_json
get_system_state_json() {
  error_get_system_info_json
}

# Function: get_error_statistics_json
# Description: Get error statistics in JSON format (backward compatibility)
# Parameters: None
# Returns:
#   Error statistics JSON via stdout
# Example:
#   stats=$(get_error_statistics_json)
# Dependencies:
#   - error_get_error_statistics_json
get_error_statistics_json() {
  error_get_error_statistics_json
}

# Function: get_serversentry_version
# Description: Get ServerSentry version (backward compatibility)
# Parameters: None
# Returns:
#   Version string via stdout
# Example:
#   version=$(get_serversentry_version)
# Dependencies:
#   - error_get_serversentry_version
get_serversentry_version() {
  error_get_serversentry_version
}

# Backward compatibility aliases for function names
alias error_handling_init=error_handlers_init 2>/dev/null || true
alias error_trap_handler=error_trap_handler 2>/dev/null || true
alias error_exit_handler=error_exit_handler 2>/dev/null || true
alias determine_error_severity=error_determine_severity 2>/dev/null || true
alias create_error_context=error_create_context 2>/dev/null || true
alias generate_stack_trace=error_generate_stack_trace 2>/dev/null || true
alias get_user_friendly_error_message=error_get_user_friendly_message 2>/dev/null || true
alias get_severity_name=error_get_severity_name 2>/dev/null || true
alias log_error_with_context=error_log_with_context 2>/dev/null || true
alias attempt_error_recovery=error_attempt_recovery 2>/dev/null || true
alias recover_file_not_found=error_recover_file_not_found 2>/dev/null || true
alias recover_permission_denied=error_recover_permission_denied 2>/dev/null || true
alias recover_network_error=error_recover_network_error 2>/dev/null || true
alias recover_timeout=error_recover_timeout 2>/dev/null || true
alias recover_configuration_error=error_recover_configuration_error 2>/dev/null || true
alias recover_plugin_error=error_recover_plugin_error 2>/dev/null || true
alias recover_dependency_error=error_recover_dependency_error 2>/dev/null || true
alias recover_resource_exhausted=error_recover_resource_exhausted 2>/dev/null || true
alias suggest_dependency_installation=error_suggest_dependency_installation 2>/dev/null || true
alias handle_critical_error=error_handle_critical 2>/dev/null || true
alias emergency_cleanup=error_emergency_cleanup 2>/dev/null || true
alias create_critical_error_report=error_create_critical_report 2>/dev/null || true
alias send_error_notification=error_send_notification 2>/dev/null || true
alias send_critical_error_notification=error_send_critical_notification 2>/dev/null || true

# Export all functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration functions
  export -f error_handling_init
  export -f throw_error
  export -f safe_execute
  export -f cleanup_temporary_files
  export -f cleanup_on_error
  export -f error_cleanup_on_exit
  export -f generate_error_summary
  export -f error_generate_summary
  export -f get_system_state_json
  export -f get_error_statistics_json
  export -f get_serversentry_version

  # Export constants
  export ERROR_CODE_SUCCESS ERROR_CODE_GENERAL ERROR_CODE_INVALID_ARGUMENT
  export ERROR_CODE_FILE_NOT_FOUND ERROR_CODE_PERMISSION_DENIED ERROR_CODE_NETWORK_ERROR
  export ERROR_CODE_TIMEOUT ERROR_CODE_CONFIGURATION_ERROR ERROR_CODE_PLUGIN_ERROR
  export ERROR_CODE_DEPENDENCY_ERROR ERROR_CODE_RESOURCE_EXHAUSTED ERROR_CODE_CRITICAL_SYSTEM_ERROR
  export ERROR_SEVERITY_LOW ERROR_SEVERITY_MEDIUM ERROR_SEVERITY_HIGH ERROR_SEVERITY_CRITICAL
fi

# Initialize error handling system if not already initialized
if [[ "${ERROR_HANDLING_INITIALIZED:-false}" != "true" ]]; then
  if error_handling_init; then
    export ERROR_HANDLING_INITIALIZED=true
    echo "DEBUG: Error handling system auto-initialized" >&2
  else
    echo "Warning: Failed to auto-initialize error handling system" >&2
  fi
fi
