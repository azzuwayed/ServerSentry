#!/usr/bin/env bash
#
# ServerSentry Environment Bootstrap
#
# Central environment management for the entire ServerSentry project.
# This file should be sourced by all scripts to ensure consistent paths,
# environment variables, and common functionality.

# Prevent multiple sourcing
if [[ "${SERVERSENTRY_ENV_LOADED:-}" == "true" ]]; then
  return 0
fi

# =============================================================================
# BOOTSTRAP CONTROL VARIABLES
# =============================================================================

# Control variables for bootstrap behavior
# These can be set before sourcing this file to control initialization
SERVERSENTRY_QUIET="${SERVERSENTRY_QUIET:-false}"
SERVERSENTRY_AUTO_INIT="${SERVERSENTRY_AUTO_INIT:-true}"
SERVERSENTRY_INIT_LEVEL="${SERVERSENTRY_INIT_LEVEL:-standard}"

export SERVERSENTRY_QUIET SERVERSENTRY_AUTO_INIT SERVERSENTRY_INIT_LEVEL

# =============================================================================
# CORE ENVIRONMENT SETUP
# =============================================================================

# Determine ServerSentry root directory
if [[ -z "${SERVERSENTRY_ROOT:-}" ]]; then
  # Try multiple methods to find the root
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Called via source
    SERVERSENTRY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -f "serversentry-env.sh" ]]; then
    # Called from root directory
    SERVERSENTRY_ROOT="$(pwd)"
  elif [[ -f "../serversentry-env.sh" ]]; then
    # Called from subdirectory
    SERVERSENTRY_ROOT="$(cd .. && pwd)"
  elif [[ -f "../../serversentry-env.sh" ]]; then
    # Called from sub-subdirectory
    SERVERSENTRY_ROOT="$(cd ../.. && pwd)"
  else
    # Search upward for the root
    current_dir="$(pwd)"
    while [[ "$current_dir" != "/" ]]; do
      if [[ -f "$current_dir/serversentry-env.sh" ]]; then
        SERVERSENTRY_ROOT="$current_dir"
        break
      fi
      current_dir="$(dirname "$current_dir")"
    done
  fi

  # Validate we found the root
  if [[ -z "$SERVERSENTRY_ROOT" || ! -f "$SERVERSENTRY_ROOT/serversentry-env.sh" ]]; then
    echo "❌ ERROR: Could not locate ServerSentry root directory" >&2
    echo "   Please run from within the ServerSentry project or set SERVERSENTRY_ROOT" >&2
    return 1
  fi

  export SERVERSENTRY_ROOT
fi

# =============================================================================
# STANDARD DIRECTORY PATHS
# =============================================================================

# Core directories
export SERVERSENTRY_LIB_DIR="${SERVERSENTRY_ROOT}/lib"
export SERVERSENTRY_CORE_DIR="${SERVERSENTRY_ROOT}/lib/core"
export SERVERSENTRY_UTILS_DIR="${SERVERSENTRY_ROOT}/lib/core/utils"
export SERVERSENTRY_PLUGINS_DIR="${SERVERSENTRY_ROOT}/lib/plugins"
export SERVERSENTRY_NOTIFICATIONS_DIR="${SERVERSENTRY_ROOT}/lib/notifications"
export SERVERSENTRY_UI_DIR="${SERVERSENTRY_ROOT}/lib/ui"

# Configuration and data
export SERVERSENTRY_CONFIG_DIR="${SERVERSENTRY_ROOT}/config"
export SERVERSENTRY_DOCS_DIR="${SERVERSENTRY_ROOT}/docs"
export SERVERSENTRY_TESTS_DIR="${SERVERSENTRY_ROOT}/tests"
export SERVERSENTRY_TOOLS_DIR="${SERVERSENTRY_ROOT}/tools"

# Runtime directories
export SERVERSENTRY_LOGS_DIR="${SERVERSENTRY_ROOT}/logs"
export SERVERSENTRY_TMP_DIR="${SERVERSENTRY_ROOT}/tmp"
export SERVERSENTRY_DATA_DIR="${SERVERSENTRY_ROOT}/data"

# Main executable
export SERVERSENTRY_BIN="${SERVERSENTRY_ROOT}/bin/serversentry"

