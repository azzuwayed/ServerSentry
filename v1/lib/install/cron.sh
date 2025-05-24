#!/bin/bash
#
# ServerSentry - Cron job management
# Handles cron job setup, listing, removal, and testing

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source the install utilities
source "$PROJECT_ROOT/lib/install/utils.sh"

# List existing cron jobs
list_cron_jobs() {
  print_header "Current ServerSentry cron jobs"
  existing_crons=$(crontab -l 2>/dev/null | grep "$PROJECT_ROOT/serversentry.sh")

  if [ -z "$existing_crons" ]; then
    echo -e "  ${YELLOW}No existing cron jobs found${NC}"
    return 1
  else
    echo "$existing_crons" | nl -w2 -s") "
    return 0
  fi
}

# Set up a new cron job
setup_cron_job() {
  print_header "Setting up a cron job"

  echo -e "${CYAN}How often should ServerSentry run?${NC}"
  echo -e "1) Every 5 minutes    ${YELLOW}• Recommended for critical systems (default)${NC}"
  echo -e "2) Every 15 minutes   ${YELLOW}• Good balance between monitoring and resources${NC}"
  echo -e "3) Every hour         ${YELLOW}• Less frequent, suitable for stable systems${NC}"
  echo -e "4) Daily (midnight)   ${YELLOW}• Once per day health check${NC}"
  echo -e "5) Custom             ${YELLOW}• Define your own cron schedule expression${NC}"

  echo ""
  read -p "Select option (1-5): " cron_option

  case "$cron_option" in
  1) CRON_INTERVAL="*/5 * * * *" ;;
  2) CRON_INTERVAL="*/15 * * * *" ;;
  3) CRON_INTERVAL="0 * * * *" ;;
  4) CRON_INTERVAL="0 0 * * *" ;;
  5)
    echo "Enter cron schedule expression (e.g., */10 * * * *):"
    read -p "Cron expression: " CRON_INTERVAL
    ;;
  *) CRON_INTERVAL="*/5 * * * *" ;;
  esac

  # Create the cron entry
  CRON_ENTRY="$CRON_INTERVAL $PROJECT_ROOT/serversentry.sh --check >> $PROJECT_ROOT/serversentry.log 2>&1"

  # Add to crontab
  (crontab -l 2>/dev/null || echo "") | {
    cat
    echo "$CRON_ENTRY"
  } | crontab -

  echo -e "${GREEN}Cron job has been set up successfully!${NC}"
  echo "ServerSentry will run: $CRON_INTERVAL"
  return 0
}

# Remove a specific cron job
remove_cron_job() {
  print_header "Remove a specific cron job"

  list_cron_jobs
  if [ $? -eq 1 ]; then
    return 1
  fi

  echo ""
  read -p "Enter number of cron job to remove (0 to cancel): " cron_number

  if [ "$cron_number" = "0" ]; then
    echo "Operation cancelled."
    return 0
  fi

  local cron_to_remove=$(crontab -l | grep "$PROJECT_ROOT/serversentry.sh" | sed -n "${cron_number}p")

  if [ -z "$cron_to_remove" ]; then
    echo -e "${RED}Invalid cron job number${NC}"
    return 1
  fi

  # Remove the specific cron job
  crontab -l | grep -v "$cron_to_remove" | crontab -
  echo -e "${GREEN}Cron job removed successfully!${NC}"
  return 0
}

# Remove all ServerSentry cron jobs
remove_all_cron_jobs() {
  print_header "Remove all ServerSentry cron jobs"

  read -p "Are you sure you want to remove ALL ServerSentry cron jobs? (y/n): " confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    return 0
  fi

  crontab -l 2>/dev/null | grep -v "$PROJECT_ROOT/serversentry.sh" | crontab -
  echo -e "${GREEN}All ServerSentry cron jobs have been removed.${NC}"
  return 0
}

# Test a cron job manually
test_cron_job() {
  print_header "Test a cron job manually"

  list_cron_jobs
  if [ $? -eq 1 ]; then
    return 1
  fi

  echo ""
  read -p "Enter number of cron job to test (0 to cancel): " cron_number

  if [ "$cron_number" = "0" ]; then
    echo "Operation cancelled."
    return 0
  fi

  local cron_to_test=$(crontab -l | grep "$PROJECT_ROOT/serversentry.sh" | sed -n "${cron_number}p")

  if [ -z "$cron_to_test" ]; then
    echo -e "${RED}Invalid cron job number${NC}"
    return 1
  fi

  # Extract command part (everything after the time fields)
  local cron_command=$(echo "$cron_to_test" | cut -d' ' -f6-)

  # Split command and redirection
  local command=$(echo "$cron_command" | grep -o "^[^>]*")
  local redirection=$(echo "$cron_command" | grep -o ">>.*" || echo "")

  echo ""
  echo -e "${CYAN}Testing actual cron job command:${NC}"
  echo -e "${YELLOW}$command${NC}"
  echo ""
  read -p "Proceed with test? (y/n): " confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Test cancelled."
    return 0
  fi

  echo ""
  echo -e "${CYAN}Executing command from crontab:${NC}"
  echo "-------------------------------------"

  # Execute the exact command from crontab
  eval "$command"

  local status=$?
  echo "-------------------------------------"
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}✓ Test completed successfully (exit code: $status)${NC}"
  else
    echo -e "${RED}✗ Test failed with exit code: $status${NC}"
  fi

  echo ""
  if [ -n "$redirection" ]; then
    echo -e "${YELLOW}Note:${NC} When run by cron, output will be redirected: $redirection"
  fi

  return $status
}

# Main cron management function
manage_crons() {
  while true; do
    print_header "ServerSentry Cron Management"

    list_cron_jobs

    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo -e "1) Add new cron job         ${YELLOW}• Schedule a new automatic monitoring task${NC}"
    echo -e "2) Remove specific cron job ${YELLOW}• Delete an individual scheduled task${NC}"
    echo -e "3) Remove all cron jobs     ${YELLOW}• Clear all ServerSentry scheduled tasks${NC}"
    echo -e "4) Test cron job manually   ${YELLOW}• Run a scheduled task now to verify it works${NC}"
    echo -e "5) Return to main menu      ${YELLOW}• Go back to management options${NC}"

    echo ""
    read -p "Select option (1-5): " cron_action

    case "$cron_action" in
    1) setup_cron_job ;;
    2) remove_cron_job ;;
    3) remove_all_cron_jobs ;;
    4) test_cron_job ;;
    5) return 0 ;;
    *) echo -e "${RED}Invalid option${NC}" ;;
    esac

    echo ""
    read -p "Press Enter to continue..." dummy
  done
}
