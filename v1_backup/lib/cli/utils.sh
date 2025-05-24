#!/bin/bash
#
# ServerSentry - CLI utilities
# Common utilities for CLI commands

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the paths module
source "$SCRIPT_DIR/../utils/paths.sh"

# Get standardized paths using path utilities
PROJECT_ROOT="$(get_project_root)"
LOG_FILE="$(get_file_path "log")"
CONFIG_DIR="$(get_dir_path "config")"
THRESHOLDS_FILE="$(get_file_path "thresholds")"
WEBHOOKS_FILE="$(get_file_path "webhooks")"

# Define color codes for terminal output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
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

# Function to display help message
show_help() {
  local script_name="$(basename "$0")"

  echo -e "${GREEN}ServerSentry - System Monitoring & Alert Tool${NC}"
  echo -e "${CYAN}=====================================================${NC}"
  echo ""
  echo -e "Usage: $script_name [OPTION]..."
  echo ""

  echo -e "${BLUE}Basic Options:${NC}"
  echo -e "  ${GREEN}-h, --help${NC}             📚 Show this help message"
  echo -e "  ${GREEN}-i, --interactive${NC}      🖥️  Launch interactive menu system"
  echo -e "  ${GREEN}-c, --check${NC}            🧪 Perform a one-time system check"
  echo -e "  ${GREEN}-m, --monitor${NC}          👁️  Start monitoring (foreground process)"
  echo -e "  ${GREEN}-s, --status${NC}           ℹ️  Show current status and configuration"
  echo -e "  ${GREEN}-l, --list${NC}             📋 List all thresholds and webhooks"

  echo -e ""
  echo -e "${BLUE}Webhook Management:${NC}"
  echo -e "  ${GREEN}-t, --test-webhook${NC}     🧪 Test webhook notifications"
  echo -e "  ${GREEN}-a, --add-webhook URL${NC}  ➕ Add a new webhook endpoint"
  echo -e "  ${GREEN}-r, --remove-webhook N${NC} ➖ Remove webhook number N"

  echo -e ""
  echo -e "${BLUE}Configuration:${NC}"
  echo -e "  ${GREEN}-u, --update N=VALUE${NC}   ⚙️  Update threshold (e.g., cpu_threshold=85)"

  echo -e ""
  echo -e "${BLUE}Periodic Reports:${NC}"
  echo -e "  ${GREEN}--periodic run${NC}         🏃 Run a periodic check now"
  echo -e "  ${GREEN}--periodic status${NC}      ℹ️  Show periodic checks status"
  echo -e "  ${GREEN}--periodic config${NC}      ⚙️  Configure periodic checks"
  echo -e "                         e.g., --periodic config report_interval 3600"

  echo -e ""
  echo -e "${BLUE}Log Management:${NC}"
  echo -e "  ${GREEN}--logs status${NC}          ℹ️  Show log rotation status"
  echo -e "  ${GREEN}--logs rotate${NC}          🔄 Rotate logs now"
  echo -e "  ${GREEN}--logs clean${NC}           🧹 Clean up old log files"
  echo -e "  ${GREEN}--logs config${NC}          ⚙️  Configure log rotation"
  echo -e "                         e.g., --logs config max_age_days 14"
}

# Function to create a visual progress bar
create_visual_bar() {
  local usage=$1
  local threshold=$2
  local width=20
  local filled=$((usage * width / 100))
  local bar="["

  for ((i = 0; i < width; i++)); do
    if [ $i -lt $filled ]; then
      bar+="#"
    else
      bar+="-"
    fi
  done

  bar+="] $usage%"
  echo "$bar"
}

# Function to add color based on threshold
colorize_metric() {
  local value=$1
  local threshold=$2
  local warn_threshold=$((threshold - 20))
  local text=$3
  local bar=$(create_visual_bar "$value" "$threshold")

  if [ "$value" -ge "$threshold" ]; then
    echo -e "${RED}$text ${bar} ${RED}⚠️  ALERT: Above threshold ($threshold%)${NC}"
  elif [ "$value" -ge "$warn_threshold" ]; then
    echo -e "${YELLOW}$text ${bar} ${YELLOW}⚡ WARNING: Approaching threshold${NC}"
  else
    echo -e "${GREEN}$text ${bar} ${GREEN}✅ NORMAL${NC}"
  fi
}

# Function to launch the interactive menu
cli_interactive() {
  # Check if running in an interactive terminal
  if [ -t 0 ]; then
    # Source install utilities and menu if not already loaded
    if ! type check_update_status >/dev/null 2>&1; then
      source "$(get_dir_path "lib")/install/utils.sh"
    fi

    if ! type update_menu >/dev/null 2>&1; then
      source "$(get_dir_path "lib")/install/menu.sh"
    fi

    # Determine if this is an update or new installation
    local update_check=$(check_update_status | tail -n 1)

    if [ "$update_check" = "true" ]; then
      # Show the management menu for existing installation
      update_menu
    else
      # Show the installation menu for new installation
      install_menu
    fi
  else
    echo "Error: Interactive mode requires a terminal."
    return 1
  fi
}
