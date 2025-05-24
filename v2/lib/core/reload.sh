#!/bin/bash
#
# ServerSentry v2 - Dynamic Reload System
#
# This module handles dynamic configuration and plugin reloading via SIGUSR1 signal
# Allows updating configuration without restarting the monitoring service

# Reload configuration
RELOAD_LOG_FILE="${BASE_DIR}/logs/reload.log"
RELOAD_STATE_FILE="${BASE_DIR}/logs/reload.state"

# Initialize reload system
init_reload_system() {
  log_debug "Initializing dynamic reload system"

  # Create reload log if it doesn't exist
  if [ ! -f "$RELOAD_LOG_FILE" ]; then
    touch "$RELOAD_LOG_FILE"
  fi

  # Set up signal handlers
  setup_signal_handlers

  return 0
}

# Set up signal handlers for dynamic reload
setup_signal_handlers() {
  log_debug "Setting up signal handlers for dynamic reload"

  # Handle SIGUSR1 for configuration reload
  trap 'handle_reload_signal' USR1

  # Handle SIGUSR2 for plugin reload
  trap 'handle_plugin_reload_signal' USR2

  # Handle SIGHUP for log rotation
  trap 'handle_log_rotation_signal' HUP

  log_debug "Signal handlers configured"
}

# Handle reload signal (SIGUSR1)
handle_reload_signal() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  log_info "Received reload signal (SIGUSR1) - starting configuration reload"
  echo "$timestamp: SIGUSR1 received - starting configuration reload" >>"$RELOAD_LOG_FILE"

  # Update reload state
  echo "status=reloading" >"$RELOAD_STATE_FILE"
  echo "started=$timestamp" >>"$RELOAD_STATE_FILE"
  echo "pid=$$" >>"$RELOAD_STATE_FILE"

  # Perform the reload
  if perform_config_reload; then
    local completed_timestamp
    completed_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "Configuration reload completed successfully"
    echo "$completed_timestamp: Configuration reload completed successfully" >>"$RELOAD_LOG_FILE"

    echo "status=completed" >>"$RELOAD_STATE_FILE"
    echo "completed=$completed_timestamp" >>"$RELOAD_STATE_FILE"
  else
    local failed_timestamp
    failed_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_error "Configuration reload failed"
    echo "$failed_timestamp: Configuration reload failed" >>"$RELOAD_LOG_FILE"

    echo "status=failed" >>"$RELOAD_STATE_FILE"
    echo "failed=$failed_timestamp" >>"$RELOAD_STATE_FILE"
  fi
}

# Handle plugin reload signal (SIGUSR2)
handle_plugin_reload_signal() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  log_info "Received plugin reload signal (SIGUSR2) - starting plugin reload"
  echo "$timestamp: SIGUSR2 received - starting plugin reload" >>"$RELOAD_LOG_FILE"

  # Update reload state
  echo "status=plugin_reloading" >"$RELOAD_STATE_FILE"
  echo "started=$timestamp" >>"$RELOAD_STATE_FILE"
  echo "pid=$$" >>"$RELOAD_STATE_FILE"

  # Perform plugin reload
  if perform_plugin_reload; then
    local completed_timestamp
    completed_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "Plugin reload completed successfully"
    echo "$completed_timestamp: Plugin reload completed successfully" >>"$RELOAD_LOG_FILE"

    echo "status=plugin_completed" >>"$RELOAD_STATE_FILE"
    echo "completed=$completed_timestamp" >>"$RELOAD_STATE_FILE"
  else
    local failed_timestamp
    failed_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_error "Plugin reload failed"
    echo "$failed_timestamp: Plugin reload failed" >>"$RELOAD_LOG_FILE"

    echo "status=plugin_failed" >>"$RELOAD_STATE_FILE"
    echo "failed=$failed_timestamp" >>"$RELOAD_STATE_FILE"
  fi
}

