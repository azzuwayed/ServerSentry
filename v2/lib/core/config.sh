#!/bin/bash
#
# ServerSentry v2 - Configuration Management
#
# This module handles loading, parsing, and validating YAML configuration

# Configuration settings
CONFIG_DIR="${CONFIG_DIR:-${BASE_DIR}/config}"
MAIN_CONFIG="${MAIN_CONFIG:-${CONFIG_DIR}/serversentry.yaml}"
CONFIG_NAMESPACE="config"

# Source utilities
source "${BASE_DIR}/lib/core/logging.sh"
source "${BASE_DIR}/lib/core/utils.sh"

# Configuration validation rules
declare -a CONFIG_VALIDATION_RULES=(
  "enabled:boolean:"
  "log_level:log_level:"
  "check_interval:positive_numeric:"
  "plugins_enabled:required:"
  "notification_enabled:boolean:"
  "max_log_size:positive_numeric:"
  "max_log_archives:positive_numeric:"
  "check_timeout:positive_numeric:"
  "teams_webhook_url:url:"
  "email_to:email:"
)

# New standardized function: config_init
# Description: Initialize configuration system with proper validation and directory setup
# Returns:
#   0 - success
#   1 - failure
config_init() {
  log_debug "Initializing configuration system"

  # Validate and create configuration directory
  if ! util_validate_dir_exists "$CONFIG_DIR" "Configuration directory"; then
    log_info "Creating configuration directory: $CONFIG_DIR"
    if ! create_secure_dir "$CONFIG_DIR" 755; then
      log_error "Failed to create configuration directory: $CONFIG_DIR"
      return 1
    fi
  fi

  # Check if main configuration file exists
  if ! util_validate_file_exists "$MAIN_CONFIG" "Main configuration file"; then
    log_info "Creating default configuration file: $MAIN_CONFIG"
    if ! config_create_default; then
      return 1
    fi
  fi

  log_debug "Configuration system initialized successfully"
  return 0
}

# New standardized function: config_load
# Description: Load and validate configuration with caching support
# Returns:
#   0 - success
#   1 - failure
config_load() {
  log_debug "Loading configuration from $MAIN_CONFIG"

  # Initialize configuration system
  if ! config_init; then
    return 1
  fi

  # Use cached configuration loading
  if ! util_config_get_cached "$MAIN_CONFIG" "$CONFIG_NAMESPACE" 300; then
    log_error "Failed to load configuration"
    return 1
  fi

  # Validate configuration values
  if ! util_config_validate_values CONFIG_VALIDATION_RULES "$CONFIG_NAMESPACE"; then
    log_error "Configuration validation failed"
    return 1
  fi

  # Load environment variable overrides
  util_config_load_env_overrides "SERVERSENTRY" "$CONFIG_NAMESPACE"

  log_info "Configuration loaded and validated successfully"
  return 0
}

# New standardized function: config_get_value
# Description: Get configuration value with optional default
# Parameters:
#   $1 - key name
#   $2 - default value (optional)
# Returns:
#   Configuration value via stdout
config_get_value() {
  local key="$1"
  local default_value="${2:-}"

  util_config_get_value "$key" "$default_value" "$CONFIG_NAMESPACE"
}

# New standardized function: config_set_value
# Description: Set configuration value with validation
# Parameters:
#   $1 - key name
#   $2 - value
# Returns:
#   0 - success
#   1 - failure
config_set_value() {
  local key="$1"
  local value="$2"

  if ! util_require_param "$key" "key"; then
    return 1
  fi

  if ! util_require_param "$value" "value"; then
    return 1
  fi

  util_config_set_value "$key" "$value" "$CONFIG_NAMESPACE"
}

# New standardized function: config_create_default
# Description: Create default configuration file with secure permissions
# Returns:
#   0 - success
#   1 - failure
config_create_default() {
  local template_content
  template_content=$(
    cat <<'EOF'
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
  )

  if ! util_config_create_default "$MAIN_CONFIG" "$template_content"; then
    return 1
  fi

  log_info "Default configuration created: $MAIN_CONFIG"
  return 0
}

# New standardized function: config_validate
# Description: Validate current configuration values
# Returns:
#   0 - validation passed
#   1 - validation failed
config_validate() {
  log_debug "Validating configuration values"

  if ! util_config_validate_values CONFIG_VALIDATION_RULES "$CONFIG_NAMESPACE"; then
    log_error "Configuration validation failed"
    return 1
  fi

  log_debug "Configuration validation passed"
  return 0
}

# New standardized function: config_reload
# Description: Reload configuration from file
# Returns:
#   0 - success
#   1 - failure
config_reload() {
  log_info "Reloading configuration"

  # Clear configuration cache to force reload
  unset CONFIG_CACHE CONFIG_TIMESTAMPS
  declare -g -A CONFIG_CACHE
  declare -g -A CONFIG_TIMESTAMPS

  # Reload configuration
  config_load
}

# === BACKWARD COMPATIBILITY FUNCTIONS ===
# These maintain compatibility with existing code

# Backward compatibility: init_config
init_config() {
  log_warning "Function init_config() is deprecated, use config_init() instead"
  config_init "$@"
}

# Backward compatibility: load_config
load_config() {
  log_warning "Function load_config() is deprecated, use config_load() instead"
  config_load "$@"
}

# Backward compatibility: get_config
get_config() {
  log_warning "Function get_config() is deprecated, use config_get_value() instead"
  config_get_value "$@"
}

# Backward compatibility: parse_config (now internal only)
parse_config() {
  log_warning "Function parse_config() is deprecated, use util_config_parse_yaml() instead"
  local config_file="$1"
  util_config_parse_yaml "$config_file" "$CONFIG_NAMESPACE"
}

# Backward compatibility: apply_defaults (now handled by utility)
apply_defaults() {
  log_warning "Function apply_defaults() is deprecated, defaults are applied automatically"
  return 0
}

# Backward compatibility: validate_config
validate_config() {
  log_warning "Function validate_config() is deprecated, use config_validate() instead"
  config_validate "$@"
}

# Backward compatibility: load_env_overrides (now handled by utility)
load_env_overrides() {
  log_warning "Function load_env_overrides() is deprecated, overrides are loaded automatically"
  util_config_load_env_overrides "SERVERSENTRY" "$CONFIG_NAMESPACE"
}

# Backward compatibility: create_default_config
create_default_config() {
  log_warning "Function create_default_config() is deprecated, use config_create_default() instead"
  config_create_default "$@"
}

# Export new standardized functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f config_init
  export -f config_load
  export -f config_get_value
  export -f config_set_value
  export -f config_create_default
  export -f config_validate
  export -f config_reload

  # Export backward compatibility functions
  export -f init_config
  export -f load_config
  export -f get_config
  export -f parse_config
  export -f apply_defaults
  export -f validate_config
  export -f load_env_overrides
  export -f create_default_config
fi
