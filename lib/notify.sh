#!/bin/bash
#
# ServerSentry - Notification functionality (merged and improved)

# Source dependencies if not already sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

# Check if curl is available
if ! command_exists curl; then
    log_message "WARNING" "curl command not found, webhook notifications will not work"
fi

# Check if jq is available for better JSON support
HAS_JQ=0
if command_exists jq; then
    HAS_JQ=1
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

# Create adaptive card JSON for Microsoft Teams
create_adaptive_card() {
    local title="$1"
    local message="$2"
    local system_info="$3"
    local status="$4"
    local timestamp="$5"
    
    # Extract system info from JSON
    local hostname=$(echo "$system_info" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4)
    local os=$(echo "$system_info" | grep -o '"os":"[^"]*"' | cut -d'"' -f4)
    local kernel=$(echo "$system_info" | grep -o '"kernel":"[^"]*"' | cut -d'"' -f4)
    local uptime=$(echo "$system_info" | grep -o '"uptime":"[^"]*"' | cut -d'"' -f4)
    local loadavg=$(echo "$system_info" | grep -o '"loadavg":"[^"]*"' | cut -d'"' -f4)
    local ip=$(echo "$system_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    local cpu_info=$(echo "$system_info" | grep -o '"cpu_info":"[^"]*"' | cut -d'"' -f4)
    local cpu_usage=$(echo "$system_info" | grep -o '"cpu_usage":"[^"]*"' | cut -d'"' -f4)
    local memory_info=$(echo "$system_info" | grep -o '"memory_info":"[^"]*"' | cut -d'"' -f4)
    local memory_usage=$(echo "$system_info" | grep -o '"memory_usage":"[^"]*"' | cut -d'"' -f4)
    local disk_info=$(echo "$system_info" | grep -o '"disk_info":"[^"]*"' | cut -d'"' -f4)
    local disk_usage=$(echo "$system_info" | grep -o '"disk_usage":"[^"]*"' | cut -d'"' -f4)
    
    # Determine color based on status/title
    local color="good"
    if [[ "$title" == *"CPU"* ]] || [[ "$title" == *"Alert"* ]]; then
        color="attention"
    elif [[ "$title" == *"Memory"* ]]; then
        color="warning"
    elif [[ "$title" == *"Disk"* ]]; then
        color="warning"
    elif [[ "$title" == *"Test"* ]]; then
        color="accent"
    fi
    
    # Function to determine status icon based on usage
    get_status_icon() {
        local usage=$1
        local threshold=$2
        
        if [ "$usage" -ge "$threshold" ]; then
            echo "⚠️"
        elif [ "$usage" -ge "$((threshold - 20))" ]; then
            echo "⚡"
        else
            echo "✅"
        fi
    }
    
    # Function to determine color based on usage
    get_color_for_usage() {
        local usage=$1
        local threshold=$2
        
        if [ "$usage" -ge "$threshold" ]; then
            echo "attention"  # Red
        elif [ "$usage" -ge "$((threshold - 20))" ]; then
            echo "warning"    # Yellow/Orange
        else
            echo "good"       # Green
        fi
    }
    
    # Function to create progress bar
    create_progress_bar() {
        local value=$1
        local threshold=$2
        local width=10
        local filled=$((value * width / 100))
        local bar=""
        
        # Choose color based on threshold
        local color=$(get_color_for_usage "$value" "$threshold")
        
        # Put progress bar in a column
        bar="{
            \"type\": \"Column\",
            \"width\": \"auto\",
            \"items\": [
                {
                    \"type\": \"TextBlock\",
                    \"text\": \"${value}% of ${threshold}%\",
                    \"color\": \"${color}\",
                    \"weight\": \"bolder\",
                    \"size\": \"small\"
                },
                {
                    \"type\": \"ColumnSet\",
                    \"columns\": ["
        
        # Add filled part if any
        if [ "$filled" -gt 0 ]; then
            bar="${bar}
                        {
                            \"type\": \"Column\",
                            \"width\": ${filled},
                            \"items\": [
                                {
                                    \"type\": \"Container\",
                                    \"style\": \"emphasis\",
                                    \"backgroundImage\": \"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIAAAUAAeImBZsAAAAASUVORK5CYII=\",
                                    \"bleed\": true,
                                    \"height\": \"8px\",
                                    \"backgroundImageBackgroundColor\": \"${color}\"
                                }
                            ]
                        }"
        fi
        
        # Add unfilled part if any
        if [ "$filled" -lt "$width" ]; then
            # Add comma if there's a filled part
            [ "$filled" -gt 0 ] && bar="${bar},"
            
            bar="${bar}
                        {
                            \"type\": \"Column\",
                            \"width\": $((width - filled)),
                            \"items\": [
                                {
                                    \"type\": \"Container\",
                                    \"style\": \"default\",
                                    \"backgroundImage\": \"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIAAAUAAeImBZsAAAAASUVORK5CYII=\",
                                    \"bleed\": true,
                                    \"height\": \"8px\",
                                    \"backgroundImageBackgroundColor\": \"#DDDDDD\"
                                }
                            ]
                        }"
        fi
        
        # Close columns and return
        bar="${bar}
                    ]
                }
            ]
        }"
        
        echo "$bar"
    }
    
    # Extract numerical values for thresholds
    local cpu_value=$(echo "$cpu_usage" | grep -o '[0-9]*' | head -1)
    local memory_value=$(echo "$memory_usage" | grep -o '[0-9]*' | head -1)
    local disk_value=$(echo "$disk_usage" | grep -o '[0-9]*' | head -1)
    
    # Default thresholds if not available
    local cpu_threshold=80
    local memory_threshold=80
    local disk_threshold=85
    
    # Get appropriate status icons
    local cpu_icon=$(get_status_icon "$cpu_value" "$cpu_threshold")
    local memory_icon=$(get_status_icon "$memory_value" "$memory_threshold")
    local disk_icon=$(get_status_icon "$disk_value" "$disk_threshold")
    
    # Create progress bars
    local cpu_bar=$(create_progress_bar "$cpu_value" "$cpu_threshold")
    local memory_bar=$(create_progress_bar "$memory_value" "$memory_threshold")
    local disk_bar=$(create_progress_bar "$disk_value" "$disk_threshold")
    
    # Create adaptive card JSON with enhanced visuals
    local card='{
        "type": "AdaptiveCard",
        "body": [
            {
                "type": "TextBlock",
                "text": "'"$title"'",
                "weight": "Bolder",
                "size": "Large",
                "color": "'"$color"'"
            },
            {
                "type": "TextBlock",
                "text": "'"${message//\"/\\\"}"'",
                "wrap": true
            },
            {
                "type": "Container",
                "style": "emphasis",
                "items": [
                    {
                        "type": "TextBlock",
                        "text": "📊 System Metrics",
                        "weight": "Bolder",
                        "size": "Medium"
                    },
                    {
                        "type": "ColumnSet",
                        "columns": [
                            {
                                "type": "Column",
                                "width": "auto",
                                "items": [
                                    {
                                        "type": "TextBlock",
                                        "text": "🖥️ CPU:",
                                        "weight": "Bolder"
                                    }
                                ]
                            },
                            '"$cpu_bar"'
                        ]
                    },
                    {
                        "type": "ColumnSet",
                        "columns": [
                            {
                                "type": "Column",
                                "width": "auto",
                                "items": [
                                    {
                                        "type": "TextBlock",
                                        "text": "🧠 Memory:",
                                        "weight": "Bolder"
                                    }
                                ]
                            },
                            '"$memory_bar"'
                        ]
                    },
                    {
                        "type": "ColumnSet",
                        "columns": [
                            {
                                "type": "Column",
                                "width": "auto",
                                "items": [
                                    {
                                        "type": "TextBlock",
                                        "text": "💾 Disk:",
                                        "weight": "Bolder"
                                    }
                                ]
                            },
                            '"$disk_bar"'
                        ]
                    }
                ]
            },
            {
                "type": "FactSet",
                "facts": [
                    {
                        "title": "🏠 Host",
                        "value": "'"$hostname"'"
                    },
                    {
                        "title": "🌐 IP Address",
                        "value": "'"$ip"'"
                    },
                    {
                        "title": "💻 OS",
                        "value": "'"$os"'"
                    },
                    {
                        "title": "⏱️ Uptime",
                        "value": "'"$uptime"'"
                    },
                    {
                        "title": "🔄 Status",
                        "value": "'"$status"'"
                    },
                    {
                        "title": "🕒 Time",
                        "value": "'"$timestamp"'"
                    }
                ]
            }
        ],
        "actions": [
            {
                "type": "Action.ShowCard",
                "title": "System Details",
                "card": {
                    "type": "AdaptiveCard",
                    "body": [
                        {
                            "type": "FactSet",
                            "facts": [
                                {
                                    "title": "Kernel",
                                    "value": "'"$kernel"'"
                                },
                                {
                                    "title": "Load Average",
                                    "value": "'"$loadavg"'"
                                },
                                {
                                    "title": "CPU",
                                    "value": "'"$cpu_info"'"
                                },
                                {
                                    "title": "Memory",
                                    "value": "'"$memory_info"'"
                                },
                                {
                                    "title": "Disk",
                                    "value": "'"$disk_info"'"
                                }
                            ]
                        }
                    ]
                }
            }
        ],
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.2"
    }'
    
    echo "$card"
}

