#!/usr/bin/env bash
#
# ServerSentry v2 - CLI Advanced Commands Module
#
# This module handles advanced CLI commands: webhook, template, composite, anomaly, diagnostics, reload, logging

# Function: cmd_tui
# Description: Launch the text-based user interface with enhanced error handling
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_tui
# Dependencies:
#   - util_error_validate_input
#   - TUI script location
cmd_tui() {
  log_info "Launching TUI..." "cli"
  log_audit "launch_tui" "${USER:-unknown}" "User launched TUI interface"

  local tui_script="$BASE_DIR/lib/ui/tui/tui.sh"

  if ! util_error_validate_input "$tui_script" "tui_script" "file"; then
    util_error_log_with_context "TUI script not found: $tui_script" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  # Launch TUI with error handling
  if ! util_error_safe_execute "bash '$tui_script'" "TUI launch failed" "" 2; then
    util_error_log_with_context "Failed to launch TUI interface" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
    return 1
  fi

  return 0
}

# Function: cmd_webhook
# Description: Manage webhooks with enhanced error handling and validation
# Parameters:
#   $1 (string): subcommand (add|remove|list|test|status)
#   $@ (array): additional arguments for subcommand
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_webhook add "https://example.com/webhook"
#   cmd_webhook list
#   cmd_webhook test
# Dependencies:
#   - util_error_validate_input
#   - webhook provider functions
cmd_webhook() {
  local subcommand="$1"
  shift

  if ! util_error_validate_input "$subcommand" "subcommand" "required"; then
    echo "Usage: serversentry webhook [add|remove|list|test|status] ..."
    return 1
  fi

  case "$subcommand" in
  add)
    local url="$1"
    if ! util_error_validate_input "$url" "url" "required"; then
      echo "Usage: serversentry webhook add <URL>"
      return 1
    fi

    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
      util_error_log_with_context "Invalid URL format: $url" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      echo "URL must start with http:// or https://"
      return 1
    fi

    # Add webhook to configuration
    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    local config_dir
    config_dir=$(dirname "$webhook_config")

    if ! mkdir -p "$config_dir" 2>/dev/null; then
      util_error_log_with_context "Cannot create webhook config directory: $config_dir" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    # Check if webhook already exists
    if [[ -f "$webhook_config" ]] && grep -q "webhook_url=\"$url\"" "$webhook_config"; then
      log_warning "Webhook already configured: $url" "cli"
      return 0
    fi

    # Add webhook URL to config
    if ! echo "webhook_url=\"$url\"" >>"$webhook_config"; then
      util_error_log_with_context "Failed to add webhook to config" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    log_info "Webhook added: $url" "cli"
    log_audit "webhook_added" "${USER:-unknown}" "url=$url"
    ;;

  remove)
    local index="$1"
    if ! util_error_validate_input "$index" "index" "numeric"; then
      echo "Usage: serversentry webhook remove <INDEX>"
      echo "Use 'serversentry webhook list' to see webhook indices"
      return 1
    fi

    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if ! util_error_validate_input "$webhook_config" "webhook_config" "file"; then
      log_warning "No webhook configuration found" "cli"
      return 0
    fi

    # Backup and clear webhook URL (simple approach)
    if ! cp "$webhook_config" "$webhook_config.bak"; then
      util_error_log_with_context "Failed to backup webhook config" "$ERROR_PERMISSION_DENIED" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    if ! util_error_safe_execute "compat_sed_inplace '/^webhook_url=/d' '$webhook_config'" "Failed to remove webhook" "" 1; then
      util_error_log_with_context "Failed to remove webhook from config" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    log_info "Webhook configuration cleared" "cli"
    log_audit "webhook_removed" "${USER:-unknown}" "index=$index"
    ;;

  list)
    echo "Configured webhooks:"
    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if [[ -f "$webhook_config" ]]; then
      local webhook_urls
      webhook_urls=$(grep "^webhook_url=" "$webhook_config" 2>/dev/null || true)
      if [[ -n "$webhook_urls" ]]; then
        echo "$webhook_urls" | cut -d'"' -f2 | nl -w2 -s'. '
      else
        echo "No webhooks configured."
      fi
    else
      echo "No webhooks configured."
    fi
    ;;

  test)
    echo "Testing configured webhooks..."

    # Source the webhook provider
    local webhook_provider="$BASE_DIR/lib/notifications/webhook/webhook.sh"
    if ! util_error_validate_input "$webhook_provider" "webhook_provider" "file"; then
      util_error_log_with_context "Webhook provider not found: $webhook_provider" "$ERROR_FILE_NOT_FOUND" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    if ! source "$webhook_provider"; then
      util_error_log_with_context "Failed to source webhook provider" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    # Initialize and test webhook
    if ! util_error_safe_execute "webhook_provider_init" "Webhook initialization failed" "" 1; then
      return 1
    fi

    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if [[ -f "$webhook_config" ]]; then
      if ! util_error_safe_execute "webhook_provider_configure '$webhook_config'" "Webhook configuration failed" "" 1; then
        return 1
      fi
    fi

    if util_error_safe_execute "webhook_provider_test" "Webhook test failed" "" 2; then
      echo "✅ Webhook test completed successfully"
      log_audit "webhook_tested" "${USER:-unknown}" "result=success"
    else
      echo "❌ Webhook test failed"
      log_audit "webhook_tested" "${USER:-unknown}" "result=failure"
      return 1
    fi
    ;;

  status)
    # Show webhook configuration status
    local webhook_provider="$BASE_DIR/lib/notifications/webhook/webhook.sh"
    if ! util_error_validate_input "$webhook_provider" "webhook_provider" "file"; then
      echo "Webhook provider not available"
      return 1
    fi

    if ! source "$webhook_provider"; then
      util_error_log_with_context "Failed to source webhook provider" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi

    if ! util_error_safe_execute "webhook_provider_init" "Webhook initialization failed" "" 1; then
      return 1
    fi

    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if [[ -f "$webhook_config" ]]; then
      if ! util_error_safe_execute "webhook_provider_configure '$webhook_config'" "Webhook configuration failed" "" 1; then
        return 1
      fi
    fi

    if ! util_error_safe_execute "webhook_provider_status" "Failed to get webhook status" "" 1; then
      return 1
    fi
    ;;

  *)
    echo "Usage: serversentry webhook [add|remove|list|test|status] ..."
    echo ""
    echo "Commands:"
    echo "  add <URL>     Add a webhook URL"
    echo "  remove <INDEX> Remove a webhook by index"
    echo "  list          List configured webhooks"
    echo "  test          Test webhook delivery"
    echo "  status        Show webhook configuration status"
    return 1
    ;;
  esac

  return 0
}

