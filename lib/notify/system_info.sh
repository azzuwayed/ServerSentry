#!/bin/bash
#
# ServerSentry - System Information Module
# Part of the modular notify system

# Check if utils.sh is sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

if [[ "$(type -t command_exists)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

# Get system information for detailed reports
get_system_info() {
    local hostname=$(hostname)
    local os_info=""
    local kernel=""
    local uptime=""
    local cpu_info=""
    local memory_info=""
    local disk_info=""
    local loadavg=""
    local ip_addr=""
    local cpu_cores=""
    local cpu_usage=""
    local memory_usage=""
    local disk_usage=""
    
    # Get OS information
    if [[ "$(uname)" == "Darwin" ]]; then
        os_info=$(sw_vers -productName 2>/dev/null)
        os_version=$(sw_vers -productVersion 2>/dev/null)
        os_info="$os_info $os_version"
    elif [ -f /etc/os-release ]; then
        os_info=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    else
        os_info=$(uname -s)
    fi
    
    # Get kernel version
    kernel=$(uname -r)
    
    # Get uptime (human readable)
    if command_exists uptime; then
        if [[ "$(uname)" == "Darwin" ]]; then
            uptime=$(uptime | sed 's/.*up \([^,]*\).*/\1/')
        else
            uptime=$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\).*/\1/')
        fi
    fi
    
    # Get load average
    if [[ "$(uname)" == "Darwin" ]]; then
        loadavg=$(sysctl -n vm.loadavg | awk '{print $2", "$3", "$4}')
    elif [ -f /proc/loadavg ]; then
        loadavg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    fi
    
    # Get IP address
    if command_exists hostname; then
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    if [ -z "$ip_addr" ] && [[ "$(uname)" == "Darwin" ]]; then
        ip_addr=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    fi
    
    if [ -z "$ip_addr" ]; then 
        ip_addr="Not available"
    fi
    
    # Get CPU info
    if [[ "$(uname)" == "Darwin" ]]; then
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null)
        cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}')
        cpu_info="$cpu_model ($cpu_cores cores)"
    elif [ -f /proc/cpuinfo ]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        cpu_cores=$(grep -c "processor" /proc/cpuinfo)
        if command_exists mpstat; then
            cpu_usage=$(mpstat 1 1 | grep -A 5 "%idle" | tail -n 1 | awk '{print 100 - $NF}')
            cpu_usage="${cpu_usage}%"
        else
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
            cpu_usage="${cpu_usage}%"
        fi
        cpu_info="$cpu_model ($cpu_cores cores)"
    fi
    
    # Get memory info
    if [[ "$(uname)" == "Darwin" ]]; then
        total_mem=$(sysctl -n hw.memsize 2>/dev/null)
        total_mem=$((total_mem / 1024 / 1024)) # Convert to MB
        used_mem=$(vm_stat | grep "Pages active\|Pages wired down" | awk '{sum+=$NF} END {print sum}' | tr -d '.')
        page_size=$(sysctl -n hw.pagesize 2>/dev/null)
        if [ -n "$used_mem" ] && [ -n "$page_size" ]; then
            used_mem=$((used_mem * page_size / 1024 / 1024))
            memory_usage=$(awk -v t="$total_mem" -v u="$used_mem" 'BEGIN {printf "%.1f", (u/t)*100}')
            memory_usage="${memory_usage}%"
        else
            memory_usage=$(top -l 1 -n 0 | grep PhysMem | awk '{print $8}')
        fi
        memory_info="$used_mem MB Used / $total_mem MB Total"
    elif command_exists free; then
        total_mem=$(free -m | grep Mem | awk '{print $2}')
        used_mem=$(free -m | grep Mem | awk '{print $3}')
        memory_usage=$(awk -v t="$total_mem" -v u="$used_mem" 'BEGIN {printf "%.1f", (u/t)*100}')
        memory_usage="${memory_usage}%"
        memory_info="$used_mem MB Used / $total_mem MB Total"
    fi
    
    # Get disk info
    if command_exists df; then
        if [[ "$(uname)" == "Darwin" ]]; then
            disk_usage=$(df -h / | tail -1 | awk '{print $5}')
            disk_total=$(df -h / | tail -1 | awk '{print $2}')
            disk_used=$(df -h / | tail -1 | awk '{print $3}')
            disk_avail=$(df -h / | tail -1 | awk '{print $4}')
        else
            disk_usage=$(df -h / | tail -1 | awk '{print $5}')
            disk_total=$(df -h / | tail -1 | awk '{print $2}')
            disk_used=$(df -h / | tail -1 | awk '{print $3}')
            disk_avail=$(df -h / | tail -1 | awk '{print $4}')
        fi
        disk_info="$disk_used Used / $disk_total Total ($disk_usage)"
    fi
    
    # Create a JSON object with all system info
    local json="{"
    json+="\"hostname\":\"$hostname\","
    json+="\"os\":\"$os_info\","
    json+="\"kernel\":\"$kernel\","
    json+="\"uptime\":\"$uptime\","
    json+="\"loadavg\":\"$loadavg\","
    json+="\"ip\":\"$ip_addr\","
    json+="\"cpu_info\":\"$cpu_info\","
    json+="\"cpu_cores\":\"$cpu_cores\","
    json+="\"cpu_usage\":\"$cpu_usage\","
    json+="\"memory_info\":\"$memory_info\","
    json+="\"memory_usage\":\"$memory_usage\","
    json+="\"disk_info\":\"$disk_info\","
    json+="\"disk_usage\":\"$disk_usage\","
    json+="\"disk_total\":\"$disk_total\","
    json+="\"disk_used\":\"$disk_used\","
    json+="\"disk_avail\":\"$disk_avail\""
    json+="}"
    
    echo "$json"
}

# Helper function to extract a field from system info JSON
extract_from_system_info() {
    local json="$1"
    local field="$2"
    
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | cut -d'"' -f4
} 