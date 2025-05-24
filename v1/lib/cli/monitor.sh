#!/bin/bash
#
# ServerSentry - Monitor command
# Starts monitoring in foreground mode

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/config/config.sh"
source "$PROJECT_ROOT/lib/monitor/monitor.sh"

# Start monitoring in foreground
cli_monitor() {
  log_message "INFO" "Starting system monitoring in foreground"

  # Load config
  load_thresholds
  load_webhooks

  # Print current configuration
  print_config

  echo "Press Ctrl+C to stop monitoring..."

  # Set up trap to handle Ctrl+C gracefully
  trap 'echo -e "\n${YELLOW}Monitoring stopped.${NC}"; exit 0' INT

  # Continuous monitoring loop
  while true; do
    check_cpu
    check_memory
    check_disk
    check_processes

    # Sleep for the configured interval
    sleep "$CHECK_INTERVAL"
  done
}
