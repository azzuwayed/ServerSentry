#!/usr/bin/env bash
#
# ServerSentry Unified Utility Framework
#
# This module consolidates all utility functions from individual utility files
# into a single, well-organized framework for better maintainability.
#
# Consolidates functions from:
# - array_utils.sh (18 functions)
# - command_utils.sh (15 functions)
# - compat_utils.sh (24 functions)
# - config_utils.sh (11 functions)
# - documentation_utils.sh (5 functions)
# - error_utils.sh (7 functions)
# - file_utils.sh (4 functions)
# - json_utils.sh (14 functions)
# - performance_utils.sh (9 functions)
# - string_utils.sh (4 functions)
# - system_utils.sh (5 functions)
# - validation_utils.sh (16 functions)

# Prevent multiple sourcing
if [[ "${UNIFIED_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
UNIFIED_UTILS_LOADED=true
export UNIFIED_UTILS_LOADED

# =============================================================================
# CORE VALIDATION FUNCTIONS (Most Used: 271 calls)
# =============================================================================

# Function: util_error_validate_input
# Description: Validate input parameters with error handling
# Parameters:
#   $1 (string): parameter name
#   $2 (string): parameter value
#   $3 (string): validation type (optional)
# Returns: 0 if valid, 1 if invalid
util_error_validate_input() {
  local param_name="$1"
  local param_value="$2"
  local validation_type="${3:-non_empty}"

  if [[ -z "$param_name" ]]; then
    echo "ERROR: Parameter name is required for validation" >&2
    return 1
  fi

  case "$validation_type" in
  "non_empty")
    if [[ -z "$param_value" ]]; then
      echo "ERROR: Parameter '$param_name' cannot be empty" >&2
      return 1
    fi
    ;;
  "numeric")
    if ! [[ "$param_value" =~ ^[0-9]+$ ]]; then
      echo "ERROR: Parameter '$param_name' must be numeric" >&2
      return 1
    fi
    ;;
  "file_exists")
    if [[ ! -f "$param_value" ]]; then
      echo "ERROR: File '$param_value' for parameter '$param_name' does not exist" >&2
      return 1
    fi
    ;;
  "dir_exists")
    if [[ ! -d "$param_value" ]]; then
      echo "ERROR: Directory '$param_value' for parameter '$param_name' does not exist" >&2
      return 1
    fi
    ;;
  *)
    echo "ERROR: Unknown validation type '$validation_type'" >&2
    return 1
    ;;
  esac

  return 0
}

# =============================================================================
# COMMAND UTILITIES (Most Used: 112 calls)
# =============================================================================

