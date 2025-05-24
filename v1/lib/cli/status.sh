#!/bin/bash
#
# ServerSentry - Status command
# Shows current status and configuration

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/config/config.sh"
source "$PROJECT_ROOT/lib/monitor/monitor.sh"

# Show current status
cli_status() {
  log_message "INFO" "Showing current system status"

  # Load config
  load_thresholds
  load_webhooks

  # Print current configuration
  print_config

  # Show current resource usage
  local cpu_usage=$(get_cpu_usage)
  echo -e "\n${CYAN}Current Resource Usage:${NC}"
  echo -e "CPU usage: $cpu_usage%"

  local memory_usage=$(get_memory_usage)
  echo -e "Memory usage: $memory_usage%"

  local disk_usage=$(get_disk_usage)
  echo -e "Disk usage: $disk_usage%"

  # Check for active cron jobs
  echo -e "\n${CYAN}Scheduled Tasks:${NC}"
  local cron_jobs=$(crontab -l 2>/dev/null | grep "$PROJECT_ROOT/serversentry.sh" | wc -l)

  if [ "$cron_jobs" -gt 0 ]; then
    echo -e "Found $cron_jobs active cron job(s). Use 'install.sh --manage-crons' to manage."
  else
    echo -e "No scheduled tasks found. Use 'install.sh --manage-crons' to add."
  fi

  # Check status of configuration files
  echo -e "\n${CYAN}Configuration Files:${NC}"

  if [ -f "$CONFIG_DIR/thresholds.conf" ]; then
    echo -e "Thresholds configuration: ${GREEN}OK${NC}"
  else
    echo -e "Thresholds configuration: ${RED}Missing${NC}"
  fi

  if [ -f "$CONFIG_DIR/webhooks.conf" ]; then
    local webhook_count=$(grep -v "^#" "$CONFIG_DIR/webhooks.conf" | grep -v "^$" | wc -l)
    if [ "$webhook_count" -gt 0 ]; then
      echo -e "Webhooks configuration: ${GREEN}OK ($webhook_count webhooks)${NC}"
    else
      echo -e "Webhooks configuration: ${YELLOW}No webhooks configured${NC}"
    fi
  else
    echo -e "Webhooks configuration: ${RED}Missing${NC}"
  fi

  # Check log file status
  echo -e "\n${CYAN}Logs:${NC}"
  if [ -f "$LOG_FILE" ]; then
    local log_size=$(du -h "$LOG_FILE" | cut -f1)
    echo -e "Log file: ${GREEN}OK (Size: $log_size)${NC}"
  else
    echo -e "Log file: ${YELLOW}Not created yet${NC}"
  fi

  return 0
}
