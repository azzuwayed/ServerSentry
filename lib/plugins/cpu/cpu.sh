#!/usr/bin/env bash
#
# ServerSentry v2 - CPU Monitoring Plugin
#
# This plugin monitors CPU usage, load average, and related metrics

# Plugin metadata
CPU_PLUGIN_VERSION="2.0.0"
CPU_PLUGIN_AUTHOR="ServerSentry Team"
CPU_PLUGIN_DESCRIPTION="CPU usage and load average monitoring"

# Default configuration
CPU_THRESHOLD=85
CPU_WARNING_THRESHOLD=75
CPU_CHECK_INTERVAL=30
CPU_LOAD_THRESHOLD=10.0

# Plugin information function
cpu_plugin_info() {
  echo "CPU Monitor v${CPU_PLUGIN_VERSION} - ${CPU_PLUGIN_DESCRIPTION}"
}

# Plugin configuration function
cpu_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
  fi

  # Validate thresholds
  if [[ "$CPU_THRESHOLD" -lt 1 || "$CPU_THRESHOLD" -gt 100 ]]; then
    log_warning "Invalid CPU_THRESHOLD: $CPU_THRESHOLD, using default: 85"
    CPU_THRESHOLD=85
  fi

  if [[ "$CPU_WARNING_THRESHOLD" -lt 1 || "$CPU_WARNING_THRESHOLD" -gt 100 ]]; then
    log_warning "Invalid CPU_WARNING_THRESHOLD: $CPU_WARNING_THRESHOLD, using default: 75"
    CPU_WARNING_THRESHOLD=75
  fi

  # Ensure warning threshold is less than critical threshold
  if [[ "$CPU_WARNING_THRESHOLD" -ge "$CPU_THRESHOLD" ]]; then
    CPU_WARNING_THRESHOLD=$((CPU_THRESHOLD - 10))
    log_warning "Adjusted CPU_WARNING_THRESHOLD to $CPU_WARNING_THRESHOLD (must be less than critical threshold)"
  fi

  return 0
}

# Main CPU check function
cpu_plugin_check() {
  local cpu_usage
  local load_avg
  local status_code=0
  local status_message=""

  # Get CPU usage
  cpu_usage=$(get_cpu_usage)
  if [[ $? -ne 0 || -z "$cpu_usage" ]]; then
    status_code=2
    status_message="Failed to retrieve CPU usage"

    # Create error JSON using utility function
    if declare -f util_json_create_status_object >/dev/null 2>&1; then
      local metrics='{"usage_percent":"N/A","threshold":'$CPU_THRESHOLD',"warning_threshold":'$CPU_WARNING_THRESHOLD',"load_average":"N/A"}'
      util_json_create_status_object "$status_code" "$status_message" "cpu" "$metrics"
    else
      # Fallback JSON format
      echo '{"status_code":'$status_code',"status_message":"'"$status_message"'","plugin":"cpu","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","metrics":{"usage_percent":"N/A","threshold":'$CPU_THRESHOLD',"warning_threshold":'$CPU_WARNING_THRESHOLD',"load_average":"N/A"}}'
    fi
    return 1
  fi

  # Get load average
  load_avg=$(get_load_average)
  if [[ $? -ne 0 || -z "$load_avg" ]]; then
    load_avg="0.00"
  fi

  # Determine status based on thresholds
  local cpu_int=${cpu_usage%.*} # Remove decimal part for comparison
  if [[ "$cpu_int" -ge "$CPU_THRESHOLD" ]]; then
    status_code=2
    status_message="High CPU usage: ${cpu_usage}%"
  elif [[ "$cpu_int" -ge "$CPU_WARNING_THRESHOLD" ]]; then
    status_code=1
    status_message="Elevated CPU usage: ${cpu_usage}%"
  else
    status_code=0
    status_message="CPU usage normal: ${cpu_usage}%"
  fi

  # Create metrics object
  local metrics='{"usage_percent":'$cpu_usage',"threshold":'$CPU_THRESHOLD',"warning_threshold":'$CPU_WARNING_THRESHOLD',"load_average":'$load_avg'}'

  # Output JSON result
  if declare -f util_json_create_status_object >/dev/null 2>&1; then
    util_json_create_status_object "$status_code" "$status_message" "cpu" "$metrics"
  else
    # Fallback JSON format
    echo '{"status_code":'$status_code',"status_message":"'"$status_message"'","plugin":"cpu","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","metrics":'"$metrics"'}'
  fi

  return 0
}