# Handle log rotation signal (SIGHUP)
handle_log_rotation_signal() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  log_info "Received log rotation signal (SIGHUP) - rotating logs"
  echo "$timestamp: SIGHUP received - rotating logs" >>"$RELOAD_LOG_FILE"

  # Perform log rotation
  if declare -f rotate_logs >/dev/null; then
    rotate_logs
    log_info "Log rotation completed"
    echo "$timestamp: Log rotation completed" >>"$RELOAD_LOG_FILE"
  else
    log_warning "Log rotation function not available"
    echo "$timestamp: Log rotation function not available" >>"$RELOAD_LOG_FILE"
  fi
}

# Perform configuration reload
perform_config_reload() {
  log_debug "Performing configuration reload"

  # Backup current configuration state
  local backup_timestamp
  backup_timestamp=$(date +%Y%m%d_%H%M%S)
  local config_backup_dir="${BASE_DIR}/logs/config_backups"

  mkdir -p "$config_backup_dir"

  # Create backup of current config
  if [ -f "$MAIN_CONFIG" ]; then
    cp "$MAIN_CONFIG" "$config_backup_dir/serversentry_${backup_timestamp}.yaml.bak"
    log_debug "Backed up configuration to $config_backup_dir/serversentry_${backup_timestamp}.yaml.bak"
  fi

  # Validate new configuration before applying
  if ! validate_config_file "$MAIN_CONFIG"; then
    log_error "Configuration validation failed - reload aborted"
    return 1
  fi

  # Reload configuration
  if declare -f load_config >/dev/null; then
    if load_config; then
      log_info "Configuration reloaded successfully"
    else
      log_error "Configuration reload failed"
      return 1
    fi
  else
    log_error "Configuration load function not available"
    return 1
  fi

  # Reload notification configurations
  if declare -f reload_notification_configs >/dev/null; then
    reload_notification_configs
  fi

  # Reload composite check configurations
  if [ -f "$BASE_DIR/lib/core/composite.sh" ]; then
    source "$BASE_DIR/lib/core/composite.sh"
    init_composite_system
    log_debug "Reloaded composite check system"
  fi

  # Reload template system
  if [ -f "$BASE_DIR/lib/core/templates.sh" ]; then
    source "$BASE_DIR/lib/core/templates.sh"
    init_template_system
    log_debug "Reloaded template system"
  fi

  log_info "Configuration reload completed"
  return 0
}

# Perform plugin reload
perform_plugin_reload() {
  log_debug "Performing plugin reload"

  # Get list of currently loaded plugins
  local current_plugins=()
  if [ -n "${registered_plugins[*]}" ]; then
    current_plugins=("${registered_plugins[@]}")
  fi

  # Clear current plugin registrations
  registered_plugins=()

  # Reinitialize plugin system
  if declare -f init_plugin_system >/dev/null; then
    if init_plugin_system; then
      log_info "Plugin system reinitialized successfully"
    else
      log_error "Plugin system reinitialization failed"
      return 1
    fi
  else
    log_error "Plugin system initialization function not available"
    return 1
  fi

  # Update plugin health for reloaded plugins
  if [ -f "$BASE_DIR/lib/core/plugin_health.sh" ]; then
    source "$BASE_DIR/lib/core/plugin_health.sh"

    for plugin in "${registered_plugins[@]}"; do
      if [[ " ${current_plugins[*]} " == *" $plugin "* ]]; then
        log_debug "Plugin reloaded: $plugin"
        update_plugin_health "$plugin" "success" "Plugin reloaded successfully"
      else
        log_debug "New plugin loaded: $plugin"
        register_plugin_health "$plugin"
      fi
    done
  fi

  log_info "Plugin reload completed"
  return 0
}

# Validate configuration file
validate_config_file() {
  local config_file="$1"

  if [ ! -f "$config_file" ]; then
    log_error "Configuration file not found: $config_file"
    return 1
  fi

  # Basic YAML syntax validation
  if command -v yq >/dev/null 2>&1; then
    if ! yq eval . "$config_file" >/dev/null 2>&1; then
      log_error "Invalid YAML syntax in configuration file"
      return 1
    fi
  else
    log_warning "yq not available - skipping YAML syntax validation"
  fi

  # Check required configuration keys
  local required_keys=("enabled" "log_level" "check_interval")
  for key in "${required_keys[@]}"; do
    if ! grep -q "^${key}:" "$config_file"; then
      log_error "Required configuration key missing: $key"
      return 1
    fi
  done

  log_debug "Configuration file validation passed"
  return 0
}

