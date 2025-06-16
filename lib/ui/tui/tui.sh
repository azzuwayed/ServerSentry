#!/usr/bin/env bash
#
# ServerSentry v2 - Text-based User Interface (TUI) Main Entry Point
#
# This provides both advanced and fallback TUI options

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal
  
  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done
  
  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi
# Initialize with minimal level for TUI
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi

# Get the directory of this script
TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core utilities for unified command checking using bootstrap
if [[ -f "$SERVERSENTRY_CORE_DIR/utils.sh" ]]; then
  serversentry_load_core
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

  SERVERSENTRY_BIN="$SERVERSENTRY_BIN"

  # Source modular TUI components using bootstrap paths
  source "$SERVERSENTRY_UI_DIR/tui/utils.sh"
  source "$SERVERSENTRY_UI_DIR/tui/status.sh"
  source "$SERVERSENTRY_UI_DIR/tui/logs.sh"
  source "$SERVERSENTRY_UI_DIR/tui/sysinfo.sh"
  source "$SERVERSENTRY_UI_DIR/tui/config.sh"
  source "$SERVERSENTRY_UI_DIR/tui/plugin.sh"
  source "$SERVERSENTRY_UI_DIR/tui/notification.sh"

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
