#!/bin/bash
#
# ServerSentry - Monitoring functionality (merged and improved)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source paths module and utilities
source "$SCRIPT_DIR/../utils/paths.sh"
source "$SCRIPT_DIR/../utils/utils.sh"

# Get the project root
PROJECT_ROOT="$(get_project_root)"

# Source required modules
if [[ "$(type -t send_webhook_notification)" != "function" ]]; then
    source "$PROJECT_ROOT/lib/notify/main.sh"
fi
if [[ "$(type -t load_thresholds)" != "function" ]]; then
    source "$PROJECT_ROOT/lib/config/config_manager.sh"
fi

# Global variable to store function results
RESULT=""

# Get CPU usage percentage (robust, cross-platform)
get_cpu_usage() {
    local result=0

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS-specific approach using alternate methods
        local cpu_line=$(sysctl -n vm.loadavg 2>/dev/null)
        if [ -n "$cpu_line" ]; then
            # Get current system load average
            local load=$(echo "$cpu_line" | awk '{print $2}')
            # Get number of cores
            local cores=$(sysctl -n hw.ncpu 2>/dev/null)
            # Calculate usage as percentage of available cores
            if [ -n "$cores" ] && [ "$cores" -gt 0 ]; then
                result=$(awk -v load="$load" -v cores="$cores" 'BEGIN {printf "%.0f", (load/cores)*100}')
                if [ "$result" -gt 100 ]; then
                    result=100
                fi
            fi
        else
            # Fallback method
            local cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | tr -d '%')
            if [ -n "$cpu_usage" ]; then
                result=$cpu_usage
            fi
        fi
    elif command_exists mpstat; then
        # Using mpstat (part of sysstat package)
        local cpu_idle=$(mpstat 1 1 | grep -A 5 "%idle" | tail -n 1 | awk '{print $NF}')
        result=$(awk -v idle="$cpu_idle" 'BEGIN {print 100 - idle}')
    elif command_exists top; then
        # Linux specific approach
        local cpu_line=$(top -bn 1 | grep -i '%cpu\|cpu(s)')
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
            local cpu1=($(echo "$cpu_line1" | awk '{$1=""; print $0}'))
            local cpu2=($(echo "$cpu_line2" | awk '{$1=""; print $0}'))
            local total1=0
            local total2=0
            local idle1=${cpu1[3]}
            local idle2=${cpu2[3]}
            for val in "${cpu1[@]}"; do total1=$((total1 + val)); done
            for val in "${cpu2[@]}"; do total2=$((total2 + val)); done
            local delta_total=$((total2 - total1))
            local delta_idle=$((idle2 - idle1))
            if [ "$delta_total" -gt 0 ]; then
                result=$(awk -v dt="$delta_total" -v di="$delta_idle" 'BEGIN {printf "%.1f", 100 * (1 - di/dt)}')
            fi
        fi
    fi

    result=$(printf "%.0f" "$result" 2>/dev/null || echo "$result" | awk '{printf "%.0f", $1}' 2>/dev/null || echo "0")
    if ! is_number "$result"; then result=0; fi
    RESULT="$result"
    echo "$result"
}

