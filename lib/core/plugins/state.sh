#!/usr/bin/env bash
#
# ServerSentry v2 - Plugin State Management
#
# This module handles plugin state tracking, caching, and metadata management

# Prevent multiple sourcing
if [[ "${PLUGIN_STATE_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
PLUGIN_STATE_MODULE_LOADED=true
export PLUGIN_STATE_MODULE_LOADED

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

# Check bash version for associative array support
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  # Plugin state tracking for optimization (bash 4+)
  declare -A PLUGIN_LOADED
  declare -A PLUGIN_FUNCTIONS
  declare -A PLUGIN_METADATA
  declare -A PLUGIN_PERFORMANCE_STATS
  declare -A PLUGIN_LOAD_TIMES
  declare -A PLUGIN_CHECK_COUNTS
  declare -A PLUGIN_ERROR_COUNTS
  declare -A PLUGIN_LAST_CHECK
  ASSOCIATIVE_ARRAYS_SUPPORTED=true
else
  # Fallback for older bash versions
  ASSOCIATIVE_ARRAYS_SUPPORTED=false
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le 2 ]]; then
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Associative arrays not supported in bash version $BASH_VERSION, using fallback methods" "plugin"
    fi
  fi
fi

# Function: plugin_state_init
# Description: Initialize plugin state management system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_state_init
# Dependencies:
#   - util_create_secure_dir
plugin_state_init() {
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing plugin state management" "plugin"
  fi

  # Create state tracking directories
  if declare -f util_create_secure_dir >/dev/null 2>&1; then
    if ! util_create_secure_dir "${BASE_DIR}/tmp" "755"; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Failed to create plugin temp directory" "plugin"
      fi
      return 1
    fi

    if ! util_create_secure_dir "${BASE_DIR}/logs" "755"; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Failed to create plugin logs directory" "plugin"
      fi
      return 1
    fi
  else
    # Fallback directory creation
    mkdir -p "${BASE_DIR}/tmp" "${BASE_DIR}/logs" 2>/dev/null || true
  fi

  return 0
}

