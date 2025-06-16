#!/usr/bin/env bash
#
# ServerSentry v2 - CLI Plugin Commands Module
#
# This module handles plugin-related CLI commands: check, list, clear-cache

# Function: cmd_check
# Description: Run plugin checks with enhanced error handling and validation
# Parameters:
#   $1 (string): plugin name (optional, if empty runs all plugins)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_check "cpu"
#   cmd_check  # runs all plugins
# Dependencies:
#   - util_error_validate_input
#   - run_all_plugin_checks, run_plugin_check
#   - is_plugin_registered, list_plugins
cmd_check() {
  local plugin_name="$1"

  if [[ -z "$plugin_name" ]]; then
    # Check all plugins
    log_info "Running all plugin checks..." "cli"
    log_audit "check_all_plugins" "${USER:-unknown}" "User requested all plugin checks"

    local results
    if ! results=$(util_error_safe_execute "run_all_plugin_checks" "Failed to run all plugin checks" "" 2); then
      util_error_log_with_context "Failed to execute plugin checks" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    # Format output
    if util_command_exists jq; then
      if ! echo "$results" | jq . 2>/dev/null; then
        log_warning "Invalid JSON output from plugin checks, displaying raw output" "cli"
        echo "$results"
      fi
    else
      echo "$results"
    fi
  else
    # Validate plugin name input
    if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
      return 1
    fi

    # Sanitize plugin name
    plugin_name=$(util_sanitize_input "$plugin_name")

    # Check specific plugin
    log_info "Running check for plugin: $plugin_name" "cli"
    log_audit "check_plugin" "${USER:-unknown}" "plugin=$plugin_name"

    # Verify plugin is registered
    if ! is_plugin_registered "$plugin_name"; then
      util_error_log_with_context "Plugin not found: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      echo "Available plugins:"
      list_plugins
      return 1
    fi

    # Run the specific plugin check
    local result
    if ! result=$(util_error_safe_execute "run_plugin_check '$plugin_name'" "Failed to run plugin check" "" 2); then
      util_error_log_with_context "Failed to execute plugin check: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    # Format output
    if util_command_exists jq; then
      if ! echo "$result" | jq . 2>/dev/null; then
        log_warning "Invalid JSON output from plugin check, displaying raw output" "cli"
        echo "$result"
      fi
    else
      echo "$result"
    fi
  fi

  return 0
}

# Function: cmd_list
# Description: List available plugins with enhanced formatting and error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_list
# Dependencies:
#   - util_error_safe_execute
#   - list_plugins
cmd_list() {
  log_info "Listing available plugins..." "cli"
  log_audit "list_plugins" "${USER:-unknown}" "User requested plugin list"

  # Get plugin list with error handling
  if ! util_error_safe_execute "list_plugins" "Failed to list plugins" "" 1; then
    util_error_log_with_context "Failed to retrieve plugin list" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  return 0
}

# Function: cmd_clear_cache
# Description: Clear all plugin cache and temporary files with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_clear_cache
# Dependencies:
#   - util_error_safe_execute
#   - plugin_clear_cache
cmd_clear_cache() {
  log_info "Clearing plugin cache and temporary files..." "cli"
  log_audit "clear_cache" "${USER:-unknown}" "User requested cache clearing"

  # Clear plugin cache with error handling
  if ! util_error_safe_execute "plugin_clear_cache" "Failed to clear plugin cache" "" 2; then
    util_error_log_with_context "Failed to clear plugin cache" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Clear additional temporary files
  local temp_dirs=("${BASE_DIR}/tmp" "${BASE_DIR}/logs/temp")
  local cleared_count=0

  for temp_dir in "${temp_dirs[@]}"; do
    if [[ -d "$temp_dir" ]]; then
      log_debug "Clearing temporary files in: $temp_dir" "cli"

      # Clear temporary files safely
      if find "$temp_dir" -name "*.tmp" -type f -delete 2>/dev/null; then
        ((cleared_count++))
      fi

      if find "$temp_dir" -name "temp_*" -type f -delete 2>/dev/null; then
        ((cleared_count++))
      fi
    fi
  done

  # Clear old log files if configured
  if [[ "${CLEAR_OLD_LOGS:-false}" == "true" ]]; then
    log_debug "Clearing old log files" "cli"
    if util_error_safe_execute "cleanup_old_logs" "Failed to cleanup old logs" "" 1; then
      ((cleared_count++))
    fi
  fi

  log_info "Cache clearing completed successfully" "cli"
  log_audit "cache_cleared" "${USER:-unknown}" "cleared_items=$cleared_count"

  return 0
}

# Function: is_plugin_registered
# Description: Check if a plugin is registered in the system
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - plugin is registered
#   1 - plugin is not registered
# Example:
#   if is_plugin_registered "cpu"; then echo "Registered"; fi
# Dependencies:
#   - plugin_is_loaded or registered_plugins array
is_plugin_registered() {
  local plugin_name="$1"

  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  # Check if plugin_is_loaded function is available
  if declare -f plugin_is_loaded >/dev/null 2>&1; then
    plugin_is_loaded "$plugin_name"
    return $?
  fi

  # Fallback: check if plugin directory exists
  local plugin_dir="${PLUGIN_DIR:-${BASE_DIR}/lib/plugins}/${plugin_name}"
  if [[ -d "$plugin_dir" && -f "$plugin_dir/${plugin_name}.sh" ]]; then
    return 0
  fi

  return 1
}

# Function: list_plugins
# Description: List all available plugins with status information
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   list_plugins
# Dependencies:
#   - PLUGIN_DIR variable
#   - plugin_is_loaded (optional)
list_plugins() {
  local plugin_dir="${PLUGIN_DIR:-${BASE_DIR}/lib/plugins}"

  if ! util_error_validate_input "$plugin_dir" "plugin_dir" "directory"; then
    util_error_log_with_context "Plugin directory not found: $plugin_dir" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  echo "Available plugins:"
  echo "=================="

  local found_plugins=false

  # List plugins from plugin directory
  for plugin_path in "$plugin_dir"/*; do
    if [[ -d "$plugin_path" ]]; then
      local plugin_name
      plugin_name=$(basename "$plugin_path")
      local plugin_file="$plugin_path/${plugin_name}.sh"

      if [[ -f "$plugin_file" ]]; then
        found_plugins=true

        # Check if plugin is loaded
        local status="Available"
        if declare -f plugin_is_loaded >/dev/null 2>&1; then
          if plugin_is_loaded "$plugin_name"; then
            status="Loaded"
          fi
        fi

        # Get plugin description if available
        local description=""
        if [[ -r "$plugin_file" ]]; then
          description=$(grep -m1 "^# Description:" "$plugin_file" 2>/dev/null | sed 's/^# Description: *//' || echo "")
        fi

        if [[ -n "$description" ]]; then
          printf "  %-15s [%-9s] %s\n" "$plugin_name" "$status" "$description"
        else
          printf "  %-15s [%-9s]\n" "$plugin_name" "$status"
        fi
      fi
    fi
  done

  if [[ "$found_plugins" == "false" ]]; then
    echo "  No plugins found in $plugin_dir"
    return 1
  fi

  echo ""
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f cmd_check
  export -f cmd_list
  export -f cmd_clear_cache
  export -f is_plugin_registered
  export -f list_plugins
fi
