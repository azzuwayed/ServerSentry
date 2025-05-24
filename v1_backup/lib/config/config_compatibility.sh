#!/bin/bash
#
# ServerSentry - Configuration Compatibility Layer
# Provides backward compatibility for code that uses the old config.sh interface

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the new configuration manager
source "$SCRIPT_DIR/config_manager.sh"

# Initialize default configurations if needed
initialize_default_configs

# Global variables for backward compatibility
CPU_THRESHOLD=$(get_config "thresholds" "cpu_threshold" "80")
MEMORY_THRESHOLD=$(get_config "thresholds" "memory_threshold" "80")
DISK_THRESHOLD=$(get_config "thresholds" "disk_threshold" "85")
LOAD_THRESHOLD=$(get_config "thresholds" "load_threshold" "2.0")
CHECK_INTERVAL=$(get_config "thresholds" "check_interval" "60")
PROCESS_CHECKS=$(get_config "thresholds" "process_checks" "")

# Webhooks array for backward compatibility
declare -a WEBHOOKS
while IFS= read -r webhook; do
  if [ -n "$webhook" ]; then
    WEBHOOKS+=("$webhook")
  fi
done < <(manage_webhooks "get_all")

# Backward compatibility functions

# Load thresholds from configuration file
load_thresholds() {
  # Get values from config manager
  CPU_THRESHOLD=$(get_config "thresholds" "cpu_threshold" "80")
  MEMORY_THRESHOLD=$(get_config "thresholds" "memory_threshold" "80")
  DISK_THRESHOLD=$(get_config "thresholds" "disk_threshold" "85")
  LOAD_THRESHOLD=$(get_config "thresholds" "load_threshold" "2.0")
  CHECK_INTERVAL=$(get_config "thresholds" "check_interval" "60")
  PROCESS_CHECKS=$(get_config "thresholds" "process_checks" "")

  log_message "INFO" "Loaded thresholds configuration"
  return 0
}

# Load webhooks from configuration file
load_webhooks() {
  # Clear the existing webhooks array
  WEBHOOKS=()

  # Get values from config manager
  while IFS= read -r webhook; do
    if [ -n "$webhook" ]; then
      WEBHOOKS+=("$webhook")
    fi
  done < <(manage_webhooks "get_all")

  log_message "INFO" "Loaded ${#WEBHOOKS[@]} webhook(s)"
  return 0
}

# Update a threshold value
update_threshold() {
  local name="$1"
  local value="$2"

  # Validate the threshold name
  case "$name" in
  cpu_threshold | memory_threshold | disk_threshold | load_threshold | check_interval | process_checks)
    # Valid threshold name
    ;;
  *)
    log_message "ERROR" "Invalid threshold name: $name"
    return 1
    ;;
  esac

  # Validate the value (except for process_checks)
  if [ "$name" != "process_checks" ]; then
    if ! is_number "$value"; then
      log_message "ERROR" "Invalid threshold value: $value (must be a number)"
      return 1
    fi
  fi

  # Update using config manager
  if set_config "thresholds" "$name" "$value"; then
    # Update the global variable
    case "$name" in
    cpu_threshold)
      CPU_THRESHOLD="$value"
      ;;
    memory_threshold)
      MEMORY_THRESHOLD="$value"
      ;;
    disk_threshold)
      DISK_THRESHOLD="$value"
      ;;
    load_threshold)
      LOAD_THRESHOLD="$value"
      ;;
    check_interval)
      CHECK_INTERVAL="$value"
      ;;
    process_checks)
      PROCESS_CHECKS="$value"
      ;;
    esac

    log_message "INFO" "Updated threshold: $name=$value"
    return 0
  else
    log_message "ERROR" "Failed to update threshold: $name=$value"
    return 1
  fi
}

# Add a new webhook endpoint
add_webhook() {
  local url="$1"

  # Remove any escaping from the URL before storing
  url=$(echo "$url" | sed 's/\\//g')

  if ! is_valid_url "$url"; then
    log_message "ERROR" "Invalid webhook URL: $url"
    echo "[ERROR] Invalid webhook URL: $url"
    return 1
  fi

  # Check if webhook already exists
  load_webhooks
  for webhook in "${WEBHOOKS[@]}"; do
    if [ "$webhook" == "$url" ]; then
      log_message "WARNING" "Webhook already exists: $url"
      echo "[WARNING] Webhook already exists: $url"
      return 0
    fi
  done

  # Add webhook using config manager
  if manage_webhooks "add" "$url"; then
    # Reload webhooks array
    load_webhooks

    log_message "INFO" "Added webhook: $url"
    echo "Webhook added: $url"

    # Immediately send a test notification
    if [[ "$(type -t send_webhook_notification)" != "function" ]]; then
      source "$(get_dir_path "lib")/notify/main.sh"
    fi

    echo "Testing webhook..."
    send_webhook_notification "$url" "Test" "This is a test notification from ServerSentry (add_webhook)."
    local status=$?

    if [ $status -eq 0 ]; then
      echo "[SUCCESS] Webhook test notification sent successfully."
    else
      echo "[ERROR] Webhook test notification failed. Please check the URL or your endpoint."
    fi

    return 0
  else
    log_message "ERROR" "Failed to add webhook: $url"
    echo "[ERROR] Failed to add webhook: $url"
    return 1
  fi
}

# Remove a webhook endpoint by index
remove_webhook() {
  local index="$1"

  # Validate the index
  if ! [[ "$index" =~ ^[0-9]+$ ]]; then
    log_message "ERROR" "Invalid webhook index: $index"
    return 1
  fi

  # Load existing webhooks
  load_webhooks

  # Check if the index is valid
  if [ "$index" -ge "${#WEBHOOKS[@]}" ]; then
    log_message "ERROR" "Webhook index out of range: $index"
    return 1
  fi

  # Get the webhook URL for logging
  local removed_webhook="${WEBHOOKS[$index]}"

  # Remove webhook using config manager
  if manage_webhooks "remove" "$((index + 1))"; then # +1 because manage_webhooks is 1-indexed
    log_message "INFO" "Removed webhook: $removed_webhook"
    return 0
  else
    log_message "ERROR" "Failed to remove webhook: $removed_webhook"
    return 1
  fi
}

# Print the current configuration
print_config() {
  echo "ServerSentry Configuration:"
  print_line
  echo "Thresholds:"
  echo "  CPU Usage Threshold: ${CPU_THRESHOLD}%"
  echo "  Memory Usage Threshold: ${MEMORY_THRESHOLD}%"
  echo "  Disk Usage Threshold: ${DISK_THRESHOLD}%"
  echo "  System Load Threshold: ${LOAD_THRESHOLD}"
  echo "  Check Interval: ${CHECK_INTERVAL} seconds"

  if [ -n "$PROCESS_CHECKS" ]; then
    echo "  Process Checks: ${PROCESS_CHECKS}"
  else
    echo "  Process Checks: None"
  fi

  print_line
  echo "Webhooks:"
  if [ ${#WEBHOOKS[@]} -eq 0 ]; then
    echo "  No webhooks configured"
  else
    for i in "${!WEBHOOKS[@]}"; do
      echo "  $i: ${WEBHOOKS[$i]}"
    done
  fi
  print_line
}
