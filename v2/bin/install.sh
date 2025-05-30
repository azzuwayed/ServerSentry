#!/bin/bash
#
# ServerSentry v2 - Installation Script
#
# This script installs and configures ServerSentry v2

set -eo pipefail

# Enforce root privileges or auto-elevate
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    echo "[INFO] Root privileges are required. Attempting to re-run with sudo..."
    exec sudo "$0" "$@"
    exit 1
  else
    echo "[ERROR] This installer must be run as root. Please re-run as root or with sudo."
    exit 1
  fi
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
  local level="$1"
  local message="$2"

  case "$level" in
  "info")
    echo -e "${BLUE}[INFO]${NC} $message"
    ;;
  "success")
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    ;;
  "warning")
    echo -e "${YELLOW}[WARNING]${NC} $message"
    ;;
  "error")
    echo -e "${RED}[ERROR]${NC} $message"
    ;;
  *)
    echo -e "$message"
    ;;
  esac
}

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}=======================================${NC}"
  echo -e "${CYAN}    ServerSentry v2 - Installation    ${NC}"
  echo -e "${CYAN}=======================================${NC}"
  echo ""
}

# Check for required dependencies
check_dependencies() {
  print_message "info" "Checking dependencies..."

  local missing_deps=0
  local deps=("bash" "curl" "jq")

  for dep in "${deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
      print_message "success" "✓ $dep is installed"
    else
      print_message "error" "✗ $dep is not installed"
      missing_deps=$((missing_deps + 1))
    fi
  done

  # Check bash version (need 5.0 or higher)
  local bash_version
  bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  local bash_major
  bash_major=$(echo "$bash_version" | cut -d. -f1)
  local bash_minor
  bash_minor=$(echo "$bash_version" | cut -d. -f2)

  if [ "$bash_major" -lt 5 ]; then
    print_message "error" "✗ Bash version $bash_version detected, but version 5.0+ is required"
    missing_deps=$((missing_deps + 1))
  else
    print_message "success" "✓ Bash version $bash_version is compatible"
  fi

  # Check for optional dependencies
  local opt_deps=("mail" "sendmail")

  echo ""
  print_message "info" "Checking optional dependencies..."

  for dep in "${opt_deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
      print_message "success" "✓ $dep is installed (optional)"
    else
      print_message "warning" "✗ $dep is not installed (optional)"
    fi
  done

  echo ""
  if [ "$missing_deps" -gt 0 ]; then
    print_message "error" "Please install missing dependencies and run the installer again."
    exit 1
  else
    print_message "success" "All required dependencies are installed."
  fi
}

# Set up directories and permissions
setup_directories() {
  print_message "info" "Setting up directories..."

  # Create log directory
  if [ ! -d "$BASE_DIR/logs" ]; then
    mkdir -p "$BASE_DIR/logs"
    print_message "success" "Created logs directory"
  fi

  # Create log archive directory
  if [ ! -d "$BASE_DIR/logs/archive" ]; then
    mkdir -p "$BASE_DIR/logs/archive"
    print_message "success" "Created logs archive directory"
  fi

  # Create periodic results directory
  if [ ! -d "$BASE_DIR/logs/periodic" ]; then
    mkdir -p "$BASE_DIR/logs/periodic"
    print_message "success" "Created periodic results directory"
  fi

  # Set permissions
  chmod 755 "$BASE_DIR/bin/serversentry"
  chmod 755 "$BASE_DIR/bin/install.sh"
  chmod -R 755 "$BASE_DIR/lib"
  chmod -R 644 "$BASE_DIR/logs"
  chmod 755 "$BASE_DIR/logs"
  chmod 755 "$BASE_DIR/logs/archive"
  chmod 755 "$BASE_DIR/logs/periodic"

  print_message "success" "Directories and permissions set up"
}

