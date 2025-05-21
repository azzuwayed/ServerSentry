#!/bin/bash
#
# ServerSentry - Installation script
# Installs and configures the ServerSentry monitoring tool

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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
        chmod +x "$SCRIPT_DIR/lib/config/config.sh"
        chmod +x "$SCRIPT_DIR/lib/monitor/monitor.sh"
        chmod +x "$SCRIPT_DIR/lib/utils/utils.sh"
        chmod +x "$SCRIPT_DIR/lib/monitor/periodic.sh"
        chmod +x "$SCRIPT_DIR/lib/log/logrotate.sh"
    fi

    echo -e "${GREEN}Done!${NC}"
}

# Create configurations
create_config_files() {
    echo ""
    echo "Creating configuration files..."
    mkdir -p "$SCRIPT_DIR/config"
    mkdir -p "$SCRIPT_DIR/logs/archive"

    if [ ! -f "$SCRIPT_DIR/config/thresholds.conf" ]; then
        cat >"$SCRIPT_DIR/config/thresholds.conf" <<EOF
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
        cat >"$SCRIPT_DIR/config/webhooks.conf" <<EOF
# ServerSentry Webhooks Configuration
# Add one webhook URL per line
EOF
        echo -e "  ${GREEN}Created${NC} webhooks.conf"
    else
        echo -e "  ${YELLOW}Skipped${NC} webhooks.conf (already exists)"
    fi

    # Create log rotation configuration file
    if [ ! -f "$SCRIPT_DIR/config/logrotate.conf" ]; then
        cat >"$SCRIPT_DIR/config/logrotate.conf" <<EOF
# ServerSentry Log Rotation Configuration

# Maximum size in MB before rotation (0 = no size limit)
max_size_mb=10

# Maximum age in days before deletion (0 = never delete based on age)
max_age_days=30

# Maximum number of rotated log files to keep (0 = keep all)
max_files=10

# Compress rotated logs (true/false)
compress=true

# Rotate logs on application start (true/false)
rotate_on_start=false

# End of configuration
EOF
        echo -e "  ${GREEN}Created${NC} logrotate.conf"
    else
        echo -e "  ${YELLOW}Skipped${NC} logrotate.conf (already exists)"
    fi

    # Copy the periodic cron template
    if [ ! -f "$SCRIPT_DIR/config/periodic_cron.template" ]; then
        # Create directory if needed
        mkdir -p "$SCRIPT_DIR/config"

        # Create the template file
        cat >"$SCRIPT_DIR/config/periodic_cron.template" <<EOF
# ServerSentry - Periodic Checks Cron Template
# 
# This file contains example cron entries for automated periodic reports.
# To use: Copy and paste the appropriate line into your crontab (crontab -e)
# Be sure to replace /path/to with the actual path to your ServerSentry installation.

# Run periodic check every hour
0 * * * * $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1

# Run periodic check at specific times (9 AM daily)
0 9 * * * $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1

# Run periodic check every 6 hours
0 */6 * * * $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1

# Run checks only on weekdays (Monday through Friday) at 9 AM
0 9 * * 1-5 $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1

# Run check once every Monday and Thursday at 9 AM
0 9 * * 1,4 $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1

# Run log rotation daily at midnight
0 0 * * * $SCRIPT_DIR/serversentry.sh --logs rotate >> $SCRIPT_DIR/serversentry.log 2>&1

# NOTE: You can configure the report behavior using the config file at:
# $SCRIPT_DIR/config/periodic.conf
#
# Or use the command-line interface:
# $SCRIPT_DIR/serversentry.sh --periodic config report_level detailed
EOF
        echo -e "  ${GREEN}Created${NC} periodic_cron.template"
    else
        echo -e "  ${YELLOW}Skipped${NC} periodic_cron.template (already exists)"
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
    (crontab -l 2>/dev/null || echo "") | {
        cat
        echo "$CRON_ENTRY"
    } | crontab -

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
    eval "$command"

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
    clear
    echo ""
    echo -e "${CYAN}┌───────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│             ServerSentry Usage Guide                  │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────────┘${NC}"

    echo -e "\n${BLUE}🔍 BASIC COMMANDS${NC}\n"
    echo -e "  ${GREEN}serversentry --help${NC}"
    echo -e "    ↳ Display comprehensive help information\n"

    echo -e "  ${GREEN}serversentry --check${NC}"
    echo -e "    ↳ Run a one-time system check and display results\n"

    echo -e "  ${GREEN}serversentry --monitor${NC}"
    echo -e "    ↳ Start continuous monitoring in foreground mode\n"

    echo -e "  ${GREEN}serversentry --status${NC}"
    echo -e "    ↳ Show current system status and metrics\n"

    echo -e "\n${BLUE}🔔 NOTIFICATION MANAGEMENT${NC}\n"
    echo -e "  ${GREEN}serversentry --test-webhook${NC}"
    echo -e "    ↳ Test notifications to all configured webhooks\n"

    echo -e "  ${GREEN}serversentry --add-webhook URL${NC}"
    echo -e "    ↳ Add a new webhook notification endpoint\n"

    echo -e "  ${GREEN}serversentry --remove-webhook N${NC}"
    echo -e "    ↳ Remove webhook number N from configuration\n"

    echo -e "\n${BLUE}⚙️ CONFIGURATION${NC}\n"
    echo -e "  ${GREEN}serversentry --update NAME=VALUE${NC}"
    echo -e "    ↳ Update configuration threshold (e.g., cpu_threshold=90)\n"

    echo -e "  ${GREEN}serversentry --list${NC}"
    echo -e "    ↳ List all configured thresholds and webhooks\n"

    echo -e "\n${YELLOW}TIP:${NC} Create an alias for easier access:"
    echo -e "  ${GREEN}alias serversentry=\"$SCRIPT_DIR/serversentry.sh\"${NC}"

    echo -e "\n${BLUE}📖 DOCUMENTATION${NC}"
    echo -e "  For Microsoft Teams integration, see:"
    echo -e "  ${GREEN}cat TEAMS_SETUP.md${NC}\n"

    read -p "Press Enter to continue..." dummy
}

