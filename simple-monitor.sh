#!/bin/bash
#
# Simple System Monitor - Demonstrates core monitoring capabilities

# Get CPU usage percentage
get_cpu_usage() {
    # Using top in batch mode
    local cpu_line=$(top -b -n 1 | grep "Cpu(s)")
    # Extract idle percentage 
    local cpu_idle=$(echo "$cpu_line" | awk '{print $8}' | tr -d '%,id')
    # Calculate usage by subtracting idle from 100
    echo $((100 - ${cpu_idle%.*}))
}

# Get memory usage percentage
get_memory_usage() {
    # Using free command
    local memory_info=$(free | grep Mem)
    local total=$(echo "$memory_info" | awk '{print $2}')
    local used=$(echo "$memory_info" | awk '{print $3}')
    local usage=$((used * 100 / total))
    echo $usage
}

# Get disk usage percentage
get_disk_usage() {
    # Using df command for root partition (/)
    local disk_info=$(df -h / | tail -n 1)
    local usage=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
    echo $usage
}

# Check if a process is running
check_process() {
    local process_name="$1"
    if ps aux | grep -v grep | grep -q "$process_name"; then
        echo "✓ Process $process_name is running"
    else
        echo "✗ Process $process_name is NOT running"
    fi
}

# Print a horizontal line
print_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}

# Send a webhook notification
send_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"
    
    if [ -z "$url" ]; then
        echo "No webhook URL provided, skipping notification"
        return
    fi
    
    # Create a simple JSON payload
    local payload="{\"title\":\"$title\",\"message\":\"$message\",\"hostname\":\"$(hostname)\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
    
    # Send the webhook request
    if curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url" >/dev/null 2>&1; then
        echo "✓ Webhook notification sent successfully"
    else
        echo "✗ Failed to send webhook notification"
    fi
}

# Main function
main() {
    echo "Simple System Monitor"
    print_line
    
    # Get resource usage
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local disk=$(get_disk_usage)
    
    # Display current usage
    echo "Current System Status:"
    echo "CPU Usage: $cpu%"
    echo "Memory Usage: $memory%"
    echo "Disk Usage: $disk%"
    print_line
    
    # Check some common processes
    echo "Process Status:"
    check_process "sshd"
    check_process "cron"
    print_line
    
    # Define thresholds
    local cpu_threshold=80
    local memory_threshold=80
    local disk_threshold=85
    
    # Check thresholds and send alerts if needed
    echo "Threshold Checks:"
    
    if [ "$cpu" -ge "$cpu_threshold" ]; then
        echo "⚠️ CPU usage alert: $cpu% >= $cpu_threshold%"
        # Uncomment to enable webhook notifications
        # send_webhook "https://your-webhook-url" "CPU Alert" "CPU usage is at $cpu% (threshold: $cpu_threshold%)"
    else
        echo "✓ CPU usage normal: $cpu% < $cpu_threshold%"
    fi
    
    if [ "$memory" -ge "$memory_threshold" ]; then
        echo "⚠️ Memory usage alert: $memory% >= $memory_threshold%"
        # Uncomment to enable webhook notifications
        # send_webhook "https://your-webhook-url" "Memory Alert" "Memory usage is at $memory% (threshold: $memory_threshold%)"
    else
        echo "✓ Memory usage normal: $memory% < $memory_threshold%"
    fi
    
    if [ "$disk" -ge "$disk_threshold" ]; then
        echo "⚠️ Disk usage alert: $disk% >= $disk_threshold%"
        # Uncomment to enable webhook notifications
        # send_webhook "https://your-webhook-url" "Disk Alert" "Disk usage is at $disk% (threshold: $disk_threshold%)"
    else
        echo "✓ Disk usage normal: $disk% < $disk_threshold%"
    fi
}

# Run the main function
main