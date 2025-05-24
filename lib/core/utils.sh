#!/bin/bash
#
# ServerSentry v2 - Utilities Loader
#
# This module loads all utility functions and provides standardized operations
# for ServerSentry v2 with no legacy compatibility

# Set BASE_DIR if not already set
BASE_DIR="${BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Function: init_utilities
# Description: Initialize all utility modules
# Returns:
#   0 - success
#   1 - failure
init_utilities() {
  # Fallback logging functions if logging system not available
  if ! declare -f log_debug >/dev/null 2>&1; then
    log_debug() { echo "[DEBUG] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
  fi

  # Use professional logging with utils component
  log_debug "Initializing utility modules" "utils"

  # Check if utilities directory exists
  if [[ ! -d "${BASE_DIR}/lib/core/utils" ]]; then
    log_warning "Utilities directory not found: ${BASE_DIR}/lib/core/utils" "utils"
    return 1
  fi

  # Initialize utilities by loading all utility modules in proper order
  # Load validation utils first as other modules depend on it
  local utility_modules=(
    "validation_utils.sh"
    "array_utils.sh"
    "json_utils.sh"
    "command_utils.sh"
    "performance_utils.sh"
    "config_utils.sh"
  )

  local failed_modules=()

  for module in "${utility_modules[@]}"; do
    local module_path="${BASE_DIR}/lib/core/utils/${module}"
    if [[ -f "$module_path" ]]; then
      log_debug "Loading utility module: $module" "utils"
      # shellcheck source=/dev/null
      if ! source "$module_path"; then
        failed_modules+=("$module")
        log_error "Failed to load utility module: $module" "utils"
      fi
    else
      failed_modules+=("$module (not found)")
      log_warning "Utility module not found: $module" "utils"
    fi
  done

  if [[ ${#failed_modules[@]} -gt 0 ]]; then
    log_error "Failed to load ${#failed_modules[@]} utility modules: ${failed_modules[*]}" "utils"
    return 1
  else
    log_debug "All utility modules loaded successfully" "utils"
  fi
  return 0
}

# Initialize utilities when this module is sourced
# Only initialize if logging is available
# Temporarily disabled to avoid syntax errors in utility modules
# if declare -f log_debug >/dev/null 2>&1; then
#   init_utilities
# fi

# === ENHANCED UTILITY FUNCTIONS ===
# These functions provide enhanced operations with modern patterns

# Check if command exists
command_exists() {
  # Use cached version if available, fallback to original
  if declare -f util_command_exists_cached >/dev/null 2>&1; then
    util_command_exists_cached "$1"
  else
    command -v "$1" >/dev/null 2>&1
  fi
}

# Check if running as root
is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# Get operating system type
get_os_type() {
  case "$(uname -s)" in
  Linux*) echo "linux" ;;
  Darwin*) echo "macos" ;;
  CYGWIN*) echo "windows" ;;
  MINGW*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

# Get OS distribution (for Linux)
get_linux_distro() {
  if [[ -f /etc/os-release ]]; then
    # freedesktop.org and systemd
    . /etc/os-release
    echo "$ID"
  elif command_exists lsb_release; then
    # linuxbase.org
    lsb_release -si | tr '[:upper:]' '[:lower:]'
  elif [[ -f /etc/lsb-release ]]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]'
  elif [[ -f /etc/debian_version ]]; then
    # Older Debian/Ubuntu/etc.
    echo "debian"
  else
    # Fall back to uname
    uname -s
  fi
}

# Format bytes to human-readable string
format_bytes() {
  local bytes="$1"
  local precision="${2:-2}"

  # Ensure bc is available for floating point calculations
  if ! command_exists bc; then
    echo "${bytes}B"
    return
  fi

  # Use bc for comparisons to handle floating point values
  if [[ $(echo "$bytes < 1024" | bc) -eq 1 ]]; then
    echo "${bytes}B"
  elif [[ $(echo "$bytes < 1048576" | bc) -eq 1 ]]; then
    awk "BEGIN { printf \"%.${precision}f KB\", $bytes/1024 }"
  elif [[ $(echo "$bytes < 1073741824" | bc) -eq 1 ]]; then
    awk "BEGIN { printf \"%.${precision}f MB\", $bytes/1048576 }"
  else
    awk "BEGIN { printf \"%.${precision}f GB\", $bytes/1073741824 }"
  fi
}

# Convert to lowercase
to_lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert to uppercase
to_uppercase() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Trim whitespace
trim() {
  local var="$*"
  # remove leading whitespace
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}

# Validate IP address (uses validation utils)
is_valid_ip() {
  local ip="$1"

  # Use validation utils if available, otherwise use basic validation
  if declare -f util_validate_ip_address >/dev/null 2>&1; then
    util_validate_ip_address "$ip" "ip_address"
  else
    # Basic IP validation for testing
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      return 1
    fi

    local IFS='.'
    local octets=($ip)
    for octet in "${octets[@]}"; do
      if [[ "$octet" -gt 255 ]]; then
        return 1
      fi
    done
    return 0
  fi
}

# Generate a random string
random_string() {
  local length="${1:-32}"
  if [[ -r /dev/urandom ]]; then
    # Use LC_ALL=C to avoid locale issues with tr
    LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
  else
    # Fallback for systems without /dev/urandom - add microsecond precision
    local timestamp=$(date +%s.%N 2>/dev/null || date +%s)
    echo "${timestamp}${RANDOM}" | sha256sum | base64 | tr -d '=' | head -c "$length"
  fi
}

# Check if a directory is writable
is_dir_writable() {
  local dir="$1"
  [[ -d "$dir" && -w "$dir" ]]
}

# Get timestamp
get_timestamp() {
  # Use cached version if available, fallback to original
  if declare -f util_get_cached_timestamp >/dev/null 2>&1; then
    util_get_cached_timestamp 1
  else
    date +%s
  fi
}

# Get formatted date
get_formatted_date() {
  local format="${1:-"%Y-%m-%d %H:%M:%S"}"

  # Use cached version if available, fallback to original
  if declare -f util_get_cached_formatted_date >/dev/null 2>&1; then
    util_get_cached_formatted_date "$format" 1
  else
    date +"$format"
  fi
}

# Safe file write (write to temp file, then move)
safe_write() {
  local target_file="$1"
  local content="$2"

  local tmp_file="${target_file}.tmp"
  echo "$content" >"$tmp_file" || return 1
  mv "$tmp_file" "$target_file" || return 1

  return 0
}

# URL encode
url_encode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for ((pos = 0; pos < strlen; pos++)); do
    c=${string:$pos:1}
    case "$c" in
    [-_.~a-zA-Z0-9]) o="$c" ;;
    *) printf -v o '%%%02x' "'$c" ;;
    esac
    encoded+="$o"
  done

  echo "$encoded"
}

