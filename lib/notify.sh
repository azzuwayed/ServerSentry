#!/bin/bash
#
# SysMon - Notification functionality

# Source dependencies if not already sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"  # Go up one level to get to the root

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

# Check if curl is available
if ! command_exists curl; then
    log_message "WARNING" "curl command not found, webhook notifications will not work"
fi

# Check if jq is available for better JSON support
HAS_JQ=0
if command_exists jq; then
    HAS_JQ=1
fi

# Format the webhook payload based on the provider (default is generic JSON)
format_webhook_payload() {
    local url="$1"
    local title="$2"
    local message="$3"
    local hostname=$(hostname)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Extract domain from URL to identify the provider
    local domain=$(echo "$url" | grep -oP '(?<=://)[^/]+' | awk -F. '{print $(NF-1)"."$NF}')
    
    # Default JSON payload
    local payload='{
        "title": "'"$title"'",
        "message": "'"${message//\"/\\\"}"'",
        "hostname": "'"$hostname"'",
        "timestamp": "'"$timestamp"'",
        "source": "SysMon"
    }'
    
    # Format the payload according to the provider
    case "$domain" in
        slack.com)
            # Slack webhook
            payload='{
                "text": "'"$title"'",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "'"$title"'"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": "'"${message//\"/\\\"}"'"
                        }
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": "Server: *'"$hostname"'* | Time: '"$timestamp"'"
                            }
                        ]
                    }
                ]
            }'
            ;;
        discord.com)
            # Discord webhook
            payload='{
                "embeds": [
                    {
                        "title": "'"$title"'",
                        "description": "'"${message//\"/\\\"}"'",
                        "color": 16711680,
                        "footer": {
                            "text": "SysMon on '"$hostname"' at '"$timestamp"'"
                        }
                    }
                ]
            }'
            ;;
        microsoft.com|office.com)
            # Microsoft Teams webhook
            payload='{
                "@type": "MessageCard",
                "@context": "http://schema.org/extensions",
                "themeColor": "0076D7",
                "summary": "'"$title"'",
                "sections": [
                    {
                        "activityTitle": "'"$title"'",
                        "activitySubtitle": "From '"$hostname"' at '"$timestamp"'",
                        "text": "'"${message//\"/\\\"}"'"
                    }
                ]
            }'
            ;;
    esac
    
    echo "$payload"
}

# Send a webhook notification
send_webhook_notification() {
    local url="$1"
    local title="$2"
    local message="$3"
    
    if ! command_exists curl; then
        log_message "ERROR" "curl command not found, cannot send webhook notification"
        return 1
    fi
    
    log_message "INFO" "Sending webhook notification to $url"
    
    # Format the payload
    local payload=$(format_webhook_payload "$url" "$title" "$message")
    
    # Send the webhook request
    local response
    if [ $HAS_JQ -eq 1 ]; then
        # Better error handling with jq
        response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        local status_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $status_code)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $status_code, Response: $body)"
            return 1
        fi
    else
        # Simple error handling without jq
        response=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        
        if [ "$response" -ge 200 ] && [ "$response" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $response)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $response)"
            return 1
        fi
    fi
}
