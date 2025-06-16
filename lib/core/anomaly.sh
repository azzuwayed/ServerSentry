#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Detection Stub (Simplified Core Version)
#
# This is a simplified stub that provides basic anomaly detection interface
# The full anomaly detection system has been moved to optional plugins

# Prevent multiple sourcing
if [[ "${ANOMALY_STUB_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_STUB_LOADED=true
export ANOMALY_STUB_LOADED

# Simple anomaly detection configuration
ANOMALY_ENABLED="${ANOMALY_ENABLED:-false}"
ANOMALY_SIMPLE_THRESHOLD="${ANOMALY_SIMPLE_THRESHOLD:-95}"

# Function: anomaly_system_init
# Description: Initialize simplified anomaly detection (stub version)
# Parameters: None
# Returns: 0 - success, 1 - failure
anomaly_system_init() {
  if [[ "${ANOMALY_ENABLED}" == "true" ]]; then
    echo "INFO: Simple anomaly detection enabled (threshold: ${ANOMALY_SIMPLE_THRESHOLD}%)" >&2
  else
    echo "INFO: Anomaly detection disabled (use plugins for advanced features)" >&2
  fi
  return 0
}

# Function: anomaly_run_detection
# Description: Simple anomaly detection (stub version)
# Parameters: $1 - plugin results JSON
# Returns: 0 - success
anomaly_run_detection() {
  local plugin_results="$1"

  if [[ "${ANOMALY_ENABLED}" != "true" ]]; then
    echo '{"anomaly_detection": "disabled", "message": "Use anomaly plugin for advanced detection"}'
    return 0
  fi

  # Simple threshold-based detection
  echo '{"anomaly_detection": "simple", "threshold": "'"${ANOMALY_SIMPLE_THRESHOLD}"'", "message": "Basic threshold detection only"}'
  return 0
}

# Backward compatibility stubs - all return "not available" messages
store_metric_data() {
  echo "INFO: Advanced anomaly detection not available in core. Install anomaly plugin." >&2
  return 1
}

calculate_statistics() {
  echo "INFO: Statistical analysis not available in core. Install anomaly plugin." >&2
  return 1
}

detect_statistical_anomaly() {
  echo "INFO: Statistical anomaly detection not available in core. Install anomaly plugin." >&2
  return 1
}

detect_trend_anomaly() {
  echo "INFO: Trend analysis not available in core. Install anomaly plugin." >&2
  return 1
}

detect_spike_anomaly() {
  echo "INFO: Spike detection not available in core. Install anomaly plugin." >&2
  return 1
}

anomaly_parse_config() {
  echo "INFO: Advanced configuration not available in core. Install anomaly plugin." >&2
  return 1
}

anomaly_get_config_value() {
  local key="$2"
  local default="$3"

  # Only support basic configuration
  case "$key" in
  "enabled") echo "${ANOMALY_ENABLED}" ;;
  "threshold") echo "${ANOMALY_SIMPLE_THRESHOLD}" ;;
  *) echo "${default}" ;;
  esac
}

anomaly_should_send_notification() {
  echo "INFO: Advanced notifications not available in core. Install anomaly plugin." >&2
  return 1
}

anomaly_get_consecutive_count() {
  echo "0"
}

anomaly_send_notification() {
  echo "INFO: Anomaly notifications not available in core. Install anomaly plugin." >&2
  return 1
}

# Export functions for backward compatibility
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_system_init
  export -f anomaly_run_detection
  export -f store_metric_data
  export -f calculate_statistics
  export -f detect_statistical_anomaly
  export -f detect_trend_anomaly
  export -f detect_spike_anomaly
  export -f anomaly_parse_config
  export -f anomaly_get_config_value
  export -f anomaly_should_send_notification
  export -f anomaly_get_consecutive_count
  export -f anomaly_send_notification
fi

# Auto-initialize
if [[ "${ANOMALY_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if anomaly_system_init; then
    export ANOMALY_SYSTEM_INITIALIZED=true
  fi
fi
