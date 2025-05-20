#!/bin/bash
#
# ServerSentry - Enhanced System Monitoring & Alert Tool
# Combines the best of the original enhanced-sysmon.sh with the modularity of serversentry.sh
#
# This tool monitors system resources (CPU, memory, disk) and sends
# webhook notifications when thresholds are exceeded.
# 
# Features:
# - Cross-environment compatibility
# - Robust monitoring functions
# - Modular architecture
# - Comprehensive alerting
#
# Author: ServerSentry Team
# Version: 1.1.0
# License: MIT

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Global configuration files
LOG_FILE="$SCRIPT_DIR/serversentry.log"
CONFIG_DIR="$SCRIPT_DIR/config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
WEBHOOKS_FILE="$CONFIG_DIR/webhooks.conf"

# Default thresholds (will be overridden by config files)
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
CHECK_INTERVAL=60
PROCESS_CHECKS=""

# Webhooks array
declare -a WEBHOOKS

# Create lib directory if it doesn't exist
if [ ! -d "$SCRIPT_DIR/lib" ]; then
    mkdir -p "$SCRIPT_DIR/lib"
    echo "Created library directory at $SCRIPT_DIR/lib"
    echo "Please ensure library files are present before running again."
    exit 1
fi

# Source the modular library files
if [ ! -f "$SCRIPT_DIR/lib/utils.sh" ] || 
   [ ! -f "$SCRIPT_DIR/lib/config.sh" ] || 
   [ ! -f "$SCRIPT_DIR/lib/monitor.sh" ] || 
   [ ! -f "$SCRIPT_DIR/lib/notify.sh" ]; then
    echo "Error: Required library files not found. Please reinstall the application."
    echo "Missing one or more of: utils.sh, config.sh, monitor.sh, notify.sh"
    exit 1
fi

# Source library files
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/monitor.sh"
source "$SCRIPT_DIR/lib/notify.sh"

# Initialize log file if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || {
    echo "Error: Cannot create log file at $LOG_FILE. Check permissions."
    exit 1
}

# Command-line argument handling
show_help() {
    echo "ServerSentry - Enhanced System Monitoring & Alert Tool"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -c, --check            Perform a one-time system check"
    echo "  -m, --monitor          Start monitoring (foreground process)"
    echo "  -s, --status           Show current status and configuration"
    echo "  -t, --test-webhook     Test webhook notifications"
    echo "  -a, --add-webhook URL  Add a new webhook endpoint"
    echo "  -r, --remove-webhook N Remove webhook number N"
    echo "  -u, --update N=VALUE   Update threshold (e.g., cpu_threshold=85)"
    echo "  -l, --list             List all thresholds and webhooks"
    echo ""
    echo "Examples:"
    echo "  $0 --check                  # Run a one-time check"
    echo "  $0 --update cpu_threshold=90 # Set CPU threshold to 90%"
    echo "  $0 --add-webhook https://example.com/webhook # Add webhook endpoint"
}

run_check() {
    log_message "INFO" "Running one-time system check"
    
    # Load config
    load_thresholds
    load_webhooks
    
    # Define color codes for terminal output
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    
    # Function to create a visual progress bar
    create_visual_bar() {
        local usage=$1
        local threshold=$2
        local width=20
        local filled=$(( usage * width / 100 ))
        local bar="["
        
        for ((i=0; i<width; i++)); do
            if [ $i -lt $filled ]; then
                bar+="#"
            else
                bar+="-"
            fi
        done
        
        bar+="] $usage%"
        echo "$bar"
    }
    
    # Function to add color based on threshold
    colorize_metric() {
        local value=$1
        local threshold=$2
        local warn_threshold=$((threshold - 20))
        local text=$3
        local bar=$(create_visual_bar "$value" "$threshold")
        
        if [ "$value" -ge "$threshold" ]; then
            echo -e "${RED}$text ${bar} ${RED}⚠️  ALERT: Above threshold ($threshold%)${NC}"
        elif [ "$value" -ge "$warn_threshold" ]; then
            echo -e "${YELLOW}$text ${bar} ${YELLOW}⚡ WARNING: Approaching threshold${NC}"
        else
            echo -e "${GREEN}$text ${bar} ${GREEN}✅ NORMAL${NC}"
        fi
    }
    
    # Get and display current resource usage with visual indicators
    local cpu_usage=$(get_cpu_usage)
    colorize_metric "$cpu_usage" "${CPU_THRESHOLD}" "🖥️  CPU usage:"
    
    local memory_usage=$(get_memory_usage)
    colorize_metric "$memory_usage" "${MEMORY_THRESHOLD}" "🧠 Memory usage:"
    
    local disk_usage=$(get_disk_usage)
    colorize_metric "$disk_usage" "${DISK_THRESHOLD}" "💾 Disk usage:"
    
    echo -e "\n${CYAN}=== System Information ===${NC}"
    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}OS:${NC} $(uname -a)"
    echo -e "${CYAN}Uptime:${NC} $(uptime)"
    
    # Run threshold checks and show details when thresholds are exceeded
    if [ "${cpu_usage:-0}" -ge "${CPU_THRESHOLD:-80}" ] 2>/dev/null; then
        echo -e "\n${RED}⚠️ CPU ALERT: Usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%${NC}"
        echo -e "${CYAN}Top CPU consumers:${NC}"
        get_top_cpu_processes 5
    fi
    
    if [ "${memory_usage:-0}" -ge "${MEMORY_THRESHOLD:-80}" ] 2>/dev/null; then
        echo -e "\n${RED}⚠️ MEMORY ALERT: Usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%${NC}"
        echo -e "${CYAN}Top memory consumers:${NC}"
        get_top_memory_processes 5
    fi
    
    if [ "${disk_usage:-0}" -ge "${DISK_THRESHOLD:-85}" ] 2>/dev/null; then
        echo -e "\n${RED}⚠️ DISK ALERT: Usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%${NC}"
        echo -e "${CYAN}Largest directories:${NC}"
        if command_exists du; then
            du -h /var /tmp /Users 2>/dev/null | sort -hr | head -n 5
        fi
    fi
    
    # Check monitored processes
    if [ -n "$PROCESS_CHECKS" ]; then
        echo "Process checks:"
        IFS=',' read -ra PROCESSES <<< "$PROCESS_CHECKS"
        for process in "${PROCESSES[@]}"; do
            process=$(echo "$process" | xargs)
            if [ -z "$process" ]; then continue; fi
            
            if check_process_running "$process"; then
                echo "  ✓ $process is running"
            else
                echo "  ✗ $process is NOT running"
            fi
        done
    fi
    
    log_message "INFO" "One-time check completed"
}

