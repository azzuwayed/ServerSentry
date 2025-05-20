#!/bin/bash
#
# Enhanced SysMon - System Monitoring Tool
# A resilient system monitoring script that works across different environments

# Global variables
LOG_FILE="./sysmon.log"
THRESHOLDS_FILE="./thresholds.conf"
WEBHOOKS_FILE="./webhooks.conf"

# Default thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
CHECK_INTERVAL=60
PROCESS_CHECKS=""

# Webhooks array
declare -a WEBHOOKS

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # If it's an error or warning, also print to stderr
    if [ "$level" == "ERROR" ] || [ "$level" == "WARNING" ]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create a directory if it doesn't exist
ensure_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_message "ERROR" "Failed to create directory: $dir"
            return 1
        }
    fi
    return 0
}

# Initialize log file if it doesn't exist
initialize_log() {
    touch "$LOG_FILE" 2>/dev/null || {
        echo "Error: Cannot create log file at $LOG_FILE. Using stdout instead."
        LOG_FILE="/dev/stdout"
    }
}

# Check if a string is a number
is_number() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

# Check if a string is a valid URL
is_valid_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Print a horizontal line
print_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}

# Get CPU usage percentage - adaptable to different environments
get_cpu_usage() {
    local result=0
    
    if command_exists mpstat; then
        # Using mpstat (part of sysstat package)
        local cpu_idle=$(mpstat 1 1 | grep -A 5 "%idle" | tail -n 1 | awk '{print $NF}')
        result=$(awk -v idle="$cpu_idle" 'BEGIN {print 100 - idle}')
    elif command_exists top; then
        # Using top in batch mode
        local cpu_line=$(top -b -n 1 | grep -i '%cpu\|cpu(s)')
        local cpu_idle=""
        
        # Try to extract idle percentage using different patterns
        cpu_idle=$(echo "$cpu_line" | grep -o '[0-9.]*[% ]*id' | grep -o '[0-9.]*')
        
        if [ -z "$cpu_idle" ]; then
            # Try alternate format 
            cpu_idle=$(echo "$cpu_line" | awk '{for(i=1;i<=NF;i++) {if($i ~ /id|idle/) {print $(i-1)}}}' | grep -o '[0-9.]*')
        fi
        
        if [ -n "$cpu_idle" ]; then
            result=$(awk -v idle="$cpu_idle" 'BEGIN {print 100 - idle}')
        else
            # Last resort - try to parse the line differently
            local user=$(echo "$cpu_line" | grep -o '[0-9.]*[% ]*us' | grep -o '[0-9.]*')
            local system=$(echo "$cpu_line" | grep -o '[0-9.]*[% ]*sy' | grep -o '[0-9.]*')
            
            if [ -n "$user" ] && [ -n "$system" ]; then
                result=$(awk -v u="$user" -v s="$system" 'BEGIN {print u + s}')
            fi
        fi
    else
        # Fallback to /proc/stat
        local cpu_line1=$(grep '^cpu ' /proc/stat 2>/dev/null)
        if [ -n "$cpu_line1" ]; then
            sleep 1
            local cpu_line2=$(grep '^cpu ' /proc/stat)
            
            # Extract values
            local cpu1=($(echo "$cpu_line1" | awk '{$1=""; print $0}'))
            local cpu2=($(echo "$cpu_line2" | awk '{$1=""; print $0}'))
            
            # Calculate deltas
            local total1=0
            local total2=0
            local idle1=${cpu1[3]}
            local idle2=${cpu2[3]}
            
            for val in "${cpu1[@]}"; do
                total1=$((total1 + val))
            done
            
            for val in "${cpu2[@]}"; do
                total2=$((total2 + val))
            done
            
            local delta_total=$((total2 - total1))
            local delta_idle=$((idle2 - idle1))
            
            # Handle division by zero
            if [ "$delta_total" -gt 0 ]; then
                result=$(awk -v dt="$delta_total" -v di="$delta_idle" 'BEGIN {printf "%.1f", 100 * (1 - di/dt)}')
            fi
        fi
    fi
    
    # Round to integer and ensure it's a number
    result=$(printf "%.0f" "$result" 2>/dev/null || echo "$result" | awk '{printf "%.0f", $1}' 2>/dev/null || echo "0")
    if ! is_number "$result"; then
        result=0
    fi
    
    echo "$result"
}

