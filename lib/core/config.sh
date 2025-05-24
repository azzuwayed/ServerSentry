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
  "system.enabled:boolean:"
  "system.log_level:log_level:"
  "system.check_interval:positive_numeric:"
  "plugins.enabled:required:"
  "notifications.enabled:boolean:"
  "system.max_log_size:positive_numeric:"
  "system.max_log_archives:positive_numeric:"
  "system.check_timeout:positive_numeric:"
  "notifications.teams.webhook_url:url:"
  "notifications.email.to:email:"
)

# Initialize configuration system with proper validation and directory setup
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

# Load and validate configuration with caching support
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

# Get configuration value with optional default
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

# Set configuration value with validation
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

# Create default configuration file with secure permissions
# Returns:
#   0 - success
#   1 - failure
config_create_default() {
  local template_content
  template_content=$(
    cat <<'EOF'
# ServerSentry v2 Configuration
# Main configuration file for the ServerSentry monitoring system

# Core System Settings
system:
  enabled: true
  log_level: info
  check_interval: 60
  check_timeout: 30
  max_log_size: 10485760  # 10MB
  max_log_archives: 10

# Plugin Configuration
plugins:
  enabled: [cpu, memory, disk]
  directory: lib/plugins
  config_directory: config/plugins

# Notification System
notifications:
  enabled: true
  channels: []
  cooldown_period: 300  # 5 minutes between notifications
  
  # Teams Integration
  teams:
    webhook_url: ""
    notification_title: "ServerSentry Alert"
    enabled: false
  
  # Email Configuration
  email:
    enabled: false
    from: "serversentry@localhost"
    to: ""
    subject: "[ServerSentry] Alert: {status}"
    smtp_server: "localhost"
    smtp_port: 587

# Anomaly Detection
anomaly_detection:
  enabled: true
  default_sensitivity: 2.0
  data_retention_days: 30
  minimum_data_points: 10

# Composite Checks
composite_checks:
  enabled: true
  config_directory: config/composite

# Performance Monitoring
performance:
  track_plugin_performance: true
  track_system_performance: true
  performance_log_retention_days: 7

# Security Settings
security:
  file_permissions:
    config_files: 644
    log_files: 644
    directories: 755

# Advanced Features
advanced:
  enable_json_output: true
  enable_webhook_notifications: true
  enable_template_system: true
  enable_diagnostics: true
EOF
  )

  if ! util_config_create_default "$MAIN_CONFIG" "$template_content"; then
    return 1
  fi

  log_info "Default configuration created: $MAIN_CONFIG"
  return 0
}

# Validate current configuration values
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

# Reload configuration from file
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

# Export functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f config_init
  export -f config_load
  export -f config_get_value
  export -f config_set_value
  export -f config_create_default
  export -f config_validate
  export -f config_reload
fi