# Get memory usage percentage (robust, cross-platform)
get_memory_usage() {
    local result=0

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS-specific memory usage - improved parsing
        local memory_line=$(top -l 1 -n 0 | grep PhysMem)
        if [ -n "$memory_line" ]; then
            # Extract total memory
            local total_mem=$(sysctl -n hw.memsize 2>/dev/null)
            total_mem=$((total_mem / 1024 / 1024)) # Convert bytes to MB

            # Extract used memory from PhysMem line
            # Modern macOS format: "PhysMem: 16G used (3680M wired, 665M compressor), 469M unused."
            if [[ "$memory_line" == *"used"*"unused"* ]]; then
                local used_str=$(echo "$memory_line" | grep -o '[0-9]*G used' | grep -o '[0-9]*')
                local unused_str=$(echo "$memory_line" | grep -o '[0-9]*M unused' | grep -o '[0-9]*')

                # Convert gigabytes to megabytes if needed
                if [ -n "$used_str" ]; then
                    local used_mb=$((used_str * 1024))
                    if [ -n "$unused_str" ]; then
                        # Calculate percentage from used and unused
                        local total_mb=$((used_mb + unused_str))
                        result=$(awk -v u="$used_mb" -v t="$total_mb" 'BEGIN {printf "%.0f", (u/t)*100}')
                    elif [ -n "$total_mem" ] && [ "$total_mem" -gt 0 ]; then
                        # Use system reported total memory
                        result=$(awk -v u="$used_mb" -v t="$total_mem" 'BEGIN {printf "%.0f", (u/t)*100}')
                    fi
                fi
            else
                # Fallback: Try to extract wired/active memory and calculate
                local wired=$(echo "$memory_line" | grep -o '[0-9]*M wired' | grep -o '[0-9]*')
                local active=$(echo "$memory_line" | grep -o '[0-9]*M active' | grep -o '[0-9]*')

                if [ -n "$wired" ] && [ -n "$active" ] && [ -n "$total_mem" ]; then
                    local used_mem=$((wired + active))
                    result=$(awk -v u="$used_mem" -v t="$total_mem" 'BEGIN {printf "%.0f", (u/t)*100}')
                fi
            fi

            # Ensure we have a valid result
            if [ -z "$result" ] || [ "$result" -eq 0 ]; then
                # Last resort: estimate based on unused memory
                local unused_mb=$(echo "$memory_line" | grep -o '[0-9]*M unused' | grep -o '[0-9]*')
                if [ -n "$unused_mb" ] && [ -n "$total_mem" ]; then
                    result=$(awk -v u="$unused_mb" -v t="$total_mem" 'BEGIN {printf "%.0f", 100-(u/t)*100}')
                fi
            fi
        fi
    elif command_exists free; then
        # Using free command (Linux)
        local memory_info=$(free | grep Mem)
        local total=$(echo "$memory_info" | awk '{print $2}')
        local used=$(echo "$memory_info" | awk '{print $3}')
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
            if [ -n "$mem_total" ] && [ -n "$mem_free" ] && [ "$mem_total" -gt 0 ]; then
                local used=$((mem_total - mem_free - buffers - cached))
                result=$(awk -v t="$mem_total" -v u="$used" 'BEGIN {printf "%.1f", 100 * u/t}')
            fi
        fi
    fi

    result=$(printf "%.0f" "$result" 2>/dev/null || echo "$result" | awk '{printf "%.0f", $1}' 2>/dev/null || echo "0")
    if ! is_number "$result"; then result=0; fi
    RESULT="$result"
    echo "$result"
}

# Get disk usage percentage (robust, cross-platform)
get_disk_usage() {
    local result=0
    local mount_point="/"

    if [ -n "$1" ]; then
        mount_point="$1"
    fi

    if command_exists df; then
        # Using df command for specified partition
        # Handle macOS/BSD vs Linux differences in df output
        if [[ "$(uname)" == "Darwin" ]]; then
            local disk_info=$(df -h "$mount_point" 2>/dev/null | tail -n 1)
            local usage=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
        else
            local disk_info=$(df -P "$mount_point" 2>/dev/null | tail -n 1)
            local usage=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
        fi

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

    RESULT="$result"
    echo "$result"
}

# Get system load average (1 min)
get_system_load() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS specific load average
        RESULT=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
    elif [ -f /proc/loadavg ]; then
        RESULT=$(cat /proc/loadavg | awk '{print $1}')
    elif command_exists uptime; then
        RESULT=$(uptime | awk -F'[a-z]: ' '{print $2}' | awk '{print $1}' | tr -d ',')
    else
        RESULT=0
        log_message "WARNING" "Cannot determine system load average"
    fi
    if ! is_number "$RESULT"; then RESULT=0; fi
    echo "$RESULT"
}

