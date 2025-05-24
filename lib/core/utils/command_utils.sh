#!/bin/bash
#
# ServerSentry v2 - Command Utilities
#
# This module provides command caching and optimization utilities

# Check bash version for associative array support
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  # Command cache for optimization (bash 4+)
  declare -A COMMAND_CACHE
  declare -A COMMAND_CACHE_TIME
  declare -A COMMAND_CACHE_HITS
  declare -A COMMAND_CACHE_MISSES
  COMMAND_CACHE_SUPPORTED=true
else
  # Fallback for older bash versions
  COMMAND_CACHE_SUPPORTED=false
fi

# Command cache configuration
COMMAND_CACHE_DEFAULT_DURATION=60
COMMAND_CACHE_MAX_SIZE=1000
COMMAND_CACHE_LOG="${BASE_DIR}/logs/command_cache.log"

# Create cache directory if it doesn't exist
mkdir -p "${BASE_DIR}/logs" 2>/dev/null || true

# Function: util_cached_command
# Description: Execute command with caching support
# Parameters:
#   $1 - command to execute
#   $2 - cache duration in seconds (optional, defaults to 60)
#   $3 - cache key (optional, auto-generated from command)
# Returns:
#   Command output via stdout
util_cached_command() {
  local command="$1"
  local cache_duration="${2:-$COMMAND_CACHE_DEFAULT_DURATION}"
  local cache_key="${3:-}"

  # Validate input
  if ! util_require_param "$command" "command"; then
    return 1
  fi

  # Generate cache key if not provided
  if [[ -z "$cache_key" ]]; then
    cache_key="cmd_$(echo "$command" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "${command//[^a-zA-Z0-9]/_}")"
  fi

  # Check if caching is supported
  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    # Execute without caching
    eval "$command"
    return $?
  fi

  local current_time
  current_time=$(date +%s)
  local cache_time="${COMMAND_CACHE_TIME[$cache_key]:-0}"

  # Check if cache is valid
  if [[ -n "${COMMAND_CACHE[$cache_key]}" ]] && [[ $((current_time - cache_time)) -lt "$cache_duration" ]]; then
    # Cache hit
    ((COMMAND_CACHE_HITS["$cache_key"]++))
    log_debug "Command cache hit: $cache_key"
    echo "${COMMAND_CACHE[$cache_key]}"
    return 0
  fi

  # Cache miss - execute command
  ((COMMAND_CACHE_MISSES["$cache_key"]++))
  log_debug "Command cache miss: $cache_key"

  local result
  local exit_code
  if result=$(eval "$command" 2>&1); then
    exit_code=0

    # Store in cache
    COMMAND_CACHE[$cache_key]="$result"
    COMMAND_CACHE_TIME[$cache_key]="$current_time"

    # Log cache activity
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] CACHE_STORE key=$cache_key duration=${cache_duration}s" >>"$COMMAND_CACHE_LOG"

    echo "$result"
  else
    exit_code=$?
    echo "$result"
  fi

  return "$exit_code"
}

# Function: util_command_cache_clear
# Description: Clear command cache
# Parameters:
#   $1 - cache key pattern (optional, clears all if empty)
# Returns:
#   0 - success
util_command_cache_clear() {
  local pattern="${1:-}"

  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    log_debug "Command cache not supported"
    return 0
  fi

  if [[ -z "$pattern" ]]; then
    # Clear all cache
    COMMAND_CACHE=()
    COMMAND_CACHE_TIME=()
    log_debug "Command cache cleared completely"
  else
    # Clear matching keys
    for key in "${!COMMAND_CACHE[@]}"; do
      if [[ "$key" =~ $pattern ]]; then
        unset COMMAND_CACHE["$key"]
        unset COMMAND_CACHE_TIME["$key"]
        log_debug "Cleared cache key: $key"
      fi
    done
  fi

  return 0
}

