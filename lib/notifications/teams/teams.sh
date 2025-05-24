#!/usr/bin/env bash
#
# ServerSentry v2 - Microsoft Teams Notification Provider
#
# This provider sends notifications to Microsoft Teams via webhook

# Provider metadata
TEAMS_PROVIDER_VERSION="2.0.0"
TEAMS_PROVIDER_AUTHOR="ServerSentry Team"
TEAMS_PROVIDER_DESCRIPTION="Microsoft Teams webhook notifications"

# Configuration variables
teams_webhook_url=""
teams_notification_title="ServerSentry Alert"
teams_enabled=false
teams_timeout=30

# Function: teams_provider_info
# Description: Return provider information
teams_provider_info() {
  echo "Microsoft Teams Notification Provider v${TEAMS_PROVIDER_VERSION} - ${TEAMS_PROVIDER_DESCRIPTION}"
}

# Function: teams_provider_configure
# Description: Configure the Teams provider
# Parameters:
#   $1 - configuration file path (optional)
teams_provider_configure() {
  local config_file="$1"

  # Load configuration from file if provided
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
  fi

  # Load from main config
  teams_webhook_url=$(config_get_value "notifications.teams.webhook_url" "$teams_webhook_url")
  teams_notification_title=$(config_get_value "notifications.teams.notification_title" "$teams_notification_title")
  teams_enabled=$(config_get_value "notifications.teams.enabled" "$teams_enabled")
  teams_timeout=$(config_get_value "notifications.teams.timeout" "$teams_timeout")

  # Validate configuration
  if [[ -z "$teams_webhook_url" || "$teams_webhook_url" == "false" ]]; then
    log_error "Teams webhook URL not configured" "teams"
    return 1
  fi

  log_debug "Teams notification provider configured" "teams"
  return 0
}

# Function: teams_provider_send
# Description: Send notification to Microsoft Teams
# Parameters:
#   $1 - status code (OK/WARNING/CRITICAL/ERROR)
#   $2 - status message
#   $3 - plugin name
#   $4 - details (optional JSON)
teams_provider_send() {
  local status="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="${4:-}"

  # Check if Teams notifications are enabled
  if [[ "$teams_enabled" != "true" ]]; then
    log_debug "Teams notifications are disabled" "teams"
    return 0
  fi

  # Create the basic card content
  local color="#808080" # Default gray
  local activity_title="$teams_notification_title"
  local activity_subtitle="Plugin: $plugin_name"
  local activity_text="$status_message"

  # Set color based on status
  case "$status" in
  "OK")
    color="#00FF00" # Green
    ;;
  "WARNING")
    color="#FFA500" # Orange
    ;;
  "CRITICAL")
    color="#FF0000" # Red
    ;;
  "ERROR")
    color="#800080" # Purple
    ;;
  esac

  # Get hostname and timestamp
  local hostname
  hostname=$(hostname 2>/dev/null || echo "unknown")
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")

  # Build Teams message card JSON
  local teams_payload
  teams_payload=$(
    cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "${color}",
  "summary": "${activity_title}",
  "sections": [{
    "activityTitle": "${activity_title}",
    "activitySubtitle": "${activity_subtitle}",
    "activityImage": "https://github.com/microsoft/vscode-icons/raw/main/icons/file_type_log.svg",
    "facts": [{
      "name": "Status",
      "value": "${status}"
    }, {
      "name": "Server",
      "value": "${hostname}"
    }, {
      "name": "Plugin",
      "value": "${plugin_name}"
    }, {
      "name": "Time",
      "value": "${timestamp}"
    }, {
      "name": "Message",
      "value": "${status_message}"
    }],
    "markdown": true
  }]
EOF
  )

  # Add details if provided and valid JSON
  if [[ -n "$details" ]] && util_command_exists jq && echo "$details" | jq . >/dev/null 2>&1; then
    # Extract metrics from details if it's JSON
    local metrics_facts=""
    while IFS= read -r key; do
      local value
      value=$(echo "$details" | jq -r ".$key" 2>/dev/null)
      if [[ "$value" != "null" && -n "$value" ]]; then
        metrics_facts+=", {\"name\": \"$(echo "$key" | sed 's/^./\U&/' | tr '_' ' ')\", \"value\": \"$value\"}"
      fi
    done < <(echo "$details" | jq -r 'keys[]' 2>/dev/null)

    if [[ -n "$metrics_facts" ]]; then
      # Add metrics to facts array
      teams_payload="${teams_payload}${metrics_facts}"
    fi
  fi

  # Close the JSON structure
  teams_payload="${teams_payload}]}]}"

  # Send to Teams webhook
  log_debug "Sending notification to Teams webhook" "teams"

  if ! util_command_exists curl; then
    log_error "Cannot send Teams notification: 'curl' command not found" "teams"
    return 1
  fi

  local response
  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$teams_payload" \
    --max-time "$teams_timeout" \
    "$teams_webhook_url" 2>&1)

  local curl_exit_code=$?

  if [[ $curl_exit_code -ne 0 ]]; then
    log_error "Failed to send Teams notification: $response" "teams"
    return 1
  fi

  # Check Teams API response
  if [[ "$response" != "1" && -n "$response" ]]; then
    log_error "Teams API error: $response" "teams"
    return 1
  fi

  log_debug "Teams notification sent successfully" "teams"
  return 0
}

