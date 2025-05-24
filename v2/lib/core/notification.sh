#!/bin/bash
#
# ServerSentry v2 - Notification Management
#
# This module handles loading notification providers and sending notifications

# Notification system configuration
NOTIFICATION_DIR="${BASE_DIR}/lib/notifications"
NOTIFICATION_CONFIG_DIR="${BASE_DIR}/config/notifications"

# Array to store registered notification providers
declare -a registered_providers

# Initialize notification system
init_notification_system() {
  log_debug "Initializing notification system"

  # Make sure notification directories exist
  if [ ! -d "$NOTIFICATION_DIR" ]; then
    log_warning "Notification directory not found: $NOTIFICATION_DIR"
    log_info "Creating notification directory"
    mkdir -p "$NOTIFICATION_DIR" || return 1
  fi

  if [ ! -d "$NOTIFICATION_CONFIG_DIR" ]; then
    log_warning "Notification config directory not found: $NOTIFICATION_CONFIG_DIR"
    log_info "Creating notification config directory"
    mkdir -p "$NOTIFICATION_CONFIG_DIR" || return 1
  fi

  # Clear registered providers
  registered_providers=()

  # Check if notifications are enabled
  local notification_enabled
  notification_enabled=$(get_config "notification_enabled" "true")

  if [ "$notification_enabled" != "true" ]; then
    log_info "Notifications are disabled in configuration"
    return 0
  fi

  # Load enabled notification channels from configuration
  local notification_channels
  notification_channels=$(get_config "notification_channels" "")

  # Convert comma/space/brackets separated string to array
  local channel_list
  channel_list=$(echo "$notification_channels" | tr -d '[]' | tr ',' ' ')

  if [ -z "$channel_list" ]; then
    log_warning "No notification channels configured"
    return 0
  fi

  log_info "Loading notification providers: $channel_list"

  # Load each provider
  for provider_name in $channel_list; do
    log_debug "Loading notification provider: $provider_name"
    load_notification_provider "$provider_name" || log_error "Failed to load notification provider: $provider_name"
  done

  log_info "Loaded ${#registered_providers[@]} notification providers"

  return 0
}

# Load a notification provider
load_notification_provider() {
  local provider_name="$1"
  local provider_path="${NOTIFICATION_DIR}/${provider_name}/${provider_name}.sh"
  local provider_config="${NOTIFICATION_CONFIG_DIR}/${provider_name}.conf"

  # Check if provider exists
  if [ ! -f "$provider_path" ]; then
    log_error "Notification provider not found: $provider_path"
    return 1
  fi

  # Source the provider file
  log_debug "Sourcing notification provider: $provider_path"
  source "$provider_path" || return 1

  # Register the provider
  register_notification_provider "$provider_name" || return 1

  # Configure the provider
  ${provider_name}_provider_configure "$provider_config" || {
    log_error "Failed to configure notification provider: $provider_name"
    return 1
  }

  log_info "Notification provider loaded successfully: $provider_name"
  return 0
}

# Validate notification provider interface
validate_notification_provider() {
  local provider_name="$1"
  local required_functions=("provider_info" "provider_configure" "provider_send")

  for func in "${required_functions[@]}"; do
    if ! declare -f "${provider_name}_${func}" >/dev/null; then
      log_error "Notification provider $provider_name does not implement required function: $func"
      return 1
    fi
  done

  return 0
}

# Register a notification provider
register_notification_provider() {
  local provider_name="$1"

  # Validate provider interface
  validate_notification_provider "$provider_name" || return 1

  # Get provider info
  local provider_info
  provider_info=$(${provider_name}_provider_info)

  # Add to registered providers
  registered_providers+=("$provider_name")

  log_info "Notification provider registered: $provider_name - $provider_info"
  return 0
}

# Send notification to all registered providers
send_notification() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="${4:-}"

  # Check if notifications are enabled
  local notification_enabled
  notification_enabled=$(get_config "notification_enabled" "true")

  if [ "$notification_enabled" != "true" ]; then
    log_debug "Notifications are disabled, skipping"
    return 0
  fi

  # Check if we have any registered providers
  if [ ${#registered_providers[@]} -eq 0 ]; then
    log_warning "No notification providers registered, notification not sent"
    return 0
  fi

  log_debug "Sending notification to ${#registered_providers[@]} providers"

  # Send to each provider
  local failed=0
  for provider_name in "${registered_providers[@]}"; do
    log_debug "Sending notification via $provider_name"

    if ! ${provider_name}_provider_send "$status_code" "$status_message" "$plugin_name" "$details"; then
      log_error "Failed to send notification via $provider_name"
      failed=$((failed + 1))
    fi
  done

  if [ $failed -gt 0 ]; then
    log_warning "Failed to send notification to $failed providers"
    return 1
  fi

  log_debug "Notification sent successfully to all providers"
  return 0
}
