#!/bin/bash
#
# ServerSentry - Periodic System Checks Module
# This module handles scheduled system checks and reporting
#
# QUICKSTART: To test periodic reporting with curl:
#
# 1. First set up a webhook (e.g., webhook.site for testing)
#    ./serversentry.sh --add-webhook https://webhook.site/your-unique-id
#
# 2. Configure reporting level:
#    ./serversentry.sh --periodic config report_level detailed
#    ./serversentry.sh --periodic config force_report true
#
# 3. Run a check manually:
#    ./serversentry.sh --periodic run
#
# 4. Schedule with cron (optional):
#    (crontab -l 2>/dev/null; echo "0 * * * * $(pwd)/serversentry.sh --periodic run") | crontab -
#
# See the README.md and documentation for more customization options.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source paths module and utilities
source "$SCRIPT_DIR/../utils/paths.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Get the project root
PROJECT_ROOT="$(get_project_root)"

# Source required modules
source "$PROJECT_ROOT/lib/config/config_manager.sh"
source "$PROJECT_ROOT/lib/monitor/monitor.sh"
source "$PROJECT_ROOT/lib/notify/main.sh"

# Configuration files using standardized paths
PERIODIC_CONFIG_FILE="$(get_file_path "periodic")"
REPORT_HISTORY_FILE="$PROJECT_ROOT/config/report_history.json"

# Default configuration
DEFAULT_REPORT_INTERVAL=86400  # 24 hours in seconds
DEFAULT_REPORT_LEVEL="summary" # Options: summary, detailed, minimal
DEFAULT_REPORT_CHECKS="cpu,memory,disk,processes"
DEFAULT_FORCE_REPORT="false" # Whether to send report even if no issues found

# Create periodic config file if it doesn't exist
ensure_periodic_config() {
    if [ ! -f "$PERIODIC_CONFIG_FILE" ]; then
        log_message "INFO" "Creating default periodic report configuration"
        ensure_dir_exists "$(dirname "$PERIODIC_CONFIG_FILE")"
        cat >"$PERIODIC_CONFIG_FILE" <<EOF
# ServerSentry Periodic Reports Configuration
# This file controls automatic system checks and reporting

# Time between reports in seconds 
# 3600 = hourly, 86400 = daily, 604800 = weekly
report_interval=$DEFAULT_REPORT_INTERVAL

# Report detail level (summary, detailed, minimal)
report_level=$DEFAULT_REPORT_LEVEL

# System aspects to check (comma-separated)
# Options: cpu, memory, disk, load, processes, network, all
report_checks=$DEFAULT_REPORT_CHECKS

# Force send reports even when no issues detected (true/false)
force_report=$DEFAULT_FORCE_REPORT

# Time to run daily reports (24-hour format, UTC)
# Set to empty to use intervals from last report instead
report_time=09:00

# Days of week to send reports (comma-separated, 1=Monday, 7=Sunday)
# Set to empty to send reports based on interval regardless of day
report_days=1,4

# Custom report title (leave empty for default)
report_title=

# End of configuration
EOF
    fi
}