# =============================================================================
# CORE LIBRARY LOADING
# =============================================================================

# Function: serversentry_load_minimal
# Description: Load only essential ServerSentry libraries for minimal mode
# Parameters: None
# Returns: 0 on success, 1 on failure
serversentry_load_minimal() {
  # Initialize basic logging constants first (before loading any modules)
  if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARNING=2
    readonly LOG_LEVEL_ERROR=3
    readonly LOG_LEVEL_CRITICAL=4
    export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_CRITICAL

    # Set default log level
    CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
    export CURRENT_LOG_LEVEL

    # Set basic log paths
    LOG_DIR="${SERVERSENTRY_LOGS_DIR}"
    LOG_FILE="${LOG_DIR}/serversentry.log"
    export LOG_DIR LOG_FILE
  fi

  # In minimal mode, only load absolutely essential libraries
  local minimal_libs=(
    "logging.sh"
  )

  for lib in "${minimal_libs[@]}"; do
    local lib_path="${SERVERSENTRY_CORE_DIR}/${lib}"
    if [[ -f "$lib_path" ]]; then
      # shellcheck source=/dev/null
      source "$lib_path" || {
        echo "❌ ERROR: Failed to load minimal library: $lib" >&2
        return 1
      }
    else
      echo "⚠️  WARNING: Minimal library not found: $lib_path" >&2
    fi
  done

  return 0
}

# Function: serversentry_load_core
# Description: Load core ServerSentry libraries
# Parameters: None
# Returns: 0 on success, 1 on failure
serversentry_load_core() {
  # Initialize basic logging constants first (before loading any modules)
  if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARNING=2
    readonly LOG_LEVEL_ERROR=3
    readonly LOG_LEVEL_CRITICAL=4
    export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_CRITICAL

    # Set default log level
    CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
    export CURRENT_LOG_LEVEL

    # Set basic log paths
    LOG_DIR="${SERVERSENTRY_LOGS_DIR}"
    LOG_FILE="${LOG_DIR}/serversentry.log"
    export LOG_DIR LOG_FILE
  fi

  # Load in dependency order: logging first, then utils, then config, then diagnostics
  # Skip error_handling.sh for now due to circular dependencies
  local core_libs=(
    "logging.sh"
    "utils.sh"
    "config.sh"
    "diagnostics.sh"
  )

  for lib in "${core_libs[@]}"; do
    local lib_path="${SERVERSENTRY_CORE_DIR}/${lib}"
    if [[ -f "$lib_path" ]]; then
      # shellcheck source=/dev/null
      source "$lib_path" || {
        echo "❌ ERROR: Failed to load core library: $lib" >&2
        return 1
      }
    else
      echo "⚠️  WARNING: Core library not found: $lib_path" >&2
    fi
  done

  return 0
}

