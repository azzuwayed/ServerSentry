#!/usr/bin/env bash
#
# ServerSentry v2 - Comprehensive Demo Script
#
# This script demonstrates the complete functionality of ServerSentry v2

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal
  
  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi

    current_dir="$(dirname "$current_dir")"
  done
  
  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi
SERVERSENTRY="$SCRIPT_DIR/bin/serversentry"

# Initialize error handling system
if [[ -f "$SERVERSENTRY_ROOT/lib/core/error_handling.sh" ]]; then
  source "$SERVERSENTRY_ROOT/lib/core/error_handling.sh"
  if ! error_handling_init; then
    echo "Warning: Failed to initialize error handling system - continuing with basic error handling" >&2
  fi
fi

# Source standardized color functions
if [[ -f "$SCRIPT_DIR/lib/ui/cli/colors.sh" ]]; then
  source "$SCRIPT_DIR/lib/ui/cli/colors.sh"
else
  # Fallback definitions if colors.sh not available
fi

# Demo functions
demo_print_header() {
  echo ""
  print_header "$1" 64
  echo ""
}

demo_print_step() {
  echo ""
  print_status "info" "$1"
  echo ""
}

# Enhanced run_command function with error handling
run_command() {
  local description="$1"
  local command="$2"
  local show_output="${3:-true}"

  print_info "$description:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ $command${RESET}"
  else
    echo "$ $command"
  fi

  if [ "$show_output" = "true" ]; then
    # Use safe_execute if available, otherwise fallback to eval
    if declare -f safe_execute >/dev/null 2>&1; then
      safe_execute "$command" "Demo command failed: $description" || print_warning "Command failed (this may be expected)"
    else
      eval "$command" || print_warning "Command failed (this may be expected)"
    fi
  else
    if declare -f safe_execute >/dev/null 2>&1; then
      safe_execute "$command" "Demo command failed: $description" >/dev/null 2>&1 || print_warning "Command failed"
    else
      eval "$command" >/dev/null 2>&1 || print_warning "Command failed"
    fi
  fi
  echo ""
}

