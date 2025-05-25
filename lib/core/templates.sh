#!/usr/bin/env bash
#
# ServerSentry v2 - Notification Template System
#
# This module provides template processing for notifications with variable substitution

# Template configuration
TEMPLATE_DIR="${BASE_DIR}/config/templates"
DEFAULT_TEMPLATE_DIR="${BASE_DIR}/lib/notifications/templates"

# Initialize template system
init_template_system() {
  log_debug "Initializing template system"

  # Create template directories if they don't exist
  if [ ! -d "$TEMPLATE_DIR" ]; then
    mkdir -p "$TEMPLATE_DIR"
    log_debug "Created template directory: $TEMPLATE_DIR"
  fi

  if [ ! -d "$DEFAULT_TEMPLATE_DIR" ]; then
    mkdir -p "$DEFAULT_TEMPLATE_DIR"
    log_debug "Created default template directory: $DEFAULT_TEMPLATE_DIR"
  fi

  # Create default templates if they don't exist
  create_default_templates

  return 0
}

# Create default notification templates
create_default_templates() {
  # Default alert template
  local alert_template="$DEFAULT_TEMPLATE_DIR/alert.template"
  if [ ! -f "$alert_template" ]; then
    cat >"$alert_template" <<'EOF'
🚨 **{status_text}** Alert on {hostname}

**Message:** {status_message}
**Plugin:** {plugin_name}
**Time:** {timestamp}
**Status Code:** {status_code}

{metrics}

---
*ServerSentry v2 Monitoring System*
EOF
    log_debug "Created default alert template"
  fi

  # Default info template
  local info_template="$DEFAULT_TEMPLATE_DIR/info.template"
  if [ ! -f "$info_template" ]; then
    cat >"$info_template" <<'EOF'
ℹ️ **{status_text}** Information from {hostname}

**Message:** {status_message}
**Plugin:** {plugin_name}
**Time:** {timestamp}

{metrics}

---
*ServerSentry v2 Monitoring System*
EOF
    log_debug "Created default info template"
  fi

  # Default test template
  local test_template="$DEFAULT_TEMPLATE_DIR/test.template"
  if [ ! -f "$test_template" ]; then
    cat >"$test_template" <<'EOF'
🧪 **Test Notification** from {hostname}

This is a test notification to verify your ServerSentry configuration.

**Time:** {timestamp}
**Plugin:** {plugin_name}

{metrics}

If you received this message, your notification system is working correctly!

---
*ServerSentry v2 Monitoring System*
EOF
    log_debug "Created default test template"
  fi

  # Default JSON template for APIs
  local json_template="$DEFAULT_TEMPLATE_DIR/json.template"
  if [ ! -f "$json_template" ]; then
    cat >"$json_template" <<'EOF'
{
  "hostname": "{hostname}",
  "timestamp": "{timestamp}",
  "status_code": {status_code},
  "status_text": "{status_text}",
  "status_message": "{status_message}",
  "plugin_name": "{plugin_name}",
  "metrics": {metrics},
  "color": "{color}",
  "title": "ServerSentry Alert - {hostname}",
  "description": "{status_message}"
}
EOF
    log_debug "Created default JSON template"
  fi

  # Default Teams card template
  local teams_template="$DEFAULT_TEMPLATE_DIR/teams.template"
  if [ ! -f "$teams_template" ]; then
    cat >"$teams_template" <<'EOF'
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "{color}",
  "summary": "ServerSentry Alert",
  "sections": [{
    "activityTitle": "{status_text} Alert",
    "activitySubtitle": "{hostname}",
    "activityImage": "https://raw.githubusercontent.com/microsoft/fluentui-system-icons/main/assets/Alert/SVG/ic_fluent_alert_24_regular.svg",
    "facts": [{
      "name": "Message",
      "value": "{status_message}"
    }, {
      "name": "Plugin",
      "value": "{plugin_name}"
    }, {
      "name": "Time",
      "value": "{timestamp}"
    }, {
      "name": "Status Code",
      "value": "{status_code}"
    }],
    "markdown": true
  }]
}
EOF
    log_debug "Created default Teams template"
  fi

  # Default Slack template
  local slack_template="$DEFAULT_TEMPLATE_DIR/slack.template"
  if [ ! -f "$slack_template" ]; then
    cat >"$slack_template" <<'EOF'
{
  "text": "{status_text} Alert from {hostname}",
  "attachments": [{
    "color": "{color}",
    "fields": [{
      "title": "Message",
      "value": "{status_message}",
      "short": false
    }, {
      "title": "Plugin",
      "value": "{plugin_name}",
      "short": true
    }, {
      "title": "Time",
      "value": "{timestamp}",
      "short": true
    }],
    "footer": "ServerSentry v2",
    "ts": {timestamp_epoch}
  }]
}
EOF
    log_debug "Created default Slack template"
  fi
}

