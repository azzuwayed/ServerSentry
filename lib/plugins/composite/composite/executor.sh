#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check Executor
#
# This module handles execution, state management, and notifications for composite checks

# Prevent multiple sourcing
if [[ "${COMPOSITE_EXECUTOR_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPOSITE_EXECUTOR_MODULE_LOADED=true
export COMPOSITE_EXECUTOR_MODULE_LOADED

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

# Configuration directories
COMPOSITE_CONFIG_DIR="${COMPOSITE_CONFIG_DIR:-${BASE_DIR}/config/composite}"
COMPOSITE_RESULTS_DIR="${COMPOSITE_RESULTS_DIR:-${BASE_DIR}/logs/composite}"

# Function: composite_is_in_cooldown
# Description: Check if composite check is in cooldown period
# Parameters:
#   $1 (string): check name
#   $2 (numeric): cooldown seconds
# Returns:
#   0 - in cooldown
#   1 - not in cooldown
# Example:
#   if composite_is_in_cooldown "high_usage" 300; then echo "In cooldown"; fi
# Dependencies:
#   - util_error_validate_input
composite_is_in_cooldown() {
  if ! util_error_validate_input "composite_is_in_cooldown" "2" "$#"; then
    return 1
  fi

  local check_name="$1"
  local cooldown_seconds="$2"
  local state_file="$COMPOSITE_RESULTS_DIR/${check_name}.state"

  if [[ ! -f "$state_file" ]]; then
    return 1 # No previous state, not in cooldown
  fi

  local last_trigger
  last_trigger=$(grep "last_trigger=" "$state_file" 2>/dev/null | cut -d'=' -f2)

  if [[ -z "$last_trigger" ]]; then
    return 1 # No valid timestamp
  fi

  local current_time
  current_time=$(date +%s)
  local time_diff=$((current_time - last_trigger))

  if [[ "$time_diff" -lt "$cooldown_seconds" ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Composite check '$check_name' is in cooldown (${time_diff}s / ${cooldown_seconds}s)" "composite"
    fi
    return 0 # In cooldown
  else
    return 1 # Not in cooldown
  fi
}

# Function: composite_update_state
# Description: Update composite check state file
# Parameters:
#   $1 (string): check name
#   $2 (string): state (triggered or recovered)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   composite_update_state "high_usage" "triggered"
# Dependencies:
#   - util_error_validate_input
composite_update_state() {
  if ! util_error_validate_input "composite_update_state" "2" "$#"; then
    return 1
  fi

  local check_name="$1"
  local state="$2" # triggered or recovered
  local state_file="$COMPOSITE_RESULTS_DIR/${check_name}.state"

  # Validate state parameter
  if [[ "$state" != "triggered" && "$state" != "recovered" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Invalid state: $state (must be 'triggered' or 'recovered')" "composite"
    fi
    return 1
  fi

  local timestamp
  timestamp=$(date +%s)

  # Create or update state file
  {
    echo "check_name=$check_name"
    echo "last_state=$state"
    echo "last_${state}=$timestamp"
    echo "updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } >"$state_file"

  if [[ $? -eq 0 ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Updated composite check state: $check_name -> $state" "composite"
    fi
    return 0
  else
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Failed to update composite check state: $check_name" "composite"
    fi
    return 1
  fi
}

# Function: composite_send_notification
# Description: Send notification for composite check state change
# Parameters:
#   $1 (string): check name
#   $2 (numeric): severity level
#   $3 (string): state (triggered or recovered)
#   $4 (string): plugin results JSON
# Returns:
#   0 - success
#   1 - failure
# Example:
#   composite_send_notification "high_usage" 2 "triggered" "$plugin_results"
# Dependencies:
#   - util_error_validate_input
#   - composite_get_triggered_conditions
composite_send_notification() {
  if ! util_error_validate_input "composite_send_notification" "4" "$#"; then
    return 1
  fi

  local check_name="$1"
  local severity="$2"
  local state="$3" # triggered or recovered
  local plugin_results="$4"

  local message="$notification_message"
  if [[ -z "$message" ]]; then
    if [[ "$state" == "triggered" ]]; then
      message="Composite check triggered: $check_name"
    else
      message="Composite check recovered: $check_name"
    fi
  fi

  # Replace variables in message
  local triggered_conditions
  if declare -f composite_get_triggered_conditions >/dev/null 2>&1; then
    triggered_conditions=$(composite_get_triggered_conditions "$rule" "$plugin_results")
  else
    triggered_conditions="Unknown conditions"
  fi

  if util_command_exists jq; then
    local cpu_value memory_value disk_value
    cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // "N/A"' 2>/dev/null || echo "N/A")
    memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // "N/A"' 2>/dev/null || echo "N/A")
    disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // "N/A"' 2>/dev/null || echo "N/A")

    message="${message//\{cpu.value\}/$cpu_value}"
    message="${message//\{memory.value\}/$memory_value}"
    message="${message//\{disk.value\}/$disk_value}"
    message="${message//\{triggered_conditions\}/$triggered_conditions}"
  fi

  # Create composite metrics for notification
  local composite_metrics
  composite_metrics=$(
    cat <<EOF
{
  "composite_check": "$check_name",
  "rule": "$rule",
  "state": "$state",
  "triggered_conditions": "$triggered_conditions"
}
EOF
  )

  # Send notification if notification system is available
  if declare -f send_notification >/dev/null 2>&1; then
    if send_notification "$severity" "$message" "composite" "$composite_metrics"; then
      if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Sent composite check notification: $check_name ($state)" "composite"
      fi
      return 0
    else
      if declare -f log_error >/dev/null 2>&1; then
        log_error "Failed to send composite check notification: $check_name" "composite"
      fi
      return 1
    fi
  else
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Notification system not available for composite check: $check_name" "composite"
    fi
    return 1
  fi
}

# Function: composite_run_single_check
# Description: Run a single composite check
# Parameters:
#   $1 (string): configuration file path
#   $2 (string): plugin results JSON
# Returns:
#   0 - success (outputs JSON result)
#   1 - failure
# Example:
#   result=$(composite_run_single_check "/path/to/config.conf" "$plugin_results")
# Dependencies:
#   - composite_config_parse
#   - composite_evaluate_rule
#   - composite_get_triggered_conditions
composite_run_single_check() {
  if ! util_error_validate_input "composite_run_single_check" "2" "$#"; then
    return 1
  fi

  local config_file="$1"
  local plugin_results="$2"

  # Parse configuration
  if ! composite_config_parse "$config_file"; then
    return 1
  fi

  # Skip if disabled
  if [[ "$enabled" != "true" ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Composite check disabled: $name" "composite"
    fi
    return 0
  fi

  # Check if in cooldown
  if composite_is_in_cooldown "$name" "$cooldown"; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Composite check in cooldown: $name" "composite"
    fi
    return 0
  fi

  # Evaluate the rule
  local rule_result
  if composite_evaluate_rule "$rule" "$plugin_results"; then
    rule_result="triggered"
  else
    rule_result="normal"
  fi

  # Get previous state
  local state_file="$COMPOSITE_RESULTS_DIR/${name}.state"
  local previous_state="normal"
  if [[ -f "$state_file" ]]; then
    previous_state=$(grep "last_state=" "$state_file" 2>/dev/null | cut -d'=' -f2)
    previous_state="${previous_state:-normal}"
  fi

  # Handle state transitions
  if [[ "$rule_result" == "triggered" && "$previous_state" != "triggered" ]]; then
    # New trigger
    if declare -f log_info >/dev/null 2>&1; then
      log_info "Composite check triggered: $name" "composite"
    fi
    composite_update_state "$name" "triggered"

    if [[ "$notify_on_trigger" == "true" ]]; then
      composite_send_notification "$name" "$severity" "triggered" "$plugin_results"
    fi

  elif [[ "$rule_result" == "normal" && "$previous_state" == "triggered" ]]; then
    # Recovery
    if declare -f log_info >/dev/null 2>&1; then
      log_info "Composite check recovered: $name" "composite"
    fi
    composite_update_state "$name" "recovered"

    if [[ "$notify_on_recovery" == "true" ]]; then
      composite_send_notification "$name" 0 "recovered" "$plugin_results"
    fi
  fi

  # Return JSON result
  local triggered_conditions
  if declare -f composite_get_triggered_conditions >/dev/null 2>&1; then
    triggered_conditions=$(composite_get_triggered_conditions "$rule" "$plugin_results")
  else
    triggered_conditions="Unknown conditions"
  fi

  cat <<EOF
{
  "name": "$name",
  "rule": "$rule",
  "result": "$rule_result",
  "previous_state": "$previous_state",
  "severity": $severity,
  "triggered_conditions": "$triggered_conditions",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Function: composite_run_all_checks
# Description: Run all enabled composite checks
# Parameters:
#   $1 (string): plugin results JSON
# Returns:
#   0 - success (outputs JSON results)
#   1 - failure
# Example:
#   results=$(composite_run_all_checks "$plugin_results")
# Dependencies:
#   - util_error_validate_input
#   - composite_run_single_check
composite_run_all_checks() {
  if ! util_error_validate_input "composite_run_all_checks" "1" "$#"; then
    return 1
  fi

  local plugin_results="$1"

  if [[ -z "$plugin_results" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "No plugin results provided to composite checks" "composite"
    fi
    return 1
  fi

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Running all composite checks" "composite"
  fi

  local composite_results="[]"

  # Process all composite check configuration files
  for config_file in "$COMPOSITE_CONFIG_DIR"/*.conf; do
    if [[ -f "$config_file" ]]; then
      local check_result
      check_result=$(composite_run_single_check "$config_file" "$plugin_results" 2>/dev/null)

      if [[ $? -eq 0 && -n "$check_result" ]]; then
        # Add to results array
        if util_command_exists jq; then
          composite_results=$(echo "$composite_results" | jq ". += [$check_result]" 2>/dev/null || echo "$composite_results")
        else
          # Fallback without jq
          composite_results="${composite_results%]}, $check_result]"
        fi
      fi
    fi
  done

  # Output final results
  echo "{\"composite_checks\": $composite_results}"
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f composite_is_in_cooldown
  export -f composite_update_state
  export -f composite_send_notification
  export -f composite_run_single_check
  export -f composite_run_all_checks
fi
