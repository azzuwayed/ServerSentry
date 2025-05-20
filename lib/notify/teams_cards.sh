#!/bin/bash
#
# ServerSentry - Microsoft Teams Cards Module
# Part of the modular notify system

# Check if utils.sh is sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PARENT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [[ "$(type -t log_message)" != "function" ]]; then
    source "$PARENT_DIR/lib/utils.sh"
fi

# Make sure we have access to system_info.sh functions
if [[ "$(type -t extract_from_system_info)" != "function" ]]; then
    source "$SCRIPT_DIR/system_info.sh"
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

# Create adaptive card JSON for Microsoft Teams
create_adaptive_card() {
    local title="$1"
    local message="$2"
    local system_info="$3"
    local status="$4"
    local timestamp="$5"
    
    # Extract system info from JSON
    local hostname=$(extract_from_system_info "$system_info" "hostname")
    local os=$(extract_from_system_info "$system_info" "os")
    local kernel=$(extract_from_system_info "$system_info" "kernel")
    local uptime=$(extract_from_system_info "$system_info" "uptime")
    local loadavg=$(extract_from_system_info "$system_info" "loadavg")
    local ip=$(extract_from_system_info "$system_info" "ip")
    local cpu_info=$(extract_from_system_info "$system_info" "cpu_info")
    local cpu_usage=$(extract_from_system_info "$system_info" "cpu_usage")
    local memory_info=$(extract_from_system_info "$system_info" "memory_info")
    local memory_usage=$(extract_from_system_info "$system_info" "memory_usage")
    local disk_info=$(extract_from_system_info "$system_info" "disk_info")
    local disk_usage=$(extract_from_system_info "$system_info" "disk_usage")
    
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

# Create Teams-formatted message card for attachments array
create_teams_message_card() {
    local title="$1"
    local message="$2"
    local system_info="$3"
    local status="$4"
    local timestamp="$5"
    
    # Extract necessary info
    local hostname=$(extract_from_system_info "$system_info" "hostname")
    local os=$(extract_from_system_info "$system_info" "os")
    local kernel=$(extract_from_system_info "$system_info" "kernel")
    local uptime=$(extract_from_system_info "$system_info" "uptime")
    local loadavg=$(extract_from_system_info "$system_info" "loadavg")
    local ip=$(extract_from_system_info "$system_info" "ip")
    local cpu_info=$(extract_from_system_info "$system_info" "cpu_info")
    local cpu_usage=$(extract_from_system_info "$system_info" "cpu_usage")
    local memory_info=$(extract_from_system_info "$system_info" "memory_info")
    local memory_usage=$(extract_from_system_info "$system_info" "memory_usage")
    local disk_info=$(extract_from_system_info "$system_info" "disk_info")
    local disk_usage=$(extract_from_system_info "$system_info" "disk_usage")
    
    # Escape message text
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
    
    echo "$teams_card"
} 