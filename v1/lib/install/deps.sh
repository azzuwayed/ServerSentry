#!/bin/bash
#
# ServerSentry - Dependency checker
# Checks for required and recommended system commands

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source the install utilities
source "$PROJECT_ROOT/lib/install/utils.sh"

# Check if a command exists and output formatted status
check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $1"
    return 0
  else
    echo -e "  ${RED}✗${NC} $1 ${YELLOW}($2)${NC}"
    return 1
  fi
}

# Check for required and recommended commands
check_dependencies() {
  print_header "Checking for required commands"
  MISSING_COMMANDS=0

  check_command "bash" "required" || ((MISSING_COMMANDS++))
  check_command "curl" "required for webhooks" || ((MISSING_COMMANDS++))
  check_command "grep" "required" || ((MISSING_COMMANDS++))
  check_command "awk" "required" || ((MISSING_COMMANDS++))
  check_command "sed" "required" || ((MISSING_COMMANDS++))
  check_command "bc" "recommended for calculations" || ((MISSING_COMMANDS++))
  check_command "jq" "recommended for webhook formatting" || ((MISSING_COMMANDS++))
  check_command "crontab" "recommended for scheduling" || ((MISSING_COMMANDS++))

  if [ $MISSING_COMMANDS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Some recommended commands are missing.${NC}"
    echo "You can install them on:"
    echo -e "  ${BLUE}Debian/Ubuntu${NC}: sudo apt-get install curl jq bc"
    echo -e "  ${BLUE}CentOS/RHEL${NC}: sudo yum install curl jq bc"
    echo -e "  ${BLUE}macOS${NC}: brew install jq curl bc"
    echo ""
    read -p "Continue anyway? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo "Operation aborted."
      exit 1
    fi
  fi

  return $MISSING_COMMANDS
}