# Get memory usage percentage - adaptable to different environments
get_memory_usage() {
    local result=0
    
    if command_exists free; then
        # Using free command
        local memory_info=$(free | grep Mem)
        local total=$(echo "$memory_info" | awk '{print $2}')
        
        # Try to get used memory directly
        local used=$(echo "$memory_info" | awk '{print $3}')
        
        # Handle different free output formats
        if [ -n "$total" ] && [ -n "$used" ] && [ "$total" -gt 0 ]; then
            result=$(awk -v t="$total" -v u="$used" 'BEGIN {printf "%.1f", 100 * u/t}')
        fi
    else
        # Fallback to /proc/meminfo
        if [ -f /proc/meminfo ]; then
            local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
            local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
            local cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
            
            # Calculate used memory
            if [ -n "$mem_total" ] && [ -n "$mem_free" ] && [ "$mem_total" -gt 0 ]; then
                local used=$((mem_total - mem_free - buffers - cached))
                result=$(awk -v t="$mem_total" -v u="$used" 'BEGIN {printf "%.1f", 100 * u/t}')
            fi
        fi
    fi
    
    # Round to integer and ensure it's a number
    result=$(printf "%.0f" "$result" 2>/dev/null || echo "$result" | awk '{printf "%.0f", $1}' 2>/dev/null || echo "0")
    if ! is_number "$result"; then
        result=0
    fi
    
    echo "$result"
}

# Get disk usage percentage - adaptable to different environments
get_disk_usage() {
    local result=0
    local mount_point="/"
    
    if [ -n "$1" ]; then
        mount_point="$1"
    fi
    
    if command_exists df; then
        # Using df command for specified partition
        local disk_info=$(df -P "$mount_point" 2>/dev/null | tail -n 1)
        local usage=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
        
        if is_number "$usage"; then
            result="$usage"
        else
            # Try alternate format
            usage=$(echo "$disk_info" | awk '{print $3/$2*100}')
            if is_number "$usage"; then
                result="$usage"
            fi
        fi
    fi
    
    echo "$result"
}

# Check if a specific process is running
check_process_running() {
    local process_name="$1"
    
    if command_exists pgrep; then
        # Using pgrep
        if pgrep -x "$process_name" >/dev/null; then
            return 0  # Process is running
        fi
    elif command_exists ps; then
        # Using ps
        if ps aux | grep -v grep | grep -q "$process_name"; then
            return 0  # Process is running
        fi
    fi
    
    return 1  # Process is not running
}

# Get top CPU consuming processes
get_top_cpu_processes() {
    local count="${1:-5}"
    
    if command_exists ps; then
        ps aux | sort -rn -k 3,3 | head -n "$((count+1))" | tail -n "$count" | awk '{print $11, $3"%"}'
    else
        echo "Process information not available"
    fi
}

# Get top memory consuming processes
get_top_memory_processes() {
    local count="${1:-5}"
    
    if command_exists ps; then
        ps aux | sort -rn -k 4,4 | head -n "$((count+1))" | tail -n "$count" | awk '{print $11, $4"%"}'
    else
        echo "Process information not available"
    fi
}

# Initialize configuration
init_config() {
    # Create thresholds file if it doesn't exist
    if [ ! -f "$THRESHOLDS_FILE" ]; then
        cat > "$THRESHOLDS_FILE" <<EOF
# SysMon Thresholds Configuration
# Values are in percentage except for load and interval
cpu_threshold=$CPU_THRESHOLD
memory_threshold=$MEMORY_THRESHOLD
disk_threshold=$DISK_THRESHOLD
check_interval=$CHECK_INTERVAL
process_checks=$PROCESS_CHECKS
EOF
        log_message "INFO" "Created default thresholds configuration file"
    fi
    
    # Create webhooks file if it doesn't exist
    if [ ! -f "$WEBHOOKS_FILE" ]; then
        echo "# SysMon Webhooks Configuration" > "$WEBHOOKS_FILE"
        echo "# Add one webhook URL per line" >> "$WEBHOOKS_FILE"
        log_message "INFO" "Created webhooks configuration file"
    fi
}

