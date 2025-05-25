#!/usr/bin/env bash
#
# ServerSentry v2 - Command Utilities
#
# Unified command checking, execution, and cross-platform utilities

# Prevent multiple sourcing
if [[ "${COMMAND_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
COMMAND_UTILS_LOADED=true
export COMMAND_UTILS_LOADED

# Global cache for command existence (performance optimization)
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  declare -A COMMAND_CACHE
  declare -A COMMAND_CACHE_TIMESTAMPS
  COMMAND_CACHE_SUPPORTED=true
else
  COMMAND_CACHE_SUPPORTED=false
fi

# Cache configuration
COMMAND_CACHE_TTL=3600              # 1 hour cache TTL
COMMAND_CACHE_CLEANUP_INTERVAL=7200 # 2 hours

# === UNIFIED COMMAND CHECKING FUNCTIONS ===

# Function: util_command_exists
# Description: Unified command existence checker with caching and cross-platform support
# Parameters:
#   $1 - command name
# Returns:
#   0 - command exists
#   1 - command does not exist
util_command_exists() {
  local cmd="$1"

  if [[ -z "$cmd" ]]; then
    # Only log if logging functions are available
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Command name cannot be empty" "command_utils"
    fi
    return 1
  fi

  # Check cache first if supported
  if [[ "$COMMAND_CACHE_SUPPORTED" == "true" ]]; then
    local cache_key="cmd_$cmd"
    local current_time
    current_time=$(date +%s)

    # Check if we have a cached result
    if [[ -n "${COMMAND_CACHE[$cache_key]:-}" ]]; then
      local cache_time="${COMMAND_CACHE_TIMESTAMPS[$cache_key]:-0}"
      local age=$((current_time - cache_time))

      # Return cached result if within TTL
      if [[ "$age" -lt "$COMMAND_CACHE_TTL" ]]; then
        [[ "${COMMAND_CACHE[$cache_key]}" == "1" ]] && return 0 || return 1
      fi
    fi
  fi

  # Perform actual command check
  local result=1
  if command -v "$cmd" >/dev/null 2>&1; then
    result=0
  fi

  # Cache the result if caching is supported
  if [[ "$COMMAND_CACHE_SUPPORTED" == "true" ]]; then
    local cache_key="cmd_$cmd"
    local current_time
    current_time=$(date +%s)

    COMMAND_CACHE[$cache_key]="$result"
    COMMAND_CACHE_TIMESTAMPS[$cache_key]="$current_time"
  fi

  return $result
}

# Function: util_command_exists_bulk
# Description: Check multiple commands at once for efficiency
# Parameters:
#   $@ - command names
# Returns:
#   0 - all commands exist
#   1 - one or more commands missing
util_command_exists_bulk() {
  local commands=("$@")
  local missing_commands=()

  for cmd in "${commands[@]}"; do
    if ! util_command_exists "$cmd"; then
      missing_commands+=("$cmd")
    fi
  done

  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    if declare -f log_debug >/dev/null 2>&1; then
      log_debug "Missing commands: ${missing_commands[*]}" "command_utils"
    fi
    return 1
  fi

  return 0
}

# Function: util_command_get_path
# Description: Get the full path of a command with caching
# Parameters:
#   $1 - command name
# Returns:
#   Command path via stdout, empty if not found
util_command_get_path() {
  local cmd="$1"

  if util_command_exists "$cmd"; then
    command -v "$cmd" 2>/dev/null
  fi
}

# Function: util_command_get_version
# Description: Get version of a command using common patterns
# Parameters:
#   $1 - command name
#   $2 - version flag (optional, defaults to --version)
# Returns:
#   Version string via stdout
util_command_get_version() {
  local cmd="$1"
  local version_flag="${2:---version}"

  if ! util_command_exists "$cmd"; then
    return 1
  fi

  # Try common version patterns
  local version_output
  if version_output=$("$cmd" "$version_flag" 2>/dev/null); then
    echo "$version_output" | head -n1
  elif version_output=$("$cmd" -V 2>/dev/null); then
    echo "$version_output" | head -n1
  elif version_output=$("$cmd" version 2>/dev/null); then
    echo "$version_output" | head -n1
  else
    echo "unknown"
  fi
}

# === COMMAND EXECUTION UTILITIES ===

# Function: util_execute_with_timeout
# Description: Execute command with timeout and error handling
# Parameters:
#   $1 - timeout in seconds
#   $2+ - command and arguments
# Returns:
#   Command exit code or 124 for timeout
util_execute_with_timeout() {
  local timeout_seconds="$1"
  shift
  local command=("$@")

  if util_command_exists timeout; then
    timeout "$timeout_seconds" "${command[@]}"
  else
    # Fallback implementation for systems without timeout command
    local command_pid
    "${command[@]}" &
    command_pid=$!

    # Wait for timeout or command completion
    local count=0
    while [[ $count -lt $timeout_seconds ]]; do
      if ! kill -0 "$command_pid" 2>/dev/null; then
        wait "$command_pid"
        return $?
      fi
      sleep 1
      ((count++))
    done

    # Command timed out, kill it
    kill "$command_pid" 2>/dev/null
    wait "$command_pid" 2>/dev/null
    return 124 # timeout exit code
  fi
}

# Function: util_execute_with_retry
# Description: Execute command with retry logic
# Parameters:
#   $1 - max attempts
#   $2 - delay between attempts
#   $3+ - command and arguments
# Returns:
#   0 - success
#   1 - failure after all retries
util_execute_with_retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local command=("$@")

  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    if "${command[@]}"; then
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      if declare -f log_debug >/dev/null 2>&1; then
        log_debug "Command failed, retrying in ${delay}s (attempt $attempt/$max_attempts)" "command_utils"
      fi
      sleep "$delay"
    fi

    ((attempt++))
  done

  # Only log if logging functions are available
  if declare -f log_error >/dev/null 2>&1; then
    log_error "Command failed after $max_attempts attempts: ${command[*]}" "command_utils"
  fi
  return 1
}

# === CROSS-PLATFORM UTILITIES ===

# Function: util_get_package_manager
# Description: Detect the system package manager
# Returns:
#   Package manager name via stdout
util_get_package_manager() {
  case "$(uname -s)" in
  Darwin*)
    if util_command_exists brew; then
      echo "homebrew"
    elif util_command_exists port; then
      echo "macports"
    else
      echo "none"
    fi
    ;;
  Linux*)
    if util_command_exists apt-get; then
      echo "apt"
    elif util_command_exists dnf; then
      echo "dnf"
    elif util_command_exists yum; then
      echo "yum"
    elif util_command_exists pacman; then
      echo "pacman"
    elif util_command_exists zypper; then
      echo "zypper"
    elif util_command_exists apk; then
      echo "apk"
    else
      echo "unknown"
    fi
    ;;
  *)
    echo "unknown"
    ;;
  esac
}

