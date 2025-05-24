#!/bin/bash
#
# ServerSentry v2 - Comprehensive Demo Script
#
# This script demonstrates the complete functionality of ServerSentry v2
# including advanced features from Phases 1-3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SERVERSENTRY="$SCRIPT_DIR/bin/serversentry"

# Demo functions
print_header() {
  echo ""
  echo -e "${CYAN}================================================================${NC}"
  echo -e "${WHITE}  $1${NC}"
  echo -e "${CYAN}================================================================${NC}"
  echo ""
}

print_step() {
  echo -e "${GREEN}➤${NC} ${YELLOW}$1${NC}"
  echo ""
}

run_command() {
  local description="$1"
  local command="$2"
  local show_output="${3:-true}"

  echo -e "${BLUE}$description:${NC}"
  echo -e "${PURPLE}$ $command${NC}"

  if [ "$show_output" = "true" ]; then
    eval "$command" || echo -e "${RED}Command failed (this may be expected)${NC}"
  else
    eval "$command" >/dev/null 2>&1 || echo -e "${RED}Command failed${NC}"
  fi
  echo ""
}

# Main demo function
main() {
  print_header "ServerSentry v2 - Enterprise Monitoring Demo"

  echo -e "${WHITE}Welcome to ServerSentry v2!${NC}"
  echo "This demo showcases the complete feature set including:"
  echo "• Statistical anomaly detection"
  echo "• Real-time TUI dashboard"
  echo "• Comprehensive diagnostics"
  echo "• Composite logic checks"
  echo "• Multi-provider notifications"
  echo "• Template management"
  echo ""
  read -p "Press Enter to continue..."

  # Setup
  print_step "1. Setting up ServerSentry v2"
  run_command "Making executable" "chmod +x '$SERVERSENTRY'"

  print_step "2. Version and System Information"
  run_command "Checking version" "'$SERVERSENTRY' version"
  run_command "System information" "uname -a"

  # Core functionality
  print_step "3. Core Monitoring Features"
  run_command "Listing available plugins" "'$SERVERSENTRY' list"
  run_command "Overall system status (with visual output)" "'$SERVERSENTRY' status"

  print_step "4. Individual Plugin Checks"
  run_command "CPU monitoring check" "'$SERVERSENTRY' check cpu"
  run_command "Memory monitoring check" "'$SERVERSENTRY' check memory"
  run_command "Disk space monitoring check" "'$SERVERSENTRY' check disk"
  run_command "Process monitoring check" "'$SERVERSENTRY' check process"

  # Advanced features
  print_step "5. Anomaly Detection System"
  run_command "List anomaly detection configurations" "'$SERVERSENTRY' anomaly list"
  run_command "Test anomaly detection on current metrics" "'$SERVERSENTRY' anomaly test"
  run_command "Show anomaly summary (last 7 days)" "'$SERVERSENTRY' anomaly summary 7"

  print_step "6. Composite Logic Checks"
  run_command "List composite check rules" "'$SERVERSENTRY' composite list"
  run_command "Test composite checks" "'$SERVERSENTRY' composite test"

  print_step "7. System Diagnostics"
  run_command "Quick diagnostic health check" "'$SERVERSENTRY' diagnostics quick"
  echo -e "${YELLOW}Running full diagnostics (this may take a moment)...${NC}"
  run_command "Full system diagnostics" "'$SERVERSENTRY' diagnostics run"
  run_command "List diagnostic reports" "'$SERVERSENTRY' diagnostics reports"

  print_step "8. Notification System"
  run_command "List webhook configurations" "'$SERVERSENTRY' webhook list"
  run_command "Check webhook status" "'$SERVERSENTRY' webhook status"

  print_step "9. Template Management"
  run_command "List available notification templates" "'$SERVERSENTRY' template list"
  run_command "Test template generation" "'$SERVERSENTRY' template test webhook test"

  print_step "10. Configuration Management"
  run_command "List current thresholds" "'$SERVERSENTRY' list-thresholds"
  run_command "Show reload status" "'$SERVERSENTRY' reload status"

  print_step "11. Log Management"
  run_command "View recent logs" "'$SERVERSENTRY' logs view | tail -10"

  # Interactive TUI Demo
  print_step "12. Interactive TUI Dashboard Demo"
  echo -e "${YELLOW}The TUI (Text User Interface) provides a real-time dashboard with:${NC}"
  echo "• Live system metrics with visual progress bars"
  echo "• 7 interactive screens (Dashboard, Plugins, Composite, Anomaly, Notifications, Logs, Config)"
  echo "• Auto-refresh every 2 seconds"
  echo "• Navigation: [1-7] screens, [r] refresh, [a] auto-refresh toggle, [q] quit"
  echo ""
  echo -e "${CYAN}Would you like to launch the interactive TUI? (Press Ctrl+C to exit TUI when ready)${NC}"
  read -p "Launch TUI? [y/N]: " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Launching TUI dashboard...${NC}"
    echo -e "${YELLOW}Use [1-7] to navigate screens, [q] to quit${NC}"
    sleep 2
    "$SERVERSENTRY" tui || echo -e "${RED}TUI demo completed${NC}"
  else
    echo -e "${YELLOW}Skipping TUI demo${NC}"
  fi

  # Advanced configuration examples
  print_step "13. Advanced Configuration Examples"

  echo -e "${BLUE}Creating a custom composite check:${NC}"
  echo -e "${PURPLE}$ serversentry composite create demo_check \"cpu.value > 80 AND memory.value > 85\"${NC}"
  "$SERVERSENTRY" composite create demo_check "cpu.value > 80 AND memory.value > 85" || echo "Composite check creation demo"
  echo ""

  echo -e "${BLUE}Configuring anomaly detection:${NC}"
  echo -e "${PURPLE}$ serversentry anomaly config cpu${NC}"
  echo "(Would open editor for CPU anomaly detection configuration)"
  echo ""

  # Monitoring demonstration
  print_step "14. Background Monitoring Demo"
  echo -e "${YELLOW}ServerSentry can run in the background for continuous monitoring.${NC}"
  echo ""
  echo -e "${BLUE}To start background monitoring:${NC}"
  echo -e "${PURPLE}$ serversentry start${NC}"
  echo ""
  echo -e "${BLUE}To stop background monitoring:${NC}"
  echo -e "${PURPLE}$ serversentry stop${NC}"
  echo ""
  echo -e "${BLUE}To check if monitoring is running:${NC}"
  echo -e "${PURPLE}$ serversentry status${NC}"
  echo ""

  # Performance metrics
  print_step "15. Performance Characteristics"
  echo -e "${GREEN}ServerSentry v2 Performance:${NC}"
  echo "• CPU Overhead: <2% during active monitoring"
  echo "• Memory Usage: 2-5MB for advanced features"
  echo "• Storage: ~10KB per plugin per month"
  echo "• Startup Time: <1 second"
  echo "• Plugin Execution: <500ms average"
  echo ""

  # Feature summary
  print_step "16. Complete Feature Summary"
  echo -e "${WHITE}ServerSentry v2 includes:${NC}"
  echo ""
  echo -e "${GREEN}Phase 1 - Foundation:${NC}"
  echo "✅ Generic webhook system"
  echo "✅ Notification templates with variables"
  echo "✅ Enhanced CLI with colors and formatting"
  echo "✅ Template management and validation"
  echo ""
  echo -e "${GREEN}Phase 2 - Advanced Features:${NC}"
  echo "✅ Composite checks with logical operators"
  echo "✅ Plugin health tracking and versioning"
  echo "✅ Dynamic configuration reload (no restart)"
  echo ""
  echo -e "${GREEN}Phase 3 - Intelligence Layer:${NC}"
  echo "✅ Statistical anomaly detection (Z-score)"
  echo "✅ Advanced TUI with real-time dashboard"
  echo "✅ Comprehensive self-diagnostics"
  echo ""
  echo -e "${GREEN}Core Features:${NC}"
  echo "✅ 4 core plugins (CPU, Memory, Disk, Process)"
  echo "✅ 5 notification providers (Teams, Slack, Discord, Email, Webhook)"
  echo "✅ JSON API output for all commands"
  echo "✅ Cross-platform compatibility (Linux, macOS)"
  echo "✅ Professional terminal interface"
  echo ""

  print_header "Demo Complete!"

  echo -e "${WHITE}Next Steps:${NC}"
  echo ""
  echo -e "${GREEN}1. Configuration:${NC}"
  echo "   • Edit config/serversentry.yaml for main settings"
  echo "   • Configure notification providers in config/notifications/"
  echo "   • Customize plugin thresholds in config/plugins/"
  echo ""
  echo -e "${GREEN}2. Production Usage:${NC}"
  echo "   • Start monitoring: $SERVERSENTRY start"
  echo "   • Launch TUI dashboard: $SERVERSENTRY tui"
  echo "   • Run diagnostics: $SERVERSENTRY diagnostics run"
  echo ""
  echo -e "${GREEN}3. Documentation:${NC}"
  echo "   • User Guide: docs/user/README.md"
  echo "   • Developer Guide: docs/developer/README.md"
  echo "   • API Reference: docs/api/README.md"
  echo ""
  echo -e "${GREEN}4. Advanced Features:${NC}"
  echo "   • Set up anomaly detection: $SERVERSENTRY anomaly config <plugin>"
  echo "   • Create composite checks: $SERVERSENTRY composite create <name> \"<rule>\""
  echo "   • Configure webhooks: $SERVERSENTRY webhook add <url>"
  echo ""
  echo -e "${CYAN}Thank you for trying ServerSentry v2!${NC}"
  echo -e "${WHITE}Enterprise-grade monitoring with statistical intelligence.${NC}"
  echo ""
}

# Run the demo
main "$@"
