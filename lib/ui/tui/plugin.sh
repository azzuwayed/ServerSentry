#!/bin/bash
# TUI plugin management module

source "$(dirname "$0")/utils.sh"

tui_plugin_management() {
  # Read enabled plugins from config
  local config_file="$BASE_DIR/config/serversentry.yaml"
  local enabled_plugins
  if command -v yq >/dev/null 2>&1; then
    enabled_plugins=$(yq e '.plugins.enabled | join(",")' "$config_file" 2>/dev/null)
  else
    enabled_plugins=$(grep '^[[:space:]]*enabled:' "$config_file" | grep -A1 'plugins:' | tail -1 | sed 's/^[[:space:]]*enabled:[[:space:]]*\[//;s/\][[:space:]]*$//;s/[[:space:]]//g')
  fi
  IFS=',' read -ra enabled_array <<<"$enabled_plugins"

  # Find all available plugins (by directory)
  local plugin_dir="$BASE_DIR/lib/plugins"
  local all_plugins=()
  for d in "$plugin_dir"/*/; do
    [ -d "$d" ] || continue
    all_plugins+=("$(basename "$d")")
  done

  # Build menu options
  local menu_opts=()
  for plugin in "${all_plugins[@]}"; do
    local status="disabled"
    for en in "${enabled_array[@]}"; do
      if [ "$plugin" = "$en" ]; then
        status="enabled"
        break
      fi
    done
    menu_opts+=("$plugin" "$status")
  done

  local choice
  if [ "$TUI_TOOL" = "dialog" ]; then
    choice=$(dialog --clear --stdout --title "Plugin Management" \
      --menu "Select a plugin to manage:" 20 60 10 \
      "${menu_opts[@]}" \
      edit "Edit plugin config" \
      back "Return to main menu")
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    choice=$(whiptail --title "Plugin Management" --menu "Select a plugin to manage:" 20 60 10 \
      "${menu_opts[@]}" \
      edit "Edit plugin config" \
      back "Return to main menu" 3>&1 1>&2 2>&3)
  else
    echo -e "\n--- Plugin Management ---"
    for i in "${!all_plugins[@]}"; do
      echo "$((i + 1))) ${all_plugins[$i]} [${menu_opts[$((i * 2 + 1))]}]"
    done
    echo "$((${#all_plugins[@]} + 1))) Edit plugin config"
    echo "$((${#all_plugins[@]} + 2))) Return to main menu"
    read -p "Select a plugin to toggle/edit [1-$((${#all_plugins[@]} + 2))]: " idx
    if [ "$idx" -gt 0 ] && [ "$idx" -le "${#all_plugins[@]}" ]; then
      choice="${all_plugins[$((idx - 1))]}"
    elif [ "$idx" = "$((${#all_plugins[@]} + 1))" ]; then
      choice="edit"
    else
      return
    fi
  fi

  if [ "$choice" = "edit" ]; then
    # Ask which plugin to edit
    if [ "$TUI_TOOL" = "dialog" ] || [ "$TUI_TOOL" = "whiptail" ]; then
      local edit_plugin
      if [ "$TUI_TOOL" = "dialog" ]; then
        edit_plugin=$(dialog --stdout --menu "Select plugin to edit config:" 20 60 10 "${all_plugins[@]}")
      else
        edit_plugin=$(whiptail --menu "Select plugin to edit config:" 20 60 10 "${all_plugins[@]}" 3>&1 1>&2 2>&3)
      fi
      [ -z "$edit_plugin" ] && return
    else
      echo "Select plugin to edit config:"
      select edit_plugin in "${all_plugins[@]}"; do
        [ -n "$edit_plugin" ] && break
      done
    fi
    local plugin_conf="$BASE_DIR/config/plugins/${edit_plugin}.conf"
    ${EDITOR:-vi} "$plugin_conf"
    # Basic validation: check file is not empty
    if [ ! -s "$plugin_conf" ]; then
      echo "Warning: $plugin_conf is empty!"
      read -p "Press Enter to continue..."
    fi
    # Validate YAML after edit (main config)
    if command -v yq >/dev/null 2>&1; then
      if ! yq e . "$BASE_DIR/config/serversentry.yaml" >/dev/null 2>&1; then
        tui_show_message "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
        ${EDITOR:-vi} "$BASE_DIR/config/serversentry.yaml"
      fi
    fi
    tui_plugin_management
    return
  elif [ "$choice" = "back" ]; then
    return
  fi

  # If a plugin was selected, toggle its status
  if [ -n "$choice" ]; then
    local new_enabled=()
    local found=0
    for en in "${enabled_array[@]}"; do
      if [ "$en" = "$choice" ]; then
        found=1
      else
        new_enabled+=("$en")
      fi
    done
    if [ $found -eq 0 ]; then
      new_enabled+=("$choice")
    fi
    # Write new enabled plugins list to config in YAML array format
    local new_line="  enabled: [$(
      IFS=,
      echo \""${new_enabled[*]}"\"
    )]"
    # Update the plugins.enabled line specifically
    if ! sed -i.bak "/^[[:space:]]*enabled:.*# Plugin Configuration/,/^[[:space:]]*enabled:/c\\$new_line" "$config_file" 2>/dev/null; then
      # Fallback method for updating plugins.enabled
      awk -v repl="$new_line" '
        /^plugins:/ { in_plugins=1 }
        in_plugins && /^[[:space:]]*enabled:/ { $0=repl; in_plugins=0 }
        /^[^[:space:]]/ && !/^plugins:/ { in_plugins=0 }
        {print}
      ' "$config_file" >"$config_file.new" && mv "$config_file.new" "$config_file"
    fi
    # Validate YAML after change
    if command -v yq >/dev/null 2>&1; then
      if ! yq e . "$config_file" >/dev/null 2>&1; then
        tui_show_message "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
        ${EDITOR:-vi} "$config_file"
      fi
    fi
    tui_show_message "Plugin '$choice' status toggled." 8 40
    # Recursively call to allow more changes and refresh the menu
    tui_plugin_management
  fi
}

# (This module is intended to be sourced by tui.sh)
