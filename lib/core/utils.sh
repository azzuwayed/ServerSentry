#!/usr/bin/env bash
#
# ServerSentry v2 - Unified Utilities Loader
#
# This module loads the unified utility framework for ServerSentry v2
# All legacy utility files have been consolidated into unified_utils.sh

# Prevent multiple sourcing
if [[ "${UTILS_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
UTILS_MODULE_LOADED=true
export UTILS_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# Function: init_utilities
# Description: Initialize the unified utility framework
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   init_utilities
# Dependencies: None
init_utilities() {
  # Use professional logging with utils component
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing unified utility framework" "utils"
  fi

  # Check if utilities directory exists
  if [[ ! -d "${SERVERSENTRY_UTILS_DIR}" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Utilities directory not found: ${SERVERSENTRY_UTILS_DIR}" "utils"
    else
      echo "❌ ERROR: Utilities directory not found: ${SERVERSENTRY_UTILS_DIR}" >&2
    fi
    return 1
  fi

  # Load the unified utility framework
  local unified_utils="${SERVERSENTRY_UTILS_DIR}/unified_utils.sh"

  if [[ ! -f "$unified_utils" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Unified utility framework not found: $unified_utils" "utils"
    else
      echo "❌ ERROR: Unified utility framework not found: $unified_utils" >&2
    fi
    return 1
  fi

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Loading unified utility framework" "utils"
  fi

  # Source the unified framework
  # shellcheck source=/dev/null
  if source "$unified_utils" 2>/dev/null; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Unified utility framework loaded successfully" "utils"
    fi
    return 0
  else
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Failed to load unified utility framework" "utils"
    else
      echo "❌ ERROR: Failed to load unified utility framework" >&2
    fi
    return 1
  fi
}

# Export utility functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Export main orchestration function
  export -f init_utilities
fi

# Auto-initialize utility modules
if ! init_utilities; then
  echo "❌ FATAL: Failed to initialize unified utility framework" >&2
  exit 1
fi