# Function: serversentry_load_module
# Description: Load a specific ServerSentry module
# Parameters:
#   $1 (string): module name (e.g., "plugin", "notification")
# Returns: 0 on success, 1 on failure
serversentry_load_module() {
  if [[ $# -ne 1 ]]; then
    echo "❌ ERROR: serversentry_load_module requires exactly 1 parameter" >&2
    return 1
  fi

  local module="$1"
  local module_path="${SERVERSENTRY_CORE_DIR}/${module}.sh"

  if [[ -f "$module_path" ]]; then
    # shellcheck source=/dev/null
    source "$module_path" || {
      echo "❌ ERROR: Failed to load module: $module" >&2
      return 1
    }
  else
    echo "❌ ERROR: Module not found: $module_path" >&2
    return 1
  fi

  return 0
}

# Function: serversentry_load_utility
# Description: Load a specific utility module
# Parameters:
#   $1 (string): utility name (e.g., "string_utils", "file_utils")
# Returns: 0 on success, 1 on failure
serversentry_load_utility() {
  if [[ $# -ne 1 ]]; then
    echo "❌ ERROR: serversentry_load_utility requires exactly 1 parameter" >&2
    return 1
  fi

  local utility="$1"
  local utility_path="${SERVERSENTRY_UTILS_DIR}/${utility}.sh"

  if [[ -f "$utility_path" ]]; then
    # shellcheck source=/dev/null
    source "$utility_path" || {
      echo "❌ ERROR: Failed to load utility: $utility" >&2
      return 1
    }
  else
    echo "❌ ERROR: Utility not found: $utility_path" >&2
    return 1
  fi

  return 0
}

# =============================================================================
# PATH RESOLUTION UTILITIES
# =============================================================================

# Function: serversentry_resolve_path
# Description: Resolve a path relative to ServerSentry root
# Parameters:
#   $1 (string): relative path from root
# Returns: absolute path via stdout
serversentry_resolve_path() {
  if [[ $# -ne 1 ]]; then
    echo "❌ ERROR: serversentry_resolve_path requires exactly 1 parameter" >&2
    return 1
  fi

  local rel_path="$1"
  echo "${SERVERSENTRY_ROOT}/${rel_path}"
}

# Function: serversentry_get_relative_path
# Description: Get relative path from ServerSentry root
# Parameters:
#   $1 (string): absolute path
# Returns: relative path via stdout
serversentry_get_relative_path() {
  if [[ $# -ne 1 ]]; then
    echo "❌ ERROR: serversentry_get_relative_path requires exactly 1 parameter" >&2
    return 1
  fi

  local abs_path="$1"
  echo "${abs_path#"$SERVERSENTRY_ROOT"/}"
}

# Function: serversentry_find_script
# Description: Find a script in the ServerSentry project
# Parameters:
#   $1 (string): script name
# Returns: full path via stdout, or empty if not found
serversentry_find_script() {
  if [[ $# -ne 1 ]]; then
    echo "❌ ERROR: serversentry_find_script requires exactly 1 parameter" >&2
    return 1
  fi

  local script_name="$1"
  local search_dirs=(
    "${SERVERSENTRY_ROOT}"
    "${SERVERSENTRY_TOOLS_DIR}"
    "${SERVERSENTRY_CORE_DIR}"
    "${SERVERSENTRY_BIN%/*}"
  )

  for dir in "${search_dirs[@]}"; do
    if [[ -f "$dir/$script_name" ]]; then
      echo "$dir/$script_name"
      return 0
    fi
  done

  # Search recursively in tools directory
  local found_script
  found_script=$(find "${SERVERSENTRY_TOOLS_DIR}" -name "$script_name" -type f 2>/dev/null | head -1)
  if [[ -n "$found_script" ]]; then
    echo "$found_script"
    return 0
  fi

  return 1
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

# Function: serversentry_validate_environment
# Description: Validate the ServerSentry environment
# Parameters: None
# Returns: 0 if valid, 1 if invalid
serversentry_validate_environment() {
  local errors=0

  # Check required directories (only essential ones)
  local required_dirs=(
    "$SERVERSENTRY_LIB_DIR"
    "$SERVERSENTRY_CORE_DIR"
  )

  for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      echo "❌ ERROR: Required directory not found: $dir" >&2
      ((errors++))
    fi
  done

  # Check core libraries (only if they should exist)
  local core_libs=(
    "${SERVERSENTRY_CORE_DIR}/logging.sh"
    "${SERVERSENTRY_CORE_DIR}/utils.sh"
  )

  for lib in "${core_libs[@]}"; do
    if [[ ! -f "$lib" ]]; then
      echo "⚠️  WARNING: Core library not found: $lib" >&2
      # Don't count as error - some environments might not have all libraries
    fi
  done

  if [[ $errors -gt 0 ]]; then
    echo "❌ Environment validation failed with $errors errors" >&2
    return 1
  fi

  return 0
}

# =============================================================================
# COMMON UTILITIES
# =============================================================================

# Function: serversentry_log
# Description: Centralized logging function with quiet mode support
# Parameters:
#   $1 (string): log level (INFO, WARN, ERROR, SUCCESS)
#   $2 (string): message
# Returns: 0 on success
serversentry_log() {
  if [[ $# -ne 2 ]]; then
    echo "❌ ERROR: serversentry_log requires exactly 2 parameters" >&2
    return 1
  fi

  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Respect quiet mode - only show errors in quiet mode
  if [[ "${SERVERSENTRY_QUIET}" == "true" && "$level" != "ERROR" ]]; then
    return 0
  fi

  # Colors (use different variable names to avoid conflicts)
  local LOG_RED='\033[0;31m'
  local LOG_GREEN='\033[0;32m'
  local LOG_YELLOW='\033[1;33m'
  local LOG_BLUE='\033[0;34m'
  local LOG_NC='\033[0m'

  case "$level" in
  "INFO")
    echo -e "${LOG_BLUE}ℹ️  [$timestamp] $message${LOG_NC}"
    ;;
  "WARN")
    echo -e "${LOG_YELLOW}⚠️  [$timestamp] $message${LOG_NC}"
    ;;
  "ERROR")
    echo -e "${LOG_RED}❌ [$timestamp] $message${LOG_NC}" >&2
    ;;
  "SUCCESS")
    echo -e "${LOG_GREEN}✅ [$timestamp] $message${LOG_NC}"
    ;;
  *)
    echo "[$timestamp] $message"
    ;;
  esac
}

# Function: serversentry_create_runtime_dirs
# Description: Create runtime directories if they don't exist
# Parameters: None
# Returns: 0 on success
serversentry_create_runtime_dirs() {
  local runtime_dirs=(
    "$SERVERSENTRY_LOGS_DIR"
    "$SERVERSENTRY_TMP_DIR"
    "$SERVERSENTRY_DATA_DIR"
  )

  for dir in "${runtime_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        serversentry_log "ERROR" "Failed to create runtime directory: $dir"
        return 1
      fi
    fi
  done

  return 0
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Function: serversentry_init
# Description: Initialize the ServerSentry environment
# Parameters:
#   $1 (string): initialization level (minimal, standard, full)
# Returns: 0 on success, 1 on failure
serversentry_init() {
  local init_level="${1:-standard}"

  # Validate environment
  if ! serversentry_validate_environment; then
    return 1
  fi

  # Create runtime directories
  if ! serversentry_create_runtime_dirs; then
    return 1
  fi

  case "$init_level" in
  "minimal")
    # Just basic environment setup
    ;;
  "standard")
    # Load core libraries
    if ! serversentry_load_core; then
      serversentry_log "ERROR" "Failed to load core libraries"
      return 1
    fi
    ;;
  "full")
    # Load everything
    if ! serversentry_load_core; then
      serversentry_log "ERROR" "Failed to load core libraries"
      return 1
    fi

    # Load additional modules as needed
    local additional_modules=(
      "plugin"
      "notification"
      "composite"
    )

    for module in "${additional_modules[@]}"; do
      if [[ -f "${SERVERSENTRY_CORE_DIR}/${module}.sh" ]]; then
        serversentry_load_module "$module" || {
          serversentry_log "WARN" "Failed to load optional module: $module"
        }
      fi
    done
    ;;
  *)
    serversentry_log "ERROR" "Invalid initialization level: $init_level"
    return 1
    ;;
  esac

  return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export all functions for use in other scripts
export -f serversentry_load_minimal
export -f serversentry_load_core
export -f serversentry_load_module
export -f serversentry_load_utility
export -f serversentry_resolve_path
export -f serversentry_get_relative_path
export -f serversentry_find_script
export -f serversentry_validate_environment
export -f serversentry_log
export -f serversentry_create_runtime_dirs
export -f serversentry_init

# =============================================================================
# MARK AS LOADED AND AUTO-INITIALIZE
# =============================================================================

SERVERSENTRY_ENV_LOADED=true
export SERVERSENTRY_ENV_LOADED

# Backward compatibility - provide BASE_DIR alias
export BASE_DIR="$SERVERSENTRY_ROOT"

# Auto-initialize if enabled (default: true)
if [[ "${SERVERSENTRY_AUTO_INIT:-true}" == "true" ]]; then
  # Use the specified initialization level
  init_level="${SERVERSENTRY_INIT_LEVEL:-minimal}"

  if ! serversentry_init "$init_level"; then
    serversentry_log "ERROR" "Failed to auto-initialize ServerSentry environment (level: $init_level)"
    # Don't return 1 here as it would prevent the functions from being available
    # Just log the error and continue
  fi
fi

# Success message (only if not in quiet mode)
if [[ "${SERVERSENTRY_QUIET:-}" != "true" ]]; then
  serversentry_log "SUCCESS" "ServerSentry environment loaded (root: $SERVERSENTRY_ROOT)"
fi
