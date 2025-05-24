#!/bin/bash
# TUI system info module

source "$(dirname "$0")/utils.sh"

tui_system_info() {
  check_serversentry_bin || return
  local hostname os kernel uptime loadavg cpuinfo meminfo diskinfo ip version
  hostname=$(hostname)
  os=$(uname -s)
  kernel=$(uname -r)
  uptime=$(uptime | sed 's/.*up \([^,]*\), .*/\1/')
  loadavg=$(uptime | awk -F'load averages?: ' '{print $2}')
  cpuinfo=$(uname -p)
  meminfo="$(
    if command -v vm_stat >/dev/null 2>&1; then
      # macOS
      pages_free=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
      pages_active=$(vm_stat | awk '/Pages active/ {print $3}' | tr -d '.')
      pages_inactive=$(vm_stat | awk '/Pages inactive/ {print $3}' | tr -d '.')
      pages_speculative=$(vm_stat | awk '/Pages speculative/ {print $3}' | tr -d '.')
      pages_wired=$(vm_stat | awk '/Pages wired down/ {print $4}' | tr -d '.')
      page_size=$(vm_stat | head -1 | awk '{print $8}')
      [ -z "$page_size" ] && page_size=4096
      total_pages=$((pages_free + pages_active + pages_inactive + pages_speculative + pages_wired))
      total_mem=$((total_pages * page_size / 1024 / 1024))
      used_mem=$(((pages_active + pages_inactive + pages_speculative + pages_wired) * page_size / 1024 / 1024))
      echo "$used_mem MB / $total_mem MB"
    elif command -v free >/dev/null 2>&1; then
      # Linux
      free -m | awk '/Mem:/ {print $3 " MB / " $2 " MB"}'
    else
      echo "Unknown"
    fi
  )"
  diskinfo=$(df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 " used)"}')
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$ip" ] && ip=$(ipconfig getifaddr en0 2>/dev/null)
  version="$($SERVERSENTRY_BIN version 2>&1 | head -n1)"
  local info="Hostname: $hostname\nOS: $os\nKernel: $kernel\nUptime: $uptime\nLoad Avg: $loadavg\nCPU: $cpuinfo\nMemory: $meminfo\nDisk: $diskinfo\nIP: $ip\n$version"
  tui_show_message "$info" 20 70
}

# (This module is intended to be sourced by tui.sh)