# Set up configuration files
setup_configuration() {
  print_message "info" "Setting up configuration..."

  # Create main config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config" ]; then
    mkdir -p "$BASE_DIR/config"
    print_message "success" "Created config directory"
  fi

  # Create plugin config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config/plugins" ]; then
    mkdir -p "$BASE_DIR/config/plugins"
    print_message "success" "Created plugin config directory"
  fi

  # Create notification config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config/notifications" ]; then
    mkdir -p "$BASE_DIR/config/notifications"
    print_message "success" "Created notification config directory"
  fi

  # Create main YAML config file if it doesn't exist
  if [ ! -f "$BASE_DIR/config/serversentry.yaml" ]; then
    cat >"$BASE_DIR/config/serversentry.yaml" <<EOF
# ServerSentry v2 Configuration

# General settings
enabled: true
log_level: info
check_interval: 60

# Plugin settings
plugins_enabled: [cpu, memory, disk]

# Notification settings
notification_enabled: true
notification_channels: []

# Teams notification settings
teams_webhook_url: ""
teams_notification_title: "ServerSentry Alert"

# Email notification settings
email_enabled: false
email_from: "serversentry@localhost"
email_to: ""
email_subject: "[ServerSentry] Alert: {status}"

# Advanced settings
max_log_size: 10485760  # 10MB
max_log_archives: 10
check_timeout: 30
EOF
    print_message "success" "Created main YAML configuration file"
  fi

  # Set up sample plugin configurations if they don't exist
  local plugins=("cpu" "memory" "disk" "process")

  for plugin in "${plugins[@]}"; do
    if [ ! -f "$BASE_DIR/config/plugins/${plugin}.conf" ]; then
      case "$plugin" in
      cpu)
        cat >"$BASE_DIR/config/plugins/${plugin}.conf" <<EOF
# CPU Plugin Configuration
cpu_threshold=80
cpu_warning_threshold=70
EOF
        ;;
      memory)
        cat >"$BASE_DIR/config/plugins/${plugin}.conf" <<EOF
# Memory Plugin Configuration
memory_threshold=80
memory_warning_threshold=70
EOF
        ;;
      disk)
        cat >"$BASE_DIR/config/plugins/${plugin}.conf" <<EOF
# Disk Plugin Configuration
disk_threshold=85
disk_warning_threshold=75
disk_monitored_paths=/
EOF
        ;;
      process)
        cat >"$BASE_DIR/config/plugins/${plugin}.conf" <<EOF
# Process Plugin Configuration
process_names=
process_check_interval=60
EOF
        ;;
      esac
      print_message "success" "Created $plugin plugin configuration"
    fi
  done

  print_message "success" "Configuration set up"
}

# Set up cron jobs
setup_cron() {
  print_message "info" "Setting up cron jobs..."

  # Create a temp file for the new crontab
  local temp_crontab
  temp_crontab=$(mktemp)

  # Get existing crontab
  crontab -l 2>/dev/null >"$temp_crontab" || echo "" >"$temp_crontab"

  # Check if our cron job already exists
  if grep -q "serversentry" "$temp_crontab"; then
    print_message "warning" "ServerSentry cron job already exists"
  else
    # Add our cron job
    echo "# ServerSentry periodic check (every 5 minutes)" >>"$temp_crontab"
    echo "*/5 * * * * $BASE_DIR/bin/serversentry check >/dev/null 2>&1" >>"$temp_crontab"

    # Add periodic system report job (daily at midnight)
    echo "# ServerSentry daily system report" >>"$temp_crontab"
    echo "0 0 * * * $BASE_DIR/bin/serversentry status > $BASE_DIR/logs/daily_report.log 2>&1" >>"$temp_crontab"

    # Install the new crontab
    crontab "$temp_crontab"
    print_message "success" "Cron jobs installed"
  fi

  # Clean up
  rm -f "$temp_crontab"
}

# Create symbolic link to make serversentry available system-wide
create_symlink() {
  print_message "info" "Creating symbolic link..."

  # Check if we have permission to create the symlink
  if [ -w /usr/local/bin ]; then
    ln -sf "$BASE_DIR/bin/serversentry" /usr/local/bin/serversentry
    print_message "success" "Created symbolic link at /usr/local/bin/serversentry"
  else
    print_message "warning" "Cannot create symbolic link. Permission denied."
    print_message "info" "To create the symlink manually, run:"
    print_message "info" "sudo ln -sf \"$BASE_DIR/bin/serversentry\" /usr/local/bin/serversentry"
  fi
}

# Configure webhooks interactively
configure_webhooks() {
  print_message "info" "Configuring webhooks..."

  echo "Which notification providers would you like to enable?"
  echo "1) Microsoft Teams"
  echo "2) Slack"
  echo "3) Discord"
  echo "4) Email"
  echo "5) None/Skip"

  read -p "Enter your choices (e.g., 1 2 3): " -a choices

  local notification_channels=""

  for choice in "${choices[@]}"; do
    case "$choice" in
    1)
      echo ""
      echo "Microsoft Teams Configuration:"
      read -p "Enter Teams webhook URL: " teams_webhook_url

      # Update the Teams configuration file
      cat >"$BASE_DIR/config/notifications/teams.conf" <<EOF
