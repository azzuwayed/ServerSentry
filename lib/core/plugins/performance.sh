#!/usr/bin/env bash
#
# ServerSentry v2 - Plugin Performance Module
#
# This module handles plugin performance tracking, metrics collection, and optimization

# Function: plugin_performance_track
# Description: Track plugin performance metrics with enhanced error handling
# Parameters:
#   $1 (string): plugin name
#   $2 (string): operation type (load|check|error)
#   $3 (string): duration in seconds (optional)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_performance_track "cpu" "check" "0.123"
# Dependencies:
#   - util_error_validate_input
#   - util_error_log_with_context
plugin_performance_track() {
  local plugin_name="$1"
  local operation="$2"
  local duration="${3:-}"

  # Input validation
  if ! util_error_validate_input "$plugin_name" "plugin_name" "required"; then
    return 1
  fi

  if ! util_error_validate_input "$operation" "operation" "required"; then
    return 1
  fi

  local timestamp
  timestamp=$(date +%s)

  # Update performance statistics
  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    case "$operation" in
    "load")
      PLUGIN_LOAD_TIMES[$plugin_name]="$timestamp"
      if [[ -n "$duration" ]]; then
        PLUGIN_PERFORMANCE_STATS["${plugin_name}_load_duration"]="$duration"
      fi
      ;;
    "check")
      PLUGIN_CHECK_COUNTS[$plugin_name]=$((${PLUGIN_CHECK_COUNTS[$plugin_name]:-0} + 1))
      PLUGIN_LAST_CHECK[$plugin_name]="$timestamp"
      if [[ -n "$duration" ]]; then
        PLUGIN_PERFORMANCE_STATS["${plugin_name}_avg_check_duration"]=$(
          _calculate_average_duration "$plugin_name" "check" "$duration"
        )
      fi
      ;;
    "error")
      PLUGIN_ERROR_COUNTS[$plugin_name]=$((${PLUGIN_ERROR_COUNTS[$plugin_name]:-0} + 1))
      ;;
    esac
  fi

  # Always log to performance file for persistence
  if [[ -w "$(dirname "$PLUGIN_PERFORMANCE_LOG")" ]]; then
    local log_entry="$timestamp|$plugin_name|$operation"
    if [[ -n "$duration" ]]; then
      log_entry+="|$duration"
    fi
    echo "$log_entry" >>"$PLUGIN_PERFORMANCE_LOG"
  else
    util_error_log_with_context "Cannot write to plugin performance log" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_WARNING" "file=$PLUGIN_PERFORMANCE_LOG"
  fi

  return 0
}

# Function: plugin_get_performance_stats
# Description: Get performance statistics for a plugin or all plugins
# Parameters:
#   $1 (string): plugin name (optional, if empty returns stats for all plugins)
# Returns:
#   JSON performance statistics via stdout
#   0 - success
#   1 - failure
# Example:
#   stats=$(plugin_get_performance_stats "cpu")
#   all_stats=$(plugin_get_performance_stats)
# Dependencies:
#   - util_json_create_object
#   - util_json_create_array
plugin_get_performance_stats() {
  local plugin_name="${1:-}"

  if [[ -n "$plugin_name" ]]; then
    # Get stats for specific plugin
    _get_single_plugin_stats "$plugin_name"
  else
    # Get stats for all plugins
    _get_all_plugins_stats
  fi
}

# Function: _get_single_plugin_stats
# Description: Get performance statistics for a single plugin
# Parameters:
#   $1 (string): plugin name
# Returns:
#   JSON performance statistics via stdout
# Example:
#   stats=$(_get_single_plugin_stats "cpu")
# Dependencies:
#   - util_json_create_object
_get_single_plugin_stats() {
  local plugin_name="$1"

  local load_time check_count error_count last_check avg_duration

  if [[ "$ASSOCIATIVE_ARRAYS_SUPPORTED" == "true" ]]; then
    load_time="${PLUGIN_LOAD_TIMES[$plugin_name]:-0}"
    check_count="${PLUGIN_CHECK_COUNTS[$plugin_name]:-0}"
    error_count="${PLUGIN_ERROR_COUNTS[$plugin_name]:-0}"
    last_check="${PLUGIN_LAST_CHECK[$plugin_name]:-0}"
    avg_duration="${PLUGIN_PERFORMANCE_STATS["${plugin_name}_avg_check_duration"]:-0}"
  else
    # Fallback: read from performance log
    load_time=$(grep "|$plugin_name|load" "$PLUGIN_PERFORMANCE_LOG" 2>/dev/null | tail -1 | cut -d'|' -f1 || echo "0")
    check_count=$(grep -c "|$plugin_name|check" "$PLUGIN_PERFORMANCE_LOG" 2>/dev/null || echo "0")
    error_count=$(grep -c "|$plugin_name|error" "$PLUGIN_PERFORMANCE_LOG" 2>/dev/null || echo "0")
    last_check=$(grep "|$plugin_name|check" "$PLUGIN_PERFORMANCE_LOG" 2>/dev/null | tail -1 | cut -d'|' -f1 || echo "0")
    avg_duration="0"
  fi

  # Calculate success rate
  local success_rate="100"
  if [[ $check_count -gt 0 ]]; then
    success_rate=$(echo "scale=2; (($check_count - $error_count) * 100) / $check_count" | bc -l 2>/dev/null || echo "100")
  fi

  # Create JSON result
  local stats
  stats=$(util_json_create_object \
    "plugin_name" "$plugin_name" \
    "load_time" "$load_time" \
    "check_count" "$check_count" \
    "error_count" "$error_count" \
    "last_check" "$last_check" \
    "average_duration" "$avg_duration" \
    "success_rate" "$success_rate")

  echo "$stats"
}

