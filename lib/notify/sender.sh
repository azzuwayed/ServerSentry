#!/bin/bash
#
# ServerSentry - Webhook Sender Module
# Part of the modular notify system

# Check if dependencies are sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$PARENT_DIR/lib/utils.sh"
fi

if [[ "$(type -t command_exists)" != "function" ]]; then
    source "$PARENT_DIR/lib/utils.sh"
fi

# Make sure we have access to formatters.sh
if [[ "$(type -t format_webhook_payload)" != "function" ]]; then
    source "$SCRIPT_DIR/formatters.sh"
fi

# Check if jq is available for better JSON support
HAS_JQ=0
if command_exists jq; then
    HAS_JQ=1
fi

# Send a webhook notification
send_webhook_notification() {
    local url="$1"
    local title="$2"
    local message="$3"
    
    # Ensure URL is properly formatted (remove any accidental escaping)
    url=$(echo "$url" | sed 's/\\//g')
    
    if ! command_exists curl; then
        log_message "ERROR" "curl command not found, cannot send webhook notification"
        echo "[ERROR] curl command not found, cannot send webhook notification"
        return 1
    fi
    
    log_message "INFO" "Sending webhook notification to $url"
    local payload=$(format_webhook_payload "$url" "$title" "$message")
    
    # Log the payload for debugging
    log_message "DEBUG" "Webhook payload: $payload"
    
    local response status_code body
    if [ $HAS_JQ -eq 1 ]; then
        response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        status_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        echo "[DEBUG] HTTP status: $status_code"
        echo "[DEBUG] Response body: $body"
        
        log_message "DEBUG" "Response status: $status_code, body: $body"
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $status_code)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $status_code, Response: $body)"
            return 1
        fi
    else
        status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        echo "[DEBUG] HTTP status: $status_code"
        
        log_message "DEBUG" "Response status: $status_code"
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $status_code)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $status_code)"
            return 1
        fi
    fi
} 