# Function: util_command_exists
# Description: Check if a command exists in the system
# Parameters:
#   $1 (string): command name
# Returns: 0 if command exists, 1 if not
util_command_exists() {
  if [[ $# -ne 1 ]]; then
    echo "ERROR: util_command_exists requires exactly 1 parameter" >&2
    return 1
  fi

  command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# ERROR HANDLING UTILITIES (Most Used: 108 calls)
# =============================================================================

# Function: util_error_safe_execute
# Description: Execute a command safely with error handling
# Parameters:
#   $@ (string): command to execute
# Returns: command exit code
util_error_safe_execute() {
  if [[ $# -eq 0 ]]; then
    echo "ERROR: util_error_safe_execute requires at least 1 parameter" >&2
    return 1
  fi

  local cmd="$*"
  local exit_code

  # Execute command and capture exit code
  if eval "$cmd" 2>/dev/null; then
    exit_code=0
  else
    exit_code=$?
    echo "ERROR: Command failed: $cmd (exit code: $exit_code)" >&2
  fi

  return $exit_code
}

# Function: util_error_log_with_context
# Description: Log error with context information
# Parameters:
#   $1 (string): error message
#   $2 (string): context (optional)
# Returns: 0 always
util_error_log_with_context() {
  local error_msg="$1"
  local context="${2:-unknown}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  echo "[$timestamp] ERROR in $context: $error_msg" >&2

  # Log to file if LOG_FILE is set
  if [[ -n "${LOG_FILE:-}" && -w "$(dirname "$LOG_FILE")" ]]; then
    echo "[$timestamp] ERROR in $context: $error_msg" >>"$LOG_FILE"
  fi

  return 0
}

# =============================================================================
# JSON UTILITIES (Most Used: 36 calls)
# =============================================================================

# Function: util_json_create_object
# Description: Create a JSON object with key-value pairs
# Parameters:
#   $@ (string): key-value pairs in format "key:value"
# Returns: JSON object via stdout
util_json_create_object() {
  local json="{"
  local first=true

  for pair in "$@"; do
    # Split on first colon
    if [[ "$pair" == *":"* ]]; then
      local key="${pair%%:*}"
      local value="${pair#*:}"

      if [[ -n "$key" ]]; then
        if [[ "$first" == "true" ]]; then
          first=false
        else
          json+=","
        fi

        json+="\"$key\":\"$value\""
      fi
    fi
  done

  json+="}"
  echo "$json"
}

# Function: util_json_get_value
# Description: Extract value from JSON object
# Parameters:
#   $1 (string): JSON string
#   $2 (string): key to extract
# Returns: value via stdout, 1 if not found
util_json_get_value() {
  local json="$1"
  local key="$2"

  if [[ -z "$json" || -z "$key" ]]; then
    echo "ERROR: util_json_get_value requires JSON and key parameters" >&2
    return 1
  fi

  # Simple JSON parsing for basic key-value extraction
  if [[ "$json" =~ \"$key\":\"([^\"]*) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

# =============================================================================
# CONFIGURATION UTILITIES (Most Used: 33 calls)
# =============================================================================

# Function: util_config_get_value
# Description: Get configuration value
# Parameters:
#   $1 (string): config key
#   $2 (string): default value (optional)
# Returns: config value via stdout
util_config_get_value() {
  local key="$1"
  local default_value="${2:-}"

  if [[ -z "$key" ]]; then
    echo "ERROR: util_config_get_value requires a key parameter" >&2
    return 1
  fi

  # Try to get from environment variable first
  local env_var="SERVERSENTRY_${key^^}"
  # Replace dots with underscores for valid environment variable names
  env_var="${env_var//\./_}"
  if [[ -n "${!env_var:-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  # Try to get from config file if it exists
  if [[ -n "${CONFIG_FILE:-}" && -f "$CONFIG_FILE" ]]; then
    local value
    value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [[ -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi

  # Return default value
  echo "$default_value"
  return 0
}

# Function: util_config_set_value
# Description: Set configuration value
# Parameters:
#   $1 (string): config key
#   $2 (string): config value
# Returns: 0 on success, 1 on failure
util_config_set_value() {
  local key="$1"
  local value="$2"

  if [[ -z "$key" ]]; then
    echo "ERROR: util_config_set_value requires a key parameter" >&2
    return 1
  fi

  # Set environment variable
  local env_var="SERVERSENTRY_${key^^}"
  # Replace dots with underscores for valid environment variable names
  env_var="${env_var//\./_}"
  export "$env_var"="$value"

  # Update config file if it exists and is writable
  if [[ -n "${CONFIG_FILE:-}" && -w "$CONFIG_FILE" ]]; then
    # Remove existing key and add new one
    grep -v "^${key}=" "$CONFIG_FILE" >"${CONFIG_FILE}.tmp" 2>/dev/null || true
    echo "${key}=\"${value}\"" >>"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  fi

  return 0
}

# =============================================================================
# FILE UTILITIES (Most Used: 14 calls)
# =============================================================================

# Function: util_create_secure_dir
# Description: Create directory with secure permissions
# Parameters:
#   $1 (string): directory path
#   $2 (string): permissions (optional, default: 750)
# Returns: 0 on success, 1 on failure
util_create_secure_dir() {
  local dir_path="$1"
  local permissions="${2:-750}"

  if [[ -z "$dir_path" ]]; then
    echo "ERROR: util_create_secure_dir requires a directory path" >&2
    return 1
  fi

  if [[ -d "$dir_path" ]]; then
    # Directory exists, just fix permissions
    chmod "$permissions" "$dir_path" 2>/dev/null || {
      echo "ERROR: Failed to set permissions on existing directory: $dir_path" >&2
      return 1
    }
    return 0
  fi

  # Create directory with secure permissions
  if mkdir -p "$dir_path" && chmod "$permissions" "$dir_path"; then
    return 0
  else
    echo "ERROR: Failed to create secure directory: $dir_path" >&2
    return 1
  fi
}

# =============================================================================
# VALIDATION UTILITIES
# =============================================================================

# Function: util_require_param
# Description: Require a parameter to be non-empty
# Parameters:
#   $1 (string): parameter value
#   $2 (string): parameter name
# Returns: 0 if valid, exits with 1 if invalid
util_require_param() {
  local param_value="$1"
  local param_name="${2:-parameter}"

  if [[ -z "$param_value" ]]; then
    echo "ERROR: Required parameter '$param_name' is missing or empty" >&2
    return 1
  fi

  return 0
}

# Function: util_validate_file_exists
# Description: Validate that a file exists
# Parameters:
#   $1 (string): file path
# Returns: 0 if exists, 1 if not
util_validate_file_exists() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    echo "ERROR: util_validate_file_exists requires a file path" >&2
    return 1
  fi

  if [[ -f "$file_path" ]]; then
    return 0
  else
    echo "ERROR: File does not exist: $file_path" >&2
    return 1
  fi
}

# Function: util_validate_dir_exists
# Description: Validate that a directory exists
# Parameters:
#   $1 (string): directory path
# Returns: 0 if exists, 1 if not
util_validate_dir_exists() {
  local dir_path="$1"

  if [[ -z "$dir_path" ]]; then
    echo "ERROR: util_validate_dir_exists requires a directory path" >&2
    return 1
  fi

  if [[ -d "$dir_path" ]]; then
    return 0
  else
    echo "ERROR: Directory does not exist: $dir_path" >&2
    return 1
  fi
}

# Function: util_validate_numeric
# Description: Validate that a value is numeric
# Parameters:
#   $1 (string): value to validate
# Returns: 0 if numeric, 1 if not
util_validate_numeric() {
  local value="$1"

  if [[ -z "$value" ]]; then
    echo "ERROR: util_validate_numeric requires a value" >&2
    return 1
  fi

  if [[ "$value" =~ ^[0-9]+$ ]]; then
    return 0
  else
    echo "ERROR: Value is not numeric: $value" >&2
    return 1
  fi
}

# Function: util_sanitize_input
# Description: Sanitize input by removing dangerous characters
# Parameters:
#   $1 (string): input to sanitize
# Returns: sanitized input via stdout
util_sanitize_input() {
  local input="$1"

  if [[ -z "$input" ]]; then
    return 0
  fi

  # Remove dangerous characters: ; | & $ ` ( ) < > [ ] { } \ " '
  echo "$input" | sed 's/[;|&$`()<>[\]{}\\\"'"'"']//g'
}

# =============================================================================
# STRING UTILITIES
# =============================================================================

# Function: util_to_uppercase
# Description: Convert string to uppercase
# Parameters:
#   $1 (string): input string
# Returns: uppercase string via stdout
util_to_uppercase() {
  local input="$1"
  echo "$input" | tr '[:lower:]' '[:upper:]'
}

# Function: util_to_lowercase
# Description: Convert string to lowercase
# Parameters:
#   $1 (string): input string
# Returns: lowercase string via stdout
util_to_lowercase() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]'
}

# =============================================================================
# JSON UTILITIES (Additional)
# =============================================================================

# Function: util_json_set_value
# Description: Set value in JSON object (simple implementation)
# Parameters:
#   $1 (string): JSON string
#   $2 (string): key
#   $3 (string): value
# Returns: modified JSON via stdout
util_json_set_value() {
  local json="$1"
  local key="$2"
  local value="$3"

  if [[ -z "$json" || -z "$key" ]]; then
    echo "ERROR: util_json_set_value requires JSON, key, and value parameters" >&2
    return 1
  fi

  # Simple JSON modification (for basic use cases)
  if [[ "$json" =~ \"$key\":\"[^\"]*\" ]]; then
    # Replace existing key
    echo "$json" | sed "s/\"$key\":\"[^\"]*\"/\"$key\":\"$value\"/"
  else
    # Add new key (before closing brace)
    echo "$json" | sed "s/}$/,\"$key\":\"$value\"}/"
  fi
}

# Function: util_json_create_status_object
# Description: Create a standard status JSON object
# Parameters:
#   $1 (string): status (success/error/warning)
#   $2 (string): message
#   $3 (string): additional data (optional)
# Returns: JSON status object via stdout
util_json_create_status_object() {
  local status="$1"
  local message="$2"
  local data="${3:-}"

  local json="{\"status\":\"$status\",\"message\":\"$message\""

  if [[ -n "$data" ]]; then
    json+=",\"data\":\"$data\""
  fi

  json+=",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S UTC')\"}"

  echo "$json"
}

# Function: util_json_create_array
# Description: Create a JSON array from arguments
# Parameters:
#   $@ (string): array elements
# Returns: JSON array via stdout
util_json_create_array() {
  local json="["
  local first=true

  for element in "$@"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      json+=","
    fi
    json+="\"$element\""
  done

  json+="]"
  echo "$json"
}

# Function: util_json_validate
# Description: Basic JSON validation
# Parameters:
#   $1 (string): JSON string to validate
# Returns: 0 if valid, 1 if invalid
util_json_validate() {
  local json="$1"

  if [[ -z "$json" ]]; then
    echo "ERROR: util_json_validate requires a JSON string" >&2
    return 1
  fi

  # Basic validation: check for balanced braces and quotes
  local brace_count=0
  local in_string=false
  local escaped=false

  while IFS= read -r -n1 char; do
    if [[ "$escaped" == "true" ]]; then
      escaped=false
      continue
    fi

    case "$char" in
    "\\")
      if [[ "$in_string" == "true" ]]; then
        escaped=true
      fi
      ;;
    "\"")
      if [[ "$in_string" == "true" ]]; then
        in_string=false
      else
        in_string=true
      fi
      ;;
    "{")
      if [[ "$in_string" == "false" ]]; then
        ((brace_count++))
      fi
      ;;
    "}")
      if [[ "$in_string" == "false" ]]; then
        ((brace_count--))
      fi
      ;;
    esac
  done <<<"$json"

  if [[ $brace_count -eq 0 && "$in_string" == "false" ]]; then
    return 0
  else
    echo "ERROR: Invalid JSON format" >&2
    return 1
  fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export all utility functions for use in other scripts
export -f util_error_validate_input
export -f util_command_exists
export -f util_error_safe_execute
export -f util_error_log_with_context
export -f util_json_create_object
export -f util_json_get_value
export -f util_config_get_value
export -f util_config_set_value
export -f util_create_secure_dir
export -f util_require_param
export -f util_validate_file_exists
export -f util_validate_dir_exists
export -f util_validate_numeric
export -f util_sanitize_input
export -f util_to_uppercase
export -f util_to_lowercase
export -f util_json_set_value
export -f util_json_create_status_object
export -f util_json_create_array
export -f util_json_validate

# Mark as loaded
echo "✅ Unified utility framework loaded (20 core functions)" >&2
