#!/bin/bash
#
# ServerSentry - Installation script
# Installs and configures the ServerSentry monitoring tool

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}ServerSentry - System Monitoring & Alert Tool${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

# Detect if this is an update or a new installation
is_update=false
if [ -f "$SCRIPT_DIR/serversentry.sh" ] && [ -f "$SCRIPT_DIR/config/thresholds.conf" ]; then
    is_update=true
    current_version=$(grep -m 1 "Version:" "$SCRIPT_DIR/serversentry.sh" | awk '{print $3}')
    echo -e "${YELLOW}Existing ServerSentry installation detected (Version: $current_version)${NC}"
    echo "This script will help manage your installation."
    echo ""
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Not running as root. Some operations may fail.${NC}"
    echo "It's recommended to run this script with sudo."
    echo ""
    read -p "Continue anyway? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "Operation aborted."
        exit 1
    fi
fi

# Check for required commands
check_dependencies() {
    echo "Checking for required commands..."
    MISSING_COMMANDS=0

    check_command() {
        if command -v "$1" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $1"
        else
            echo -e "  ${RED}✗${NC} $1 ${YELLOW}($2)${NC}"
            MISSING_COMMANDS=$((MISSING_COMMANDS + 1))
        fi
    }

    check_command "bash" "required"
    check_command "curl" "required for webhooks"
    check_command "grep" "required"
    check_command "awk" "required"
    check_command "sed" "required"
    check_command "bc" "recommended for calculations"
    check_command "jq" "recommended for webhook formatting"
    check_command "crontab" "recommended for scheduling"

    if [ $MISSING_COMMANDS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Some recommended commands are missing.${NC}"
        echo "You can install them on:"
        echo -e "  ${BLUE}Debian/Ubuntu${NC}: sudo apt-get install curl jq bc"
        echo -e "  ${BLUE}CentOS/RHEL${NC}: sudo yum install curl jq bc"
        echo -e "  ${BLUE}macOS${NC}: brew install jq curl bc"
        echo ""
        read -p "Continue anyway? (y/n): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo "Operation aborted."
            exit 1
        fi
    fi
}

# Set proper permissions for scripts
set_permissions() {
    echo ""
    echo "Setting permissions..."
    chmod +x "$SCRIPT_DIR/serversentry.sh"
    
    if [ -d "$SCRIPT_DIR/lib" ]; then
        chmod +x "$SCRIPT_DIR/lib/config.sh"
        chmod +x "$SCRIPT_DIR/lib/monitor.sh"
        chmod +x "$SCRIPT_DIR/lib/notify.sh"
        chmod +x "$SCRIPT_DIR/lib/utils.sh"
    fi
    
    echo -e "${GREEN}Done!${NC}"
}

# Create configurations
create_config_files() {
    echo ""
    echo "Creating configuration files..."
    mkdir -p "$SCRIPT_DIR/config"
    
    if [ ! -f "$SCRIPT_DIR/config/thresholds.conf" ]; then
        cat > "$SCRIPT_DIR/config/thresholds.conf" <<EOF
# ServerSentry Thresholds Configuration
# Values are in percentage except for load and interval
cpu_threshold=80
memory_threshold=80
disk_threshold=85
load_threshold=2.0
check_interval=60
process_checks=
EOF
        echo -e "  ${GREEN}Created${NC} thresholds.conf"
    else
        echo -e "  ${YELLOW}Skipped${NC} thresholds.conf (already exists)"
    fi

    if [ ! -f "$SCRIPT_DIR/config/webhooks.conf" ]; then
        cat > "$SCRIPT_DIR/config/webhooks.conf" <<EOF
# ServerSentry Webhooks Configuration
# Add one webhook URL per line
EOF
        echo -e "  ${GREEN}Created${NC} webhooks.conf"
    else
        echo -e "  ${YELLOW}Skipped${NC} webhooks.conf (already exists)"
    fi
}

# Function to list existing crons
list_existing_crons() {
    echo ""
    echo -e "${CYAN}Current ServerSentry cron jobs:${NC}"
    existing_crons=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/serversentry.sh")
    
    if [ -z "$existing_crons" ]; then
        echo -e "  ${YELLOW}No existing cron jobs found${NC}"
        return 1
    else
        echo "$existing_crons" | nl -w2 -s") "
        return 0
    fi
}

# Function to set up a new cron job
setup_cron_job() {
    CRON_INTERVAL="*/5"
    echo ""
    echo -e "${CYAN}How often should ServerSentry run?${NC}"
    echo -e "1) Every 5 minutes    ${YELLOW}• Recommended for critical systems (default)${NC}"
    echo -e "2) Every 15 minutes   ${YELLOW}• Good balance between monitoring and resources${NC}"
    echo -e "3) Every hour         ${YELLOW}• Less frequent, suitable for stable systems${NC}"
    echo -e "4) Daily (midnight)   ${YELLOW}• Once per day health check${NC}"
    echo -e "5) Custom             ${YELLOW}• Define your own cron schedule expression${NC}"
    
    echo ""
    read -p "Select option (1-5): " cron_option
    
    case "$cron_option" in
        1) CRON_INTERVAL="*/5 * * * *" ;;
        2) CRON_INTERVAL="*/15 * * * *" ;;
        3) CRON_INTERVAL="0 * * * *" ;;
        4) CRON_INTERVAL="0 0 * * *" ;;
        5)
            echo "Enter cron schedule expression (e.g., */10 * * * *):"
            read -p "Cron expression: " CRON_INTERVAL
            ;;
        *) CRON_INTERVAL="*/5 * * * *" ;;
    esac
    
    # Create the cron entry
    CRON_ENTRY="$CRON_INTERVAL $SCRIPT_DIR/serversentry.sh --check >> $SCRIPT_DIR/sysmon.log 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null || echo "") | { cat; echo "$CRON_ENTRY"; } | crontab -
    
    echo -e "${GREEN}Cron job has been set up successfully!${NC}"
    echo "ServerSentry will run: $CRON_INTERVAL"
}

