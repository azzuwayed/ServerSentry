#!/bin/bash
#
# ServerSentry v2 - Comprehensive Demo Script
#
# This script demonstrates the complete functionality of ServerSentry v2

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
  echo "• Comprehensive diagnostics"
  echo "• Composite logic checks"
  echo "• Multi-provider notifications"
  echo "• Template management"
  echo "• Plugin system"
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
  run_command "Overall system status" "'$SERVERSENTRY' status"

  print_step "4. Individual Plugin Checks"
  run_command "CPU monitoring check" "'$SERVERSENTRY' check cpu"
  run_command "Memory monitoring check" "'$SERVERSENTRY' check memory"
  run_command "Disk space monitoring check" "'$SERVERSENTRY' check disk"
  run_command "Process monitoring check" "'$SERVERSENTRY' check process"

  # Advanced features
  print_step "5. Anomaly Detection System"
  run_command "Test anomaly detection on current metrics" "'$SERVERSENTRY' anomaly test"
  run_command "Show anomaly summary (last 7 days)" "'$SERVERSENTRY' anomaly summary 7"

  print_step "6. Composite Logic Checks"
  run_command "Test composite checks" "'$SERVERSENTRY' composite test"

  print_step "7. System Diagnostics"
  run_command "Quick diagnostic health check" "'$SERVERSENTRY' diagnostics quick"
  echo -e "${YELLOW}Running full diagnostics (this may take a moment)...${NC}"
  run_command "Full system diagnostics" "'$SERVERSENTRY' diagnostics run"

  print_step "8. Notification System"
  run_command "Check notification status" "'$SERVERSENTRY' notifications status"

  print_step "9. Template Management"
  run_command "List available notification templates" "'$SERVERSENTRY' template list"

  print_step "10. Configuration Management"
  run_command "Show configuration status" "'$SERVERSENTRY' config status"

  print_step "11. Log Management"
  run_command "View recent logs" "'$SERVERSENTRY' logs view | tail -10"

  # Advanced configuration examples
  print_step "12. Advanced Configuration Examples"

  echo -e "${BLUE}Creating a custom composite check:${NC}"
  echo -e "${PURPLE}$ serversentry composite create demo_check \"cpu.value > 80 AND memory.value > 85\"${NC}"
  echo "(Demo command - would create composite check)"
  echo ""

  echo -e "${BLUE}Configuring anomaly detection:${NC}"
  echo -e "${PURPLE}$ serversentry anomaly config cpu${NC}"
  echo "(Would configure CPU anomaly detection)"
  echo ""

  # Monitoring demonstration
  print_step "13. Background Monitoring Demo"
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
  print_step "14. Performance Characteristics"
  echo -e "${GREEN}ServerSentry v2 Performance:${NC}"
  echo "• CPU Overhead: <2% during active monitoring"
  echo "• Memory Usage: 2-5MB for advanced features"
  echo "• Storage: ~10KB per plugin per month"
  echo "• Startup Time: <1 second"
  echo "• Plugin Execution: <500ms average"
  echo ""

  # Feature summary
  print_step "15. Complete Feature Summary"
  echo -e "${WHITE}ServerSentry v2 includes:${NC}"
  echo ""
  echo -e "${GREEN}Core Features:${NC}"
  echo "✅ 4 core plugins (CPU, Memory, Disk, Process)"
  echo "✅ 5 notification providers (Teams, Slack, Discord, Email, Webhook)"
  echo "✅ JSON API output for all commands"
  echo "✅ YAML configuration management"
  echo "✅ Comprehensive logging system"
  echo ""
  echo -e "${GREEN}Advanced Features:${NC}"
  echo "✅ Statistical anomaly detection (Z-score)"
  echo "✅ Composite checks with logical operators"
  echo "✅ Plugin health tracking and performance monitoring"
  echo "✅ Dynamic configuration reload"
  echo "✅ Comprehensive self-diagnostics"
  echo "✅ Template system for notifications"
  echo ""
  echo -e "${GREEN}Enterprise Features:${NC}"
  echo "✅ Cross-platform compatibility"
  echo "✅ Minimal dependencies (pure Bash)"
  echo "✅ Resource efficient operation"
  echo "✅ Secure file permissions"
  echo "✅ Automated log rotation"
  echo ""

  print_header "Demo Complete!"
  echo -e "${GREEN}Thank you for exploring ServerSentry v2!${NC}"
  echo ""
  echo -e "${WHITE}Next steps:${NC}"
  echo "1. Review the configuration in config/serversentry.yaml"
  echo "2. Customize plugin thresholds in config/plugins/"
  echo "3. Set up notification providers in config/notifications/"
  echo "4. Start monitoring with: $SERVERSENTRY start"
  echo ""
  echo -e "${CYAN}For more information, see the documentation in docs/README.md${NC}"
}

# Check if ServerSentry executable exists
if [ ! -f "$SERVERSENTRY" ]; then
  echo -e "${RED}Error: ServerSentry executable not found at $SERVERSENTRY${NC}"
  echo "Please ensure you're running this script from the ServerSentry root directory."
  exit 1
fi

# Run the demo
main "$@"
