#!/bin/bash
#
# ServerSentry v2 - Slack Notification Provider
#
# This module sends notifications to Slack webhooks

# Provider metadata
slack_provider_name="slack"
slack_provider_version="1.0"
slack_provider_description="Sends notifications to Slack"
slack_provider_author="ServerSentry Team"

# Default configuration
slack_webhook_url=""
slack_notification_title="ServerSentry Alert"
slack_username="ServerSentry"
slack_icon_emoji=":robot_face:"
slack_icon_url=""

# Return provider information
slack_provider_info() {
  echo "Slack Notification Provider v${slack_provider_version}"
}

# Configure the provider
slack_provider_configure() {
  local config_file="$1"

  # Load global configuration first
  slack_webhook_url=$(get_config "slack_webhook_url" "")
  slack_notification_title=$(get_config "slack_notification_title" "ServerSentry Alert")
  slack_username=$(get_config "slack_username" "ServerSentry")
  slack_icon_emoji=$(get_config "slack_icon_emoji" ":robot_face:")
  slack_icon_url=$(get_config "slack_icon_url" "")

  # Load provider-specific configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$slack_webhook_url" ]; then
    log_error "Slack webhook URL not configured"
    return 1
  fi

  log_debug "Slack notification provider configured"

  return 0
}

# Send notification
slack_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="$4"

  # Determine color based on status code
  local color
  case "$status_code" in
  0) color="good" ;;    # OK - Green
  1) color="warning" ;; # Warning - Yellow
  2) color="danger" ;;  # Critical - Red
  *) color="#808080" ;; # Unknown - Gray
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

  # Create JSON payload for Slack
  local payload
  payload=$(
    cat <<EOF
{
  "username": "${slack_username}",
  "icon_emoji": "${slack_icon_emoji}",
  "text": "${slack_notification_title}",
  "attachments": [
    {
      "color": "${color}",
      "title": "${status_text}: ${plugin_name}",
      "text": "${status_message}",
      "fields": [
        {
          "title": "Host",
          "value": "${hostname}",
          "short": true
        },
        {
          "title": "Status",
          "value": "${status_text}",
          "short": true
        },
        {
          "title": "Time",
          "value": "${timestamp}",
          "short": true
        }
      ],
      "footer": "ServerSentry v2",
      "ts": $(date +%s)
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

        # Add comma separator if not first item
        if [ -n "$fields_json" ]; then
          fields_json+=","
        fi

        # Add field
        fields_json+=$(
          cat <<EOF
{
  "title": "${key}",
  "value": "${value}",
  "short": true
}
EOF
        )
      done < <(echo "$metrics_json" | jq -r 'to_entries | .[] | .key + "=" + (.value | tostring)')

      # Update payload with fields if we have any
      if [ -n "$fields_json" ]; then
        payload=$(echo "$payload" | jq --argjson fields "[$fields_json]" '.attachments[0].fields = $fields')
      fi
    else
      # Just add details as text
      payload=$(echo "$payload" | jq --arg details "$details" '.attachments[0].text += "\n\n" + $details')
    fi
  fi

  # Send to Slack
  log_debug "Sending notification to Slack webhook"

  # Check if curl is installed
  if ! command_exists curl; then
    log_error "Cannot send Slack notification: 'curl' command not found"
    return 1
  fi

  # Send using curl
  local response
  response=$(curl -s -H "Content-Type: application/json" -d "$payload" "$slack_webhook_url" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send Slack notification: $response"
    return 1
  fi

  # Check for "ok" response from Slack
  if [ "$response" != "ok" ]; then
    log_error "Slack API error: $response"
    return 1
  fi

  log_debug "Slack notification sent successfully"
  return 0
}
