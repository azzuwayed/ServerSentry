#!/bin/bash
#
# ServerSentry v2 - Plugin Management
#
# This module handles plugin loading, validation, and execution

# Plugin system configuration
PLUGIN_DIR="${BASE_DIR}/lib/plugins"
PLUGIN_CONFIG_DIR="${BASE_DIR}/config/plugins"
PLUGIN_INTERFACE_VERSION="1.0"

# Array to store registered plugins
declare -a registered_plugins

# Initialize plugin system
init_plugin_system() {
  log_debug "Initializing plugin system"

  # Make sure plugin directories exist
  if [ ! -d "$PLUGIN_DIR" ]; then
    log_warning "Plugin directory not found: $PLUGIN_DIR"
    log_info "Creating plugin directory"
    mkdir -p "$PLUGIN_DIR" || return 1
  fi

  if [ ! -d "$PLUGIN_CONFIG_DIR" ]; then
    log_warning "Plugin config directory not found: $PLUGIN_CONFIG_DIR"
    log_info "Creating plugin config directory"
    mkdir -p "$PLUGIN_CONFIG_DIR" || return 1
  fi

  # Clear registered plugins
  registered_plugins=()

  # Load enabled plugins from configuration
  local enabled_plugins
  enabled_plugins=$(get_config "plugins_enabled" "cpu")

  # Convert comma/space/brackets separated string to array
  local plugin_list
  plugin_list=$(echo "$enabled_plugins" | tr -d '[]' | tr ',' ' ')

  log_info "Loading plugins: $plugin_list"

  # Load each plugin
  for plugin_name in $plugin_list; do
    log_debug "Loading plugin: $plugin_name"
    load_plugin "$plugin_name" || log_error "Failed to load plugin: $plugin_name"
  done

  log_info "Loaded ${#registered_plugins[@]} plugins"

  return 0
}

# Load a plugin
load_plugin() {
  local plugin_name="$1"
  local plugin_path="${PLUGIN_DIR}/${plugin_name}/${plugin_name}.sh"
  local plugin_config="${PLUGIN_CONFIG_DIR}/${plugin_name}.conf"

  # Check if plugin exists
  if [ ! -f "$plugin_path" ]; then
    log_error "Plugin not found: $plugin_path"
    return 1
  fi

  # Source the plugin file
  log_debug "Sourcing plugin: $plugin_path"
  source "$plugin_path" || return 1

  # Register the plugin
  register_plugin "$plugin_name" || return 1

  # Configure the plugin
  if [ -f "$plugin_config" ]; then
    log_debug "Configuring plugin from: $plugin_config"
    "${plugin_name}"_plugin_configure "$plugin_config" || {
      log_error "Failed to configure plugin: $plugin_name"
      return 1
    }
  else
    log_warning "No configuration found for plugin: $plugin_name"
    # Use default configuration
    "${plugin_name}"_plugin_configure "" || {
      log_error "Failed to configure plugin with defaults: $plugin_name"
      return 1
    }
  fi

  log_info "Plugin loaded successfully: $plugin_name"
  return 0
}

# Validate plugin interface
validate_plugin() {
  local plugin_name="$1"
  local required_functions=("plugin_info" "plugin_check" "plugin_configure")

  for func in "${required_functions[@]}"; do
    if ! declare -f "${plugin_name}_${func}" >/dev/null; then
      log_error "Plugin $plugin_name does not implement required function: $func"
      return 1
    fi
  done

  return 0
}

# Register a plugin with the system
register_plugin() {
  local plugin_name="$1"

  # Validate plugin interface
  validate_plugin "$plugin_name" || return 1

  # Get plugin info
  local plugin_info
  plugin_info=$("${plugin_name}"_plugin_info)

  # Add to registered plugins
  registered_plugins+=("$plugin_name")

  log_info "Plugin registered: $plugin_name - $plugin_info"
  return 0
}

# Run a plugin check
run_plugin_check() {
  local plugin_name="$1"
  local send_notifications="${2:-true}"

  # Check if plugin is registered
  if ! is_plugin_registered "$plugin_name"; then
    log_error "Plugin not registered: $plugin_name"
    return 1
  fi

  # Run the plugin check
  log_debug "Running check for plugin: $plugin_name"
  local result
  result=$("${plugin_name}"_plugin_check)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Plugin check failed: $plugin_name (exit code: $exit_code)"
    return $exit_code
  fi

  # Process result for notifications if needed
  if [ "$send_notifications" = "true" ] && command_exists jq; then
    # Extract status code and message from the JSON result
    local status_code
    status_code=$(echo "$result" | jq -r '.status_code')

    local status_message
    status_message=$(echo "$result" | jq -r '.status_message')

    # Get metrics JSON for notification details
    local metrics
    metrics=$(echo "$result" | jq -c '.metrics')

    # Only send notifications for non-OK statuses (status code > 0)
    if [ "$status_code" -gt 0 ]; then
      # Check if notifications module is available (it should be loaded by main script)
      if declare -f send_notification >/dev/null; then
        log_debug "Sending notification for $plugin_name: $status_message"
        send_notification "$status_code" "$status_message" "$plugin_name" "$metrics"
      fi
    fi
  fi

  # Process and return the result
  echo "$result"
  return 0
}

# Check if a plugin is registered
is_plugin_registered() {
  local plugin_name="$1"

  for registered_plugin in "${registered_plugins[@]}"; do
    if [ "$registered_plugin" = "$plugin_name" ]; then
      return 0
    fi
  done

  return 1
}

# List all registered plugins
list_plugins() {
  log_debug "Listing registered plugins"

  for plugin_name in "${registered_plugins[@]}"; do
    local plugin_info
    plugin_info=$("${plugin_name}"_plugin_info)
    echo "$plugin_name: $plugin_info"
  done
}

# Run all plugin checks
run_all_plugin_checks() {
  log_debug "Running all plugin checks"

  local results=()
  local failed=0

  for plugin_name in "${registered_plugins[@]}"; do
    local result
    result=$(run_plugin_check "$plugin_name" "true")
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
      failed=$((failed + 1))
    fi

    results+=("$result")
  done

  # Return the combined results
  for result in "${results[@]}"; do
    echo "$result"
  done

  if [ $failed -gt 0 ]; then
    log_warning "$failed plugin checks failed"
    return 1
  fi

  return 0
}
