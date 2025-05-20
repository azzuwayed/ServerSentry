#!/bin/bash
#
# SysMon - Monitoring functionality

# Source dependencies if not already sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"  # Go up one level to get to the root

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

if [[ "$(type -t send_webhook_notification)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/notify.sh"
fi

# Global variable to store function results
RESULT=""

# Get CPU usage percentage
get_cpu_usage() {
    # Try different methods to get CPU usage based on available tools
    if command_exists mpstat; then
        # Using mpstat (part of sysstat package)
        local cpu_idle=$(mpstat 1 1 | grep -A 5 "%idle" | tail -n 1 | awk '{print $NF}')
        RESULT=$(echo "100 - $cpu_idle" | bc)
    elif command_exists top; then
        # Using top in batch mode
        local cpu_line=$(top -b -n 1 | grep -i '%cpu')
        # Extract idle percentage
        local cpu_idle=$(echo "$cpu_line" | awk '{for(i=1;i<=NF;i++) {if($i ~ /%idle/) {print $(i-1)}}}')
        if [ -z "$cpu_idle" ]; then
            # Try alternate format
            cpu_idle=$(echo "$cpu_line" | awk '{for(i=1;i<=NF;i++) {if($i ~ /id/) {print $(i+1)}}}' | tr -d '%,')
        fi
        RESULT=$(echo "100 - $cpu_idle" | bc 2>/dev/null || echo "0")
    else
        # Fallback to /proc/stat
        local cpu_line1=$(grep '^cpu ' /proc/stat)
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
            ((total1 += val))
        done
        
        for val in "${cpu2[@]}"; do
            ((total2 += val))
        done
        
        local delta_total=$((total2 - total1))
        local delta_idle=$((idle2 - idle1))
        
        # Calculate usage percentage
        RESULT=$(echo "scale=2; 100 * (1 - $delta_idle / $delta_total)" | bc)
    fi
    
    # Ensure result is a number and round to integer
    RESULT=$(echo "$RESULT" | awk '{printf "%.0f", $1}')
    if ! is_number "$RESULT"; then
        RESULT=0
    fi
}

# Get memory usage percentage
get_memory_usage() {
    if command_exists free; then
        # Using free command
        local memory_info=$(free | grep Mem)
        local total=$(echo "$memory_info" | awk '{print $2}')
        local free=$(echo "$memory_info" | awk '{print $4}')
        local buffers=$(echo "$memory_info" | awk '{print $6}')
        local cache=$(echo "$memory_info" | awk '{print $7}')
        
        # If buffers/cache columns don't exist in this version of free
        if [ -z "$buffers" ] || [ -z "$cache" ]; then
            local used=$(echo "$memory_info" | awk '{print $3}')
            RESULT=$(echo "scale=2; 100 * $used / $total" | bc)
        else
            # Calculate used memory (excluding buffers/cache)
            local used=$((total - free - buffers - cache))
            RESULT=$(echo "scale=2; 100 * $used / $total" | bc)
        fi
    else
        # Fallback to /proc/meminfo
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
        
        # Calculate used memory (excluding buffers/cache)
        local used=$((mem_total - mem_free - buffers - cached))
        RESULT=$(echo "scale=2; 100 * $used / $mem_total" | bc)
    fi
    
    # Ensure result is a number and round to integer
    RESULT=$(echo "$RESULT" | awk '{printf "%.0f", $1}')
    if ! is_number "$RESULT"; then
        RESULT=0
    fi
}

# Get disk usage percentage for root partition
get_disk_usage() {
    if command_exists df; then
        # Using df command for root partition (/)
        local disk_info=$(df -h / | tail -n 1)
        RESULT=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
    else
        # If df is not available, set to 0 (we can't easily determine disk usage without df)
        RESULT=0
        log_message "WARNING" "df command not available, cannot determine disk usage"
    fi
    
    # Ensure result is a number
    if ! is_number "$RESULT"; then
        RESULT=0
    fi
}

# Get system load average
get_system_load() {
    if [ -f /proc/loadavg ]; then
        # Using /proc/loadavg
        RESULT=$(cat /proc/loadavg | awk '{print $1}')
    elif command_exists uptime; then
        # Using uptime command
        RESULT=$(uptime | awk -F'[a-z]: ' '{print $2}' | awk '{print $1}' | tr -d ',')
    else
        # If neither is available
        RESULT=0
        log_message "WARNING" "Cannot determine system load average"
    fi
    
    # Ensure result is a number
    if ! is_number "$RESULT"; then
        RESULT=0
    fi
}

# Check if a specific process is running
check_process_running() {
    local process_name="$1"
    
    if command_exists pgrep; then
        # Using pgrep
        if pgrep -x "$process_name" >/dev/null; then
            return 0  # Process is running
        else
            return 1  # Process is not running
        fi
    elif command_exists ps; then
        # Using ps
        if ps aux | grep -v grep | grep -q "$process_name"; then
            return 0  # Process is running
        else
            return 1  # Process is not running
        fi
    else
        # Cannot check
        log_message "WARNING" "Cannot check if process is running: $process_name"
        return 2  # Unknown
    fi
}

# CPU monitoring check
check_cpu() {
    get_cpu_usage
    local cpu_usage=$RESULT
    
    log_message "INFO" "CPU usage: $cpu_usage% (threshold: $CPU_THRESHOLD%)"
    
    if [ "$cpu_usage" -ge "$CPU_THRESHOLD" ]; then
        log_message "WARNING" "CPU usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%"
        
        # Get top CPU consumers
        local top_processes=""
        if command_exists ps; then
            top_processes=$(ps aux --sort=-%cpu | head -n 6 | tail -n 5 | awk '{print $11 " " $3 "%"}')
        fi
        
        # Send notifications
        send_notifications "CPU Usage Alert" "CPU usage is at $cpu_usage% (threshold: $CPU_THRESHOLD%)\n\nTop CPU consumers:\n$top_processes"
        return 1
    fi
    
    return 0
}

# Memory monitoring check
check_memory() {
    get_memory_usage
    local memory_usage=$RESULT
    
    log_message "INFO" "Memory usage: $memory_usage% (threshold: $MEMORY_THRESHOLD%)"
    
    if [ "$memory_usage" -ge "$MEMORY_THRESHOLD" ]; then
        log_message "WARNING" "Memory usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%"
        
        # Get top memory consumers
        local top_processes=""
        if command_exists ps; then
            top_processes=$(ps aux --sort=-%mem | head -n 6 | tail -n 5 | awk '{print $11 " " $4 "%"}')
        fi
        
        # Send notifications
        send_notifications "Memory Usage Alert" "Memory usage is at $memory_usage% (threshold: $MEMORY_THRESHOLD%)\n\nTop memory consumers:\n$top_processes"
        return 1
    fi
    
    return 0
}

# Disk monitoring check
check_disk() {
    get_disk_usage
    local disk_usage=$RESULT
    
    log_message "INFO" "Disk usage: $disk_usage% (threshold: $DISK_THRESHOLD%)"
    
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        log_message "WARNING" "Disk usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%"
        
        # Get largest directories/files
        local top_dirs=""
        if command_exists du; then
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