# Process template with variable substitution
process_template() {
  local template_file="$1"
  local status_code="$2"
  local status_message="$3"
  local plugin_name="$4"
  local metrics="$5"

  # Check if template file exists
  if [ ! -f "$template_file" ]; then
    log_error "Template file not found: $template_file"
    return 1
  fi

  # Get system information
  local hostname
  hostname=$(hostname)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local timestamp_epoch
  timestamp_epoch=$(date +%s)

  # Determine status text and color
  local status_text
  local color
  case "$status_code" in
  0)
    status_text="OK"
    color="good"
    ;;
  1)
    status_text="WARNING"
    color="warning"
    ;;
  2)
    status_text="CRITICAL"
    color="danger"
    ;;
  *)
    status_text="UNKNOWN"
    color="#808080"
    ;;
  esac

  # Read template content
  local template_content
  template_content=$(cat "$template_file")

  # Perform variable substitution
  template_content="${template_content//\{hostname\}/$hostname}"
  template_content="${template_content//\{timestamp\}/$timestamp}"
  template_content="${template_content//\{timestamp_epoch\}/$timestamp_epoch}"
  template_content="${template_content//\{status_code\}/$status_code}"
  template_content="${template_content//\{status_text\}/$status_text}"
  template_content="${template_content//\{status_message\}/$status_message}"
  template_content="${template_content//\{plugin_name\}/$plugin_name}"
  template_content="${template_content//\{metrics\}/$metrics}"
  template_content="${template_content//\{color\}/$color}"

  # Additional helper variables
  local uptime
  uptime=$(uptime | awk '{print $3,$4}' | sed 's/,//')
  template_content="${template_content//\{uptime\}/$uptime}"

  local load_avg
  load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
  template_content="${template_content//\{load_avg\}/$load_avg}"

  # Output the processed template
  echo "$template_content"
}

# Get template for notification type and provider
get_template() {
  local notification_type="$1" # alert, info, test
  local provider="$2"          # teams, slack, webhook, etc.

  # Try custom template first
  local custom_template="$TEMPLATE_DIR/${provider}_${notification_type}.template"
  if [ -f "$custom_template" ]; then
    echo "$custom_template"
    return 0
  fi

  # Try provider-specific default template
  local provider_template="$DEFAULT_TEMPLATE_DIR/${provider}.template"
  if [ -f "$provider_template" ]; then
    echo "$provider_template"
    return 0
  fi

  # Try notification type default template
  local type_template="$DEFAULT_TEMPLATE_DIR/${notification_type}.template"
  if [ -f "$type_template" ]; then
    echo "$type_template"
    return 0
  fi

  # Fall back to basic alert template
  local fallback_template="$DEFAULT_TEMPLATE_DIR/alert.template"
  if [ -f "$fallback_template" ]; then
    echo "$fallback_template"
    return 0
  fi

  # Return error if no template found
  log_error "No template found for type='$notification_type' provider='$provider'"
  return 1
}

# Generate notification content using templates
generate_notification_content() {
  local notification_type="$1" # alert, info, test
  local provider="$2"          # teams, slack, webhook, etc.
  local status_code="$3"
  local status_message="$4"
  local plugin_name="$5"
  local metrics="$6"

  # Get appropriate template
  local template_file
  template_file=$(get_template "$notification_type" "$provider")

  if [ $? -ne 0 ] || [ -z "$template_file" ]; then
    log_error "Could not find template for $notification_type/$provider"
    return 1
  fi

  # Process template
  process_template "$template_file" "$status_code" "$status_message" "$plugin_name" "$metrics"
}

# List available templates
list_templates() {
  echo "Available Templates:"
  echo ""

  echo "Default Templates:"
  if [ -d "$DEFAULT_TEMPLATE_DIR" ]; then
    find "$DEFAULT_TEMPLATE_DIR" -name "*.template" -type f | sed "s|$DEFAULT_TEMPLATE_DIR/|  |" | sort
  fi

  echo ""
  echo "Custom Templates:"
  if [ -d "$TEMPLATE_DIR" ]; then
    find "$TEMPLATE_DIR" -name "*.template" -type f | sed "s|$TEMPLATE_DIR/|  |" | sort
  else
    echo "  None"
  fi
}

# Validate template syntax
validate_template() {
  local template_file="$1"

  if [ ! -f "$template_file" ]; then
    echo "❌ Template file not found: $template_file"
    return 1
  fi

  # Check for common template variables
  local required_vars=("hostname" "timestamp" "status_message")
  local warnings=0

  for var in "${required_vars[@]}"; do
    if ! grep -q "{$var}" "$template_file"; then
      echo "⚠️  Warning: Template missing variable: {$var}"
      warnings=$((warnings + 1))
    fi
  done

  # Try to process template with test data
  local test_output
  test_output=$(process_template "$template_file" 1 "Test message" "test" '{"test": true}' 2>&1)

  if [ $? -eq 0 ]; then
    echo "✅ Template validation passed"
    if [ $warnings -gt 0 ]; then
      echo "   ($warnings warnings)"
    fi
    return 0
  else
    echo "❌ Template validation failed: $test_output"
    return 1
  fi
}

# Export functions for use by notification system
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f init_template_system
  export -f create_default_templates
  export -f process_template
  export -f get_template
  export -f generate_notification_content
  export -f list_templates
  export -f validate_template
fi
