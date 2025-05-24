#!/usr/bin/env bash
# TUI configuration management module

# Source utilities if not already loaded
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

source "$(dirname "$0")/utils.sh"

tui_show_config() {
  local config_content
  if util_command_exists yq; then
    config_content=$(yq . "$MAIN_CONFIG" 2>/dev/null)
  else
    config_content=$(cat "$MAIN_CONFIG" 2>/dev/null)
  fi

  tui_show_message "Current Configuration:\n\n$config_content" 25 80
}

tui_configure() {
  if util_command_exists yq; then
    config_content=$(yq . "$MAIN_CONFIG" 2>/dev/null)
  else
    config_content="yq command not available, showing raw config"
  fi

  if [ "$TUI_TOOL" = "dialog" ] || [ "$TUI_TOOL" = "whiptail" ]; then
    local edit_choice
    if [ "$TUI_TOOL" = "dialog" ]; then
      edit_choice=$(dialog --stdout --yesno "Do you want to edit the configuration file directly?" 8 60 && echo "yes" || echo "no")
    else
      edit_choice=$(whiptail --yesno "Do you want to edit the configuration file directly?" 8 60 && echo "yes" || echo "no")
    fi

    if [ "$edit_choice" = "yes" ]; then
      ${EDITOR:-vi} "$MAIN_CONFIG"
      # Validate YAML after edit
      if util_command_exists yq; then
        if ! yq . "$MAIN_CONFIG" >/dev/null 2>&1; then
          tui_show_message "YAML syntax error detected! Please fix before continuing." 10 60
          ${EDITOR:-vi} "$MAIN_CONFIG"
        fi
      fi
    fi
  else
    echo "Current configuration file: $MAIN_CONFIG"
    read -p "Do you want to edit it? [y/N]: " edit_choice
    if [[ "$edit_choice" =~ ^[Yy] ]]; then
      ${EDITOR:-vi} "$MAIN_CONFIG"
    fi
  fi
}

# (This module is intended to be sourced by tui.sh)
