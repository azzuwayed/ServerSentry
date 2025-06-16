#!/usr/bin/env bash
#
# ServerSentry v2 - CLI Configuration Commands Module
#
# This module handles configuration-related CLI commands: configure, logs, version, update-threshold, list-thresholds

# Function: cmd_configure
# Description: Open configuration file for editing with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_configure
# Dependencies:
#   - util_error_validate_input
#   - MAIN_CONFIG variable
#   - EDITOR environment variable
cmd_configure() {
  log_info "Opening configuration..." "cli"
  log_audit "edit_config" "${USER:-unknown}" "User opened configuration file for editing"

  # Validate configuration file exists
  if ! util_error_validate_input "$MAIN_CONFIG" "MAIN_CONFIG" "file"; then
    # Try to create default config if it doesn't exist
    local config_dir
    config_dir=$(dirname "$MAIN_CONFIG")
    if ! util_error_validate_input "$config_dir" "config_dir" "directory"; then
      if ! mkdir -p "$config_dir" 2>/dev/null; then
        util_error_log_with_context "Cannot create config directory: $config_dir" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
        return 1
      fi
    fi

    # Create basic config file
    if ! util_error_safe_execute "create_default_config '$MAIN_CONFIG'" "Failed to create default config" "" 1; then
      util_error_log_with_context "Cannot create default configuration file" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    log_info "Created default configuration file: $MAIN_CONFIG" "cli"
  fi

  # Determine editor to use
  local editor="${EDITOR:-vi}"
  if ! command -v "$editor" >/dev/null 2>&1; then
    # Try common editors
    for fallback_editor in nano vim vi; do
      if command -v "$fallback_editor" >/dev/null 2>&1; then
        editor="$fallback_editor"
        break
      fi
    done
  fi

  # Backup current config before editing
  local backup_file="${MAIN_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
  if ! cp "$MAIN_CONFIG" "$backup_file" 2>/dev/null; then
    log_warning "Could not create backup of configuration file" "cli"
  else
    log_debug "Configuration backup created: $backup_file" "cli"
  fi

  # Open with editor
  log_info "Opening configuration with: $editor" "cli"
  if ! "$editor" "$MAIN_CONFIG"; then
    util_error_log_with_context "Editor failed or was cancelled" "$ERROR_GENERAL" "$ERROR_SEVERITY_WARNING" "cli"
    return 1
  fi

  # Validate configuration after editing
  if ! util_error_safe_execute "validate_configuration" "Configuration validation failed" "" 1; then
    log_warning "Configuration validation failed after editing" "cli"
    echo "Would you like to restore the backup? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      if cp "$backup_file" "$MAIN_CONFIG" 2>/dev/null; then
        log_info "Configuration restored from backup" "cli"
      else
        util_error_log_with_context "Failed to restore backup" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
        return 1
      fi
    fi
  else
    log_info "Configuration validation passed" "cli"
    # Remove backup if validation passed
    rm -f "$backup_file" 2>/dev/null
  fi

  log_audit "config_edit_completed" "${USER:-unknown}" "Configuration editing session completed"
  return 0
}

# Function: cmd_logs
# Description: Manage log files with enhanced error handling and validation
# Parameters:
#   $1 (string): subcommand (view|rotate|clear) - defaults to "view"
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_logs view
#   cmd_logs rotate
#   cmd_logs clear
# Dependencies:
#   - util_error_validate_input
#   - LOG_FILE variable
#   - rotate_logs function
cmd_logs() {
  local subcommand="${1:-view}"

  # Validate LOG_FILE exists for most operations
  if [[ "$subcommand" != "clear" ]] && ! util_error_validate_input "$LOG_FILE" "LOG_FILE" "file"; then
    util_error_log_with_context "Log file not found: $LOG_FILE" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  case "$subcommand" in
  view)
    # View logs with enhanced formatting
    log_audit "view_logs" "${USER:-unknown}" "User viewed log file"

    local lines="${2:-50}"
    if ! util_error_validate_input "$lines" "lines" "numeric"; then
      lines=50
    fi

    echo "=== ServerSentry Logs (last $lines lines) ==="
    if ! tail -n "$lines" "$LOG_FILE" 2>/dev/null; then
      util_error_log_with_context "Failed to read log file" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    echo "=== End of Logs ==="
    ;;

  rotate)
    # Rotate logs with validation
    log_audit "rotate_logs" "${USER:-unknown}" "User manually rotated logs"
    log_info "Rotating log files..." "cli"

    if ! util_error_safe_execute "rotate_logs" "Failed to rotate logs" "" 2; then
      util_error_log_with_context "Log rotation failed" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    log_info "Log rotation completed successfully" "cli"
    ;;

  clear)
    # Clear logs with confirmation
    log_warning "This will permanently clear all log data. Continue? (y/N)" "cli"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      log_audit "clear_logs" "${USER:-unknown}" "User cleared log file"

      # Ensure log file exists before clearing
      if [[ ! -f "$LOG_FILE" ]]; then
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if ! mkdir -p "$log_dir" 2>/dev/null; then
          util_error_log_with_context "Cannot create log directory: $log_dir" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
          return 1
        fi
      fi

      if ! >"$LOG_FILE" 2>/dev/null; then
        util_error_log_with_context "Failed to clear log file" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
        return 1
      fi

      log_info "Log file cleared successfully" "cli"
    else
      log_info "Log clearing cancelled" "cli"
    fi
    ;;

  *)
    util_error_log_with_context "Unknown logs subcommand: $subcommand" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    echo "Available subcommands: view [lines], rotate, clear"
    return 1
    ;;
  esac

  return 0
}