# Configure periodic reporting
setup_periodic_reports() {
    clear
    echo -e "${CYAN}┌───────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│         Configure Periodic System Reports             │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────────┘${NC}"

    echo -e "\nPeriodic reports send system status to configured webhooks on a schedule."
    echo -e "You can use this to receive daily/weekly summaries or regular health checks.\n"

    # First ensure the config file exists
    "$SCRIPT_DIR/serversentry.sh" --periodic status >/dev/null 2>&1

    echo -e "${BLUE}Current configuration:${NC}"
    "$SCRIPT_DIR/serversentry.sh" --periodic status | grep -v "No report history"
    echo ""

    # Let user select which settings to change
    echo -e "${BLUE}What would you like to configure?${NC}"
    echo -e "1) Report frequency"
    echo -e "2) Report level (detail)"
    echo -e "3) Checks to include"
    echo -e "4) Force reporting (send even when no issues)"
    echo -e "5) Schedule specific days"
    echo -e "6) Set up a cron job"
    echo -e "7) Return to main menu"

    echo ""
    read -p "Select option (1-7): " option

    case "$option" in
    1)
        echo -e "\n${BLUE}Select report frequency:${NC}"
        echo -e "1) Hourly"
        echo -e "2) Every 6 hours"
        echo -e "3) Daily"
        echo -e "4) Weekly"
        echo -e "5) Custom interval (in seconds)"
        echo ""
        read -p "Select frequency (1-5): " freq

        case "$freq" in
        1) "$SCRIPT_DIR/serversentry.sh" --periodic config report_interval 3600 ;;
        2) "$SCRIPT_DIR/serversentry.sh" --periodic config report_interval 21600 ;;
        3) "$SCRIPT_DIR/serversentry.sh" --periodic config report_interval 86400 ;;
        4) "$SCRIPT_DIR/serversentry.sh" --periodic config report_interval 604800 ;;
        5)
            read -p "Enter interval in seconds: " custom_interval
            "$SCRIPT_DIR/serversentry.sh" --periodic config report_interval "$custom_interval"
            ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        ;;
    2)
        echo -e "\n${BLUE}Select report detail level:${NC}"
        echo -e "1) Minimal (only alerts)"
        echo -e "2) Summary (basic info + alerts)"
        echo -e "3) Detailed (comprehensive system info)"
        echo ""
        read -p "Select level (1-3): " level

        case "$level" in
        1) "$SCRIPT_DIR/serversentry.sh" --periodic config report_level minimal ;;
        2) "$SCRIPT_DIR/serversentry.sh" --periodic config report_level summary ;;
        3) "$SCRIPT_DIR/serversentry.sh" --periodic config report_level detailed ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        ;;
    3)
        echo -e "\n${BLUE}Select checks to include (comma-separated):${NC}"
        echo -e "Available checks: cpu, memory, disk, load, processes, network, all"
        echo -e "Example: cpu,memory,disk"
        echo ""
        read -p "Enter checks: " checks

        "$SCRIPT_DIR/serversentry.sh" --periodic config report_checks "$checks"
        ;;
    4)
        echo -e "\n${BLUE}Force sending reports even when no issues detected?${NC}"
        echo -e "This will send a report regardless of whether thresholds are exceeded."
        echo ""
        read -p "Force reports (y/n): " force

        if [[ "$force" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --periodic config force_report true
        else
            "$SCRIPT_DIR/serversentry.sh" --periodic config force_report false
        fi
        ;;
    5)
        echo -e "\n${BLUE}Schedule specific days of the week:${NC}"
        echo -e "Enter days as comma-separated list (1=Monday, 7=Sunday)"
        echo -e "Example: 1,3,5 for Monday, Wednesday, Friday"
        echo -e "Leave empty to run every day"
        echo ""
        read -p "Enter days: " days

        if [ -n "$days" ]; then
            "$SCRIPT_DIR/serversentry.sh" --periodic config report_days "$days"

            echo -e "\n${BLUE}Set time of day (24-hour format, UTC):${NC}"
            read -p "Enter time (HH:MM): " time

            if [ -n "$time" ]; then
                "$SCRIPT_DIR/serversentry.sh" --periodic config report_time "$time"
            fi
        else
            # Empty days - clear the schedule
            "$SCRIPT_DIR/serversentry.sh" --periodic config report_days ""
            "$SCRIPT_DIR/serversentry.sh" --periodic config report_time ""
        fi
        ;;
    6)
        echo -e "\n${BLUE}Cron Job Setup${NC}"
        echo -e "This will show example cron entries for your installation."
        echo -e "You can copy and paste these into your crontab (crontab -e)."
        echo ""

        if [ -f "$SCRIPT_DIR/config/periodic_cron.template" ]; then
            cat "$SCRIPT_DIR/config/periodic_cron.template"
        else
            echo -e "${RED}Cron template file not found.${NC}"
        fi

        echo ""
        read -p "Would you like to add a cron job now? (y/n): " add_cron

        if [[ "$add_cron" =~ ^[Yy]$ ]]; then
            echo -e "\n${BLUE}Select cron schedule:${NC}"
            echo -e "1) Hourly (0 * * * *)"
            echo -e "2) Daily at 9 AM (0 9 * * *)"
            echo -e "3) Every 6 hours (0 */6 * * *)"
            echo -e "4) Weekdays at 9 AM (0 9 * * 1-5)"
            echo -e "5) Monday and Thursday at 9 AM (0 9 * * 1,4)"
            echo -e "6) Custom"
            echo ""
            read -p "Select schedule (1-6): " cron_opt

            case "$cron_opt" in
            1) CRON_SCHED="0 * * * *" ;;
            2) CRON_SCHED="0 9 * * *" ;;
            3) CRON_SCHED="0 */6 * * *" ;;
            4) CRON_SCHED="0 9 * * 1-5" ;;
            5) CRON_SCHED="0 9 * * 1,4" ;;
            6)
                read -p "Enter custom cron schedule: " custom_sched
                CRON_SCHED="$custom_sched"
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                return
                ;;
            esac

            # Create cron entry
            CRON_ENTRY="$CRON_SCHED $SCRIPT_DIR/serversentry.sh --periodic run >> $SCRIPT_DIR/serversentry.log 2>&1"

            # Add to crontab
            (crontab -l 2>/dev/null || echo "") | {
                cat
                echo "$CRON_ENTRY"
            } | crontab -

            echo -e "${GREEN}Cron job has been added successfully!${NC}"
            echo "ServerSentry periodic reports will run: $CRON_SCHED"
        fi
        ;;
    7) return ;;
    *) echo -e "${RED}Invalid option${NC}" ;;
    esac

    # Pause before returning to the menu
    echo ""
    read -p "Press Enter to continue..." dummy
    setup_periodic_reports
}

