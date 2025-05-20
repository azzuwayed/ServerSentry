#!/bin/bash
#
# ServerSentry - Webhook Payload Formatters Module
# Part of the modular notify system

# Check if dependencies are sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$PARENT_DIR/lib/utils.sh"
fi

# Make sure we have access to system_info.sh functions
if [[ "$(type -t extract_from_system_info)" != "function" ]]; then
    source "$SCRIPT_DIR/system_info.sh"
fi

# Make sure we have access to teams_cards.sh functions
if [[ "$(type -t create_adaptive_card)" != "function" ]]; then
    source "$SCRIPT_DIR/teams_cards.sh"
fi

# Wrapper function that main.sh calls
format_payload() {
    format_webhook_payload "$@"
}

# Format the webhook payload based on the provider
format_webhook_payload() {
    local url="$1"
    local title="$2"
    local message="$3"
    local hostname=$(hostname)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)
    
    # Get additional system information
    local system_info=""
    local adaptive_card=""
    system_info=$(get_system_info)

    # Get alert severity/status
    local status="info"
    if [[ "$title" == *"Alert"* ]]; then
        status="alert"
    elif [[ "$title" == *"Test"* ]]; then
        status="test"
    fi
    
    # Extract specific values from system_info JSON
    local os=$(extract_from_system_info "$system_info" "os")
    local ip=$(extract_from_system_info "$system_info" "ip")
    local cpu_usage=$(extract_from_system_info "$system_info" "cpu_usage")
    local memory_usage=$(extract_from_system_info "$system_info" "memory_usage")
    local disk_usage=$(extract_from_system_info "$system_info" "disk_usage")
    local uptime=$(extract_from_system_info "$system_info" "uptime")
    local kernel=$(extract_from_system_info "$system_info" "kernel")
    local loadavg=$(extract_from_system_info "$system_info" "loadavg")
    local memory_info=$(extract_from_system_info "$system_info" "memory_info")
    local disk_info=$(extract_from_system_info "$system_info" "disk_info")
    local cpu_info=$(extract_from_system_info "$system_info" "cpu_info")
    
    # Create adaptive card for Teams
    adaptive_card=$(create_adaptive_card "$title" "$message" "$system_info" "$status" "$timestamp")
    
    # Escape message for JSON embedding
    local escaped_message="${message//\"/\\\"}"
    escaped_message="${escaped_message//$'\n'/\\n}"
    
    # Determine which format to use based on URL
    local domain=$(echo "$url" | grep -o -E 'https?://([^/]+)' | sed 's|https\?://||')
    local payload=""
    
    # Look for Power Automate/Microsoft Flow/Teams in the URL
    if [[ "$url" =~ "logic.azure.com" ]] || [[ "$url" =~ "powerautomate" ]] || [[ "$url" =~ "microsoft" ]]; then
        # Create a Teams-formatted message card
        local teams_card=$(create_teams_message_card "$title" "$message" "$system_info" "$status" "$timestamp")
        
        # Create the primary payload with the required attachments array
        payload="{
            \"type\": \"message\",
            \"title\": \"$title\",
            \"text\": \"$escaped_message\",
            \"attachments\": [
                $teams_card
            ],
            \"hostname\": \"$hostname\",
            \"ip\": \"$ip\",
            \"timestamp\": \"$timestamp\",
            \"source\": \"ServerSentry\",
            \"os\": \"$os\",
            \"cpu_usage\": \"$cpu_usage\",
            \"memory_usage\": \"$memory_usage\",
            \"disk_usage\": \"$disk_usage\"
        }"
    elif [[ "$domain" == *slack.com ]]; then
        # Slack webhook
        payload="{\"text\":\"*$title*\\n$message\\n_From $hostname at $timestamp_\"}"
    elif [[ "$domain" == *discord.com ]]; then
        # Discord webhook
        payload="{\"content\":\"**$title**\\n$message\\n*From $hostname at $timestamp*\"}"
    else
        # Default generic JSON payload - include all data
        payload="{
            \"title\": \"$title\",
            \"message\": \"${escaped_message}\",
            \"hostname\": \"$hostname\",
            \"ip\": \"$ip\",
            \"timestamp\": \"$timestamp\",
            \"source\": \"ServerSentry\",
            \"os\": \"$os\",
            \"kernel\": \"$kernel\",
            \"uptime\": \"$uptime\",
            \"loadavg\": \"$loadavg\",
            \"cpu\": \"$cpu_info\",
            \"cpu_usage\": \"$cpu_usage\",
            \"memory\": \"$memory_info\",
            \"memory_usage\": \"$memory_usage\",
            \"disk\": \"$disk_info\",
            \"disk_usage\": \"$disk_usage\",
            \"status\": \"$status\",
            \"content\": ${adaptive_card}
        }"
    fi
    
    echo "$payload"
} 