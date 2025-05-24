#!/bin/bash
#
# ServerSentry v2 - Disk Monitoring Plugin
#
# This plugin monitors disk usage and alerts when thresholds are exceeded

# Plugin metadata
disk_plugin_name="disk"
disk_plugin_version="1.0"
disk_plugin_description="Monitors disk usage and performance"
disk_plugin_author="ServerSentry Team"

# Default configuration
disk_threshold=90
disk_warning_threshold=80
disk_check_interval=300
disk_monitored_paths="/"
disk_exclude_types="tmpfs,devtmpfs,squashfs,overlay"
disk_exclude_mounts=""

# Return plugin information
disk_plugin_info() {
  echo "Disk Monitoring Plugin v${disk_plugin_version}"
}

# Configure the plugin
disk_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if ! [[ "$disk_threshold" =~ ^[0-9]+$ ]] || [ "$disk_threshold" -gt 100 ]; then
    log_error "Invalid disk threshold: $disk_threshold (must be 0-100)"
    return 1
  fi

  if ! [[ "$disk_warning_threshold" =~ ^[0-9]+$ ]] || [ "$disk_warning_threshold" -gt 100 ]; then
    log_error "Invalid disk warning threshold: $disk_warning_threshold (must be 0-100)"
    return 1
  fi

  if [ "$disk_warning_threshold" -gt "$disk_threshold" ]; then
    log_warning "Warning threshold ($disk_warning_threshold) is higher than critical threshold ($disk_threshold), swapping values"
    local temp=$disk_threshold
    disk_threshold=$disk_warning_threshold
    disk_warning_threshold=$temp
  fi

  log_debug "Disk plugin configured with: threshold=$disk_threshold, warning=$disk_warning_threshold"

  return 0
}