# Load thresholds from configuration file
load_thresholds() {
    if [ ! -f "$THRESHOLDS_FILE" ]; then
        log_message "WARNING" "Thresholds file not found, creating default"
        init_config
    else
        # Read thresholds from file
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key == \#* ]] && continue
            [[ -z $key ]] && continue
            
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            case "$key" in
                cpu_threshold)
                    CPU_THRESHOLD="$value"
                    ;;
                memory_threshold)
                    MEMORY_THRESHOLD="$value"
                    ;;
                disk_threshold)
                    DISK_THRESHOLD="$value"
                    ;;
                check_interval)
                    CHECK_INTERVAL="$value"
                    ;;
                process_checks)
                    PROCESS_CHECKS="$value"
                    ;;
            esac
        done < "$THRESHOLDS_FILE"
        
        log_message "INFO" "Loaded thresholds configuration"
    fi
}

# Load webhooks from configuration file
load_webhooks() {
    if [ ! -f "$WEBHOOKS_FILE" ]; then
        log_message "WARNING" "Webhooks file not found, creating default"
        init_config
    else
        # Clear the existing webhooks array
        WEBHOOKS=()
        
        # Read webhooks from file
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ $line == \#* ]] && continue
            [[ -z $line ]] && continue
            
            # Trim whitespace and add to array
            line=$(echo "$line" | xargs)
            WEBHOOKS+=("$line")
        done < "$WEBHOOKS_FILE"
        
        log_message "INFO" "Loaded ${#WEBHOOKS[@]} webhook(s)"
    fi
}

# Format webhook payload based on URL
format_webhook_payload() {
    local url="$1"
    local title="$2"
    local message="$3"
    local hostname=$(hostname)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)
    
    # Extract domain from URL to identify the provider
    local domain=$(echo "$url" | grep -o '://[^/]*' | sed 's/:///' | awk -F. '{print $(NF-1)"."$NF}')
    
    # Default JSON payload (simple enough to not need jq)
    local payload="{\"title\":\"$title\",\"message\":\"$message\",\"hostname\":\"$hostname\",\"timestamp\":\"$timestamp\",\"source\":\"SysMon\"}"
    
    # Format the payload according to the provider if we can identify it
    case "$domain" in
        *slack.com)
            # Slack webhook (simplified)
            payload="{\"text\":\"*$title*\n$message\n_From $hostname at $timestamp_\"}"
            ;;
        *discord.com)
            # Discord webhook (simplified)
            payload="{\"content\":\"**$title**\n$message\n*From $hostname at $timestamp*\"}"
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
    
    # Simple error handling to work in most environments
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url" 2>/dev/null)
    
    if [ -z "$response" ]; then
        log_message "ERROR" "Failed to send webhook notification - curl failed"
        return 1
    elif [ "$response" -ge 200 ] && [ "$response" -lt 300 ]; then
        log_message "INFO" "Webhook notification sent successfully (Status: $response)"
        return 0
    else
        log_message "ERROR" "Failed to send webhook notification (Status: $response)"
        return 1
    fi
}

# Add a new webhook endpoint
add_webhook() {
    local url="$1"
    
    # Validate the URL
    if ! is_valid_url "$url"; then
        log_message "ERROR" "Invalid webhook URL: $url"
        return 1
    fi
    
    # Load existing webhooks
    load_webhooks
    
    # Check if the webhook already exists
    for webhook in "${WEBHOOKS[@]}"; do
        if [ "$webhook" == "$url" ]; then
            log_message "WARNING" "Webhook already exists: $url"
            return 0
        fi
    done
    
    # Add the new webhook to the file
    echo "$url" >> "$WEBHOOKS_FILE"
    
    # Add to the array as well
    WEBHOOKS+=("$url")
    
    log_message "INFO" "Added webhook: $url"
    return 0
}

# Remove a webhook endpoint by index
remove_webhook() {
    local index="$1"
    
    # Validate the index
    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Invalid webhook index: $index"
        return 1
    fi
    
    # Load existing webhooks
    load_webhooks
    
    # Check if the index is valid
    if [ "$index" -ge "${#WEBHOOKS[@]}" ]; then
        log_message "ERROR" "Webhook index out of range: $index"
        return 1
    fi
    
    # Remove the webhook from the array
    local removed_webhook="${WEBHOOKS[$index]}"
    unset 'WEBHOOKS[$index]'
    
    # Rebuild the webhooks file
    echo "# SysMon Webhooks Configuration" > "$WEBHOOKS_FILE"
    echo "# Add one webhook URL per line" >> "$WEBHOOKS_FILE"
    
    for webhook in "${WEBHOOKS[@]}"; do
        if [ -n "$webhook" ]; then  # Only add non-empty webhooks
            echo "$webhook" >> "$WEBHOOKS_FILE"
        fi
    done
    
    log_message "INFO" "Removed webhook: $removed_webhook"
    return 0
}

