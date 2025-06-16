#!/usr/bin/env bash
#
# ServerSentry v2 - Notification Management
#
# This module handles loading notification providers and sending notifications

# Prevent multiple sourcing
if [[ "${NOTIFICATION_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
NOTIFICATION_MODULE_LOADED=true
export NOTIFICATION_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# Notification system configuration using bootstrap paths
NOTIFICATION_DIR="${NOTIFICATION_DIR:-${SERVERSENTRY_NOTIFICATIONS_DIR}}"
NOTIFICATION_CONFIG_DIR="${NOTIFICATION_CONFIG_DIR:-${SERVERSENTRY_CONFIG_DIR}/notifications}"

# Array to store registered notification providers
declare -a registered_providers

# Fallback logging functions if not available
if ! declare -f log_debug >/dev/null 2>&1; then
  log_debug() { echo "[DEBUG] [notifications] $1" >&2; }
  log_info() { echo "[INFO] [notifications] $1" >&2; }
  log_warning() { echo "[WARNING] [notifications] $1" >&2; }
  log_error() { echo "[ERROR] [notifications] $1" >&2; }
fi

# Initialize notification system with enhanced error handling
# Returns:
#   0 - success
#   1 - failure
notification_system_init() {
  log_debug "Initializing notification system" "notifications"

  # Make sure notification directories exist
  if [ ! -d "$NOTIFICATION_DIR" ]; then
    log_warning "Notification directory not found: $NOTIFICATION_DIR" "notifications"
    log_info "Creating notification directory" "notifications"
    mkdir -p "$NOTIFICATION_DIR" || return 1
  fi

  if [ ! -d "$NOTIFICATION_CONFIG_DIR" ]; then
    log_warning "Notification config directory not found: $NOTIFICATION_CONFIG_DIR" "notifications"
    log_info "Creating notification config directory" "notifications"
    mkdir -p "$NOTIFICATION_CONFIG_DIR" || return 1
  fi

  # Clear registered providers
  registered_providers=()

  # Check if notifications are enabled
  local notifications_enabled
  notifications_enabled=$(util_config_get_value "notifications.enabled" "false")

  if [[ "$notifications_enabled" != "true" ]]; then
    log_debug "Notifications are disabled in configuration" "notifications"
    return 0
  fi

  # Load enabled notification channels from configuration
  local notification_channels
  notification_channels=$(util_config_get_value "notification_channels" "")

  # Convert comma/space/brackets separated string to array
  local channel_list
  channel_list=$(echo "$notification_channels" | tr -d '[]' | tr ',' ' ')

  if [ -z "$channel_list" ]; then
    log_warning "No notification channels configured" "notifications"
    return 0
  fi

  log_info "Loading notification providers: $channel_list" "notifications"

  # Load each provider
  for provider_name in $channel_list; do
    log_debug "Loading notification provider: $provider_name" "notifications"
    load_notification_provider "$provider_name" || log_error "Failed to load notification provider: $provider_name" "notifications"
  done

  log_info "Loaded ${#registered_providers[@]} notification providers" "notifications"

  return 0
}

# Load a notification provider
load_notification_provider() {
  local provider_name="$1"
  local provider_path="${NOTIFICATION_DIR}/${provider_name}/${provider_name}.sh"
  local provider_config="${NOTIFICATION_CONFIG_DIR}/${provider_name}.conf"

  # Check if provider exists
  if [ ! -f "$provider_path" ]; then
    log_error "Notification provider not found: $provider_path" "notifications"
    return 1
  fi

  # Source the provider file
  log_debug "Sourcing notification provider: $provider_path" "notifications"
  source "$provider_path" || return 1

  # Register the provider
  register_notification_provider "$provider_name" || return 1

  # Configure the provider
  "${provider_name}"_provider_configure "$provider_config" || {
    log_error "Failed to configure notification provider: $provider_name" "notifications"
    return 1
  }

  log_info "Notification provider loaded successfully: $provider_name" "notifications"
  return 0
}

# Validate notification provider interface
validate_notification_provider() {
  local provider_name="$1"
  local required_functions=("provider_info" "provider_configure" "provider_send")

  for func in "${required_functions[@]}"; do
    if ! declare -f "${provider_name}_${func}" >/dev/null; then
      log_error "Notification provider $provider_name does not implement required function: $func" "notifications"
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
  provider_info=$("${provider_name}"_provider_info)

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
  notification_enabled=$(util_config_get_value "notification_enabled" "false")

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

    if ! "${provider_name}"_provider_send "$status_code" "$status_message" "$plugin_name" "$details"; then
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

# Export functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f notification_system_init
  export -f load_notification_provider
  export -f validate_notification_provider
  export -f register_notification_provider
  export -f send_notification
fi
