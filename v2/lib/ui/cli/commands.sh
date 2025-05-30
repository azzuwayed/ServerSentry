#!/bin/bash
#
# ServerSentry v2 - CLI Commands
#
# This module handles the command-line interface commands

# Help text
show_help() {
  cat <<EOF
ServerSentry v2 - Server Monitoring Tool

Usage: serversentry [options] [command]

Commands:
  status              Show current status of all monitors
  start               Start monitoring in background
  stop                Stop monitoring
  check [plugin]      Run a specific plugin check (or all if not specified)
  list                List available plugins
  configure           Configure ServerSentry
  logs                View or manage logs
  version             Show version information
  help                Show this help message
  tui                 Launch the text-based user interface (TUI)
  webhook             Manage webhooks (add, remove, list, test, status)
  template            Manage notification templates (list, validate, test)
  composite           Manage composite checks (list, test, enable, disable)
  anomaly             Manage anomaly detection (list, test, summary, config)
  diagnostics         Run system diagnostics and health checks
  reload              Reload configuration or plugins without restart
  update-threshold    Update a threshold value (e.g., cpu_threshold=85)
  list-thresholds     List all thresholds and configuration
  monitor             Run continuous monitoring daemon

Options:
  -v, --verbose       Enable verbose output
  -c, --config FILE   Use alternative config file
  -d, --debug         Enable debug mode
  -h, --help          Show this help message
EOF
}

# Process command line arguments
process_commands() {
  # Default command
  local command="status"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    # Options
    -v | --verbose)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
      shift
      ;;
    -c | --config)
      MAIN_CONFIG="$2"
      shift 2
      ;;
    -d | --debug)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
      set -x # Enable shell debug mode
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    # Commands
    status | start | stop | check | list | configure | logs | version | help | tui | webhook | template | update-threshold | list-thresholds | composite | anomaly | reload | diagnostics | monitor)
      command="$1"
      shift
      break
      ;;
    # Unknown option/command
    *)
      if [[ "$1" == -* ]]; then
        log_error "Unknown option: $1"
        show_help
        exit 1
      else
        command="$1"
        shift
        break
      fi
      ;;
    esac
  done

  # Execute the command
  case "$command" in
  status)
    cmd_status "$@"
    ;;
  start)
    cmd_start "$@"
    ;;
  stop)
    cmd_stop "$@"
    ;;
  check)
    cmd_check "$@"
    ;;
  list)
    cmd_list "$@"
    ;;
  configure)
    cmd_configure "$@"
    ;;
  logs)
    cmd_logs "$@"
    ;;
  version)
    cmd_version "$@"
    ;;
  help)
    show_help
    ;;
  tui)
    cmd_tui "$@"
    ;;
  webhook)
    cmd_webhook "$@"
    ;;
  template)
    cmd_template "$@"
    ;;
  update-threshold)
    cmd_update_threshold "$@"
    ;;
  list-thresholds)
    cmd_list_thresholds "$@"
    ;;
  composite)
    cmd_composite "$@"
    ;;
  anomaly)
    cmd_anomaly "$@"
    ;;
  reload)
    cmd_reload "$@"
    ;;
  diagnostics)
    cmd_diagnostics "$@"
    ;;
  monitor)
    cmd_monitor "$@"
    ;;
  *)
    log_error "Unknown command: $command"
    show_help
    exit 1
    ;;
  esac
}

