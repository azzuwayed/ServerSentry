#!/usr/bin/env bash
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

# Source compatibility utilities first
if [[ -f "$BASE_DIR/lib/core/utils/compat_utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils/compat_utils.sh"
fi

# Initialize utility modules if logging is available
if declare -f log_debug >/dev/null 2>&1; then
  init_utilities
fi

# === ENHANCED UTILITY FUNCTIONS ===
# These functions provide enhanced operations with modern patterns

# Backward compatibility wrapper for command_exists
command_exists() {
  # Use unified command utility if available
  if declare -f util_command_exists >/dev/null 2>&1; then
    util_command_exists "$1"
    return $?
  fi

  # Basic fallback
  command -v "$1" >/dev/null 2>&1
}

# Backward compatibility wrapper for get_os_type
get_os_type() {
  # Use compatibility layer if available
  if declare -f compat_get_os >/dev/null 2>&1; then
    compat_get_os
    return $?
  fi

  # Fallback implementation
  case "$(uname -s)" in
  Darwin*)
    echo "macos"
    ;;
  Linux*)
    if [[ -f /etc/os-release ]]; then
      echo "linux"
    elif command_exists lsb_release; then
      echo "linux"
    else
      echo "linux"
    fi
    ;;
  CYGWIN* | MINGW* | MSYS*)
    echo "windows"
    ;;
  *)
    echo "unknown"
    ;;
  esac
}

# Check if running as root
is_root() {
  [[ "$(id -u)" -eq 0 ]]
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

# Sanitize filename
sanitize_filename() {
  local filename="$1"
  # Remove/replace problematic characters
  echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Create directory with proper permissions
create_secure_dir() {
  local dir="$1"
  local permissions="${2:-755}"

  if [[ ! -d "$dir" ]]; then
    if mkdir -p "$dir"; then
      chmod "$permissions" "$dir"
      return 0
    else
      return 1
    fi
  fi
  return 0
}

# Create temporary file with cleanup
create_temp_file() {
  local prefix="${1:-serversentry}"
  local temp_file

  if command_exists mktemp; then
    temp_file=$(mktemp -t "${prefix}.XXXXXX")
  else
    # Fallback for systems without mktemp
    temp_file="/tmp/${prefix}.$$.$RANDOM"
    touch "$temp_file"
  fi

  echo "$temp_file"
}

# Enhanced error logging with context
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

# Retry operation with backoff
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

# Cross-platform file size function
get_file_size() {
  local file="$1"

  # Use compatibility layer if available
  if declare -f compat_stat_size >/dev/null 2>&1; then
    compat_stat_size "$file"
  else
    # Fallback
    if [[ -f "$file" ]]; then
      case "$(uname -s)" in
      Darwin*)
        stat -f%z "$file" 2>/dev/null
        ;;
      Linux*)
        stat -c%s "$file" 2>/dev/null
        ;;
      *)
        ls -l "$file" 2>/dev/null | awk '{print $5}'
        ;;
      esac
    else
      echo "0"
    fi
  fi
}

# Cross-platform file modification time
get_file_mtime() {
  local file="$1"

  # Use compatibility layer if available
  if declare -f compat_stat_mtime >/dev/null 2>&1; then
    compat_stat_mtime "$file"
  else
    # Fallback
    if [[ -f "$file" ]]; then
      case "$(uname -s)" in
      Darwin*)
        stat -f%m "$file" 2>/dev/null
        ;;
      Linux*)
        stat -c%Y "$file" 2>/dev/null
        ;;
      *)
        # Basic fallback - not very accurate
        echo ""
        ;;
      esac
    else
      echo ""
    fi
  fi
}

# Export modern utility functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f init_utilities
  export -f command_exists
  export -f get_os_type
  export -f is_root
  export -f get_linux_distro
  export -f format_bytes
  export -f to_lowercase
  export -f to_uppercase
  export -f sanitize_filename
  export -f create_secure_dir
  export -f create_temp_file
  export -f log_error_context
  export -f retry_operation
  export -f measure_performance
  export -f get_file_size
  export -f get_file_mtime
fi
