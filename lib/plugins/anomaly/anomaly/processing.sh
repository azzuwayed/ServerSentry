#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Processing and Notification Module
#
# This module handles anomaly processing, notification management, result
# storage, and integration with the broader ServerSentry monitoring system.

# Prevent multiple sourcing
if [[ "${ANOMALY_PROCESSING_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_PROCESSING_MODULE_LOADED=true
export ANOMALY_PROCESSING_MODULE_LOADED

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

# Source core utilities and dependencies
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Source anomaly modules
source "${BASE_DIR}/lib/core/anomaly/config.sh"
source "${BASE_DIR}/lib/core/anomaly/data.sh"
source "${BASE_DIR}/lib/core/anomaly/detection.sh"

# Processing directories
ANOMALY_RESULTS_DIR="${BASE_DIR}/logs/anomaly/results"
ANOMALY_NOTIFICATIONS_DIR="${BASE_DIR}/logs/anomaly/notifications"

# Notification tracking
declare -A ANOMALY_NOTIFICATION_CACHE
declare -A ANOMALY_CONSECUTIVE_COUNT

# Function: anomaly_processing_init
# Description: Initialize the anomaly processing and notification system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_processing_init
# Dependencies:
#   - util_error_validate_input
anomaly_processing_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for anomaly_processing_init: expected 0, got $#" "anomaly_processing"
    return 1
  fi

  # Create required directories
  local dirs=("$ANOMALY_RESULTS_DIR" "$ANOMALY_NOTIFICATIONS_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create anomaly processing directory: $dir" "anomaly_processing"
        return 1
      fi
      log_debug "Created anomaly processing directory: $dir" "anomaly_processing"
    fi
  done

  log_debug "Anomaly processing and notification system initialized" "anomaly_processing"
  return 0
}

# Function: anomaly_process_plugin_results
# Description: Process plugin results and run anomaly detection for all configured metrics
# Parameters:
#   $1 (string): plugin results in JSON format
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_process_plugin_results "$plugin_results_json"
# Dependencies:
#   - util_error_validate_input
#   - anomaly_run_single_detection
anomaly_process_plugin_results() {
  if ! util_error_validate_input "anomaly_process_plugin_results" "1" "$#"; then
    return 1
  fi

  local plugin_results="$1"

  if [[ -z "$plugin_results" ]]; then
    log_error "Empty plugin results provided" "anomaly_processing"
    return 1
  fi

  # Validate JSON input if jq is available
  if command -v jq >/dev/null 2>&1; then
    if ! echo "$plugin_results" | jq . >/dev/null 2>&1; then
      log_error "Invalid JSON in plugin results" "anomaly_processing"
      return 1
    fi
  fi

  log_debug "Processing plugin results for anomaly detection" "anomaly_processing"

  local processed_count=0
  local anomaly_count=0

  # Process each plugin result
  if command -v jq >/dev/null 2>&1; then
    # Use jq for robust JSON parsing
    echo "$plugin_results" | jq -r '.[]? | "\(.plugin)|\(.metrics.usage_percent // .metrics.highest_usage // .metrics.value // 0)"' | while IFS='|' read -r plugin_name metric_value; do
      if [[ -n "$plugin_name" ]] && [[ -n "$metric_value" ]] && [[ "$metric_value" != "null" ]]; then
        log_debug "Processing anomaly detection for $plugin_name: $metric_value" "anomaly_processing"

        # Store the metric data
        if anomaly_data_store_metric "$plugin_name" "value" "$metric_value"; then
          processed_count=$((processed_count + 1))

          # Run anomaly detection
          if anomaly_run_single_detection "$plugin_name" "value" "$metric_value"; then
            anomaly_count=$((anomaly_count + 1))
          fi
        else
          log_warning "Failed to store metric data for $plugin_name" "anomaly_processing"
        fi
      fi
    done

    log_debug "Anomaly processing completed: $processed_count processed, $anomaly_count anomalies detected" "anomaly_processing"
    return 0
  else
    log_warning "jq command not available for robust JSON parsing" "anomaly_processing"

    # Fallback: simple parsing for basic cases
    local plugin_pattern='"plugin"[[:space:]]*:[[:space:]]*"([^"]+)"'
    local value_pattern='"(usage_percent|highest_usage|value)"[[:space:]]*:[[:space:]]*([0-9.]+)'

    while read -r line; do
      if [[ "$line" =~ $plugin_pattern ]]; then
        local plugin_name="${BASH_REMATCH[1]}"

        if [[ "$line" =~ $value_pattern ]]; then
          local metric_value="${BASH_REMATCH[2]}"

          if [[ -n "$plugin_name" ]] && [[ -n "$metric_value" ]]; then
            log_debug "Processing anomaly detection for $plugin_name: $metric_value" "anomaly_processing"

            if anomaly_data_store_metric "$plugin_name" "value" "$metric_value"; then
              processed_count=$((processed_count + 1))

              if anomaly_run_single_detection "$plugin_name" "value" "$metric_value"; then
                anomaly_count=$((anomaly_count + 1))
              fi
            fi
          fi
        fi
      fi
    done <<<"$plugin_results"

    log_debug "Anomaly processing completed (fallback): $processed_count processed, $anomaly_count anomalies detected" "anomaly_processing"
    return 0
  fi
}

# Function: anomaly_run_single_detection
# Description: Run anomaly detection for a single plugin metric
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name
#   $3 (numeric): current metric value
# Returns:
#   0 - anomaly detected
#   1 - no anomaly or error
# Example:
#   anomaly_run_single_detection "cpu" "usage" 95.5
# Dependencies:
#   - anomaly_config_get_value
#   - anomaly_detect_statistical_outliers
#   - anomaly_store_result
#   - anomaly_check_notification_needed
anomaly_run_single_detection() {
  if ! util_error_validate_input "anomaly_run_single_detection" "3" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local current_value="$3"

  # Check if anomaly detection is enabled for this plugin
  local enabled
  enabled=$(anomaly_config_get_value "$plugin_name" "enabled" "false")

  if [[ "$enabled" != "true" ]]; then
    log_debug "Anomaly detection disabled for plugin: $plugin_name" "anomaly_processing"
    return 1
  fi

  # Get configuration values
  local sensitivity
  sensitivity=$(anomaly_config_get_value "$plugin_name" "sensitivity" "2.0")

  local min_data_points
  min_data_points=$(anomaly_config_get_value "$plugin_name" "min_data_points" "10")

  local check_patterns
  check_patterns=$(anomaly_config_get_value "$plugin_name" "check_patterns" "true")

  local detect_trends
  detect_trends=$(anomaly_config_get_value "$plugin_name" "detect_trends" "true")

  local detect_spikes
  detect_spikes=$(anomaly_config_get_value "$plugin_name" "detect_spikes" "true")

  # Get data file path
  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  # Run statistical anomaly detection
  local anomaly_result
  if anomaly_result=$(anomaly_detect_statistical_outliers "$plugin_name" "$metric_name" "$current_value" "$data_file" "$sensitivity" "$min_data_points"); then
    log_debug "Statistical anomaly detected for ${plugin_name}.${metric_name}" "anomaly_processing"

    # Enhance result with additional pattern detection
    if [[ "$check_patterns" == "true" ]]; then
      anomaly_result=$(anomaly_enhance_with_patterns "$anomaly_result" "$data_file" "$current_value" "$detect_trends" "$detect_spikes")
    fi

    # Store the anomaly result
    if anomaly_store_result "$plugin_name" "$anomaly_result"; then
      # Check if notification should be sent
      if anomaly_check_notification_needed "$plugin_name" "$anomaly_result"; then
        anomaly_send_notification_if_needed "$plugin_name" "$anomaly_result"
      fi
    fi

    return 0
  else
    log_debug "No statistical anomaly detected for ${plugin_name}.${metric_name}" "anomaly_processing"

    # Reset consecutive anomaly count
    ANOMALY_CONSECUTIVE_COUNT["$plugin_name"]=0

    return 1
  fi
}

# Function: anomaly_enhance_with_patterns
# Description: Enhance anomaly result with additional pattern detection (trends, spikes)
# Parameters:
#   $1 (string): base anomaly result JSON
#   $2 (string): data file path
#   $3 (numeric): current value
#   $4 (boolean): detect trends
#   $5 (boolean): detect spikes
# Returns:
#   Enhanced anomaly result JSON via stdout
# Example:
#   enhanced=$(anomaly_enhance_with_patterns "$result" "/path/to/data.dat" 95.5 true true)
# Dependencies:
#   - anomaly_detect_trend_patterns
#   - anomaly_detect_spike_patterns
anomaly_enhance_with_patterns() {
  local base_result="$1"
  local data_file="$2"
  local current_value="$3"
  local detect_trends="$4"
  local detect_spikes="$5"

  if [[ -z "$base_result" ]]; then
    echo "$base_result"
    return
  fi

  local enhanced_result="$base_result"
  local additional_patterns=()

  # Detect trend patterns
  if [[ "$detect_trends" == "true" ]]; then
    local trend_result
    if trend_result=$(anomaly_detect_trend_patterns "$data_file" 20 2.0); then
      if [[ "$trend_result" != "none" ]]; then
        additional_patterns+=("$trend_result")
        log_debug "Trend pattern detected: $trend_result" "anomaly_processing"
      fi
    fi
  fi

  # Detect spike patterns
  if [[ "$detect_spikes" == "true" ]]; then
    # Extract baseline statistics from the result
    local mean std_dev
    if command -v jq >/dev/null 2>&1; then
      mean=$(echo "$base_result" | jq -r '.statistics.mean // 0')
      std_dev=$(echo "$base_result" | jq -r '.statistics.std_dev // 0')
    else
      # Fallback parsing
      mean=$(echo "$base_result" | grep -o '"mean"[[:space:]]*:[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')
      std_dev=$(echo "$base_result" | grep -o '"std_dev"[[:space:]]*:[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ')
    fi

    if [[ -n "$mean" ]] && [[ -n "$std_dev" ]]; then
      local spike_result
      if spike_result=$(anomaly_detect_spike_patterns "$data_file" "$current_value" "$mean" "$std_dev" 3.0); then
        if [[ "$spike_result" != "none" ]]; then
          additional_patterns+=("$spike_result")
          log_debug "Spike pattern detected: $spike_result" "anomaly_processing"
        fi
      fi
    fi
  fi

  # Add additional patterns to the result
  if [[ ${#additional_patterns[@]} -gt 0 ]]; then
    local patterns_string
    patterns_string=$(
      IFS=','
      echo "${additional_patterns[*]}"
    )

    if command -v jq >/dev/null 2>&1; then
      enhanced_result=$(echo "$enhanced_result" | jq --arg patterns "$patterns_string" '.additional_patterns = $patterns')
    else
      # Fallback: simple string replacement
      enhanced_result="${enhanced_result%\}}, \"additional_patterns\": \"$patterns_string\"}"
    fi
  fi

  echo "$enhanced_result"
}

# Function: anomaly_store_result
# Description: Store anomaly detection result to file and update tracking
# Parameters:
#   $1 (string): plugin name
#   $2 (string): anomaly result JSON
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_store_result "cpu" "$anomaly_result_json"
# Dependencies:
#   - util_error_validate_input
anomaly_store_result() {
  if ! util_error_validate_input "anomaly_store_result" "2" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local anomaly_result="$2"

  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_processing"
    return 1
  fi

  if [[ -z "$anomaly_result" ]]; then
    log_error "Empty anomaly result" "anomaly_processing"
    return 1
  fi

  # Create result file path
  local today
  today=$(date +%Y%m%d)
  local result_file="$ANOMALY_RESULTS_DIR/${plugin_name}_${today}.log"

  # Store the result with timestamp
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if ! echo "[$timestamp] $anomaly_result" >>"$result_file"; then
    log_error "Failed to store anomaly result: $result_file" "anomaly_processing"
    return 1
  fi

  # Update consecutive anomaly count
  local current_count="${ANOMALY_CONSECUTIVE_COUNT[$plugin_name]:-0}"
  ANOMALY_CONSECUTIVE_COUNT["$plugin_name"]=$((current_count + 1))

  log_debug "Stored anomaly result for $plugin_name (consecutive: ${ANOMALY_CONSECUTIVE_COUNT[$plugin_name]})" "anomaly_processing"
  return 0
}

# Function: anomaly_check_notification_needed
# Description: Check if notification should be sent based on configuration and cooldown
# Parameters:
#   $1 (string): plugin name
#   $2 (string): anomaly result JSON
# Returns:
#   0 - notification needed
#   1 - notification not needed
# Example:
#   if anomaly_check_notification_needed "cpu" "$result"; then
# Dependencies:
#   - anomaly_config_get_value
#   - util_error_validate_input
anomaly_check_notification_needed() {
  if ! util_error_validate_input "anomaly_check_notification_needed" "2" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local anomaly_result="$2"

  # Get notification configuration
  local notification_threshold
  notification_threshold=$(anomaly_config_get_value "$plugin_name" "notification_threshold" "3")

  local cooldown
  cooldown=$(anomaly_config_get_value "$plugin_name" "cooldown" "1800")

  # Check consecutive anomaly threshold
  local consecutive_count="${ANOMALY_CONSECUTIVE_COUNT[$plugin_name]:-0}"

  if [[ "$consecutive_count" -lt "$notification_threshold" ]]; then
    log_debug "Consecutive anomaly count ($consecutive_count) below threshold ($notification_threshold) for $plugin_name" "anomaly_processing"
    return 1
  fi

  # Check cooldown period
  local last_notification_file="$ANOMALY_NOTIFICATIONS_DIR/${plugin_name}_last_notification"

  if [[ -f "$last_notification_file" ]]; then
    local last_notification
    last_notification=$(cat "$last_notification_file" 2>/dev/null || echo "0")

    local current_time
    current_time=$(date +%s)

    local time_diff=$((current_time - last_notification))

    if [[ "$time_diff" -lt "$cooldown" ]]; then
      log_debug "Notification for $plugin_name is in cooldown (${time_diff}s < ${cooldown}s)" "anomaly_processing"
      return 1
    fi
  fi

  log_debug "Notification needed for $plugin_name (consecutive: $consecutive_count, threshold: $notification_threshold)" "anomaly_processing"
  return 0
}

# Function: anomaly_send_notification_if_needed
# Description: Send anomaly notification and update tracking
# Parameters:
#   $1 (string): plugin name
#   $2 (string): anomaly result JSON
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_send_notification_if_needed "cpu" "$anomaly_result"
# Dependencies:
#   - util_error_validate_input
#   - anomaly_format_notification_message
anomaly_send_notification_if_needed() {
  if ! util_error_validate_input "anomaly_send_notification_if_needed" "2" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local anomaly_result="$2"

  # Format notification message
  local notification_message
  if ! notification_message=$(anomaly_format_notification_message "$plugin_name" "$anomaly_result"); then
    log_error "Failed to format notification message for $plugin_name" "anomaly_processing"
    return 1
  fi

  # Send notification if notification system is available
  if declare -f send_notification >/dev/null; then
    if send_notification 1 "$notification_message" "anomaly" "$anomaly_result"; then
      log_info "Sent anomaly notification for $plugin_name" "anomaly_processing"

      # Update last notification time
      local last_notification_file="$ANOMALY_NOTIFICATIONS_DIR/${plugin_name}_last_notification"
      echo "$(date +%s)" >"$last_notification_file"

      # Reset consecutive count after successful notification
      ANOMALY_CONSECUTIVE_COUNT["$plugin_name"]=0

      return 0
    else
      log_error "Failed to send notification for $plugin_name" "anomaly_processing"
      return 1
    fi
  else
    log_warning "Notification system not available for anomaly: $plugin_name" "anomaly_processing"

    # Log the notification message instead
    log_warning "ANOMALY NOTIFICATION: $notification_message" "anomaly_processing"

    # Still update tracking
    local last_notification_file="$ANOMALY_NOTIFICATIONS_DIR/${plugin_name}_last_notification"
    echo "$(date +%s)" >"$last_notification_file"
    ANOMALY_CONSECUTIVE_COUNT["$plugin_name"]=0

    return 0
  fi
}

# Function: anomaly_format_notification_message
# Description: Format a user-friendly notification message from anomaly result
# Parameters:
#   $1 (string): plugin name
#   $2 (string): anomaly result JSON
# Returns:
#   Formatted message via stdout
# Example:
#   message=$(anomaly_format_notification_message "cpu" "$result")
# Dependencies:
#   - util_error_validate_input
anomaly_format_notification_message() {
  if ! util_error_validate_input "anomaly_format_notification_message" "2" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local anomaly_result="$2"

  # Extract key information from the result
  local current_value anomaly_type anomaly_score confidence_level

  if command -v jq >/dev/null 2>&1; then
    current_value=$(echo "$anomaly_result" | jq -r '.current_value // "unknown"')
    anomaly_type=$(echo "$anomaly_result" | jq -r '.anomaly_type // "unknown"')
    anomaly_score=$(echo "$anomaly_result" | jq -r '.anomaly_score // "0"')
    confidence_level=$(echo "$anomaly_result" | jq -r '.confidence_level // "unknown"')
  else
    # Fallback parsing
    current_value=$(echo "$anomaly_result" | grep -o '"current_value"[[:space:]]*:[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "unknown")
    anomaly_type=$(echo "$anomaly_result" | grep -o '"anomaly_type"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    anomaly_score=$(echo "$anomaly_result" | grep -o '"anomaly_score"[[:space:]]*:[[:space:]]*[0-9.-]*' | cut -d':' -f2 | tr -d ' ' || echo "0")
    confidence_level=$(echo "$anomaly_result" | grep -o '"confidence_level"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  fi

  # Format the message based on anomaly type
  local message="🚨 ANOMALY DETECTED: $plugin_name"
  message="$message\n📊 Current Value: $current_value"
  message="$message\n🔍 Type: $(echo "$anomaly_type" | tr '_' ' ' | tr ',' ', ')"
  message="$message\n📈 Score: $anomaly_score"
  message="$message\n🎯 Confidence: $confidence_level"
  message="$message\n⏰ Time: $(date)"

  # Add severity indicator
  case "$confidence_level" in
  "high")
    message="🔴 HIGH SEVERITY\n$message"
    ;;
  "medium")
    message="🟡 MEDIUM SEVERITY\n$message"
    ;;
  *)
    message="🟢 LOW SEVERITY\n$message"
    ;;
  esac

  echo -e "$message"
  return 0
}

# Function: anomaly_get_processing_statistics
# Description: Get comprehensive statistics about anomaly processing
# Parameters: None
# Returns:
#   0 - success (outputs JSON statistics)
#   1 - failure
# Example:
#   stats=$(anomaly_get_processing_statistics)
# Dependencies:
#   - util_error_validate_input
anomaly_get_processing_statistics() {
  if ! util_error_validate_input "anomaly_get_processing_statistics" "0" "$#"; then
    return 1
  fi

  local total_results=0
  local total_notifications=0
  local active_plugins=0

  # Count result files and entries
  if [[ -d "$ANOMALY_RESULTS_DIR" ]]; then
    local result_files
    if result_files=$(find "$ANOMALY_RESULTS_DIR" -name "*.log" -type f 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          local line_count
          if line_count=$(wc -l <"$file" 2>/dev/null); then
            total_results=$((total_results + line_count))
          fi
        fi
      done <<<"$result_files"
    fi
  fi

  # Count notification files
  if [[ -d "$ANOMALY_NOTIFICATIONS_DIR" ]]; then
    local notification_files
    if notification_files=$(find "$ANOMALY_NOTIFICATIONS_DIR" -name "*_last_notification" -type f 2>/dev/null); then
      total_notifications=$(echo "$notification_files" | grep -c . 2>/dev/null || echo "0")
    fi
  fi

  # Count active plugins (those with consecutive anomaly counts)
  active_plugins=${#ANOMALY_CONSECUTIVE_COUNT[@]}

  # Generate statistics JSON
  cat <<EOF
{
  "anomaly_processing_statistics": {
    "total_anomaly_results": $total_results,
    "total_notifications_sent": $total_notifications,
    "active_plugins": $active_plugins,
    "consecutive_anomaly_counts": {
EOF

  # Add consecutive counts
  local first=true
  for plugin in "${!ANOMALY_CONSECUTIVE_COUNT[@]}"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo ","
    fi
    echo -n "      \"$plugin\": ${ANOMALY_CONSECUTIVE_COUNT[$plugin]}"
  done

  cat <<EOF

    },
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF

  return 0
}

# Export all processing functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_processing_init
  export -f anomaly_process_plugin_results
  export -f anomaly_run_single_detection
  export -f anomaly_enhance_with_patterns
  export -f anomaly_store_result
  export -f anomaly_check_notification_needed
  export -f anomaly_send_notification_if_needed
  export -f anomaly_format_notification_message
  export -f anomaly_get_processing_statistics
fi

# Initialize the module
if ! anomaly_processing_init; then
  log_error "Failed to initialize anomaly processing module" "anomaly_processing"
fi
