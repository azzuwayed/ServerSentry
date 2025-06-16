#!/usr/bin/env bash
#
# ServerSentry v2 - CLI Commands (Modular)
#
# This module orchestrates all CLI commands through modular components

# Source modular command components
source "${BASE_DIR}/lib/core/utils.sh"
source "${BASE_DIR}/lib/ui/cli/commands/system.sh"
source "${BASE_DIR}/lib/ui/cli/commands/plugins.sh"
source "${BASE_DIR}/lib/ui/cli/commands/config.sh"
source "${BASE_DIR}/lib/ui/cli/commands/advanced.sh"
source "${BASE_DIR}/lib/ui/cli/commands/template.sh"
source "${BASE_DIR}/lib/ui/cli/commands/composite.sh"

# Source UI components
if [[ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]]; then
  source "$BASE_DIR/lib/ui/cli/colors.sh"
fi

# Help text
show_help() {
  # Check if we're in minimal mode
  if [[ "${SERVERSENTRY_MINIMAL_MODE:-}" == "true" ]]; then
    cat <<EOF
ServerSentry v2 - Server Monitoring Tool (Minimal Mode)

Usage: serversentry --minimal [options] [command]

Basic Commands:
  status              Show current system status
  help                Show this help message
  version             Show version information
  logs                View logs

Options:
  --minimal           Run in minimal mode (fewer features, more stable)
  -v, --verbose       Enable verbose output
  -q, --quiet         Suppress warning messages
  -d, --debug         Enable debug mode
  -h, --help          Show this help message

Minimal Mode Features:
  ✅ Basic system monitoring
  ✅ Essential logging
  ✅ Core status checks
  ❌ Plugins disabled
  ❌ Notifications disabled
  ❌ Advanced features disabled

To enable more features, run without --minimal flag.
EOF
  else
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
  logging             Manage logging system (status, health, rotate, config)
  clear-cache         Clear all plugin cache and temporary files

Options:
  --minimal           Run in minimal mode (fewer features, more stable)
  -v, --verbose       Enable verbose output
  -q, --quiet         Suppress warning messages (for automation)
  -c, --config FILE   Use alternative config file
  -d, --debug         Enable debug mode
  -h, --help          Show this help message
EOF
  fi
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
    -q | --quiet)
      CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
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
    status | start | stop | check | list | configure | logs | version | help | tui | webhook | template | update-threshold | list-thresholds | composite | anomaly | reload | diagnostics | monitor | logging | clear-cache)
      command="$1"
      shift
      break
      ;;
    # Unknown option/command
    *)
      if [[ "$1" == -* ]]; then
        log_error "Unknown option: $1" "cli"
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
  logging)
    cmd_logging "$@"
    ;;
  clear-cache)
    cmd_clear_cache "$@"
    ;;
  *)
    log_error "Unknown command: $command" "cli"
    show_help
    exit 1
    ;;
  esac
}

