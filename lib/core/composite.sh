#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check System
#
# This module handles composite checks with logical operators (AND, OR, NOT)
# Allows creating complex monitoring rules like "CPU > 80% AND Memory > 90%"

# Source logging module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
COMPOSITE_BASE_DIR="${BASE_DIR:-$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)}"

# Check if logging functions exist, if not try to source or provide fallbacks
if ! declare -f log_debug >/dev/null 2>&1; then
  if [ -f "${COMPOSITE_BASE_DIR}/lib/core/logging.sh" ]; then
    source "${COMPOSITE_BASE_DIR}/lib/core/logging.sh"
  fi

  # If still not available, provide fallback functions
  if ! declare -f log_debug >/dev/null 2>&1; then
    log_debug() { echo "[DEBUG] $1" >&2; }
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
  fi
fi

# Composite check configuration
COMPOSITE_CONFIG_DIR="${COMPOSITE_BASE_DIR}/config/composite"
COMPOSITE_RESULTS_DIR="${COMPOSITE_BASE_DIR}/logs/composite"

# Initialize composite check system
init_composite_system() {
  log_debug "Initializing composite check system"

  # Create directories if they don't exist
  if [ ! -d "$COMPOSITE_CONFIG_DIR" ]; then
    mkdir -p "$COMPOSITE_CONFIG_DIR"
    log_debug "Created composite config directory: $COMPOSITE_CONFIG_DIR"
  fi

  if [ ! -d "$COMPOSITE_RESULTS_DIR" ]; then
    mkdir -p "$COMPOSITE_RESULTS_DIR"
    log_debug "Created composite results directory: $COMPOSITE_RESULTS_DIR"
  fi

  # Create default composite checks if they don't exist
  create_default_composite_checks

  return 0
}

# Create default composite check examples
create_default_composite_checks() {
  # High resource usage composite check
  local high_usage_check="$COMPOSITE_CONFIG_DIR/high_resource_usage.conf"
  if [ ! -f "$high_usage_check" ]; then
    cat >"$high_usage_check" <<'EOF'
# High Resource Usage Composite Check
# Triggers when CPU > 80% AND Memory > 85%

name="High Resource Usage Alert"
description="Alerts when both CPU and memory are critically high"
enabled=true
severity=2
cooldown=300

# Rule: CPU > 80% AND Memory > 85%
rule="cpu.value > 80 AND memory.value > 85"

# Notification settings
notify_on_trigger=true
notify_on_recovery=true
notification_message="Critical: High resource usage detected - CPU: {cpu.value}%, Memory: {memory.value}%"
EOF
    log_debug "Created default high resource usage composite check"
  fi

  # System overload composite check
  local overload_check="$COMPOSITE_CONFIG_DIR/system_overload.conf"
  if [ ! -f "$overload_check" ]; then
    cat >"$overload_check" <<'EOF'
# System Overload Composite Check
# Triggers when (CPU > 90% OR Memory > 95%) AND Disk > 90%

name="System Overload Alert"
description="Alerts when system is critically overloaded"
enabled=true
severity=2
cooldown=600

# Rule: (CPU > 90% OR Memory > 95%) AND Disk > 90%
rule="(cpu.value > 90 OR memory.value > 95) AND disk.value > 90"

# Notification settings
notify_on_trigger=true
notify_on_recovery=true
notification_message="CRITICAL: System overload detected - CPU: {cpu.value}%, Memory: {memory.value}%, Disk: {disk.value}%"
EOF
    log_debug "Created default system overload composite check"
  fi

  # Maintenance mode composite check
  local maintenance_check="$COMPOSITE_CONFIG_DIR/maintenance_mode.conf"
  if [ ! -f "$maintenance_check" ]; then
    cat >"$maintenance_check" <<'EOF'
# Maintenance Mode Composite Check
# Only alerts on critical issues during maintenance

name="Maintenance Mode Alert"
description="Reduced sensitivity alerts for maintenance periods"
enabled=false
severity=2
cooldown=900

# Rule: CPU > 95% OR Memory > 98% OR Disk > 95%
rule="cpu.value > 95 OR memory.value > 98 OR disk.value > 95"

# Notification settings
notify_on_trigger=true
notify_on_recovery=false
notification_message="MAINTENANCE ALERT: Critical threshold exceeded - {triggered_conditions}"
EOF
    log_debug "Created default maintenance mode composite check"
  fi
}

