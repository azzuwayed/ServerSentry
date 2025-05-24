#!/bin/bash
#
# ServerSentry - Webhook commands
# Manages and tests webhook notifications

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the paths module
source "$SCRIPT_DIR/../utils/paths.sh"

# Get standardized paths
PROJECT_ROOT="$(get_project_root)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/config/config_manager.sh"
source "$PROJECT_ROOT/lib/monitor/monitor.sh"
source "$PROJECT_ROOT/lib/notify/main.sh"

# Test all configured webhooks
cli_test_webhook() {
  log_message "INFO" "Testing webhook notifications"

  # Load webhooks using the config manager
  local webhooks=()
  while IFS= read -r webhook; do
    if [ -n "$webhook" ]; then
      webhooks+=("$webhook")
    fi
  done < <(manage_webhooks "get_all")

  if [ ${#webhooks[@]} -eq 0 ]; then
    echo "Error: No webhooks configured. Add one with --add-webhook"
    return 1
  fi

  # Get current system stats for a more useful test
  local cpu_usage=$(get_cpu_usage)
  local memory_usage=$(get_memory_usage)
  local disk_usage=$(get_disk_usage)

  # Create comprehensive test message with color formatting
  local test_message="ServerSentry test notification with current status overview:

System Resources:
CPU Usage: ${cpu_usage}% 
Memory Usage: ${memory_usage}%
Disk Usage: ${disk_usage}%

This is a test alert to verify proper webhook configuration and Teams integration. The notification includes comprehensive system information and is formatted for optimal display in Microsoft Teams.

For more information on configuring Teams with ServerSentry, see the TEAMS_SETUP.md guide."

  # Show what we're sending
  echo "Sending test alert to all configured webhooks..."
  echo "Current system stats:"
  echo "- CPU: ${cpu_usage}%"
  echo "- Memory: ${memory_usage}%"
  echo "- Disk: ${disk_usage}%"

  # Test each webhook
  local i=0
  for webhook in "${webhooks[@]}"; do
    echo "Testing webhook #$i: ${webhook}"
    echo "Sending detailed system information and adaptive card..."
    send_webhook_notification "${webhook}" "ServerSentry System Test" "$test_message"
    ((i++))

    # Brief delay to avoid throttling
    sleep 1
  done

  echo "Test complete. Please check your notification channels."
  echo "If using Microsoft Teams, you should see an adaptive card with detailed system information."

  return 0
}

# Add a new webhook
cli_add_webhook() {
  local url="$1"

  if [ -z "$url" ]; then
    echo "Error: Webhook URL is required"
    echo "Usage: $0 --add-webhook URL"
    return 1
  fi

  # Use the config manager to add webhook
  if manage_webhooks "add" "$url"; then
    echo "Webhook added successfully"
    return 0
  else
    echo "Failed to add webhook"
    return 1
  fi
}

# Remove a webhook by index
cli_remove_webhook() {
  local index="$1"

  if [ -z "$index" ]; then
    echo "Error: Webhook index is required"
    echo "Usage: $0 --remove-webhook INDEX"
    return 1
  fi

  # Use the config manager to remove webhook
  if manage_webhooks "remove" "$index"; then
    echo "Webhook removed successfully"
    return 0
  else
    echo "Failed to remove webhook"
    return 1
  fi
}
