#!/bin/bash
#
# ServerSentry - Menu system
# Handles interactive menus for installation and management

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/install/utils.sh"
source "$PROJECT_ROOT/lib/install/deps.sh"
source "$PROJECT_ROOT/lib/install/permissions.sh"
source "$PROJECT_ROOT/lib/install/config.sh"
source "$PROJECT_ROOT/lib/install/cron.sh"
source "$PROJECT_ROOT/lib/install/help.sh"

# Show and handle the installation menu (new installation)
install_menu() {
  while true; do
    clear

    print_app_header
    echo -e "${CYAN}ServerSentry Installation${NC}"
    echo "======================="

    # Menu options with icons and better formatting
    echo -e "${BLUE}Select an option:${NC}"
    echo -e "  ${GREEN}1)${NC} 🔄 ${CYAN}Complete Installation${NC}"
    echo -e "     ↳ Install all components and set up basic configuration"

    echo -e "  ${GREEN}2)${NC} 🔍 ${CYAN}Check Dependencies${NC}"
    echo -e "     ↳ Verify all required system dependencies"

    echo -e "  ${GREEN}3)${NC} 🔒 ${CYAN}Set Permissions${NC}"
    echo -e "     ↳ Set proper file and directory permissions"

    echo -e "  ${GREEN}4)${NC} ⚙️  ${CYAN}Configure Thresholds${NC}"
    echo -e "     ↳ Set monitoring thresholds for alerts"

    echo -e "  ${GREEN}5)${NC} 🔔 ${CYAN}Configure Webhooks${NC}"
    echo -e "     ↳ Set up notification webhooks"

    echo -e "  ${GREEN}6)${NC} ⏱️  ${CYAN}Configure Scheduled Tasks${NC}"
    echo -e "     ↳ Set up automated monitoring checks"

    echo -e "  ${GREEN}7)${NC} 📋 ${CYAN}Configure Log Rotation${NC}"
    echo -e "     ↳ Set up log rotation parameters"

    echo -e "  ${GREEN}8)${NC} 📨 ${CYAN}Configure Periodic Reports${NC}"
    echo -e "     ↳ Set up scheduled system reports"

    echo -e "  ${GREEN}9)${NC} 📚 ${CYAN}View Usage Guide${NC}"
    echo -e "     ↳ Display available commands and usage examples"

    echo -e "  ${GREEN}10)${NC} 🚪 ${CYAN}Exit${NC}"
    echo -e "     ↳ Exit the installation"

    echo ""
    read -p "Select option (1-10): " option

    case "$option" in
    1)
      install_serversentry
      show_usage
      exit 0
      ;;
    2)
      check_dependencies
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    3)
      set_permissions
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    4)
      configure_thresholds
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    5)
      configure_webhooks
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    6)
      manage_crons
      ;;
    7)
      configure_log_rotation
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    8)
      configure_periodic_reports
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    9)
      show_usage
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    10) exit 0 ;;
    *)
      echo -e "${RED}Invalid option. Please select 1-10.${NC}"
      sleep 2
      ;;
    esac
  done
}

# Main installation function that performs a complete install
install_serversentry() {
  check_dependencies
  set_permissions
  create_config_files

  echo ""
  echo -e "${GREEN}ServerSentry installation complete!${NC}"

  echo ""
  read -p "Would you like to set up a cron job for automatic monitoring? (y/n): " setup_cron
  if [[ "$setup_cron" =~ ^[Yy]$ ]]; then
    setup_cron_job
  else
    echo "Skipping cron job setup."
  fi
}