# Parse composite check configuration
parse_composite_config() {
  local config_file="$1"

  if [ ! -f "$config_file" ]; then
    log_error "Composite config file not found: $config_file"
    return 1
  fi

  # Clear previous values
  unset name description enabled severity cooldown rule
  unset notify_on_trigger notify_on_recovery notification_message

  # Source the configuration file
  source "$config_file"

  # Validate required fields
  if [ -z "$name" ] || [ -z "$rule" ]; then
    log_error "Composite check missing required fields (name, rule): $config_file"
    return 1
  fi

  # Set defaults
  enabled="${enabled:-true}"
  severity="${severity:-1}"
  cooldown="${cooldown:-300}"
  notify_on_trigger="${notify_on_trigger:-true}"
  notify_on_recovery="${notify_on_recovery:-false}"

  return 0
}

# Evaluate a composite rule
evaluate_composite_rule() {
  local rule="$1"
  local plugin_results="$2" # JSON string with plugin results

  log_debug "Evaluating composite rule: $rule" "composite"

  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required for composite checks" "composite"
    return 1
  fi

  # Extract plugin values from results
  local cpu_value memory_value disk_value process_value
  cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // 0')
  memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // 0')
  disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // 0')
  process_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="process") | .metrics.count // 0')

  # Replace plugin references in rule with actual values
  local eval_rule="$rule"
  eval_rule="${eval_rule//cpu.value/$cpu_value}"
  eval_rule="${eval_rule//memory.value/$memory_value}"
  eval_rule="${eval_rule//disk.value/$disk_value}"
  eval_rule="${eval_rule//process.count/$process_value}"

  # Convert comparison operators to arithmetic evaluation format
  # Replace > with -gt to avoid file redirection
  eval_rule="${eval_rule// > / -gt }"
  eval_rule="${eval_rule// < / -lt }"
  eval_rule="${eval_rule// >= / -ge }"
  eval_rule="${eval_rule// <= / -le }"
  eval_rule="${eval_rule// == / -eq }"
  eval_rule="${eval_rule// != / -ne }"

  # Convert logical operators to bash equivalents
  eval_rule="${eval_rule// AND / && }"
  eval_rule="${eval_rule// OR / || }"
  eval_rule="${eval_rule// NOT / ! }"

  log_debug "Transformed rule: $eval_rule" "composite"

  # Evaluate the rule by splitting on logical operators and evaluating each part
  if command -v bc >/dev/null 2>&1; then
    # Handle complex expressions with logical operators
    local final_result

    if [[ "$eval_rule" == *"&&"* ]]; then
      # Handle AND operations - split on && and all parts must be true
      local temp_rule="$eval_rule"
      final_result=1
      while [[ "$temp_rule" == *" && "* ]]; do
        # Extract the first part before &&
        local part="${temp_rule%% && *}"
        # Remove the processed part from temp_rule
        temp_rule="${temp_rule#* && }"

        # Clean up the part and convert to bc-compatible format
        part=$(echo "$part" | sed 's/^ *//; s/ *$//')
        part="${part// -gt / > }"
        part="${part// -lt / < }"
        part="${part// -ge / >= }"
        part="${part// -le / <= }"
        part="${part// -eq / == }"
        part="${part// -ne / != }"

        # Evaluate this part with bc
        local part_result
        part_result=$(echo "$part" | bc 2>/dev/null || echo "0")

        if [[ "$part_result" != "1" ]]; then
          final_result=0
          break
        fi
      done

      # Process the last part if we haven't failed
      if [[ "$final_result" == "1" ]]; then
        local part="$temp_rule"
        part=$(echo "$part" | sed 's/^ *//; s/ *$//')
        part="${part// -gt / > }"
        part="${part// -lt / < }"
        part="${part// -ge / >= }"
        part="${part// -le / <= }"
        part="${part// -eq / == }"
        part="${part// -ne / != }"

        local part_result
        part_result=$(echo "$part" | bc 2>/dev/null || echo "0")

        if [[ "$part_result" != "1" ]]; then
          final_result=0
        fi
      fi

    elif [[ "$eval_rule" == *"||"* ]]; then
      # Handle OR operations - split on || and any part can be true
      local temp_rule="$eval_rule"
      final_result=0
      while [[ "$temp_rule" == *" || "* ]]; do
        # Extract the first part before ||
        local part="${temp_rule%% || *}"
        # Remove the processed part from temp_rule
        temp_rule="${temp_rule#* || }"

        # Clean up the part and convert to bc-compatible format
        part=$(echo "$part" | sed 's/^ *//; s/ *$//')
        part="${part// -gt / > }"
        part="${part// -lt / < }"
        part="${part// -ge / >= }"
        part="${part// -le / <= }"
        part="${part// -eq / == }"
        part="${part// -ne / != }"

        # Evaluate this part with bc
        local part_result
        part_result=$(echo "$part" | bc 2>/dev/null || echo "0")

        if [[ "$part_result" == "1" ]]; then
          final_result=1
          break
        fi
      done

      # Process the last part if we haven't succeeded
      if [[ "$final_result" == "0" ]]; then
        local part="$temp_rule"
        part=$(echo "$part" | sed 's/^ *//; s/ *$//')
        part="${part// -gt / > }"
        part="${part// -lt / < }"
        part="${part// -ge / >= }"
        part="${part// -le / <= }"
        part="${part// -eq / == }"
        part="${part// -ne / != }"

        local part_result
        part_result=$(echo "$part" | bc 2>/dev/null || echo "0")

        if [[ "$part_result" == "1" ]]; then
          final_result=1
        fi
      fi

    else
      # Simple comparison without logical operators
      local bc_rule="$eval_rule"
      bc_rule="${bc_rule// -gt / > }"
      bc_rule="${bc_rule// -lt / < }"
      bc_rule="${bc_rule// -ge / >= }"
      bc_rule="${bc_rule// -le / <= }"
      bc_rule="${bc_rule// -eq / == }"
      bc_rule="${bc_rule// -ne / != }"

      final_result=$(echo "$bc_rule" | bc 2>/dev/null || echo "0")
    fi

  else
    # Fallback: use bash arithmetic evaluation for integer comparisons
    if eval "[[ $eval_rule ]]" 2>/dev/null; then
      final_result=1
    else
      final_result=0
    fi
  fi

  if [[ "$final_result" == "1" ]]; then
    log_debug "Composite rule evaluated to TRUE" "composite"
    return 0 # Rule matched
  else
    log_debug "Composite rule evaluated to FALSE" "composite"
    return 1 # Rule not matched
  fi
}