# Configure log rotation
configure_log_rotation() {
    clear
    echo -e "${CYAN}┌───────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│             Configure Log Rotation                     │${NC}"
    echo -e "${CYAN}└───────────────────────────────────────────────────────┘${NC}"

    echo -e "\nLog rotation ensures log files don't grow too large and old logs are cleaned up."
    echo -e "This helps prevent disk space issues and makes log management easier.\n"

    # First ensure the config file exists
    "$SCRIPT_DIR/serversentry.sh" --logs status >/dev/null 2>&1

    echo -e "${BLUE}Current configuration:${NC}"
    "$SCRIPT_DIR/serversentry.sh" --logs status | grep -v "No archived logs found"
    echo ""

    # Let user select which settings to change
    echo -e "${BLUE}What would you like to configure?${NC}"
    echo -e "1) Maximum log file size before rotation"
    echo -e "2) Maximum age of log files to keep"
    echo -e "3) Maximum number of log files to keep"
    echo -e "4) Log compression settings"
    echo -e "5) Automatic rotation on startup"
    echo -e "6) Set up a cron job for log rotation"
    echo -e "7) Rotate logs now"
    echo -e "8) Return to main menu"

    echo ""
    read -p "Select option (1-8): " option

    case "$option" in
    1)
        echo -e "\n${BLUE}Set maximum log file size:${NC}"
        echo -e "Enter the maximum size in MB before log rotation occurs."
        echo -e "Set to 0 to disable size-based rotation."
        echo ""
        read -p "Enter size in MB (default: 10): " size

        if [[ "$size" =~ ^[0-9]+$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --logs config max_size_mb "$size"
            echo -e "${GREEN}Log rotation size updated to $size MB.${NC}"
        else
            echo -e "${RED}Invalid input. Please enter a number.${NC}"
        fi
        ;;
    2)
        echo -e "\n${BLUE}Set maximum log age:${NC}"
        echo -e "Enter the maximum age in days for log files to keep."
        echo -e "Logs older than this will be deleted during cleanup."
        echo -e "Set to 0 to disable age-based deletion."
        echo ""
        read -p "Enter age in days (default: 30): " age

        if [[ "$age" =~ ^[0-9]+$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --logs config max_age_days "$age"
            echo -e "${GREEN}Log retention period updated to $age days.${NC}"
        else
            echo -e "${RED}Invalid input. Please enter a number.${NC}"
        fi
        ;;
    3)
        echo -e "\n${BLUE}Set maximum number of log files:${NC}"
        echo -e "Enter the maximum number of archived log files to keep."
        echo -e "When this limit is exceeded, older logs will be deleted."
        echo -e "Set to 0 to keep all log files (not recommended)."
        echo ""
        read -p "Enter maximum files (default: 10): " files

        if [[ "$files" =~ ^[0-9]+$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --logs config max_files "$files"
            echo -e "${GREEN}Maximum log files updated to $files.${NC}"
        else
            echo -e "${RED}Invalid input. Please enter a number.${NC}"
        fi
        ;;
    4)
        echo -e "\n${BLUE}Log compression:${NC}"
        echo -e "Would you like to compress rotated log files?"
        echo -e "This saves disk space but requires gzip to be installed."
        echo ""
        read -p "Enable compression? (y/n): " compress

        if [[ "$compress" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --logs config compress true
            echo -e "${GREEN}Log compression enabled.${NC}"
        else
            "$SCRIPT_DIR/serversentry.sh" --logs config compress false
            echo -e "${GREEN}Log compression disabled.${NC}"
        fi
        ;;
    5)
        echo -e "\n${BLUE}Automatic rotation on startup:${NC}"
        echo -e "Should logs be rotated every time ServerSentry starts?"
        echo ""
        read -p "Enable rotation on startup? (y/n): " rotate

        if [[ "$rotate" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/serversentry.sh" --logs config rotate_on_start true
            echo -e "${GREEN}Log rotation on startup enabled.${NC}"
        else
            "$SCRIPT_DIR/serversentry.sh" --logs config rotate_on_start false
            echo -e "${GREEN}Log rotation on startup disabled.${NC}"
        fi
        ;;
    6)
        echo -e "\n${BLUE}Set up a cron job for log rotation:${NC}"
        echo -e "This will add a cron job to rotate logs automatically."
        echo ""
        read -p "Set up daily log rotation at midnight? (y/n): " setup_cron

        if [[ "$setup_cron" =~ ^[Yy]$ ]]; then
            # Create cron entry
            CRON_ENTRY="0 0 * * * $SCRIPT_DIR/serversentry.sh --logs rotate >> $SCRIPT_DIR/serversentry.log 2>&1"

            # Add to crontab
            (crontab -l 2>/dev/null || echo "") | {
                cat
                echo "$CRON_ENTRY"
            } | crontab -

            echo -e "${GREEN}Cron job has been added successfully!${NC}"
            echo "ServerSentry logs will be rotated daily at midnight."
        fi
        ;;
    7)
        echo -e "\n${BLUE}Rotating logs now...${NC}"
        "$SCRIPT_DIR/serversentry.sh" --logs rotate
        ;;
    8) return ;;
    *) echo -e "${RED}Invalid option${NC}" ;;
    esac

    # Pause before returning to the menu
    echo ""
    read -p "Press Enter to continue..." dummy
    configure_log_rotation
}

# Main menu for update case
update_menu() {
    while true; do
        clear

        # Header without system info
        echo -e "${CYAN}┌───────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│             ServerSentry Management                   │${NC}"
        echo -e "${CYAN}└───────────────────────────────────────────────────────┘${NC}"

        # Version info
        current_version=$(grep -m 1 "Version:" "$SCRIPT_DIR/serversentry.sh" | awk '{print $3}' 2>/dev/null || echo "Unknown")
        echo -e "\nServerSentry Version: ${GREEN}$current_version${NC}\n"

        # Menu options with icons and better formatting
        echo -e "${BLUE}Select an option:${NC}"
        echo -e "  ${GREEN}1)${NC} 🔄 ${CYAN}Update ServerSentry${NC}"
        echo -e "     ↳ Update and maintain core monitoring components"

        echo -e "  ${GREEN}2)${NC} ⏱️  ${CYAN}Manage Scheduled Tasks${NC}"
        echo -e "     ↳ Configure automated monitoring checks and alerts"

        echo -e "  ${GREEN}3)${NC} 👁️  ${CYAN}View Configuration${NC}"
        echo -e "     ↳ Inspect current thresholds, webhooks, and scheduled tasks"

        echo -e "  ${GREEN}4)${NC} 🔧 ${CYAN}Reset Configuration${NC}"
        echo -e "     ↳ Restore default settings for thresholds and webhooks"

        echo -e "  ${GREEN}5)${NC} 📚 ${CYAN}Usage Guide${NC}"
        echo -e "     ↳ Display available commands and usage examples"

        echo -e "  ${GREEN}6)${NC} 📋 ${CYAN}View Logs${NC}"
        echo -e "     ↳ Check recent monitoring logs and activity"

        echo -e "  ${GREEN}7)${NC} 🧪 ${CYAN}Run System Check${NC}"
        echo -e "     ↳ Perform a one-time system check now"

        echo -e "  ${GREEN}8)${NC} 📩 ${CYAN}Configure Periodic Reports${NC}"
        echo -e "     ↳ Set up automatic system reports via webhooks"

        echo -e "  ${GREEN}9)${NC} 🔄 ${CYAN}Configure Log Rotation${NC}"
        echo -e "     ↳ Manage log file rotation and cleanup"

        echo -e "  ${GREEN}10)${NC} 🚪 ${CYAN}Exit${NC}"
        echo -e "     ↳ Close this management interface"

        echo ""
        read -p "Enter your choice (1-10): " option

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
                sleep 2
            fi
            ;;
        5) print_usage ;;
        6)
            echo -e "\n${CYAN}Recent Log Entries:${NC}"
            if [ -f "$SCRIPT_DIR/serversentry.log" ]; then
                tail -n 20 "$SCRIPT_DIR/serversentry.log"
            else
                echo -e "${YELLOW}No log file found at $SCRIPT_DIR/serversentry.log${NC}"
            fi
            echo ""
            read -p "Press Enter to continue..." dummy
            ;;
        7)
            echo -e "\n${CYAN}Running system check...${NC}\n"
            "$SCRIPT_DIR/serversentry.sh" --check
            echo ""
            read -p "Press Enter to continue..." dummy
            ;;
        8) setup_periodic_reports ;;
        9) configure_log_rotation ;;
        10) exit 0 ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-10.${NC}"
            sleep 2
            ;;
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
    1)
        install_serversentry
        print_usage
        ;;
    2) exit 0 ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
    esac
}

# Main execution logic
if $is_update; then
    update_menu
else
    install_menu
fi

exit 0
