#!/usr/bin/env bash
#
# ServerSentry v2 - Plugin Executor Module
#
# This module handles plugin execution, performance tracking, and result processing

# Function: plugin_run_check
# Description: Run a plugin check with enhanced error handling and notifications
# Parameters:
#   $1 (string): plugin name
#   $2 (boolean): send notifications (optional, defaults to true)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_run_check "cpu" "true"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
#   - plugin_performance_track
plugin_run_check() {
  local plugin_name="$1"
  local send_notifications="${2:-true}"

  # Input validation using new error utilities
  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  # Check if plugin is loaded
  if [[ "$(_plugin_get_loaded "$plugin_name")" != "true" ]]; then
    util_error_log_with_context "Plugin not loaded: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
    return 1
  fi

  # Ensure plugin functions are available (re-source if needed)
  if ! declare -f "${plugin_name}_plugin_check" >/dev/null 2>&1; then
    log_debug "Plugin functions not available, re-sourcing plugin: $plugin_name"
    local plugin_path="${PLUGIN_DIR}/${plugin_name}/${plugin_name}.sh"
    if [[ -f "$plugin_path" ]]; then
      # shellcheck source=/dev/null
      if ! util_error_safe_execute "source \"$plugin_path\"" "Failed to re-source plugin" "" 1; then
        util_error_log_with_context "Failed to re-source plugin: $plugin_path" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugins"
        return 1
      fi
    else
      util_error_log_with_context "Plugin file not found: $plugin_path" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "plugins"
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
    util_error_log_with_context "Plugin check failed" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugin=$plugin_name, exit_code=$exit_code"
    return "$exit_code"
  fi

  # Validate JSON result
  if ! util_json_validate "$result"; then
    util_error_log_with_context "Plugin returned invalid JSON" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "plugin=$plugin_name"
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

    # Send notifications for non-OK status
    if [[ "$status_code" != "0" && "$status_code" != "OK" ]]; then
      plugin_send_notification "$plugin_name" "$result"
    fi
  fi

  echo "$result"
  return 0
}

# Function: plugin_run_all_checks
# Description: Run checks for all loaded plugins with enhanced error handling
# Parameters:
#   $1 (boolean): send notifications (optional, defaults to true)
# Returns:
#   0 - all checks successful
#   1 - one or more checks failed
# Example:
#   plugin_run_all_checks "true"
# Dependencies:
#   - plugin_list_loaded
#   - plugin_run_check
#   - util_json_create_array
plugin_run_all_checks() {
  local send_notifications="${1:-true}"
  local results=()
  local failed_count=0
  local total_count=0

  log_debug "Running checks for all loaded plugins"

  # Get list of loaded plugins
  local loaded_plugins
  loaded_plugins=$(plugin_list_loaded)

  if [[ -z "$loaded_plugins" ]]; then
    log_warning "No plugins loaded for checks"
    echo "[]"
    return 0
  fi

  # Run check for each loaded plugin
  while IFS= read -r plugin_name; do
    [[ -z "$plugin_name" ]] && continue
    ((total_count++))

    log_debug "Running check for plugin: $plugin_name"

    local plugin_result
    if plugin_result=$(plugin_run_check "$plugin_name" "$send_notifications"); then
      results+=("$plugin_result")
      log_debug "Plugin check successful: $plugin_name"
    else
      ((failed_count++))
      # Create error result for failed plugin
      local error_result
      error_result=$(util_json_create_error_object "Plugin check failed" 1 "plugin=$plugin_name")
      results+=("$error_result")
      util_error_log_with_context "Plugin check failed: $plugin_name" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_WARNING" "plugins"
    fi
  done <<<"$loaded_plugins"

  # Create combined results array
  local combined_results
  combined_results=$(util_json_create_array "${results[@]}")

  echo "$combined_results"

  log_debug "Plugin checks completed: $total_count total, $failed_count failed"

  # Return success if no failures
  [[ "$failed_count" -eq 0 ]]
}

# Function: plugin_send_notification
# Description: Send notification for plugin check result
# Parameters:
#   $1 (string): plugin name
#   $2 (string): plugin result JSON
# Returns:
#   0 - notification sent successfully
#   1 - notification failed
# Example:
#   plugin_send_notification "cpu" "$result_json"
# Dependencies:
#   - util_json_get_value
#   - notification_send
plugin_send_notification() {
  local plugin_name="$1"
  local result_json="$2"

  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$result_json" "result_json" "required"; then
    return 1
  fi

  # Extract notification details from result
  local status_code message details
  status_code=$(util_json_get_value "$result_json" "status_code" 2>/dev/null || echo "unknown")
  message=$(util_json_get_value "$result_json" "message" 2>/dev/null || echo "Plugin check completed")
  details=$(util_json_get_value "$result_json" "details" 2>/dev/null || echo "{}")

  # Determine notification severity
  local severity="info"
  case "$status_code" in
  "0" | "OK") severity="info" ;;
  "1" | "WARNING") severity="warning" ;;
  "2" | "ERROR") severity="error" ;;
  "3" | "CRITICAL") severity="critical" ;;
  *) severity="warning" ;;
  esac

  # Create notification payload
  local notification_title="ServerSentry Plugin Alert: $plugin_name"
  local notification_message="$message"

  if [[ "$details" != "{}" ]]; then
    notification_message+="\n\nDetails: $details"
  fi

  # Send notification if notification system is available
  if declare -f notification_send >/dev/null 2>&1; then
    if notification_send "$severity" "$notification_title" "$notification_message"; then
      log_debug "Notification sent for plugin: $plugin_name"
      return 0
    else
      util_error_log_with_context "Failed to send notification for plugin: $plugin_name" "$ERROR_NETWORK_ERROR" "$ERROR_SEVERITY_WARNING" "plugins"
      return 1
    fi
  else
    log_debug "Notification system not available"
    return 1
  fi
}

# Function: plugin_is_loaded
# Description: Check if a plugin is loaded
# Parameters:
#   $1 (string): plugin name
# Returns:
#   0 - plugin is loaded
#   1 - plugin is not loaded
# Example:
#   plugin_is_loaded "cpu"
# Dependencies:
#   - util_error_validate_input
#   - _plugin_get_loaded
plugin_is_loaded() {
  local plugin_name="$1"

  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  [[ "$(_plugin_get_loaded "$plugin_name")" == "true" ]]
}

# Function: plugin_list_loaded
# Description: List all loaded plugins
# Parameters: None
# Returns:
#   List of loaded plugin names via stdout
#   0 - success
#   1 - failure
# Example:
#   loaded_plugins=$(plugin_list_loaded)
# Dependencies:
#   - registered_plugins array
plugin_list_loaded() {
  local loaded_plugins=()

  # Check each registered plugin
  for plugin_name in "${registered_plugins[@]}"; do
    if [[ "$(_plugin_get_loaded "$plugin_name")" == "true" ]]; then
      loaded_plugins+=("$plugin_name")
    fi
  done

  # Output loaded plugins, one per line
  printf '%s\n' "${loaded_plugins[@]}"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f plugin_run_check
  export -f plugin_run_all_checks
  export -f plugin_send_notification
  export -f plugin_is_loaded
  export -f plugin_list_loaded
fi
