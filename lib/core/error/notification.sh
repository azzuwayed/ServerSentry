#!/usr/bin/env bash
#
# ServerSentry v2 - Error Notification Module
#
# This module provides error notification and critical error handling

# Function: error_send_notification
# Description: Send error notification through available channels
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   0 - notification sent successfully
#   1 - notification failed
# Example:
#   error_send_notification "$error_context"
# Dependencies:
#   - util_error_validate_input
#   - notification system functions
error_send_notification() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    return 1
  fi

  log_debug "Sending error notification" "error"

  # Extract severity for notification filtering
  local severity
  severity=$(echo "$error_context" | grep -o '"severity": *[0-9]*' | grep -o '[0-9]*' || echo "1")

  # Check if notifications are enabled
  if [[ "${ERROR_NOTIFICATION_ENABLED:-true}" != "true" ]]; then
    log_debug "Error notifications are disabled" "error"
    return 0
  fi

  # Check severity threshold for notifications
  local notification_threshold="${ERROR_NOTIFICATION_THRESHOLD:-2}"
  if [[ "$severity" -lt "$notification_threshold" ]]; then
    log_debug "Error severity ($severity) below notification threshold ($notification_threshold)" "error"
    return 0
  fi

  # Format notification message
  local notification_message
  notification_message=$(error_format_notification_message "$error_context")

  if [[ -z "$notification_message" ]]; then
    log_warning "Failed to format notification message" "error"
    return 1
  fi

  # Try to send through available notification channels
  local notification_sent=false

  # Try webhook notifications
  if _error_send_webhook_notification "$notification_message" "$error_context"; then
    notification_sent=true
    log_debug "Webhook notification sent successfully" "error"
  fi

  # Try email notifications
  if _error_send_email_notification "$notification_message" "$error_context"; then
    notification_sent=true
    log_debug "Email notification sent successfully" "error"
  fi

  # Try system notifications (desktop/system)
  if _error_send_system_notification "$notification_message" "$error_context"; then
    notification_sent=true
    log_debug "System notification sent successfully" "error"
  fi

  # Log notification attempt
  if [[ "$notification_sent" == "true" ]]; then
    log_info "Error notification sent successfully" "error"
    return 0
  else
    log_warning "Failed to send error notification through any channel" "error"
    return 1
  fi
}

# Function: error_handle_critical
# Description: Handle critical errors with enhanced emergency procedures
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   0 - critical error handled
#   1 - critical error handling failed
# Example:
#   error_handle_critical "$error_context"
# Dependencies:
#   - util_error_validate_input
#   - error_send_critical_notification
error_handle_critical() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    return 1
  fi

  log_critical "CRITICAL ERROR DETECTED - Initiating emergency procedures" "error"

  # Send immediate critical error notification
  if ! error_send_critical_notification "$error_context"; then
    log_error "Failed to send critical error notification" "error"
  fi

  # Perform emergency cleanup
  if ! error_emergency_cleanup; then
    log_error "Emergency cleanup failed" "error"
  fi

  # Create critical error report
  local report_file
  report_file=$(error_create_critical_report "$error_context")
  if [[ -n "$report_file" ]]; then
    log_critical "Critical error report created: $report_file" "error"
  fi

  # Attempt to preserve system state
  if ! error_preserve_system_state; then
    log_error "Failed to preserve system state" "error"
  fi

  # Log critical error statistics
  log_critical "Critical error handling completed" "error"

  return 0
}

# Function: error_send_critical_notification
# Description: Send critical error notification with highest priority
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   0 - critical notification sent
#   1 - critical notification failed
# Example:
#   error_send_critical_notification "$error_context"
# Dependencies:
#   - util_error_validate_input
#   - notification functions
error_send_critical_notification() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    return 1
  fi

  log_debug "Sending critical error notification" "error"

  # Format critical notification message
  local critical_message
  critical_message=$(error_format_critical_notification "$error_context")

  if [[ -z "$critical_message" ]]; then
    log_error "Failed to format critical notification message" "error"
    return 1
  fi

  # Send through all available channels for critical errors
  local notification_sent=false

  # High priority webhook notification
  if _error_send_webhook_notification "$critical_message" "$error_context" "critical"; then
    notification_sent=true
  fi

  # High priority email notification
  if _error_send_email_notification "$critical_message" "$error_context" "critical"; then
    notification_sent=true
  fi

  # System alert notification
  if _error_send_system_notification "$critical_message" "$error_context" "critical"; then
    notification_sent=true
  fi

  # Try to send SMS if configured
  if _error_send_sms_notification "$critical_message" "$error_context"; then
    notification_sent=true
  fi

  # Log to system log if available
  if command -v logger >/dev/null 2>&1; then
    logger -p daemon.crit "ServerSentry CRITICAL ERROR: $critical_message"
    notification_sent=true
  fi

  if [[ "$notification_sent" == "true" ]]; then
    log_info "Critical error notification sent successfully" "error"
    return 0
  else
    log_error "Failed to send critical error notification" "error"
    return 1
  fi
}

