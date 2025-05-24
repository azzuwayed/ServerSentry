#!/bin/bash
#
# ServerSentry - Permission setter
# Sets appropriate execution permissions for all scripts

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source the install utilities
source "$PROJECT_ROOT/lib/install/utils.sh"

# Set executable permissions for all scripts
set_permissions() {
  print_header "Setting permissions"

  # Main script
  chmod +x "$PROJECT_ROOT/serversentry.sh"
  echo -e "  ${GREEN}✓${NC} serversentry.sh"

  # Set permissions for lib directory scripts
  if [ -d "$PROJECT_ROOT/lib" ]; then
    # Config module
    if [ -f "$PROJECT_ROOT/lib/config/config.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/config/config.sh"
      echo -e "  ${GREEN}✓${NC} lib/config/config.sh"
    fi

    # Monitor modules
    if [ -f "$PROJECT_ROOT/lib/monitor/monitor.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/monitor/monitor.sh"
      echo -e "  ${GREEN}✓${NC} lib/monitor/monitor.sh"
    fi

    if [ -f "$PROJECT_ROOT/lib/monitor/periodic.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/monitor/periodic.sh"
      echo -e "  ${GREEN}✓${NC} lib/monitor/periodic.sh"
    fi

    # Utils module
    if [ -f "$PROJECT_ROOT/lib/utils/utils.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/utils/utils.sh"
      echo -e "  ${GREEN}✓${NC} lib/utils/utils.sh"
    fi

    # Log module
    if [ -f "$PROJECT_ROOT/lib/log/logrotate.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/log/logrotate.sh"
      echo -e "  ${GREEN}✓${NC} lib/log/logrotate.sh"
    fi

    # Notify modules
    if [ -f "$PROJECT_ROOT/lib/notify/main.sh" ]; then
      chmod +x "$PROJECT_ROOT/lib/notify/main.sh"
      echo -e "  ${GREEN}✓${NC} lib/notify/main.sh"
    fi

    # CLI modules
    find "$PROJECT_ROOT/lib/cli" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    echo -e "  ${GREEN}✓${NC} lib/cli/* modules"

    # Install modules
    find "$PROJECT_ROOT/lib/install" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    echo -e "  ${GREEN}✓${NC} lib/install/* modules"
  fi

  echo -e "${GREEN}Done!${NC}"
}
