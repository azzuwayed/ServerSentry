#!/bin/bash
#
# ServerSentry v2 - Utilities Loader
#
# This module loads all utility functions and maintains backward compatibility

# Get the utilities directory path
UTILS_DIR="${BASE_DIR}/lib/core/utils"

# Function: init_utilities
# Description: Initialize all utility modules
# Returns:
#   0 - success
#   1 - failure
init_utilities() {
  # Check if log_debug function exists, if not use echo
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing utility modules"
  else
    echo "[DEBUG] Initializing utility modules"
  fi

  # Check if utilities directory exists
  if [[ ! -d "$UTILS_DIR" ]]; then
    if declare -f log_warning >/dev/null 2>&1; then
      log_warning "Utilities directory not found: $UTILS_DIR"
    else
      echo "[WARNING] Utilities directory not found: $UTILS_DIR"
    fi
    return 1
  fi

  # Load all utility modules
  local utility_modules=(
    "validation_utils.sh"
    "json_utils.sh"
    "array_utils.sh"
    "config_utils.sh"
  )

  for module in "${utility_modules[@]}"; do
    local module_path="$UTILS_DIR/$module"
    if [[ -f "$module_path" ]]; then
      if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Loading utility module: $module"
      else
        echo "[DEBUG] Loading utility module: $module"
      fi
      source "$module_path" || {
        if declare -f log_error >/dev/null 2>&1; then
          log_error "Failed to load utility module: $module"
        else
          echo "[ERROR] Failed to load utility module: $module" >&2
        fi
        return 1
      }
    else
      if declare -f log_warning >/dev/null 2>&1; then
        log_warning "Utility module not found: $module_path"
      else
        echo "[WARNING] Utility module not found: $module_path"
      fi
    fi
  done

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "All utility modules loaded successfully"
  else
    echo "[DEBUG] All utility modules loaded successfully"
  fi
  return 0
}

# Initialize utilities when this module is sourced
init_utilities

# === BACKWARD COMPATIBILITY FUNCTIONS ===
# These functions maintain compatibility with existing code

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
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

# Validate IP address (now uses new validation utils)
is_valid_ip() {
  local ip="$1"
  util_validate_ip_address "$ip" "ip_address"
}

# Generate a random string
random_string() {
  local length="${1:-32}"
  if command_exists /dev/urandom; then
    tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1
  else
    # Fallback for systems without /dev/urandom
    date +%s | sha256sum | base64 | head -c "$length"
  fi
}

# Check if a directory is writable
is_dir_writable() {
  local dir="$1"
  [[ -d "$dir" && -w "$dir" ]]
}

# Get timestamp
get_timestamp() {
  date +%s
}

# Get formatted date
get_formatted_date() {
  local format="${1:-"%Y-%m-%d %H:%M:%S"}"
  date +"$format"
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

# JSON escape (now uses new JSON utils)
json_escape() {
  local json="$1"
  util_json_escape "$json"
}

# === NEW UTILITY ALIASES FOR COMMON OPERATIONS ===

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

# Export backward compatibility functions
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
