#!/bin/bash
#
# ServerSentry v2 - Configuration Management
#
# This module handles loading, parsing, and validating YAML configuration

# Configuration settings
CONFIG_DIR="${BASE_DIR}/config"
MAIN_CONFIG="${CONFIG_DIR}/serversentry.yaml"
CONFIG_NAMESPACE="config"

source "${BASE_DIR}/lib/core/logging.sh"

# Initialize configuration
init_config() {
  log_debug "Initializing configuration system"

  # Check if configuration directory exists
  if [ ! -d "$CONFIG_DIR" ]; then
    log_warning "Configuration directory not found: $CONFIG_DIR"
    log_info "Creating default configuration directory"
    mkdir -p "$CONFIG_DIR" || return 1
  fi

  # Check if main configuration file exists
  if [ ! -f "$MAIN_CONFIG" ]; then
    log_warning "Main configuration file not found: $MAIN_CONFIG"
    log_info "Creating default configuration file"
    create_default_config || return 1
  fi

  return 0
}

# Load configuration
load_config() {
  log_debug "Loading configuration from $MAIN_CONFIG"

  # Initialize configuration system
  init_config || return 1

  # Parse YAML configuration
  parse_config "$MAIN_CONFIG" || return 1

  # Apply default values
  apply_defaults

  # Validate configuration
  validate_config || return 1

  # Load environment variables that override config
  load_env_overrides

  return 0
}

# Parse YAML configuration file
parse_config() {
  local config_file="$1"

  # Check if yq is available for better YAML parsing
  if command -v yq >/dev/null 2>&1; then
    log_debug "Parsing configuration with yq"

    # Use yq to parse YAML into key-value pairs
    while IFS=': ' read -r key value; do
      # Skip empty lines and comments
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

      # Trim whitespace and quotes
      key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

      # Store in configuration
      if [ -n "$key" ] && [ -n "$value" ]; then
        log_debug "Setting config: $key = $value"
        eval "${CONFIG_NAMESPACE}_${key}='${value}'"
      fi
    done < <(yq -r '. | to_entries | .[] | "\(.key): \(.value)"' "$config_file")
  else
    log_debug "Parsing configuration with basic parser (yq not available)"

    # Basic YAML parser
    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$line" ]] && continue

      # Parse key-value pairs
      if [[ "$line" =~ ^[[:space:]]*([^:]+)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"

        # Trim whitespace and brackets
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^\[//;s/\]$//')

        # Store in configuration
        if [ -n "$key" ] && [ -n "$value" ]; then
          log_debug "Setting config: $key = $value"
          eval "${CONFIG_NAMESPACE}_${key}='${value}'"
        fi
      fi
    done <"$config_file"
  fi

  return 0
}

# Apply default values for configuration
apply_defaults() {
  log_debug "Applying default configuration values"

  # Default log level
  if [ -z "${config_log_level:-}" ]; then
    config_log_level="info"
    log_debug "Using default for log_level: $config_log_level"
  fi

  # Default check interval
  if [ -z "${config_check_interval:-}" ]; then
    config_check_interval="60"
    log_debug "Using default for check_interval: $config_check_interval"
  fi

  # Default enabled status
  if [ -z "${config_enabled:-}" ]; then
    config_enabled="true"
    log_debug "Using default for enabled: $config_enabled"
  fi

  # Default plugins enabled
  if [ -z "${config_plugins_enabled:-}" ]; then
    config_plugins_enabled="cpu,memory,disk"
    log_debug "Using default for plugins_enabled: $config_plugins_enabled"
  fi

  # Default notification settings
  if [ -z "${config_notification_enabled:-}" ]; then
    config_notification_enabled="true"
    log_debug "Using default for notification_enabled: $config_notification_enabled"
  fi

  # Default max log size (10MB)
  if [ -z "${config_max_log_size:-}" ]; then
    config_max_log_size="10485760"
    log_debug "Using default for max_log_size: $config_max_log_size"
  fi

  # Default max log archives
  if [ -z "${config_max_log_archives:-}" ]; then
    config_max_log_archives="10"
    log_debug "Using default for max_log_archives: $config_max_log_archives"
  fi

  return 0
}

# Validate configuration
validate_config() {
  log_debug "Validating configuration"

  # Validate log level
  case "${config_log_level}" in
  debug | info | warning | error) ;;
  *)
    log_error "Invalid log_level: ${config_log_level}"
    return 1
    ;;
  esac

  # Validate check interval
  if ! [[ "${config_check_interval}" =~ ^[0-9]+$ ]]; then
    log_error "Invalid check_interval: ${config_check_interval}"
    return 1
  fi

  # Validate enabled status
  if ! [[ "${config_enabled}" =~ ^(true|false)$ ]]; then
    log_error "Invalid enabled status: ${config_enabled}"
    return 1
  fi

  return 0
}

# Load environment variable overrides
load_env_overrides() {
  log_debug "Loading environment variable overrides"

  # Look for SERVERSENTRY_ prefixed environment variables
  for var in $(env | grep "^SERVERSENTRY_" | cut -d= -f1); do
    # Convert to lowercase and remove prefix
    local key=$(echo "${var#SERVERSENTRY_}" | tr '[:upper:]' '[:lower:]')
    local value="${!var}"

    log_debug "Override from environment: $key = $value"
    eval "${CONFIG_NAMESPACE}_${key}='${value}'"
  done

  return 0
}

# Create default configuration
create_default_config() {
  log_debug "Creating default configuration file: $MAIN_CONFIG"

  # Create parent directory if it doesn't exist
  mkdir -p "$(dirname "$MAIN_CONFIG")" || return 1

  # Create YAML configuration file
  cat >"$MAIN_CONFIG" <<EOF
# ServerSentry v2 Configuration

# General settings
enabled: true
log_level: info
check_interval: 60

# Plugin settings
plugins_enabled: [cpu, memory, disk]

# Notification settings
notification_enabled: true
notification_channels: []

# Teams notification settings
teams_webhook_url: ""
teams_notification_title: "ServerSentry Alert"

# Email notification settings
email_enabled: false
email_from: "serversentry@localhost"
email_to: ""
email_subject: "[ServerSentry] Alert: {status}"

# Advanced settings
max_log_size: 10485760  # 10MB
max_log_archives: 10
check_timeout: 30
EOF

  return 0
}

# Get configuration value
get_config() {
  local key="$1"
  local default_value="${2:-}"

  local var_name="${CONFIG_NAMESPACE}_${key}"
  local value="${!var_name}"

  # Return the value or default
  if [ -z "$value" ]; then
    echo "$default_value"
  else
    echo "$value"
  fi
}
