#!/usr/bin/env bash
#
# ServerSentry v2 - Logging System (Modular)
#
# This module orchestrates all logging components through modular architecture

# Prevent multiple sourcing
if [[ "${LOGGING_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
LOGGING_MODULE_LOADED=true
export LOGGING_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# This removes the circular dependency between logging and error handling

# Source modular logging components using standardized paths (if they exist)
if [[ -f "${SERVERSENTRY_CORE_DIR}/logging/config.sh" ]]; then
  source "${SERVERSENTRY_CORE_DIR}/logging/config.sh"
fi

if [[ -f "${SERVERSENTRY_CORE_DIR}/logging/core.sh" ]]; then
  source "${SERVERSENTRY_CORE_DIR}/logging/core.sh"
fi

if [[ -f "${SERVERSENTRY_CORE_DIR}/logging/specialized.sh" ]]; then
  source "${SERVERSENTRY_CORE_DIR}/logging/specialized.sh"
fi

if [[ -f "${SERVERSENTRY_CORE_DIR}/logging/management.sh" ]]; then
  source "${SERVERSENTRY_CORE_DIR}/logging/management.sh"
fi

# Function: logging_init
# Description: Initialize the complete logging system with all modules
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   logging_init
# Dependencies:
#   - logging_config_init
#   - logging_core_init
#   - logging_specialized_init
#   - logging_management_init
logging_init() {
  # Initialize configuration first
  if ! logging_config_init; then
    echo "Error: Failed to initialize logging configuration" >&2
    return 1
  fi

  # Initialize core logging functionality
  if ! logging_core_init; then
    echo "Error: Failed to initialize core logging" >&2
    return 1
  fi

  # Initialize specialized logging
  if ! logging_specialized_init; then
    echo "Warning: Failed to initialize specialized logging" >&2
  fi

  # Initialize log management
  if ! logging_management_init; then
    echo "Warning: Failed to initialize log management" >&2
  fi

  # Log system initialization (only if not in quiet mode)
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le "${LOG_LEVEL_DEBUG:-0}" ]]; then
    log_debug "Modular logging system initialized successfully" "logging"
    log_debug "Main log: ${LOG_FILE}" "logging"
    log_debug "Log level: $(logging_get_level)" "logging"
    log_debug "Format: ${LOG_FORMAT:-standard}" "logging"
  fi

  return 0
}

# Backward compatibility aliases for original function names
alias _init_log_file=_logging_init_log_file 2>/dev/null || true
alias _load_logging_config=logging_load_config 2>/dev/null || true
alias _init_specialized_logs=logging_specialized_init 2>/dev/null || true
alias logging_check_size=logging_check_size 2>/dev/null || true
alias logging_cleanup_archives=logging_cleanup_archives 2>/dev/null || true
alias _log=logging_core_log 2>/dev/null || true

# Backward compatibility function: format_bytes
# Description: Format byte count into human-readable format (backward compatibility)
# Parameters:
#   $1 (numeric): byte count
# Returns:
#   Formatted size string via stdout
# Example:
#   size=$(format_bytes 1048576)
# Dependencies:
#   - logging_format_bytes
format_bytes() {
  logging_format_bytes "$@"
}

# Export all logging functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration function
  export -f logging_init
  export -f format_bytes

  # Export core logging functions (already exported by modules, but ensure availability)
  export -f logging_set_level
  export -f logging_get_level
  export -f log_debug
  export -f log_info
  export -f log_warning
  export -f log_error
  export -f log_critical
  export -f log_with_context

  # Export specialized logging functions
  export -f log_performance
  export -f log_audit
  export -f log_security
  export -f log_plugin
  export -f log_config
  export -f log_notification
  export -f log_system
  export -f log_network

  # Export management functions
  export -f logging_rotate
  export -f logging_cleanup_archives
  export -f logging_check_size
  export -f logging_check_health
  export -f logging_get_status
  export -f logging_format_bytes
  export -f logging_auto_rotate

  # Export configuration functions
  export -f logging_load_config
  export -f logging_set_component_level
  export -f logging_get_component_level
  export -f logging_validate_config
  export -f logging_get_config_summary
fi

# Initialize logging system if not already initialized
if [[ "${LOGGING_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if logging_init; then
    export LOGGING_SYSTEM_INITIALIZED=true
    log_debug "Logging system auto-initialized" "logging"
  else
    echo "Warning: Failed to auto-initialize logging system" >&2
  fi
fi