# Command: status
cmd_status() {
  # Source colors if available
  if [ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]; then
    source "$BASE_DIR/lib/ui/cli/colors.sh"
  fi

  print_header "ServerSentry Status" 60

  log_info "Checking system status..."

  # Check if monitoring is running
  if is_monitoring_running; then
    print_status "ok" "Monitoring service is running"
  else
    print_status "warning" "Monitoring service is stopped"
  fi

  echo ""

  # Run all plugin checks
  log_debug "Running all plugin checks"
  local results
  results=$(run_all_plugin_checks)

  # Parse and display results with colors
  if command -v jq >/dev/null 2>&1 && [ -n "$results" ]; then
    echo "$results" | jq -r '.plugins[]? | "\(.name)|\(.status_code)|\(.status_message)|\(.metrics.value // "N/A")|\(.metrics.threshold // "N/A")"' | while IFS='|' read -r plugin status_code message value threshold; do
      if [ -n "$plugin" ]; then
        case "$status_code" in
        0)
          print_status "ok" "$plugin: $message"
          if [ "$value" != "N/A" ] && [ "$threshold" != "N/A" ]; then
            create_metric_bar "$value" "$threshold" "  └─ Usage"
          fi
          ;;
        1)
          print_status "warning" "$plugin: $message"
          if [ "$value" != "N/A" ] && [ "$threshold" != "N/A" ]; then
            create_metric_bar "$value" "$threshold" "  └─ Usage"
          fi
          ;;
        2)
          print_status "error" "$plugin: $message"
          if [ "$value" != "N/A" ] && [ "$threshold" != "N/A" ]; then
            create_metric_bar "$value" "$threshold" "  └─ Usage"
          fi
          ;;
        *)
          print_status "info" "$plugin: $message"
          ;;
        esac
      fi
    done
  else
    # Fallback display without jq
    echo "$results"
  fi

  print_separator
  echo ""
}

# Command: start
cmd_start() {
  log_info "Starting monitoring..."

  # Check if already running
  if is_monitoring_running; then
    log_warning "Monitoring is already running"
    return 0
  fi

  # Start the monitoring process in the background
  nohup "$BASE_DIR/bin/serversentry" monitor >/dev/null 2>&1 &
  echo $! >"${BASE_DIR}/serversentry.pid"

  log_info "Monitoring started with PID $(cat "${BASE_DIR}/serversentry.pid")"
}

# Command: stop
cmd_stop() {
  log_info "Stopping monitoring..."

  # Check if running
  if ! is_monitoring_running; then
    log_warning "Monitoring is not running"
    return 0
  fi

  # Get PID
  local pid
  pid=$(cat "${BASE_DIR}/serversentry.pid" 2>/dev/null)

  if [ -n "$pid" ]; then
    # Kill the process
    kill "$pid" 2>/dev/null
    rm -f "${BASE_DIR}/serversentry.pid"
    log_info "Monitoring stopped"
  else
    log_error "Could not find monitoring PID"
    return 1
  fi
}

# Command: check
cmd_check() {
  local plugin_name="$1"

  if [ -z "$plugin_name" ]; then
    # Check all plugins
    log_info "Running all plugin checks..."
    run_all_plugin_checks | jq
  else
    # Check specific plugin
    log_info "Running check for plugin: $plugin_name"
    if is_plugin_registered "$plugin_name"; then
      run_plugin_check "$plugin_name" | jq
    else
      log_error "Plugin not found: $plugin_name"
      echo "Available plugins:"
      list_plugins
      return 1
    fi
  fi
}

# Command: list
cmd_list() {
  log_info "Listing available plugins..."
  list_plugins
}

# Command: configure
cmd_configure() {
  log_info "Opening configuration..."

  # Open with default editor
  ${EDITOR:-vi} "$MAIN_CONFIG"
}

# Command: logs
cmd_logs() {
  local subcommand="${1:-view}"

  case "$subcommand" in
  view)
    # View logs
    tail -n 50 "$LOG_FILE"
    ;;
  rotate)
    # Rotate logs
    rotate_logs
    ;;
  clear)
    # Clear logs
    log_warning "Clearing logs..."
    >"$LOG_FILE"
    ;;
  *)
    log_error "Unknown logs subcommand: $subcommand"
    echo "Available subcommands: view, rotate, clear"
    return 1
    ;;
  esac
}

# Command: version
cmd_version() {
  echo "ServerSentry v2.0.0"
  echo "Plugin Interface v${PLUGIN_INTERFACE_VERSION}"
}

# Check if monitoring is running
is_monitoring_running() {
  local pid_file="${BASE_DIR}/serversentry.pid"

  if [ -f "$pid_file" ]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)

    if [ -n "$pid" ] && ps -p "$pid" >/dev/null; then
      return 0 # Running
    fi
  fi

  return 1 # Not running
}

