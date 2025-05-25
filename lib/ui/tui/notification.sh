#!/usr/bin/env bash
# TUI notification management module

# Source utilities if not already loaded
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

source "$(dirname "$0")/utils.sh"

tui_notification_management() {
  # Read enabled notification channels from config
  local config_file="$BASE_DIR/config/serversentry.yaml"
  local enabled_channels
  if util_command_exists yq; then
    enabled_channels=$(yq e '.notification_channels | join(",")' "$config_file" 2>/dev/null)
  else
    enabled_channels=$(grep '^notification_channels:' "$config_file" | sed 's/^notification_channels:[[:space:]]*\[//;s/\][[:space:]]*$//;s/[[:space:]]//g')
  fi
  IFS=',' read -ra enabled_array <<<"$enabled_channels"

  # Find all available providers (by directory)
  local provider_dir="$BASE_DIR/lib/notifications"
  local all_providers=()
  for d in "$provider_dir"/*/; do
    [ -d "$d" ] || continue
    all_providers+=("$(basename "$d")")
  done

  # Build menu options
  local menu_opts=()
  for provider in "${all_providers[@]}"; do
    local status="disabled"
    for en in "${enabled_array[@]}"; do
      if [ "$provider" = "$en" ]; then
        status="enabled"
        break
      fi
    done
    menu_opts+=("$provider" "$status")
  done

  local choice
  if [ "$TUI_TOOL" = "dialog" ]; then
    choice=$(dialog --clear --stdout --title "Notification Management" \
      --menu "Select a provider to manage:" 20 60 10 \
      "${menu_opts[@]}" \
      edit "Edit provider config" \
      back "Return to main menu")
  elif [ "$TUI_TOOL" = "whiptail" ]; then
    choice=$(whiptail --title "Notification Management" --menu "Select a provider to manage:" 20 60 10 \
      "${menu_opts[@]}" \
      edit "Edit provider config" \
      back "Return to main menu" 3>&1 1>&2 2>&3)
  else
    echo -e "\n--- Notification Management ---"
    for i in "${!all_providers[@]}"; do
      echo "$((i + 1))) ${all_providers[$i]} [${menu_opts[$((i * 2 + 1))]}]"
    done
    echo "$((${#all_providers[@]} + 1))) Edit provider config"
    echo "$((${#all_providers[@]} + 2))) Return to main menu"
    read -r -p "Select a provider to toggle/edit [1-$((${#all_providers[@]} + 2))]: " idx
    if [ "$idx" -gt 0 ] && [ "$idx" -le "${#all_providers[@]}" ]; then
      choice="${all_providers[$((idx - 1))]}"
    elif [ "$idx" = "$((${#all_providers[@]} + 1))" ]; then
      choice="edit"
    else
      return
    fi
  fi

  if [ "$choice" = "edit" ]; then
    # Ask which provider to edit
    if [ "$TUI_TOOL" = "dialog" ] || [ "$TUI_TOOL" = "whiptail" ]; then
      local edit_provider
      if [ "$TUI_TOOL" = "dialog" ]; then
        edit_provider=$(dialog --stdout --menu "Select provider to edit config:" 20 60 10 "${all_providers[@]}")
      else
        edit_provider=$(whiptail --menu "Select provider to edit config:" 20 60 10 "${all_providers[@]}" 3>&1 1>&2 2>&3)
      fi
      [ -z "$edit_provider" ] && return
    else
      echo "Select provider to edit config:"
      select edit_provider in "${all_providers[@]}"; do
        [ -n "$edit_provider" ] && break
      done
    fi
    local provider_conf="$BASE_DIR/config/notifications/${edit_provider}.conf"
    ${EDITOR:-vi} "$provider_conf"
    # Basic validation: check file is not empty
    if [ ! -s "$provider_conf" ]; then
      echo "Warning: $provider_conf is empty!"
      read -r -p "Press Enter to continue..."
    fi
    # Validate YAML after edit (main config)
    if util_command_exists yq; then
      if ! yq e . "$BASE_DIR/config/serversentry.yaml" >/dev/null 2>&1; then
        tui_show_message "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
        ${EDITOR:-vi} "$BASE_DIR/config/serversentry.yaml"
      fi
    fi
    tui_notification_management
    return
  elif [ "$choice" = "back" ]; then
    return
  fi

  # If a provider was selected, offer to toggle or test
  if [ -n "$choice" ]; then
    local action
    if [ "$TUI_TOOL" = "dialog" ]; then
      action=$(dialog --clear --stdout --title "Provider: $choice" \
        --menu "What would you like to do?" 12 50 2 \
        toggle "Enable/Disable Provider" \
        test "Send Test Notification")
    elif [ "$TUI_TOOL" = "whiptail" ]; then
      action=$(whiptail --title "Provider: $choice" --menu "What would you like to do?" 12 50 2 \
        toggle "Enable/Disable Provider" \
        test "Send Test Notification" 3>&1 1>&2 2>&3)
    else
      echo "1) Enable/Disable Provider"
      echo "2) Send Test Notification"
      read -r -p "Select action [1-2]: " action_idx
      if [ "$action_idx" = "1" ]; then
        action="toggle"
      elif [ "$action_idx" = "2" ]; then
        action="test"
      else
        return
      fi
    fi

    if [ "$action" = "toggle" ]; then
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
      # Write new enabled providers list to config in YAML array format
      local new_line
      new_line="notification_channels: [$(
        IFS=,
        echo \""${new_enabled[*]}"\"
      )]"
      if ! compat_sed_inplace "/^notification_channels:/c\\$new_line" "$config_file" 2>/dev/null; then
        awk -v repl="$new_line" '/^notification_channels:/ {$0=repl} {print}' "$config_file" >"$config_file.new" && mv "$config_file.new" "$config_file"
      fi
      # Validate YAML after change
      if util_command_exists yq; then
        if ! yq e . "$config_file" >/dev/null 2>&1; then
          tui_show_message "YAML syntax error detected in serversentry.yaml! Please fix before continuing." 10 60
          ${EDITOR:-vi} "$config_file"
        fi
      fi
      tui_show_message "Provider '$choice' status toggled." 8 40
      tui_notification_management
    elif [ "$action" = "test" ]; then
      # Try to send a test notification using the provider's script
      local provider_script="$BASE_DIR/lib/notifications/$choice/${choice}.sh"
      if [ ! -f "$provider_script" ]; then
        tui_show_message "Provider script not found: $provider_script" 8 60
        return
      fi
      # Source the provider script and call its send function
      # shellcheck disable=SC1090
      source "$provider_script"
      local result
      if declare -f "${choice}"_provider_send >/dev/null; then
        # Use a generic test message
        result=$("${choice}"_provider_send 1 "Test notification from ServerSentry TUI" "tui" "{\"test\":true}")
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
          tui_show_message "Test notification sent successfully via $choice." 8 60
        else
          tui_show_message "Failed to send test notification via $choice.\n$result" 10 80
        fi
      else
        tui_show_message "Provider send function not found for $choice." 8 60
      fi
      tui_notification_management
    fi
  fi
}

# (This module is intended to be sourced by tui.sh)