# Check if a specific process is running
check_process_running() {
    local process_name="$1"

    if command_exists pgrep; then
        # Using pgrep (slightly different syntax for macOS vs Linux)
        if [[ "$(uname)" == "Darwin" ]]; then
            if pgrep "$process_name" >/dev/null; then
                return 0 # Process is running
            fi
        else
            if pgrep -x "$process_name" >/dev/null; then
                return 0 # Process is running
            fi
        fi
    elif command_exists ps; then
        # Using ps
        if ps aux | grep -v grep | grep -q "$process_name"; then
            return 0 # Process is running
        fi
    fi

    return 1 # Process is not running
}

# Get top CPU consuming processes
get_top_cpu_processes() {
    local count="${1:-5}"

    if command_exists ps; then
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS version
            ps -arcwwxo command,pcpu | head -n "$((count + 1))" | tail -n "$count" | awk '{print $1, $2"%"}'
        else
            # Linux version
            ps aux | sort -rn -k 3,3 | head -n "$((count + 1))" | tail -n "$count" | awk '{print $11, $3"%"}'
        fi
    else
        echo "Process information not available"
    fi
}

# Get top memory consuming processes
get_top_memory_processes() {
    local count="${1:-5}"

    if command_exists ps; then
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS version
            ps -arcwwxo command,pmem | head -n "$((count + 1))" | tail -n "$count" | awk '{print $1, $2"%"}'
        else
            # Linux version
            ps aux | sort -rn -k 4,4 | head -n "$((count + 1))" | tail -n "$count" | awk '{print $11, $4"%"}'
        fi
    else
        echo "Process information not available"
    fi
}

# CPU monitoring check
check_cpu() {
    get_cpu_usage
    local cpu_usage=$RESULT
    log_message "INFO" "CPU usage: $cpu_usage% (threshold: $CPU_THRESHOLD%)"

    # Force conversion to integers and handle errors for reliable comparison
    if [ "${cpu_usage:-0}" -ge "${CPU_THRESHOLD:-80}" ] 2>/dev/null; then
        log_message "WARNING" "CPU usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%"
        local top_processes=$(get_top_cpu_processes 5)
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

    # Force conversion to integers and handle errors for reliable comparison
    if [ "${memory_usage:-0}" -ge "${MEMORY_THRESHOLD:-80}" ] 2>/dev/null; then
        log_message "WARNING" "Memory usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%"
        local top_processes=$(get_top_memory_processes 5)
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

    # Force conversion to integers and handle errors for reliable comparison
    if [ "${disk_usage:-0}" -ge "${DISK_THRESHOLD:-85}" ] 2>/dev/null; then
        log_message "WARNING" "Disk usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%"
        local top_dirs=""
        if command_exists du; then
            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS specific directories
                top_dirs=$(du -h /var /tmp /Users 2>/dev/null | sort -hr | head -n 5)
            else
                # Linux directories
                top_dirs=$(du -h /var /tmp /home 2>/dev/null | sort -rh | head -n 5)
            fi
        fi
        send_notifications "Disk Usage Alert" "Disk usage is at $disk_usage% (threshold: $DISK_THRESHOLD%)\n\nLargest directories:\n$top_dirs"
        return 1
    fi
    return 0
}

# Process monitoring check
check_processes() {
    if [ -z "$PROCESS_CHECKS" ]; then
        return 0
    fi
    log_message "INFO" "Checking monitored processes"
    IFS=',' read -ra PROCESSES <<<"$PROCESS_CHECKS"
    local failed_processes=""
    for process in "${PROCESSES[@]}"; do
        process=$(echo "$process" | xargs)
        if [ -z "$process" ]; then continue; fi
        if ! check_process_running "$process"; then
            log_message "WARNING" "Monitored process not running: $process"
            failed_processes="$failed_processes $process"
        else
            log_message "INFO" "Monitored process running: $process"
        fi
    done
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
    if [ ${#WEBHOOKS[@]} -eq 0 ]; then
        log_message "INFO" "No webhooks configured, skipping notification"
        return 0
    fi
    for webhook in "${WEBHOOKS[@]}"; do
        send_webhook_notification "$webhook" "$title" "$message"
    done
}