# Function: util_install_package
# Description: Install a package using the system package manager
# Parameters:
#   $1 - package name
# Returns:
#   0 - success
#   1 - failure
util_install_package() {
  local package="$1"
  local package_manager
  package_manager=$(util_get_package_manager)

  case "$package_manager" in
  homebrew)
    brew install "$package"
    ;;
  macports)
    port install "$package"
    ;;
  apt)
    apt-get update && apt-get install -y "$package"
    ;;
  dnf)
    dnf install -y "$package"
    ;;
  yum)
    yum install -y "$package"
    ;;
  pacman)
    pacman -S --noconfirm "$package"
    ;;
  zypper)
    zypper install -y "$package"
    ;;
  apk)
    apk add "$package"
    ;;
  *)
    # Only log if logging functions are available
    if declare -f log_error >/dev/null 2>&1; then
      log_error "Cannot install package: unknown package manager" "command_utils"
    fi
    return 1
    ;;
  esac
}

# === PERFORMANCE AND MAINTENANCE ===

# Function: util_command_cache_cleanup
# Description: Clean up expired cache entries
# Returns:
#   0 - success
util_command_cache_cleanup() {
  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    return 0
  fi

  local current_time
  current_time=$(date +%s)
  local cleaned_count=0

  for cache_key in "${!COMMAND_CACHE_TIMESTAMPS[@]}"; do
    local cache_time="${COMMAND_CACHE_TIMESTAMPS[$cache_key]}"
    local age=$((current_time - cache_time))

    if [[ $age -gt $COMMAND_CACHE_TTL ]]; then
      unset COMMAND_CACHE["$cache_key"]
      unset COMMAND_CACHE_TIMESTAMPS["$cache_key"]
      ((cleaned_count++))
    fi
  done

  if [[ $cleaned_count -gt 0 ]] && declare -f log_debug >/dev/null 2>&1; then
    log_debug "Cleaned up $cleaned_count expired command cache entries" "command_utils"
  fi

  return 0
}

