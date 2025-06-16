#!/usr/bin/env bash
#
# ServerSentry v2 - Sample Module
#
# This module demonstrates the complete development standards and patterns
# for creating new ServerSentry modules. It includes examples of all common
# function types, error handling, documentation, and integration patterns.

# Prevent multiple sourcing
if [[ "${SAMPLE_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
SAMPLE_MODULE_LOADED=true
export SAMPLE_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Search upward for bootstrap
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      export SERVERSENTRY_QUIET=true
      export SERVERSENTRY_AUTO_INIT=false
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done
fi

# Source core utilities
if [[ -f "${BASE_DIR}/lib/core/utils/error_utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils/error_utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Module constants
SAMPLE_CONFIG_DIR="${BASE_DIR}/config/sample"
SAMPLE_DATA_DIR="${BASE_DIR}/logs/sample"
SAMPLE_CACHE_DIR="${BASE_DIR}/cache/sample"
SAMPLE_DEFAULT_TIMEOUT=30
SAMPLE_MAX_RETRIES=3

# Configuration cache
declare -A SAMPLE_CONFIG_CACHE
declare -A SAMPLE_CONFIG_CACHE_TIME

# Function: sample_module_init
# Description: Initialize the sample module with required directories and default configuration
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   sample_module_init
# Dependencies:
#   - util_error_validate_input
sample_module_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for sample_module_init: expected 0, got $#" "sample"
    return 1
  fi

  # Create required directories
  local dirs=("$SAMPLE_CONFIG_DIR" "$SAMPLE_DATA_DIR" "$SAMPLE_CACHE_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create directory: $dir" "sample"
        return 1
      fi
      log_debug "Created directory: $dir" "sample"
    fi
  done

  # Create default configuration if it doesn't exist
  if ! sample_create_default_config; then
    log_warning "Failed to create default configuration" "sample"
  fi

  log_debug "Sample module initialized successfully" "sample"
  return 0
}

# Function: sample_create_default_config
# Description: Create default configuration file for the sample module
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   sample_create_default_config
# Dependencies:
#   - util_error_validate_input
sample_create_default_config() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for sample_create_default_config: expected 0, got $#" "sample"
    return 1
  fi

  local config_file="$SAMPLE_CONFIG_DIR/sample.conf"

  # Only create if it doesn't exist
  if [[ -f "$config_file" ]]; then
    log_debug "Configuration file already exists: $config_file" "sample"
    return 0
  fi

  # Create default configuration
  if ! cat >"$config_file" <<EOF; then
# Sample Module Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Basic Settings
enabled=true
debug_mode=false
timeout=$SAMPLE_DEFAULT_TIMEOUT
max_retries=$SAMPLE_MAX_RETRIES

# Processing Settings
processing_mode=standard
batch_size=100
cache_ttl=300

# Output Settings
output_format=json
include_metadata=true
compress_output=false

# Advanced Settings
parallel_processing=false
memory_limit=512
disk_quota=1024
EOF
    log_error "Failed to create default configuration: $config_file" "sample"
    return 1
  fi

  log_debug "Created default configuration: $config_file" "sample"
  return 0
}

# Function: sample_get_config_value
# Description: Get configuration value with caching and default fallback
# Parameters:
#   $1 (string): configuration key
#   $2 (string): default value
#   $3 (numeric): cache TTL in seconds (optional, default: 300)
# Returns:
#   Configuration value via stdout
# Example:
#   timeout=$(sample_get_config_value "timeout" "30" 300)
# Dependencies:
#   - util_error_validate_input
sample_get_config_value() {
  if ! util_error_validate_input "sample_get_config_value" "2" "$#"; then
    echo "$2"
    return 1
  fi

  local key="$1"
  local default_value="$2"
  local cache_ttl="${3:-300}"

  # Validate key format
  if [[ ! "$key" =~ ^[a-zA-Z0-9_]+$ ]]; then
    log_error "Invalid configuration key: $key" "sample"
    echo "$default_value"
    return 1
  fi

  local cache_key="config_${key}"
  local current_time
  current_time=$(date +%s)

  # Check cache validity
  if [[ -n "${SAMPLE_CONFIG_CACHE[$cache_key]:-}" ]] && [[ -n "${SAMPLE_CONFIG_CACHE_TIME[$cache_key]:-}" ]]; then
    local cache_age=$((current_time - SAMPLE_CONFIG_CACHE_TIME[$cache_key]))
    if [[ "$cache_age" -lt "$cache_ttl" ]]; then
      echo "${SAMPLE_CONFIG_CACHE[$cache_key]}"
      return 0
    fi
  fi

  # Read from configuration file
  local config_file="$SAMPLE_CONFIG_DIR/sample.conf"
  local value

  if [[ -f "$config_file" ]]; then
    value=$(grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  fi

  # Use default if not found
  if [[ -z "$value" ]]; then
    value="$default_value"
  fi

  # Cache the value
  SAMPLE_CONFIG_CACHE[$cache_key]="$value"
  SAMPLE_CONFIG_CACHE_TIME[$cache_key]="$current_time"

  echo "$value"
  return 0
}

# Function: sample_validate_input_data
# Description: Validate input data with multiple validation types
# Parameters:
#   $1 (string): input data to validate
#   $2 (string): validation type (email|url|number|alphanumeric|file|directory)
# Returns:
#   0 - valid input
#   1 - invalid input
# Example:
#   if sample_validate_input_data "user@example.com" "email"; then
# Dependencies:
#   - util_error_validate_input
sample_validate_input_data() {
  if ! util_error_validate_input "sample_validate_input_data" "2" "$#"; then
    return 1
  fi

  local input_data="$1"
  local validation_type="$2"

  if [[ -z "$input_data" ]]; then
    log_error "Empty input data provided" "sample"
    return 1
  fi

  case "$validation_type" in
  "email")
    if [[ ! "$input_data" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      log_error "Invalid email format: $input_data" "sample"
      return 1
    fi
    ;;
  "url")
    if [[ ! "$input_data" =~ ^https?://[a-zA-Z0-9.-]+.*$ ]]; then
      log_error "Invalid URL format: $input_data" "sample"
      return 1
    fi
    ;;
  "number")
    if [[ ! "$input_data" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      log_error "Invalid number format: $input_data" "sample"
      return 1
    fi
    ;;
  "alphanumeric")
    if [[ ! "$input_data" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      log_error "Invalid alphanumeric format: $input_data" "sample"
      return 1
    fi
    ;;
  "file")
    if [[ ! -f "$input_data" ]]; then
      log_error "File not found: $input_data" "sample"
      return 1
    fi
    ;;
  "directory")
    if [[ ! -d "$input_data" ]]; then
      log_error "Directory not found: $input_data" "sample"
      return 1
    fi
    ;;
  *)
    log_error "Invalid validation type: $validation_type" "sample"
    return 1
    ;;
  esac

  log_debug "Input validation passed: $input_data ($validation_type)" "sample"
  return 0
}

# Function: sample_process_data_batch
# Description: Process data in batches with configurable processing modes
# Parameters:
#   $1 (string): input data (comma-separated values or file path)
#   $2 (string): processing mode (standard|advanced|minimal) (optional, default: standard)
#   $3 (numeric): batch size (optional, uses config default)
# Returns:
#   0 - success (outputs processed data in JSON format)
#   1 - failure
# Example:
#   result=$(sample_process_data_batch "data1,data2,data3" "advanced" 50)
# Dependencies:
#   - util_error_validate_input
#   - sample_get_config_value
#   - sample_validate_input_data
sample_process_data_batch() {
  if ! util_error_validate_input "sample_process_data_batch" "1" "$#"; then
    return 1
  fi

  local input_data="$1"
  local processing_mode="${2:-$(sample_get_config_value "processing_mode" "standard")}"
  local batch_size="${3:-$(sample_get_config_value "batch_size" "100")}"

  # Validate processing mode
  case "$processing_mode" in
  "standard" | "advanced" | "minimal")
    log_debug "Using processing mode: $processing_mode" "sample"
    ;;
  *)
    log_error "Invalid processing mode: $processing_mode" "sample"
    return 1
    ;;
  esac

  # Validate batch size
  if [[ ! "$batch_size" =~ ^[0-9]+$ ]] || [[ "$batch_size" -le 0 ]]; then
    log_error "Invalid batch size: $batch_size" "sample"
    return 1
  fi

  # Determine if input is file or data
  local data_items=()
  if [[ -f "$input_data" ]]; then
    # Read from file
    local file_content
    if ! file_content=$(cat "$input_data" 2>/dev/null); then
      log_error "Failed to read input file: $input_data" "sample"
      return 1
    fi
    IFS=',' read -ra data_items <<<"$file_content"
  else
    # Parse comma-separated data
    IFS=',' read -ra data_items <<<"$input_data"
  fi

  if [[ ${#data_items[@]} -eq 0 ]]; then
    log_error "No data items found in input" "sample"
    return 1
  fi

  # Process data in batches
  local processed_items=()
  local batch_count=0
  local total_items=${#data_items[@]}

  for ((i = 0; i < total_items; i += batch_size)); do
    batch_count=$((batch_count + 1))
    local batch_end=$((i + batch_size))
    if [[ $batch_end -gt $total_items ]]; then
      batch_end=$total_items
    fi

    log_debug "Processing batch $batch_count: items $((i + 1))-$batch_end of $total_items" "sample"

    # Process current batch
    for ((j = i; j < batch_end; j++)); do
      local item="${data_items[j]}"
      local processed_item

      case "$processing_mode" in
      "standard")
        processed_item=$(echo "$item" | tr '[:lower:]' '[:upper:]' | sed 's/[^a-zA-Z0-9]/_/g')
        ;;
      "advanced")
        processed_item=$(echo "$item" | base64 | tr -d '\n')
        ;;
      "minimal")
        processed_item="$item"
        ;;
      esac

      processed_items+=("$processed_item")
    done
  done

  # Generate JSON output
  local output_format
  output_format=$(sample_get_config_value "output_format" "json")

  case "$output_format" in
  "json")
    local json_output='{"processed_data": ['
    local first=true

    for item in "${processed_items[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        json_output+=','
      fi
      json_output+="\"$item\""
    done

    json_output+='], "metadata": {"total_items": '$total_items', "batch_count": '$batch_count', "processing_mode": "'$processing_mode'", "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}'
    echo "$json_output"
    ;;
  "text")
    for item in "${processed_items[@]}"; do
      echo "$item"
    done
    ;;
  *)
    log_error "Invalid output format: $output_format" "sample"
    return 1
    ;;
  esac

  log_debug "Successfully processed $total_items items in $batch_count batches" "sample"
  return 0
}

# Function: sample_cache_operation
# Description: Perform cached operations with TTL-based cache management
# Parameters:
#   $1 (string): cache key
#   $2 (string): operation command to execute if cache miss
#   $3 (numeric): cache TTL in seconds (optional, uses config default)
# Returns:
#   0 - success (outputs cached or fresh result)
#   1 - failure
# Example:
#   result=$(sample_cache_operation "system_info" "uname -a" 600)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
#   - sample_get_config_value
sample_cache_operation() {
  if ! util_error_validate_input "sample_cache_operation" "2" "$#"; then
    return 1
  fi

  local cache_key="$1"
  local operation_command="$2"
  local cache_ttl="${3:-$(sample_get_config_value "cache_ttl" "300")}"

  # Validate cache key
  if [[ ! "$cache_key" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid cache key: $cache_key" "sample"
    return 1
  fi

  # Validate TTL
  if [[ ! "$cache_ttl" =~ ^[0-9]+$ ]] || [[ "$cache_ttl" -le 0 ]]; then
    log_error "Invalid cache TTL: $cache_ttl" "sample"
    return 1
  fi

  local cache_file="$SAMPLE_CACHE_DIR/${cache_key}.cache"
  local cache_time_file="$SAMPLE_CACHE_DIR/${cache_key}.time"
  local current_time
  current_time=$(date +%s)

  # Check if cache exists and is valid
  if [[ -f "$cache_file" ]] && [[ -f "$cache_time_file" ]]; then
    local cache_time
    cache_time=$(cat "$cache_time_file" 2>/dev/null || echo "0")

    if [[ "$cache_time" =~ ^[0-9]+$ ]]; then
      local cache_age=$((current_time - cache_time))

      if [[ "$cache_age" -lt "$cache_ttl" ]]; then
        log_debug "Cache hit for key: $cache_key (age: ${cache_age}s)" "sample"
        cat "$cache_file"
        return 0
      else
        log_debug "Cache expired for key: $cache_key (age: ${cache_age}s)" "sample"
      fi
    fi
  fi

  # Cache miss - execute operation
  log_debug "Cache miss for key: $cache_key, executing operation" "sample"

  local result
  if ! result=$(util_error_safe_execute "$operation_command" "$SAMPLE_DEFAULT_TIMEOUT"); then
    log_error "Failed to execute cached operation: $operation_command" "sample"
    return 1
  fi

  # Store result in cache
  if ! echo "$result" >"$cache_file"; then
    log_warning "Failed to write cache file: $cache_file" "sample"
  else
    echo "$current_time" >"$cache_time_file"
    log_debug "Cached result for key: $cache_key" "sample"
  fi

  echo "$result"
  return 0
}

# Function: sample_cleanup_cache
# Description: Clean up expired cache files and manage cache size
# Parameters:
#   $1 (numeric): maximum cache age in seconds (optional, default: 3600)
#   $2 (numeric): maximum cache size in MB (optional, default: 100)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   sample_cleanup_cache 3600 100
# Dependencies:
#   - util_error_validate_input
sample_cleanup_cache() {
  if ! util_error_validate_input "sample_cleanup_cache" "0" "$#"; then
    return 1
  fi

  local max_age="${1:-3600}"
  local max_size_mb="${2:-100}"

  # Validate parameters
  if [[ ! "$max_age" =~ ^[0-9]+$ ]] || [[ "$max_age" -le 0 ]]; then
    log_error "Invalid maximum cache age: $max_age" "sample"
    return 1
  fi

  if [[ ! "$max_size_mb" =~ ^[0-9]+$ ]] || [[ "$max_size_mb" -le 0 ]]; then
    log_error "Invalid maximum cache size: $max_size_mb" "sample"
    return 1
  fi

  if [[ ! -d "$SAMPLE_CACHE_DIR" ]]; then
    log_debug "Cache directory does not exist: $SAMPLE_CACHE_DIR" "sample"
    return 0
  fi

  local current_time
  current_time=$(date +%s)
  local cleanup_count=0

  # Clean up expired cache files
  local cache_files
  if cache_files=$(find "$SAMPLE_CACHE_DIR" -name "*.cache" -type f 2>/dev/null); then
    while read -r cache_file; do
      if [[ -n "$cache_file" ]]; then
        local time_file="${cache_file%.cache}.time"

        if [[ -f "$time_file" ]]; then
          local cache_time
          cache_time=$(cat "$time_file" 2>/dev/null || echo "0")

          if [[ "$cache_time" =~ ^[0-9]+$ ]]; then
            local cache_age=$((current_time - cache_time))

            if [[ "$cache_age" -gt "$max_age" ]]; then
              if rm -f "$cache_file" "$time_file"; then
                cleanup_count=$((cleanup_count + 1))
                log_debug "Removed expired cache file: $cache_file (age: ${cache_age}s)" "sample"
              fi
            fi
          fi
        else
          # Remove cache file without time file
          if rm -f "$cache_file"; then
            cleanup_count=$((cleanup_count + 1))
            log_debug "Removed orphaned cache file: $cache_file" "sample"
          fi
        fi
      fi
    done <<<"$cache_files"
  fi

  # Check total cache size and clean if necessary
  if command -v du >/dev/null 2>&1; then
    local cache_size_kb
    cache_size_kb=$(du -sk "$SAMPLE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    local cache_size_mb=$((cache_size_kb / 1024))

    if [[ "$cache_size_mb" -gt "$max_size_mb" ]]; then
      log_warning "Cache size ($cache_size_mb MB) exceeds limit ($max_size_mb MB), cleaning oldest files" "sample"

      # Remove oldest cache files until under limit
      local old_cache_files
      if old_cache_files=$(find "$SAMPLE_CACHE_DIR" -name "*.cache" -type f -exec ls -t {} + 2>/dev/null | tail -n +10); then
        while read -r old_file; do
          if [[ -n "$old_file" ]]; then
            local old_time_file="${old_file%.cache}.time"
            if rm -f "$old_file" "$old_time_file"; then
              cleanup_count=$((cleanup_count + 1))
              log_debug "Removed old cache file for size management: $old_file" "sample"
            fi
          fi
        done <<<"$old_cache_files"
      fi
    fi
  fi

  log_debug "Cache cleanup completed: $cleanup_count files removed" "sample"
  return 0
}

# Function: sample_get_module_status
# Description: Get comprehensive status information about the sample module
# Parameters: None
# Returns:
#   0 - success (outputs JSON status)
#   1 - failure
# Example:
#   status=$(sample_get_module_status)
# Dependencies:
#   - util_error_validate_input
#   - sample_get_config_value
sample_get_module_status() {
  if ! util_error_validate_input "sample_get_module_status" "0" "$#"; then
    return 1
  fi

  # Collect status information
  local enabled
  enabled=$(sample_get_config_value "enabled" "false")

  local config_file="$SAMPLE_CONFIG_DIR/sample.conf"
  local config_exists="false"
  if [[ -f "$config_file" ]]; then
    config_exists="true"
  fi

  # Count cache files
  local cache_count=0
  local cache_size=0
  if [[ -d "$SAMPLE_CACHE_DIR" ]]; then
    local cache_files
    if cache_files=$(find "$SAMPLE_CACHE_DIR" -name "*.cache" -type f 2>/dev/null); then
      cache_count=$(echo "$cache_files" | grep -c . 2>/dev/null || echo "0")
    fi

    if command -v du >/dev/null 2>&1; then
      cache_size=$(du -sb "$SAMPLE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    fi
  fi

  # Generate status JSON
  cat <<EOF
{
  "sample_module_status": {
    "enabled": $enabled,
    "configuration": {
      "file_exists": $config_exists,
      "file_path": "$config_file"
    },
    "directories": {
      "config_dir": "$SAMPLE_CONFIG_DIR",
      "data_dir": "$SAMPLE_DATA_DIR",
      "cache_dir": "$SAMPLE_CACHE_DIR"
    },
    "cache": {
      "file_count": $cache_count,
      "size_bytes": $cache_size
    },
    "constants": {
      "default_timeout": $SAMPLE_DEFAULT_TIMEOUT,
      "max_retries": $SAMPLE_MAX_RETRIES
    },
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF

  return 0
}

# Export all sample module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f sample_module_init
  export -f sample_create_default_config
  export -f sample_get_config_value
  export -f sample_validate_input_data
  export -f sample_process_data_batch
  export -f sample_cache_operation
  export -f sample_cleanup_cache
  export -f sample_get_module_status
fi

# Initialize the module
if ! sample_module_init; then
  log_error "Failed to initialize sample module" "sample"
fi
