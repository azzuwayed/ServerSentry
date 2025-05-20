#!/bin/bash
#
# SysMon - System Monitoring Tool
# Main script that handles CLI and orchestrates the monitoring processes

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source the required libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/monitor.sh"
source "$SCRIPT_DIR/lib/notify.sh"

# Initialize log file if it doesn't exist
LOG_FILE="$SCRIPT_DIR/sysmon.log"
touch "$LOG_FILE" 2>/dev/null || {
    echo "Error: Cannot create log file at $LOG_FILE. Check permissions."
    exit 1
}

# Command-line argument handling
show_help() {
    echo "SysMon - System Monitoring Tool"
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
    
    # Run all checks
    check_cpu
    check_memory
    check_disk
    check_processes
    
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
    get_cpu_usage
    local cpu_usage=$RESULT
    echo "Current CPU usage: $cpu_usage%"
    
    get_memory_usage
    local memory_usage=$RESULT
    echo "Current memory usage: $memory_usage%"
    
    get_disk_usage
    local disk_usage=$RESULT
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
    
    # Test each webhook
    for i in "${!WEBHOOKS[@]}"; do
        echo "Testing webhook #$i: ${WEBHOOKS[$i]}"
        send_webhook_notification "${WEBHOOKS[$i]}" "Test" "This is a test notification from SysMon"
    done
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