cmd_tui() {
  log_info "Launching TUI..."
  "$BASE_DIR/lib/ui/tui/tui.sh"
}

# Command: webhook
cmd_webhook() {
  local subcommand="$1"
  shift
  case "$subcommand" in
  add)
    local url="$1"
    if [ -z "$url" ]; then
      echo "Usage: serversentry webhook add <URL>"
      return 1
    fi
    # Add webhook to generic webhook config
    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"

    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$webhook_config")"

    # Check if webhook already exists
    if [ -f "$webhook_config" ] && grep -q "webhook_url=\"$url\"" "$webhook_config"; then
      echo "Webhook already configured: $url"
      return 0
    fi

    # Add webhook URL to config
    echo "webhook_url=\"$url\"" >>"$webhook_config"
    echo "Webhook added: $url"
    ;;
  remove)
    local index="$1"
    if [ -z "$index" ]; then
      echo "Usage: serversentry webhook remove <INDEX>"
      echo "Use 'serversentry webhook list' to see webhook indices"
      return 1
    fi
    # Remove webhook by clearing the config (simple approach for now)
    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if [ -f "$webhook_config" ]; then
      # Backup and clear webhook URL
      cp "$webhook_config" "$webhook_config.bak"
      sed -i '/^webhook_url=/d' "$webhook_config"
      echo "Webhook configuration cleared."
    else
      echo "No webhook configuration found."
    fi
    ;;
  list)
    echo "Configured webhooks:"
    local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
    if [ -f "$webhook_config" ]; then
      grep "^webhook_url=" "$webhook_config" | cut -d'"' -f2 | nl -w2 -s'. '
    else
      echo "No webhooks configured."
    fi
    ;;
  test)
    echo "Testing configured webhooks..."

    # Source the webhook provider
    if [ -f "$BASE_DIR/lib/notifications/webhook/webhook.sh" ]; then
      source "$BASE_DIR/lib/notifications/webhook/webhook.sh"

      # Initialize the webhook provider
      webhook_provider_init

      # Configure from config file
      local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
      if [ -f "$webhook_config" ]; then
        webhook_provider_configure "$webhook_config"
      fi

      # Test the webhook
      if webhook_provider_test; then
        echo "✅ Webhook test completed successfully"
      else
        echo "❌ Webhook test failed"
        return 1
      fi
    else
      echo "❌ Webhook provider not found"
      return 1
    fi
    ;;
  status)
    # Show webhook configuration status
    if [ -f "$BASE_DIR/lib/notifications/webhook/webhook.sh" ]; then
      source "$BASE_DIR/lib/notifications/webhook/webhook.sh"
      webhook_provider_init
      local webhook_config="$BASE_DIR/config/notifications/webhook.conf"
      if [ -f "$webhook_config" ]; then
        webhook_provider_configure "$webhook_config"
      fi
      webhook_provider_status
    else
      echo "Webhook provider not available"
    fi
    ;;
  *)
    echo "Usage: serversentry webhook [add|remove|list|test|status] ..."
    echo ""
    echo "Commands:"
    echo "  add <URL>     Add a webhook URL"
    echo "  remove <IDX>  Remove webhook by index"
    echo "  list          List all configured webhooks"
    echo "  test          Test webhook connectivity"
    echo "  status        Show webhook configuration status"
    return 1
    ;;
  esac
}

# Command: update-threshold
cmd_update_threshold() {
  local param="$1"
  if [ -z "$param" ]; then
    echo "Usage: serversentry update-threshold NAME=VALUE"
    return 1
  fi
  local name="$(echo "$param" | cut -d= -f1)"
  local value="$(echo "$param" | cut -d= -f2)"
  if [ -z "$name" ] || [ -z "$value" ]; then
    echo "Invalid format. Use NAME=VALUE."
    return 1
  fi
  # Update in YAML config (serversentry.yaml)
  # Use yq if available, else sed
  if command -v yq >/dev/null 2>&1; then
    yq -i ".${name} = ${value}" "$MAIN_CONFIG"
    echo "Updated $name to $value in $MAIN_CONFIG"
  else
    # Fallback: naive sed (may not work for all YAML)
    sed -i.bak "/^${name}:/c\${name}: ${value}" "$MAIN_CONFIG"
    echo "Updated $name to $value in $MAIN_CONFIG (sed)"
  fi
}

