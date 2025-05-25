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

  # Get enabled plugins from config
  local enabled_plugins=""
  if util_command_exists yq; then
    enabled_plugins=$(yq e '.plugins.enabled[]' "$BASE_DIR/config/serversentry.yaml" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
  fi

  local display_text="Available Plugins:\n\n$plugin_list"
  if [[ -n "$enabled_plugins" ]]; then
    display_text+="\n\nCurrently Enabled: $enabled_plugins"
  fi

  tui_show_message "$display_text" 20 70
}

# Get list of available plugins from plugin directory
_get_available_plugins() {
  local available_plugins=()

  if [[ -d "$BASE_DIR/lib/plugins" ]]; then
    for plugin_dir in "$BASE_DIR/lib/plugins"/*; do
      if [[ -d "$plugin_dir" ]]; then
        local plugin_name=$(basename "$plugin_dir")
        if [[ -f "$plugin_dir/${plugin_name}.sh" ]]; then
          available_plugins+=("$plugin_name")
        fi
      fi
    done
  fi

  printf '%s\n' "${available_plugins[@]}"
}

# Get list of currently enabled plugins
_get_enabled_plugins() {
  local enabled_plugins=()

  if util_command_exists yq; then
    while IFS= read -r plugin; do
      [[ -n "$plugin" ]] && enabled_plugins+=("$plugin")
    done < <(yq e '.plugins.enabled[]' "$BASE_DIR/config/serversentry.yaml" 2>/dev/null)
  fi

  printf '%s\n' "${enabled_plugins[@]}"
}

# Update plugins.enabled array in YAML config
_update_plugins_config() {
  local plugins_array=("$@")
  local config_file="$BASE_DIR/config/serversentry.yaml"

  # Create backup
  cp "$config_file" "${config_file}.bak" 2>/dev/null || true

  if util_command_exists yq; then
    # Use yq to update the array
    local yq_array=""
    for plugin in "${plugins_array[@]}"; do
      if [[ -n "$yq_array" ]]; then
        yq_array+=", "
      fi
      yq_array+="\"$plugin\""
    done

    if yq e ".plugins.enabled = [$yq_array]" "$config_file" >"${config_file}.tmp" 2>/dev/null; then
      mv "${config_file}.tmp" "$config_file"
      return 0
    else
      # Restore backup on failure
      [[ -f "${config_file}.bak" ]] && mv "${config_file}.bak" "$config_file"
      return 1
    fi
  else
    # Fallback: manual YAML editing
    local new_line="  enabled: [$(
      IFS=', '
      echo "${plugins_array[*]}"
    ))]"

    if awk -v repl="$new_line" '
      /^[[:space:]]*enabled:[[:space:]]*\[/ { print repl; next }
      { print }
    ' "$config_file" >"${config_file}.tmp"; then
      mv "${config_file}.tmp" "$config_file"
      return 0
    else
      # Restore backup on failure
      [[ -f "${config_file}.bak" ]] && mv "${config_file}.bak" "$config_file"
      return 1
    fi
  fi
}

tui_enable_plugin() {
  local available_plugins
  mapfile -t available_plugins < <(_get_available_plugins)

  local enabled_plugins
  mapfile -t enabled_plugins < <(_get_enabled_plugins)

  if [[ ${#available_plugins[@]} -eq 0 ]]; then
    tui_show_message "No plugins found in $BASE_DIR/lib/plugins" 8 50
    return
  fi

  # Create list of plugins that are not currently enabled
  local disabled_plugins=()
  for plugin in "${available_plugins[@]}"; do
    local is_enabled=false
    for enabled in "${enabled_plugins[@]}"; do
      if [[ "$plugin" == "$enabled" ]]; then
        is_enabled=true
        break
      fi
    done
    if [[ "$is_enabled" == "false" ]]; then
      disabled_plugins+=("$plugin")
    fi
  done

  if [[ ${#disabled_plugins[@]} -eq 0 ]]; then
    tui_show_message "All available plugins are already enabled." 8 50
    return
  fi

  local plugin_name
  if [ "$TUI_TOOL" = "dialog" ]; then
    local menu_items=()
    for i in "${!disabled_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${disabled_plugins[i]}")
    done

    local selection
    selection=$(dialog --stdout --title "Enable Plugin" \
      --menu "Select plugin to enable:" 15 50 8 "${menu_items[@]}")

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${disabled_plugins[$((selection - 1))]}"
    fi
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    local menu_items=()
    for i in "${!disabled_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${disabled_plugins[i]}")
    done

    local selection
    selection=$(whiptail --title "Enable Plugin" \
      --menu "Select plugin to enable:" 15 50 8 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${disabled_plugins[$((selection - 1))]}"
    fi
  else
    echo "Available plugins to enable:"
    for i in "${!disabled_plugins[@]}"; do
      echo "$((i + 1))) ${disabled_plugins[i]}"
    done
    read -r -p "Select plugin number to enable: " selection

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 && "$selection" -le ${#disabled_plugins[@]} ]]; then
      plugin_name="${disabled_plugins[$((selection - 1))]}"
    fi
  fi

  if [[ -n "$plugin_name" ]]; then
    # Add plugin to enabled list
    local new_enabled_plugins=("${enabled_plugins[@]}" "$plugin_name")

    if _update_plugins_config "${new_enabled_plugins[@]}"; then
      tui_show_message "✅ Plugin '$plugin_name' has been enabled successfully.\n\nRestart ServerSentry for changes to take effect." 10 60
    else
      tui_show_message "❌ Failed to enable plugin '$plugin_name'.\nPlease check configuration file permissions." 10 60
    fi
  fi
}

tui_disable_plugin() {
  local enabled_plugins
  mapfile -t enabled_plugins < <(_get_enabled_plugins)

  if [[ ${#enabled_plugins[@]} -eq 0 ]]; then
    tui_show_message "No plugins are currently enabled." 8 50
    return
  fi

  local plugin_name
  if [ "$TUI_TOOL" = "dialog" ]; then
    local menu_items=()
    for i in "${!enabled_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${enabled_plugins[i]}")
    done

    local selection
    selection=$(dialog --stdout --title "Disable Plugin" \
      --menu "Select plugin to disable:" 15 50 8 "${menu_items[@]}")

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${enabled_plugins[$((selection - 1))]}"
    fi
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    local menu_items=()
    for i in "${!enabled_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${enabled_plugins[i]}")
    done

    local selection
    selection=$(whiptail --title "Disable Plugin" \
      --menu "Select plugin to disable:" 15 50 8 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${enabled_plugins[$((selection - 1))]}"
    fi
  else
    echo "Currently enabled plugins:"
    for i in "${!enabled_plugins[@]}"; do
      echo "$((i + 1))) ${enabled_plugins[i]}"
    done
    read -r -p "Select plugin number to disable: " selection

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 && "$selection" -le ${#enabled_plugins[@]} ]]; then
      plugin_name="${enabled_plugins[$((selection - 1))]}"
    fi
  fi

  if [[ -n "$plugin_name" ]]; then
    # Remove plugin from enabled list
    local new_enabled_plugins=()
    for plugin in "${enabled_plugins[@]}"; do
      if [[ "$plugin" != "$plugin_name" ]]; then
        new_enabled_plugins+=("$plugin")
      fi
    done

    if _update_plugins_config "${new_enabled_plugins[@]}"; then
      tui_show_message "✅ Plugin '$plugin_name' has been disabled successfully.\n\nRestart ServerSentry for changes to take effect." 10 60
    else
      tui_show_message "❌ Failed to disable plugin '$plugin_name'.\nPlease check configuration file permissions." 10 60
    fi
  fi
}

tui_configure_plugin() {
  local available_plugins
  mapfile -t available_plugins < <(_get_available_plugins)

  if [[ ${#available_plugins[@]} -eq 0 ]]; then
    tui_show_message "No plugins found in $BASE_DIR/lib/plugins" 8 50
    return
  fi

  local plugin_name
  if [ "$TUI_TOOL" = "dialog" ]; then
    local menu_items=()
    for i in "${!available_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${available_plugins[i]}")
    done

    local selection
    selection=$(dialog --stdout --title "Configure Plugin" \
      --menu "Select plugin to configure:" 15 50 8 "${menu_items[@]}")

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${available_plugins[$((selection - 1))]}"
    fi
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    local menu_items=()
    for i in "${!available_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${available_plugins[i]}")
    done

    local selection
    selection=$(whiptail --title "Configure Plugin" \
      --menu "Select plugin to configure:" 15 50 8 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      plugin_name="${available_plugins[$((selection - 1))]}"
    fi
  else
    echo "Available plugins:"
    for i in "${!available_plugins[@]}"; do
      echo "$((i + 1))) ${available_plugins[i]}"
    done
    read -r -p "Select plugin number to configure: " selection

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 && "$selection" -le ${#available_plugins[@]} ]]; then
      plugin_name="${available_plugins[$((selection - 1))]}"
    fi
  fi

  if [[ -n "$plugin_name" ]]; then
    local plugin_config="$BASE_DIR/config/plugins/${plugin_name}.conf"

    # Create default config if it doesn't exist
    if [[ ! -f "$plugin_config" ]]; then
      local config_dir="$BASE_DIR/config/plugins"
      mkdir -p "$config_dir" 2>/dev/null || true

      # Create basic configuration template
      cat >"$plugin_config" <<EOF
# ${plugin_name^} Plugin Configuration
# Generated by ServerSentry TUI

# Alert threshold (percentage)
${plugin_name}_threshold=90

# Warning threshold (percentage)
${plugin_name}_warning_threshold=80

# Check interval in seconds
${plugin_name}_check_interval=60

# Plugin-specific settings
# Add your custom configuration here
EOF

      tui_show_message "Created default configuration file:\n$plugin_config" 8 60
    fi

    # Open configuration file in editor
    if [[ -f "$plugin_config" ]]; then
      ${EDITOR:-vi} "$plugin_config"

      # Validate configuration after edit
      if util_command_exists yq && [[ "$plugin_config" == *.yaml || "$plugin_config" == *.yml ]]; then
        if ! yq e . "$plugin_config" >/dev/null 2>&1; then
          tui_show_message "⚠️  Configuration syntax error detected!\nPlease fix before continuing." 10 60
          ${EDITOR:-vi} "$plugin_config"
        fi
      fi

      tui_show_message "✅ Plugin configuration updated.\n\nRestart ServerSentry for changes to take effect." 8 60
    else
      tui_show_message "❌ Failed to create configuration file:\n$plugin_config" 8 60
    fi
  fi
}

tui_test_plugin() {
  check_serversentry_bin || return

  local available_plugins
  mapfile -t available_plugins < <(_get_available_plugins)

  if [[ ${#available_plugins[@]} -eq 0 ]]; then
    tui_show_message "No plugins found in $BASE_DIR/lib/plugins" 8 50
    return
  fi

  # Add "All Plugins" option
  local test_options=("all" "${available_plugins[@]}")

  local plugin_name
  if [ "$TUI_TOOL" = "dialog" ]; then
    local menu_items=()
    menu_items+=("0" "All Plugins")
    for i in "${!available_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${available_plugins[i]}")
    done

    local selection
    selection=$(dialog --stdout --title "Test Plugin" \
      --menu "Select plugin to test:" 15 50 8 "${menu_items[@]}")

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      if [[ "$selection" -eq 0 ]]; then
        plugin_name="all"
      else
        plugin_name="${available_plugins[$((selection - 1))]}"
      fi
    fi
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    local menu_items=()
    menu_items+=("0" "All Plugins")
    for i in "${!available_plugins[@]}"; do
      menu_items+=("$((i + 1))" "${available_plugins[i]}")
    done

    local selection
    selection=$(whiptail --title "Test Plugin" \
      --menu "Select plugin to test:" 15 50 8 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      if [[ "$selection" -eq 0 ]]; then
        plugin_name="all"
      else
        plugin_name="${available_plugins[$((selection - 1))]}"
      fi
    fi
  else
    echo "Available plugins to test:"
    echo "0) All Plugins"
    for i in "${!available_plugins[@]}"; do
      echo "$((i + 1))) ${available_plugins[i]}"
    done
    read -r -p "Select plugin number to test (0 for all): " selection

    if [[ -n "$selection" && "$selection" =~ ^[0-9]+$ ]]; then
      if [[ "$selection" -eq 0 ]]; then
        plugin_name="all"
      elif [[ "$selection" -ge 1 && "$selection" -le ${#available_plugins[@]} ]]; then
        plugin_name="${available_plugins[$((selection - 1))]}"
      fi
    fi
  fi

  if [[ -n "$plugin_name" ]]; then
    local test_result
    if [[ "$plugin_name" == "all" ]]; then
      test_result=$("$SERVERSENTRY_BIN" check 2>&1)
    else
      test_result=$("$SERVERSENTRY_BIN" check "$plugin_name" 2>&1)
    fi

    tui_show_message "Plugin Test Results:\n\n$test_result" 25 90
  fi
}

# (This module is intended to be sourced by tui.sh)
