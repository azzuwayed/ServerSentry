#!/bin/bash
#
# ServerSentry v2 - Process Monitoring Plugin
#
# This plugin monitors critical processes and alerts when they are not running

# Plugin metadata
process_plugin_name="process"
process_plugin_version="1.0"
process_plugin_description="Monitors critical processes"
process_plugin_author="ServerSentry Team"

# Default configuration
process_check_interval=60
process_monitored_processes=""

# Return plugin information
process_plugin_info() {
  echo "Process Monitoring Plugin v${process_plugin_version}"
}

# Configure the plugin
process_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$process_monitored_processes" ]; then
    log_warning "No processes configured for monitoring"
  fi

  log_debug "Process plugin configured to monitor: $process_monitored_processes"

  return 0
}

# Perform process check
process_plugin_check() {
  local status_code=0
  local status_message="OK"
  local missing_processes=()
  local running_processes=()

  # Check if required commands exist using compatibility layer
  if ! compat_command_exists ps && ! compat_command_exists pgrep; then
    status_code=3
    status_message="Cannot check processes: neither 'ps' nor 'pgrep' command found"

    # Create empty results
    local timestamp
    timestamp=$(get_timestamp)

    cat <<EOF
{
  "plugin": "process",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "monitored_count": 0,
    "running_count": 0,
    "missing_count": 0,
    "running_processes": [],
    "missing_processes": []
  },
  "timestamp": "${timestamp}"
}
EOF
    return 0
  fi

  # Split monitored processes into array
  IFS=',' read -r -a processes <<<"$process_monitored_processes"

  # Check each process
  for process in "${processes[@]}"; do
    # Skip empty entries
    [ -z "$process" ] && continue

    local is_running=false

    # Try to find the process using pgrep first (more reliable)
    if compat_command_exists pgrep; then
      if pgrep -f "$process" >/dev/null 2>&1; then
        is_running=true
      fi
    # Fall back to ps if pgrep is not available
    elif compat_command_exists ps; then
      if ps -ef | grep -v grep | grep -q "$process"; then
        is_running=true
      fi
    fi

    # Add to appropriate list
    if [ "$is_running" = true ]; then
      running_processes+=("$process")
    else
      missing_processes+=("$process")
    fi
  done

  # Count processes
  local monitored_count=${#processes[@]}
  local running_count=${#running_processes[@]}
  local missing_count=${#missing_processes[@]}

  # Set status based on missing processes
  if [ "$missing_count" -gt 0 ]; then
    status_code=2
    status_message="CRITICAL: $missing_count monitored processes not running"
  else
    status_message="OK: All $monitored_count monitored processes are running"
  fi

  # Create JSON for running processes
  local running_json=""
  for i in "${!running_processes[@]}"; do
    if [ "$i" -gt 0 ]; then
      running_json+=","
    fi
    running_json+="\"${running_processes[$i]}\""
  done

  # Create JSON for missing processes
  local missing_json=""
  for i in "${!missing_processes[@]}"; do
    if [ "$i" -gt 0 ]; then
      missing_json+=","
    fi
    missing_json+="\"${missing_processes[$i]}\""
  done

  # Get timestamp
  local timestamp
  timestamp=$(get_timestamp)

  # Return standardized output format
  cat <<EOF
{
  "plugin": "process",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "monitored_count": ${monitored_count},
    "running_count": ${running_count},
    "missing_count": ${missing_count},
    "running_processes": [${running_json}],
    "missing_processes": [${missing_json}]
  },
  "timestamp": "${timestamp}"
}
EOF
}
