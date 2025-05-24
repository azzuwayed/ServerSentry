#!/bin/bash
#
# ServerSentry v2 - Validation Utilities
#
# This module provides standardized validation functions used throughout the application

# Function: util_require_param
# Description: Validate that a required parameter is provided
# Parameters:
#   $1 - parameter value
#   $2 - parameter name
# Returns:
#   0 - parameter is valid
#   1 - parameter is missing or empty
util_require_param() {
  local param="$1"
  local name="$2"

  if [[ -z "$param" ]]; then
    log_error "Required parameter missing: $name"
    return 1
  fi

  return 0
}

# Function: util_validate_numeric
# Description: Validate that a parameter is numeric
# Parameters:
#   $1 - value to validate
#   $2 - parameter name
# Returns:
#   0 - value is numeric
#   1 - value is not numeric
util_validate_numeric() {
  local value="$1"
  local name="$2"

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    log_error "Parameter must be numeric: $name = $value"
    return 1
  fi

  return 0
}

# Function: util_validate_positive_numeric
# Description: Validate that a parameter is a positive number
# Parameters:
#   $1 - value to validate
#   $2 - parameter name
# Returns:
#   0 - value is positive numeric
#   1 - value is not positive numeric
util_validate_positive_numeric() {
  local value="$1"
  local name="$2"

  if ! util_validate_numeric "$value" "$name"; then
    return 1
  fi

  if [[ "$value" -le 0 ]]; then
    log_error "Parameter must be positive: $name = $value"
    return 1
  fi

  return 0
}

# Function: util_validate_boolean
# Description: Validate that a parameter is a boolean value
# Parameters:
#   $1 - value to validate
#   $2 - parameter name
# Returns:
#   0 - value is boolean
#   1 - value is not boolean
util_validate_boolean() {
  local value="$1"
  local name="$2"

  if ! [[ "$value" =~ ^(true|false)$ ]]; then
    log_error "Parameter must be boolean (true/false): $name = $value"
    return 1
  fi

  return 0
}

# Function: util_validate_file_exists
# Description: Validate that a file exists and is readable
# Parameters:
#   $1 - file path
#   $2 - file description
# Returns:
#   0 - file exists and is readable
#   1 - file does not exist or is not readable
util_validate_file_exists() {
  local file="$1"
  local description="${2:-File}"

  if [[ ! -f "$file" ]]; then
    log_error "$description not found: $file"
    return 1
  fi

  if [[ ! -r "$file" ]]; then
    log_error "$description is not readable: $file"
    return 1
  fi

  return 0
}

# Function: util_validate_dir_exists
# Description: Validate that a directory exists and is accessible
# Parameters:
#   $1 - directory path
#   $2 - directory description
# Returns:
#   0 - directory exists and is accessible
#   1 - directory does not exist or is not accessible
util_validate_dir_exists() {
  local dir="$1"
  local description="${2:-Directory}"

  if [[ ! -d "$dir" ]]; then
    log_error "$description not found: $dir"
    return 1
  fi

  if [[ ! -x "$dir" ]]; then
    log_error "$description is not accessible: $dir"
    return 1
  fi

  return 0
}

# Function: util_validate_executable
# Description: Validate that a command is executable
# Parameters:
#   $1 - command name
#   $2 - command description
# Returns:
#   0 - command is available
#   1 - command is not available
util_validate_executable() {
  local cmd="$1"
  local description="${2:-Command}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "$description not available: $cmd"
    return 1
  fi

  return 0
}

# Function: util_validate_ip_address
# Description: Validate IP address format (IPv4)
# Parameters:
#   $1 - IP address to validate
#   $2 - parameter name
# Returns:
#   0 - valid IP address
#   1 - invalid IP address
util_validate_ip_address() {
  local ip="$1"
  local name="$2"

  if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Invalid IP address format: $name = $ip"
    return 1
  fi

  # Validate each octet is 0-255
  IFS='.' read -r -a octets <<<"$ip"
  for octet in "${octets[@]}"; do
    if [[ "$octet" -gt 255 ]]; then
      log_error "Invalid IP address octet: $name = $ip"
      return 1
    fi
  done

  return 0
}