# Enhanced main function with error handling
main() {
  # Validate ServerSentry binary exists
  if [[ ! -f "$SERVERSENTRY" ]]; then
    if declare -f throw_error >/dev/null 2>&1; then
      throw_error 3 "ServerSentry binary not found at: $SERVERSENTRY" 3
    else
      print_error "ServerSentry binary not found at: $SERVERSENTRY"
      exit 3
    fi
  fi

  demo_print_header "ServerSentry v2 - Enterprise Monitoring Demo"

  print_success "Welcome to ServerSentry v2!"
  echo "This demo showcases the complete feature set including:"
  echo "• Statistical anomaly detection"
  echo "• Comprehensive diagnostics"
  echo "• Composite logic checks"
  echo "• Multi-provider notifications"
  echo "• Template management"
  echo "• Plugin system"
  echo ""
  read -r -p "Press Enter to continue..."

  # Setup
  demo_print_step "1. Setting up ServerSentry v2"
  run_command "Making executable" "chmod +x '$SERVERSENTRY'"

  demo_print_step "2. Version and System Information"
  run_command "Checking version" "'$SERVERSENTRY' version"
  run_command "System information" "uname -a"

  # Core functionality
  demo_print_step "3. Core Monitoring Features"
  run_command "Overall system status" "'$SERVERSENTRY' status"

  demo_print_step "4. Individual Plugin Checks"
  run_command "CPU monitoring check" "'$SERVERSENTRY' check cpu"
  run_command "Memory monitoring check" "'$SERVERSENTRY' check memory"
  run_command "Disk space monitoring check" "'$SERVERSENTRY' check disk"
  run_command "Process monitoring check" "'$SERVERSENTRY' check process"

  # Advanced features
  demo_print_step "5. Anomaly Detection System"
  run_command "Test anomaly detection on current metrics" "'$SERVERSENTRY' anomaly test"
  run_command "Show anomaly summary (last 7 days)" "'$SERVERSENTRY' anomaly summary 7"

  demo_print_step "6. Composite Logic Checks"
  run_command "Test composite checks" "'$SERVERSENTRY' composite test"

  demo_print_step "7. System Diagnostics"
  run_command "Quick diagnostic health check" "'$SERVERSENTRY' diagnostics quick"
  print_warning "Running full diagnostics (this may take a moment)..."
  run_command "Full system diagnostics" "'$SERVERSENTRY' diagnostics run"

  demo_print_step "8. Notification System"
  run_command "Check notification status" "'$SERVERSENTRY' notifications status"

  demo_print_step "9. Template Management"
  run_command "List available notification templates" "'$SERVERSENTRY' template list"

  demo_print_step "10. Configuration Management"
  run_command "Show configuration status" "'$SERVERSENTRY' config status"

  demo_print_step "11. Log Management"
  run_command "View recent logs" "'$SERVERSENTRY' logs view | tail -10"

  # Advanced configuration examples
  demo_print_step "12. Advanced Configuration Examples"

  print_info "Creating a custom composite check:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ serversentry composite create demo_check \"cpu.value > 80 AND memory.value > 85\"${RESET}"
  else
    echo "$ serversentry composite create demo_check \"cpu.value > 80 AND memory.value > 85\""
  fi
  echo "(Demo command - would create composite check)"
  echo ""

  print_info "Configuring anomaly detection:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ serversentry anomaly config cpu${RESET}"
  else
    echo "$ serversentry anomaly config cpu"
  fi
  echo "(Would configure CPU anomaly detection)"
  echo ""

  # Monitoring demonstration
  demo_print_step "13. Background Monitoring Demo"
  print_warning "ServerSentry can run in the background for continuous monitoring."
  echo ""
  print_info "To start background monitoring:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ serversentry start${RESET}"
  else
    echo "$ serversentry start"
  fi
  echo ""
  print_info "To stop background monitoring:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ serversentry stop${RESET}"
  else
    echo "$ serversentry stop"
  fi
  echo ""
  print_info "To check if monitoring is running:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$ serversentry status${RESET}"
  else
    echo "$ serversentry status"
  fi
  echo ""

  # Performance metrics
  demo_print_step "14. Performance Characteristics"
  print_success "ServerSentry v2 Performance:"
  echo "• CPU Overhead: <2% during active monitoring"
  echo "• Memory Usage: 2-5MB for advanced features"
  echo "• Storage: ~10KB per plugin per month"
  echo "• Startup Time: <1 second"
  echo "• Plugin Execution: <500ms average"
  echo ""

  # Feature summary
  demo_print_step "15. Complete Feature Summary"
  print_success "ServerSentry v2 includes:"
  echo ""
  print_status "ok" "Core Features:"
  echo "✅ 4 core plugins (CPU, Memory, Disk, Process)"
  echo "✅ 5 notification providers (Teams, Slack, Discord, Email, Webhook)"
  echo "✅ JSON API output for all commands"
  echo "✅ YAML configuration management"
  echo "✅ Comprehensive logging system"
  echo ""
  print_status "ok" "Advanced Features:"
  echo "✅ Statistical anomaly detection (Z-score)"
  echo "✅ Composite checks with logical operators"
  echo "✅ Plugin health tracking and performance monitoring"
  echo "✅ Dynamic configuration reload"
  echo "✅ Comprehensive self-diagnostics"
  echo "✅ Template system for notifications"
  echo ""
  print_status "ok" "Enterprise Features:"
  echo "✅ Cross-platform compatibility"
  echo "✅ Minimal dependencies (pure Bash)"
  echo "✅ Resource efficient operation"
  echo "✅ Secure file permissions"
  echo "✅ Automated log rotation"
  echo ""

  demo_print_header "Demo Complete!"
  print_success "Thank you for exploring ServerSentry v2!"
  echo ""
  print_info "Next steps:"
  echo "1. Review the configuration in config/serversentry.yaml"
  echo "2. Customize plugin thresholds in config/plugins/"
  echo "3. Set up notification providers in config/notifications/"
  echo "4. Start monitoring with: $SERVERSENTRY start"
  echo ""
  print_info "For more information, see the documentation in docs/README.md"
}

# Run the demo
main "$@"