# Reload notification configurations
reload_notification_configs() {
  log_debug "Reloading notification configurations"

  # Reload webhook configuration
  if [ -f "$BASE_DIR/lib/notifications/webhook/webhook.sh" ]; then
    source "$BASE_DIR/lib/notifications/webhook/webhook.sh"
    webhook_provider_init
    log_debug "Reloaded webhook provider"
  fi

  # Reload other notification providers
  for provider in teams slack email discord; do
    local provider_file="$BASE_DIR/lib/notifications/$provider/$provider.sh"
    if [ -f "$provider_file" ]; then
      source "$provider_file"
      if declare -f "${provider}_provider_init" >/dev/null; then
        "${provider}_provider_init"
        log_debug "Reloaded $provider provider"
      fi
    fi
  done

  log_debug "Notification configurations reloaded"
}

# Send reload signal to running instance
send_reload_signal() {
  local signal_type="${1:-config}" # config, plugin, or logs
  local pid_file="${BASE_DIR}/serversentry.pid"

  if [ ! -f "$pid_file" ]; then
    echo "❌ ServerSentry is not running (PID file not found)"
    return 1
  fi

  local pid
  pid=$(cat "$pid_file" 2>/dev/null)

  if [ -z "$pid" ] || ! ps -p "$pid" >/dev/null 2>&1; then
    echo "❌ ServerSentry is not running (invalid PID)"
    return 1
  fi

  case "$signal_type" in
  "config")
    echo "Sending configuration reload signal to PID $pid..."
    kill -USR1 "$pid"
    echo "✅ Configuration reload signal sent"
    ;;
  "plugin")
    echo "Sending plugin reload signal to PID $pid..."
    kill -USR2 "$pid"
    echo "✅ Plugin reload signal sent"
    ;;
  "logs")
    echo "Sending log rotation signal to PID $pid..."
    kill -HUP "$pid"
    echo "✅ Log rotation signal sent"
    ;;
  *)
    echo "❌ Unknown signal type: $signal_type"
    echo "Valid types: config, plugin, logs"
    return 1
    ;;
  esac

  # Show reload status after a brief delay
  sleep 2
  show_reload_status
}

# Show reload status
show_reload_status() {
  if [ -f "$RELOAD_STATE_FILE" ]; then
    echo ""
    echo "Reload Status:"
    echo "=============="

    local status started completed failed
    status=$(grep "^status=" "$RELOAD_STATE_FILE" | cut -d'=' -f2)
    started=$(grep "^started=" "$RELOAD_STATE_FILE" | cut -d'=' -f2)
    completed=$(grep "^completed=" "$RELOAD_STATE_FILE" | cut -d'=' -f2)
    failed=$(grep "^failed=" "$RELOAD_STATE_FILE" | cut -d'=' -f2)

    echo "Status: $status"
    [ -n "$started" ] && echo "Started: $started"
    [ -n "$completed" ] && echo "Completed: $completed"
    [ -n "$failed" ] && echo "Failed: $failed"
  else
    echo "No reload status available"
  fi
}

# Get reload history
get_reload_history() {
  local lines="${1:-10}"

  if [ -f "$RELOAD_LOG_FILE" ]; then
    echo "Recent Reload History:"
    echo "====================="
    tail -n "$lines" "$RELOAD_LOG_FILE"
  else
    echo "No reload history available"
  fi
}

# Export functions for use by other modules
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f init_reload_system
  export -f setup_signal_handlers
  export -f handle_reload_signal
  export -f handle_plugin_reload_signal
  export -f handle_log_rotation_signal
  export -f perform_config_reload
  export -f perform_plugin_reload
  export -f validate_config_file
  export -f reload_notification_configs
  export -f send_reload_signal
  export -f show_reload_status
  export -f get_reload_history
fi