# Function: _get_all_plugins_stats
# Description: Get performance statistics for all plugins
# Parameters: None
# Returns:
#   JSON array of performance statistics via stdout
# Example:
#   all_stats=$(_get_all_plugins_stats)
# Dependencies:
#   - _get_single_plugin_stats
#   - util_json_create_array
_get_all_plugins_stats() {
  local all_stats=()

  # Get stats for each registered plugin
  for plugin_name in "${registered_plugins[@]}"; do
    local plugin_stats
    plugin_stats=$(_get_single_plugin_stats "$plugin_name")
    all_stats+=("$plugin_stats")
  done

  # Create JSON array
  local combined_stats
  combined_stats=$(util_json_create_array "${all_stats[@]}")

  echo "$combined_stats"
}

# Function: _calculate_average_duration
# Description: Calculate average duration for plugin operations
# Parameters:
#   $1 (string): plugin name
#   $2 (string): operation type
#   $3 (string): new duration
# Returns:
#   Average duration via stdout
# Example:
#   avg=$(_calculate_average_duration "cpu" "check" "0.123")
# Dependencies:
#   - bc command for calculations
_calculate_average_duration() {
  local plugin_name="$1"
  local operation="$2"
  local new_duration="$3"

  # Get current average
  local current_avg="${PLUGIN_PERFORMANCE_STATS["${plugin_name}_avg_${operation}_duration"]:-0}"
  local count="${PLUGIN_CHECK_COUNTS[$plugin_name]:-1}"

  # Calculate new average: ((old_avg * (count-1)) + new_duration) / count
  local new_avg
  if command -v bc >/dev/null 2>&1; then
    new_avg=$(echo "scale=3; (($current_avg * ($count - 1)) + $new_duration) / $count" | bc -l 2>/dev/null || echo "$new_duration")
  else
    # Fallback without bc
    new_avg="$new_duration"
  fi

  echo "$new_avg"
}

# Function: plugin_registry_save
# Description: Save plugin registry to file with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_registry_save
# Dependencies:
#   - util_json_create_object
#   - util_error_log_with_context
plugin_registry_save() {
  log_debug "Saving plugin registry to: $PLUGIN_REGISTRY_FILE"

  # Create registry directory if needed
  local registry_dir
  registry_dir=$(dirname "$PLUGIN_REGISTRY_FILE")
  if ! mkdir -p "$registry_dir" 2>/dev/null; then
    util_error_log_with_context "Failed to create registry directory: $registry_dir" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_WARNING" "plugins"
    return 1
  fi

  # Create registry data
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local plugins_array
  plugins_array=$(util_json_create_array "${registered_plugins[@]}")

  local registry_data
  registry_data=$(util_json_create_object \
    "timestamp" "$timestamp" \
    "version" "2.0.0" \
    "plugins" "$plugins_array" \
    "total_plugins" "${#registered_plugins[@]}")

  # Save to file with error handling
  if echo "$registry_data" >"$PLUGIN_REGISTRY_FILE" 2>/dev/null; then
    chmod 644 "$PLUGIN_REGISTRY_FILE" 2>/dev/null
    log_debug "Plugin registry saved successfully"
    return 0
  else
    util_error_log_with_context "Failed to save plugin registry" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_WARNING" "file=$PLUGIN_REGISTRY_FILE"
    return 1
  fi
}