# Function: cmd_version
# Description: Display version information with enhanced details
# Parameters: None
# Returns:
#   0 - success
# Example:
#   cmd_version
# Dependencies:
#   - PLUGIN_INTERFACE_VERSION variable
cmd_version() {
  echo "ServerSentry v2.0.0"
  echo "Plugin Interface v${PLUGIN_INTERFACE_VERSION:-1.0}"
  echo "Build Date: $(date -r "${BASE_DIR}/bin/serversentry" 2>/dev/null || echo "Unknown")"
  echo "Installation Path: ${BASE_DIR}"

  # Show system information
  echo ""
  echo "System Information:"
  echo "  OS: $(uname -s) $(uname -r)"
  echo "  Architecture: $(uname -m)"
  echo "  Shell: ${SHELL:-Unknown} (${BASH_VERSION:-Unknown})"
  echo "  User: ${USER:-Unknown}"

  # Show configuration status
  echo ""
  echo "Configuration:"
  echo "  Config File: ${MAIN_CONFIG}"
  echo "  Log File: ${LOG_FILE}"
  echo "  Plugin Directory: ${PLUGIN_DIR:-${BASE_DIR}/lib/plugins}"

  return 0
}

# Function: cmd_update_threshold
# Description: Update threshold values with enhanced validation
# Parameters:
#   $1 (string): threshold assignment (e.g., "cpu_threshold=85")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_update_threshold "cpu_threshold=85"
#   cmd_update_threshold "memory_threshold=90"
# Dependencies:
#   - util_error_validate_input
#   - config_set_value function
cmd_update_threshold() {
  local threshold_assignment="$1"

  if ! util_error_validate_input "$threshold_assignment" "threshold_assignment" "required"; then
    echo "Usage: serversentry update-threshold <key>=<value>"
    echo "Example: serversentry update-threshold cpu_threshold=85"
    return 1
  fi

  # Parse the assignment
  if [[ ! "$threshold_assignment" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=([0-9]+)$ ]]; then
    util_error_log_with_context "Invalid threshold format: $threshold_assignment" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    echo "Format must be: key=value (e.g., cpu_threshold=85)"
    return 1
  fi

  local key="${BASH_REMATCH[1]}"
  local value="${BASH_REMATCH[2]}"

  # Validate threshold key
  local valid_thresholds=("cpu_threshold" "memory_threshold" "disk_threshold" "load_threshold")
  local valid_key=false
  for valid_threshold in "${valid_thresholds[@]}"; do
    if [[ "$key" == "$valid_threshold" ]]; then
      valid_key=true
      break
    fi
  done

  if [[ "$valid_key" == "false" ]]; then
    util_error_log_with_context "Unknown threshold key: $key" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    echo "Valid threshold keys: ${valid_thresholds[*]}"
    return 1
  fi

  # Validate threshold value range
  if [[ "$value" -lt 1 || "$value" -gt 100 ]]; then
    util_error_log_with_context "Threshold value out of range: $value" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    echo "Threshold value must be between 1 and 100"
    return 1
  fi

  # Update the configuration
  log_info "Updating $key to $value" "cli"
  log_audit "update_threshold" "${USER:-unknown}" "key=$key, value=$value"

  if ! util_error_safe_execute "config_set_value '$key' '$value'" "Failed to update threshold" "" 1; then
    util_error_log_with_context "Failed to update threshold in configuration" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  log_info "Threshold updated successfully: $key=$value" "cli"
  return 0
}

# Function: cmd_list_thresholds
# Description: List all current threshold values with enhanced formatting
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_list_thresholds
# Dependencies:
#   - config_get_value function
cmd_list_thresholds() {
  log_info "Current threshold configuration:" "cli"
  log_audit "list_thresholds" "${USER:-unknown}" "User requested threshold list"

  echo "Current Thresholds:"
  echo "==================="

  local thresholds=("cpu_threshold" "memory_threshold" "disk_threshold" "load_threshold")
  local defaults=("80" "85" "90" "5.0")

  for i in "${!thresholds[@]}"; do
    local key="${thresholds[$i]}"
    local default="${defaults[$i]}"

    local value
    if declare -f config_get_value >/dev/null 2>&1; then
      value=$(config_get_value "$key" "$default" 2>/dev/null || echo "$default")
    else
      value="$default"
    fi

    printf "  %-20s: %s\n" "$key" "$value"
  done

  echo ""
  echo "To update a threshold:"
  echo "  serversentry update-threshold <key>=<value>"
  echo "  Example: serversentry update-threshold cpu_threshold=85"

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f cmd_configure
  export -f cmd_logs
  export -f cmd_version
  export -f cmd_update_threshold
  export -f cmd_list_thresholds
fi