# Load periodic check configuration
load_periodic_config() {
    ensure_periodic_config

    if [ -f "$PERIODIC_CONFIG_FILE" ]; then
        # Load configuration with defaults as fallbacks
        REPORT_INTERVAL=$(grep -E "^report_interval=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_REPORT_INTERVAL")
        REPORT_LEVEL=$(grep -E "^report_level=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_REPORT_LEVEL")
        REPORT_CHECKS=$(grep -E "^report_checks=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_REPORT_CHECKS")
        FORCE_REPORT=$(grep -E "^force_report=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_FORCE_REPORT")
        REPORT_TIME=$(grep -E "^report_time=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "")
        REPORT_DAYS=$(grep -E "^report_days=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "")
        REPORT_TITLE=$(grep -E "^report_title=" "$PERIODIC_CONFIG_FILE" | cut -d= -f2 || echo "")

        log_message "INFO" "Loaded periodic check configuration"
    else
        log_message "WARNING" "Periodic check configuration not found, using defaults"
        REPORT_INTERVAL="$DEFAULT_REPORT_INTERVAL"
        REPORT_LEVEL="$DEFAULT_REPORT_LEVEL"
        REPORT_CHECKS="$DEFAULT_REPORT_CHECKS"
        FORCE_REPORT="$DEFAULT_FORCE_REPORT"
        REPORT_TIME=""
        REPORT_DAYS=""
        REPORT_TITLE=""
    fi
}

# Update a specific periodic check configuration parameter
update_periodic_parameter() {
    local param="$1"
    local value="$2"

    ensure_periodic_config

    # Validate parameters
    case "$param" in
    report_interval)
        # Validate is a positive number
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            log_message "ERROR" "Invalid report interval: $value (must be a positive number)"
            return 1
        fi
        ;;
    report_level)
        # Validate is one of allowed values
        if ! [[ "$value" =~ ^(summary|detailed|minimal)$ ]]; then
            log_message "ERROR" "Invalid report level: $value (must be summary, detailed, or minimal)"
            return 1
        fi
        ;;
    report_checks)
        # Validate contains only allowed check types
        local valid_checks="cpu,memory,disk,load,processes,network,all"
        # Split by comma and check each value
        IFS=',' read -ra CHECKS <<<"$value"
        for check in "${CHECKS[@]}"; do
            if ! [[ "$valid_checks" == *"$check"* ]]; then
                log_message "ERROR" "Invalid check type: $check (allowed: cpu, memory, disk, load, processes, network, all)"
                return 1
            fi
        done
        ;;
    force_report)
        # Validate is boolean
        if ! [[ "$value" =~ ^(true|false)$ ]]; then
            log_message "ERROR" "Invalid value for force_report: $value (must be true or false)"
            return 1
        fi
        ;;
    report_time)
        # Validate time format or empty
        if [ -n "$value" ] && ! [[ "$value" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            log_message "ERROR" "Invalid time format: $value (must be HH:MM in 24-hour format)"
            return 1
        fi
        ;;
    report_days)
        # Validate days format or empty
        if [ -n "$value" ]; then
            IFS=',' read -ra DAYS <<<"$value"
            for day in "${DAYS[@]}"; do
                if ! [[ "$day" =~ ^[1-7]$ ]]; then
                    log_message "ERROR" "Invalid day: $day (must be 1-7, where 1=Monday)"
                    return 1
                fi
            done
        fi
        ;;
    report_title)
        # No validation needed
        ;;
    *)
        log_message "ERROR" "Unknown parameter: $param"
        return 1
        ;;
    esac

    # Update the configuration file
    if grep -q "^$param=" "$PERIODIC_CONFIG_FILE"; then
        # Parameter exists, update it
        sed -i.bak "s/^$param=.*/$param=$value/" "$PERIODIC_CONFIG_FILE"
    else
        # Parameter doesn't exist, add it
        echo "$param=$value" >>"$PERIODIC_CONFIG_FILE"
    fi

    log_message "INFO" "Updated $param to $value"
    return 0
}

# Check if it's time to send a periodic report
should_send_report() {
    local now=$(date +%s)

    # Initialize history file if it doesn't exist
    if [ ! -f "$REPORT_HISTORY_FILE" ]; then
        echo '{"last_report": 0, "report_count": 0}' >"$REPORT_HISTORY_FILE"
    fi

    # Get last report time
    local last_report=$(grep -o '"last_report":[0-9]*' "$REPORT_HISTORY_FILE" | cut -d: -f2)
    if [ -z "$last_report" ]; then
        last_report=0
    fi

    # Check if specific time is set and due today
    if [ -n "$REPORT_TIME" ]; then
        # Get current date in YYYY-MM-DD format
        local today=$(date +%Y-%m-%d)

        # Get current day of week (1-7, where 1 is Monday)
        local day_of_week=$(date +%u)

        # Check if day-of-week restriction is in place
        if [ -n "$REPORT_DAYS" ]; then
            if ! [[ "$REPORT_DAYS" == *"$day_of_week"* ]]; then
                # Not a reporting day
                return 1
            fi
        fi

        # Extract hour and minute from the report time
        local hour=$(echo "$REPORT_TIME" | cut -d: -f1)
        local minute=$(echo "$REPORT_TIME" | cut -d: -f2)

        # Convert report time to Unix timestamp
        local report_time=$(date -d "$today $hour:$minute:00" +%s 2>/dev/null ||
            date -j -f "%Y-%m-%d %H:%M:%S" "$today $hour:$minute:00" +%s 2>/dev/null)

        # Check if we already reported today
        local last_report_date=$(date -d "@$last_report" +%Y-%m-%d 2>/dev/null ||
            date -r "$last_report" +%Y-%m-%d 2>/dev/null)

        if [ "$today" = "$last_report_date" ]; then
            # Already reported today
            return 1
        fi

        # Check if the scheduled time has passed for today
        if [ "$now" -ge "$report_time" ]; then
            return 0
        else
            return 1
        fi
    fi

    # Simple interval check if no specific time set
    local time_since_last=$((now - last_report))
    if [ "$time_since_last" -ge "$REPORT_INTERVAL" ]; then
        return 0
    else
        return 1
    fi
}