# Command: list-thresholds
cmd_list_thresholds() {
  echo "Current thresholds and configuration:"
  grep -E 'threshold|interval|timeout|max_|min_' "$MAIN_CONFIG"
}

# Command: template
cmd_template() {
  local subcommand="$1"
  shift

  # Source the template system
  if [ -f "$BASE_DIR/lib/core/templates.sh" ]; then
    source "$BASE_DIR/lib/core/templates.sh"
    init_template_system
  else
    echo "❌ Template system not available"
    return 1
  fi

  case "$subcommand" in
  list)
    list_templates
    ;;
  validate)
    local template_file="$1"
    if [ -z "$template_file" ]; then
      echo "Usage: serversentry template validate <template_file>"
      return 1
    fi
    validate_template "$template_file"
    ;;
  test)
    local provider="${1:-webhook}"
    local notification_type="${2:-test}"
    echo "Testing template for provider='$provider' type='$notification_type'..."

    local content
    content=$(generate_notification_content "$notification_type" "$provider" 0 "Test notification message" "test" '{"test": true}')

    if [ $? -eq 0 ]; then
      echo "✅ Template test successful"
      echo ""
      echo "Generated content:"
      echo "==================="
      echo "$content"
    else
      echo "❌ Template test failed"
      return 1
    fi
    ;;
  create)
    local template_name="$1"
    local provider="$2"
    if [ -z "$template_name" ] || [ -z "$provider" ]; then
      echo "Usage: serversentry template create <name> <provider>"
      echo "Example: serversentry template create my_alert teams"
      return 1
    fi

    local template_file="$TEMPLATE_DIR/${provider}_${template_name}.template"
    mkdir -p "$(dirname "$template_file")"

    if [ -f "$template_file" ]; then
      echo "Template already exists: $template_file"
      return 1
    fi

    # Create a basic template
    cat >"$template_file" <<'EOF'
{status_text} Alert from {hostname}

Message: {status_message}
Plugin: {plugin_name}
Time: {timestamp}

Metrics: {metrics}

---
ServerSentry v2
EOF

    echo "✅ Created template: $template_file"
    echo "Edit this file to customize your template."
    ;;
  *)
    echo "Usage: serversentry template [list|validate|test|create] ..."
    echo ""
    echo "Commands:"
    echo "  list                     List all available templates"
    echo "  validate <file>          Validate a template file"
    echo "  test [provider] [type]   Test template generation (default: webhook test)"
    echo "  create <name> <provider> Create a new custom template"
    return 1
    ;;
  esac
}

