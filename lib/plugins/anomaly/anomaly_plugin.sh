#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Detection System (Modular)
#
# This module orchestrates all anomaly detection components through modular architecture

# Prevent multiple sourcing
if [[ "${ANOMALY_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_MODULE_LOADED=true
export ANOMALY_MODULE_LOADED

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

# Source modular anomaly components
source "${BASE_DIR}/lib/plugins/anomaly/anomaly/config.sh"
source "${BASE_DIR}/lib/plugins/anomaly/anomaly/data.sh"
source "${BASE_DIR}/lib/plugins/anomaly/anomaly/detection.sh"
source "${BASE_DIR}/lib/plugins/anomaly/anomaly/processing.sh"

# Function: anomaly_system_init
# Description: Initialize the complete anomaly detection system with all modules
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_system_init
# Dependencies:
#   - anomaly_config_init
#   - anomaly_data_init
#   - anomaly_detection_init
#   - anomaly_processing_init
anomaly_system_init() {
  # Initialize configuration management first
  if ! anomaly_config_init; then
    echo "Error: Failed to initialize anomaly configuration" >&2
    return 1
  fi

  # Initialize data management
  if ! anomaly_data_init; then
    echo "Error: Failed to initialize anomaly data management" >&2
    return 1
  fi

  # Initialize detection algorithms
  if ! anomaly_detection_init; then
    echo "Warning: Failed to initialize anomaly detection algorithms" >&2
  fi

  # Initialize processing and notifications
  if ! anomaly_processing_init; then
    echo "Warning: Failed to initialize anomaly processing" >&2
  fi

  # Log system initialization (only if not in quiet mode)
  if [[ "${CURRENT_LOG_LEVEL:-1}" -le "${LOG_LEVEL_DEBUG:-0}" ]]; then
    log_debug "Modular anomaly detection system initialized successfully" "anomaly"
    log_debug "Config dir: ${ANOMALY_CONFIG_DIR}" "anomaly"
    log_debug "Data dir: ${ANOMALY_DATA_DIR}" "anomaly"
    log_debug "Results dir: ${ANOMALY_RESULTS_DIR}" "anomaly"
  fi

  return 0
}

# Backward compatibility aliases for original function names
alias anomaly_create_default_config=anomaly_config_create_defaults 2>/dev/null || true
alias store_metric_data=anomaly_data_store_metric 2>/dev/null || true
alias calculate_statistics=anomaly_calculate_statistics 2>/dev/null || true
alias detect_statistical_anomaly=anomaly_detect_statistical_outliers 2>/dev/null || true
alias detect_trend_anomaly=anomaly_detect_trend_patterns 2>/dev/null || true
alias detect_spike_anomaly=anomaly_detect_spike_patterns 2>/dev/null || true
alias anomaly_parse_config=anomaly_config_parse 2>/dev/null || true
alias anomaly_get_config_value=anomaly_config_get_value 2>/dev/null || true
alias anomaly_run_detection=anomaly_process_plugin_results 2>/dev/null || true
alias anomaly_should_send_notification=anomaly_check_notification_needed 2>/dev/null || true
alias anomaly_get_consecutive_count=anomaly_get_processing_statistics 2>/dev/null || true
alias anomaly_send_notification=anomaly_send_notification_if_needed 2>/dev/null || true

# Note: Backward compatibility functions are now handled by core stubs
# The core anomaly.sh provides stub implementations that delegate to this plugin
# when available, eliminating function name conflicts.

# Export all anomaly functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration function
  export -f anomaly_system_init

  # Note: Backward compatibility functions are exported by core stubs

  # Export modular functions (already exported by modules, but ensure availability)
  export -f anomaly_config_init
  export -f anomaly_config_create_defaults
  export -f anomaly_config_get_value
  export -f anomaly_config_set_value
  export -f anomaly_config_list_plugins
  export -f anomaly_config_get_summary

  export -f anomaly_data_init
  export -f anomaly_data_store_metric
  export -f anomaly_data_get_recent
  export -f anomaly_data_cleanup_old
  export -f anomaly_data_get_statistics
  export -f anomaly_data_export

  export -f anomaly_detection_init
  export -f anomaly_calculate_statistics
  export -f anomaly_detect_statistical_outliers
  export -f anomaly_detect_trend_patterns
  export -f anomaly_detect_spike_patterns

  export -f anomaly_processing_init
  export -f anomaly_process_plugin_results
  export -f anomaly_run_single_detection
  export -f anomaly_check_notification_needed
  export -f anomaly_send_notification_if_needed
  export -f anomaly_format_notification_message
  export -f anomaly_get_processing_statistics
fi

# Initialize anomaly system if not already initialized
if [[ "${ANOMALY_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if anomaly_system_init; then
    export ANOMALY_SYSTEM_INITIALIZED=true
    log_debug "Anomaly detection system auto-initialized" "anomaly"
  else
    echo "Warning: Failed to auto-initialize anomaly detection system" >&2
  fi
fi