# Perform disk check
disk_plugin_check() {
  local highest_usage=0
  local most_used_mount=""
  local status_code=0
  local status_message="OK"
  local all_mounts=()
  local all_usage=()
  local all_sizes=()
  local all_used=()
  local all_avail=()

  # Check if df command exists using compatibility layer
  if ! compat_command_exists df; then
    status_code=3
    status_message="Cannot determine disk usage: 'df' command not found"

    # Create empty results
    local timestamp
    if compat_command_exists compat_date; then
      timestamp=$(compat_date --iso-8601=seconds)
    else
      timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)
    fi

    cat <<EOF
{
  "plugin": "disk",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "highest_usage": 0,
    "most_used_mount": "",
    "mounts": [],
    "threshold": ${disk_threshold},
    "warning_threshold": ${disk_warning_threshold}
  },
  "timestamp": "${timestamp}"
}
EOF
    return 0
  fi

  # Get disk information using compatibility layer
  local df_output
  df_output=$(compat_df -kP 2>/dev/null)

  # Fallback to regular df if compatibility function fails
  if [[ -z "$df_output" ]]; then
    df_output=$(df -kP 2>/dev/null)
  fi

  # If still no output, use OS-specific approach
  if [[ -z "$df_output" ]]; then
    local os_type
    os_type=$(compat_get_os)

    case "$os_type" in
    macos)
      # macOS sometimes needs different df flags
      df_output=$(df -k 2>/dev/null)
      ;;
    linux)
      # Linux standard df
      df_output=$(df -kP 2>/dev/null)
      ;;
    *)
      df_output=$(df 2>/dev/null)
      ;;
    esac
  fi

  # Check if we got any output
  if [[ -z "$df_output" ]]; then
    status_code=3
    status_message="Cannot determine disk usage: no output from df command"

    local timestamp
    if compat_command_exists compat_date; then
      timestamp=$(compat_date --iso-8601=seconds)
    else
      timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)
    fi

    cat <<EOF
{
  "plugin": "disk",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "highest_usage": 0,
    "most_used_mount": "",
    "mounts": [],
    "threshold": ${disk_threshold},
    "warning_threshold": ${disk_warning_threshold}
  },
  "timestamp": "${timestamp}"
}
EOF
    return 0
  fi

  # Convert monitored paths to array
  IFS=',' read -r -a monitored_paths <<<"$disk_monitored_paths"

  # Convert exclude mounts to array
  IFS=',' read -r -a exclude_mounts <<<"$disk_exclude_mounts"

  # Convert exclude types to array
  IFS=',' read -r -a exclude_types <<<"$disk_exclude_types"

  # Parse df output line by line, skipping the header
  while read -r line; do
    local fs usage mount used avail size

    # Skip the header line
    if [[ $line == Filesystem* ]]; then
      continue
    fi

    # Extract filesystem, used space, available space, size, usage percentage, and mount point
    read -r fs size used avail usage mount <<<"$line"

    # Remove % from usage
    usage=${usage/\%/}

    # Skip if this mount is in exclude_mounts
    local skip=false
    for exclude_mount in "${exclude_mounts[@]}"; do
      if [ "$mount" = "$exclude_mount" ]; then
        skip=true
        break
      fi
    done
    [ "$skip" = true ] && continue

    # Skip if this filesystem type is in exclude_types
    for exclude_type in "${exclude_types[@]}"; do
      if [[ $fs == *$exclude_type* ]]; then
        skip=true
        break
      fi
    done
    [ "$skip" = true ] && continue

    # Check if we should include this mount
    local include=false
    if [ ${#monitored_paths[@]} -eq 0 ] || [ "${monitored_paths[0]}" = "" ]; then
      # If no paths specified, include all
      include=true
    else
      # Check if this mount matches any of the monitored paths
      for monitored_path in "${monitored_paths[@]}"; do
        if [ "$mount" = "$monitored_path" ] || [[ "$mount" == $monitored_path/* ]]; then
          include=true
          break
        fi
      done
    fi

    # Skip if we shouldn't include this mount
    [ "$include" = false ] && continue

    # Add to arrays
    all_mounts+=("$mount")
    all_usage+=("$usage")
    all_sizes+=("$size")
    all_used+=("$used")
    all_avail+=("$avail")

    # Update highest usage if needed
    if [ "$usage" -gt "$highest_usage" ]; then
      highest_usage=$usage
      most_used_mount=$mount
    fi
  done <<<"$df_output"

  # Check if any mounts were found
  if [ ${#all_mounts[@]} -eq 0 ]; then
    status_code=3
    status_message="No monitored disks found"
  else
    # Check thresholds based on highest usage
    if [ "$highest_usage" -ge "$disk_threshold" ]; then
      status_code=2
      status_message="CRITICAL: Disk usage at ${most_used_mount} is ${highest_usage}%, threshold: ${disk_threshold}%"
    elif [ "$highest_usage" -ge "$disk_warning_threshold" ]; then
      status_code=1
      status_message="WARNING: Disk usage at ${most_used_mount} is ${highest_usage}%, threshold: ${disk_warning_threshold}%"
    else
      status_message="OK: Highest disk usage is ${highest_usage}% at ${most_used_mount}"
    fi
  fi

  # Get timestamp
  local timestamp
  timestamp=$(get_timestamp)

  # Create JSON for mounts
  local mounts_json=""
  for i in "${!all_mounts[@]}"; do
    local mount="${all_mounts[$i]}"
    local usage="${all_usage[$i]}"
    local size="${all_sizes[$i]}"
    local used="${all_used[$i]}"
    local avail="${all_avail[$i]}"

    # Convert to human-readable format
    local size_human=$(format_bytes "$((size * 1024))")
    local used_human=$(format_bytes "$((used * 1024))")
    local avail_human=$(format_bytes "$((avail * 1024))")

    # Add to JSON
    if [ "$i" -gt 0 ]; then
      mounts_json+=","
    fi

    mounts_json+=$(
      cat <<EOF
    {
      "mount": "${mount}",
      "usage": ${usage},
      "size": ${size},
      "used": ${used},
      "avail": ${avail},
      "size_human": "${size_human}",
      "used_human": "${used_human}",
      "avail_human": "${avail_human}"
    }
EOF
    )
  done

  # Return standardized output format
  cat <<EOF
{
  "plugin": "disk",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "highest_usage": ${highest_usage},
    "most_used_mount": "${most_used_mount}",
    "mounts": [${mounts_json}],
    "threshold": ${disk_threshold},
    "warning_threshold": ${disk_warning_threshold}
  },
  "timestamp": "${timestamp}"
}
EOF
}
