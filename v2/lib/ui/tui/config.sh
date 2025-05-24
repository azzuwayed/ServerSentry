#!/bin/bash
# TUI config module

source "$(dirname "$0")/utils.sh"

tui_configure() {
  local config_file="$BASE_DIR/config/serversentry.yaml"
  if [ "$TUI_TOOL" = "dialog" ]; then
    dialog --msgbox "Launching configuration editor..." 8 40
    ${EDITOR:-vi} "$config_file"
    # Validate YAML after editing
    if command -v yq >/dev/null 2>&1; then
      if ! yq e . "$config_file" >/dev/null 2>&1; then
        dialog --msgbox "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
        ${EDITOR:-vi} "$config_file"
      fi
    fi
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    whiptail --msgbox "Launching configuration editor..." 8 40
    ${EDITOR:-vi} "$config_file"
    if command -v yq >/dev/null 2>&1; then
      if ! yq e . "$config_file" >/dev/null 2>&1; then
        whiptail --msgbox "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
        ${EDITOR:-vi} "$config_file"
      fi
    fi
  else
    echo -e "\n--- Edit Configuration ---"
    ${EDITOR:-vi} "$config_file"
    if command -v yq >/dev/null 2>&1; then
      if ! yq e . "$config_file" >/dev/null 2>&1; then
        echo "YAML syntax error detected in serversentry.yaml! Please fix before continuing."
        ${EDITOR:-vi} "$config_file"
      fi
    fi
    echo -e "--------------------------\n"
    read -p "Press Enter to continue..."
  fi
}

tui_show_config() {
  local config_file="$BASE_DIR/config/serversentry.yaml"
  if [ "$TUI_TOOL" = "dialog" ]; then
    dialog --textbox "$config_file" 30 100
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    whiptail --textbox "$config_file" 30 100
  else
    echo -e "\n--- Current Configuration ---"
    cat "$config_file"
    echo -e "-----------------------------\n"
    read -p "Press Enter to continue..."
  fi
}

# (This module is intended to be sourced by tui.sh)