# Function: util_command_cache_stats
# Description: Get command cache statistics
# Returns:
#   Cache statistics JSON via stdout
util_command_cache_stats() {
  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    echo '{"error": "Command cache not supported in bash < 4.0"}'
    return 0
  fi

  local stats_json="{"
  local total_entries="${#COMMAND_CACHE[@]}"
  local total_hits=0
  local total_misses=0

  # Calculate totals
  for key in "${!COMMAND_CACHE_HITS[@]}"; do
    ((total_hits += COMMAND_CACHE_HITS["$key"]))
  done

  for key in "${!COMMAND_CACHE_MISSES[@]}"; do
    ((total_misses += COMMAND_CACHE_MISSES["$key"]))
  done

  local total_requests=$((total_hits + total_misses))
  local hit_rate=0
  if [[ "$total_requests" -gt 0 ]]; then
    hit_rate=$(echo "scale=4; $total_hits * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
  fi

  stats_json+="\"total_entries\":$total_entries,"
  stats_json+="\"total_hits\":$total_hits,"
  stats_json+="\"total_misses\":$total_misses,"
  stats_json+="\"total_requests\":$total_requests,"
  stats_json+="\"hit_rate\":$hit_rate,"
  stats_json+="\"cache_size_limit\":$COMMAND_CACHE_MAX_SIZE"
  stats_json+="}"

  echo "$stats_json"
}

# Function: util_command_cache_cleanup
# Description: Clean up expired cache entries
# Parameters:
#   $1 - max age in seconds (optional, defaults to 3600)
# Returns:
#   0 - success
util_command_cache_cleanup() {
  local max_age="${1:-3600}"

  if [[ "$COMMAND_CACHE_SUPPORTED" != "true" ]]; then
    return 0
  fi

  local current_time
  current_time=$(date +%s)
  local cleaned_count=0

  for key in "${!COMMAND_CACHE_TIME[@]}"; do
    local cache_time="${COMMAND_CACHE_TIME[$key]}"
    if [[ $((current_time - cache_time)) -gt "$max_age" ]]; then
      unset COMMAND_CACHE["$key"]
      unset COMMAND_CACHE_TIME["$key"]
      unset COMMAND_CACHE_HITS["$key"]
      unset COMMAND_CACHE_MISSES["$key"]
      ((cleaned_count++))
    fi
  done

  log_debug "Command cache cleanup: removed $cleaned_count expired entries"
  return 0
}

# Function: util_batch_commands
# Description: Execute multiple commands efficiently
# Parameters:
#   $@ - commands to execute
# Returns:
#   Combined results via stdout
util_batch_commands() {
  local commands=("$@")

  if [[ "${#commands[@]}" -eq 0 ]]; then
    log_error "No commands provided for batch execution"
    return 1
  fi

  log_debug "Executing ${#commands[@]} commands in batch"

  local results=()
  local start_time
  start_time=$(date +%s.%N 2>/dev/null || date +%s)

  for command in "${commands[@]}"; do
    local result
    if result=$(util_cached_command "$command"); then
      results+=("$result")
    else
      results+=("ERROR: Command failed: $command")
    fi
  done

  local end_time
  end_time=$(date +%s.%N 2>/dev/null || date +%s)

  if command -v bc >/dev/null 2>&1; then
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    log_debug "Batch execution completed in ${duration}s"
  fi

  # Output results
  printf '%s\n' "${results[@]}"
}

# Function: util_optimize_common_commands
# Description: Pre-cache common system commands
# Returns:
#   0 - success
util_optimize_common_commands() {
  log_debug "Pre-caching common system commands"

  # Common commands that are frequently used
  local common_commands=(
    "uname -s"
    "date +%s"
    "whoami"
    "id -u"
    "command -v jq"
    "command -v bc"
    "command -v yq"
  )

  for cmd in "${common_commands[@]}"; do
    # Cache with longer duration for static commands
    util_cached_command "$cmd" 3600 >/dev/null 2>&1 || true
  done

  log_debug "Common commands pre-cached"
  return 0
}

# Function: util_command_exists_cached
# Description: Cached version of command existence check
# Parameters:
#   $1 - command name
# Returns:
#   0 - command exists
#   1 - command does not exist
util_command_exists_cached() {
  local cmd="$1"

  if ! util_require_param "$cmd" "command"; then
    return 1
  fi

  # Use cached command check with long duration (commands don't change often)
  local result
  result=$(util_cached_command "command -v '$cmd'" 3600 "cmd_exists_$cmd" 2>/dev/null)

  if [[ -n "$result" ]]; then
    return 0
  else
    return 1
  fi
}

# Function: util_get_cached_timestamp
# Description: Get cached timestamp to reduce date command calls
# Parameters:
#   $1 - cache duration in seconds (optional, defaults to 1)
# Returns:
#   Unix timestamp via stdout
util_get_cached_timestamp() {
  local cache_duration="${1:-1}"

  util_cached_command "date +%s" "$cache_duration" "timestamp"
}

# Function: util_get_cached_formatted_date
# Description: Get cached formatted date
# Parameters:
#   $1 - date format (optional, defaults to "%Y-%m-%d %H:%M:%S")
#   $2 - cache duration in seconds (optional, defaults to 1)
# Returns:
#   Formatted date via stdout
util_get_cached_formatted_date() {
  local format="${1:-"%Y-%m-%d %H:%M:%S"}"
  local cache_duration="${2:-1}"

  util_cached_command "date +'$format'" "$cache_duration" "date_$(echo "$format" | tr -d '% :')"
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_cached_command
  export -f util_command_cache_clear
  export -f util_command_cache_stats
  export -f util_command_cache_cleanup
  export -f util_batch_commands
  export -f util_optimize_common_commands
  export -f util_command_exists_cached
  export -f util_get_cached_timestamp
  export -f util_get_cached_formatted_date
fi