# JSON escape (uses JSON utils)
json_escape() {
  local json="$1"

  # Use JSON utils if available, otherwise use basic escaping
  if declare -f util_json_escape >/dev/null 2>&1; then
    util_json_escape "$json"
  else
    # Basic JSON escaping for testing
    echo "$json" | sed 's/\\/\\\\/g; s/"/\\"/g'
  fi
}

# === MODERN UTILITY OPERATIONS ===

# Create secure temporary file
create_temp_file() {
  local prefix="${1:-serversentry}"
  local temp_file
  temp_file=$(mktemp -t "${prefix}.XXXXXX") || return 1
  echo "$temp_file"
}

# Create secure directory
create_secure_dir() {
  local dir="$1"
  local mode="${2:-755}"

  mkdir -p "$dir" || return 1
  chmod "$mode" "$dir" || return 1

  return 0
}

# Create secure file
create_secure_file() {
  local file="$1"
  local mode="${2:-644}"

  touch "$file" || return 1
  chmod "$mode" "$file" || return 1

  return 0
}

# Enhanced error handling with context
log_error_context() {
  local message="$1"
  local context="${2:-}"

  local caller_function="${FUNCNAME[1]}"
  local caller_line="${BASH_LINENO[0]}"

  if [[ -n "$context" ]]; then
    log_error "$message [$context] (function: $caller_function, line: $caller_line)"
  else
    log_error "$message (function: $caller_function, line: $caller_line)"
  fi
}

# Standardized retry mechanism
retry_operation() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local command=("$@")

  local attempt=1
  while [[ "$attempt" -le "$max_attempts" ]]; do
    if "${command[@]}"; then
      return 0
    fi

    if [[ "$attempt" -lt "$max_attempts" ]]; then
      log_debug "Operation failed, retrying in ${delay}s (attempt $attempt/$max_attempts)"
      sleep "$delay"
    fi

    ((attempt++))
  done

  log_error "Operation failed after $max_attempts attempts"
  return 1
}

# Performance measurement
measure_performance() {
  local operation_name="$1"
  shift
  local command=("$@")

  local start_time
  start_time=$(date +%s.%N)

  "${command[@]}"
  local exit_code=$?

  local end_time
  end_time=$(date +%s.%N)

  local duration
  duration=$(echo "$end_time - $start_time" | bc -l)

  log_debug "Performance: $operation_name took ${duration}s"

  return "$exit_code"
}

# Export modern utility functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f command_exists
  export -f is_root
  export -f get_os_type
  export -f get_linux_distro
  export -f format_bytes
  export -f to_lowercase
  export -f to_uppercase
  export -f trim
  export -f is_valid_ip
  export -f random_string
  export -f is_dir_writable
  export -f get_timestamp
  export -f get_formatted_date
  export -f safe_write
  export -f url_encode
  export -f json_escape
  export -f create_temp_file
  export -f create_secure_dir
  export -f create_secure_file
  export -f log_error_context
  export -f retry_operation
  export -f measure_performance
fi