# Function: plugin_state_set_loaded
# Description: Set plugin loaded state
# Parameters:
#   $1 (string): plugin name
#   $2 (string): loaded state value
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_state_set_loaded "cpu" "true"
# Dependencies:
#   - util_error_validate_input
plugin_state_set_loaded() {
  if [[ $# -ne 2 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_set_loaded requires exactly 2 parameters" "plugin"
    fi
    return 1
  fi

  local plugin_name="$1"
  local value="$2"

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_LOADED[$plugin_name]="$value"
  fi

  # Always write to cache file for persistence across contexts
  local state_file="${BASE_DIR}/tmp/plugin_loaded_${plugin_name}"
  if ! echo "$value" >"$state_file" 2>/dev/null; then
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Failed to write plugin state file: $state_file" "plugin"
    fi
    return 1
  fi

  return 0
}

# Function: plugin_state_get_loaded
# Description: Get plugin loaded state
# Parameters:
#   $1 (string): plugin name
# Returns:
#   Plugin loaded state via stdout
# Example:
#   state=$(plugin_state_get_loaded "cpu")
# Dependencies:
#   - util_error_validate_input
plugin_state_get_loaded() {
  if [[ $# -ne 1 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_get_loaded requires exactly 1 parameter" "plugin"
    fi
    return 1
  fi

  local plugin_name="$1"
  local result=""

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    result="${PLUGIN_LOADED[$plugin_name]:-}"
  fi

  # Always check temporary files as fallback (handles scope issues)
  if [[ -z "$result" ]]; then
    local state_file="${BASE_DIR}/tmp/plugin_loaded_${plugin_name}"
    if [[ -f "$state_file" ]]; then
      result=$(cat "$state_file" 2>/dev/null || echo "")
    fi
  fi

  echo "$result"
}

# Function: plugin_state_set_function_status
# Description: Set plugin function availability status
# Parameters:
#   $1 (string): function name
#   $2 (string): status (available/missing)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_state_set_function_status "cpu_plugin_check" "available"
# Dependencies:
#   - util_error_validate_input
plugin_state_set_function_status() {
  if [[ $# -ne 2 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_set_function_status requires exactly 2 parameters" "plugin"
    fi
    return 1
  fi

  local func_name="$1"
  local status="$2"

  # Validate status parameter
  if [[ "$status" != "available" && "$status" != "missing" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Invalid function status: $status (must be 'available' or 'missing')" "plugin"
    fi
    return 1
  fi

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_FUNCTIONS[$func_name]="$status"
  fi

  # Always write to cache file for persistence across contexts
  local func_file="${BASE_DIR}/tmp/plugin_func_${func_name}"
  if ! echo "$status" >"$func_file" 2>/dev/null; then
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Failed to write plugin function status file: $func_file" "plugin"
    fi
    return 1
  fi

  return 0
}

# Function: plugin_state_get_function_status
# Description: Get plugin function availability status
# Parameters:
#   $1 (string): function name
# Returns:
#   Function status via stdout
# Example:
#   status=$(plugin_state_get_function_status "cpu_plugin_check")
# Dependencies:
#   - util_error_validate_input
plugin_state_get_function_status() {
  if [[ $# -ne 1 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_get_function_status requires exactly 1 parameter" "plugin"
    fi
    return 1
  fi

  local func_name="$1"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    echo "${PLUGIN_FUNCTIONS[$func_name]:-}"
  else
    # Fallback: read from temporary file
    local func_file="${BASE_DIR}/tmp/plugin_func_${func_name}"
    if [[ -f "$func_file" ]]; then
      cat "$func_file" 2>/dev/null || echo ""
    else
      echo ""
    fi
  fi
}

# Function: plugin_state_set_metadata
# Description: Set plugin metadata
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metadata JSON
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_state_set_metadata "cpu" '{"version":"1.0","author":"ServerSentry"}'
# Dependencies:
#   - util_error_validate_input
plugin_state_set_metadata() {
  if [[ $# -ne 2 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_set_metadata requires exactly 2 parameters" "plugin"
    fi
    return 1
  fi

  local plugin_name="$1"
  local metadata="$2"

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_METADATA[$plugin_name]="$metadata"
  fi

  # Always write to cache file for persistence across contexts
  local meta_file="${BASE_DIR}/tmp/plugin_meta_${plugin_name}"
  if ! echo "$metadata" >"$meta_file" 2>/dev/null; then
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Failed to write plugin metadata file: $meta_file" "plugin"
    fi
    return 1
  fi

  return 0
}

# Function: plugin_state_get_metadata
# Description: Get plugin metadata
# Parameters:
#   $1 (string): plugin name
# Returns:
#   Plugin metadata via stdout
# Example:
#   metadata=$(plugin_state_get_metadata "cpu")
# Dependencies:
#   - util_error_validate_input
plugin_state_get_metadata() {
  if [[ $# -ne 1 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_get_metadata requires exactly 1 parameter" "plugin"
    fi
    return 1
  fi

  local plugin_name="$1"
  local result=""

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    result="${PLUGIN_METADATA[$plugin_name]:-}"
  fi

  # Always check temporary files as fallback (handles scope issues)
  if [[ -z "$result" ]]; then
    local meta_file="${BASE_DIR}/tmp/plugin_meta_${plugin_name}"
    if [[ -f "$meta_file" ]]; then
      result=$(cat "$meta_file" 2>/dev/null || echo "")
    fi
  fi

  echo "$result"
}

# Function: plugin_state_cache_functions
# Description: Cache plugin function availability for performance
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_state_cache_functions "cpu"
# Dependencies:
#   - util_error_validate_input
#   - plugin_state_set_function_status
plugin_state_cache_functions() {
  if [[ $# -ne 1 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_cache_functions requires exactly 1 parameter" "plugin"
    fi
    return 1
  fi

  local plugin_name="$1"
  local required_functions=("info" "check" "configure")

  for func in "${required_functions[@]}"; do
    local func_name="${plugin_name}_plugin_${func}"
    if declare -f "$func_name" >/dev/null 2>&1; then
      plugin_state_set_function_status "$func_name" "available"
      if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Cached function: $func_name (available)" "plugin"
      fi
    else
      plugin_state_set_function_status "$func_name" "missing"
      if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Cached function: $func_name (missing)" "plugin"
      fi
    fi
  done

  return 0
}

# Function: plugin_state_sanitize_and_validate_input
# Description: Sanitize and validate plugin input
# Parameters:
#   $1 (string): input to sanitize
#   $2 (string): validation type
#   $3 (numeric): max length (optional, default: 64)
# Returns:
#   Sanitized input via stdout
# Example:
#   clean_name=$(plugin_state_sanitize_and_validate_input "cpu-plugin" "plugin_name")
# Dependencies:
#   - util_error_validate_input
#   - util_sanitize_input
#   - util_validate_string_length
plugin_state_sanitize_and_validate_input() {
  if [[ $# -lt 2 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "plugin_state_sanitize_and_validate_input requires at least 2 parameters" "plugin"
    fi
    return 1
  fi

  local input="$1"
  local validation_type="$2"
  local max_length="${3:-64}"

  # Basic sanitization
  local sanitized
  if declare -f util_sanitize_input >/dev/null 2>&1; then
    sanitized=$(util_sanitize_input "$input")
  else
    # Fallback sanitization
    sanitized=$(echo "$input" | tr -cd '[:alnum:]_-')
  fi

  # Length validation
  if declare -f util_validate_string_length >/dev/null 2>&1; then
    if ! util_validate_string_length "$sanitized" 1 "$max_length" "input"; then
      return 1
    fi
  else
    # Fallback length check
    if [[ ${#sanitized} -gt $max_length ]]; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Input too long: ${#sanitized} > $max_length" "plugin"
      fi
      return 1
    fi
  fi

  # Plugin name specific validation
  if [[ "$validation_type" == "plugin_name" ]]; then
    if ! [[ "$sanitized" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Invalid plugin name format: $sanitized" "plugin"
      fi
      return 1
    fi
  fi

  echo "$sanitized"
  return 0
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
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