# Teams Notification Provider Configuration
teams_webhook_url="$teams_webhook_url"
teams_notification_title="ServerSentry Alert"
teams_enabled=true
teams_min_level=1
EOF

      if [ -n "$notification_channels" ]; then
        notification_channels="${notification_channels},teams"
      else
        notification_channels="teams"
      fi

      print_message "success" "Teams webhook configured"
      ;;

    2)
      echo ""
      echo "Slack Configuration:"
      read -p "Enter Slack webhook URL: " slack_webhook_url

      # Update the Slack configuration file
      cat >"$BASE_DIR/config/notifications/slack.conf" <<EOF
# Slack Notification Provider Configuration
slack_webhook_url="$slack_webhook_url"
slack_notification_title="ServerSentry Alert"
slack_username="ServerSentry"
slack_icon_emoji=":robot_face:"
slack_enabled=true
slack_min_level=1
EOF

      if [ -n "$notification_channels" ]; then
        notification_channels="${notification_channels},slack"
      else
        notification_channels="slack"
      fi

      print_message "success" "Slack webhook configured"
      ;;

    3)
      echo ""
      echo "Discord Configuration:"
      read -p "Enter Discord webhook URL: " discord_webhook_url

      # Update the Discord configuration file
      cat >"$BASE_DIR/config/notifications/discord.conf" <<EOF
# Discord Notification Provider Configuration
discord_webhook_url="$discord_webhook_url"
discord_notification_title="ServerSentry Alert"
discord_username="ServerSentry"
discord_enabled=true
discord_min_level=1
EOF

      if [ -n "$notification_channels" ]; then
        notification_channels="${notification_channels},discord"
      else
        notification_channels="discord"
      fi

      print_message "success" "Discord webhook configured"
      ;;

    4)
      echo ""
      echo "Email Configuration:"
      read -p "Enter email recipient(s) (comma-separated): " email_recipients
      read -p "Enter sender email (default: serversentry@hostname): " email_sender

      if [ -z "$email_sender" ]; then
        email_sender="serversentry@$(hostname -f 2>/dev/null || echo 'localhost')"
      fi

      echo "Select email send method:"
      echo "1) mail (system mail command)"
      echo "2) sendmail (sendmail command)"
      echo "3) smtp (direct SMTP)"

      read -p "Enter your choice (1-3): " email_method_choice

      local email_send_method="mail"
      local smtp_config=""

      case "$email_method_choice" in
      1) email_send_method="mail" ;;
      2) email_send_method="sendmail" ;;
      3)
        email_send_method="smtp"
        read -p "SMTP Server: " smtp_server
        read -p "SMTP Port (default: 25): " smtp_port
        smtp_port=${smtp_port:-25}
        read -p "SMTP Username (optional): " smtp_user

        if [ -n "$smtp_user" ]; then
          read -p "SMTP Password: " -s smtp_password
          echo ""
        fi

        read -p "Use TLS? (y/n): " -n 1 use_tls
        echo ""

        if [[ $use_tls =~ ^[Yy]$ ]]; then
          use_tls="true"
        else
          use_tls="false"
        fi

        smtp_config="email_smtp_server=\"$smtp_server\"
email_smtp_port=\"$smtp_port\"
email_smtp_user=\"$smtp_user\"
email_smtp_password=\"$smtp_password\"
email_smtp_use_tls=\"$use_tls\""
        ;;
      esac

      # Update the Email configuration file
      cat >"$BASE_DIR/config/notifications/email.conf" <<EOF
# Email Notification Provider Configuration
email_recipients="$email_recipients"
email_sender="$email_sender"
email_subject_prefix="[ServerSentry]"
email_send_method="$email_send_method"

# SMTP Configuration
$smtp_config

email_enabled=true
email_min_level=1
EOF

      if [ -n "$notification_channels" ]; then
        notification_channels="${notification_channels},email"
      else
        notification_channels="email"
      fi

      print_message "success" "Email notification configured"
      ;;

    5)
      print_message "info" "Skipping webhook configuration"
      ;;

    *)
      print_message "warning" "Invalid choice: $choice"
      ;;
    esac
  done

  # Update main config with notification channels
  if [ -n "$notification_channels" ]; then
    sed -i.bak "s/notification_channels=.*/notification_channels=$notification_channels/" "$BASE_DIR/config/serversentry.yaml" 2>/dev/null ||
      sed "s/notification_channels=.*/notification_channels=$notification_channels/" "$BASE_DIR/config/serversentry.yaml" >"$BASE_DIR/config/serversentry.yaml.new" &&
      mv "$BASE_DIR/config/serversentry.yaml.new" "$BASE_DIR/config/serversentry.yaml"

    print_message "success" "Updated notification channels in main configuration"
  fi
}

