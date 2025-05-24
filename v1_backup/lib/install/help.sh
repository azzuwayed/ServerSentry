#!/bin/bash
#
# ServerSentry - Installation help functions
# Provides functions for displaying help and usage information

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source the install utilities
source "$PROJECT_ROOT/lib/install/utils.sh"

# Show help for the install script
show_help() {
  print_app_header

  echo "ServerSentry Installation and Management Tool"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  --help, -h            Show this help message"
  echo "  --check-deps          Check system dependencies"
  echo "  --set-perms           Set proper permissions on scripts"
  echo "  --create-config       Create configuration files"
  echo "  --reset-config        Reset all configuration files"
  echo "  --manage-crons        Manage cron jobs"
  echo "  --usage               Show a quick guide to using ServerSentry"
  echo "  --install             Install ServerSentry (full installation)"
  echo ""
  echo "Without arguments, the script will run in interactive mode."
  echo ""
  echo "Examples:"
  echo "  $0                   # Run in interactive mode"
  echo "  $0 --check-deps      # Only check dependencies"
  echo "  $0 --install         # Perform a full installation"
  echo ""
}

# Show usage information
show_usage() {
  clear
  print_app_header

  echo -e "${CYAN}┌───────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│             ServerSentry Usage Guide                  │${NC}"
  echo -e "${CYAN}└───────────────────────────────────────────────────────┘${NC}"

  echo -e "\n${BLUE}🔍 BASIC COMMANDS${NC}\n"
  echo -e "  ${GREEN}serversentry --help${NC}"
  echo -e "    ↳ Display comprehensive help information\n"

  echo -e "  ${GREEN}serversentry --check${NC}"
  echo -e "    ↳ Run a one-time system check and display results\n"

  echo -e "  ${GREEN}serversentry --monitor${NC}"
  echo -e "    ↳ Start continuous monitoring in foreground mode\n"

  echo -e "  ${GREEN}serversentry --status${NC}"
  echo -e "    ↳ Show current system status and metrics\n"

  echo -e "\n${BLUE}🔔 NOTIFICATION MANAGEMENT${NC}\n"
  echo -e "  ${GREEN}serversentry --test-webhook${NC}"
  echo -e "    ↳ Test notifications to all configured webhooks\n"

  echo -e "  ${GREEN}serversentry --add-webhook URL${NC}"
  echo -e "    ↳ Add a new webhook notification endpoint\n"

  echo -e "  ${GREEN}serversentry --remove-webhook N${NC}"
  echo -e "    ↳ Remove webhook number N from configuration\n"

  echo -e "\n${BLUE}⚙️ CONFIGURATION${NC}\n"
  echo -e "  ${GREEN}serversentry --update NAME=VALUE${NC}"
  echo -e "    ↳ Update configuration threshold (e.g., cpu_threshold=90)\n"

  echo -e "  ${GREEN}serversentry --list${NC}"
  echo -e "    ↳ List all configured thresholds and webhooks\n"

  echo -e "\n${YELLOW}TIP:${NC} Create an alias for easier access:"
  echo -e "  ${GREEN}alias serversentry=\"$PROJECT_ROOT/serversentry.sh\"${NC}"

  echo -e "\n${BLUE}📖 DOCUMENTATION${NC}"
  echo -e "  For Microsoft Teams integration, see:"
  echo -e "  ${GREEN}cat $PROJECT_ROOT/TEAMS_SETUP.md${NC}\n"

  read -p "Press Enter to continue..." dummy
}
