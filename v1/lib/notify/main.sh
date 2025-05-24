#!/bin/bash
#
# ServerSentry - Notification main interface
# This is the main entry point for the modular notification system

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the paths and utils modules
source "$SCRIPT_DIR/../utils/paths.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Get the project root
PROJECT_ROOT="$(get_project_root)"

# Source all required notification modules
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

    # Call the function from the sender module
    send_webhook "$url" "$title" "$message"
}

# Export the system_info getter function
get_system_info() {
    # Call the function from the system_info module
    get_system_info_data "$@"
}

# Function to create adaptive card for Microsoft Teams
create_adaptive_card() {
    # Call the function from the teams_cards module
    create_teams_card "$@"
}

# Function to format webhook payload based on URL
format_webhook_payload() {
    # Call the function from the formatters module
    format_payload "$@"
}