# Function: util_validate_port
# Description: Validate port number
# Parameters:
#   $1 - port number to validate
#   $2 - parameter name
# Returns:
#   0 - valid port number
#   1 - invalid port number
util_validate_port() {
  local port="$1"
  local name="$2"

  if ! util_validate_numeric "$port" "$name"; then
    return 1
  fi

  if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    log_error "Port number out of range (1-65535): $name = $port"
    return 1
  fi

  return 0
}

# Function: util_validate_url
# Description: Basic URL validation
# Parameters:
#   $1 - URL to validate
#   $2 - parameter name
# Returns:
#   0 - valid URL format
#   1 - invalid URL format
util_validate_url() {
  local url="$1"
  local name="$2"

  if [[ ! "$url" =~ ^https?:// ]]; then
    log_error "URL must start with http:// or https://: $name = $url"
    return 1
  fi

  return 0
}

# Function: util_validate_email
# Description: Basic email validation
# Parameters:
#   $1 - email to validate
#   $2 - parameter name
# Returns:
#   0 - valid email format
#   1 - invalid email format
util_validate_email() {
  local email="$1"
  local name="$2"

  if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
    log_error "Invalid email format: $name = $email"
    return 1
  fi

  return 0
}

# Function: util_validate_log_level
# Description: Validate log level values
# Parameters:
#   $1 - log level to validate
#   $2 - parameter name
# Returns:
#   0 - valid log level
#   1 - invalid log level
util_validate_log_level() {
  local level="$1"
  local name="$2"

  case "$level" in
  debug | info | warning | error | critical)
    return 0
    ;;
  *)
    log_error "Invalid log level: $name = $level (must be: debug, info, warning, error, critical)"
    return 1
    ;;
  esac
}

# Function: util_validate_string_length
# Description: Validate string length constraints
# Parameters:
#   $1 - string to validate
#   $2 - minimum length
#   $3 - maximum length
#   $4 - parameter name
# Returns:
#   0 - string length is valid
#   1 - string length is invalid
util_validate_string_length() {
  local string="$1"
  local min_length="$2"
  local max_length="$3"
  local name="$4"

  local length=${#string}

  if [[ "$length" -lt "$min_length" ]]; then
    log_error "String too short: $name (minimum: $min_length, actual: $length)"
    return 1
  fi

  if [[ "$length" -gt "$max_length" ]]; then
    log_error "String too long: $name (maximum: $max_length, actual: $length)"
    return 1
  fi

  return 0
}

# Function: util_validate_path_safe
# Description: Validate that a path is safe (no directory traversal)
# Parameters:
#   $1 - path to validate
#   $2 - parameter name
# Returns:
#   0 - path is safe
#   1 - path is unsafe
util_validate_path_safe() {
  local path="$1"
  local name="$2"

  # Check for directory traversal attempts
  if [[ "$path" =~ \.\./|\.\.\\ ]]; then
    log_error "Path contains directory traversal: $name = $path"
    return 1
  fi

  # Check for absolute paths if not expected
  if [[ "$path" =~ ^/ ]]; then
    log_warning "Absolute path detected: $name = $path"
  fi

  return 0
}

# Function: util_sanitize_input
# Description: Sanitize input by removing control characters
# Parameters:
#   $1 - input to sanitize
# Returns:
#   Sanitized string via stdout
util_sanitize_input() {
  local input="$1"

  # Remove control characters and limit length
  echo "$input" | tr -d '[:cntrl:]' | cut -c1-1024
}

# Function: util_sanitize_path
# Description: Sanitize file path by removing dangerous characters
# Parameters:
#   $1 - path to sanitize
# Returns:
#   Sanitized path via stdout
util_sanitize_path() {
  local path="$1"

  # Remove dangerous characters and normalize
  echo "$path" | sed 's/[;&|`$()]//g' | tr -s '/' '/'
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_require_param
  export -f util_validate_numeric
  export -f util_validate_positive_numeric
  export -f util_validate_boolean
  export -f util_validate_file_exists
  export -f util_validate_dir_exists
  export -f util_validate_executable
  export -f util_validate_ip_address
  export -f util_validate_port
  export -f util_validate_url
  export -f util_validate_email
  export -f util_validate_log_level
  export -f util_validate_string_length
  export -f util_validate_path_safe
  export -f util_sanitize_input
  export -f util_sanitize_path
fi