# Function: error_format_notification_message
# Description: Format error context into notification message
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   Formatted notification message via stdout
# Example:
#   message=$(error_format_notification_message "$context")
# Dependencies:
#   - util_error_validate_input
error_format_notification_message() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    echo "Invalid error context"
    return 1
  fi

  # Extract key information
  local hostname severity_name error_message failed_command timestamp
  hostname=$(echo "$error_context" | grep -o '"hostname": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  severity_name=$(echo "$error_context" | grep -o '"severity_name": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  error_message=$(echo "$error_context" | grep -o '"error_message": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  failed_command=$(echo "$error_context" | grep -o '"failed_command": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  timestamp=$(echo "$error_context" | grep -o '"timestamp": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")

  # Format notification message
  cat <<EOF
🚨 ServerSentry Error Alert

Host: $hostname
Severity: $severity_name
Time: $timestamp

Error: $error_message

Command: $failed_command

Please check the system logs for more details.
EOF

  return 0
}

# Function: error_format_critical_notification
# Description: Format critical error notification with enhanced urgency
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   Formatted critical notification message via stdout
# Example:
#   message=$(error_format_critical_notification "$context")
# Dependencies:
#   - util_error_validate_input
error_format_critical_notification() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    echo "CRITICAL ERROR - Invalid context"
    return 1
  fi

  # Extract key information
  local hostname user error_message failed_command timestamp exit_code
  hostname=$(echo "$error_context" | grep -o '"hostname": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  user=$(echo "$error_context" | grep -o '"user": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  error_message=$(echo "$error_context" | grep -o '"error_message": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  failed_command=$(echo "$error_context" | grep -o '"failed_command": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  timestamp=$(echo "$error_context" | grep -o '"timestamp": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  exit_code=$(echo "$error_context" | grep -o '"exit_code": *[0-9]*' | grep -o '[0-9]*' || echo "unknown")

  # Format critical notification message
  cat <<EOF
🚨🚨🚨 CRITICAL SERVERSENTRY ERROR 🚨🚨🚨

IMMEDIATE ATTENTION REQUIRED

Host: $hostname
User: $user
Time: $timestamp
Exit Code: $exit_code

CRITICAL ERROR: $error_message

Failed Command: $failed_command

This is a critical system error that requires immediate investigation.
Emergency procedures have been initiated.

Please check the system immediately and review error logs.
EOF

  return 0
}

# Function: error_emergency_cleanup
# Description: Perform emergency cleanup procedures for critical errors
# Parameters: None
# Returns:
#   0 - cleanup successful
#   1 - cleanup failed
# Example:
#   error_emergency_cleanup
# Dependencies:
#   - util_error_safe_execute
error_emergency_cleanup() {
  log_debug "Performing emergency cleanup" "error"

  local cleanup_success=true

  # Stop non-essential processes
  if ! _error_stop_nonessential_processes; then
    log_warning "Failed to stop non-essential processes" "error"
    cleanup_success=false
  fi

  # Clean up temporary files aggressively
  if ! _error_aggressive_temp_cleanup; then
    log_warning "Failed to perform aggressive temp cleanup" "error"
    cleanup_success=false
  fi

  # Sync filesystems
  if command -v sync >/dev/null 2>&1; then
    if ! util_error_safe_execute "sync" "Failed to sync filesystems" "" 1; then
      log_warning "Failed to sync filesystems" "error"
      cleanup_success=false
    fi
  fi

  # Free up memory if possible
  if [[ -w /proc/sys/vm/drop_caches ]]; then
    if ! util_error_safe_execute "echo 3 > /proc/sys/vm/drop_caches" "Failed to drop caches" "" 1; then
      log_warning "Failed to drop system caches" "error"
    fi
  fi

  # Create emergency backup of critical files
  if ! _error_backup_critical_files; then
    log_warning "Failed to backup critical files" "error"
    cleanup_success=false
  fi

  if [[ "$cleanup_success" == "true" ]]; then
    log_info "Emergency cleanup completed successfully" "error"
    return 0
  else
    log_warning "Emergency cleanup completed with warnings" "error"
    return 1
  fi
}

# Function: error_create_critical_report
# Description: Create detailed critical error report
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   Report file path via stdout
# Example:
#   report=$(error_create_critical_report "$context")
# Dependencies:
#   - util_error_validate_input
error_create_critical_report() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    return 1
  fi

  # Create reports directory
  local reports_dir="${BASE_DIR}/logs/critical_reports"
  if ! mkdir -p "$reports_dir" 2>/dev/null; then
    log_error "Failed to create critical reports directory" "error"
    return 1
  fi

  # Generate report filename
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local report_file="${reports_dir}/critical_error_${timestamp}.txt"

  # Create comprehensive report
  {
    echo "CRITICAL ERROR REPORT"
    echo "===================="
    echo "Generated: $(date)"
    echo ""

    # Format error context for display
    error_format_context_for_display "$error_context"

    echo ""
    echo "SYSTEM STATE AT TIME OF ERROR"
    echo "============================="

    # System information
    echo "System Information:"
    uname -a 2>/dev/null || echo "uname: not available"
    echo ""

    # Memory information
    echo "Memory Information:"
    if [[ -r /proc/meminfo ]]; then
      head -10 /proc/meminfo 2>/dev/null
    elif command -v vm_stat >/dev/null 2>&1; then
      vm_stat 2>/dev/null
    else
      echo "Memory info: not available"
    fi
    echo ""

    # Disk space
    echo "Disk Space:"
    df -h 2>/dev/null || echo "df: not available"
    echo ""

    # Process information
    echo "Process Information:"
    ps aux 2>/dev/null | head -20 || echo "ps: not available"
    echo ""

    # Network information
    echo "Network Information:"
    if command -v netstat >/dev/null 2>&1; then
      netstat -tuln 2>/dev/null | head -10
    elif command -v ss >/dev/null 2>&1; then
      ss -tuln 2>/dev/null | head -10
    else
      echo "Network info: not available"
    fi
    echo ""

    # Recent log entries
    echo "RECENT LOG ENTRIES"
    echo "=================="
    if [[ -r "${BASE_DIR}/logs/serversentry.log" ]]; then
      tail -50 "${BASE_DIR}/logs/serversentry.log" 2>/dev/null
    else
      echo "Main log: not available"
    fi

  } >"$report_file" 2>/dev/null

  if [[ -f "$report_file" ]]; then
    chmod 600 "$report_file" 2>/dev/null
    echo "$report_file"
    return 0
  else
    log_error "Failed to create critical error report" "error"
    return 1
  fi
}

# Function: error_preserve_system_state
# Description: Preserve system state for post-mortem analysis
# Parameters: None
# Returns:
#   0 - state preserved
#   1 - preservation failed
# Example:
#   error_preserve_system_state
# Dependencies:
#   - util_error_safe_execute
error_preserve_system_state() {
  log_debug "Preserving system state" "error"

  local state_dir="${BASE_DIR}/logs/system_state"
  if ! mkdir -p "$state_dir" 2>/dev/null; then
    log_error "Failed to create system state directory" "error"
    return 1
  fi

  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")

  # Preserve process list
  if ! ps aux >"${state_dir}/processes_${timestamp}.txt" 2>/dev/null; then
    log_warning "Failed to preserve process list" "error"
  fi

  # Preserve environment variables
  if ! env >"${state_dir}/environment_${timestamp}.txt" 2>/dev/null; then
    log_warning "Failed to preserve environment" "error"
  fi

  # Preserve network state
  if command -v netstat >/dev/null 2>&1; then
    netstat -tuln >"${state_dir}/network_${timestamp}.txt" 2>/dev/null
  elif command -v ss >/dev/null 2>&1; then
    ss -tuln >"${state_dir}/network_${timestamp}.txt" 2>/dev/null
  fi

  # Preserve system configuration
  if [[ -d /etc ]]; then
    find /etc -name "*.conf" -type f 2>/dev/null | head -20 | while read -r conf_file; do
      if [[ -r "$conf_file" ]]; then
        cp "$conf_file" "${state_dir}/" 2>/dev/null
      fi
    done
  fi

  log_info "System state preserved in: $state_dir" "error"
  return 0
}

# Internal function: Send webhook notification
_error_send_webhook_notification() {
  local message="$1"
  local context="$2"
  local priority="${3:-normal}"

  # Check if webhook is configured
  if ! declare -f webhook_provider_send >/dev/null 2>&1; then
    return 1
  fi

  # Try to send webhook notification
  if util_error_safe_execute "webhook_provider_send '$message' '$priority'" "Webhook notification failed" "" 1; then
    return 0
  fi

  return 1
}

# Internal function: Send email notification
_error_send_email_notification() {
  local message="$1"
  local context="$2"
  local priority="${3:-normal}"

  # Check if email is configured
  if ! declare -f email_provider_send >/dev/null 2>&1; then
    return 1
  fi

  # Try to send email notification
  if util_error_safe_execute "email_provider_send '$message' '$priority'" "Email notification failed" "" 1; then
    return 0
  fi

  return 1
}

# Internal function: Send system notification
_error_send_system_notification() {
  local message="$1"
  local context="$2"
  local priority="${3:-normal}"

  # Try desktop notification
  if command -v notify-send >/dev/null 2>&1; then
    local urgency="normal"
    [[ "$priority" == "critical" ]] && urgency="critical"

    if util_error_safe_execute "notify-send -u '$urgency' 'ServerSentry Error' '$message'" "Desktop notification failed" "" 1; then
      return 0
    fi
  fi

  # Try system wall message for critical errors
  if [[ "$priority" == "critical" ]] && command -v wall >/dev/null 2>&1; then
    if util_error_safe_execute "echo '$message' | wall" "Wall notification failed" "" 1; then
      return 0
    fi
  fi

  return 1
}

# Internal function: Send SMS notification
_error_send_sms_notification() {
  local message="$1"
  local context="$2"

  # Check if SMS is configured
  if ! declare -f sms_provider_send >/dev/null 2>&1; then
    return 1
  fi

  # Try to send SMS notification
  if util_error_safe_execute "sms_provider_send '$message'" "SMS notification failed" "" 1; then
    return 0
  fi

  return 1
}

# Internal function: Stop non-essential processes
_error_stop_nonessential_processes() {
  log_debug "Stopping non-essential processes" "error"

  # List of processes that can be safely stopped
  local nonessential_processes=("backup" "cron" "at" "anacron")

  for process in "${nonessential_processes[@]}"; do
    if pgrep "$process" >/dev/null 2>&1; then
      if util_error_safe_execute "pkill '$process'" "Failed to stop $process" "" 1; then
        log_debug "Stopped non-essential process: $process" "error"
      fi
    fi
  done

  return 0
}

# Internal function: Aggressive temporary file cleanup
_error_aggressive_temp_cleanup() {
  log_debug "Performing aggressive temporary file cleanup" "error"

  local temp_dirs=("/tmp" "${BASE_DIR}/tmp" "${BASE_DIR}/logs/temp" "/var/tmp")
  local cleaned_count=0

  for temp_dir in "${temp_dirs[@]}"; do
    if [[ -d "$temp_dir" && -w "$temp_dir" ]]; then
      # Clean files older than 1 hour
      find "$temp_dir" -type f -mmin +60 -delete 2>/dev/null && ((cleaned_count++))

      # Clean empty directories
      find "$temp_dir" -type d -empty -delete 2>/dev/null
    fi
  done

  log_debug "Aggressive cleanup processed $cleaned_count directories" "error"
  return 0
}

# Internal function: Backup critical files
_error_backup_critical_files() {
  log_debug "Backing up critical files" "error"

  local backup_dir="${BASE_DIR}/logs/emergency_backup"
  if ! mkdir -p "$backup_dir" 2>/dev/null; then
    return 1
  fi

  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")

  # Backup configuration files
  local critical_files=(
    "${BASE_DIR}/config/serversentry.yaml"
    "${BASE_DIR}/config/serversentry.conf"
    "${BASE_DIR}/logs/serversentry.log"
  )

  for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]]; then
      local backup_name
      backup_name="$(basename "$file")_${timestamp}"
      if cp "$file" "${backup_dir}/${backup_name}" 2>/dev/null; then
        log_debug "Backed up critical file: $file" "error"
      fi
    fi
  done

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f error_send_notification
  export -f error_handle_critical
  export -f error_send_critical_notification
  export -f error_format_notification_message
  export -f error_format_critical_notification
  export -f error_emergency_cleanup
  export -f error_create_critical_report
  export -f error_preserve_system_state
fi
