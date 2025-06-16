#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Configuration Management Module
#
# This module handles anomaly detection configuration including parsing,
# validation, default configuration creation, and configuration caching.

# Prevent multiple sourcing
if [[ "${ANOMALY_CONFIG_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_CONFIG_MODULE_LOADED=true
export ANOMALY_CONFIG_MODULE_LOADED

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
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Configuration directories
ANOMALY_CONFIG_DIR="${BASE_DIR}/config/anomaly"
ANOMALY_DATA_DIR="${BASE_DIR}/logs/anomaly"
ANOMALY_RESULTS_DIR="${BASE_DIR}/logs/anomaly/results"

# Configuration cache for performance
declare -A ANOMALY_CONFIG_CACHE
declare -A ANOMALY_CONFIG_CACHE_TIME

# Function: anomaly_config_init
# Description: Initialize the anomaly configuration management system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_config_init
# Dependencies:
#   - util_error_validate_input
anomaly_config_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for anomaly_config_init: expected 0, got $#" "anomaly_config"
    return 1
  fi

  # Create required directories
  local dirs=("$ANOMALY_CONFIG_DIR" "$ANOMALY_DATA_DIR" "$ANOMALY_RESULTS_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create anomaly directory: $dir" "anomaly_config"
        return 1
      fi
      log_debug "Created anomaly directory: $dir" "anomaly_config"
    fi
  done

  # Create default configurations if they don't exist
  if ! anomaly_config_create_defaults; then
    log_error "Failed to create default anomaly configurations" "anomaly_config"
    return 1
  fi

  log_debug "Anomaly configuration management initialized" "anomaly_config"
  return 0
}

# Function: anomaly_config_create_defaults
# Description: Create default anomaly detection configurations for common plugins
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_config_create_defaults
# Dependencies:
#   - anomaly_config_create_plugin_config
anomaly_config_create_defaults() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for anomaly_config_create_defaults: expected 0, got $#" "anomaly_config"
    return 1
  fi

  # Default configurations for common system plugins
  local plugins=(
    "cpu:2.0:20:10:true:true:true:3:1800"
    "memory:1.8:25:12:true:true:true:2:1200"
    "disk:2.2:30:15:true:false:true:4:3600"
    "network:2.5:15:8:true:true:false:3:1800"
    "load:2.0:20:10:true:true:true:3:1800"
    "processes:3.0:25:12:true:false:true:5:2400"
  )

  for plugin_config in "${plugins[@]}"; do
    IFS=':' read -r plugin sensitivity window_size min_data_points check_patterns detect_spikes detect_trends notification_threshold cooldown <<<"$plugin_config"

    if ! anomaly_config_create_plugin_config "$plugin" "$sensitivity" "$window_size" "$min_data_points" "$check_patterns" "$detect_spikes" "$detect_trends" "$notification_threshold" "$cooldown"; then
      log_warning "Failed to create default config for plugin: $plugin" "anomaly_config"
    fi
  done

  log_debug "Default anomaly configurations created" "anomaly_config"
  return 0
}

# Function: anomaly_config_create_plugin_config
# Description: Create anomaly detection configuration for a specific plugin
# Parameters:
#   $1 (string): plugin name
#   $2 (numeric): sensitivity threshold (default: 2.0)
#   $3 (numeric): window size (default: 20)
#   $4 (numeric): minimum data points (default: 10)
#   $5 (boolean): check patterns (default: true)
#   $6 (boolean): detect spikes (default: true)
#   $7 (boolean): detect trends (default: true)
#   $8 (numeric): notification threshold (default: 3)
#   $9 (numeric): cooldown period in seconds (default: 1800)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_config_create_plugin_config "cpu" 2.0 20 10 true true true 3 1800
# Dependencies:
#   - util_error_validate_input
anomaly_config_create_plugin_config() {
  if ! util_error_validate_input "anomaly_config_create_plugin_config" "1" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local sensitivity="${2:-2.0}"
  local window_size="${3:-20}"
  local min_data_points="${4:-10}"
  local check_patterns="${5:-true}"
  local detect_spikes="${6:-true}"
  local detect_trends="${7:-true}"
  local notification_threshold="${8:-3}"
  local cooldown="${9:-1800}"

  # Validate plugin name
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_config"
    return 1
  fi

  local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"

  # Only create if it doesn't exist
  if [[ -f "$config_file" ]]; then
    log_debug "Anomaly config already exists for plugin: $plugin_name" "anomaly_config"
    return 0
  fi

  # Create configuration with comprehensive settings
  if ! cat >"$config_file" <<EOF; then
# Anomaly Detection Configuration for ${plugin_name}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Basic Configuration
plugin="$plugin_name"
metric="value"
enabled=true

# Detection Parameters
sensitivity=$sensitivity
window_size=$window_size
min_data_points=$min_data_points

# Pattern Detection Settings
check_patterns=$check_patterns
detect_spikes=$detect_spikes
detect_trends=$detect_trends

# Notification Settings
notification_threshold=$notification_threshold
cooldown=$cooldown

# Advanced Settings
trend_sensitivity=2.0
spike_sensitivity=3.0
confidence_threshold=0.7

# Data Management
max_data_points=1000
data_retention_days=30

# Logging
log_level=info
log_anomalies=true
log_statistics=false

# Integration
webhook_enabled=false
email_enabled=false
alert_priority=medium
EOF
    log_error "Failed to create anomaly config file: $config_file" "anomaly_config"
    return 1
  fi

  log_debug "Created anomaly config for plugin: $plugin_name" "anomaly_config"
  return 0
}

# Function: anomaly_config_parse
# Description: Parse anomaly detection configuration file with caching and validation
# Parameters:
#   $1 (string): configuration file path
#   $2 (string): plugin name for cache key
#   $3 (numeric): cache TTL in seconds (default: 300)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_config_parse "/path/to/config.conf" "cpu" 300
# Dependencies:
#   - util_error_validate_input
#   - anomaly_config_validate
anomaly_config_parse() {
  if ! util_error_validate_input "anomaly_config_parse" "2" "$#"; then
    return 1
  fi

  local config_file="$1"
  local plugin_name="$2"
  local cache_ttl="${3:-300}"

  # Validate inputs
  if [[ ! -f "$config_file" ]]; then
    log_error "Configuration file not found: $config_file" "anomaly_config"
    return 1
  fi

  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_config"
    return 1
  fi

  local cache_key="anomaly_${plugin_name}"
  local current_time
  current_time=$(date +%s)

  # Check cache validity
  if [[ -n "${ANOMALY_CONFIG_CACHE[$cache_key]:-}" ]] && [[ -n "${ANOMALY_CONFIG_CACHE_TIME[$cache_key]:-}" ]]; then
    local cache_age=$((current_time - ANOMALY_CONFIG_CACHE_TIME[$cache_key]))
    if [[ "$cache_age" -lt "$cache_ttl" ]]; then
      log_debug "Using cached config for plugin: $plugin_name" "anomaly_config"
      return 0
    fi
  fi

  # Parse configuration file
  local config_content
  if ! config_content=$(util_error_safe_execute "cat '$config_file'" 10); then
    log_error "Failed to read configuration file: $config_file" "anomaly_config"
    return 1
  fi

  # Validate configuration content
  if ! anomaly_config_validate "$config_content" "$plugin_name"; then
    log_error "Invalid configuration for plugin: $plugin_name" "anomaly_config"
    return 1
  fi

  # Cache the configuration
  ANOMALY_CONFIG_CACHE[$cache_key]="$config_content"
  ANOMALY_CONFIG_CACHE_TIME[$cache_key]="$current_time"

  log_debug "Parsed and cached config for plugin: $plugin_name" "anomaly_config"
  return 0
}

# Function: anomaly_config_validate
# Description: Validate anomaly detection configuration content
# Parameters:
#   $1 (string): configuration content
#   $2 (string): plugin name
# Returns:
#   0 - valid configuration
#   1 - invalid configuration
# Example:
#   anomaly_config_validate "$config_content" "cpu"
# Dependencies:
#   - util_error_validate_input
anomaly_config_validate() {
  if ! util_error_validate_input "anomaly_config_validate" "2" "$#"; then
    return 1
  fi

  local config_content="$1"
  local plugin_name="$2"

  if [[ -z "$config_content" ]]; then
    log_error "Empty configuration content for plugin: $plugin_name" "anomaly_config"
    return 1
  fi

  # Required configuration keys
  local required_keys=("plugin" "enabled" "sensitivity" "window_size" "min_data_points")

  for key in "${required_keys[@]}"; do
    if ! echo "$config_content" | grep -q "^${key}="; then
      log_error "Missing required configuration key '$key' for plugin: $plugin_name" "anomaly_config"
      return 1
    fi
  done

  # Validate numeric values
  local numeric_keys=("sensitivity" "window_size" "min_data_points" "notification_threshold" "cooldown")

  for key in "${numeric_keys[@]}"; do
    local value
    value=$(echo "$config_content" | grep "^${key}=" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    if [[ -n "$value" ]] && [[ ! "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
      log_error "Invalid numeric value for '$key': $value in plugin: $plugin_name" "anomaly_config"
      return 1
    fi
  done

  # Validate boolean values
  local boolean_keys=("enabled" "check_patterns" "detect_spikes" "detect_trends")

  for key in "${boolean_keys[@]}"; do
    local value
    value=$(echo "$config_content" | grep "^${key}=" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    if [[ -n "$value" ]] && [[ ! "$value" =~ ^(true|false)$ ]]; then
      log_error "Invalid boolean value for '$key': $value in plugin: $plugin_name" "anomaly_config"
      return 1
    fi
  done

  log_debug "Configuration validation passed for plugin: $plugin_name" "anomaly_config"
  return 0
}

# Function: anomaly_config_get_value
# Description: Get configuration value for a plugin with default fallback
# Parameters:
#   $1 (string): plugin name
#   $2 (string): configuration key
#   $3 (string): default value
# Returns:
#   Configuration value via stdout
# Example:
#   sensitivity=$(anomaly_config_get_value "cpu" "sensitivity" "2.0")
# Dependencies:
#   - util_error_validate_input
anomaly_config_get_value() {
  if ! util_error_validate_input "anomaly_config_get_value" "3" "$#"; then
    echo "$3"
    return 1
  fi

  local plugin_name="$1"
  local key="$2"
  local default_value="$3"

  local cache_key="anomaly_${plugin_name}"

  # Check if configuration is cached
  if [[ -z "${ANOMALY_CONFIG_CACHE[$cache_key]:-}" ]]; then
    local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"
    if [[ -f "$config_file" ]]; then
      if ! anomaly_config_parse "$config_file" "$plugin_name"; then
        echo "$default_value"
        return 1
      fi
    else
      echo "$default_value"
      return 1
    fi
  fi

  # Extract value from cached configuration
  local value
  value=$(echo "${ANOMALY_CONFIG_CACHE[$cache_key]}" | grep "^${key}=" | cut -d'=' -f2 | tr -d '"' | tr -d "'")

  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "$default_value"
  fi
}

# Function: anomaly_config_set_value
# Description: Set configuration value for a plugin and update cache
# Parameters:
#   $1 (string): plugin name
#   $2 (string): configuration key
#   $3 (string): new value
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_config_set_value "cpu" "sensitivity" "2.5"
# Dependencies:
#   - util_error_validate_input
#   - anomaly_config_validate
anomaly_config_set_value() {
  if ! util_error_validate_input "anomaly_config_set_value" "3" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local key="$2"
  local new_value="$3"

  # Validate inputs
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_config"
    return 1
  fi

  if [[ ! "$key" =~ ^[a-zA-Z0-9_]+$ ]]; then
    log_error "Invalid configuration key: $key" "anomaly_config"
    return 1
  fi

  local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"

  if [[ ! -f "$config_file" ]]; then
    log_error "Configuration file not found: $config_file" "anomaly_config"
    return 1
  fi

  # Create backup
  local backup_file="${config_file}.backup.$(date +%s)"
  if ! cp "$config_file" "$backup_file"; then
    log_error "Failed to create backup of config file: $config_file" "anomaly_config"
    return 1
  fi

  # Update configuration file
  if ! sed -i.tmp "s/^${key}=.*/${key}=${new_value}/" "$config_file"; then
    log_error "Failed to update configuration key '$key' in file: $config_file" "anomaly_config"
    # Restore backup
    mv "$backup_file" "$config_file"
    return 1
  fi

  # Remove temporary file if it exists
  [[ -f "${config_file}.tmp" ]] && rm -f "${config_file}.tmp"

  # Invalidate cache
  local cache_key="anomaly_${plugin_name}"
  unset ANOMALY_CONFIG_CACHE["$cache_key"]
  unset ANOMALY_CONFIG_CACHE_TIME["$cache_key"]

  # Reload configuration
  if ! anomaly_config_parse "$config_file" "$plugin_name"; then
    log_error "Failed to reload configuration after update for plugin: $plugin_name" "anomaly_config"
    # Restore backup
    mv "$backup_file" "$config_file"
    return 1
  fi

  # Remove backup on success
  rm -f "$backup_file"

  log_debug "Updated configuration '$key'='$new_value' for plugin: $plugin_name" "anomaly_config"
  return 0
}

# Function: anomaly_config_list_plugins
# Description: List all plugins with anomaly detection configurations
# Parameters: None
# Returns:
#   0 - success (outputs plugin list)
#   1 - failure
# Example:
#   plugins=$(anomaly_config_list_plugins)
# Dependencies:
#   - util_error_validate_input
anomaly_config_list_plugins() {
  if ! util_error_validate_input "anomaly_config_list_plugins" "0" "$#"; then
    return 1
  fi

  if [[ ! -d "$ANOMALY_CONFIG_DIR" ]]; then
    log_error "Anomaly configuration directory not found: $ANOMALY_CONFIG_DIR" "anomaly_config"
    return 1
  fi

  # Find all anomaly configuration files
  local config_files
  if ! config_files=$(find "$ANOMALY_CONFIG_DIR" -name "*_anomaly.conf" -type f 2>/dev/null); then
    log_error "Failed to list anomaly configuration files" "anomaly_config"
    return 1
  fi

  if [[ -z "$config_files" ]]; then
    log_debug "No anomaly configuration files found" "anomaly_config"
    return 1
  fi

  # Extract plugin names
  echo "$config_files" | while read -r config_file; do
    local filename
    filename=$(basename "$config_file")
    local plugin_name
    plugin_name="${filename%_anomaly.conf}"
    echo "$plugin_name"
  done

  return 0
}

# Function: anomaly_config_get_summary
# Description: Get comprehensive configuration summary for all plugins
# Parameters: None
# Returns:
#   0 - success (outputs JSON summary)
#   1 - failure
# Example:
#   summary=$(anomaly_config_get_summary)
# Dependencies:
#   - anomaly_config_list_plugins
#   - anomaly_config_get_value
anomaly_config_get_summary() {
  if ! util_error_validate_input "anomaly_config_get_summary" "0" "$#"; then
    return 1
  fi

  local plugins
  if ! plugins=$(anomaly_config_list_plugins); then
    echo '{"error": "No anomaly configurations found"}'
    return 1
  fi

  local summary='{"anomaly_configurations": ['
  local first=true

  while read -r plugin_name; do
    if [[ -n "$plugin_name" ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        summary+=','
      fi

      local enabled
      enabled=$(anomaly_config_get_value "$plugin_name" "enabled" "false")
      local sensitivity
      sensitivity=$(anomaly_config_get_value "$plugin_name" "sensitivity" "2.0")
      local window_size
      window_size=$(anomaly_config_get_value "$plugin_name" "window_size" "20")
      local notification_threshold
      notification_threshold=$(anomaly_config_get_value "$plugin_name" "notification_threshold" "3")

      summary+="{\"plugin\": \"$plugin_name\", \"enabled\": $enabled, \"sensitivity\": $sensitivity, \"window_size\": $window_size, \"notification_threshold\": $notification_threshold}"
    fi
  done <<<"$plugins"

  summary+='], "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
  echo "$summary"
  return 0
}

# Export all configuration functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_config_init
  export -f anomaly_config_create_defaults
  export -f anomaly_config_create_plugin_config
  export -f anomaly_config_parse
  export -f anomaly_config_validate
  export -f anomaly_config_get_value
  export -f anomaly_config_set_value
  export -f anomaly_config_list_plugins
  export -f anomaly_config_get_summary
fi

# Initialize the module
if ! anomaly_config_init; then
  log_error "Failed to initialize anomaly configuration module" "anomaly_config"
fi