# Update the report history after sending a report
update_report_history() {
    local now=$(date +%s)

    # Initialize history file if it doesn't exist
    if [ ! -f "$REPORT_HISTORY_FILE" ]; then
        echo '{"last_report": '"$now"', "report_count": 1}' >"$REPORT_HISTORY_FILE"
        return
    fi

    # Get current report count
    local report_count=$(grep -o '"report_count":[0-9]*' "$REPORT_HISTORY_FILE" | cut -d: -f2)
    if [ -z "$report_count" ]; then
        report_count=0
    fi

    # Increment report count
    report_count=$((report_count + 1))

    # Update history file
    echo '{"last_report": '"$now"', "report_count": '$report_count'}' >"$REPORT_HISTORY_FILE"
}

# Generate a system report based on report level and checks
generate_system_report() {
    local title=""
    local message=""
    local issues_found=false

    # Set report title
    if [ -n "$REPORT_TITLE" ]; then
        title="$REPORT_TITLE"
    else
        title="ServerSentry Periodic System Report"
    fi

    # Add report header
    local hostname=$(hostname)
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="System report for $hostname at $timestamp\n\n"

    # Determine which checks to run
    local run_cpu=false
    local run_memory=false
    local run_disk=false
    local run_load=false
    local run_processes=false
    local run_network=false

    if [[ "$REPORT_CHECKS" == *"all"* ]]; then
        run_cpu=true
        run_memory=true
        run_disk=true
        run_load=true
        run_processes=true
        run_network=true
    else
        [[ "$REPORT_CHECKS" == *"cpu"* ]] && run_cpu=true
        [[ "$REPORT_CHECKS" == *"memory"* ]] && run_memory=true
        [[ "$REPORT_CHECKS" == *"disk"* ]] && run_disk=true
        [[ "$REPORT_CHECKS" == *"load"* ]] && run_load=true
        [[ "$REPORT_CHECKS" == *"processes"* ]] && run_processes=true
        [[ "$REPORT_CHECKS" == *"network"* ]] && run_network=true
    fi

    # CPU check
    if [ "$run_cpu" = true ]; then
        local cpu_usage=$(get_cpu_usage)

        if [ "$REPORT_LEVEL" = "detailed" ] || [ "$REPORT_LEVEL" = "summary" ]; then
            message+="📊 CPU Usage: $cpu_usage% (threshold: $CPU_THRESHOLD%)\n"

            if [ "${cpu_usage:-0}" -ge "${CPU_THRESHOLD:-80}" ]; then
                issues_found=true
                message+="⚠️ CPU usage is above threshold!\n"

                if [ "$REPORT_LEVEL" = "detailed" ]; then
                    message+="\nTop CPU processes:\n"
                    message+="$(get_top_cpu_processes 5)\n"
                fi
            fi

            message+="\n"
        elif [ "$REPORT_LEVEL" = "minimal" ] && [ "${cpu_usage:-0}" -ge "${CPU_THRESHOLD:-80}" ]; then
            issues_found=true
            message+="⚠️ CPU Alert: $cpu_usage%\n"
        fi
    fi

    # Memory check
    if [ "$run_memory" = true ]; then
        local memory_usage=$(get_memory_usage)

        if [ "$REPORT_LEVEL" = "detailed" ] || [ "$REPORT_LEVEL" = "summary" ]; then
            message+="📊 Memory Usage: $memory_usage% (threshold: $MEMORY_THRESHOLD%)\n"

            if [ "${memory_usage:-0}" -ge "${MEMORY_THRESHOLD:-80}" ]; then
                issues_found=true
                message+="⚠️ Memory usage is above threshold!\n"

                if [ "$REPORT_LEVEL" = "detailed" ]; then
                    message+="\nTop memory processes:\n"
                    message+="$(get_top_memory_processes 5)\n"
                fi
            fi

            message+="\n"
        elif [ "$REPORT_LEVEL" = "minimal" ] && [ "${memory_usage:-0}" -ge "${MEMORY_THRESHOLD:-80}" ]; then
            issues_found=true
            message+="⚠️ Memory Alert: $memory_usage%\n"
        fi
    fi

    # Disk check
    if [ "$run_disk" = true ]; then
        local disk_usage=$(get_disk_usage)

        if [ "$REPORT_LEVEL" = "detailed" ] || [ "$REPORT_LEVEL" = "summary" ]; then
            message+="📊 Disk Usage: $disk_usage% (threshold: $DISK_THRESHOLD%)\n"

            if [ "${disk_usage:-0}" -ge "${DISK_THRESHOLD:-85}" ]; then
                issues_found=true
                message+="⚠️ Disk usage is above threshold!\n"

                if [ "$REPORT_LEVEL" = "detailed" ] && command_exists du; then
                    message+="\nLargest directories:\n"
                    if [[ "$(uname)" == "Darwin" ]]; then
                        # macOS specific
                        message+="$(du -h /var /tmp /Users 2>/dev/null | sort -hr | head -n 5)\n"
                    else
                        # Linux
                        message+="$(du -h /var /tmp /home 2>/dev/null | sort -hr | head -n 5)\n"
                    fi
                fi
            fi

            message+="\n"
        elif [ "$REPORT_LEVEL" = "minimal" ] && [ "${disk_usage:-0}" -ge "${DISK_THRESHOLD:-85}" ]; then
            issues_found=true
            message+="⚠️ Disk Alert: $disk_usage%\n"
        fi
    fi

    # Process checks
    if [ "$run_processes" = true ] && [ -n "$PROCESS_CHECKS" ]; then
        local failed_processes=""
        local monitored_count=0
        local failed_count=0

        IFS=',' read -ra PROCESSES <<<"$PROCESS_CHECKS"
        for process in "${PROCESSES[@]}"; do
            process=$(echo "$process" | xargs)
            if [ -z "$process" ]; then continue; fi

            monitored_count=$((monitored_count + 1))

            if ! check_process_running "$process"; then
                failed_count=$((failed_count + 1))
                issues_found=true
                failed_processes+="- $process\n"
            fi
        done

        if [ "$REPORT_LEVEL" = "detailed" ] || [ "$REPORT_LEVEL" = "summary" ]; then
            message+="📊 Process Monitoring: $monitored_count processes checked\n"

            if [ "$failed_count" -gt 0 ]; then
                message+="⚠️ $failed_count processes not running:\n$failed_processes"
            else
                message+="✅ All monitored processes are running\n"
            fi

            message+="\n"
        elif [ "$REPORT_LEVEL" = "minimal" ] && [ "$failed_count" -gt 0 ]; then
            message+="⚠️ Process Alert: $failed_count processes not running\n"
        fi
    fi

    # Return values
    if [ "$issues_found" = true ] || [ "$FORCE_REPORT" = "true" ]; then
        echo "$title"
        echo "$message"
        return 0
    else
        # No issues found and force_report is false
        return 1
    fi
}

