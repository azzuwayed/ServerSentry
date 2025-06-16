#!/usr/bin/env bash
#
# ServerSentry v2 - Plugin Loader Module
#
# This module handles plugin loading, validation, and registration

# Function: plugin_system_init
# Description: Initialize plugin system with optimization and validation
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_system_init
# Dependencies:
#   - util_error_validate_input
#   - create_secure_dir
#   - log_debug
plugin_system_init() {
  log_debug "Initializing plugin system" "plugins"

  # Validate and create plugin directories
  if ! util_error_validate_input "$PLUGIN_DIR" "PLUGIN_DIR" "directory"; then
    log_info "Creating plugin directory: $PLUGIN_DIR" "plugins"
    if ! create_secure_dir "$PLUGIN_DIR" 755; then
      util_error_log_with_context "Failed to create plugin directory: $PLUGIN_DIR" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
      return 1
    fi
  fi

  if ! util_error_validate_input "$PLUGIN_CONFIG_DIR" "PLUGIN_CONFIG_DIR" "directory"; then
    log_info "Creating plugin config directory: $PLUGIN_CONFIG_DIR" "plugins"
    if ! create_secure_dir "$PLUGIN_CONFIG_DIR" 755; then
      util_error_log_with_context "Failed to create plugin config directory: $PLUGIN_CONFIG_DIR" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
      return 1
    fi
  fi

  # Clear plugin state
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_LOADED=()
    PLUGIN_FUNCTIONS=()
    PLUGIN_METADATA=()
    PLUGIN_PERFORMANCE_STATS=()
    PLUGIN_LOAD_TIMES=()
    PLUGIN_CHECK_COUNTS=()
    PLUGIN_ERROR_COUNTS=()
    PLUGIN_LAST_CHECK=()
  fi

  # Always clear cache files (handles scope issues and ensures clean state)
  log_debug "Clearing plugin cache files" "plugins"
  rm -f "${BASE_DIR}/tmp/plugin_"* 2>/dev/null || true

  # Clear registered plugins array
  registered_plugins=()

  # Load plugin registry for performance tracking
  if declare -f plugin_registry_load >/dev/null 2>&1; then
    plugin_registry_load
  else
    log_debug "Plugin registry functions not available, skipping performance tracking" "plugins"
  fi

  # Load enabled plugins from configuration
  local enabled_plugins
  enabled_plugins=$(config_get_array "plugins.enabled" 2>/dev/null || echo "")

  # If no plugins found in array format, fallback to single value
  if [[ -z "$enabled_plugins" ]]; then
    enabled_plugins=$(config_get_value "plugins.enabled" "" 2>/dev/null || echo "")
  fi

  # If still no plugins found, use default plugins
  if [[ -z "$enabled_plugins" ]]; then
    log_debug "No plugins configured, using defaults: cpu memory disk" "plugins"
    enabled_plugins="cpu
memory
disk"
  fi

  log_debug "Loading plugins: $(echo "$enabled_plugins" | tr '\n' ',' | sed 's/,$//')" "plugins"

  # Load each plugin with error handling and performance tracking
  local loaded_count=0
  while IFS= read -r plugin_name; do
    [[ -z "$plugin_name" ]] && continue
    plugin_name=$(util_sanitize_input "$plugin_name")
    log_debug "Loading plugin: $plugin_name" "plugins"

    if util_error_safe_execute "plugin_load \"$plugin_name\"" "Plugin load failed" "plugin_handle_load_failure" 2; then
      ((loaded_count++))
      if declare -f plugin_performance_track >/dev/null 2>&1; then
        plugin_performance_track "$plugin_name" "load"
      fi
    else
      util_error_log_with_context "Failed to load plugin: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
      if declare -f plugin_performance_track >/dev/null 2>&1; then
        plugin_performance_track "$plugin_name" "error"
      fi
    fi
  done <<<"$enabled_plugins"

  # Save updated registry
  if declare -f plugin_registry_save >/dev/null 2>&1; then
    plugin_registry_save
  fi

  # Optimize loading order for next time
  if declare -f plugin_optimize_loading >/dev/null 2>&1; then
    plugin_optimize_loading
  fi

  log_debug "Plugin system initialized: loaded $loaded_count plugins" "plugins"
  return 0
}

