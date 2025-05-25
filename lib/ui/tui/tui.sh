#!/usr/bin/env bash
#
# ServerSentry v2 - Text-based User Interface (TUI) Main Entry Point
#
# This provides both advanced and fallback TUI options

# Get the directory of this script
TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set BASE_DIR if not already set
if [ -z "$BASE_DIR" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  BASE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
fi

# Source core utilities for unified command checking
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

# Try to use advanced TUI first
if [ -f "$TUI_DIR/advanced_tui.sh" ] && [ "${SERVERSENTRY_SIMPLE_TUI:-}" != "true" ]; then
  echo "Starting ServerSentry Advanced TUI..."
  echo "Press Ctrl+C to exit anytime"
  sleep 1

  source "$TUI_DIR/advanced_tui.sh"
  start_advanced_tui
else
  # Fallback to simple TUI
  echo "Using Simple TUI (set SERVERSENTRY_SIMPLE_TUI=true to force this mode)"

  # Check for dialog/whiptail using unified command checking
  if util_command_exists dialog; then
    TUI_TOOL="dialog"
  elif util_command_exists whiptail; then
    TUI_TOOL="whiptail"
  else
    TUI_TOOL="none"
  fi

  SERVERSENTRY_BIN="$BASE_DIR/bin/serversentry"

  # Source modular TUI components
  source "$BASE_DIR/lib/ui/tui/utils.sh"
  source "$BASE_DIR/lib/ui/tui/status.sh"
  source "$BASE_DIR/lib/ui/tui/logs.sh"
  source "$BASE_DIR/lib/ui/tui/sysinfo.sh"
  source "$BASE_DIR/lib/ui/tui/config.sh"
  source "$BASE_DIR/lib/ui/tui/plugin.sh"
  source "$BASE_DIR/lib/ui/tui/notification.sh"

  # Helper to check serversentry binary exists
  check_serversentry_bin() {
    if [ ! -x "$SERVERSENTRY_BIN" ]; then
      tui_show_message "ServerSentry executable not found at $SERVERSENTRY_BIN" 8 60
      return 1
    fi
    return 0
  }

  # Main TUI menu
  show_tui_menu() {
    while true; do
      local choice
      if [ "$TUI_TOOL" = "dialog" ]; then
        choice=$(dialog --clear --stdout --title "ServerSentry TUI" \
          --menu "Select an action:" 18 50 8 \
          1 "View System Status" \
          2 "Run System Check" \
          3 "View Logs" \
          4 "Configure Settings" \
          5 "Exit" \
          6 "Plugin Management" \
          7 "Notification Management" \
          8 "System Info" \
          9 "Show Current Configuration")
      elif [ "$TUI_TOOL" = "whiptail" ]; then
        choice=$(whiptail --title "ServerSentry TUI" --menu "Select an action:" 18 50 8 \
          1 "View System Status" \
          2 "Run System Check" \
          3 "View Logs" \
          4 "Configure Settings" \
          5 "Exit" \
          6 "Plugin Management" \
          7 "Notification Management" \
          8 "System Info" \
          9 "Show Current Configuration" 3>&1 1>&2 2>&3)
      else
        echo ""
        echo "ServerSentry TUI"
        echo "================="
        echo "1) View System Status"
        echo "2) Run System Check"
        echo "3) View Logs"
        echo "4) Configure Settings"
        echo "5) Exit"
        echo "6) Plugin Management"
        echo "7) Notification Management"
        echo "8) System Info"
        echo "9) Show Current Configuration"
        read -r -p "Select an action [1-9]: " choice
      fi

      case "$choice" in
      1)
        tui_status
        ;;
      2)
        tui_check
        ;;
      3)
        tui_logs
        ;;
      4)
        tui_configure
        ;;
      5)
        break
        ;;
      6)
        tui_plugin_management
        ;;
      7)
        tui_notification_management
        ;;
      8)
        tui_system_info
        ;;
      9)
        tui_show_config
        ;;
      *)
        if [ "$TUI_TOOL" = "none" ]; then
          echo "Invalid choice."
        fi
        ;;
      esac
    done

    if [ "$TUI_TOOL" = "dialog" ]; then
      clear
    fi
  }

  # Entry point for simple TUI
  show_tui_menu
fi