# Command: composite
cmd_composite() {
  local subcommand="$1"
  shift

  # Source the composite system
  if [ -f "$BASE_DIR/lib/core/composite.sh" ]; then
    source "$BASE_DIR/lib/core/composite.sh"
    init_composite_system
  else
    echo "❌ Composite check system not available"
    return 1
  fi

  case "$subcommand" in
  list)
    list_composite_checks
    ;;
  test)
    local check_name="$1"
    echo "Testing composite checks..."

    # Get current plugin results
    local plugin_results
    plugin_results=$(run_all_plugin_checks)

    if [ -n "$check_name" ]; then
      # Test specific composite check
      local config_file="$COMPOSITE_CONFIG_DIR/${check_name}.conf"
      if [ -f "$config_file" ]; then
        echo "Running composite check: $check_name"
        run_composite_check "$config_file" "$plugin_results" | jq
      else
        echo "❌ Composite check not found: $check_name"
        echo "Available checks:"
        list_composite_checks
        return 1
      fi
    else
      # Test all composite checks
      echo "Running all composite checks..."
      run_all_composite_checks "$plugin_results" | jq
    fi
    ;;
  enable)
    local check_name="$1"
    if [ -z "$check_name" ]; then
      echo "Usage: serversentry composite enable <check_name>"
      return 1
    fi

    local config_file="$COMPOSITE_CONFIG_DIR/${check_name}.conf"
    if [ -f "$config_file" ]; then
      # Enable the check by updating the config file
      sed -i.bak 's/enabled=false/enabled=true/' "$config_file"
      echo "✅ Enabled composite check: $check_name"
    else
      echo "❌ Composite check not found: $check_name"
      return 1
    fi
    ;;
  disable)
    local check_name="$1"
    if [ -z "$check_name" ]; then
      echo "Usage: serversentry composite disable <check_name>"
      return 1
    fi

    local config_file="$COMPOSITE_CONFIG_DIR/${check_name}.conf"
    if [ -f "$config_file" ]; then
      # Disable the check by updating the config file
      sed -i.bak 's/enabled=true/enabled=false/' "$config_file"
      echo "✅ Disabled composite check: $check_name"
    else
      echo "❌ Composite check not found: $check_name"
      return 1
    fi
    ;;
  create)
    local check_name="$1"
    local rule="$2"
    if [ -z "$check_name" ] || [ -z "$rule" ]; then
      echo "Usage: serversentry composite create <check_name> \"<rule>\""
      echo "Example: serversentry composite create my_check \"cpu.value > 80 AND memory.value > 85\""
      return 1
    fi

    local config_file="$COMPOSITE_CONFIG_DIR/${check_name}.conf"
    if [ -f "$config_file" ]; then
      echo "❌ Composite check already exists: $check_name"
      return 1
    fi

    # Create new composite check
    cat >"$config_file" <<EOF
# Custom Composite Check: $check_name
name="$check_name"
description="Custom composite check created via CLI"
enabled=true
severity=1
cooldown=300

# Rule: $rule
rule="$rule"

# Notification settings
notify_on_trigger=true
notify_on_recovery=false
notification_message="Composite check triggered: $check_name - {triggered_conditions}"
EOF

    echo "✅ Created composite check: $check_name"
    echo "Config file: $config_file"
    ;;
  *)
    echo "Usage: serversentry composite [list|test|enable|disable|create] ..."
    echo ""
    echo "Commands:"
    echo "  list                        List all composite checks"
    echo "  test [check_name]           Test composite checks (all or specific)"
    echo "  enable <check_name>         Enable a composite check"
    echo "  disable <check_name>        Disable a composite check"
    echo "  create <name> \"<rule>\"      Create a new composite check"
    echo ""
    echo "Rule Examples:"
    echo "  \"cpu.value > 80 AND memory.value > 85\""
    echo "  \"(cpu.value > 90 OR memory.value > 95) AND disk.value > 90\""
    echo "  \"cpu.value > 95 OR memory.value > 98 OR disk.value > 95\""
    return 1
    ;;
  esac
}

