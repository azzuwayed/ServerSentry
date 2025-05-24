#!/bin/bash
#
# ServerSentry v2 - Periodic Monitoring
#
# This module handles periodic monitoring and scheduling

# Periodic monitoring configuration
PERIODIC_CONFIG="${CONFIG_DIR}/periodic.yaml"
PERIODIC_RESULTS_DIR="${BASE_DIR}/logs/periodic"
PERIODIC_STATE_FILE="${PERIODIC_RESULTS_DIR}/state.json"
PERIODIC_NAMESPACE="periodic"

# Initialize periodic monitoring system
init_periodic_system() {
  log_debug "Initializing periodic monitoring system"

  # Make sure periodic directories exist
  if [ ! -d "$PERIODIC_RESULTS_DIR" ]; then
    log_warning "Periodic results directory not found: $PERIODIC_RESULTS_DIR"
    log_info "Creating periodic results directory"
    mkdir -p "$PERIODIC_RESULTS_DIR" || return 1
  fi

  # Check if periodic config exists, create if needed
  if [ ! -f "$PERIODIC_CONFIG" ]; then
    log_warning "Periodic configuration file not found: $PERIODIC_CONFIG"
    log_info "Creating default periodic configuration file"
    create_default_periodic_config || return 1
  fi

  # Initialize state file if it doesn't exist
  if [ ! -f "$PERIODIC_STATE_FILE" ]; then
    log_debug "Creating periodic state file"
    echo "{}" >"$PERIODIC_STATE_FILE"
  fi

  log_info "Periodic monitoring system initialized"

  return 0
}

# Create default periodic configuration
create_default_periodic_config() {
  log_debug "Creating default periodic configuration file: $PERIODIC_CONFIG"

  # Create parent directory if it doesn't exist
  mkdir -p "$(dirname "$PERIODIC_CONFIG")" || return 1

  # Create basic configuration file
  cat >"$PERIODIC_CONFIG" <<EOF
# ServerSentry v2 Periodic Monitoring Configuration

# Enable periodic monitoring
enabled: true

# Interval between full system reports (in hours)
report_interval: 24

# Notification settings for periodic reports
notify_on_report: true

# Report retention (number of reports to keep)
report_retention: 30

# Silence period after alerts (in minutes)
silence_period: 60

# Emergency notification settings
emergency_contacts: []
emergency_threshold: 3
EOF

  return 0
}

# Get periodic configuration value
get_periodic_config() {
  local key="$1"
  local default_value="${2:-}"

  local var_name="${PERIODIC_NAMESPACE}_${key}"
  local value="${!var_name}"

  # Return the value or default
  if [ -z "$value" ]; then
    echo "$default_value"
  else
    echo "$value"
  fi
}

# Set periodic configuration value
set_periodic_config() {
  local key="$1"
  local value="$2"

  # Validate inputs
  if [ -z "$key" ] || [ -z "$value" ]; then
    log_error "Invalid periodic configuration: key=$key, value=$value"
    return 1
  fi

  log_debug "Setting periodic config: $key = $value"
  eval "${PERIODIC_NAMESPACE}_${key}=\"$value\""

  # TODO: Persist to config file

  return 0
}

# Update last alert timestamp for a plugin
update_last_alert_time() {
  local plugin_name="$1"

  # Update state file
  local timestamp=$(get_timestamp)
  local temp_file=$(mktemp)

  if [ -f "$PERIODIC_STATE_FILE" ] && [ -s "$PERIODIC_STATE_FILE" ]; then
    # Try to use jq if available
    if command_exists jq; then
      jq --arg plugin "$plugin_name" --arg time "$timestamp" \
        '.last_alerts[$plugin] = $time' \
        "$PERIODIC_STATE_FILE" >"$temp_file"
    else
      # Simple sed-based approach if jq is not available
      # This is a simplified implementation
      if grep -q "\"$plugin_name\"" "$PERIODIC_STATE_FILE"; then
        sed "s/\"$plugin_name\": \"[0-9]*\"/\"$plugin_name\": \"$timestamp\"/" \
          "$PERIODIC_STATE_FILE" >"$temp_file"
      else
        # Add new entry
        sed "s/{/{\"$plugin_name\": \"$timestamp\", /" \
          "$PERIODIC_STATE_FILE" >"$temp_file"
      fi
    fi

    mv "$temp_file" "$PERIODIC_STATE_FILE"
  else
    # Create new state file
    echo "{\"last_alerts\": {\"$plugin_name\": \"$timestamp\"}}" >"$PERIODIC_STATE_FILE"
  fi
}