# Run a periodic check and send report if needed
run_periodic_check() {
    # Load configurations
    load_thresholds
    load_webhooks
    load_periodic_config

    # Check if it's time to send a report
    if should_send_report; then
        log_message "INFO" "Running periodic system check"

        # Generate system report
        local report_title=$(generate_system_report)
        local exit_code=$?
        local report_message=$(generate_system_report | tail -n +2)

        # Send report if needed
        if [ $exit_code -eq 0 ]; then
            # Check if any webhooks are configured
            if [ ${#WEBHOOKS[@]} -eq 0 ]; then
                log_message "WARNING" "No webhooks configured for periodic report"
                return 2
            fi

            log_message "INFO" "Sending periodic system report"

            # Send to all configured webhooks
            local success_count=0
            for webhook in "${WEBHOOKS[@]}"; do
                if send_webhook_notification "$webhook" "$report_title" "$report_message"; then
                    success_count=$((success_count + 1))
                fi
            done

            # Update report history only if at least one notification was sent
            if [ $success_count -gt 0 ]; then
                update_report_history
                log_message "INFO" "Periodic report sent to $success_count webhooks"
                return 0
            else
                log_message "ERROR" "Failed to send periodic report to any webhooks"
                return 1
            fi
        else
            log_message "INFO" "No issues found and force_report disabled - skipping report"
            return 0
        fi
    else
        log_message "DEBUG" "Not time for periodic report yet"
        return 0
    fi
}

# Show status of periodic checks
show_periodic_status() {
    load_periodic_config

    echo ""
    echo "Periodic Checks Configuration:"
    echo "-----------------------------"

    # Format interval in human-readable format
    local interval_human=""
    if [ "$REPORT_INTERVAL" -lt 3600 ]; then
        # Less than an hour - show minutes
        interval_human="$(($REPORT_INTERVAL / 60)) minutes"
    elif [ "$REPORT_INTERVAL" -lt 86400 ]; then
        # Less than a day - show hours
        interval_human="$(($REPORT_INTERVAL / 3600)) hours"
    else
        # Days
        interval_human="$(($REPORT_INTERVAL / 86400)) days"
    fi

    if [ -n "$REPORT_TIME" ]; then
        if [ -n "$REPORT_DAYS" ]; then
            local days_text=""
            local days=()
            IFS=',' read -ra days_array <<<"$REPORT_DAYS"
            for day in "${days_array[@]}"; do
                case "$day" in
                1) days+=("Monday") ;;
                2) days+=("Tuesday") ;;
                3) days+=("Wednesday") ;;
                4) days+=("Thursday") ;;
                5) days+=("Friday") ;;
                6) days+=("Saturday") ;;
                7) days+=("Sunday") ;;
                esac
            done
            days_text=$(printf ", %s" "${days[@]}")
            days_text=${days_text:2} # Remove leading comma and space

            echo "Schedule: Daily at $REPORT_TIME UTC on $days_text"
        else
            echo "Schedule: Daily at $REPORT_TIME UTC"
        fi
    else
        echo "Interval: Every $interval_human"
    fi

    echo "Report level: $REPORT_LEVEL"
    echo "Checks included: $REPORT_CHECKS"
    echo "Force reports: $FORCE_REPORT"

    # Show report history
    if [ -f "$REPORT_HISTORY_FILE" ]; then
        local last_report=$(grep -o '"last_report":[0-9]*' "$REPORT_HISTORY_FILE" | cut -d: -f2)
        local report_count=$(grep -o '"report_count":[0-9]*' "$REPORT_HISTORY_FILE" | cut -d: -f2)

        if [ -n "$last_report" ] && [ "$last_report" -gt 0 ]; then
            # Format last report time
            local last_report_date=$(date -d "@$last_report" +"%Y-%m-%d %H:%M:%S" 2>/dev/null ||
                date -r "$last_report" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

            # Calculate next report time
            local next_report=0

            if [ -n "$REPORT_TIME" ]; then
                # Next report is at the specified time on the next applicable day
                local today=$(date +%Y-%m-%d)
                local hour=$(echo "$REPORT_TIME" | cut -d: -f1)
                local minute=$(echo "$REPORT_TIME" | cut -d: -f2)

                # Get tomorrow's date
                local tomorrow=$(date -d "$today + 1 day" +%Y-%m-%d 2>/dev/null ||
                    date -v+1d -j -f "%Y-%m-%d" "$today" +%Y-%m-%d 2>/dev/null)

                # Convert to Unix timestamp
                next_report=$(date -d "$tomorrow $hour:$minute:00" +%s 2>/dev/null ||
                    date -j -f "%Y-%m-%d %H:%M:%S" "$tomorrow $hour:$minute:00" +%s 2>/dev/null)
            else
                # Next report is current interval after the last one
                next_report=$((last_report + REPORT_INTERVAL))
            fi

            # Format next report time
            local next_report_date=$(date -d "@$next_report" +"%Y-%m-%d %H:%M:%S" 2>/dev/null ||
                date -r "$next_report" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

            echo "Last report: $last_report_date"
            echo "Next report: $next_report_date (approximately)"
            echo "Reports sent: $report_count"
        else
            echo "No reports sent yet"
        fi
    else
        echo "No report history available"
    fi

    echo ""
}

# Main function for periodic module
periodic_main() {
    local command="$1"
    shift

    case "$command" in
    run)
        run_periodic_check
        ;;
    status)
        show_periodic_status
        ;;
    config)
        if [ $# -ge 2 ]; then
            update_periodic_parameter "$1" "$2"
        else
            echo "Usage: periodic config <parameter> <value>"
            return 1
        fi
        ;;
    *)
        echo "Unknown periodic command: $command"
        echo "Available commands: run, status, config"
        return 1
        ;;
    esac

    return 0
}