# Configure threshold values
configure_thresholds() {
  print_header "Configure Monitoring Thresholds"

  # Create config file if it doesn't exist
  if [ ! -f "$PROJECT_ROOT/config/thresholds.conf" ]; then
    create_config_files
  fi

  echo "Current threshold values:"
  if [ -f "$PROJECT_ROOT/config/thresholds.conf" ]; then
    grep -v "^#" "$PROJECT_ROOT/config/thresholds.conf" | grep -v "^$" | sed 's/^/  /'
  fi

  echo ""
  read -p "CPU threshold (%) [80]: " cpu_threshold
  read -p "Memory threshold (%) [80]: " memory_threshold
  read -p "Disk threshold (%) [85]: " disk_threshold
  read -p "Load threshold [2.0]: " load_threshold
  read -p "Check interval (seconds) [60]: " check_interval
  read -p "Process checks (comma separated, no spaces): " process_checks

  # Update threshold values if provided
  [ -n "$cpu_threshold" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "cpu_threshold" "$cpu_threshold"
  [ -n "$memory_threshold" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "memory_threshold" "$memory_threshold"
  [ -n "$disk_threshold" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "disk_threshold" "$disk_threshold"
  [ -n "$load_threshold" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "load_threshold" "$load_threshold"
  [ -n "$check_interval" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "check_interval" "$check_interval"
  [ -n "$process_checks" ] && update_config_value "$PROJECT_ROOT/config/thresholds.conf" "process_checks" "$process_checks"

  echo -e "\n${GREEN}Threshold values updated successfully!${NC}"
}

# Configure webhooks
configure_webhooks() {
  print_header "Configure Notification Webhooks"

  # Create config directory and file if they don't exist
  if [ ! -d "$PROJECT_ROOT/config" ]; then
    mkdir -p "$PROJECT_ROOT/config"
  fi

  if [ ! -f "$PROJECT_ROOT/config/webhooks.conf" ]; then
    touch "$PROJECT_ROOT/config/webhooks.conf"
  fi

  while true; do
    echo -e "\n${BLUE}Current webhooks:${NC}"
    if [ -s "$PROJECT_ROOT/config/webhooks.conf" ]; then
      grep -v "^#" "$PROJECT_ROOT/config/webhooks.conf" | grep -v "^$" | nl | sed 's/^/  /'
    else
      echo "  No webhooks configured."
    fi

    echo -e "\n${BLUE}Options:${NC}"
    echo "1) Add webhook"
    echo "2) Remove webhook"
    echo "3) Back to main menu"

    read -p "Select option (1-3): " webhook_option

    case "$webhook_option" in
    1)
      read -p "Enter webhook URL: " webhook_url
      if [ -n "$webhook_url" ]; then
        echo "$webhook_url" >>"$PROJECT_ROOT/config/webhooks.conf"
        echo -e "${GREEN}Webhook added successfully!${NC}"
      else
        echo -e "${RED}No URL provided.${NC}"
      fi
      ;;
    2)
      if [ ! -s "$PROJECT_ROOT/config/webhooks.conf" ]; then
        echo "No webhooks to remove."
        continue
      fi
      read -p "Enter webhook number to remove: " webhook_num
      if [[ "$webhook_num" =~ ^[0-9]+$ ]]; then
        webhook_count=$(wc -l <"$PROJECT_ROOT/config/webhooks.conf")
        if [ "$webhook_num" -ge 1 ] && [ "$webhook_num" -le "$webhook_count" ]; then
          sed -i.bak "${webhook_num}d" "$PROJECT_ROOT/config/webhooks.conf"
          rm -f "$PROJECT_ROOT/config/webhooks.conf.bak" 2>/dev/null
          echo -e "${GREEN}Webhook removed successfully!${NC}"
        else
          echo -e "${RED}Invalid webhook number.${NC}"
        fi
      else
        echo -e "${RED}Please enter a valid number.${NC}"
      fi
      ;;
    3)
      return
      ;;
    *)
      echo -e "${RED}Invalid option. Please select 1-3.${NC}"
      ;;
    esac
  done
}

# Configure log rotation
configure_log_rotation() {
  print_header "Configure Log Rotation"

  # Create config file if it doesn't exist
  if [ ! -f "$PROJECT_ROOT/config/logrotate.conf" ]; then
    create_config_files
  fi

  echo "Current log rotation settings:"
  if [ -f "$PROJECT_ROOT/config/logrotate.conf" ]; then
    grep -v "^#" "$PROJECT_ROOT/config/logrotate.conf" | grep -v "^$" | sed 's/^/  /'
  fi

  echo ""
  read -p "Maximum log size in MB [10]: " max_size
  read -p "Maximum age in days [30]: " max_age
  read -p "Maximum number of files [10]: " max_files
  read -p "Compress logs (true/false) [true]: " compress
  read -p "Rotate logs on start (true/false) [false]: " rotate_on_start

  # Update log rotation values if provided
  [ -n "$max_size" ] && update_config_value "$PROJECT_ROOT/config/logrotate.conf" "max_size_mb" "$max_size"
  [ -n "$max_age" ] && update_config_value "$PROJECT_ROOT/config/logrotate.conf" "max_age_days" "$max_age"
  [ -n "$max_files" ] && update_config_value "$PROJECT_ROOT/config/logrotate.conf" "max_files" "$max_files"
  [ -n "$compress" ] && update_config_value "$PROJECT_ROOT/config/logrotate.conf" "compress" "$compress"
  [ -n "$rotate_on_start" ] && update_config_value "$PROJECT_ROOT/config/logrotate.conf" "rotate_on_start" "$rotate_on_start"

  echo -e "\n${GREEN}Log rotation settings updated successfully!${NC}"
}

# Configure periodic reports
configure_periodic_reports() {
  print_header "Configure Periodic Reports"

  # Create config file if it doesn't exist
  if [ ! -f "$PROJECT_ROOT/config/periodic.conf" ]; then
    create_config_files
  fi

  echo "Current periodic reports settings:"
  if [ -f "$PROJECT_ROOT/config/periodic.conf" ]; then
    grep -v "^#" "$PROJECT_ROOT/config/periodic.conf" | grep -v "^$" | sed 's/^/  /'
  fi

  echo ""
  read -p "Report interval in seconds [86400]: " interval
  read -p "Report level (summary, detailed, minimal) [detailed]: " level
  read -p "Report checks (comma separated, e.g., cpu,memory,disk) [cpu,memory,disk,processes]: " checks
  read -p "Force report even without issues (true/false) [false]: " force
  read -p "Specific time for reports (HH:MM, leave empty for none): " time
  read -p "Days for reports (1-7 for Mon-Sun, comma separated, leave empty for all): " days

  # Update periodic reports values if provided
  [ -n "$interval" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "report_interval" "$interval"
  [ -n "$level" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "report_level" "$level"
  [ -n "$checks" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "report_checks" "$checks"
  [ -n "$force" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "force_report" "$force"
  [ -n "$time" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "report_time" "$time"
  [ -n "$days" ] && update_config_value "$PROJECT_ROOT/config/periodic.conf" "report_days" "$days"

  echo -e "\n${GREEN}Periodic reports settings updated successfully!${NC}"
}

# Update existing ServerSentry installation
update_serversentry() {
  print_header "Updating ServerSentry"

  check_dependencies
  set_permissions

  echo ""
  echo -e "${GREEN}ServerSentry updated successfully!${NC}"

  sleep 2
}

# Show current configuration
show_config() {
  print_header "Current ServerSentry Configuration"

  if [ -f "$PROJECT_ROOT/config/thresholds.conf" ]; then
    echo -e "${BLUE}Thresholds:${NC}"
    grep -v "^#" "$PROJECT_ROOT/config/thresholds.conf" | grep -v "^$" | sed 's/^/  /'
  else
    echo -e "${RED}No thresholds configuration found.${NC}"
  fi

  echo ""
  echo -e "${BLUE}Webhooks:${NC}"
  if [ -f "$PROJECT_ROOT/config/webhooks.conf" ]; then
    webhook_count=$(grep -v "^#" "$PROJECT_ROOT/config/webhooks.conf" | grep -v "^$" | wc -l)
    if [ "$webhook_count" -gt 0 ]; then
      grep -v "^#" "$PROJECT_ROOT/config/webhooks.conf" | grep -v "^$" | nl | sed 's/^/  /'
    else
      echo -e "  ${YELLOW}No webhooks configured${NC}"
    fi
  else
    echo -e "  ${RED}No webhooks configuration found.${NC}"
  fi

  echo ""
  echo -e "${BLUE}Cron Jobs:${NC}"
  existing_crons=$(crontab -l 2>/dev/null | grep "$PROJECT_ROOT/serversentry.sh")
  if [ -z "$existing_crons" ]; then
    echo -e "  ${YELLOW}No scheduled tasks configured${NC}"
  else
    echo "$existing_crons" | sed 's/^/  /'
  fi

  echo ""
  read -p "Press Enter to continue..." dummy
}

# Show and handle the management menu (existing installation)
update_menu() {
  while true; do
    clear

    # Header
    print_app_header

    # Version info
    current_version=$(get_version)
    echo -e "ServerSentry Version: ${GREEN}$current_version${NC}\n"

    # Menu options with icons and better formatting
    echo -e "${BLUE}Select an option:${NC}"
    echo -e "  ${GREEN}1)${NC} 🔄 ${CYAN}Update ServerSentry${NC}"
    echo -e "     ↳ Update and maintain core monitoring components"

    echo -e "  ${GREEN}2)${NC} ⏱️  ${CYAN}Manage Scheduled Tasks${NC}"
    echo -e "     ↳ Configure automated monitoring checks and alerts"

    echo -e "  ${GREEN}3)${NC} 👁️  ${CYAN}View Configuration${NC}"
    echo -e "     ↳ Inspect current thresholds, webhooks, and scheduled tasks"

    echo -e "  ${GREEN}4)${NC} 🔧 ${CYAN}Reset Configuration${NC}"
    echo -e "     ↳ Restore default settings for thresholds and webhooks"

    echo -e "  ${GREEN}5)${NC} 📚 ${CYAN}Usage Guide${NC}"
    echo -e "     ↳ Display available commands and usage examples"

    echo -e "  ${GREEN}6)${NC} 📋 ${CYAN}View Logs${NC}"
    echo -e "     ↳ Check recent monitoring logs and activity"

    echo -e "  ${GREEN}7)${NC} 🧪 ${CYAN}Run System Check${NC}"
    echo -e "     ↳ Perform a one-time system check now"

    echo -e "  ${GREEN}8)${NC} 📩 ${CYAN}Configure Periodic Reports${NC}"
    echo -e "     ↳ Set up automatic system reports via webhooks"

    echo -e "  ${GREEN}9)${NC} 🔄 ${CYAN}Configure Log Rotation${NC}"
    echo -e "     ↳ Manage log file rotation and cleanup"

    echo -e "  ${GREEN}10)${NC} 🚪 ${CYAN}Exit${NC}"
    echo -e "     ↳ Close this management interface"

    echo ""
    read -p "Enter your choice (1-10): " option

    case "$option" in
    1) update_serversentry ;;
    2) manage_crons ;;
    3) show_config ;;
    4) reset_config_files ;;
    5) show_usage ;;
    6)
      echo -e "\n${CYAN}Recent Log Entries:${NC}"
      if [ -f "$PROJECT_ROOT/serversentry.log" ]; then
        tail -n 20 "$PROJECT_ROOT/serversentry.log"
      else
        echo -e "${YELLOW}No log file found at $PROJECT_ROOT/serversentry.log${NC}"
      fi
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    7)
      echo -e "\n${CYAN}Running system check...${NC}\n"
      "$PROJECT_ROOT/serversentry.sh" --check
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    8)
      "$PROJECT_ROOT/serversentry.sh" --periodic status >/dev/null 2>&1
      # This would ideally call a specific function to setup periodic reports
      # But for now, we'll just show this message
      echo -e "\n${CYAN}This feature is accessed through the main ServerSentry script.${NC}"
      echo "Run: $PROJECT_ROOT/serversentry.sh --periodic config"
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    9)
      "$PROJECT_ROOT/serversentry.sh" --logs status >/dev/null 2>&1
      # This would ideally call a specific function to configure log rotation
      # But for now, we'll just show this message
      echo -e "\n${CYAN}This feature is accessed through the main ServerSentry script.${NC}"
      echo "Run: $PROJECT_ROOT/serversentry.sh --logs config"
      echo ""
      read -p "Press Enter to continue..." dummy
      ;;
    10) exit 0 ;;
    *)
      echo -e "${RED}Invalid option. Please select 1-10.${NC}"
      sleep 2
      ;;
    esac
  done
}