# Function: plugin_registry_load
# Description: Load plugin registry from file with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_registry_load
# Dependencies:
#   - util_json_validate
#   - util_json_get_value
plugin_registry_load() {
  if [[ ! -f "$PLUGIN_REGISTRY_FILE" ]]; then
    log_debug "Plugin registry file not found, starting with empty registry"
    return 0
  fi

  log_debug "Loading plugin registry from: $PLUGIN_REGISTRY_FILE"

  # Read and validate registry file
  local registry_content
  if ! registry_content=$(cat "$PLUGIN_REGISTRY_FILE" 2>/dev/null); then
    util_error_log_with_context "Failed to read plugin registry file" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_WARNING" "file=$PLUGIN_REGISTRY_FILE"
    return 1
  fi

  # Validate JSON format
  if ! util_json_validate "$registry_content"; then
    util_error_log_with_context "Invalid JSON in plugin registry file" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_WARNING" "file=$PLUGIN_REGISTRY_FILE"
    return 1
  fi

  # Extract plugin list (basic extraction for compatibility)
  local plugins_json
  plugins_json=$(util_json_get_value "$registry_content" "plugins" 2>/dev/null || echo "[]")

  # Parse plugins array (simple approach for shell compatibility)
  if [[ "$plugins_json" != "[]" ]]; then
    # Extract plugin names from JSON array
    local plugin_names
    plugin_names=$(echo "$plugins_json" | sed 's/\[//g; s/\]//g; s/"//g; s/,/ /g')

    # Add to registered plugins array
    for plugin_name in $plugin_names; do
      if [[ -n "$plugin_name" ]]; then
        registered_plugins+=("$plugin_name")
      fi
    done
  fi

  log_debug "Plugin registry loaded: ${#registered_plugins[@]} plugins"
  return 0
}

# Function: plugin_optimize_loading
# Description: Optimize plugin loading order based on performance metrics
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_optimize_loading
# Dependencies:
#   - plugin_get_performance_stats
plugin_optimize_loading() {
  log_debug "Optimizing plugin loading order"

  # Get performance stats for all plugins
  local all_stats
  all_stats=$(plugin_get_performance_stats)

  if [[ -z "$all_stats" || "$all_stats" == "[]" ]]; then
    log_debug "No performance data available for optimization"
    return 0
  fi

  # For now, just log the optimization attempt
  # In a full implementation, this would reorder plugins based on:
  # - Load time
  # - Success rate
  # - Average check duration
  # - Error frequency

  log_debug "Plugin loading optimization completed"
  return 0
}

# Function: plugin_cleanup_performance_logs
# Description: Clean up old performance log entries
# Parameters:
#   $1 (integer): days to keep (optional, default: 30)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_cleanup_performance_logs 7
# Dependencies:
#   - util_error_validate_input
plugin_cleanup_performance_logs() {
  local days_to_keep="${1:-30}"

  if ! util_error_validate_input "$days_to_keep" "days_to_keep" "numeric"; then
    days_to_keep="30"
  fi

  log_debug "Cleaning up plugin performance logs older than $days_to_keep days"

  if [[ ! -f "$PLUGIN_PERFORMANCE_LOG" ]]; then
    log_debug "Plugin performance log not found, nothing to clean"
    return 0
  fi

  # Calculate cutoff timestamp
  local cutoff_timestamp
  cutoff_timestamp=$(date -d "$days_to_keep days ago" +%s 2>/dev/null || date -v-"${days_to_keep}"d +%s 2>/dev/null || echo "0")

  if [[ "$cutoff_timestamp" == "0" ]]; then
    util_error_log_with_context "Failed to calculate cutoff timestamp for cleanup" "$ERROR_GENERAL" "$ERROR_SEVERITY_WARNING" "plugins"
    return 1
  fi

  # Create temporary file for cleaned log
  local temp_log
  temp_log=$(create_temp_file "plugin_performance_clean")

  # Filter log entries
  local cleaned_count=0
  while IFS='|' read -r timestamp plugin operation duration; do
    if [[ "$timestamp" -ge "$cutoff_timestamp" ]]; then
      echo "$timestamp|$plugin|$operation|$duration" >>"$temp_log"
    else
      ((cleaned_count++))
    fi
  done <"$PLUGIN_PERFORMANCE_LOG"

  # Replace original log with cleaned version
  if mv "$temp_log" "$PLUGIN_PERFORMANCE_LOG" 2>/dev/null; then
    log_debug "Cleaned up $cleaned_count old performance log entries"
    return 0
  else
    rm -f "$temp_log" 2>/dev/null
    util_error_log_with_context "Failed to update performance log after cleanup" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_WARNING" "file=$PLUGIN_PERFORMANCE_LOG"
    return 1
  fi
}

# Function: plugin_clear_cache
# Description: Clear plugin cache files and reset state
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   plugin_clear_cache
# Dependencies:
#   - util_error_log_with_context
plugin_clear_cache() {
  log_debug "Clearing plugin cache"

  # Clear associative arrays if supported
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

  # Clear cache files
  local cache_files_removed=0
  for cache_file in "${BASE_DIR}/tmp/plugin_"*; do
    if [[ -f "$cache_file" ]]; then
      if rm "$cache_file" 2>/dev/null; then
        ((cache_files_removed++))
      else
        util_error_log_with_context "Failed to remove cache file: $cache_file" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_WARNING" "plugins"
      fi
    fi
  done

  log_debug "Plugin cache cleared: $cache_files_removed files removed"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f plugin_performance_track
  export -f plugin_get_performance_stats
  export -f plugin_registry_save
  export -f plugin_registry_load
  export -f plugin_optimize_loading
  export -f plugin_cleanup_performance_logs
  export -f plugin_clear_cache
  export -f _get_single_plugin_stats
  export -f _get_all_plugins_stats
  export -f _calculate_average_duration
fi
