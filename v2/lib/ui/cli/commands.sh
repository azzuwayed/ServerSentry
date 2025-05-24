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
  webhook             Manage webhooks (add, remove, list, test)
  update-threshold    Update a threshold value (e.g., cpu_threshold=85)
  list-thresholds     List all thresholds and configuration

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
    status | start | stop | check | list | configure | logs | version | help | tui | webhook | update-threshold | list-thresholds)
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
  update-threshold)
    cmd_update_threshold "$@"
    ;;
  list-thresholds)
    cmd_list_thresholds "$@"
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
  log_info "Checking system status..."

  # Run all plugin checks
  log_debug "Running all plugin checks"
  local results
  results=$(run_all_plugin_checks)

  # Display results
  echo "=== ServerSentry Status ==="
  echo "$results" | jq -r '.status_message'
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
    # Add webhook to config (YAML or .conf as appropriate)
    # For now, append to config/notifications/teams.conf as example
    echo "$url" >>"$BASE_DIR/config/notifications/teams.conf"
    echo "Webhook added: $url"
    ;;
  remove)
    local index="$1"
    if [ -z "$index" ]; then
      echo "Usage: serversentry webhook remove <INDEX>"
      return 1
    fi
    # Remove webhook by index (from teams.conf as example)
    sed -i.bak "${index}d" "$BASE_DIR/config/notifications/teams.conf"
    echo "Webhook #$index removed."
    ;;
  list)
    echo "Configured webhooks:"
    nl -w2 -s'. ' "$BASE_DIR/config/notifications/teams.conf"
    ;;
  test)
    echo "Testing all configured webhooks..."
    # For each webhook, send a test notification (Teams as example)
    while IFS= read -r webhook; do
      if [ -n "$webhook" ]; then
        echo "Testing webhook: $webhook"
        # Call teams_provider_send or similar (stub)
        # teams_provider_send 0 "Test notification from ServerSentry" "test" "{\"test\":true}" "$webhook"
        echo "(Stub) Sent test notification to $webhook"
      fi
    done <"$BASE_DIR/config/notifications/teams.conf"
    ;;
  *)
    echo "Usage: serversentry webhook [add|remove|list|test] ..."
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