# Get triggered conditions for a rule
get_triggered_conditions() {
  local rule="$1"
  local plugin_results="$2"
  local conditions=""

  if ! command -v jq >/dev/null 2>&1; then
    echo "Unable to determine conditions"
    return
  fi

  # Extract values
  local cpu_value memory_value disk_value
  cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // 0')
  memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // 0')
  disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // 0')

  # Check individual conditions using safe numeric comparison
  if [[ "$rule" == *"cpu.value"* ]] && echo "$rule" | grep -q "cpu\.value > [0-9]*"; then
    local threshold=$(echo "$rule" | grep -o "cpu\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if [[ $(echo "$cpu_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="CPU: ${cpu_value}% (>${threshold}%) "
    fi
  fi

  if [[ "$rule" == *"memory.value"* ]] && echo "$rule" | grep -q "memory\.value > [0-9]*"; then
    local threshold=$(echo "$rule" | grep -o "memory\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if [[ $(echo "$memory_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="Memory: ${memory_value}% (>${threshold}%) "
    fi
  fi

  if [[ "$rule" == *"disk.value"* ]] && echo "$rule" | grep -q "disk\.value > [0-9]*"; then
    local threshold=$(echo "$rule" | grep -o "disk\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if [[ $(echo "$disk_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="Disk: ${disk_value}% (>${threshold}%) "
    fi
  fi

  echo "${conditions:-Unknown conditions}"
}

# Check if composite check is in cooldown
is_in_cooldown() {
  local check_name="$1"
  local cooldown_seconds="$2"
  local state_file="$COMPOSITE_RESULTS_DIR/${check_name}.state"

  if [ ! -f "$state_file" ]; then
    return 1 # No previous state, not in cooldown
  fi

  local last_trigger
  last_trigger=$(grep "last_trigger=" "$state_file" 2>/dev/null | cut -d'=' -f2)

  if [ -z "$last_trigger" ]; then
    return 1 # No valid timestamp
  fi

  local current_time
  current_time=$(date +%s)
  local time_diff=$((current_time - last_trigger))

  if [ "$time_diff" -lt "$cooldown_seconds" ]; then
    log_debug "Composite check '$check_name' is in cooldown (${time_diff}s / ${cooldown_seconds}s)"
    return 0 # In cooldown
  else
    return 1 # Not in cooldown
  fi
}

# Update composite check state
update_composite_state() {
  local check_name="$1"
  local state="$2" # triggered or recovered
  local state_file="$COMPOSITE_RESULTS_DIR/${check_name}.state"

  local timestamp
  timestamp=$(date +%s)

  # Create or update state file
  {
    echo "check_name=$check_name"
    echo "last_state=$state"
    echo "last_${state}=$timestamp"
    echo "updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } >"$state_file"

  log_debug "Updated composite check state: $check_name -> $state"
}

# Run a single composite check
run_composite_check() {
  local config_file="$1"
  local plugin_results="$2"

  # Parse configuration
  if ! parse_composite_config "$config_file"; then
    return 1
  fi

  # Skip if disabled
  if [ "$enabled" != "true" ]; then
    log_debug "Composite check disabled: $name"
    return 0
  fi

  # Check if in cooldown
  if is_in_cooldown "$name" "$cooldown"; then
    log_debug "Composite check in cooldown: $name"
    return 0
  fi

  # Evaluate the rule
  local rule_result
  if evaluate_composite_rule "$rule" "$plugin_results"; then
    rule_result="triggered"
  else
    rule_result="normal"
  fi

  # Get previous state
  local state_file="$COMPOSITE_RESULTS_DIR/${name}.state"
  local previous_state="normal"
  if [ -f "$state_file" ]; then
    previous_state=$(grep "last_state=" "$state_file" 2>/dev/null | cut -d'=' -f2)
    previous_state="${previous_state:-normal}"
  fi

  # Handle state transitions
  if [ "$rule_result" = "triggered" ] && [ "$previous_state" != "triggered" ]; then
    # New trigger
    log_info "Composite check triggered: $name"
    update_composite_state "$name" "triggered"

    if [ "$notify_on_trigger" = "true" ]; then
      send_composite_notification "$name" "$severity" "triggered" "$plugin_results"
    fi

  elif [ "$rule_result" = "normal" ] && [ "$previous_state" = "triggered" ]; then
    # Recovery
    log_info "Composite check recovered: $name"
    update_composite_state "$name" "recovered"

    if [ "$notify_on_recovery" = "true" ]; then
      send_composite_notification "$name" 0 "recovered" "$plugin_results"
    fi
  fi

  # Return JSON result
  local triggered_conditions
  triggered_conditions=$(get_triggered_conditions "$rule" "$plugin_results")

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

# Send notification for composite check
send_composite_notification() {
  local check_name="$1"
  local severity="$2"
  local state="$3" # triggered or recovered
  local plugin_results="$4"

  local message="$notification_message"
  if [ -z "$message" ]; then
    if [ "$state" = "triggered" ]; then
      message="Composite check triggered: $check_name"
    else
      message="Composite check recovered: $check_name"
    fi
  fi

  # Replace variables in message
  local triggered_conditions
  triggered_conditions=$(get_triggered_conditions "$rule" "$plugin_results")

  if command -v jq >/dev/null 2>&1; then
    local cpu_value memory_value disk_value
    cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // "N/A"')
    memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // "N/A"')
    disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // "N/A"')

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
  if declare -f send_notification >/dev/null; then
    send_notification "$severity" "$message" "composite" "$composite_metrics"
  else
    log_warning "Notification system not available for composite check: $check_name"
  fi
}

# Run all enabled composite checks
run_all_composite_checks() {
  local plugin_results="$1"

  if [ -z "$plugin_results" ]; then
    log_error "No plugin results provided to composite checks"
    return 1
  fi

  log_debug "Running all composite checks"

  local composite_results="[]"

  # Process all composite check configuration files
  for config_file in "$COMPOSITE_CONFIG_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
      local check_result
      check_result=$(run_composite_check "$config_file" "$plugin_results" 2>/dev/null)

      if [ $? -eq 0 ] && [ -n "$check_result" ]; then
        # Add to results array
        composite_results=$(echo "$composite_results" | jq ". += [$check_result]" 2>/dev/null || echo "$composite_results")
      fi
    fi
  done

  # Output final results
  echo "{\"composite_checks\": $composite_results}"
}

# List all composite checks
list_composite_checks() {
  echo "Composite Checks:"
  echo "=================="

  for config_file in "$COMPOSITE_CONFIG_DIR"/*.conf; do
    if [ -f "$config_file" ]; then
      if parse_composite_config "$config_file"; then
        local status
        if [ "$enabled" = "true" ]; then
          status="✅ Enabled"
        else
          status="❌ Disabled"
        fi

        echo "Name: $name"
        echo "Status: $status"
        echo "Rule: $rule"
        echo "Severity: $severity"
        echo "Cooldown: ${cooldown}s"
        echo "Config: $(basename "$config_file")"
        echo "---"
      fi
    fi
  done
}

# Export functions for use by other modules
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f init_composite_system
  export -f parse_composite_config
  export -f evaluate_composite_rule
  export -f run_composite_check
  export -f run_all_composite_checks
  export -f list_composite_checks
fi
