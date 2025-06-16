#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check Rule Evaluator
#
# This module handles rule evaluation and condition analysis for composite checks

# Prevent multiple sourcing
if [[ "${COMPOSITE_EVALUATOR_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPOSITE_EVALUATOR_MODULE_LOADED=true
export COMPOSITE_EVALUATOR_MODULE_LOADED

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

# Function: composite_evaluate_rule
# Description: Evaluate a composite rule against plugin results
# Parameters:
#   $1 (string): rule to evaluate
#   $2 (string): plugin results JSON
# Returns:
#   0 - rule matched (triggered)
#   1 - rule not matched
# Example:
#   composite_evaluate_rule "cpu.value > 80 AND memory.value > 85" "$plugin_results"
# Dependencies:
#   - util_error_validate_input
#   - util_command_exists
composite_evaluate_rule() {
  if ! util_error_validate_input "composite_evaluate_rule" "2" "$#"; then
    return 1
  fi

  local rule="$1"
  local plugin_results="$2"

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Evaluating composite rule: $rule" "composite"
  fi

  if ! util_command_exists jq; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "jq is required for composite checks" "composite"
    fi
    return 1
  fi

  # Extract plugin values from results
  local cpu_value memory_value disk_value process_value
  cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // 0' 2>/dev/null || echo "0")
  memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // 0' 2>/dev/null || echo "0")
  disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // 0' 2>/dev/null || echo "0")
  process_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="process") | .metrics.count // 0' 2>/dev/null || echo "0")

  # Replace plugin references in rule with actual values
  local eval_rule="$rule"
  eval_rule="${eval_rule//cpu.value/$cpu_value}"
  eval_rule="${eval_rule//memory.value/$memory_value}"
  eval_rule="${eval_rule//disk.value/$disk_value}"
  eval_rule="${eval_rule//process.count/$process_value}"

  # Convert comparison operators to arithmetic evaluation format
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

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Transformed rule: $eval_rule" "composite"
  fi

  # Evaluate the rule
  local final_result
  if util_command_exists bc; then
    final_result=$(composite_evaluate_with_bc "$eval_rule")
  else
    final_result=$(composite_evaluate_with_bash "$eval_rule")
  fi

  if [[ "$final_result" == "1" ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Composite rule evaluated to TRUE" "composite"
    fi
    return 0 # Rule matched
  else
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Composite rule evaluated to FALSE" "composite"
    fi
    return 1 # Rule not matched
  fi
}

# Function: composite_evaluate_with_bc
# Description: Evaluate rule using bc for floating point arithmetic
# Parameters:
#   $1 (string): transformed rule
# Returns:
#   1 or 0 via stdout
# Example:
#   result=$(composite_evaluate_with_bc "$eval_rule")
# Dependencies:
#   - util_command_exists
composite_evaluate_with_bc() {
  local eval_rule="$1"
  local final_result

  if [[ "$eval_rule" == *"&&"* ]]; then
    # Handle AND operations - all parts must be true
    final_result=$(composite_evaluate_and_with_bc "$eval_rule")
  elif [[ "$eval_rule" == *"||"* ]]; then
    # Handle OR operations - any part can be true
    final_result=$(composite_evaluate_or_with_bc "$eval_rule")
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

  echo "$final_result"
}

# Function: composite_evaluate_and_with_bc
# Description: Evaluate AND operations using bc
# Parameters:
#   $1 (string): rule with AND operators
# Returns:
#   1 or 0 via stdout
# Example:
#   result=$(composite_evaluate_and_with_bc "$eval_rule")
# Dependencies: None
composite_evaluate_and_with_bc() {
  local temp_rule="$1"
  local final_result=1

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

  echo "$final_result"
}

# Function: composite_evaluate_or_with_bc
# Description: Evaluate OR operations using bc
# Parameters:
#   $1 (string): rule with OR operators
# Returns:
#   1 or 0 via stdout
# Example:
#   result=$(composite_evaluate_or_with_bc "$eval_rule")
# Dependencies: None
composite_evaluate_or_with_bc() {
  local temp_rule="$1"
  local final_result=0

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

  echo "$final_result"
}

# Function: composite_evaluate_with_bash
# Description: Evaluate rule using bash arithmetic (fallback)
# Parameters:
#   $1 (string): transformed rule
# Returns:
#   1 or 0 via stdout
# Example:
#   result=$(composite_evaluate_with_bash "$eval_rule")
# Dependencies: None
composite_evaluate_with_bash() {
  local eval_rule="$1"

  # Fallback: use bash arithmetic evaluation for integer comparisons
  if eval "[[ $eval_rule ]]" 2>/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

# Function: composite_get_triggered_conditions
# Description: Get human-readable description of triggered conditions
# Parameters:
#   $1 (string): rule
#   $2 (string): plugin results JSON
# Returns:
#   Triggered conditions description via stdout
# Example:
#   conditions=$(composite_get_triggered_conditions "$rule" "$plugin_results")
# Dependencies:
#   - util_error_validate_input
#   - util_command_exists
composite_get_triggered_conditions() {
  if ! util_error_validate_input "composite_get_triggered_conditions" "2" "$#"; then
    return 1
  fi

  local rule="$1"
  local plugin_results="$2"
  local conditions=""

  if ! util_command_exists jq; then
    echo "Unable to determine conditions"
    return 0
  fi

  # Extract values
  local cpu_value memory_value disk_value
  cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // 0' 2>/dev/null || echo "0")
  memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // 0' 2>/dev/null || echo "0")
  disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // 0' 2>/dev/null || echo "0")

  # Check individual conditions using safe numeric comparison
  if [[ "$rule" == *"cpu.value"* ]] && echo "$rule" | grep -q "cpu\.value > [0-9]*"; then
    local threshold
    threshold=$(echo "$rule" | grep -o "cpu\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if util_command_exists bc && [[ $(echo "$cpu_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="CPU: ${cpu_value}% (>${threshold}%) "
    elif [[ ! $(util_command_exists bc) ]] && [[ $(echo "$cpu_value > $threshold" | awk '{print ($1 > $3)}') -eq 1 ]]; then
      conditions+="CPU: ${cpu_value}% (>${threshold}%) "
    fi
  fi

  if [[ "$rule" == *"memory.value"* ]] && echo "$rule" | grep -q "memory\.value > [0-9]*"; then
    local threshold
    threshold=$(echo "$rule" | grep -o "memory\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if util_command_exists bc && [[ $(echo "$memory_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="Memory: ${memory_value}% (>${threshold}%) "
    elif [[ ! $(util_command_exists bc) ]] && [[ $(echo "$memory_value > $threshold" | awk '{print ($1 > $3)}') -eq 1 ]]; then
      conditions+="Memory: ${memory_value}% (>${threshold}%) "
    fi
  fi

  if [[ "$rule" == *"disk.value"* ]] && echo "$rule" | grep -q "disk\.value > [0-9]*"; then
    local threshold
    threshold=$(echo "$rule" | grep -o "disk\.value > [0-9]*" | grep -o "[0-9]*")
    # Use arithmetic comparison to avoid redirection
    if util_command_exists bc && [[ $(echo "$disk_value > $threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      conditions+="Disk: ${disk_value}% (>${threshold}%) "
    elif [[ ! $(util_command_exists bc) ]] && [[ $(echo "$disk_value > $threshold" | awk '{print ($1 > $3)}') -eq 1 ]]; then
      conditions+="Disk: ${disk_value}% (>${threshold}%) "
    fi
  fi

  echo "${conditions:-Unknown conditions}"
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f composite_evaluate_rule
  export -f composite_evaluate_with_bc
  export -f composite_evaluate_and_with_bc
  export -f composite_evaluate_or_with_bc
  export -f composite_evaluate_with_bash
  export -f composite_get_triggered_conditions
fi
