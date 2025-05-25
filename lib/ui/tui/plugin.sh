#!/usr/bin/env bash
# TUI plugin management module

# Source utilities if not already loaded
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

source "$(dirname "$0")/utils.sh"

tui_plugin_management() {
  if util_command_exists yq; then
    local plugins_config
    plugins_config=$(yq e '.plugins' "$BASE_DIR/config/serversentry.yaml" 2>/dev/null)
  else
    # shellcheck disable=SC2034
    plugins_config="yq command not available"
  fi

  local choice
  if [ "$TUI_TOOL" = "dialog" ]; then
    choice=$(dialog --clear --stdout --title "Plugin Management" \
      --menu "Select an action:" 15 50 8 \
      1 "List Plugins" \
      2 "Enable Plugin" \
      3 "Disable Plugin" \
      4 "Configure Plugin" \
      5 "Test Plugin" \
      6 "Return to Main Menu")
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    choice=$(whiptail --title "Plugin Management" --menu "Select an action:" 15 50 8 \
      1 "List Plugins" \
      2 "Enable Plugin" \
      3 "Disable Plugin" \
      4 "Configure Plugin" \
      5 "Test Plugin" \
      6 "Return to Main Menu" 3>&1 1>&2 2>&3)
  else
    echo ""
    echo "Plugin Management"
    echo "================="
    echo "1) List Plugins"
    echo "2) Enable Plugin"
    echo "3) Disable Plugin"
    echo "4) Configure Plugin"
    echo "5) Test Plugin"
    echo "6) Return to Main Menu"
    read -r -p "Select an action [1-6]: " choice
  fi

  case "$choice" in
  1) tui_list_plugins ;;
  2) tui_enable_plugin ;;
  3) tui_disable_plugin ;;
  4) tui_configure_plugin ;;
  5) tui_test_plugin ;;
  6) return ;;
  *)
    if [ "$TUI_TOOL" = "none" ]; then
      echo "Invalid choice."
    fi
    ;;
  esac

  # Recursive call to show menu again
  tui_plugin_management
}

tui_list_plugins() {
  check_serversentry_bin || return

  local plugin_list
  plugin_list=$("$SERVERSENTRY_BIN" list 2>&1)

  tui_show_message "Available Plugins:\n\n$plugin_list" 15 60
}

tui_enable_plugin() {
  local plugin_name

  if [ "$TUI_TOOL" = "dialog" ]; then
    plugin_name=$(dialog --stdout --inputbox "Enter plugin name to enable:" 8 40)
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    plugin_name=$(whiptail --inputbox "Enter plugin name to enable:" 8 40 3>&1 1>&2 2>&3)
  else
    read -r -p "Enter plugin name to enable: " plugin_name
  fi

  if [ -n "$plugin_name" ]; then
    # This would need to be implemented in the main config
    tui_show_message "Plugin enabling not implemented in TUI yet. Please edit config manually." 8 60
  fi
}

tui_disable_plugin() {
  local plugin_name

  if [ "$TUI_TOOL" = "dialog" ]; then
    plugin_name=$(dialog --stdout --inputbox "Enter plugin name to disable:" 8 40)
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    plugin_name=$(whiptail --inputbox "Enter plugin name to disable:" 8 40 3>&1 1>&2 2>&3)
  else
    read -r -p "Enter plugin name to disable: " plugin_name
  fi

  if [ -n "$plugin_name" ]; then
    # This would need to be implemented
    tui_show_message "Plugin disabling not implemented in TUI yet. Please edit config manually." 8 60
  fi
}

tui_configure_plugin() {
  local plugin_name

  if [ "$TUI_TOOL" = "dialog" ]; then
    plugin_name=$(dialog --stdout --inputbox "Enter plugin name to configure:" 8 40)
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    plugin_name=$(whiptail --inputbox "Enter plugin name to configure:" 8 40 3>&1 1>&2 2>&3)
  else
    read -r -p "Enter plugin name to configure: " plugin_name
  fi

  if [ -n "$plugin_name" ]; then
    local plugin_config="$BASE_DIR/config/plugins/${plugin_name}.conf"
    if [ -f "$plugin_config" ]; then
      ${EDITOR:-vi} "$plugin_config"
      # Validate configuration after edit
      if util_command_exists yq; then
        if ! yq e . "$plugin_config" >/dev/null 2>&1; then
          tui_show_message "Configuration syntax error detected! Please fix before continuing." 10 60
          ${EDITOR:-vi} "$plugin_config"
        fi
      fi
    else
      tui_show_message "Plugin configuration file not found: $plugin_config" 8 60
    fi
  fi
}

tui_test_plugin() {
  check_serversentry_bin || return

  local plugin_name

  if [ "$TUI_TOOL" = "dialog" ]; then
    plugin_name=$(dialog --stdout --inputbox "Enter plugin name to test (leave empty for all):" 8 50)
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    plugin_name=$(whiptail --inputbox "Enter plugin name to test (leave empty for all):" 8 50 3>&1 1>&2 2>&3)
  else
    read -r -p "Enter plugin name to test (leave empty for all): " plugin_name
  fi

  local test_result
  if [ -n "$plugin_name" ]; then
    test_result=$("$SERVERSENTRY_BIN" check "$plugin_name" 2>&1)
  else
    test_result=$("$SERVERSENTRY_BIN" check 2>&1)
  fi

  tui_show_message "Plugin Test Results:\n\n$test_result" 20 80
}

# (This module is intended to be sourced by tui.sh)