# Check if an alert for a plugin is currently in silence period
is_in_silence_period() {
  local plugin_name="$1"

  # Get silence period from config
  local silence_period
  silence_period=$(get_periodic_config "silence_period" "60")
  silence_period=$((silence_period * 60)) # Convert to seconds

  # Get last alert time for this plugin
  local last_alert_time=0

  if [ -f "$PERIODIC_STATE_FILE" ] && [ -s "$PERIODIC_STATE_FILE" ]; then
    # Try to use jq if available
    if command_exists jq; then
      last_alert_time=$(jq -r ".last_alerts.\"$plugin_name\" // 0" "$PERIODIC_STATE_FILE")
    else
      # Simple grep-based approach if jq is not available
      local time_entry
      time_entry=$(grep -o "\"$plugin_name\": \"[0-9]*\"" "$PERIODIC_STATE_FILE" | grep -o "[0-9]*")
      if [ -n "$time_entry" ]; then
        last_alert_time=$time_entry
      fi
    fi
  fi

  # Check if we're still in the silence period
  local current_time
  current_time=$(get_timestamp)
  local elapsed_time=$((current_time - last_alert_time))

  if [ "$elapsed_time" -lt "$silence_period" ]; then
    return 0 # Yes, still in silence period
  else
    return 1 # No, not in silence period
  fi
}

# Generate system report with all plugin data
generate_system_report() {
  log_info "Generating system report"

  local report_file="${PERIODIC_RESULTS_DIR}/report_$(date +%Y%m%d_%H%M%S).json"
  local report_data="{}"
  local current_time
  current_time=$(get_timestamp)

  # Add system information
  local hostname
  hostname=$(hostname)
  local os_type
  os_type=$(get_os_type)
  local os_version
  if [ "$os_type" = "linux" ]; then
    if [ -f /etc/os-release ]; then
      os_version=$(source /etc/os-release && echo "$PRETTY_NAME")
    else
      os_version=$(uname -r)
    fi
  elif [ "$os_type" = "macos" ]; then
    os_version=$(sw_vers -productVersion)
  else
    os_version=$(uname -r)
  fi

  # Basic system info
  report_data=$(echo "$report_data" | jq --arg hostname "$hostname" \
    --arg os_type "$os_type" \
    --arg os_version "$os_version" \
    --arg timestamp "$current_time" \
    '. + {
      "system_info": {
        "hostname": $hostname,
        "os_type": $os_type, 
        "os_version": $os_version
      },
      "timestamp": $timestamp,
      "plugins": {}
    }')

  # Run all plugin checks and add to report
  for plugin_name in "${registered_plugins[@]}"; do
    log_debug "Adding $plugin_name data to system report"

    local plugin_result
    plugin_result=$(run_plugin_check "$plugin_name" "false")
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
      # Add plugin data to report
      report_data=$(echo "$report_data" | jq --arg name "$plugin_name" \
        --argjson data "$(echo "$plugin_result" | jq '.')" \
        '.plugins[$name] = $data')
    else
      log_warning "Failed to get data from plugin $plugin_name for system report"
    fi
  done

  # Save the report
  echo "$report_data" >"$report_file"
  log_info "System report saved to $report_file"

  # Clean up old reports
  cleanup_old_reports

  # Send notification if configured
  local notify_on_report
  notify_on_report=$(get_periodic_config "notify_on_report" "true")

  if [ "$notify_on_report" = "true" ]; then
    log_info "Sending system report notification"
    # Check if notifications module is available
    if declare -f send_notification >/dev/null; then
      send_notification "0" "System Report Generated" "system" "$report_data"
    fi
  fi

  return 0
}

# Clean up old reports based on retention policy
cleanup_old_reports() {
  local report_retention
  report_retention=$(get_periodic_config "report_retention" "30")

  # Keep only the N most recent reports
  if [ -d "$PERIODIC_RESULTS_DIR" ]; then
    # Find all report files and sort by modification time (newest first)
    local all_reports
    all_reports=$(ls -t "${PERIODIC_RESULTS_DIR}"/report_*.json 2>/dev/null)

    # Count reports
    local report_count
    report_count=$(echo "$all_reports" | wc -l)

    # Remove excess reports
    if [ "$report_count" -gt "$report_retention" ]; then
      log_debug "Cleaning up old reports (keeping $report_retention of $report_count)"
      echo "$all_reports" | tail -n +$((report_retention + 1)) | xargs rm -f
    fi
  fi
}

