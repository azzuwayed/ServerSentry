
# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi

#!/usr/bin/env bash
#
# ServerSentry v2 - CLI System Commands Module
#
# This module handles system-level CLI commands: status, start, stop, monitor

# Function: cmd_status
# Description: Display current status of all monitors with enhanced formatting
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_status
# Dependencies:
#   - util_error_validate_input
#   - print_header, print_status (from colors.sh)
#   - run_all_plugin_checks
cmd_status() {
  # Source colors if available
  if [[ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]]; then
    source "$BASE_DIR/lib/ui/cli/colors.sh"
  fi

  print_header "ServerSentry Status" 60

  log_info "Checking system status..." "cli"

  # Check if monitoring is running
  if is_monitoring_running; then
    print_status "ok" "Monitoring service is running"
  else
    print_status "warning" "Monitoring service is stopped"
  fi

  echo ""

  # Run all plugin checks with error handling
  log_debug "Running all plugin checks" "cli"
  local results
  if ! results=$(util_error_safe_execute "run_all_plugin_checks" "Failed to run plugin checks" "" 2); then
    print_status "error" "Failed to retrieve plugin status"
    return 1
  fi

  # Parse and display results with colors
  if [[ -n "$results" ]]; then
    if util_command_exists jq; then
      echo "$results" | jq -r '.[] | "\(.plugin)|\(.status_code)|\(.status_message)|\(.metrics.usage_percent // "N/A")|\(.metrics.threshold // "N/A")"' | while IFS='|' read -r plugin status_code message value threshold; do
        if [[ -n "$plugin" ]]; then
          case "$status_code" in
          0)
            print_status "ok" "$plugin: $message"
            if [[ "$value" != "N/A" && "$threshold" != "N/A" ]]; then
              create_metric_bar "$value" "$threshold" "  └─ Usage"
            fi
            ;;
          1)
            print_status "warning" "$plugin: $message"
            if [[ "$value" != "N/A" && "$threshold" != "N/A" ]]; then
              create_metric_bar "$value" "$threshold" "  └─ Usage"
            fi
            ;;
          2)
            print_status "error" "$plugin: $message"
            if [[ "$value" != "N/A" && "$threshold" != "N/A" ]]; then
              create_metric_bar "$value" "$threshold" "  └─ Usage"
            fi
            ;;
          *)
            print_status "info" "$plugin: $message"
            ;;
          esac
        fi
      done
    else
      # Fallback display without jq
      log_warning "jq not available, using fallback display" "cli"
      echo "$results"
    fi
  else
    echo "No plugin results available"
  fi

  print_separator
  echo ""
  return 0
}

# Function: cmd_start
# Description: Start monitoring service in background with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_start
# Dependencies:
#   - util_error_validate_input
#   - is_monitoring_running
#   - log_audit
cmd_start() {
  log_info "Starting monitoring..." "cli"
  log_audit "start_monitoring" "${USER:-unknown}" "User initiated monitoring start via CLI"

  # Check if already running
  if is_monitoring_running; then
    log_warning "Monitoring is already running" "cli"
    return 0
  fi

  # Validate BASE_DIR exists
  if ! util_error_validate_input "$BASE_DIR" "BASE_DIR" "directory"; then
    util_error_log_with_context "BASE_DIR not found" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Ensure bin directory and script exist
  local serversentry_bin="$BASE_DIR/bin/serversentry"
  if ! util_error_validate_input "$serversentry_bin" "serversentry_bin" "file"; then
    util_error_log_with_context "ServerSentry binary not found: $serversentry_bin" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Start the monitoring process in the background with error handling
  local pid_file="${BASE_DIR}/serversentry.pid"
  if ! util_error_safe_execute "nohup '$serversentry_bin' monitor >/dev/null 2>&1 & echo \$! >'$pid_file'" "Failed to start monitoring process" "" 2; then
    util_error_log_with_context "Failed to start monitoring service" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Verify the process started successfully
  sleep 1
  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      log_info "Monitoring started with PID $pid" "cli"
      log_audit "monitoring_started" "${USER:-unknown}" "PID=$pid"
      return 0
    else
      util_error_log_with_context "Monitoring process failed to start properly" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      rm -f "$pid_file" 2>/dev/null
      return 1
    fi
  else
    util_error_log_with_context "PID file not created" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi
}

