#!/bin/bash
#
# ServerSentry - Notification main interface
# This is the main entry point for the modular notification system

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)"

# Source all required modules using PROJECT_ROOT
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/notify/system_info.sh"
source "$PROJECT_ROOT/lib/notify/teams_cards.sh"
source "$PROJECT_ROOT/lib/notify/formatters.sh"
source "$PROJECT_ROOT/lib/notify/sender.sh"

# Check if curl is available
if ! command_exists curl; then
    log_message "WARNING" "curl command not found, webhook notifications will not work"
fi

# Export the main interface functions
# These are the functions that will be used by the rest of the application

# Main function to send notification to a webhook
# This maintains the same interface as the original notify.sh
send_webhook_notification() {
    local url="$1"
    local title="$2"
    local message="$3"

    # Delegate to the sender module
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/sender.sh"
    send_webhook "$url" "$title" "$message"
}

# Export the system_info getter function
get_system_info() {
    # Delegate to the system_info module
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/system_info.sh"
    get_system_info_data "$@"
}

# Function to create adaptive card for Microsoft Teams
create_adaptive_card() {
    # Delegate to the teams_cards module
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/teams_cards.sh"
    create_teams_card "$@"
}

# Function to format webhook payload based on URL
format_webhook_payload() {
    # Delegate to the formatters module
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/formatters.sh"
    format_payload "$@"
}
