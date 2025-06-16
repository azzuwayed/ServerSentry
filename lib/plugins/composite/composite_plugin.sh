#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check System (Modular)
#
# This module orchestrates all composite check components through modular architecture

# Prevent multiple sourcing
if [[ "${COMPOSITE_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPOSITE_MODULE_LOADED=true
export COMPOSITE_MODULE_LOADED

# Load ServerSentry environment
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

# Source core utilities first
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Check if logging functions exist, if not try to source or provide fallbacks
if ! declare -f log_debug >/dev/null 2>&1; then
  if [[ -f "${BASE_DIR}/lib/core/logging.sh" ]]; then
    source "${BASE_DIR}/lib/core/logging.sh"
  fi

  # If still not available, provide fallback functions
  if ! declare -f log_debug >/dev/null 2>&1; then
    log_debug() { echo "[DEBUG] $1" >&2; }
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
  fi
fi

# Source modular composite components
source "${BASE_DIR}/lib/plugins/composite/composite/config.sh"
source "${BASE_DIR}/lib/plugins/composite/composite/evaluator.sh"
source "${BASE_DIR}/lib/plugins/composite/composite/executor.sh"

# Composite check configuration
COMPOSITE_CONFIG_DIR="${BASE_DIR}/config/composite"
COMPOSITE_RESULTS_DIR="${BASE_DIR}/logs/composite"

# Function: composite_system_init
# Description: Initialize the complete composite check system with all modules
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   composite_system_init
# Dependencies:
#   - composite_config_init
composite_system_init() {
  log_debug "Initializing modular composite check system" "composite"

  # Initialize configuration management first
  if ! composite_config_init; then
    log_error "Failed to initialize composite configuration" "composite"
    return 1
  fi

  # Log system initialization
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le "${LOG_LEVEL_DEBUG:-0}" ]]; then
    log_debug "Modular composite check system initialized successfully" "composite"
    log_debug "Config dir: ${COMPOSITE_CONFIG_DIR}" "composite"
    log_debug "Results dir: ${COMPOSITE_RESULTS_DIR}" "composite"
  fi

  return 0
}

# Note: Backward compatibility functions are now handled by core stubs
# The core composite.sh provides stub implementations that delegate to this plugin
# when available, eliminating function name conflicts.

# Export all composite functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration function
  export -f composite_system_init

  # Note: Backward compatibility functions are exported by core stubs

  # Export modular functions (already exported by modules, but ensure availability)
  export -f composite_config_init
  export -f composite_config_create_defaults
  export -f composite_config_parse
  export -f composite_config_list
  export -f composite_config_validate

  export -f composite_evaluate_rule
  export -f composite_get_triggered_conditions

  export -f composite_is_in_cooldown
  export -f composite_update_state
  export -f composite_send_notification
  export -f composite_run_single_check
  export -f composite_run_all_checks
fi

# Initialize composite system if not already initialized
if [[ "${COMPOSITE_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if composite_system_init; then
    export COMPOSITE_SYSTEM_INITIALIZED=true
    log_debug "Composite check system auto-initialized" "composite"
  else
    echo "Warning: Failed to auto-initialize composite check system" >&2
  fi
fi