start_monitor() {
    log_message "INFO" "Starting system monitoring in foreground"
    
    # Load config
    load_thresholds
    load_webhooks
    
    # Print current configuration
    print_config
    
    echo "Press Ctrl+C to stop monitoring..."
    
    # Continuous monitoring loop
    while true; do
        check_cpu
        check_memory
        check_disk
        check_processes
        
        # Sleep for the configured interval
        sleep "$CHECK_INTERVAL"
    done
}

show_status() {
    log_message "INFO" "Showing current system status"
    
    # Load config
    load_thresholds
    load_webhooks
    
    # Print current configuration
    print_config
    
    # Show current resource usage
    local cpu_usage=$(get_cpu_usage)
    echo "Current CPU usage: $cpu_usage%"
    
    local memory_usage=$(get_memory_usage)
    echo "Current memory usage: $memory_usage%"
    
    local disk_usage=$(get_disk_usage)
    echo "Current disk usage: $disk_usage%"
}

test_webhook() {
    log_message "INFO" "Testing webhook notifications"
    
    # Load webhooks
    load_webhooks
    
    if [ ${#WEBHOOKS[@]} -eq 0 ]; then
        echo "Error: No webhooks configured. Add one with --add-webhook"
        exit 1
    fi
    
    # Get current system stats for a more useful test
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    
    # Create comprehensive test message with color formatting
    local test_message="ServerSentry test notification with current status overview:

System Resources:
CPU Usage: ${cpu_usage}% 
Memory Usage: ${memory_usage}%
Disk Usage: ${disk_usage}%

This is a test alert to verify proper webhook configuration and Teams integration. The notification includes comprehensive system information and is formatted for optimal display in Microsoft Teams.

For more information on configuring Teams with ServerSentry, see the TEAMS_SETUP.md guide."
    
    # Show what we're sending
    echo "Sending test alert to all configured webhooks..."
    echo "Current system stats:"
    echo "- CPU: ${cpu_usage}%"
    echo "- Memory: ${memory_usage}%"
    echo "- Disk: ${disk_usage}%"
    
    # Test each webhook
    for i in "${!WEBHOOKS[@]}"; do
        echo "Testing webhook #$i: ${WEBHOOKS[$i]}"
        echo "Sending detailed system information and adaptive card..."
        send_webhook_notification "${WEBHOOKS[$i]}" "ServerSentry System Test" "$test_message"
        
        # Brief delay to avoid throttling
        sleep 1
    done
    
    echo "Test complete. Please check your notification channels."
    echo "If using Microsoft Teams, you should see an adaptive card with detailed system information."
}

# Main execution logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Process command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            run_check
            exit 0
            ;;
        -m|--monitor)
            start_monitor
            exit 0
            ;;
        -s|--status)
            show_status
            exit 0
            ;;
        -t|--test-webhook)
            test_webhook
            exit 0
            ;;
        -a|--add-webhook)
            if [ -z "$2" ]; then
                echo "Error: Webhook URL is required"
                exit 1
            fi
            add_webhook "$2"
            echo "Webhook added: $2"
            shift
            ;;
        -r|--remove-webhook)
            if [ -z "$2" ]; then
                echo "Error: Webhook index is required"
                exit 1
            fi
            remove_webhook "$2"
            echo "Webhook #$2 removed"
            shift
            ;;
        -u|--update)
            if [ -z "$2" ]; then
                echo "Error: Threshold value is required (e.g., cpu_threshold=85)"
                exit 1
            fi
            THRESHOLD_NAME=$(echo "$2" | cut -d= -f1)
            THRESHOLD_VALUE=$(echo "$2" | cut -d= -f2)
            update_threshold "$THRESHOLD_NAME" "$THRESHOLD_VALUE"
            echo "Updated $THRESHOLD_NAME to $THRESHOLD_VALUE"
            shift
            ;;
        -l|--list)
            load_thresholds
            load_webhooks
            print_config
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

exit 0