# Function: plugin_load
# Description: Load a plugin with optimization and caching
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_load "cpu"
# Dependencies:
#   - util_error_validate_input
#   - plugin_validate_interface
#   - plugin_register
plugin_load() {
  local plugin_name="$1"

  # Input validation using new error utilities
  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
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
  if ! util_error_validate_input "$plugin_path" "plugin_path" "file"; then
    return 1
  fi

  # Source the plugin file with error handling
  log_debug "Sourcing plugin: $plugin_path"
  if ! util_error_safe_execute "source \"$plugin_path\"" "Failed to source plugin" "" 1; then
    util_error_log_with_context "Failed to source plugin" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "file=$plugin_path"
    return 1
  fi

  # Cache function availability
  if ! _plugin_cache_functions "$plugin_name"; then
    util_error_log_with_context "Failed to cache plugin functions: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
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
  if util_error_validate_input "$plugin_config" "plugin_config" "file"; then
    log_debug "Configuring plugin from: $plugin_config"
    if ! util_error_safe_execute "${plugin_name}_plugin_configure \"$plugin_config\"" "Plugin configuration failed" "" 1; then
      util_error_log_with_context "Failed to configure plugin" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugin=$plugin_name, config=$plugin_config"
      return 1
    fi
  else
    log_debug "Using default configuration for plugin: $plugin_name"
    if ! util_error_safe_execute "${plugin_name}_plugin_configure \"\"" "Plugin default configuration failed" "" 1; then
      util_error_log_with_context "Failed to configure plugin with defaults" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugin=$plugin_name"
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

  log_debug "Plugin loaded successfully: $plugin_name"
  return 0
}

# Function: plugin_validate_interface
# Description: Validate that plugin implements required interface
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - valid interface
#   1 - invalid interface
# Example:
#   plugin_validate_interface "cpu"
# Dependencies:
#   - util_error_validate_input
#   - _plugin_get_function_status
plugin_validate_interface() {
  local plugin_name="$1"
  local validation_failed=false

  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  local required_functions=("info" "check" "configure")

  for func in "${required_functions[@]}"; do
    local func_name="${plugin_name}_plugin_${func}"
    if [[ "$(_plugin_get_function_status "$func_name")" != "available" ]]; then
      util_error_log_with_context "Plugin missing required function: $func_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
      validation_failed=true
    fi
  done

  if [[ "$validation_failed" == "true" ]]; then
    return 1
  fi

  log_debug "Plugin interface validation passed: $plugin_name"
  return 0
}

# Function: plugin_register
# Description: Register a plugin with the system
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_register "cpu"
# Dependencies:
#   - util_error_validate_input
#   - plugin_validate_interface
#   - util_array_add_unique
plugin_register() {
  local plugin_name="$1"

  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  # Validate plugin interface
  if ! plugin_validate_interface "$plugin_name"; then
    return 1
  fi

  # Add to registered plugins array
  util_array_add_unique registered_plugins "$plugin_name"

  # Get and store plugin info
  local plugin_info
  plugin_info=$("${plugin_name}_plugin_info" 2>/dev/null || echo "No description available")
  _plugin_set_metadata "$plugin_name" "$plugin_info"

  log_debug "Plugin registered: $plugin_name - $plugin_info"
  return 0
}

# Function: plugin_handle_load_failure
# Description: Handle plugin load failures with recovery strategies
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   plugin_handle_load_failure "plugin_load cpu"
# Dependencies:
#   - util_error_log_with_context
plugin_handle_load_failure() {
  local failed_command="$1"

  # Extract plugin name from failed command
  local plugin_name
  if [[ "$failed_command" =~ plugin_load[[:space:]]+\"?([^\"[:space:]]+)\"? ]]; then
    plugin_name="${BASH_REMATCH[1]}"
  else
    util_error_log_with_context "Cannot extract plugin name from failed command" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_WARNING" "command=$failed_command"
    return 1
  fi

  log_debug "Attempting plugin load recovery for: $plugin_name"

  # Check if plugin directory exists
  local plugin_dir="${PLUGIN_DIR}/${plugin_name}"
  if [[ ! -d "$plugin_dir" ]]; then
    util_error_log_with_context "Plugin directory not found: $plugin_dir" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "plugins"
    return 1
  fi

  # Check if plugin file exists
  local plugin_file="${plugin_dir}/${plugin_name}.sh"
  if [[ ! -f "$plugin_file" ]]; then
    util_error_log_with_context "Plugin file not found: $plugin_file" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "plugins"
    return 1
  fi

  # Check file permissions
  if [[ ! -r "$plugin_file" ]]; then
    log_debug "Attempting to fix plugin file permissions: $plugin_file"
    if chmod +r "$plugin_file" 2>/dev/null; then
      log_info "Fixed plugin file permissions: $plugin_file"
      return 0
    else
      util_error_log_with_context "Cannot fix plugin file permissions" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "file=$plugin_file"
      return 1
    fi
  fi

  # If we get here, the issue might be with plugin content
  util_error_log_with_context "Plugin load failed due to content issues" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_WARNING" "plugin=$plugin_name"
  return 1
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f plugin_system_init
  export -f plugin_load
  export -f plugin_validate_interface
  export -f plugin_register
  export -f plugin_handle_load_failure
fi
