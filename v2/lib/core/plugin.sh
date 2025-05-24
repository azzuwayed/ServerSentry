#!/bin/bash
#
# ServerSentry v2 - Plugin Management
#
# This module handles plugin loading, validation, and execution

# Plugin system configuration
PLUGIN_DIR="${PLUGIN_DIR:-${BASE_DIR}/lib/plugins}"
PLUGIN_CONFIG_DIR="${PLUGIN_CONFIG_DIR:-${BASE_DIR}/config/plugins}"
PLUGIN_INTERFACE_VERSION="1.0"

# Check bash version for associative array support
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  # Plugin state tracking for optimization (bash 4+)
  declare -A PLUGIN_LOADED
  declare -A PLUGIN_FUNCTIONS
  declare -A PLUGIN_METADATA
  ASSOCIATIVE_ARRAYS_SUPPORTED=true
else
  # Fallback for older bash versions
  ASSOCIATIVE_ARRAYS_SUPPORTED=false
  log_warning "Associative arrays not supported in bash version $BASH_VERSION, using fallback methods"
fi

# Array to store registered plugins (for backward compatibility)
declare -a registered_plugins

# Source utilities
source "${BASE_DIR}/lib/core/utils.sh"

# Fallback functions for plugin state management (when associative arrays not supported)
_plugin_set_loaded() {
  local plugin_name="$1"
  local value="$2"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_LOADED[$plugin_name]="$value"
  else
    # Fallback: use a temporary file for state
    local state_file="${BASE_DIR}/tmp/plugin_loaded_${plugin_name}"
    mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
    echo "$value" >"$state_file" 2>/dev/null || true
  fi
}

_plugin_get_loaded() {
  local plugin_name="$1"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    echo "${PLUGIN_LOADED[$plugin_name]:-}"
  else
    # Fallback: read from temporary file
    local state_file="${BASE_DIR}/tmp/plugin_loaded_${plugin_name}"
    if [[ -f "$state_file" ]]; then
      cat "$state_file" 2>/dev/null || echo ""
    else
      echo ""
    fi
  fi
}

_plugin_set_function_status() {
  local func_name="$1"
  local status="$2"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_FUNCTIONS[$func_name]="$status"
  else
    # Fallback: use temporary file
    local func_file="${BASE_DIR}/tmp/plugin_func_${func_name}"
    mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
    echo "$status" >"$func_file" 2>/dev/null || true
  fi
}

