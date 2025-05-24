#!/bin/bash
#
# ServerSentry - Enhanced System Monitoring & Alert Tool
# A modular system resource monitoring and alerting tool
#
# Features:
# - Cross-environment compatibility
# - Robust monitoring functions
# - Modular architecture
# - Comprehensive alerting
#
# Author: ServerSentry Team
# Version: 1.2.0
# License: MIT

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Create home directory for ServerSentry
USER_HOME="$HOME/.serversentry"
mkdir -p "$USER_HOME" 2>/dev/null || {
    echo "Error: Cannot create directory at $USER_HOME. Check permissions."
    exit 1
}

# Source the path utilities first
source "$SCRIPT_DIR/lib/utils/paths.sh"

# Get standardized paths
PROJECT_ROOT="$(get_project_root)"
LOG_FILE="$USER_HOME/serversentry.log"

# Initialize log file
touch "$LOG_FILE" 2>/dev/null || {
    echo "Error: Cannot create log file at $LOG_FILE. Check permissions."
    exit 1
}

# Override log file path in environment for the utils module
export SERVERSENTRY_LOG_FILE="$LOG_FILE"

# Source required modules - core utilities only at this stage
source "$PROJECT_ROOT/lib/utils/utils.sh"

# Check for required library directory
if [ ! -d "$(get_dir_path "lib")" ]; then
    echo "Error: Required library directory not found. Please run the installer."
    exit 1
fi

# Perform log maintenance on every run
if [ -f "$(get_dir_path "lib")/log/logrotate.sh" ]; then
    source "$(get_dir_path "lib")/log/logrotate.sh"
    maintain_logs
fi

# Load CLI modules
source "$(get_dir_path "lib")/cli/utils.sh"
source "$(get_dir_path "lib")/cli/check.sh"
source "$(get_dir_path "lib")/cli/monitor.sh"
source "$(get_dir_path "lib")/cli/status.sh"
source "$(get_dir_path "lib")/cli/webhook.sh"
source "$(get_dir_path "lib")/cli/config.sh"
source "$(get_dir_path "lib")/cli/logs.sh"
source "$(get_dir_path "lib")/cli/periodic.sh"

# If no arguments, show help
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Process command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;

    -i | --interactive)
        cli_interactive
        exit $?
        ;;

    -c | --check)
        cli_check
        exit $?
        ;;

    -m | --monitor)
        cli_monitor
        exit $?
        ;;

    -s | --status)
        cli_status
        exit $?
        ;;

    -t | --test-webhook)
        cli_test_webhook
        exit $?
        ;;

    -a | --add-webhook)
        if [ -z "$2" ]; then
            echo "Error: Webhook URL is required"
            exit 1
        fi
        cli_add_webhook "$2"
        exit $?
        shift
        ;;

    -r | --remove-webhook)
        if [ -z "$2" ]; then
            echo "Error: Webhook index is required"
            exit 1
        fi
        cli_remove_webhook "$2"
        exit $?
        shift
        ;;

    -u | --update)
        if [ -z "$2" ]; then
            echo "Error: Threshold value is required (e.g., cpu_threshold=85)"
            exit 1
        fi
        cli_update "$2"
        exit $?
        shift
        ;;

    -l | --list)
        cli_list
        exit $?
        ;;

    --periodic)
        if [ -z "$2" ]; then
            echo "Error: Periodic command is required (run, status, config)"
            exit 1
        fi

        if [ "$2" = "config" ] && { [ -z "$3" ] || [ -z "$4" ]; }; then
            echo "Error: Parameter name and value required"
            echo "Usage: $0 --periodic config <parameter> <value>"
            echo "Parameters: report_interval, report_level, report_checks, force_report, report_time, report_days"
            exit 1
        fi

        cli_periodic "$2" "$3" "$4"
        exit $?
        shift 2
        ;;

    --logs)
        if [ -z "$2" ]; then
            echo "Error: Log command is required (status, rotate, clean, config)"
            exit 1
        fi

        if [ "$2" = "config" ] && { [ -z "$3" ] || [ -z "$4" ]; }; then
            echo "Error: Parameter name and value required"
            echo "Usage: $0 --logs config <parameter> <value>"
            echo "Parameters: max_size_mb, max_age_days, max_files, compress, rotate_on_start"
            exit 1
        fi

        cli_logs "$2" "$3" "$4"
        exit $?
        shift 2
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