# Command: anomaly
cmd_anomaly() {
  local subcommand="$1"
  shift

  # Source the anomaly system
  if [ -f "$BASE_DIR/lib/core/anomaly.sh" ]; then
    source "$BASE_DIR/lib/core/anomaly.sh"
    init_anomaly_system
  else
    echo "❌ Anomaly detection system not available"
    return 1
  fi

  case "$subcommand" in
  list)
    echo "Anomaly Detection Configurations:"
    echo "================================"
    for config_file in "$ANOMALY_CONFIG_DIR"/*_anomaly.conf; do
      if [ -f "$config_file" ]; then
        local plugin_name
        plugin_name=$(basename "$config_file" | sed 's/_anomaly.conf//')
        echo "• $plugin_name ($(basename "$config_file"))"
      fi
    done
    ;;
  test)
    echo "Testing anomaly detection..."

    # Get current plugin results
    local plugin_results
    plugin_results=$(run_all_plugin_checks)

    if [ -n "$plugin_results" ]; then
      # Run anomaly detection
      echo "Running anomaly detection for all plugins..."
      run_anomaly_detection "$plugin_results"
    else
      echo "❌ No plugin results available for anomaly testing"
      return 1
    fi
    ;;
  summary)
    local days="${1:-7}"
    get_anomaly_summary "$days"
    ;;
  config)
    local plugin_name="$1"
    if [ -z "$plugin_name" ]; then
      echo "Usage: serversentry anomaly config <plugin_name>"
      echo "Example: serversentry anomaly config cpu"
      return 1
    fi

    local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"
    if [ -f "$config_file" ]; then
      echo "Editing anomaly configuration for $plugin_name..."
      ${EDITOR:-vi} "$config_file"
    else
      echo "❌ No anomaly configuration found for plugin: $plugin_name"
      echo "Available configurations:"
      for cfg in "$ANOMALY_CONFIG_DIR"/*_anomaly.conf; do
        if [ -f "$cfg" ]; then
          local name
          name=$(basename "$cfg" | sed 's/_anomaly.conf//')
          echo "  $name"
        fi
      done
      return 1
    fi
    ;;
  enable)
    local plugin_name="$1"
    if [ -z "$plugin_name" ]; then
      echo "Usage: serversentry anomaly enable <plugin_name>"
      return 1
    fi

    local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"
    if [ -f "$config_file" ]; then
      sed -i.bak 's/enabled=false/enabled=true/' "$config_file"
      echo "✅ Enabled anomaly detection for $plugin_name"
    else
      echo "❌ No anomaly configuration found for plugin: $plugin_name"
      return 1
    fi
    ;;
  disable)
    local plugin_name="$1"
    if [ -z "$plugin_name" ]; then
      echo "Usage: serversentry anomaly disable <plugin_name>"
      return 1
    fi

    local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"
    if [ -f "$config_file" ]; then
      sed -i.bak 's/enabled=true/enabled=false/' "$config_file"
      echo "✅ Disabled anomaly detection for $plugin_name"
    else
      echo "❌ No anomaly configuration found for plugin: $plugin_name"
      return 1
    fi
    ;;
  *)
    echo "Usage: serversentry anomaly [list|test|summary|config|enable|disable] ..."
    echo ""
    echo "Commands:"
    echo "  list                        List all anomaly detection configurations"
    echo "  test                        Test anomaly detection on current metrics"
    echo "  summary [days]              Get anomaly detection summary (default: 7 days)"
    echo "  config <plugin_name>        Edit anomaly configuration for a plugin"
    echo "  enable <plugin_name>        Enable anomaly detection for a plugin"
    echo "  disable <plugin_name>       Disable anomaly detection for a plugin"
    echo ""
    echo "Examples:"
    echo "  serversentry anomaly list"
    echo "  serversentry anomaly test"
    echo "  serversentry anomaly summary 14"
    echo "  serversentry anomaly config cpu"
    return 1
    ;;
  esac
}

# Command: reload
cmd_reload() {
  local subcommand="${1:-config}"
  shift

  # Source the reload system
  if [ -f "$BASE_DIR/lib/core/reload.sh" ]; then
    source "$BASE_DIR/lib/core/reload.sh"
  else
    echo "❌ Reload system not available"
    return 1
  fi

  case "$subcommand" in
  config)
    echo "Sending configuration reload signal..."
    send_reload_signal "config"
    ;;
  plugin | plugins)
    echo "Sending plugin reload signal..."
    send_reload_signal "plugin"
    ;;
  logs)
    echo "Sending log rotation signal..."
    send_reload_signal "logs"
    ;;
  status)
    show_reload_status
    ;;
  history)
    local lines="${1:-10}"
    get_reload_history "$lines"
    ;;
  *)
    echo "Usage: serversentry reload [config|plugin|logs|status|history] ..."
    echo ""
    echo "Commands:"
    echo "  config              Reload configuration without restart (SIGUSR1)"
    echo "  plugin              Reload plugins without restart (SIGUSR2)"
    echo "  logs                Rotate logs (SIGHUP)"
    echo "  status              Show current reload status"
    echo "  history [lines]     Show reload history (default: 10 lines)"
    echo ""
    echo "Note: ServerSentry must be running for reload commands to work"
    return 1
    ;;
  esac
}

# Command: diagnostics
cmd_diagnostics() {
  local subcommand="${1:-run}"
  shift

  # Source the diagnostics system
  if [ -f "$BASE_DIR/lib/core/diagnostics.sh" ]; then
    source "$BASE_DIR/lib/core/diagnostics.sh"
    init_diagnostics_system
  else
    echo "❌ Diagnostics system not available"
    return 1
  fi

  case "$subcommand" in
  run)
    echo "Running full system diagnostics..."
    echo "This may take a few moments..."
    echo ""

    if run_full_diagnostics; then
      echo ""
      echo "✅ Diagnostics completed successfully"
    else
      local exit_code=$?
      echo ""
      case $exit_code in
      1) echo "⚠️ Diagnostics completed with warnings" ;;
      2) echo "❌ Diagnostics completed with errors" ;;
      3) echo "🚨 Diagnostics found critical issues" ;;
      *) echo "❓ Diagnostics completed with unknown status" ;;
      esac
    fi
    ;;
  summary)
    local days="${1:-7}"
    get_diagnostic_summary "$days"
    ;;
  quick)
    echo "Running quick diagnostics..."

    # Source colors for better output
    if [ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]; then
      source "$BASE_DIR/lib/ui/cli/colors.sh"
    fi

    # Quick system checks
    echo ""
    print_header "Quick System Diagnostics" 40

    # Check disk space
    local disk_usage
    disk_usage=$(df "$BASE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -ge 90 ]; then
      print_status "error" "Disk usage: ${disk_usage}% (High)"
    elif [ "$disk_usage" -ge 75 ]; then
      print_status "warning" "Disk usage: ${disk_usage}% (Moderate)"
    else
      print_status "ok" "Disk usage: ${disk_usage}%"
    fi

    # Check memory
    local memory_usage
    # Use cross-platform method to get memory usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      local vm_stat_output
      vm_stat_output=$(vm_stat)
      local page_size
      page_size=$(pagesize)

      local pages_active pages_inactive pages_speculative pages_wired pages_free
      pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
      pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
      pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')
      pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')
      pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')

      local total_pages used_pages
      total_pages=$((pages_active + pages_inactive + pages_speculative + pages_wired + pages_free))
      used_pages=$((pages_active + pages_inactive + pages_wired))

      if [ "$total_pages" -gt 0 ]; then
        memory_usage=$(echo "scale=0; $used_pages * 100 / $total_pages" | bc 2>/dev/null || echo "0")
      else
        memory_usage=0
      fi
    elif command -v free >/dev/null 2>&1; then
      # Linux
      memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    else
      memory_usage=0
    fi

    if [ "$memory_usage" -ge 90 ]; then
      print_status "error" "Memory usage: ${memory_usage}% (High)"
    elif [ "$memory_usage" -ge 75 ]; then
      print_status "warning" "Memory usage: ${memory_usage}% (Moderate)"
    else
      print_status "ok" "Memory usage: ${memory_usage}%"
    fi

    # Check if monitoring is running
    if is_monitoring_running; then
      print_status "ok" "Monitoring service is running"
    else
      print_status "warning" "Monitoring service is stopped"
    fi

    # Check required commands
    local missing_cmds=()
    local required_commands=("ps" "grep" "awk" "sed" "jq")
    for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_cmds+=("$cmd")
      fi
    done

    if [ ${#missing_cmds[@]} -eq 0 ]; then
      print_status "ok" "All required commands available"
    else
      print_status "warning" "Missing commands: ${missing_cmds[*]}"
    fi

    # Check configuration file
    if [ -f "$MAIN_CONFIG" ]; then
      print_status "ok" "Configuration file exists"
    else
      print_status "error" "Configuration file missing"
    fi

    print_separator
    echo ""
    ;;
  config)
    echo "Editing diagnostics configuration..."
    if [ -f "$DIAGNOSTICS_CONFIG_FILE" ]; then
      ${EDITOR:-vi} "$DIAGNOSTICS_CONFIG_FILE"
    else
      echo "❌ Diagnostics configuration file not found: $DIAGNOSTICS_CONFIG_FILE"
      echo "Run 'serversentry diagnostics run' first to create default configuration."
      return 1
    fi
    ;;
  reports)
    echo "Available diagnostic reports:"
    echo "============================="

    if [ -d "$DIAGNOSTICS_REPORT_DIR" ]; then
      local report_count=0
      for report in "$DIAGNOSTICS_REPORT_DIR"/*.json; do
        if [ -f "$report" ]; then
          local filename
          filename=$(basename "$report")
          local file_date
          file_date=$(echo "$filename" | grep -o '[0-9]\{8\}_[0-9]\{6\}' | head -1)
          local formatted_date
          formatted_date=$(echo "$file_date" | sed 's/_/ /' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')

          echo "• $filename ($formatted_date)"
          report_count=$((report_count + 1))
        fi
      done

      if [ "$report_count" -eq 0 ]; then
        echo "No diagnostic reports found."
        echo "Run 'serversentry diagnostics run' to generate a report."
      else
        echo ""
        echo "Total reports: $report_count"
      fi
    else
      echo "Diagnostics report directory not found."
    fi
    ;;
  view)
    local report_file="$1"
    if [ -z "$report_file" ]; then
      # Show the most recent report
      if [ -d "$DIAGNOSTICS_REPORT_DIR" ]; then
        report_file=$(find "$DIAGNOSTICS_REPORT_DIR" -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
      fi
    else
      # If just a basename is provided, look in the report directory
      if [[ "$report_file" != */* ]]; then
        report_file="$DIAGNOSTICS_REPORT_DIR/$report_file"
      fi
    fi

    if [ -n "$report_file" ] && [ -f "$report_file" ]; then
      echo "Viewing diagnostic report: $(basename "$report_file")"
      echo "========================================"

      if command -v jq >/dev/null 2>&1; then
        # Pretty print with jq if available
        jq '.' "$report_file"
      else
        # Fallback to cat
        cat "$report_file"
      fi
    else
      echo "❌ Diagnostic report not found: $report_file"
      echo ""
      echo "Available reports:"
      "$0" diagnostics reports
      return 1
    fi
    ;;
  cleanup)
    local days="${1:-30}"
    echo "Cleaning up diagnostic reports older than $days days..."
    cleanup_diagnostic_reports "$days"
    echo "✅ Cleanup completed"
    ;;
  *)
    echo "Usage: serversentry diagnostics [run|summary|quick|config|reports|view|cleanup] ..."
    echo ""
    echo "Commands:"
    echo "  run                         Run full system diagnostics"
    echo "  quick                       Run quick diagnostic checks"
    echo "  summary [days]              Show diagnostic summary (default: 7 days)"
    echo "  config                      Edit diagnostics configuration"
    echo "  reports                     List available diagnostic reports"
    echo "  view [report_file]          View diagnostic report (latest if not specified)"
    echo "  cleanup [days]              Clean up old reports (default: 30 days)"
    echo ""
    echo "Examples:"
    echo "  serversentry diagnostics run"
    echo "  serversentry diagnostics quick"
    echo "  serversentry diagnostics summary 14"
    echo "  serversentry diagnostics view"
    echo "  serversentry diagnostics cleanup 60"
    return 1
    ;;
  esac
}

# Command: monitor
cmd_monitor() {
  log_info "Starting continuous monitoring..."

  # Source periodic monitoring system
  if [ -f "$BASE_DIR/lib/core/periodic.sh" ]; then
    source "$BASE_DIR/lib/core/periodic.sh"
  fi

  # Get monitoring interval from config (default 60 seconds)
  local interval="${MONITOR_INTERVAL:-60}"

  # Continuous monitoring loop
  while true; do
    log_debug "Running monitoring cycle..."

    # Run all plugin checks
    run_all_plugin_checks >/dev/null 2>&1

    # Run periodic tasks
    run_periodic_monitoring >/dev/null 2>&1

    # Sleep for the specified interval
    sleep "$interval"
  done
}
