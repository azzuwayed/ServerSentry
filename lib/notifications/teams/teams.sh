#!/bin/bash
#
# ServerSentry v2 - Microsoft Teams Notification Provider
#
# This module sends notifications to Microsoft Teams webhooks

# Provider metadata
teams_provider_name="teams"
teams_provider_version="1.0"
teams_provider_description="Sends notifications to Microsoft Teams"
teams_provider_author="ServerSentry Team"

# Default configuration
teams_webhook_url=""
teams_notification_title="ServerSentry Alert"

# Return provider information
teams_provider_info() {
  echo "Microsoft Teams Notification Provider v${teams_provider_version}"
}

# Configure the provider
teams_provider_configure() {
  local config_file="$1"

  # Load global configuration first
  teams_webhook_url=$(get_config "teams_webhook_url" "")
  teams_notification_title=$(get_config "teams_notification_title" "ServerSentry Alert")

  # Load provider-specific configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$teams_webhook_url" ]; then
    log_error "Teams webhook URL not configured"
    return 1
  fi

  log_debug "Teams notification provider configured"

  return 0
}

# Generate Adaptive Card JSON for Teams
teams_generate_adaptive_card() {
  local title="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details_json="$4"
  local status_code="$5"

  # Extract metrics from details_json if possible
  local cpu_usage memory_usage disk_usage
  if command -v jq >/dev/null 2>&1 && [ -n "$details_json" ]; then
    cpu_usage=$(echo "$details_json" | jq -r '.usage_percent // empty')
    memory_usage=$(echo "$details_json" | jq -r '.memory_percent // empty')
    disk_usage=$(echo "$details_json" | jq -r '.disk_percent // empty')
  fi

  # Fallbacks
  cpu_usage=${cpu_usage:-"N/A"}
  memory_usage=${memory_usage:-"N/A"}
  disk_usage=${disk_usage:-"N/A"}

  # Choose color
  local color
  case "$status_code" in
  0) color="good" ;;
  1) color="warning" ;;
  2) color="attention" ;;
  *) color="accent" ;;
  esac

  # Get hostname and timestamp
  local hostname=$(hostname)
  local timestamp=$(get_formatted_date)

  # Compose Adaptive Card JSON
  cat <<EOF
{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "text": "$title",
      "weight": "Bolder",
      "size": "Large",
      "color": "$color"
    },
    {
      "type": "TextBlock",
      "text": "$status_message",
      "wrap": true
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Host", "value": "$hostname" },
        { "title": "Plugin", "value": "$plugin_name" },
        { "title": "CPU Usage", "value": "$cpu_usage%" },
        { "title": "Memory Usage", "value": "$memory_usage%" },
        { "title": "Disk Usage", "value": "$disk_usage%" },
        { "title": "Time", "value": "$timestamp" }
      ]
    }
  ],
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.2"
}
EOF
}

# Send notification
teams_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="$4"

  # Get the hostname
  local hostname
  hostname=$(hostname)

  # Format timestamp
  local timestamp
  timestamp=$(get_formatted_date)

  # Determine status text
  local status_text
  case "$status_code" in
  0) status_text="OK" ;;
  1) status_text="WARNING" ;;
  2) status_text="CRITICAL" ;;
  *) status_text="UNKNOWN" ;;
  esac

  # Use Adaptive Card if details are present and jq is available
  local payload
  if [ -n "$details" ] && command -v jq >/dev/null 2>&1 && echo "$details" | jq . >/dev/null 2>&1; then
    payload=$(teams_generate_adaptive_card "$teams_notification_title" "$status_message" "$plugin_name" "$details" "$status_code")
  else
    # Fallback to MessageCard
    local color
    case "$status_code" in
    0) color="#00cc00" ;;
    1) color="#ffcc00" ;;
    2) color="#cc0000" ;;
    *) color="#808080" ;;
    esac
    payload=$(
      cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "${color}",
  "summary": "${teams_notification_title} - ${status_text}",
  "sections": [
    {
      "activityTitle": "${teams_notification_title}",
      "activitySubtitle": "Status: ${status_text}",
      "facts": [
        { "name": "Host", "value": "${hostname}" },
        { "name": "Plugin", "value": "${plugin_name}" },
        { "name": "Status", "value": "${status_message}" },
        { "name": "Time", "value": "${timestamp}" }
      ],
      "markdown": true
    }
  ]
}
EOF
    )
  fi

  # Send to Teams
  log_debug "Sending notification to Teams webhook"

  # Check if curl is installed
  if ! command_exists curl; then
    log_error "Cannot send Teams notification: 'curl' command not found"
    return 1
  fi

  # Send using curl
  local response
  response=$(curl -s -H "Content-Type: application/json" -d "$payload" "$teams_webhook_url" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send Teams notification: $response"
    return 1
  fi

  log_debug "Teams notification sent successfully"
  return 0
}
