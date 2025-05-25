#!/usr/bin/env bash
#
# ServerSentry v2 - Generic Webhook Notification Provider
#
# This module sends notifications to generic webhooks with customizable headers and payloads

# Webhook configuration
webhook_url=""
webhook_headers=""
webhook_payload_template=""
webhook_method="POST"
webhook_timeout="10"

# Initialize webhook provider
webhook_provider_init() {
  log_debug "Initializing webhook provider"

  # Load configuration
  webhook_url=$(config_get_value "webhook_url" "")
  webhook_headers=$(config_get_value "webhook_headers" "Content-Type: application/json")
  webhook_payload_template=$(config_get_value "webhook_payload_template" "")
  webhook_method=$(config_get_value "webhook_method" "POST")
  webhook_timeout=$(config_get_value "webhook_timeout" "10")

  return 0
}

# Configure webhook provider
webhook_provider_configure() {
  local config_file="$1"

  if [ -n "$config_file" ] && [ -f "$config_file" ]; then
    log_debug "Loading webhook configuration from: $config_file"
    source "$config_file"
  else
    log_debug "Using default webhook configuration"
  fi

  return 0
}

# Get webhook provider information
webhook_provider_info() {
  echo "Generic Webhook Provider v1.0 - Sends notifications to custom webhook endpoints"
}

# Send webhook notification
webhook_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local metrics="$4"
  local custom_url="${5:-$webhook_url}"

  # Validate webhook URL
  if [ -z "$custom_url" ]; then
    log_error "Webhook URL not configured"
    echo "Error: Webhook URL not configured"
    return 1
  fi

  # Validate URL format
  if ! [[ "$custom_url" =~ ^https?:// ]]; then
    log_error "Invalid webhook URL format: $custom_url"
    echo "Error: Invalid webhook URL format"
    return 1
  fi

  # Get system information for templates
  local hostname
  hostname=$(hostname)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local status_text
  case "$status_code" in
  0) status_text="OK" ;;
  1) status_text="WARNING" ;;
  2) status_text="CRITICAL" ;;
  *) status_text="UNKNOWN" ;;
  esac

  # Determine color based on status
  local color
  case "$status_code" in
  0) color="good" ;;    # Green
  1) color="warning" ;; # Yellow
  2) color="danger" ;;  # Red
  *) color="#808080" ;; # Gray
  esac

  # Create default payload if no template specified
  local payload
  if [ -n "$webhook_payload_template" ]; then
    # Use custom template with variable substitution
    payload="$webhook_payload_template"
    payload="${payload//\{hostname\}/$hostname}"
    payload="${payload//\{timestamp\}/$timestamp}"
    payload="${payload//\{status_code\}/$status_code}"
    payload="${payload//\{status_text\}/$status_text}"
    payload="${payload//\{status_message\}/$status_message}"
    payload="${payload//\{plugin_name\}/$plugin_name}"
    payload="${payload//\{metrics\}/$metrics}"
    payload="${payload//\{color\}/$color}"
  else
    # Default JSON payload
    payload=$(
      cat <<EOF
{
  "hostname": "$hostname",
  "timestamp": "$timestamp",
  "status_code": $status_code,
  "status_text": "$status_text",
  "status_message": "$status_message",
  "plugin_name": "$plugin_name",
  "metrics": $metrics,
  "color": "$color",
  "title": "ServerSentry Alert - $hostname",
  "text": "$status_message"
}
EOF
    )
  fi

  # Prepare headers
  local header_args=()
  if [ -n "$webhook_headers" ]; then
    # Split headers by newline or semicolon
    while IFS= read -r header; do
      if [ -n "$header" ]; then
        header_args+=("-H" "$header")
      fi
    done <<<"$(echo "$webhook_headers" | tr ';' '\n')"
  fi

  # Default content-type if not specified
  if [ ${#header_args[@]} -eq 0 ]; then
    header_args+=("-H" "Content-Type: application/json")
  fi

  log_debug "Sending webhook notification to: $custom_url"
  log_debug "Method: $webhook_method"
  log_debug "Headers: ${header_args[*]}"
  log_debug "Payload: $payload"

  # Send the webhook
  local response
  local http_code

  if [ "$webhook_method" = "GET" ]; then
    # For GET requests, encode data as query parameters
    local encoded_message
    encoded_message=$(echo "$status_message" | sed 's/ /%20/g' | sed 's/&/%26/g')
    local query_url="${custom_url}?hostname=${hostname}&status=${status_text}&message=${encoded_message}"

    response=$(curl -s -w "\n%{http_code}" \
      --max-time "$webhook_timeout" \
      "${header_args[@]}" \
      "$query_url" 2>&1)
  else
    # For POST/PUT/PATCH requests, send JSON payload
    response=$(curl -s -w "\n%{http_code}" \
      --max-time "$webhook_timeout" \
      -X "$webhook_method" \
      "${header_args[@]}" \
      -d "$payload" \
      "$custom_url" 2>&1)
  fi

  # Extract HTTP code from response
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | head -n -1)

  # Check response
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    log_info "Webhook notification sent successfully (HTTP $http_code)"
    echo "Webhook notification sent successfully"
    return 0
  else
    log_error "Webhook notification failed (HTTP $http_code): $response_body"
    echo "Error: Webhook notification failed (HTTP $http_code)"
    return 1
  fi
}

# Test webhook connectivity
webhook_provider_test() {
  local test_url="${1:-$webhook_url}"

  if [ -z "$test_url" ]; then
    echo "Error: No webhook URL provided for testing"
    return 1
  fi

  log_info "Testing webhook connectivity: $test_url"

  # Send a test notification
  webhook_provider_send 0 "Test notification from ServerSentry v2" "test" '{"test": true}' "$test_url"
}

# Validate webhook configuration
webhook_provider_validate() {
  local errors=0

  if [ -z "$webhook_url" ]; then
    log_error "webhook_url is required"
    errors=$((errors + 1))
  elif ! [[ "$webhook_url" =~ ^https?:// ]]; then
    log_error "webhook_url must be a valid HTTP/HTTPS URL"
    errors=$((errors + 1))
  fi

  if ! [[ "$webhook_timeout" =~ ^[0-9]+$ ]] || [ "$webhook_timeout" -lt 1 ]; then
    log_error "webhook_timeout must be a positive integer"
    errors=$((errors + 1))
  fi

  if [ -n "$webhook_method" ] && ! [[ "$webhook_method" =~ ^(GET|POST|PUT|PATCH)$ ]]; then
    log_error "webhook_method must be GET, POST, PUT, or PATCH"
    errors=$((errors + 1))
  fi

  return $errors
}

# Get webhook provider status
webhook_provider_status() {
  echo "Webhook Provider Status:"
  echo "  URL: ${webhook_url:-'Not configured'}"
  echo "  Method: ${webhook_method:-'POST'}"
  echo "  Timeout: ${webhook_timeout:-'10'}s"
  echo "  Headers: ${webhook_headers:-'Default'}"
  echo "  Template: ${webhook_payload_template:-'Default JSON'}"
}

# Export functions for use by notification system
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  # Only export if being sourced
  export -f webhook_provider_init
  export -f webhook_provider_configure
  export -f webhook_provider_info
  export -f webhook_provider_send
  export -f webhook_provider_test
  export -f webhook_provider_validate
  export -f webhook_provider_status
fi