# Update a threshold value
update_threshold() {
    local name="$1"
    local value="$2"
    
    # Validate the threshold name
    case "$name" in
        cpu_threshold|memory_threshold|disk_threshold|check_interval|process_checks)
            # Valid threshold name
            ;;
        *)
            log_message "ERROR" "Invalid threshold name: $name"
            return 1
            ;;
    esac
    
    # Validate the value (except for process_checks)
    if [ "$name" != "process_checks" ]; then
        if ! is_number "$value"; then
            log_message "ERROR" "Invalid threshold value: $value (must be a number)"
            return 1
        fi
    fi
    
    # Update the configuration file
    if [ -f "$THRESHOLDS_FILE" ]; then
        # Check if the threshold already exists in the file
        if grep -q "^$name=" "$THRESHOLDS_FILE"; then
            # Update existing threshold with a temp file approach (more universal)
            local temp_file="${THRESHOLDS_FILE}.tmp"
            while IFS= read -r line; do
                if [[ "$line" =~ ^$name= ]]; then
                    echo "$name=$value"
                else
                    echo "$line"
                fi
            done < "$THRESHOLDS_FILE" > "$temp_file"
            mv "$temp_file" "$THRESHOLDS_FILE"
        else
            # Add new threshold
            echo "$name=$value" >> "$THRESHOLDS_FILE"
        fi
        
        # Update the global variable
        case "$name" in
            cpu_threshold)
                CPU_THRESHOLD="$value"
                ;;
            memory_threshold)
                MEMORY_THRESHOLD="$value"
                ;;
            disk_threshold)
                DISK_THRESHOLD="$value"
                ;;
            check_interval)
                CHECK_INTERVAL="$value"
                ;;
            process_checks)
                PROCESS_CHECKS="$value"
                ;;
        esac
        
        log_message "INFO" "Updated threshold: $name=$value"
        return 0
    else
        log_message "ERROR" "Thresholds configuration file not found"
        return 1
    fi
}