# Configure process monitoring
configure_process_monitoring() {
  print_message "info" "Configuring process monitoring..."

  read -p "Would you like to monitor specific processes? (y/n): " -n 1 monitor_processes
  echo ""

  if [[ $monitor_processes =~ ^[Yy]$ ]]; then
    read -p "Enter process names to monitor (comma-separated): " process_names

    # Update the process plugin configuration
    sed -i.bak "s/process_names=.*/process_names=$process_names/" "$BASE_DIR/config/plugins/process.conf" 2>/dev/null ||
      sed "s/process_names=.*/process_names=$process_names/" "$BASE_DIR/config/plugins/process.conf" >"$BASE_DIR/config/plugins/process.conf.new" &&
      mv "$BASE_DIR/config/plugins/process.conf.new" "$BASE_DIR/config/plugins/process.conf"

    print_message "success" "Process monitoring configured"
  else
    print_message "info" "Skipping process monitoring configuration"
  fi
}

# Show usage instructions
show_usage() {
  echo ""
  print_message "info" "Installation complete! Here's how to use ServerSentry:"
  echo ""
  echo "Commands:"
  echo "  serversentry status      - Show current system status"
  echo "  serversentry check       - Run a system check"
  echo "  serversentry check cpu   - Run a specific plugin check"
  echo "  serversentry start       - Start monitoring in background"
  echo "  serversentry stop        - Stop monitoring"
  echo "  serversentry list        - List available plugins"
  echo "  serversentry configure   - Edit main configuration"
  echo "  serversentry logs        - View log files"
  echo "  serversentry version     - Show version information"
  echo "  serversentry help        - Show help message"
  echo ""
  echo "Configuration files are located in: $BASE_DIR/config/"
  echo "Log files are located in: $BASE_DIR/logs/"
  echo ""
  echo "For more information, see the documentation in: $BASE_DIR/docs/"
}

# Main installation function
main() {
  show_header

  # Process command line arguments
  if [ $# -gt 0 ]; then
    case "$1" in
    --check-deps)
      check_dependencies
      exit 0
      ;;
    --setup-dirs)
      setup_directories
      exit 0
      ;;
    --setup-config)
      setup_configuration
      exit 0
      ;;
    --setup-cron)
      setup_cron
      exit 0
      ;;
    --setup-webhooks)
      configure_webhooks
      exit 0
      ;;
    --setup-process)
      configure_process_monitoring
      exit 0
      ;;
    --help | -h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --check-deps    Check for dependencies"
      echo "  --setup-dirs    Set up directories and permissions"
      echo "  --setup-config  Set up configuration files"
      echo "  --setup-cron    Set up cron jobs"
      echo "  --setup-webhooks Configure webhook notifications"
      echo "  --setup-process Configure process monitoring"
      echo "  --help, -h      Show this help message"
      exit 0
      ;;
    *)
      print_message "error" "Unknown option: $1"
      print_message "info" "Use --help for usage information"
      exit 1
      ;;
    esac
  fi

  # Interactive installation
  print_message "info" "Starting ServerSentry v2 installation..."

  check_dependencies
  setup_directories
  setup_configuration

  # Ask if user wants to set up webhooks
  read -p "Would you like to configure webhook notifications? (y/n): " -n 1 setup_webhooks
  echo ""

  if [[ $setup_webhooks =~ ^[Yy]$ ]]; then
    configure_webhooks
  else
    print_message "info" "Skipping webhook configuration"
  fi

  # Ask if user wants to configure process monitoring
  read -p "Would you like to configure process monitoring? (y/n): " -n 1 setup_process
  echo ""

  if [[ $setup_process =~ ^[Yy]$ ]]; then
    configure_process_monitoring
  else
    print_message "info" "Skipping process monitoring configuration"
  fi

  # Ask if user wants to set up cron jobs
  read -p "Would you like to set up cron jobs for automated monitoring? (y/n): " -n 1 setup_cron_jobs
  echo ""

  if [[ $setup_cron_jobs =~ ^[Yy]$ ]]; then
    setup_cron
  else
    print_message "info" "Skipping cron job setup"
  fi

  # Ask if user wants to create a symbolic link
  read -p "Would you like to create a symbolic link in /usr/local/bin? (y/n): " -n 1 create_link
  echo ""

  if [[ $create_link =~ ^[Yy]$ ]]; then
    create_symlink
  else
    print_message "info" "Skipping symbolic link creation"
  fi

  # Test the installation
  print_message "info" "Testing the installation..."
  "$BASE_DIR/bin/serversentry" version

  if [ $? -eq 0 ]; then
    print_message "success" "Installation test successful!"
  else
    print_message "error" "Installation test failed. Please check the logs."
  fi

  # Show usage instructions
  show_usage

  print_message "success" "ServerSentry v2 installation complete!"
}

# Run the main function
main "$@"