# Check if it's time to generate a system report
should_generate_report() {
  # Get report interval from config
  local report_interval
  report_interval=$(get_periodic_config "report_interval" "24")
  report_interval=$((report_interval * 3600)) # Convert to seconds

  # Get last report time
  local last_report_time=0

  if [ -f "$PERIODIC_STATE_FILE" ] && [ -s "$PERIODIC_STATE_FILE" ]; then
    # Try to use jq if available
    if command_exists jq; then
      last_report_time=$(jq -r ".last_report // 0" "$PERIODIC_STATE_FILE")
    else
      # Simple grep-based approach if jq is not available
      local time_entry
      time_entry=$(grep -o "\"last_report\": \"[0-9]*\"" "$PERIODIC_STATE_FILE" | grep -o "[0-9]*")
      if [ -n "$time_entry" ]; then
        last_report_time=$time_entry
      fi
    fi
  fi

  # Check if it's time for a new report
  local current_time
  current_time=$(get_timestamp)
  local elapsed_time=$((current_time - last_report_time))

  if [ "$elapsed_time" -ge "$report_interval" ]; then
    # Update last report time
    local temp_file=$(mktemp)

    if [ -f "$PERIODIC_STATE_FILE" ] && [ -s "$PERIODIC_STATE_FILE" ]; then
      # Try to use jq if available
      if command_exists jq; then
        jq --arg time "$current_time" \
          '. + {"last_report": $time}' \
          "$PERIODIC_STATE_FILE" >"$temp_file"
      else
        # Simple sed-based approach if jq is not available
        if grep -q "\"last_report\"" "$PERIODIC_STATE_FILE"; then
          sed "s/\"last_report\": \"[0-9]*\"/\"last_report\": \"$current_time\"/" \
            "$PERIODIC_STATE_FILE" >"$temp_file"
        else
          # Add new entry
          sed "s/{/{\"last_report\": \"$current_time\", /" \
            "$PERIODIC_STATE_FILE" >"$temp_file"
        fi
      fi

      mv "$temp_file" "$PERIODIC_STATE_FILE"
    else
      # Create new state file
      echo "{\"last_report\": \"$current_time\"}" >"$PERIODIC_STATE_FILE"
    fi

    return 0 # Yes, should generate report
  else
    return 1 # No, too soon
  fi
}

# Run periodic monitoring tasks (meant to be called from cron)
run_periodic_monitoring() {
  log_debug "Running periodic monitoring tasks"

  # Check if periodic monitoring is enabled
  local enabled
  enabled=$(get_periodic_config "enabled" "true")

  if [ "$enabled" != "true" ]; then
    log_info "Periodic monitoring is disabled"
    return 0
  fi

  # Check if it's time to generate a system report
  if should_generate_report; then
    generate_system_report
  fi

  # Run all plugin checks
  run_all_plugin_checks

  return 0
}

# Show status of periodic monitoring
show_periodic_status() {
  echo "=== Periodic Monitoring Status ==="

  # Check if periodic monitoring is enabled
  local enabled
  enabled=$(get_periodic_config "enabled" "true")

  echo "Enabled: $enabled"

  # Get report interval
  local report_interval
  report_interval=$(get_periodic_config "report_interval" "24")

  echo "Report Interval: $report_interval hours"

  # Get silence period
  local silence_period
  silence_period=$(get_periodic_config "silence_period" "60")

  echo "Alert Silence Period: $silence_period minutes"

  # Get last report time
  local last_report_time=0

  if [ -f "$PERIODIC_STATE_FILE" ] && [ -s "$PERIODIC_STATE_FILE" ]; then
    # Try to use jq if available
    if command_exists jq; then
      last_report_time=$(jq -r ".last_report // 0" "$PERIODIC_STATE_FILE")
    else
      # Simple grep-based approach if jq is not available
      local time_entry
      time_entry=$(grep -o "\"last_report\": \"[0-9]*\"" "$PERIODIC_STATE_FILE" | grep -o "[0-9]*")
      if [ -n "$time_entry" ]; then
        last_report_time=$time_entry
      fi
    fi
  fi

  if [ "$last_report_time" -gt 0 ]; then
    local formatted_time
    formatted_time=$(date -r "$last_report_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

    # If date -r doesn't work (like on some Linux systems), try alternative
    if [ -z "$formatted_time" ]; then
      formatted_time=$(date -d "@$last_report_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    fi

    if [ -z "$formatted_time" ]; then
      formatted_time="$last_report_time (timestamp)"
    fi

    echo "Last Report: $formatted_time"

    # Calculate next report time
    local report_interval_seconds=$((report_interval * 3600))
    local next_report_time=$((last_report_time + report_interval_seconds))
    local next_formatted_time
    next_formatted_time=$(date -r "$next_report_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

    # If date -r doesn't work (like on some Linux systems), try alternative
    if [ -z "$next_formatted_time" ]; then
      next_formatted_time=$(date -d "@$next_report_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    fi

    if [ -z "$next_formatted_time" ]; then
      next_formatted_time="$next_report_time (timestamp)"
    fi

    echo "Next Report: $next_formatted_time"
  else
    echo "Last Report: Never"
    echo "Next Report: On next check"
  fi

  # Show report retention
  local report_retention
  report_retention=$(get_periodic_config "report_retention" "30")

  echo "Report Retention: $report_retention reports"

  # Count existing reports
  local report_count=0
  if [ -d "$PERIODIC_RESULTS_DIR" ]; then
    report_count=$(ls -1 "${PERIODIC_RESULTS_DIR}"/report_*.json 2>/dev/null | wc -l)
  fi

  echo "Existing Reports: $report_count"

  echo ""
  echo "Alert Status:"

  # Show alert silence status for each plugin
  for plugin_name in "${registered_plugins[@]}"; do
    if is_in_silence_period "$plugin_name"; then
      echo "  $plugin_name: In silence period"
    else
      echo "  $plugin_name: Ready to alert"
    fi
  done
}

# Initialize periodic system when module is loaded
init_periodic_system