_plugin_get_function_status() {
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

_plugin_set_metadata() {
  local plugin_name="$1"
  local metadata="$2"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_METADATA[$plugin_name]="$metadata"
  else
    # Fallback: use temporary file
    local meta_file="${BASE_DIR}/tmp/plugin_meta_${plugin_name}"
    mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
    echo "$metadata" >"$meta_file" 2>/dev/null || true
  fi
}

_plugin_get_metadata() {
  local plugin_name="$1"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    echo "${PLUGIN_METADATA[$plugin_name]:-}"
  else
    # Fallback: read from temporary file
    local meta_file="${BASE_DIR}/tmp/plugin_meta_${plugin_name}"
    if [[ -f "$meta_file" ]]; then
      cat "$meta_file" 2>/dev/null || echo ""
    else
      echo ""
    fi
  fi
}

# New standardized function: plugin_system_init
# Description: Initialize plugin system with optimization and validation
# Returns:
#   0 - success
#   1 - failure
plugin_system_init() {
  log_debug "Initializing plugin system"

  # Validate and create plugin directories
  if ! util_validate_dir_exists "$PLUGIN_DIR" "Plugin directory"; then
    log_info "Creating plugin directory: $PLUGIN_DIR"
    if ! create_secure_dir "$PLUGIN_DIR" 755; then
      log_error "Failed to create plugin directory: $PLUGIN_DIR"
      return 1
    fi
  fi

  if ! util_validate_dir_exists "$PLUGIN_CONFIG_DIR" "Plugin config directory"; then
    log_info "Creating plugin config directory: $PLUGIN_CONFIG_DIR"
    if ! create_secure_dir "$PLUGIN_CONFIG_DIR" 755; then
      log_error "Failed to create plugin config directory: $PLUGIN_CONFIG_DIR"
      return 1
    fi
  fi

  # Clear plugin state
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_LOADED=()
    PLUGIN_FUNCTIONS=()
    PLUGIN_METADATA=()
  else
    # Clear fallback state files for bash 3.x
    rm -f "${BASE_DIR}/tmp/plugin_"* 2>/dev/null || true
  fi
  registered_plugins=()

  # Load enabled plugins from configuration
  local enabled_plugins
  enabled_plugins=$(config_get_value "plugins_enabled" "cpu")

  # Convert comma/space/brackets separated string to array
  local plugin_list
  plugin_list=$(echo "$enabled_plugins" | tr -d '[]' | tr ',' ' ')

  log_info "Loading plugins: $plugin_list"

  # Load each plugin with error handling
  local loaded_count=0
  for plugin_name in $plugin_list; do
    plugin_name=$(util_sanitize_input "$plugin_name")
    log_debug "Loading plugin: $plugin_name"

    if plugin_load "$plugin_name"; then
      ((loaded_count++))
    else
      log_error "Failed to load plugin: $plugin_name"
    fi
  done

  log_info "Plugin system initialized: loaded $loaded_count plugins"
  return 0
}

# New standardized function: plugin_load
# Description: Load a plugin with optimization and caching
# Parameters:
#   $1 - plugin name
# Returns:
#   0 - success
#   1 - failure
plugin_load() {
  local plugin_name="$1"

  # Input validation
  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  # Sanitize plugin name
  plugin_name=$(sanitize_and_validate_input "$plugin_name" "plugin_name" 64)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Check if already loaded (optimization)
  if [[ "$(_plugin_get_loaded "$plugin_name")" == "true" ]]; then
    log_debug "Plugin already loaded: $plugin_name"
    return 0
  fi

  local plugin_path="${PLUGIN_DIR}/${plugin_name}/${plugin_name}.sh"
  local plugin_config="${PLUGIN_CONFIG_DIR}/${plugin_name}.conf"

  # Validate plugin file exists
  if ! util_validate_file_exists "$plugin_path" "Plugin file"; then
    return 1
  fi

  # Source the plugin file with error handling
  log_debug "Sourcing plugin: $plugin_path"
  if ! source "$plugin_path"; then
    log_error_context "Failed to source plugin" "file=$plugin_path"
    return 1
  fi

  # Cache function availability
  if ! _plugin_cache_functions "$plugin_name"; then
    log_error "Failed to cache plugin functions: $plugin_name"
    return 1
  fi

  # Validate plugin interface
  if ! plugin_validate_interface "$plugin_name"; then
    return 1
  fi

  # Register the plugin
  if ! plugin_register "$plugin_name"; then
    return 1
  fi

  # Configure the plugin
  if util_validate_file_exists "$plugin_config" "Plugin config"; then
    log_debug "Configuring plugin from: $plugin_config"
    if ! "${plugin_name}_plugin_configure" "$plugin_config"; then
      log_error_context "Failed to configure plugin" "plugin=$plugin_name, config=$plugin_config"
      return 1
    fi
  else
    log_debug "Using default configuration for plugin: $plugin_name"
    if ! "${plugin_name}_plugin_configure" ""; then
      log_error_context "Failed to configure plugin with defaults" "plugin=$plugin_name"
      return 1
    fi
  fi

  # Mark as loaded
  _plugin_set_loaded "$plugin_name" "true"

  # Export plugin functions for cross-shell availability
  export -f "${plugin_name}_plugin_info"
  export -f "${plugin_name}_plugin_configure"
  export -f "${plugin_name}_plugin_check"

  # Store metadata
  local plugin_info
  plugin_info=$("${plugin_name}_plugin_info" 2>/dev/null || echo "No description available")
  _plugin_set_metadata "$plugin_name" "$plugin_info"

  log_info "Plugin loaded successfully: $plugin_name"
  return 0
}

# New standardized function: plugin_validate_interface
# Description: Validate that plugin implements required interface
# Parameters:
#   $1 - plugin name
# Returns:
#   0 - valid interface
#   1 - invalid interface
plugin_validate_interface() {
  local plugin_name="$1"
  local validation_failed=false

  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  local required_functions=("info" "check" "configure")

  for func in "${required_functions[@]}"; do
    local func_name="${plugin_name}_plugin_${func}"
    if [[ "$(_plugin_get_function_status "$func_name")" != "available" ]]; then
      log_error "Plugin missing required function: $func_name"
      validation_failed=true
    fi
  done

  if [[ "$validation_failed" == "true" ]]; then
    return 1
  fi

  log_debug "Plugin interface validation passed: $plugin_name"
  return 0
}

# New standardized function: plugin_register
# Description: Register a plugin with the system
# Parameters:
#   $1 - plugin name
# Returns:
#   0 - success
#   1 - failure
plugin_register() {
  local plugin_name="$1"

  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  # Validate plugin interface
  if ! plugin_validate_interface "$plugin_name"; then
    return 1
  fi

  # Add to registered plugins array (for backward compatibility)
  util_array_add_unique registered_plugins "$plugin_name"

  # Get and store plugin info
  local plugin_info
  plugin_info=$("${plugin_name}_plugin_info" 2>/dev/null || echo "No description available")
  _plugin_set_metadata "$plugin_name" "$plugin_info"

  log_info "Plugin registered: $plugin_name - $plugin_info"
  return 0
}

# New standardized function: plugin_run_check
# Description: Run a plugin check with enhanced error handling and notifications
# Parameters:
#   $1 - plugin name
#   $2 - send notifications (optional, defaults to true)
# Returns:
#   0 - success
#   1 - failure
plugin_run_check() {
  local plugin_name="$1"
  local send_notifications="${2:-true}"

  # Input validation
  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  # Check if plugin is loaded
  if [[ "$(_plugin_get_loaded "$plugin_name")" != "true" ]]; then
    log_error "Plugin not loaded: $plugin_name"
    return 1
  fi

  # Run the plugin check with performance measurement
  log_debug "Running check for plugin: $plugin_name" >&2

  local result
  local exit_code
  local start_time
  local end_time
  local duration

  # Measure performance manually and call function directly
  start_time=$(date +%s.%N 2>/dev/null || date +%s)

  # Call plugin function directly in current shell context
  # Use a temporary file to capture output to avoid subshell issues
  local temp_output
  temp_output=$(create_temp_file "plugin_output")
  local temp_error
  temp_error=$(create_temp_file "plugin_error")

  if "${plugin_name}_plugin_check" >"$temp_output" 2>"$temp_error"; then
    exit_code=0
    result=$(cat "$temp_output")
  else
    exit_code=$?
    result=$(cat "$temp_output")
  fi

  # Clean up temp files
  rm -f "$temp_output" "$temp_error" 2>/dev/null

  end_time=$(date +%s.%N 2>/dev/null || date +%s)

  # Calculate duration if possible
  if command -v bc >/dev/null 2>&1; then
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    log_debug "Performance: plugin_${plugin_name}_check took ${duration}s" >&2
  fi

  if [[ "$exit_code" -ne 0 ]]; then
    local error_result
    error_result=$(util_json_create_error_object "Plugin check failed" "$exit_code" "plugin=$plugin_name")
    echo "$error_result"
    log_error_context "Plugin check failed" "plugin=$plugin_name, exit_code=$exit_code"
    return "$exit_code"
  fi

  # Validate JSON result
  if ! util_json_validate "$result"; then
    log_error_context "Plugin returned invalid JSON" "plugin=$plugin_name"
    local error_result
    error_result=$(util_json_create_error_object "Invalid JSON response" 2 "plugin=$plugin_name")
    echo "$error_result"
    return 1
  fi

  # Process result for notifications if needed
  if [[ "$send_notifications" == "true" ]] && command_exists jq; then
    # Extract status information from the JSON result
    local status_code
    status_code=$(util_json_get_value "$result" "status_code")

    local status_message
    status_message=$(util_json_get_value "$result" "status_message")

    # Get metrics for notification details
    local metrics
    metrics=$(util_json_extract_metrics "$result")

    # Only send notifications for non-OK statuses (status code > 0)
    if [[ "${status_code:-0}" -gt 0 ]]; then
      # Check if notifications module is available
      if declare -f send_notification >/dev/null; then
        log_debug "Sending notification for $plugin_name: $status_message"
        send_notification "$status_code" "$status_message" "$plugin_name" "$metrics"
      else
        log_debug "Notification system not available"
      fi
    fi
  fi

  # Return the validated result
  echo "$result"
  return 0
}

# New standardized function: plugin_is_loaded
# Description: Check if a plugin is loaded
# Parameters:
#   $1 - plugin name
# Returns:
#   0 - plugin is loaded
#   1 - plugin is not loaded
plugin_is_loaded() {
  local plugin_name="$1"

  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  [[ "$(_plugin_get_loaded "$plugin_name")" == "true" ]]
}

# New standardized function: plugin_list_loaded
# Description: List all loaded plugins with their information
# Returns:
#   Plugin list via stdout
plugin_list_loaded() {
  log_debug "Listing loaded plugins"

  if [[ "${#registered_plugins[@]}" -eq 0 ]]; then
    echo "No plugins loaded"
    return 0
  fi

  for plugin_name in "${registered_plugins[@]}"; do
    local plugin_info
    plugin_info="$(_plugin_get_metadata "$plugin_name")"
    if [[ -z "$plugin_info" ]]; then
      plugin_info="No description available"
    fi
    echo "$plugin_name: $plugin_info"
  done
}

# New standardized function: plugin_run_all_checks
# Description: Run checks for all loaded plugins
# Parameters:
#   $1 - send notifications (optional, defaults to true)
# Returns:
#   Combined results as JSON array
plugin_run_all_checks() {
  local send_notifications="${1:-true}"
  local results_array="[]"

  log_debug "Running checks for all loaded plugins"

  for plugin_name in "${registered_plugins[@]}"; do
    local result
    if result=$(plugin_run_check "$plugin_name" "$send_notifications"); then
      # Add to results array
      results_array=$(util_json_add_to_array "$results_array" "$result")
    else
      # Add error result
      local error_result
      error_result=$(util_json_create_error_object "Plugin check failed" 1 "plugin=$plugin_name")
      results_array=$(util_json_add_to_array "$results_array" "$error_result")
    fi
  done

  echo "$results_array"
}

# Internal function: Cache plugin function availability
_plugin_cache_functions() {
  local plugin_name="$1"
  local required_functions=("info" "check" "configure")

  for func in "${required_functions[@]}"; do
    local func_name="${plugin_name}_plugin_${func}"
    if declare -f "$func_name" >/dev/null 2>&1; then
      _plugin_set_function_status "$func_name" "available"
      log_debug "Cached function: $func_name (available)"
    else
      _plugin_set_function_status "$func_name" "missing"
      log_debug "Cached function: $func_name (missing)"
    fi
  done

  return 0
}

# Internal function: Sanitize and validate plugin input
sanitize_and_validate_input() {
  local input="$1"
  local validation_type="$2"
  local max_length="${3:-64}"

  # Basic sanitization
  local sanitized
  sanitized=$(util_sanitize_input "$input")

  # Length validation
  if ! util_validate_string_length "$sanitized" 1 "$max_length" "input"; then
    return 1
  fi

  # Plugin name specific validation
  if [[ "$validation_type" == "plugin_name" ]]; then
    if ! [[ "$sanitized" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      log_error "Invalid plugin name format: $sanitized"
      return 1
    fi
  fi

  echo "$sanitized"
  return 0
}

# === BACKWARD COMPATIBILITY FUNCTIONS ===
# These maintain compatibility with existing code

# Backward compatibility: init_plugin_system
init_plugin_system() {
  log_warning "Function init_plugin_system() is deprecated, use plugin_system_init() instead"
  plugin_system_init "$@"
}

# Backward compatibility: load_plugin
load_plugin() {
  log_warning "Function load_plugin() is deprecated, use plugin_load() instead"
  plugin_load "$@"
}

# Backward compatibility: validate_plugin
validate_plugin() {
  log_warning "Function validate_plugin() is deprecated, use plugin_validate_interface() instead"
  plugin_validate_interface "$@"
}

# Backward compatibility: register_plugin
register_plugin() {
  log_warning "Function register_plugin() is deprecated, use plugin_register() instead"
  plugin_register "$@"
}

# Backward compatibility: run_plugin_check
run_plugin_check() {
  log_warning "Function run_plugin_check() is deprecated, use plugin_run_check() instead"
  plugin_run_check "$@"
}

# Backward compatibility: is_plugin_registered
is_plugin_registered() {
  log_warning "Function is_plugin_registered() is deprecated, use plugin_is_loaded() instead"
  plugin_is_loaded "$@"
}

# Backward compatibility: list_plugins
list_plugins() {
  log_warning "Function list_plugins() is deprecated, use plugin_list_loaded() instead"
  plugin_list_loaded "$@"
}

# Backward compatibility: run_all_plugin_checks
run_all_plugin_checks() {
  log_warning "Function run_all_plugin_checks() is deprecated, use plugin_run_all_checks() instead"
  plugin_run_all_checks "$@"
}

# Export new standardized functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f plugin_system_init
  export -f plugin_load
  export -f plugin_validate_interface
  export -f plugin_register
  export -f plugin_run_check
  export -f plugin_is_loaded
  export -f plugin_list_loaded
  export -f plugin_run_all_checks

  # Export backward compatibility functions
  export -f init_plugin_system
  export -f load_plugin
  export -f validate_plugin
  export -f register_plugin
  export -f run_plugin_check
  export -f is_plugin_registered
  export -f list_plugins
  export -f run_all_plugin_checks
fi
