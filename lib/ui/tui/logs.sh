#!/bin/bash
# TUI logs module

source "$(dirname "$0")/utils.sh"

tui_logs() {
  local logfile="$BASE_DIR/logs/serversentry.log"
  if [ "$TUI_TOOL" = "dialog" ]; then
    dialog --textbox <(tail -n 50 "$logfile" 2>/dev/null || echo "No log file found.") 20 80
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    whiptail --textbox <(tail -n 50 "$logfile" 2>/dev/null || echo "No log file found.") 20 80
  else
    echo -e "\n--- Recent Logs ---"
    tail -n 50 "$logfile" 2>/dev/null || echo "No log file found."
    echo -e "-------------------\n"
    read -p "Press Enter to continue..."
  fi
}

# (This module is intended to be sourced by tui.sh)