# Function: cmd_diagnostics
# Description: Run system diagnostics with enhanced error handling
# Parameters:
#   $1 (string): diagnostic type (optional, defaults to "all")
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_diagnostics
#   cmd_diagnostics system
#   cmd_diagnostics config
# Dependencies:
#   - util_error_safe_execute
#   - diagnostics functions
cmd_diagnostics() {
  local diagnostic_type="${1:-all}"

  log_info "Running system diagnostics: $diagnostic_type" "cli"
  log_audit "run_diagnostics" "${USER:-unknown}" "type=$diagnostic_type"

  case "$diagnostic_type" in
  all)
    echo "Running comprehensive system diagnostics..."
    if ! util_error_safe_execute "diagnostics_run_full" "Full diagnostics failed" "" 3; then
      util_error_log_with_context "Comprehensive diagnostics failed" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  quick)
    echo "Running quick system diagnostics..."
    if ! util_error_safe_execute "diagnostics_run_quick" "Quick diagnostics failed" "" 2; then
      util_error_log_with_context "Quick diagnostics failed" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  system)
    echo "Running system health diagnostics..."
    if ! util_error_safe_execute "diagnostics_check_system_health" "System health check failed" "" 2; then
      util_error_log_with_context "System health diagnostics failed" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  config)
    echo "Running configuration diagnostics..."
    if ! util_error_safe_execute "diagnostics_check_configuration" "Configuration check failed" "" 2; then
      util_error_log_with_context "Configuration diagnostics failed" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  *)
    echo "Usage: serversentry diagnostics [all|quick|system|config]"
    echo ""
    echo "Diagnostic types:"
    echo "  all     - Comprehensive system diagnostics (default)"
    echo "  quick   - Quick system health check"
    echo "  system  - System health diagnostics"
    echo "  config  - Configuration validation"
    return 1
    ;;
  esac

  log_info "Diagnostics completed successfully" "cli"
  return 0
}

# Function: cmd_reload
# Description: Reload configuration or plugins with enhanced error handling
# Parameters:
#   $1 (string): reload type (config|plugins|all) - defaults to "all"
# Returns:
#   0 - success
#   1 - failure
# Example:
#   cmd_reload
#   cmd_reload config
#   cmd_reload plugins
# Dependencies:
#   - util_error_safe_execute
#   - reload functions
cmd_reload() {
  local reload_type="${1:-all}"

  log_info "Reloading: $reload_type" "cli"
  log_audit "reload_request" "${USER:-unknown}" "type=$reload_type"

  case "$reload_type" in
  config)
    echo "Reloading configuration..."
    if ! util_error_safe_execute "reload_configuration" "Configuration reload failed" "" 2; then
      util_error_log_with_context "Failed to reload configuration" "$ERROR_CONFIGURATION_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  plugins)
    echo "Reloading plugins..."
    if ! util_error_safe_execute "reload_plugins" "Plugin reload failed" "" 2; then
      util_error_log_with_context "Failed to reload plugins" "$ERROR_PLUGIN_ERROR" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  all)
    echo "Reloading configuration and plugins..."
    if ! util_error_safe_execute "reload_all" "Full reload failed" "" 3; then
      util_error_log_with_context "Failed to reload system" "$ERROR_GENERAL" "$ERROR_SEVERITY_ERROR" "cli"
      return 1
    fi
    ;;

  *)
    echo "Usage: serversentry reload [config|plugins|all]"
    echo ""
    echo "Reload types:"
    echo "  config  - Reload configuration only"
    echo "  plugins - Reload plugins only"
    echo "  all     - Reload everything (default)"
    return 1
    ;;
  esac

  log_info "Reload completed successfully" "cli"
  log_audit "reload_completed" "${USER:-unknown}" "type=$reload_type"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f cmd_tui
  export -f cmd_webhook
  export -f cmd_diagnostics
  export -f cmd_reload
fi
