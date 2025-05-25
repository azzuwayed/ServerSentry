#!/usr/bin/env bash
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
    log_warning "Associative arrays not supported in bash version $BASH_VERSION, using fallback methods"
  fi
fi

# Array to store registered plugins
declare -a registered_plugins

# Source utilities
source "${BASE_DIR}/lib/core/utils.sh"

# Plugin performance tracking
PLUGIN_REGISTRY_FILE="${BASE_DIR}/tmp/plugin_registry.json"
PLUGIN_PERFORMANCE_LOG="${BASE_DIR}/logs/plugin_performance.log"

# Create performance tracking directory
mkdir -p "${BASE_DIR}/tmp" "${BASE_DIR}/logs" 2>/dev/null || true

# Fallback functions for plugin state management (when associative arrays not supported)
_plugin_set_loaded() {
  local plugin_name="$1"
  local value="$2"

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_LOADED[$plugin_name]="$value"
  fi

  # Always write to cache file for persistence across contexts
  local state_file="${BASE_DIR}/tmp/plugin_loaded_${plugin_name}"
  mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
  echo "$value" >"$state_file" 2>/dev/null || true
}

_plugin_get_loaded() {
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

_plugin_set_function_status() {
  local func_name="$1"
  local status="$2"

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_FUNCTIONS[$func_name]="$status"
  fi

  # Always write to cache file for persistence across contexts
  local func_file="${BASE_DIR}/tmp/plugin_func_${func_name}"
  mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
  echo "$status" >"$func_file" 2>/dev/null || true
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

  # Always update associative array if supported
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    PLUGIN_METADATA[$plugin_name]="$metadata"
  fi

  # Always write to cache file for persistence across contexts
  local meta_file="${BASE_DIR}/tmp/plugin_meta_${plugin_name}"
  mkdir -p "${BASE_DIR}/tmp" 2>/dev/null || true
  echo "$metadata" >"$meta_file" 2>/dev/null || true
}

_plugin_get_metadata() {
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

# New standardized function: plugin_system_init
# Description: Initialize plugin system with optimization and validation
# Returns:
#   0 - success
#   1 - failure
plugin_system_init() {
  log_debug "Initializing plugin system" "plugins"

  # Validate and create plugin directories
  if ! util_validate_dir_exists "$PLUGIN_DIR" "Plugin directory"; then
    log_info "Creating plugin directory: $PLUGIN_DIR" "plugins"
    if ! create_secure_dir "$PLUGIN_DIR" 755; then
      log_error "Failed to create plugin directory: $PLUGIN_DIR" "plugins"
      return 1
    fi
  fi

  if ! util_validate_dir_exists "$PLUGIN_CONFIG_DIR" "Plugin config directory"; then
    log_info "Creating plugin config directory: $PLUGIN_CONFIG_DIR" "plugins"
    if ! create_secure_dir "$PLUGIN_CONFIG_DIR" 755; then
      log_error "Failed to create plugin config directory: $PLUGIN_CONFIG_DIR" "plugins"
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
  plugin_registry_load

  # Load enabled plugins from configuration
  local enabled_plugins
  enabled_plugins=$(config_get_array "plugins.enabled")

  # If no plugins found in array format, fallback to single value
  if [[ -z "$enabled_plugins" ]]; then
    enabled_plugins=$(config_get_value "plugins.enabled" "cpu")
  fi

  log_debug "Loading plugins: $(echo "$enabled_plugins" | tr '\n' ',' | sed 's/,$//')" "plugins"

  # Load each plugin with error handling and performance tracking
  local loaded_count=0
  while IFS= read -r plugin_name; do
    [[ -z "$plugin_name" ]] && continue
    plugin_name=$(util_sanitize_input "$plugin_name")
    log_debug "Loading plugin: $plugin_name" "plugins"

    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)

    if plugin_load "$plugin_name"; then
      ((loaded_count++))

      # Track load performance
      local end_time
      end_time=$(date +%s.%N 2>/dev/null || date +%s)
      plugin_performance_track "$plugin_name" "load"
    else
      log_error "Failed to load plugin: $plugin_name" "plugins"
      plugin_performance_track "$plugin_name" "error"
    fi
  done <<<"$enabled_plugins"

  # Save updated registry
  plugin_registry_save

  # Optimize loading order for next time
  plugin_optimize_loading

  log_debug "Plugin system initialized: loaded $loaded_count plugins" "plugins"
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

  log_debug "Plugin loaded successfully: $plugin_name"
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

  # Add to registered plugins array
  util_array_add_unique registered_plugins "$plugin_name"

  # Get and store plugin info
  local plugin_info
  plugin_info=$("${plugin_name}_plugin_info" 2>/dev/null || echo "No description available")
  _plugin_set_metadata "$plugin_name" "$plugin_info"

  log_debug "Plugin registered: $plugin_name - $plugin_info"
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

  # Ensure plugin functions are available (re-source if needed)
  if ! declare -f "${plugin_name}_plugin_check" >/dev/null 2>&1; then
    log_debug "Plugin functions not available, re-sourcing plugin: $plugin_name"
    local plugin_path="${PLUGIN_DIR}/${plugin_name}/${plugin_name}.sh"
    if [[ -f "$plugin_path" ]]; then
      # shellcheck source=/dev/null
      source "$plugin_path"
    else
      log_error "Plugin file not found: $plugin_path"
      return 1
    fi
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

  # Workaround: Fix extra closing brace issue if present
  if [[ "$result" =~ \}\}\}$ ]]; then
    result="${result%?}" # Remove the last character (extra brace)
    log_debug "Fixed extra closing brace in plugin result" "plugins"
  fi

  end_time=$(date +%s.%N 2>/dev/null || date +%s)

  # Calculate duration if possible
  if command -v bc >/dev/null 2>&1; then
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    log_debug "Performance: plugin_${plugin_name}_check took ${duration}s" >&2

    # Track performance metrics
    plugin_performance_track "$plugin_name" "check" "$duration"
  else
    # Track check without duration
    plugin_performance_track "$plugin_name" "check"
  fi

  if [[ "$exit_code" -ne 0 ]]; then
    # Track error
    plugin_performance_track "$plugin_name" "error"

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
  if [[ "$send_notifications" == "true" ]] && util_command_exists jq; then
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

  local loaded_plugins=()

  # Debug: Log the state of arrays and variables
  log_debug "registered_plugins count: ${#registered_plugins[@]}"
  log_debug "ASSOCIATIVE_ARRAYS_SUPPORTED: $ASSOCIATIVE_ARRAYS_SUPPORTED"
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    log_debug "PLUGIN_LOADED array count: ${#PLUGIN_LOADED[@]}"
  fi

  # First try to use the registered_plugins array
  if [[ "${#registered_plugins[@]}" -gt 0 ]]; then
    log_debug "Using registered_plugins array"
    loaded_plugins=("${registered_plugins[@]}")
  elif [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    # Fallback: check associative arrays for loaded plugins
    log_debug "Using PLUGIN_LOADED associative array"
    for plugin in "${!PLUGIN_LOADED[@]}"; do
      if [[ "${PLUGIN_LOADED[$plugin]}" == "true" ]]; then
        loaded_plugins+=("$plugin")
      fi
    done
  fi

  # Always check temporary files as final fallback (handles scope issues)
  if [[ "${#loaded_plugins[@]}" -eq 0 ]]; then
    log_debug "Using temporary files fallback"
    for state_file in "${BASE_DIR}/tmp/plugin_loaded_"*; do
      if [[ -f "$state_file" && "$(cat "$state_file" 2>/dev/null)" == "true" ]]; then
        local plugin_name
        plugin_name=$(basename "$state_file" | sed 's/^plugin_loaded_//')
        loaded_plugins+=("$plugin_name")
      fi
    done
  fi

  log_debug "Final loaded_plugins count: ${#loaded_plugins[@]}"

  if [[ "${#loaded_plugins[@]}" -eq 0 ]]; then
    echo "No plugins loaded"
    return 0
  fi

  for plugin_name in "${loaded_plugins[@]}"; do
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

  local loaded_plugins=()

  # First try to use the registered_plugins array
  if [[ "${#registered_plugins[@]}" -gt 0 ]]; then
    loaded_plugins=("${registered_plugins[@]}")
  elif [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    # Fallback: check associative arrays for loaded plugins
    for plugin in "${!PLUGIN_LOADED[@]}"; do
      if [[ "${PLUGIN_LOADED[$plugin]}" == "true" ]]; then
        loaded_plugins+=("$plugin")
      fi
    done
  fi

  # Always check temporary files as final fallback (handles scope issues)
  if [[ "${#loaded_plugins[@]}" -eq 0 ]]; then
    for state_file in "${BASE_DIR}/tmp/plugin_loaded_"*; do
      if [[ -f "$state_file" && "$(cat "$state_file" 2>/dev/null)" == "true" ]]; then
        local plugin_name
        plugin_name=$(basename "$state_file" | sed 's/^plugin_loaded_//')
        loaded_plugins+=("$plugin_name")
      fi
    done
  fi

  for plugin_name in "${loaded_plugins[@]}"; do
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

# === ADVANCED PLUGIN OPTIMIZATION FUNCTIONS ===

# Function: plugin_registry_save
# Description: Save plugin registry to persistent storage
# Returns:
#   0 - success
#   1 - failure
plugin_registry_save() {
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" != "true" ]]; then
    log_debug "Registry save not available in bash < 4.0"
    return 0
  fi

  local registry_json="{"
  local first=true

  for plugin in "${!PLUGIN_LOADED[@]}"; do
    if [[ "${PLUGIN_LOADED[$plugin]}" == "true" ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        registry_json+=","
      fi

      local metadata="${PLUGIN_METADATA[$plugin]:-}"
      local load_time="${PLUGIN_LOAD_TIMES[$plugin]:-0}"
      local check_count="${PLUGIN_CHECK_COUNTS[$plugin]:-0}"
      local error_count="${PLUGIN_ERROR_COUNTS[$plugin]:-0}"
      local last_check="${PLUGIN_LAST_CHECK[$plugin]:-0}"

      registry_json+="\"$plugin\":{"
      registry_json+="\"loaded\":true,"
      registry_json+="\"metadata\":\"$(util_json_escape "$metadata")\","
      registry_json+="\"load_time\":$load_time,"
      registry_json+="\"check_count\":$check_count,"
      registry_json+="\"error_count\":$error_count,"
      registry_json+="\"last_check\":$last_check"
      registry_json+="}"
    fi
  done

  registry_json+="}"

  if ! echo "$registry_json" >"$PLUGIN_REGISTRY_FILE"; then
    log_error "Failed to save plugin registry"
    return 1
  fi

  log_debug "Plugin registry saved to $PLUGIN_REGISTRY_FILE"
  return 0
}

# Function: plugin_registry_load
# Description: Load plugin registry from persistent storage
# Returns:
#   0 - success
#   1 - failure
plugin_registry_load() {
  if [[ ! -f "$PLUGIN_REGISTRY_FILE" ]]; then
    log_debug "No plugin registry file found, starting fresh"
    return 0
  fi

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" != "true" ]]; then
    log_debug "Registry load not available in bash < 4.0"
    return 0
  fi

  log_debug "Loading plugin registry from $PLUGIN_REGISTRY_FILE"

  # Parse JSON using jq if available, otherwise skip
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r plugin; do
      if [[ -n "$plugin" ]]; then
        local load_time
        load_time=$(jq -r ".\"$plugin\".load_time" "$PLUGIN_REGISTRY_FILE" 2>/dev/null || echo "0")
        local check_count
        check_count=$(jq -r ".\"$plugin\".check_count" "$PLUGIN_REGISTRY_FILE" 2>/dev/null || echo "0")
        local error_count
        error_count=$(jq -r ".\"$plugin\".error_count" "$PLUGIN_REGISTRY_FILE" 2>/dev/null || echo "0")

        PLUGIN_LOAD_TIMES[$plugin]="$load_time"
        PLUGIN_CHECK_COUNTS[$plugin]="$check_count"
        PLUGIN_ERROR_COUNTS[$plugin]="$error_count"
      fi
    done < <(jq -r 'keys[]' "$PLUGIN_REGISTRY_FILE" 2>/dev/null || true)
  fi

  return 0
}

# Function: plugin_performance_track
# Description: Track plugin performance metrics
# Parameters:
#   $1 - plugin name
#   $2 - operation type (load, check, error)
#   $3 - duration in seconds (optional)
# Returns:
#   0 - success
plugin_performance_track() {
  local plugin_name="$1"
  local operation="$2"
  local duration="${3:-0}"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" != "true" ]]; then
    return 0
  fi

  local timestamp
  timestamp=$(date +%s)

  case "$operation" in
  "load")
    PLUGIN_LOAD_TIMES[$plugin_name]="$timestamp"
    ;;
  "check")
    PLUGIN_CHECK_COUNTS[$plugin_name]="$((${PLUGIN_CHECK_COUNTS[$plugin_name]:-0} + 1))"
    PLUGIN_LAST_CHECK[$plugin_name]="$timestamp"

    # Log performance if duration provided
    if [[ "$duration" != "0" ]]; then
      log_performance "Plugin check completed" "plugin=$plugin_name duration=${duration}s"
    fi
    ;;
  "error")
    PLUGIN_ERROR_COUNTS[$plugin_name]="$((${PLUGIN_ERROR_COUNTS[$plugin_name]:-0} + 1))"
    log_error "Plugin operation failed" "plugins" # Use plugin component logging
    ;;
  esac

  return 0
}

# Function: plugin_get_performance_stats
# Description: Get performance statistics for a plugin
# Parameters:
#   $1 - plugin name (optional, if empty returns all)
# Returns:
#   Performance stats JSON via stdout
plugin_get_performance_stats() {
  local plugin_name="${1:-}"

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" != "true" ]]; then
    echo '{"error": "Performance stats not available in bash < 4.0"}'
    return 0
  fi

  local stats_json="{"
  local first=true

  if [[ -n "$plugin_name" ]]; then
    # Single plugin stats
    if [[ "${PLUGIN_LOADED[$plugin_name]:-}" == "true" ]]; then
      stats_json+="\"$plugin_name\":{"
      stats_json+="\"check_count\":${PLUGIN_CHECK_COUNTS[$plugin_name]:-0},"
      stats_json+="\"error_count\":${PLUGIN_ERROR_COUNTS[$plugin_name]:-0},"
      stats_json+="\"load_time\":${PLUGIN_LOAD_TIMES[$plugin_name]:-0},"
      stats_json+="\"last_check\":${PLUGIN_LAST_CHECK[$plugin_name]:-0},"

      # Calculate error rate
      local check_count="${PLUGIN_CHECK_COUNTS[$plugin_name]:-0}"
      local error_count="${PLUGIN_ERROR_COUNTS[$plugin_name]:-0}"
      local error_rate=0
      if [[ "$check_count" -gt 0 ]]; then
        error_rate=$(echo "scale=4; $error_count * 100 / $check_count" | bc -l 2>/dev/null || echo "0")
      fi
      stats_json+="\"error_rate\":$error_rate"
      stats_json+="}"
    else
      stats_json+="\"error\":\"Plugin not loaded: $plugin_name\""
    fi
  else
    # All plugins stats
    for plugin in "${!PLUGIN_LOADED[@]}"; do
      if [[ "${PLUGIN_LOADED[$plugin]}" == "true" ]]; then
        if [[ "$first" == "true" ]]; then
          first=false
        else
          stats_json+=","
        fi

        stats_json+="\"$plugin\":{"
        stats_json+="\"check_count\":${PLUGIN_CHECK_COUNTS[$plugin]:-0},"
        stats_json+="\"error_count\":${PLUGIN_ERROR_COUNTS[$plugin]:-0},"
        stats_json+="\"load_time\":${PLUGIN_LOAD_TIMES[$plugin]:-0},"
        stats_json+="\"last_check\":${PLUGIN_LAST_CHECK[$plugin]:-0},"

        # Calculate error rate
        local check_count="${PLUGIN_CHECK_COUNTS[$plugin]:-0}"
        local error_count="${PLUGIN_ERROR_COUNTS[$plugin]:-0}"
        local error_rate=0
        if [[ "$check_count" -gt 0 ]]; then
          error_rate=$(echo "scale=4; $error_count * 100 / $check_count" | bc -l 2>/dev/null || echo "0")
        fi
        stats_json+="\"error_rate\":$error_rate"
        stats_json+="}"
      fi
    done
  fi

  stats_json+="}"
  echo "$stats_json"
}

# Function: plugin_optimize_loading
# Description: Optimize plugin loading based on usage statistics
# Returns:
#   0 - success
plugin_optimize_loading() {
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" != "true" ]]; then
    log_debug "Plugin optimization not available in bash < 4.0"
    return 0
  fi

  log_debug "Optimizing plugin loading order based on usage statistics"

  # Create array of plugins with their usage scores
  local -a plugin_scores
  for plugin in "${!PLUGIN_LOADED[@]}"; do
    if [[ "${PLUGIN_LOADED[$plugin]}" == "true" ]]; then
      local check_count="${PLUGIN_CHECK_COUNTS[$plugin]:-0}"
      local error_count="${PLUGIN_ERROR_COUNTS[$plugin]:-0}"
      local score=$((check_count - error_count * 2)) # Penalize errors
      plugin_scores+=("$score:$plugin")
    fi
  done

  # Sort plugins by score (highest first)
  IFS=$'\n' plugin_scores=($(sort -rn <<<"${plugin_scores[*]}"))
  unset IFS

  log_debug "Plugin loading order optimized: ${plugin_scores[*]}"
  return 0
}

# Function: plugin_cleanup_performance_logs
# Description: Clean up old performance logs
# Parameters:
#   $1 - days to keep (defaults to 30)
# Returns:
#   0 - success
plugin_cleanup_performance_logs() {
  local days_to_keep="${1:-30}"

  if [[ -f "$PLUGIN_PERFORMANCE_LOG" ]]; then
    # Find lines older than specified days and remove them
    local cutoff_date
    cutoff_date=$(date -d "$days_to_keep days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    local temp_log
    temp_log=$(create_temp_file "plugin_perf_cleanup")

    if awk -v cutoff="$cutoff_date" '$0 > cutoff' "$PLUGIN_PERFORMANCE_LOG" >"$temp_log" 2>/dev/null; then
      mv "$temp_log" "$PLUGIN_PERFORMANCE_LOG"
      log_debug "Cleaned up performance logs older than $days_to_keep days"
    else
      rm -f "$temp_log"
    fi
  fi

  return 0
}

# Function: plugin_clear_cache
# Description: Clear all plugin cache files and reset state
# Returns:
#   0 - success
plugin_clear_cache() {
  log_info "Clearing all plugin cache and state" "plugins"

  # Clear temporary files
  rm -f "${BASE_DIR}/tmp/plugin_"* 2>/dev/null || true

  # Clear in-memory arrays if supported
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

  # Clear registered plugins array
  registered_plugins=()

  log_info "Plugin cache cleared successfully" "plugins"
  return 0
}

# Export standardized functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f plugin_system_init
  export -f plugin_load
  export -f plugin_validate_interface
  export -f plugin_register
  export -f plugin_run_check
  export -f plugin_is_loaded
  export -f plugin_list_loaded
  export -f plugin_run_all_checks
  export -f plugin_registry_save
  export -f plugin_registry_load
  export -f plugin_performance_track
  export -f plugin_get_performance_stats
  export -f plugin_optimize_loading
  export -f plugin_cleanup_performance_logs
  export -f plugin_clear_cache

fi
