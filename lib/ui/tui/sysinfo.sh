#!/usr/bin/env bash
# TUI system information module

# Source utilities if not already loaded
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

source "$(dirname "$0")/utils.sh"

tui_system_info() {
  local system_info=""

  # OS Info
  system_info+="Operating System: $(uname -s)\n"
  system_info+="Kernel: $(uname -r)\n"
  system_info+="Architecture: $(uname -m)\n\n"

  # Memory Info
  if util_command_exists vm_stat; then
    # macOS
    local vm_stat_output
    vm_stat_output=$(vm_stat)
    local page_size
    page_size=$(pagesize)

    local pages_active pages_inactive pages_speculative pages_wired pages_free
    pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
    pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
    pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')
    pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')
    pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')

    local total_pages used_pages
    total_pages=$((pages_active + pages_inactive + pages_speculative + pages_wired + pages_free))
    used_pages=$((pages_active + pages_inactive + pages_wired))

    if [[ "$total_pages" -gt 0 ]]; then
      local total_memory_gb used_memory_gb
      total_memory_gb=$(echo "scale=2; $total_pages * $page_size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "N/A")
      used_memory_gb=$(echo "scale=2; $used_pages * $page_size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "N/A")
      system_info+="Memory: ${used_memory_gb}GB / ${total_memory_gb}GB\n"
    else
      system_info+="Memory: N/A\n"
    fi
  elif util_command_exists free; then
    # Linux
    local memory_info
    memory_info=$(free -h | awk 'NR==2{printf "Memory: %s / %s", $3, $2}')
    system_info+="$memory_info\n"
  else
    system_info+="Memory: N/A\n"
  fi

  # Disk Info
  system_info+="Disk Usage:\n"
  df -h | head -10 | while read -r line; do
    system_info+="  $line\n"
  done

  # CPU Info
  if [[ -f /proc/cpuinfo ]]; then
    local cpu_count
    cpu_count=$(grep -c "^processor" /proc/cpuinfo)
    system_info+="\nCPU Cores: $cpu_count\n"
  elif util_command_exists sysctl; then
    local cpu_count
    cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo "N/A")
    system_info+="\nCPU Cores: $cpu_count\n"
  fi

  # Load Average
  if [[ -f /proc/loadavg ]]; then
    local load_avg
    load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)
    system_info+="Load Average: $load_avg\n"
  elif util_command_exists uptime; then
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[[:space:]]*//')
    system_info+="Load Average: $load_avg\n"
  fi

  # Uptime
  if util_command_exists uptime; then
    local uptime_info
    uptime_info=$(uptime | sed 's/.*up \(.*\), [0-9]* user.*/\1/')
    system_info+="Uptime: $uptime_info\n"
  fi

  tui_show_message "System Information:\n\n$system_info" 25 80
}

# (This module is intended to be sourced by tui.sh)
