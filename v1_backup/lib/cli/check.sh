#!/bin/bash
#
# ServerSentry - Check command
# Performs a one-time system check and displays results

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/config/config.sh"
source "$PROJECT_ROOT/lib/monitor/monitor.sh"

# Run a one-time system check
cli_check() {
  log_message "INFO" "Running one-time system check"

  # Load config
  load_thresholds
  load_webhooks

  # Get and display current resource usage with visual indicators
  local cpu_usage=$(get_cpu_usage)
  colorize_metric "$cpu_usage" "${CPU_THRESHOLD}" "🖥️  CPU usage:"

  local memory_usage=$(get_memory_usage)
  colorize_metric "$memory_usage" "${MEMORY_THRESHOLD}" "🧠 Memory usage:"

  local disk_usage=$(get_disk_usage)
  colorize_metric "$disk_usage" "${DISK_THRESHOLD}" "💾 Disk usage:"

  echo -e "\n${CYAN}=== System Information ===${NC}"
  echo -e "${CYAN}Hostname:${NC} $(hostname)"
  echo -e "${CYAN}OS:${NC} $(uname -a)"
  echo -e "${CYAN}Uptime:${NC} $(uptime)"

  # Run threshold checks and show details when thresholds are exceeded
  if [ "${cpu_usage:-0}" -ge "${CPU_THRESHOLD:-80}" ] 2>/dev/null; then
    echo -e "\n${RED}⚠️ CPU ALERT: Usage exceeded threshold: $cpu_usage% >= $CPU_THRESHOLD%${NC}"
    echo -e "${CYAN}Top CPU consumers:${NC}"
    get_top_cpu_processes 5
  fi

  if [ "${memory_usage:-0}" -ge "${MEMORY_THRESHOLD:-80}" ] 2>/dev/null; then
    echo -e "\n${RED}⚠️ MEMORY ALERT: Usage exceeded threshold: $memory_usage% >= $MEMORY_THRESHOLD%${NC}"
    echo -e "${CYAN}Top memory consumers:${NC}"
    get_top_memory_processes 5
  fi

  if [ "${disk_usage:-0}" -ge "${DISK_THRESHOLD:-85}" ] 2>/dev/null; then
    echo -e "\n${RED}⚠️ DISK ALERT: Usage exceeded threshold: $disk_usage% >= $DISK_THRESHOLD%${NC}"
    echo -e "${CYAN}Largest directories:${NC}"
    if command_exists du; then
      du -h /var /tmp /Users 2>/dev/null | sort -hr | head -n 5
    fi
  fi

  # Check monitored processes
  if [ -n "$PROCESS_CHECKS" ]; then
    echo ""
    echo "Process checks:"
    IFS=',' read -ra PROCESSES <<<"$PROCESS_CHECKS"
    for process in "${PROCESSES[@]}"; do
      process=$(echo "$process" | xargs)
      if [ -z "$process" ]; then continue; fi

      if check_process_running "$process"; then
        echo "  ✅ $process is running"
      else
        echo "  ❌ $process is NOT running"
      fi
    done
  fi

  log_message "INFO" "One-time check completed"
  return 0
}
