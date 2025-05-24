#!/bin/bash
#
# ServerSentry - Installation utilities
# Provides common utilities for the installation process

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print a horizontal line
print_line() {
  echo "-----------------------------------------------------------"
}

# Print a section header
print_header() {
  local title="$1"
  echo ""
  echo -e "${CYAN}${title}${NC}"
  print_line
}

# Print the main application header
print_app_header() {
  echo -e "${GREEN}ServerSentry - System Monitoring & Alert Tool${NC}"
  echo -e "${CYAN}=====================================================${NC}"
  echo ""
}

# Check if we're running as root and prompt user to confirm if not
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Not running as root. Some operations may fail.${NC}"
    echo "It's recommended to run this script with sudo."
    echo ""
    read -p "Continue anyway? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo "Operation aborted."
      exit 1
    fi
  fi
}

# Get the current version from serversentry.sh
get_version() {
  if [ -f "$PROJECT_ROOT/serversentry.sh" ]; then
    grep -m 1 "Version:" "$PROJECT_ROOT/serversentry.sh" | awk '{print $3}'
  else
    echo "Unknown"
  fi
}

# Check if this is an update or a new installation
check_update_status() {
  if [ -f "$PROJECT_ROOT/serversentry.sh" ] && [ -f "$PROJECT_ROOT/config/thresholds.conf" ]; then
    current_version=$(get_version)
    echo -e "${YELLOW}Existing ServerSentry installation detected (Version: $current_version)${NC}"
    echo "This script will help manage your installation."
    echo ""
    echo "true" # Return true for update status
  else
    echo "false" # Return false for update status
  fi
}