# Format the webhook payload based on the provider
format_webhook_payload() {
    local url="$1"
    local title="$2"
    local message="$3"
    local hostname=$(hostname)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)
    
    # Get additional system information
    local system_info=""
    local adaptive_card=""
    system_info=$(get_system_info)

    # Get alert severity/status
    local status="info"
    if [[ "$title" == *"Alert"* ]]; then
        status="alert"
    elif [[ "$title" == *"Test"* ]]; then
        status="test"
    fi
    
    # Extract specific values from system_info JSON
    local os=$(echo "$system_info" | grep -o '"os":"[^"]*"' | cut -d'"' -f4)
    local ip=$(echo "$system_info" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
    local cpu_usage=$(echo "$system_info" | grep -o '"cpu_usage":"[^"]*"' | cut -d'"' -f4)
    local memory_usage=$(echo "$system_info" | grep -o '"memory_usage":"[^"]*"' | cut -d'"' -f4)
    local disk_usage=$(echo "$system_info" | grep -o '"disk_usage":"[^"]*"' | cut -d'"' -f4)
    local uptime=$(echo "$system_info" | grep -o '"uptime":"[^"]*"' | cut -d'"' -f4)
    local kernel=$(echo "$system_info" | grep -o '"kernel":"[^"]*"' | cut -d'"' -f4)
    local loadavg=$(echo "$system_info" | grep -o '"loadavg":"[^"]*"' | cut -d'"' -f4)
    local memory_info=$(echo "$system_info" | grep -o '"memory_info":"[^"]*"' | cut -d'"' -f4)
    local disk_info=$(echo "$system_info" | grep -o '"disk_info":"[^"]*"' | cut -d'"' -f4)
    local cpu_info=$(echo "$system_info" | grep -o '"cpu_info":"[^"]*"' | cut -d'"' -f4)
    
    # Create adaptive card for Teams
    adaptive_card=$(create_adaptive_card "$title" "$message" "$system_info" "$status" "$timestamp")
    
    # Look for Power Automate/Microsoft Flow/Teams in the URL
    if [[ "$url" =~ "logic.azure.com" ]] || [[ "$url" =~ "powerautomate" ]] || [[ "$url" =~ "microsoft" ]]; then
        # Format for Microsoft Teams/Power Automate webhook with the specific attachments array
        # This is required for flows that iterate through the attachments array
        local escaped_message="${message//\"/\\\"}"
        escaped_message="${escaped_message//$'\n'/\\n}"
        
        # Create a Teams message card for the attachment content
        local teams_card="{
            \"contentType\": \"application/vnd.microsoft.card.adaptive\",
            \"content\": {
                \"$schema\": \"http://adaptivecards.io/schemas/adaptive-card.json\",
                \"type\": \"AdaptiveCard\",
                \"version\": \"1.2\",
                \"msteams\": {
                    \"width\": \"Full\"
                },
                \"body\": [
                    {
                        \"type\": \"TextBlock\",
                        \"text\": \"$title\",
                        \"weight\": \"Bolder\",
                        \"size\": \"ExtraLarge\",
                        \"color\": \"Accent\"
                    },
                    {
                        \"type\": \"TextBlock\",
                        \"text\": \"From: $hostname at $timestamp\",
                        \"isSubtle\": true,
                        \"wrap\": true
                    },
                    {
                        \"type\": \"TextBlock\",
                        \"text\": \"$escaped_message\",
                        \"wrap\": true
                    },
                    {
                        \"type\": \"FactSet\",
                        \"facts\": [
                            {
                                \"title\": \"🖥️ CPU\",
                                \"value\": \"$cpu_usage\"
                            },
                            {
                                \"title\": \"🧠 Memory\",
                                \"value\": \"$memory_usage\"
                            },
                            {
                                \"title\": \"💾 Disk\",
                                \"value\": \"$disk_usage\"
                            },
                            {
                                \"title\": \"💻 OS\",
                                \"value\": \"$os\"
                            },
                            {
                                \"title\": \"⏱️ Uptime\",
                                \"value\": \"$uptime\"
                            },
                            {
                                \"title\": \"🌐 IP\",
                                \"value\": \"$ip\"
                            }
                        ]
                    }
                ],
                \"actions\": [
                    {
                        \"type\": \"Action.ShowCard\",
                        \"title\": \"View System Details\",
                        \"card\": {
                            \"type\": \"AdaptiveCard\",
                            \"body\": [
                                {
                                    \"type\": \"FactSet\",
                                    \"facts\": [
                                        {
                                            \"title\": \"CPU\",
                                            \"value\": \"$cpu_info\"
                                        },
                                        {
                                            \"title\": \"Memory\",
                                            \"value\": \"$memory_info\"
                                        },
                                        {
                                            \"title\": \"Disk\",
                                            \"value\": \"$disk_info\"
                                        },
                                        {
                                            \"title\": \"Load Avg\",
                                            \"value\": \"$loadavg\"
                                        },
                                        {
                                            \"title\": \"Kernel\",
                                            \"value\": \"$kernel\"
                                        }
                                    ]
                                }
                            ]
                        }
                    }
                ]
            }
        }"
        
        # Create the primary payload with the required attachments array
        payload="{
            \"type\": \"message\",
            \"title\": \"$title\",
            \"text\": \"$escaped_message\",
            \"attachments\": [
                $teams_card
            ],
            \"hostname\": \"$hostname\",
            \"ip\": \"$ip\",
            \"timestamp\": \"$timestamp\",
            \"source\": \"ServerSentry\",
            \"os\": \"$os\",
            \"cpu_usage\": \"$cpu_usage\",
            \"memory_usage\": \"$memory_usage\",
            \"disk_usage\": \"$disk_usage\"
        }"
    elif [[ "$domain" == *slack.com ]]; then
        # Slack webhook
        payload="{\"text\":\"*$title*\\n$message\\n_From $hostname at $timestamp_\"}"
    elif [[ "$domain" == *discord.com ]]; then
        # Discord webhook
        payload="{\"content\":\"**$title**\\n$message\\n*From $hostname at $timestamp*\"}"
    else
        # Default generic JSON payload - include all data
        payload="{
            \"title\": \"$title\",
            \"message\": \"${escaped_message}\",
            \"hostname\": \"$hostname\",
            \"ip\": \"$ip\",
            \"timestamp\": \"$timestamp\",
            \"source\": \"ServerSentry\",
            \"os\": \"$os\",
            \"kernel\": \"$kernel\",
            \"uptime\": \"$uptime\",
            \"loadavg\": \"$loadavg\",
            \"cpu\": \"$cpu_info\",
            \"cpu_usage\": \"$cpu_usage\",
            \"memory\": \"$memory_info\",
            \"memory_usage\": \"$memory_usage\",
            \"disk\": \"$disk_info\",
            \"disk_usage\": \"$disk_usage\",
            \"status\": \"$status\",
            \"content\": ${adaptive_card}
        }"
    fi
    
    echo "$payload"
}