# Function: util_command_cache_stats
# Description: Get command cache statistics
# Returns:
#   Cache statistics via stdout
util_command_cache_stats() {
  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    echo "Command caching not supported (bash < 4.0)"
    return 1
  fi

  local total_entries=${#COMMAND_CACHE[@]}
  local current_time
  current_time=$(date +%s)
  local fresh_entries=0

  for cache_key in "${!COMMAND_CACHE_TIMESTAMPS[@]}"; do
    local cache_time="${COMMAND_CACHE_TIMESTAMPS[$cache_key]}"
    local age=$((current_time - cache_time))

    if [[ $age -lt $COMMAND_CACHE_TTL ]]; then
      ((fresh_entries++))
    fi
  done

  echo "Command Cache Statistics:"
  echo "  Total entries: $total_entries"
  echo "  Fresh entries: $fresh_entries"
  echo "  Expired entries: $((total_entries - fresh_entries))"
  echo "  Cache TTL: ${COMMAND_CACHE_TTL}s"
}

# Function: util_command_cache_clear
# Description: Clear all command cache entries
# Returns:
#   0 - success
util_command_cache_clear() {
  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    return 0
  fi

  local cleared_count=${#COMMAND_CACHE[@]}

  # Clear cache arrays
  for key in "${!COMMAND_CACHE[@]}"; do
    unset COMMAND_CACHE["$key"]
  done

  for key in "${!COMMAND_CACHE_TIMESTAMPS[@]}"; do
    unset COMMAND_CACHE_TIMESTAMPS["$key"]
  done

  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Cleared $cleared_count command cache entries" "command_utils"
  fi
  return 0
}

# === LEGACY COMPATIBILITY FUNCTIONS ===

# Backward compatibility aliases (to be removed in future versions)
command_exists() {
  util_command_exists "$@"
}

compat_command_exists() {
  util_command_exists "$@"
}

util_command_exists_cached() {
  util_command_exists "$@"
}

# === INITIALIZATION ===

# Function: util_command_utils_init
# Description: Initialize command utilities system
# Returns:
#   0 - success
util_command_utils_init() {
  # Only log if logging functions are available
  if declare -f log_debug >/dev/null 2>&1; then
    log_debug "Initializing command utilities system" "command_utils"

    # Schedule periodic cache cleanup if supported
    if [[ "$COMMAND_CACHE_SUPPORTED" == "true" ]]; then
      log_debug "Command caching enabled with ${COMMAND_CACHE_TTL}s TTL" "command_utils"
    else
      log_debug "Command caching disabled (bash < 4.0)" "command_utils"
    fi
  fi

  return 0
}

# Export all functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_command_exists
  export -f util_command_exists_bulk
  export -f util_command_get_path
  export -f util_command_get_version
  export -f util_execute_with_timeout
  export -f util_execute_with_retry
  export -f util_get_package_manager
  export -f util_install_package
  export -f util_command_cache_cleanup
  export -f util_command_cache_stats
  export -f util_command_cache_clear
  export -f util_command_utils_init

  # Legacy compatibility exports
  export -f command_exists
  export -f compat_command_exists
  export -f util_command_exists_cached
fi

# Initialize on module load
util_command_utils_init