# Function to remove a specific cron job
remove_cron_job() {
    list_existing_crons
    if [ $? -eq 1 ]; then
        return
    fi
    
    echo ""
    read -p "Enter number of cron job to remove (0 to cancel): " cron_number
    
    if [ "$cron_number" = "0" ]; then
        echo "Operation cancelled."
        return
    fi
    
    local cron_to_remove=$(crontab -l | grep "$SCRIPT_DIR/serversentry.sh" | sed -n "${cron_number}p")
    
    if [ -z "$cron_to_remove" ]; then
        echo -e "${RED}Invalid cron job number${NC}"
        return
    fi
    
    # Remove the specific cron job
    crontab -l | grep -v "$cron_to_remove" | crontab -
    echo -e "${GREEN}Cron job removed successfully!${NC}"
}

# Function to remove all ServerSentry cron jobs
remove_all_cron_jobs() {
    echo ""
    read -p "Are you sure you want to remove ALL ServerSentry cron jobs? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return
    fi
    
    crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/serversentry.sh" | crontab -
    echo -e "${GREEN}All ServerSentry cron jobs have been removed.${NC}"
}

# Function to manually test a cron job
test_cron_job() {
    list_existing_crons
    if [ $? -eq 1 ]; then
        return
    fi
    
    echo ""
    read -p "Enter number of cron job to test (0 to cancel): " cron_number
    
    if [ "$cron_number" = "0" ]; then
        echo "Operation cancelled."
        return
    fi
    
    local cron_to_test=$(crontab -l | grep "$SCRIPT_DIR/serversentry.sh" | sed -n "${cron_number}p")
    
    if [ -z "$cron_to_test" ]; then
        echo -e "${RED}Invalid cron job number${NC}"
        return
    fi
    
    # Extract command part (everything after the time fields)
    local cron_command=$(echo "$cron_to_test" | cut -d' ' -f6-)
    
    # Split command and redirection
    local command=$(echo "$cron_command" | grep -o "^[^>]*")
    local redirection=$(echo "$cron_command" | grep -o ">>.*" || echo "")
    
    echo ""
    echo -e "${CYAN}Testing actual cron job command:${NC}"
    echo -e "${YELLOW}$command${NC}"
    echo ""
    read -p "Proceed with test? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Test cancelled."
        return
    fi
    
    echo ""
    echo -e "${CYAN}Executing command from crontab:${NC}"
    echo "-------------------------------------"
    
    # Execute the exact command from crontab
    eval $command
    
    local status=$?
    echo "-------------------------------------"
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ Test completed successfully (exit code: $status)${NC}"
    else
        echo -e "${RED}✗ Test failed with exit code: $status${NC}"
    fi
    
    echo ""
    if [ -n "$redirection" ]; then
        echo -e "${YELLOW}Note:${NC} When run by cron, output will be redirected: $redirection"
    fi
    read -p "Press Enter to continue..." dummy
}

# Manage cron jobs
manage_crons() {
    while true; do
        echo ""
        echo -e "${CYAN}ServerSentry Cron Management${NC}"
        echo "=========================="
        
        list_existing_crons
        
        echo ""
        echo -e "${CYAN}Options:${NC}"
        echo -e "1) Add new cron job         ${YELLOW}• Schedule a new automatic monitoring task${NC}"
        echo -e "2) Remove specific cron job ${YELLOW}• Delete an individual scheduled task${NC}"
        echo -e "3) Remove all cron jobs     ${YELLOW}• Clear all ServerSentry scheduled tasks${NC}"
        echo -e "4) Test cron job manually   ${YELLOW}• Run a scheduled task now to verify it works${NC}"
        echo -e "5) Return to main menu      ${YELLOW}• Go back to management options${NC}"
        
        echo ""
        read -p "Select option (1-5): " cron_action
        
        case "$cron_action" in
            1) setup_cron_job ;;
            2) remove_cron_job ;;
            3) remove_all_cron_jobs ;;
            4) test_cron_job ;;
            5) return ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Show current configuration