# Send a webhook notification
send_webhook_notification() {
    local url="$1"
    local title="$2"
    local message="$3"
    
    # Ensure URL is properly formatted (remove any accidental escaping)
    url=$(echo "$url" | sed 's/\\//g')
    
    if ! command_exists curl; then
        log_message "ERROR" "curl command not found, cannot send webhook notification"
        echo "[ERROR] curl command not found, cannot send webhook notification"
        return 1
    fi
    
    log_message "INFO" "Sending webhook notification to $url"
    local payload=$(format_webhook_payload "$url" "$title" "$message")
    
    # Log the payload for debugging
    log_message "DEBUG" "Webhook payload: $payload"
    
    local response status_code body
    if [ $HAS_JQ -eq 1 ]; then
        response=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        status_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        echo "[DEBUG] HTTP status: $status_code"
        echo "[DEBUG] Response body: $body"
        
        log_message "DEBUG" "Response status: $status_code, body: $body"
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $status_code)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $status_code, Response: $body)"
            return 1
        fi
    else
        status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        echo "[DEBUG] HTTP status: $status_code"
        
        log_message "DEBUG" "Response status: $status_code"
        
        if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
            log_message "INFO" "Webhook notification sent successfully (Status: $status_code)"
            return 0
        else
            log_message "ERROR" "Failed to send webhook notification (Status: $status_code)"
            return 1
        fi
    fi
}
