#!/bin/bash
#
# ServerSentry v2 - Discord Notification Provider
#
# This module sends notifications to Discord webhooks

# Provider metadata
discord_provider_name="discord"
discord_provider_version="1.0"
discord_provider_description="Sends notifications to Discord"
discord_provider_author="ServerSentry Team"

# Default configuration
discord_webhook_url=""
discord_notification_title="ServerSentry Alert"
discord_username="ServerSentry"
discord_avatar_url=""

# Return provider information
discord_provider_info() {
  echo "Discord Notification Provider v${discord_provider_version}"
}

# Configure the provider
discord_provider_configure() {
  local config_file="$1"

  # Load global configuration first
  discord_webhook_url=$(get_config "discord_webhook_url" "")
  discord_notification_title=$(get_config "discord_notification_title" "ServerSentry Alert")
  discord_username=$(get_config "discord_username" "ServerSentry")
  discord_avatar_url=$(get_config "discord_avatar_url" "")

  # Load provider-specific configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$discord_webhook_url" ]; then
    log_error "Discord webhook URL not configured"
    return 1
  fi

  log_debug "Discord notification provider configured"

  return 0
}

# Send notification
discord_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="$4"

  # Determine color based on status code
  local color
  case "$status_code" in
  0) color="65280" ;;    # OK - Green (decimal value for 0x00FF00)
  1) color="16776960" ;; # Warning - Yellow (decimal value for 0xFFFF00)
  2) color="16711680" ;; # Critical - Red (decimal value for 0xFF0000)
  *) color="8421504" ;;  # Unknown - Gray (decimal value for 0x808080)
  esac

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

  # Create JSON payload for Discord
  local payload
  payload=$(
    cat <<EOF
{
  "username": "${discord_username}",
  "avatar_url": "${discord_avatar_url}",
  "content": "${discord_notification_title}",
  "embeds": [
    {
      "title": "${status_text}: ${plugin_name}",
      "description": "${status_message}",
      "color": ${color},
      "fields": [
        {
          "name": "Host",
          "value": "${hostname}",
          "inline": true
        },
        {
          "name": "Status",
          "value": "${status_text}",
          "inline": true
        },
        {
          "name": "Time",
          "value": "${timestamp}",
          "inline": true
        }
      ],
      "footer": {
        "text": "ServerSentry v2"
      },
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  ]
}
EOF
  )

  # Check if details are provided and add them to the payload
  if [ -n "$details" ] && command_exists jq; then
    # Try to parse details as JSON
    if echo "$details" | jq -e . >/dev/null 2>&1; then
      # Extract metrics
      local metrics_json
      metrics_json=$(echo "$details" | jq -c '.metrics // {}')

      # Create fields for metrics
      local fields_json=""
      while IFS="=" read -r key value; do
        [ -z "$key" ] && continue

        # Add field
        fields_json+=$(
          cat <<EOF
,{
  "name": "${key}",
  "value": "${value}",
  "inline": true
}
EOF
        )
      done < <(echo "$metrics_json" | jq -r 'to_entries | .[] | .key + "=" + (.value | tostring)')

      # Update payload with fields if we have any
      if [ -n "$fields_json" ]; then
        payload=$(echo "$payload" | jq --argjson fields "[$(echo "$payload" | jq -r '.embeds[0].fields[]')${fields_json}]" '.embeds[0].fields = $fields')
      fi
    else
      # Just add details as description
      payload=$(echo "$payload" | jq --arg details "$details" '.embeds[0].description += "\n\n" + $details')
    fi
  fi

  # Send to Discord
  log_debug "Sending notification to Discord webhook"

  # Check if curl is installed
  if ! command_exists curl; then
    log_error "Cannot send Discord notification: 'curl' command not found"
    return 1
  fi

  # Send using curl
  local response
  response=$(curl -s -H "Content-Type: application/json" -d "$payload" "$discord_webhook_url" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send Discord notification: $response"
    return 1
  fi

  # Discord returns 204 No Content on success, which curl shows as empty response
  if [ -n "$response" ] && echo "$response" | grep -q "error"; then
    log_error "Discord API error: $response"
    return 1
  fi

  log_debug "Discord notification sent successfully"
  return 0
}
