#!/bin/bash
#
# ServerSentry - Configuration creator
# Creates and manages configuration files

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source the install utilities
source "$PROJECT_ROOT/lib/install/utils.sh"

# Update a configuration value in a config file
# Parameters:
#   $1 - Config file path
#   $2 - Parameter name
#   $3 - New value
update_config_value() {
  local config_file="$1"
  local param_name="$2"
  local new_value="$3"

  # Check if the file exists
  if [ ! -f "$config_file" ]; then
    echo -e "${RED}Error: Config file does not exist: $config_file${NC}"
    return 1
  fi

  # Check if parameter exists in file
  if grep -q "^${param_name}=" "$config_file" 2>/dev/null; then
    # Update existing parameter (use different sed syntax for macOS/BSD vs GNU)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|^${param_name}=.*|${param_name}=${new_value}|" "$config_file" || {
        echo -e "${RED}Error: Failed to update parameter in config file${NC}"
        return 1
      }
    else
      sed -i "s|^${param_name}=.*|${param_name}=${new_value}|" "$config_file" || {
        echo -e "${RED}Error: Failed to update parameter in config file${NC}"
        return 1
      }
    fi
  else
    # Add new parameter
    echo "${param_name}=${new_value}" >>"$config_file" || {
      echo -e "${RED}Error: Failed to add parameter to config file${NC}"
      return 1
    }
  fi

  return 0
}

# Create configuration files
create_config_files() {
  print_header "Creating configuration files"

  # Create config and logs directories
  mkdir -p "$PROJECT_ROOT/config"
  mkdir -p "$PROJECT_ROOT/logs/archive"
  echo -e "  ${GREEN}✓${NC} Created config/ and logs/archive/ directories"

  # Create thresholds.conf
  if [ ! -f "$PROJECT_ROOT/config/thresholds.conf" ]; then
    cat >"$PROJECT_ROOT/config/thresholds.conf" <<EOF
# ServerSentry Thresholds Configuration
# Values are in percentage except for load and interval
cpu_threshold=80
memory_threshold=80
disk_threshold=85
load_threshold=2.0
check_interval=60
process_checks=
EOF
    echo -e "  ${GREEN}Created${NC} thresholds.conf"
  else
    echo -e "  ${YELLOW}Skipped${NC} thresholds.conf (already exists)"
  fi

  # Create webhooks.conf
  if [ ! -f "$PROJECT_ROOT/config/webhooks.conf" ]; then
    cat >"$PROJECT_ROOT/config/webhooks.conf" <<EOF
# ServerSentry Webhooks Configuration
# Add one webhook URL per line
EOF
    echo -e "  ${GREEN}Created${NC} webhooks.conf"
  else
    echo -e "  ${YELLOW}Skipped${NC} webhooks.conf (already exists)"
  fi

  # Create logrotate.conf
  if [ ! -f "$PROJECT_ROOT/config/logrotate.conf" ]; then
    cat >"$PROJECT_ROOT/config/logrotate.conf" <<EOF
# ServerSentry Log Rotation Configuration

# Maximum size in MB before rotation (0 = no size limit)
max_size_mb=10

# Maximum age in days before deletion (0 = never delete based on age)
max_age_days=30

# Maximum number of rotated log files to keep (0 = keep all)
max_files=10

# Compress rotated logs (true/false)
compress=true

# Rotate logs on application start (true/false)
rotate_on_start=false

# End of configuration
EOF
    echo -e "  ${GREEN}Created${NC} logrotate.conf"
  else
    echo -e "  ${YELLOW}Skipped${NC} logrotate.conf (already exists)"
  fi

  # Create periodic.conf if it doesn't exist
  if [ ! -f "$PROJECT_ROOT/config/periodic.conf" ]; then
    cat >"$PROJECT_ROOT/config/periodic.conf" <<EOF
# ServerSentry Periodic Reports Configuration

# Report interval in seconds (86400 = daily)
report_interval=86400

# Report detail level (summary, detailed, minimal)
report_level=detailed

# Report checks (comma separated: cpu,memory,disk,processes)
report_checks=cpu,memory,disk,processes

# Force report even without issues (true/false)
force_report=false

# Specific time for reports (HH:MM format, empty for any time)
report_time=

# Days for reports (1-7 for Mon-Sun, comma separated, empty for all days)
report_days=

# End of configuration
EOF
    echo -e "  ${GREEN}Created${NC} periodic.conf"
  else
    echo -e "  ${YELLOW}Skipped${NC} periodic.conf (already exists)"
  fi

  # Create periodic_cron.template
  if [ ! -f "$PROJECT_ROOT/config/periodic_cron.template" ]; then
    cat >"$PROJECT_ROOT/config/periodic_cron.template" <<EOF
# ServerSentry - Periodic Checks Cron Template
# 
# This file contains example cron entries for automated periodic reports.
# To use: Copy and paste the appropriate line into your crontab (crontab -e)
# Be sure to replace /path/to with the actual path to your ServerSentry installation.

# Run periodic check every hour
0 * * * * $PROJECT_ROOT/serversentry.sh --periodic run >> $PROJECT_ROOT/serversentry.log 2>&1

# Run periodic check at specific times (9 AM daily)
0 9 * * * $PROJECT_ROOT/serversentry.sh --periodic run >> $PROJECT_ROOT/serversentry.log 2>&1

# Run periodic check every 6 hours
0 */6 * * * $PROJECT_ROOT/serversentry.sh --periodic run >> $PROJECT_ROOT/serversentry.log 2>&1

# Run checks only on weekdays (Monday through Friday) at 9 AM
0 9 * * 1-5 $PROJECT_ROOT/serversentry.sh --periodic run >> $PROJECT_ROOT/serversentry.log 2>&1

# Run check once every Monday and Thursday at 9 AM
0 9 * * 1,4 $PROJECT_ROOT/serversentry.sh --periodic run >> $PROJECT_ROOT/serversentry.log 2>&1

# Run log rotation daily at midnight
0 0 * * * $PROJECT_ROOT/serversentry.sh --logs rotate >> $PROJECT_ROOT/serversentry.log 2>&1

# NOTE: You can configure the report behavior using the config file at:
# $PROJECT_ROOT/config/periodic.conf
#
# Or use the command-line interface:
# $PROJECT_ROOT/serversentry.sh --periodic config report_level detailed
EOF
    echo -e "  ${GREEN}Created${NC} periodic_cron.template"
  else
    echo -e "  ${YELLOW}Skipped${NC} periodic_cron.template (already exists)"
  fi

  echo -e "${GREEN}Configuration files created successfully!${NC}"
}

# Reset configuration files (remove and recreate)
reset_config_files() {
  print_header "Resetting configuration files"

  read -p "Are you sure you want to reset all configuration files? (y/n): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Reset cancelled.${NC}"
    return 1
  fi

  # Remove configuration files
  rm -f "$PROJECT_ROOT/config/thresholds.conf"
  rm -f "$PROJECT_ROOT/config/webhooks.conf"
  rm -f "$PROJECT_ROOT/config/logrotate.conf"
  rm -f "$PROJECT_ROOT/config/periodic.conf"

  # Recreate configuration files
  create_config_files

  echo -e "${GREEN}Configuration files have been reset successfully!${NC}"
  return 0
}