# Function: cmd_stop
# Description: Stop monitoring service with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_stop
# Dependencies:
#   - util_error_validate_input
#   - is_monitoring_running
#   - log_audit
cmd_stop() {
  log_info "Stopping monitoring..." "cli"
  log_audit "stop_monitoring" "${USER:-unknown}" "User initiated monitoring stop via CLI"

  # Check if running
  if ! is_monitoring_running; then
    log_warning "Monitoring is not running" "cli"
    return 0
  fi

  # Get PID with validation
  local pid_file="${BASE_DIR}/serversentry.pid"
  if ! util_error_validate_input "$pid_file" "pid_file" "file"; then
    util_error_log_with_context "PID file not found: $pid_file" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  local pid
  pid=$(cat "$pid_file" 2>/dev/null)
  if ! util_error_validate_input "$pid" "pid" "numeric"; then
    util_error_log_with_context "Invalid PID in file: $pid_file" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Kill the process with error handling
  if kill "$pid" 2>/dev/null; then
    # Wait for process to terminate
    local timeout=10
    while [[ $timeout -gt 0 ]] && ps -p "$pid" >/dev/null 2>&1; do
      sleep 1
      ((timeout--))
    done

    # Force kill if still running
    if ps -p "$pid" >/dev/null 2>&1; then
      log_warning "Process did not terminate gracefully, forcing termination" "cli"
      kill -9 "$pid" 2>/dev/null
    fi

    # Clean up PID file
    rm -f "$pid_file"
    log_info "Monitoring stopped" "cli"
    log_audit "monitoring_stopped" "${USER:-unknown}" "PID=$pid"
    return 0
  else
    util_error_log_with_context "Failed to stop monitoring process" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi
}

# Function: cmd_monitor
# Description: Run continuous monitoring daemon with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_monitor
# Dependencies:
#   - util_error_validate_input
#   - run_monitoring_loop
cmd_monitor() {
  log_info "Starting monitoring daemon..." "cli"
  log_audit "monitor_daemon_start" "${USER:-unknown}" "User started monitoring daemon via CLI"

  # Validate configuration before starting
  if ! util_error_safe_execute "validate_configuration" "Configuration validation failed" "" 1; then
    util_error_log_with_context "Cannot start monitoring with invalid configuration" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Initialize plugin system
  if ! util_error_safe_execute "plugin_system_init" "Plugin system initialization failed" "" 2; then
    util_error_log_with_context "Failed to initialize plugin system" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Start monitoring loop with error handling
  log_info "Monitoring daemon started. Press Ctrl+C to stop." "cli"

  # Set up signal handlers for graceful shutdown
  trap 'log_info "Received shutdown signal, stopping monitoring..." "cli"; exit 0' INT TERM

  # Run the monitoring loop
  if ! util_error_safe_execute "run_monitoring_loop" "Monitoring loop failed" "" 3; then
    util_error_log_with_context "Monitoring daemon encountered fatal error" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  log_audit "monitor_daemon_stop" "${USER:-unknown}" "Monitoring daemon stopped"
  return 0
}

# Function: is_monitoring_running
# Description: Check if monitoring service is currently running
# Parameters: None
# Returns:
#   0 - monitoring is running
#   1 - monitoring is not running
# Example:
#   if is_monitoring_running; then echo "Running"; fi
# Dependencies:
#   - BASE_DIR variable
is_monitoring_running() {
  local pid_file="${BASE_DIR}/serversentry.pid"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)

    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      return 0 # Running
    else
      # Clean up stale PID file
      rm -f "$pid_file" 2>/dev/null
    fi
  fi

  return 1 # Not running
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f cmd_status
  export -f cmd_start
  export -f cmd_stop
  export -f cmd_monitor
  export -f is_monitoring_running
fi
