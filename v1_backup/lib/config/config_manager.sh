#!/bin/bash
#
# ServerSentry - Unified Configuration Manager
# This module provides a consistent interface for managing all config files

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source required modules
source "$SCRIPT_DIR/../utils/paths.sh"

# Define config file paths using path utilities
THRESHOLDS_CONF="$(get_file_path "thresholds")"
WEBHOOKS_CONF="$(get_file_path "webhooks")"
LOGROTATE_CONF="$(get_file_path "logrotate")"
PERIODIC_CONF="$(get_file_path "periodic")"

# Create config directory if it doesn't exist
ensure_dir_exists "$(get_dir_path "config")"

# Function to get a configuration value
# Usage: get_config "config_type" "parameter_name" ["default_value"]
get_config() {
  local config_type="$1"
  local param_name="$2"
  local default_value="${3:-}"
  local config_file=""

  # Determine which config file to use
  case "$config_type" in
  "thresholds")
    config_file="$THRESHOLDS_CONF"
    ;;
  "webhooks")
    config_file="$WEBHOOKS_CONF"
    return 1 # Webhooks file is handled differently
    ;;
  "logrotate")
    config_file="$LOGROTATE_CONF"
    ;;
  "periodic")
    config_file="$PERIODIC_CONF"
    ;;
  *)
    log_message "ERROR" "Unknown config type: $config_type"
    return 1
    ;;
  esac

  # Check if config file exists
  if [ ! -f "$config_file" ]; then
    # If default value provided, return it
    if [ -n "$default_value" ]; then
      echo "$default_value"
      return 0
    fi
    return 1
  fi

  # Get parameter value from config file
  local value=$(grep -E "^${param_name}=" "$config_file" 2>/dev/null | cut -d= -f2-)

  # If value not found but default provided, return default
  if [ -z "$value" ] && [ -n "$default_value" ]; then
    echo "$default_value"
    return 0
  fi

  # Return found value or empty if not found
  echo "$value"
  return 0
}

# Function to set a configuration value
# Usage: set_config "config_type" "parameter_name" "new_value"
set_config() {
  local config_type="$1"
  local param_name="$2"
  local new_value="$3"
  local config_file=""

  # Determine which config file to use
  case "$config_type" in
  "thresholds")
    config_file="$THRESHOLDS_CONF"
    ;;
  "logrotate")
    config_file="$LOGROTATE_CONF"
    ;;
  "periodic")
    config_file="$PERIODIC_CONF"
    ;;
  *)
    log_message "ERROR" "Unknown config type: $config_type"
    return 1
    ;;
  esac

  # Create config file if it doesn't exist
  if [ ! -f "$config_file" ]; then
    touch "$config_file" || {
      log_message "ERROR" "Failed to create config file: $config_file"
      return 1
    }
  fi

  # Check if parameter already exists in config file
  if grep -q "^${param_name}=" "$config_file" 2>/dev/null; then
    # Update existing parameter
    sed -i.bak "s|^${param_name}=.*|${param_name}=${new_value}|" "$config_file" || {
      log_message "ERROR" "Failed to update parameter in config file"
      return 1
    }
    # Remove backup file created by sed
    rm -f "${config_file}.bak" 2>/dev/null
  else
    # Add new parameter
    echo "${param_name}=${new_value}" >>"$config_file" || {
      log_message "ERROR" "Failed to add parameter to config file"
      return 1
    }
  fi

  return 0
}

# Function to list all configuration parameters
# Usage: list_config "config_type"
list_config() {
  local config_type="$1"
  local config_file=""

  # Determine which config file to use
  case "$config_type" in
  "thresholds")
    config_file="$THRESHOLDS_CONF"
    ;;
  "logrotate")
    config_file="$LOGROTATE_CONF"
    ;;
  "periodic")
    config_file="$PERIODIC_CONF"
    ;;
  *)
    log_message "ERROR" "Unknown config type: $config_type"
    return 1
    ;;
  esac

  # Check if config file exists
  if [ ! -f "$config_file" ]; then
    log_message "WARNING" "Config file does not exist: $config_file"
    return 1
  fi

  # Output all parameters in the config file
  cat "$config_file"
  return 0
}