# Print the current configuration
print_config() {
    echo "SysMon Configuration:"
    print_line
    echo "Thresholds:"
    echo "  CPU Usage Threshold: ${CPU_THRESHOLD}%"
    echo "  Memory Usage Threshold: ${MEMORY_THRESHOLD}%"
    echo "  Disk Usage Threshold: ${DISK_THRESHOLD}%"
    echo "  Check Interval: ${CHECK_INTERVAL} seconds"
    
    if [ -n "$PROCESS_CHECKS" ]; then
        echo "  Process Checks: ${PROCESS_CHECKS}"
    else
        echo "  Process Checks: None"
    fi
    
    print_line
    echo "Webhooks:"
    if [ ${#WEBHOOKS[@]} -eq 0 ]; then
        echo "  No webhooks configured"
    else
        for i in "${!WEBHOOKS[@]}"; do
            echo "  $i: ${WEBHOOKS[$i]}"
        done
    fi
    print_line
}

# Send notifications to all configured webhooks
send_notifications() {
    local title="$1"
    local message="$2"
    
    # If no webhooks are configured, just log the message
    if [ ${#WEBHOOKS[@]} -eq 0 ]; then
        log_message "INFO" "No webhooks configured, skipping notification"
        return 0
    fi
    
    # Send to each webhook
    for webhook in "${WEBHOOKS[@]}"; do
        send_webhook_notification "$webhook" "$title" "$message"
    done
}

# CPU monitoring check
check_cpu() {
    local cpu_usage=$(get_cpu_usage)
    
    log_message "INFO" "CPU usage: $cpu_usage% (threshold: $CPU_THRESHOLD%)"
    
    if [ "$cpu_usage" -ge "$CPU_THRESHOLD" ]; then
        log_message "WARNING" "CPU usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%"
        
        # Get top CPU consumers
        local top_processes=$(get_top_cpu_processes 5)
        
        # Send notifications
        send_notifications "CPU Usage Alert" "CPU usage is at $cpu_usage% (threshold: $CPU_THRESHOLD%)\n\nTop CPU consumers:\n$top_processes"
        return 1
    fi
    
    return 0
}

# Memory monitoring check
check_memory() {
    local memory_usage=$(get_memory_usage)
    
    log_message "INFO" "Memory usage: $memory_usage% (threshold: $MEMORY_THRESHOLD%)"
    
    if [ "$memory_usage" -ge "$MEMORY_THRESHOLD" ]; then
        log_message "WARNING" "Memory usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%"
        
        # Get top memory consumers
        local top_processes=$(get_top_memory_processes 5)
        
        # Send notifications
        send_notifications "Memory Usage Alert" "Memory usage is at $memory_usage% (threshold: $MEMORY_THRESHOLD%)\n\nTop memory consumers:\n$top_processes"
        return 1
    fi
    
    return 0
}

# Disk monitoring check
check_disk() {
    local disk_usage=$(get_disk_usage)
    
    log_message "INFO" "Disk usage: $disk_usage% (threshold: $DISK_THRESHOLD%)"
    
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        log_message "WARNING" "Disk usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%"
        
        # Find largest directories if possible
        local top_dirs=""
        if command_exists du; then
            # Only check commonly accessible directories to avoid permission issues
            top_dirs=$(du -h /var /tmp /home 2>/dev/null | sort -rh | head -n 5)
        fi
        
        # Send notifications
        send_notifications "Disk Usage Alert" "Disk usage is at $disk_usage% (threshold: $DISK_THRESHOLD%)\n\nLargest directories:\n$top_dirs"
        return 1
    fi
    
    return 0
}

# Process monitoring check
check_processes() {
    # Skip if no processes are configured to be monitored
    if [ -z "$PROCESS_CHECKS" ]; then
        return 0
    fi
    
    log_message "INFO" "Checking monitored processes"
    
    # Split process_checks by comma
    IFS=',' read -ra PROCESSES <<< "$PROCESS_CHECKS"
    
    # Check each process
    local failed_processes=""
    for process in "${PROCESSES[@]}"; do
        # Trim whitespace
        process=$(echo "$process" | xargs)
        
        if [ -z "$process" ]; then
            continue
        fi
        
        if ! check_process_running "$process"; then
            log_message "WARNING" "Monitored process not running: $process"
            failed_processes="$failed_processes $process"
        else
            log_message "INFO" "Monitored process running: $process"
        fi
    done
    
    # If any processes failed, send a notification
    if [ -n "$failed_processes" ]; then
        send_notifications "Process Monitor Alert" "The following monitored processes are not running:$failed_processes"
        return 1
    fi
    
    return 0
}

run_check() {
    log_message "INFO" "Running one-time system check"
    
    # Load config
    load_thresholds
    load_webhooks
    
    # Show current resource usage
    local cpu_usage=$(get_cpu_usage)
    echo "Current CPU usage: $cpu_usage% (threshold: $CPU_THRESHOLD%)"
    
    local memory_usage=$(get_memory_usage)
    echo "Current memory usage: $memory_usage% (threshold: $MEMORY_THRESHOLD%)"
    
    local disk_usage=$(get_disk_usage)
    echo "Current disk usage: $disk_usage% (threshold: $DISK_THRESHOLD%)"
    
    # Run threshold checks but don't send notifications
    if [ "$cpu_usage" -ge "$CPU_THRESHOLD" ]; then
        echo "⚠️ WARNING: CPU usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%"
        echo "Top CPU consumers:"
        get_top_cpu_processes 5
    fi
    
    if [ "$memory_usage" -ge "$MEMORY_THRESHOLD" ]; then
        echo "⚠️ WARNING: Memory usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%"
        echo "Top memory consumers:"
        get_top_memory_processes 5
    fi
    
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        echo "⚠️ WARNING: Disk usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%"
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
    
    # Test each webhook
    for i in "${!WEBHOOKS[@]}"; do
        echo "Testing webhook #$i: ${WEBHOOKS[$i]}"
        send_webhook_notification "${WEBHOOKS[$i]}" "Test" "This is a test notification from SysMon"
    done
}

show_help() {
    echo "Enhanced SysMon - System Monitoring Tool"
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

# Initialize
initialize_log
init_config

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