# Function: teams_provider_test
# Description: Test Teams notification functionality
teams_provider_test() {
  log_info "Testing Teams notification..." "teams"

  # Send test notification
  if teams_provider_send "INFO" "Test notification from ServerSentry" "test" '{"test_metric": "42", "test_status": "success"}'; then
    echo "✓ Teams notification test successful"
    return 0
  else
    echo "✗ Teams notification test failed"
    return 1
  fi
}

# Function: teams_provider_validate
# Description: Validate Teams provider configuration
teams_provider_validate() {
  local errors=0

  echo "Teams Provider Validation:"

  # Check if curl is available
  if util_command_exists curl; then
    echo "✓ curl command available"
  else
    echo "✗ curl command not found"
    ((errors++))
  fi

  # Check webhook URL
  if [[ -n "$teams_webhook_url" && "$teams_webhook_url" != "false" ]]; then
    echo "✓ Webhook URL configured"

    # Validate URL format
    if [[ "$teams_webhook_url" =~ ^https://.*\.webhook\.office\.com/.* ]]; then
      echo "✓ Webhook URL format is valid"
    else
      echo "⚠ Webhook URL format may be invalid (should be a Microsoft Teams webhook URL)"
    fi
  else
    echo "✗ Webhook URL not configured"
    ((errors++))
  fi

  # Check if enabled
  if [[ "$teams_enabled" == "true" ]]; then
    echo "✓ Teams notifications enabled"
  else
    echo "⚠ Teams notifications disabled"
  fi

  # Check timeout setting
  if [[ "$teams_timeout" =~ ^[0-9]+$ ]] && [[ "$teams_timeout" -gt 0 ]]; then
    echo "✓ Timeout setting valid: ${teams_timeout}s"
  else
    echo "⚠ Invalid timeout setting: $teams_timeout"
  fi

  if [[ $errors -eq 0 ]]; then
    echo "✓ Teams provider configuration is valid"
    return 0
  else
    echo "✗ Teams provider configuration has $errors error(s)"
    return 1
  fi
}

# Function: teams_provider_status
# Description: Get provider status information
teams_provider_status() {
  echo "Teams Provider Status:"
  echo "  Version: $TEAMS_PROVIDER_VERSION"
  echo "  Enabled: $teams_enabled"
  echo "  Webhook configured: $(if [[ -n "$teams_webhook_url" && "$teams_webhook_url" != "false" ]]; then echo "yes"; else echo "no"; fi)"
  echo "  Timeout: ${teams_timeout}s"
  echo "  curl available: $(if util_command_exists curl; then echo "yes"; else echo "no"; fi)"
  echo "  jq available: $(if util_command_exists jq; then echo "yes (enhanced formatting)"; else echo "no (basic formatting)"; fi)"
}

# Export functions for use by notification system
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f teams_provider_info
  export -f teams_provider_configure
  export -f teams_provider_send
  export -f teams_provider_test
  export -f teams_provider_validate
  export -f teams_provider_status
fi