show_config() {
    echo ""
    echo -e "${CYAN}Current ServerSentry Configuration${NC}"
    echo "====================================="
    
    if [ -f "$SCRIPT_DIR/config/thresholds.conf" ]; then
        echo -e "${BLUE}Thresholds:${NC}"
        grep -v "^#" "$SCRIPT_DIR/config/thresholds.conf" | grep -v "^$" | sed 's/^/  /'
    else
        echo -e "${RED}No thresholds configuration found.${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Webhooks:${NC}"
    if [ -f "$SCRIPT_DIR/config/webhooks.conf" ]; then
        webhook_count=$(grep -v "^#" "$SCRIPT_DIR/config/webhooks.conf" | grep -v "^$" | wc -l)
        if [ "$webhook_count" -gt 0 ]; then
            grep -v "^#" "$SCRIPT_DIR/config/webhooks.conf" | grep -v "^$" | nl | sed 's/^/  /'
        else
            echo -e "  ${YELLOW}No webhooks configured${NC}"
        fi
    else
        echo -e "  ${RED}No webhooks configuration found.${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Cron Jobs:${NC}"
    existing_crons=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR/serversentry.sh")
    if [ -z "$existing_crons" ]; then
        echo -e "  ${YELLOW}No scheduled tasks configured${NC}"
    else
        echo "$existing_crons" | sed 's/^/  /'
    fi
}

# Install ServerSentry
install_serversentry() {
    check_dependencies
    set_permissions
    create_config_files
    
    echo ""
    echo -e "${GREEN}ServerSentry installation complete!${NC}"
    
    echo ""
    read -p "Would you like to set up a cron job for automatic monitoring? (y/n): " setup_cron
    if [[ "$setup_cron" =~ ^[Yy]$ ]]; then
        setup_cron_job
    else
        echo "Skipping cron job setup."
    fi
}

# Update ServerSentry
update_serversentry() {
    check_dependencies
    set_permissions
    
    echo ""
    echo -e "${GREEN}ServerSentry updated successfully!${NC}"
}

# Print usage information
print_usage() {
    echo ""
    echo -e "${CYAN}Usage Information${NC}"
    echo "================="
    echo "To use ServerSentry, run:"
    echo "  $SCRIPT_DIR/serversentry.sh --help"
    echo ""
    echo "Common Commands:"
    echo "  $SCRIPT_DIR/serversentry.sh --check"
    echo "  $SCRIPT_DIR/serversentry.sh --monitor"
    echo "  $SCRIPT_DIR/serversentry.sh --test-webhook"
    echo "  $SCRIPT_DIR/serversentry.sh --add-webhook URL"
    echo ""
}

# Main menu for update case
update_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}ServerSentry Management${NC}"
        echo "======================="
        echo -e "1) Update ServerSentry      ${YELLOW}• Update and maintain core monitoring components${NC}"
        echo -e "2) Manage cron jobs         ${YELLOW}• Schedule automatic system checks and alerts${NC}"
        echo -e "3) View current configuration${YELLOW}• See thresholds, webhooks, and scheduled tasks${NC}"
        echo -e "4) Reset configuration files ${YELLOW}• Restore default settings (thresholds, webhooks)${NC}"
        echo -e "5) Show usage information   ${YELLOW}• Display available commands and examples${NC}"
        echo -e "6) Exit                     ${YELLOW}• Close this management interface${NC}"
        
        echo ""
        read -p "Select option (1-6): " option
        
        case "$option" in
            1) update_serversentry ;;
            2) manage_crons ;;
            3) show_config ;;
            4)
                echo ""
                read -p "Are you sure you want to reset all configuration files? (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    rm -f "$SCRIPT_DIR/config/thresholds.conf"
                    rm -f "$SCRIPT_DIR/config/webhooks.conf"
                    create_config_files
                    echo -e "${GREEN}Configuration files have been reset.${NC}"
                fi
                ;;
            5) print_usage ;;
            6) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Main menu for new installation
install_menu() {
    echo ""
    echo -e "${CYAN}ServerSentry Installation${NC}"
    echo "======================="
    echo "1) Install ServerSentry"
    echo "2) Exit"
    
    read -p "Select option (1-2): " option
    
    case "$option" in
        1) install_serversentry; print_usage ;;
        2) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
    esac
}

# Main execution logic
if $is_update; then
    update_menu
else
    install_menu
fi

exit 0