# === LEGACY COMMAND IMPLEMENTATIONS ===
# These commands are not yet modularized and remain in the main file

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
      compat_sed_inplace 's/enabled=false/enabled=true/' "$config_file"
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
      compat_sed_inplace 's/enabled=true/enabled=false/' "$config_file"
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
    anomaly_system_init
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
      anomaly_run_detection "$plugin_results"
    else
      echo "❌ No plugin results available for anomaly testing"
      return 1
    fi
    ;;
  summary)
    local days="${1:-7}"
    echo "Anomaly Detection Summary (Last $days days):"
    echo "==========================================="

    # Check if anomaly results directory exists
    if [ -d "$ANOMALY_RESULTS_DIR" ]; then
      local total_anomalies=0
      local plugins_with_anomalies=()

      # Count anomalies for each plugin
      for result_file in "$ANOMALY_RESULTS_DIR"/*.log; do
        if [ -f "$result_file" ]; then
          local plugin_name
          plugin_name=$(basename "$result_file" | sed 's/_[0-9]\{8\}\.log$//')
          local count
          count=$(wc -l <"$result_file" 2>/dev/null || echo "0")
          if [ "$count" -gt 0 ]; then
            echo "• $plugin_name: $count anomalies"
            total_anomalies=$((total_anomalies + count))
            plugins_with_anomalies+=("$plugin_name")
          fi
        fi
      done

      echo ""
      echo "Total anomalies detected: $total_anomalies"
      echo "Plugins with anomalies: ${#plugins_with_anomalies[@]}"
    else
      echo "No anomaly results directory found."
      echo "Run 'serversentry anomaly test' to generate anomaly data."
    fi
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
      compat_sed_inplace 's/enabled=false/enabled=true/' "$config_file"
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
      compat_sed_inplace 's/enabled=true/enabled=false/' "$config_file"
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

# Command: logging
cmd_logging() {
  local subcommand="${1:-status}"
  shift

  case "$subcommand" in
  status)
    echo "ServerSentry Logging System Status"
    echo "=================================="
    logging_get_status
    ;;
  health)
    echo "Checking logging system health..."
    if logging_check_health; then
      echo "✅ Logging system is healthy"
    else
      local exit_code=$?
      case $exit_code in
      1) echo "⚠️ Logging system has warnings" ;;
      2) echo "❌ Logging system has critical issues" ;;
      *) echo "❓ Unknown logging system status" ;;
      esac
    fi
    ;;
  rotate)
    echo "Rotating log files..."
    if logging_rotate; then
      echo "✅ Log rotation completed successfully"
    else
      echo "❌ Log rotation failed"
      return 1
    fi
    ;;
  cleanup)
    local days="${1:-30}"
    echo "Cleaning up log archives older than $days days..."
    logging_cleanup_archives "$days"
    echo "✅ Log cleanup completed"
    ;;
  level)
    local new_level="$1"
    if [[ -z "$new_level" ]]; then
      echo "Current log level: $(logging_get_level)"
    else
      if logging_set_level "$new_level"; then
        echo "✅ Log level set to: $new_level"
      else
        echo "❌ Invalid log level: $new_level"
        echo "Valid levels: debug, info, warning, error, critical"
        return 1
      fi
    fi
    ;;
  test)
    echo "Testing logging system..."
    echo ""

    # Test all log levels
    log_debug "This is a debug message" "test"
    log_info "This is an info message" "test"
    log_warning "This is a warning message" "test"
    log_error "This is an error message" "test"

    # Test specialized logging
    log_performance "Performance test message" "duration=0.5s memory=1MB"
    log_audit "test_action" "test_user" "Testing audit logging"
    log_security "test_event" "low" "Testing security logging"

    echo ""
    echo "✅ Logging test completed. Check log files for output."
    ;;
  config)
    echo "Logging Configuration:"
    echo "====================="
    echo "Global Settings:"
    echo "  Default Level: $(config_get_value 'logging.global.default_level' 'info')"
    echo "  Output Format: $(config_get_value 'logging.global.output_format' 'standard')"
    echo "  Include Caller: $(config_get_value 'logging.global.include_caller' 'false')"
    echo ""
    echo "File Settings:"
    echo "  Main Log: $(config_get_value 'logging.file.main_log' 'logs/serversentry.log')"
    echo "  Max Size: $(config_get_value 'logging.file.max_size' '10485760') bytes"
    echo "  Max Archives: $(config_get_value 'logging.file.max_archives' '10')"
    echo "  Compression: $(config_get_value 'logging.file.compression' 'true')"
    echo ""
    echo "Specialized Logs:"
    echo "  Performance: $(config_get_value 'logging.specialized.performance.enabled' 'true')"
    echo "  Error: $(config_get_value 'logging.specialized.error.enabled' 'true')"
    echo "  Audit: $(config_get_value 'logging.specialized.audit.enabled' 'true')"
    echo "  Security: $(config_get_value 'logging.specialized.security.enabled' 'true')"
    ;;
  tail)
    local log_type="${1:-main}"
    local lines="${2:-50}"

    case "$log_type" in
    main)
      echo "Showing last $lines lines of main log:"
      tail -n "$lines" "$LOG_FILE"
      ;;
    performance)
      echo "Showing last $lines lines of performance log:"
      tail -n "$lines" "$PERFORMANCE_LOG" 2>/dev/null || echo "Performance log not found"
      ;;
    error)
      echo "Showing last $lines lines of error log:"
      tail -n "$lines" "$ERROR_LOG" 2>/dev/null || echo "Error log not found"
      ;;
    audit)
      echo "Showing last $lines lines of audit log:"
      tail -n "$lines" "$AUDIT_LOG" 2>/dev/null || echo "Audit log not found"
      ;;
    security)
      echo "Showing last $lines lines of security log:"
      tail -n "$lines" "$SECURITY_LOG" 2>/dev/null || echo "Security log not found"
      ;;
    *)
      echo "Unknown log type: $log_type"
      echo "Available types: main, performance, error, audit, security"
      return 1
      ;;
    esac
    ;;
  follow)
    local log_type="${1:-main}"

    case "$log_type" in
    main)
      echo "Following main log (Press Ctrl+C to stop):"
      tail -f "$LOG_FILE"
      ;;
    performance)
      echo "Following performance log (Press Ctrl+C to stop):"
      tail -f "$PERFORMANCE_LOG" 2>/dev/null || echo "Performance log not found"
      ;;
    error)
      echo "Following error log (Press Ctrl+C to stop):"
      tail -f "$ERROR_LOG" 2>/dev/null || echo "Error log not found"
      ;;
    audit)
      echo "Following audit log (Press Ctrl+C to stop):"
      tail -f "$AUDIT_LOG" 2>/dev/null || echo "Audit log not found"
      ;;
    security)
      echo "Following security log (Press Ctrl+C to stop):"
      tail -f "$SECURITY_LOG" 2>/dev/null || echo "Security log not found"
      ;;
    *)
      echo "Unknown log type: $log_type"
      echo "Available types: main, performance, error, audit, security"
      return 1
      ;;
    esac
    ;;
  format)
    local new_format="$1"
    if [[ -z "$new_format" ]]; then
      echo "Current log format: $LOG_FORMAT"
      echo "Available formats: standard, json, structured"
    else
      case "$new_format" in
      standard | json | structured)
        LOG_FORMAT="$new_format"
        export LOG_FORMAT
        echo "✅ Log format set to: $new_format"
        ;;
      *)
        echo "❌ Invalid log format: $new_format"
        echo "Available formats: standard, json, structured"
        return 1
        ;;
      esac
    fi
    ;;
  *)
    echo "Usage: serversentry logging [subcommand] [options]"
    echo ""
    echo "Subcommands:"
    echo "  status              Show logging system status"
    echo "  health              Check logging system health"
    echo "  rotate              Rotate log files manually"
    echo "  cleanup [days]      Clean up old log archives (default: 30 days)"
    echo "  level [level]       Get/set log level (debug, info, warning, error, critical)"
    echo "  test                Test all logging functions"
    echo "  config              Show logging configuration"
    echo "  tail [type] [lines] View recent log entries (default: main, 50 lines)"
    echo "  follow [type]       Follow log file in real-time (default: main)"
    echo "  format [format]     Get/set log format (standard, json, structured)"
    echo ""
    echo "Log Types (for tail/follow):"
    echo "  main                Main application log"
    echo "  performance         Performance metrics log"
    echo "  error               Error and critical messages log"
    echo "  audit               Audit trail log"
    echo "  security            Security events log"
    echo ""
    echo "Examples:"
    echo "  serversentry logging status"
    echo "  serversentry logging health"
    echo "  serversentry logging level debug"
    echo "  serversentry logging tail error 100"
    echo "  serversentry logging follow performance"
    echo "  serversentry logging format json"
    return 1
    ;;
  esac
}

# === PLUGIN INTERFACE FUNCTIONS ===
# These functions provide a clean interface to the plugin system

# Function: run_all_plugin_checks
# Description: Run checks for all loaded plugins
# Returns:
#   JSON results via stdout
run_all_plugin_checks() {
  # Check if we're in minimal mode or if plugin system is not available
  if [[ "${SERVERSENTRY_MINIMAL_MODE:-}" == "true" ]]; then
    echo '{"status": "skipped", "reason": "minimal_mode", "plugins": []}'
    return 0
  fi

  # Check if plugin function is available
  if ! declare -f plugin_run_all_checks >/dev/null 2>&1; then
    echo '{"status": "unavailable", "reason": "plugin_system_not_loaded", "plugins": []}'
    return 0
  fi

  plugin_run_all_checks
}

# Function: is_plugin_registered
# Description: Check if a plugin is registered and loaded
# Parameters:
#   $1 - plugin name
# Returns:
#   0 - plugin is registered
#   1 - plugin is not registered
is_plugin_registered() {
  local plugin_name="$1"

  # In minimal mode, no plugins are registered
  if [[ "${SERVERSENTRY_MINIMAL_MODE:-}" == "true" ]]; then
    return 1
  fi

  # Check if plugin function is available
  if ! declare -f plugin_is_loaded >/dev/null 2>&1; then
    return 1
  fi

  plugin_is_loaded "$plugin_name"
}

# Function: list_plugins
# Description: List all loaded plugins with their information
# Returns:
#   Plugin list via stdout
list_plugins() {
  # In minimal mode, no plugins are loaded
  if [[ "${SERVERSENTRY_MINIMAL_MODE:-}" == "true" ]]; then
    echo "No plugins loaded (minimal mode)"
    return 0
  fi

  # Check if plugin function is available
  if ! declare -f plugin_list_loaded >/dev/null 2>&1; then
    echo "Plugin system not available"
    return 0
  fi

  plugin_list_loaded
}

# Function: run_plugin_check
# Description: Run a check for a specific plugin
# Parameters:
#   $1 - plugin name
# Returns:
#   JSON result via stdout
run_plugin_check() {
  local plugin_name="$1"

  # In minimal mode, no plugins are available
  if [[ "${SERVERSENTRY_MINIMAL_MODE:-}" == "true" ]]; then
    echo '{"status": "skipped", "reason": "minimal_mode", "plugin": "'"$plugin_name"'"}'
    return 0
  fi

  # Check if plugin function is available
  if ! declare -f plugin_run_check >/dev/null 2>&1; then
    echo '{"status": "unavailable", "reason": "plugin_system_not_loaded", "plugin": "'"$plugin_name"'"}'
    return 0
  fi

  plugin_run_check "$plugin_name"
}