# Function to manage webhooks
# Operations: list, add, remove, get_all
# Usage: manage_webhooks "operation" ["parameter"]
manage_webhooks() {
  local operation="$1"
  local param="${2:-}"

  # Create webhooks file if it doesn't exist
  if [ ! -f "$WEBHOOKS_CONF" ]; then
    touch "$WEBHOOKS_CONF" || {
      log_message "ERROR" "Failed to create webhooks config file"
      return 1
    }
  fi

  case "$operation" in
  "list")
    # List all webhooks with index numbers
    if [ ! -s "$WEBHOOKS_CONF" ]; then
      echo "No webhooks configured."
      return 0
    fi

    local line_num=1
    while IFS= read -r webhook; do
      if [ -n "$webhook" ]; then
        echo "[$line_num] $webhook"
        ((line_num++))
      fi
    done <"$WEBHOOKS_CONF"
    ;;

  "add")
    # Add a new webhook
    if [ -z "$param" ]; then
      log_message "ERROR" "No webhook URL provided"
      return 1
    fi

    # Check if webhook already exists
    if grep -q "^$param$" "$WEBHOOKS_CONF" 2>/dev/null; then
      log_message "WARNING" "Webhook already exists"
      return 1
    fi

    # Add webhook to file
    echo "$param" >>"$WEBHOOKS_CONF" || {
      log_message "ERROR" "Failed to add webhook to config file"
      return 1
    }

    log_message "INFO" "Webhook added successfully"
    return 0
    ;;

  "remove")
    # Remove webhook by index
    if [ -z "$param" ] || ! [[ "$param" =~ ^[0-9]+$ ]]; then
      log_message "ERROR" "Invalid webhook index: $param"
      return 1
    fi

    local line_count=$(wc -l <"$WEBHOOKS_CONF")
    if [ "$param" -lt 1 ] || [ "$param" -gt "$line_count" ]; then
      log_message "ERROR" "Webhook index out of range: $param"
      return 1
    fi

    # Create temporary file for new content
    local temp_file=$(mktemp)
    local current_line=1

    # Copy all lines except the one to remove
    while IFS= read -r webhook; do
      if [ "$current_line" -ne "$param" ]; then
        echo "$webhook" >>"$temp_file"
      fi
      ((current_line++))
    done <"$WEBHOOKS_CONF"

    # Replace old file with new content
    mv "$temp_file" "$WEBHOOKS_CONF" || {
      log_message "ERROR" "Failed to update webhooks file"
      rm -f "$temp_file" 2>/dev/null
      return 1
    }

    log_message "INFO" "Webhook removed successfully"
    return 0
    ;;

  "get_all")
    # Return all webhooks as an array
    if [ ! -s "$WEBHOOKS_CONF" ]; then
      return 0
    fi

    while IFS= read -r webhook; do
      if [ -n "$webhook" ]; then
        echo "$webhook"
      fi
    done <"$WEBHOOKS_CONF"
    return 0
    ;;

  *)
    log_message "ERROR" "Unknown webhook operation: $operation"
    return 1
    ;;
  esac

  return 0
}

# Initialize default configurations if files don't exist
initialize_default_configs() {
  # Initialize thresholds.conf with defaults if it doesn't exist
  if [ ! -f "$THRESHOLDS_CONF" ]; then
    cat >"$THRESHOLDS_CONF" <<EOF
cpu_threshold=80
memory_threshold=80
disk_threshold=85
load_threshold=2.0
check_interval=60
process_checks=
EOF
    log_message "INFO" "Created default thresholds configuration"
  fi

  # Initialize logrotate.conf with defaults if it doesn't exist
  if [ ! -f "$LOGROTATE_CONF" ]; then
    cat >"$LOGROTATE_CONF" <<EOF
max_size_mb=10
max_age_days=30
max_files=10
compress=true
rotate_on_start=false
EOF
    log_message "INFO" "Created default log rotation configuration"
  fi

  # Initialize periodic.conf with defaults if it doesn't exist
  if [ ! -f "$PERIODIC_CONF" ]; then
    cat >"$PERIODIC_CONF" <<EOF
report_interval=86400
report_level=detailed
report_checks=cpu,memory,disk,processes
force_report=false
report_time=
report_days=
EOF
    log_message "INFO" "Created default periodic reports configuration"
  fi

  # Create empty webhooks.conf if it doesn't exist
  if [ ! -f "$WEBHOOKS_CONF" ]; then
    touch "$WEBHOOKS_CONF"
    log_message "INFO" "Created empty webhooks configuration"
  fi

  return 0
}
