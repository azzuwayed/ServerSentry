#!/usr/bin/env bash
#
# ServerSentry v2 - Plugin Management (Modular)
#
# This module orchestrates all plugin components through modular architecture

# Prevent multiple sourcing
if [[ "${PLUGIN_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
PLUGIN_MODULE_LOADED=true
export PLUGIN_MODULE_LOADED

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
fi

# Source modular plugin components using bootstrap paths
source "${SERVERSENTRY_CORE_DIR}/plugins/state.sh"
source "${SERVERSENTRY_CORE_DIR}/plugins/loader.sh"
source "${SERVERSENTRY_CORE_DIR}/plugins/executor.sh"
source "${SERVERSENTRY_CORE_DIR}/plugins/performance.sh"

# Plugin system configuration using bootstrap paths
PLUGIN_DIR="${PLUGIN_DIR:-${SERVERSENTRY_PLUGINS_DIR}}"
PLUGIN_CONFIG_DIR="${PLUGIN_CONFIG_DIR:-${SERVERSENTRY_CONFIG_DIR}/plugins}"
PLUGIN_INTERFACE_VERSION="1.0"

# Array to store registered plugins
declare -a registered_plugins

# Plugin performance tracking using bootstrap paths
PLUGIN_REGISTRY_FILE="${SERVERSENTRY_TMP_DIR}/plugin_registry.json"
PLUGIN_PERFORMANCE_LOG="${SERVERSENTRY_LOGS_DIR}/plugin_performance.log"

# Function: plugin_system_init
# Description: Initialize the complete plugin management system with all modules
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_system_init
# Dependencies:
#   - plugin_state_init
plugin_system_init() {
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing modular plugin management system" "plugin"
  fi

  # Initialize state management first
  if ! plugin_state_init; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Failed to initialize plugin state management" "plugin"
    fi
    return 1
  fi

  # Log system initialization
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le "${LOG_LEVEL_DEBUG:-0}" ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Modular plugin management system initialized successfully" "plugin"
      log_debug "Plugin dir: ${PLUGIN_DIR}" "plugin"
      log_debug "Config dir: ${PLUGIN_CONFIG_DIR}" "plugin"
      log_debug "Interface version: ${PLUGIN_INTERFACE_VERSION}" "plugin"
    fi
  fi

  return 0
}

# === BACKWARD COMPATIBILITY FUNCTIONS ===
# These functions provide backward compatibility for existing code

# Backward compatibility function: _plugin_set_loaded
# Description: Set plugin loaded state (backward compatibility)
# Parameters:
#   $1 (string): plugin name
#   $2 (string): loaded state value
# Returns:
#   0 - success
#   1 - failure
# Example:
#   _plugin_set_loaded "cpu" "true"
# Dependencies:
#   - plugin_state_set_loaded
_plugin_set_loaded() {
  plugin_state_set_loaded "$@"
}

# Backward compatibility function: _plugin_get_loaded
# Description: Get plugin loaded state (backward compatibility)
# Parameters:
#   $1 (string): plugin name
# Returns:
#   Plugin loaded state via stdout
# Example:
#   state=$(_plugin_get_loaded "cpu")
# Dependencies:
#   - plugin_state_get_loaded
_plugin_get_loaded() {
  plugin_state_get_loaded "$@"
}

# Backward compatibility function: _plugin_set_function_status
# Description: Set plugin function status (backward compatibility)
# Parameters:
#   $1 (string): function name
#   $2 (string): status
# Returns:
#   0 - success
#   1 - failure
# Example:
#   _plugin_set_function_status "cpu_plugin_check" "available"
# Dependencies:
#   - plugin_state_set_function_status
_plugin_set_function_status() {
  plugin_state_set_function_status "$@"
}

# Backward compatibility function: _plugin_get_function_status
# Description: Get plugin function status (backward compatibility)
# Parameters:
#   $1 (string): function name
# Returns:
#   Function status via stdout
# Example:
#   status=$(_plugin_get_function_status "cpu_plugin_check")
# Dependencies:
#   - plugin_state_get_function_status
_plugin_get_function_status() {
  plugin_state_get_function_status "$@"
}

# Backward compatibility function: _plugin_set_metadata
# Description: Set plugin metadata (backward compatibility)
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metadata
# Returns:
#   0 - success
#   1 - failure
# Example:
#   _plugin_set_metadata "cpu" '{"version":"1.0"}'
# Dependencies:
#   - plugin_state_set_metadata
_plugin_set_metadata() {
  plugin_state_set_metadata "$@"
}

# Backward compatibility function: _plugin_get_metadata
# Description: Get plugin metadata (backward compatibility)
# Parameters:
#   $1 (string): plugin name
# Returns:
#   Plugin metadata via stdout
# Example:
#   metadata=$(_plugin_get_metadata "cpu")
# Dependencies:
#   - plugin_state_get_metadata
_plugin_get_metadata() {
  plugin_state_get_metadata "$@"
}

# Backward compatibility function: _plugin_cache_functions
# Description: Cache plugin functions (backward compatibility)
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - success
#   1 - failure
# Example:
#   _plugin_cache_functions "cpu"
# Dependencies:
#   - plugin_state_cache_functions
_plugin_cache_functions() {
  plugin_state_cache_functions "$@"
}

# Backward compatibility function: sanitize_and_validate_input
# Description: Sanitize and validate input (backward compatibility)
# Parameters:
#   $1 (string): input to sanitize
#   $2 (string): validation type
#   $3 (numeric): max length (optional)
# Returns:
#   Sanitized input via stdout
# Example:
#   clean_name=$(sanitize_and_validate_input "cpu-plugin" "plugin_name")
# Dependencies:
#   - plugin_state_sanitize_and_validate_input
sanitize_and_validate_input() {
  plugin_state_sanitize_and_validate_input "$@"
}

# Export all plugin functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration function
  export -f plugin_system_init

  # Export backward compatibility functions
  export -f _plugin_set_loaded
  export -f _plugin_get_loaded
  export -f _plugin_set_function_status
  export -f _plugin_get_function_status
  export -f _plugin_set_metadata
  export -f _plugin_get_metadata
  export -f _plugin_cache_functions
  export -f sanitize_and_validate_input

  # Export modular functions (already exported by modules, but ensure availability)
  export -f plugin_state_init
  export -f plugin_state_set_loaded
  export -f plugin_state_get_loaded
  export -f plugin_state_set_function_status
  export -f plugin_state_get_function_status
  export -f plugin_state_set_metadata
  export -f plugin_state_get_metadata
  export -f plugin_state_cache_functions
  export -f plugin_state_sanitize_and_validate_input
fi

# Initialize plugin system if not already initialized
if [[ "${PLUGIN_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if plugin_system_init; then
    export PLUGIN_SYSTEM_INITIALIZED=true
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Plugin management system auto-initialized" "plugin"
    fi
  else
    echo "Warning: Failed to auto-initialize plugin management system" >&2
  fi
fi
