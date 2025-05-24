#!/usr/bin/env bash
# Shared TUI utility functions

# Show a message (info, warning, error) in the appropriate UI
# Usage: tui_show_message "Message text" [height] [width]
tui_show_message() {
  local msg="$1"
  local height="${2:-10}"
  local width="${3:-60}"
  if [ "$TUI_TOOL" = "dialog" ]; then
    dialog --msgbox "$msg" "$height" "$width"
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    whiptail --msgbox "$msg" "$height" "$width"
  else
    echo -e "$msg"
    read -p "Press Enter to continue..."
  fi
}
