#!/usr/bin/env bash
#
# ServerSentry v2 - CPU Monitoring Plugin
#
# This plugin monitors CPU usage and alerts when thresholds are exceeded

# Plugin metadata
cpu_plugin_name="cpu"
cpu_plugin_version="1.0"
cpu_plugin_description="Monitors CPU usage and performance"
cpu_plugin_author="ServerSentry Team"

# Default configuration
cpu_threshold=80
cpu_warning_threshold=70
cpu_check_interval=60
cpu_include_iowait=true

# Return plugin information
cpu_plugin_info() {
  echo "CPU Monitoring Plugin v${cpu_plugin_version}"
}

# Configure the plugin
cpu_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if ! [[ "$cpu_threshold" =~ ^[0-9]+$ ]] || [ "$cpu_threshold" -gt 100 ]; then
    log_error "Invalid CPU threshold: $cpu_threshold (must be 0-100)"
    return 1
  fi

  if ! [[ "$cpu_warning_threshold" =~ ^[0-9]+$ ]] || [ "$cpu_warning_threshold" -gt 100 ]; then
    log_error "Invalid CPU warning threshold: $cpu_warning_threshold (must be 0-100)"
    return 1
  fi

  if [ "$cpu_warning_threshold" -gt "$cpu_threshold" ]; then
    log_warning "Warning threshold ($cpu_warning_threshold) is higher than critical threshold ($cpu_threshold), swapping values"
    local temp=$cpu_threshold
    cpu_threshold=$cpu_warning_threshold
    cpu_warning_threshold=$temp
  fi

  log_debug "CPU plugin configured with: threshold=$cpu_threshold, warning=$cpu_warning_threshold"

  return 0
}

# Perform CPU check
cpu_plugin_check() {
  local result
  local status_code=0
  local status_message="OK"

  # Get CPU usage using compatibility layer
  result=$(compat_get_cpu_usage 2>/dev/null)

  # Check if we got a valid result
  if [[ -z "$result" || "$result" == "0.0" ]]; then
    # Fallback to OS-specific methods if compatibility layer fails
    local os_type
    os_type=$(compat_get_os)

    case "$os_type" in
    linux)
      # Linux-style - using /proc/stat if available
      if [[ -r /proc/stat ]]; then
        result=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if (NR==1){u1=u; t1=t;} else print (u-u1) * 100 / (t-t1); }' <(
          grep 'cpu ' /proc/stat
          sleep 1
          grep 'cpu ' /proc/stat
        ) 2>/dev/null)
      elif compat_command_exists top; then
        result=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
      else
        result="unknown"
        status_code=3
        status_message="Cannot determine CPU usage: required commands not found"
      fi
      ;;

    macos)
      # macOS-style - using iostat if available
      if compat_command_exists iostat; then
        result=$(iostat -c 1 2 2>/dev/null | tail -1 | awk '{print 100 - $6}')
      elif compat_command_exists top; then
        result=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d "%")
      else
        result="unknown"
        status_code=3
        status_message="Cannot determine CPU usage: required commands not found"
      fi
      ;;

    *)
      # Unsupported OS
      result="unknown"
      status_code=3
      status_message="Unsupported OS type: $os_type"
      ;;
    esac
  fi

  # Check thresholds if we got a numeric result
  if [[ "$result" =~ ^[0-9.]+$ ]]; then
    # Format to one decimal place
    result=$(printf "%.1f" "$result")

    if (($(echo "$result >= $cpu_threshold" | bc -l 2>/dev/null || awk -v a="$result" -v b="$cpu_threshold" 'BEGIN{print (a>=b)?"1":"0"}'))); then
      status_code=2
      status_message="CRITICAL: CPU usage is ${result}%, threshold: ${cpu_threshold}%"
    elif (($(echo "$result >= $cpu_warning_threshold" | bc -l 2>/dev/null || awk -v a="$result" -v b="$cpu_warning_threshold" 'BEGIN{print (a>=b)?"1":"0"}'))); then
      status_code=1
      status_message="WARNING: CPU usage is ${result}%, threshold: ${cpu_warning_threshold}%"
    else
      status_message="OK: CPU usage is ${result}%"
    fi
  elif [[ "$result" == "unknown" && "$status_code" -eq 0 ]]; then
    status_code=3
    status_message="Cannot determine CPU usage"
  fi

  # Get timestamp using compatibility layer if available
  local timestamp
  timestamp=$(get_timestamp)

  # Return standardized output format
  cat <<EOF
{
  "plugin": "cpu",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "usage_percent": ${result},
    "threshold": ${cpu_threshold},
    "warning_threshold": ${cpu_warning_threshold}
  },
  "timestamp": "${timestamp}"
}
EOF
}