# Get CPU usage percentage
get_cpu_usage() {
  local cpu_usage

  # Try different methods based on OS and available tools
  # Skip iostat on macOS as it can hang, use top instead
  if util_command_exists top; then
    # Fallback to top command
    case "$(uname -s)" in
    Darwin*)
      # macOS top format - try multiple parsing methods
      # Method 1: Parse "CPU usage" line
      cpu_usage=$(top -l 2 -n 0 | grep "CPU usage" | tail -1 | awk '{print $3}' | tr -d '%' 2>/dev/null)

      # Method 2: If that fails, try parsing the user/sys/idle line
      if [[ -z "$cpu_usage" || "$cpu_usage" == "0.0" ]]; then
        # Parse format like "CPU usage: 12.34% user, 5.67% sys, 81.99% idle"
        local cpu_line
        cpu_line=$(top -l 2 -n 0 | grep "CPU usage" | tail -1)
        if [[ "$cpu_line" =~ ([0-9]+\.[0-9]+)%[[:space:]]+user.*([0-9]+\.[0-9]+)%[[:space:]]+sys ]]; then
          local user_cpu="${BASH_REMATCH[1]}"
          local sys_cpu="${BASH_REMATCH[2]}"
          cpu_usage=$(echo "$user_cpu + $sys_cpu" | bc -l 2>/dev/null | awk '{printf "%.1f", $1}')
        fi
      fi

      # Method 3: If still no result, use iostat as fallback
      if [[ -z "$cpu_usage" || "$cpu_usage" == "0.0" ]] && command -v iostat >/dev/null 2>&1; then
        # Use iostat with timeout to avoid hanging
        cpu_usage=$(timeout 5 iostat -c 2 | tail -1 | awk '{print 100-$6}' 2>/dev/null)
      fi
      ;;
    Linux*)
      # Linux top format
      cpu_usage=$(top -bn2 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | tr -d '%us,' 2>/dev/null)
      ;;
    *)
      cpu_usage=$(top -bn1 | grep -i "cpu" | head -1 | awk '{print $2}' | tr -d '%' 2>/dev/null)
      ;;
    esac
  elif [[ -r /proc/stat ]]; then
    # Linux /proc/stat method
    cpu_usage=$(awk '/^cpu / {
      idle_prev = idle; total_prev = total
      idle = $5; total = $2 + $3 + $4 + $5 + $6 + $7 + $8
      if (NR > 1) printf "%.1f", (100 * (1 - (idle - idle_prev) / (total - total_prev)))
    }' /proc/stat /proc/stat 2>/dev/null)
  elif util_command_exists sar; then
    # Use sar if available
    cpu_usage=$(sar 1 1 | awk '/^Average:/ && /all/ {print 100 - $8}' 2>/dev/null)
  else
    # Last resort - use uptime load average as approximation
    local load
    load=$(get_load_average)
    if [[ -n "$load" ]]; then
      # Very rough approximation: load * 10 = CPU usage
      cpu_usage=$(echo "$load * 10" | bc -l 2>/dev/null | awk '{printf "%.1f", $1}')
    else
      return 1
    fi
  fi

  # Validate result - allow 0.0 as a valid result, but not empty
  if [[ -z "$cpu_usage" ]]; then
    return 1
  fi

  # Ensure it's a valid number and within range
  if ! echo "$cpu_usage" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    return 1
  fi

  # Cap at 100%
  if (($(echo "$cpu_usage > 100" | bc -l 2>/dev/null || echo 0))); then
    cpu_usage="100.0"
  fi

  echo "$cpu_usage"
  return 0
}

# Get load average (1 minute)
get_load_average() {
  local load_avg

  # Use compatibility function if available
  if declare -f compat_get_load_average >/dev/null 2>&1; then
    load_avg=$(compat_get_load_average)
  elif util_command_exists uptime; then
    # Parse uptime output
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ' 2>/dev/null)
  elif [[ -r /proc/loadavg ]]; then
    # Linux /proc/loadavg
    load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
  else
    load_avg="0.00"
  fi

  # Validate result
  if [[ -z "$load_avg" ]]; then
    load_avg="0.00"
  fi

  echo "$load_avg"
  return 0
}

# Export plugin functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f cpu_plugin_info
  export -f cpu_plugin_configure
  export -f cpu_plugin_check
  export -f get_cpu_usage
  export -f get_load_average
fi
