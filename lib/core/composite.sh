#!/usr/bin/env bash
#
# ServerSentry v2 - Composite Check Stub (Simplified Core Version)
#
# This is a simplified stub that provides basic composite check interface
# The full composite check system has been moved to optional plugins

# Prevent multiple sourcing
if [[ "${COMPOSITE_STUB_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPOSITE_STUB_LOADED=true
export COMPOSITE_STUB_LOADED

# Simple composite configuration
COMPOSITE_ENABLED="${COMPOSITE_ENABLED:-false}"
COMPOSITE_SIMPLE_RULES="${COMPOSITE_SIMPLE_RULES:-}"

# Function: composite_system_init
# Description: Initialize simplified composite checks (stub version)
# Parameters: None
# Returns: 0 - success, 1 - failure
composite_system_init() {
  if [[ "${COMPOSITE_ENABLED}" == "true" ]]; then
    echo "INFO: Basic composite checks enabled" >&2
  else
    echo "INFO: Composite checks disabled (use plugins for advanced features)" >&2
  fi
  return 0
}

# Function: run_all_composite_checks
# Description: Simple composite check runner (stub version)
# Parameters: $1 - plugin results JSON
# Returns: 0 - success
run_all_composite_checks() {
  local plugin_results="$1"

  if [[ "${COMPOSITE_ENABLED}" != "true" ]]; then
    echo '{"composite_checks": "disabled", "message": "Use composite plugin for advanced checks"}'
    return 0
  fi

  # Simple composite check - just return basic info
  echo '{"composite_checks": "basic", "message": "Basic composite checks only - install plugin for advanced features"}'
  return 0
}

# Function: run_composite_check
# Description: Simple single composite check (stub version)
# Parameters: $1 - config file, $2 - plugin results JSON
# Returns: 0 - success
run_composite_check() {
  local config_file="$1"
  local plugin_results="$2"

  echo '{"status": "basic", "message": "Install composite plugin for advanced composite checks"}'
  return 0
}

# Backward compatibility stubs - all return "not available" messages
init_composite_system() {
  composite_system_init
}

create_default_composite_checks() {
  echo "INFO: Advanced composite configuration not available in core. Install composite plugin." >&2
  return 1
}

parse_composite_config() {
  echo "INFO: Advanced configuration parsing not available in core. Install composite plugin." >&2
  return 1
}

evaluate_composite_rule() {
  echo "INFO: Advanced rule evaluation not available in core. Install composite plugin." >&2
  return 1
}

get_triggered_conditions() {
  echo "INFO: Advanced condition analysis not available in core. Install composite plugin." >&2
  return 1
}

is_in_cooldown() {
  echo "INFO: Cooldown management not available in core. Install composite plugin." >&2
  return 1
}

update_composite_state() {
  echo "INFO: State management not available in core. Install composite plugin." >&2
  return 1
}

send_composite_notification() {
  echo "INFO: Composite notifications not available in core. Install composite plugin." >&2
  return 1
}

list_composite_checks() {
  echo "Basic composite checks:"
  echo "======================"
  echo "For advanced composite checks, install the composite plugin."
}

# Export functions for backward compatibility
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f composite_system_init
  export -f run_all_composite_checks
  export -f run_composite_check
  export -f init_composite_system
  export -f create_default_composite_checks
  export -f parse_composite_config
  export -f evaluate_composite_rule
  export -f get_triggered_conditions
  export -f is_in_cooldown
  export -f update_composite_state
  export -f send_composite_notification
  export -f list_composite_checks
fi

# Auto-initialize
if [[ "${COMPOSITE_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  if composite_system_init; then
    export COMPOSITE_SYSTEM_INITIALIZED=true
  fi
fi
