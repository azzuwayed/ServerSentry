#!/usr/bin/env bash
#
# ServerSentry v2 - Installation Script
#
# This script installs and configures ServerSentry v2

set -eo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export BASE_DIR

# Skip error handling system initialization in install script to avoid interference
# The error handling system can be too aggressive during installation
# if [[ -f "$BASE_DIR/lib/core/error_handling.sh" ]]; then
#   source "$BASE_DIR/lib/core/error_handling.sh"
#   if ! error_handling_init; then
#     echo "Warning: Failed to initialize error handling system - continuing with basic error handling" >&2
#   fi
# fi

# Source compatibility utilities
source "$BASE_DIR/lib/core/utils/compat_utils.sh"

# Initialize compatibility layer
if ! compat_init; then
  echo "Warning: Failed to initialize compatibility layer - some features may not work correctly" >&2
fi

# Source command utilities for dependency checking
if [[ -f "$BASE_DIR/lib/core/utils/command_utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils/command_utils.sh"
fi

# Source standardized color functions
if [[ -f "$BASE_DIR/lib/ui/cli/colors.sh" ]]; then
  source "$BASE_DIR/lib/ui/cli/colors.sh"
else
  # Fallback definitions if colors.sh not available
  print_success() { echo "[SUCCESS] $*"; }
  print_info() { echo "[INFO] $*"; }
  print_warning() { echo "[WARNING] $*"; }
  print_error() {
    echo "[ERROR] $*"
    # Log error if error handling is available
    if declare -f log_error >/dev/null 2>&1; then
      log_error "install.sh: $*"
    fi
  }
  print_header() { echo "$*"; }
  print_status() {
    shift
    echo "$*"
  }
fi

# Enhanced privilege check with error handling
check_privileges() {
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      print_info "Root privileges are required. Attempting to re-run with sudo..."

      # Use safe_execute if available
      if declare -f safe_execute >/dev/null 2>&1; then
        safe_execute "sudo '$0' $*" "Failed to execute with sudo privileges"
      else
        exec sudo "$0" "$@"
      fi
      exit 1
    else
      local error_msg="This installer must be run as root. Please re-run as root or with sudo."
      print_error "$error_msg"

      # Use error handling system if available
      if declare -f throw_error >/dev/null 2>&1; then
        throw_error 4 "$error_msg" 3
      else
        exit 4
      fi
    fi
  fi
}

# Function to display header
show_header() {
  clear
  print_header "ServerSentry v2 - Installation" 64
  echo ""
}

# Enhanced dependency checking with error handling
check_dependencies() {
  print_info "Checking dependencies..."

  local missing_deps=0
  local deps=("bash" "curl" "jq")

  for dep in "${deps[@]}"; do
    if compat_command_exists "$dep"; then
      print_status "ok" "$dep is installed"
    else
      print_status "error" "$dep is not installed"
      missing_deps=$((missing_deps + 1))
    fi
  done

  # Check bash version using compatibility layer
  local bash_path bash_version bash_major
  bash_path=$(compat_get_bash_path)
  bash_version=$(compat_get_bash_version)
  bash_major=$(echo "$bash_version" | cut -d. -f1)

  if ! compat_bash_is_compatible; then
    print_status "error" "Bash version $bash_version detected at $bash_path, but version 4.0+ is required"
    print_info "Detected OS: $(compat_get_os) $(compat_get_os_version)"
    print_info "Package manager: $(compat_get_package_manager)"

    case "$(compat_get_package_manager)" in
    brew)
      print_info "Install newer bash with: brew install bash"
      ;;
    apt)
      print_info "Your system should have bash 4.0+. Check your PATH."
      ;;
    yum | dnf)
      print_info "Install newer bash with: $(compat_get_package_manager) install bash"
      ;;
    *)
      print_info "Please install bash 4.0+ for your system"
      ;;
    esac
    missing_deps=$((missing_deps + 1))
  else
    print_status "ok" "Bash version $bash_version is compatible (found at $bash_path)"
  fi

  # Check for optional dependencies
  local opt_deps=("mail" "sendmail")

  echo ""
  print_info "Checking optional dependencies..."

  for dep in "${opt_deps[@]}"; do
    if compat_command_exists "$dep"; then
      print_status "ok" "$dep is installed (optional)"
    else
      print_status "warning" "$dep is not installed (optional)"
    fi
  done

  echo ""
  if [ "$missing_deps" -gt 0 ]; then
    local error_msg="Please install missing dependencies and run the installer again."
    print_error "$error_msg"

    # Use error handling system if available
    if declare -f throw_error >/dev/null 2>&1; then
      throw_error 9 "$error_msg" 3
    else
      exit 9
    fi
  else
    print_success "All required dependencies are installed."
  fi
}

# Enhanced directory setup with error handling
setup_directories() {
  print_info "Setting up directories..."

  # Create log directory with error handling
  if declare -f safe_execute >/dev/null 2>&1; then
    safe_execute "compat_mkdir '$BASE_DIR/logs' 755" "Failed to create logs directory"
  else
    compat_mkdir "$BASE_DIR/logs" 755 || {
      print_error "Failed to create logs directory"
      exit 1
    }
  fi
  print_success "Created logs directory"

  # Create log archive directory
  if declare -f safe_execute >/dev/null 2>&1; then
    safe_execute "compat_mkdir '$BASE_DIR/logs/archive' 755" "Failed to create logs archive directory"
  else
    compat_mkdir "$BASE_DIR/logs/archive" 755 || {
      print_error "Failed to create logs archive directory"
      exit 1
    }
  fi
  print_success "Created logs archive directory"

  # Create periodic results directory
  if declare -f safe_execute >/dev/null 2>&1; then
    safe_execute "compat_mkdir '$BASE_DIR/logs/periodic' 755" "Failed to create periodic results directory"
  else
    compat_mkdir "$BASE_DIR/logs/periodic" 755 || {
      print_error "Failed to create periodic results directory"
      exit 1
    }
  fi
  print_success "Created periodic results directory"

  # Set permissions using compatibility layer with error handling
  local files_to_chmod=(
    "$BASE_DIR/bin/serversentry"
    "$BASE_DIR/bin/install.sh"
  )

  for file in "${files_to_chmod[@]}"; do
    if [[ -f "$file" ]]; then
      if declare -f safe_execute >/dev/null 2>&1; then
        safe_execute "compat_chmod 755 '$file'" "Failed to set permissions for $file"
      else
        compat_chmod 755 "$file" || print_warning "Failed to set permissions for $file"
      fi
    fi
  done

  # Set directory permissions
  if declare -f safe_execute >/dev/null 2>&1; then
    safe_execute "chmod -R 755 '$BASE_DIR/lib'" "Failed to set lib directory permissions"
    safe_execute "chmod -R 644 '$BASE_DIR/logs'" "Failed to set logs file permissions"
    safe_execute "compat_chmod 755 '$BASE_DIR/logs'" "Failed to set logs directory permissions"
    safe_execute "compat_chmod 755 '$BASE_DIR/logs/archive'" "Failed to set archive directory permissions"
    safe_execute "compat_chmod 755 '$BASE_DIR/logs/periodic'" "Failed to set periodic directory permissions"
  else
    chmod -R 755 "$BASE_DIR/lib" || print_warning "Failed to set lib directory permissions"
    chmod -R 644 "$BASE_DIR/logs" || print_warning "Failed to set logs file permissions"
    compat_chmod 755 "$BASE_DIR/logs" || print_warning "Failed to set logs directory permissions"
    compat_chmod 755 "$BASE_DIR/logs/archive" || print_warning "Failed to set archive directory permissions"
    compat_chmod 755 "$BASE_DIR/logs/periodic" || print_warning "Failed to set periodic directory permissions"
  fi

  print_success "Directories and permissions set up"
}

# Set up configuration files
setup_configuration() {
  print_info "Setting up configuration..."

  # Create main config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config" ]; then
    mkdir -p "$BASE_DIR/config"
    print_success "Created config directory"
  fi

  # Create plugin config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config/plugins" ]; then
    mkdir -p "$BASE_DIR/config/plugins"
    print_success "Created plugin config directory"
  fi

  # Create notification config directory if it doesn't exist
  if [ ! -d "$BASE_DIR/config/notifications" ]; then
    mkdir -p "$BASE_DIR/config/notifications"
    print_success "Created notification config directory"
  fi

  # Create main YAML config file if it doesn't exist
  if [ ! -f "$BASE_DIR/config/serversentry.yaml" ]; then
    cat >"$BASE_DIR/config/serversentry.yaml" <<EOF
# ServerSentry v2 Configuration
# Main configuration file for the ServerSentry monitoring system

# Core System Settings
system:
  enabled: true
  log_level: info
  check_interval: 60
  check_timeout: 30
  max_log_size: 10485760  # 10MB
  max_log_archives: 10

# Plugin Configuration
plugins:
  enabled: [cpu, memory, disk]
  directory: lib/plugins
  config_directory: config/plugins

# Notification System
notifications:
  enabled: true
  channels: []
  cooldown_period: 300  # 5 minutes between notifications

  # Teams Integration
  teams:
    webhook_url: ""
    notification_title: "ServerSentry Alert"
    enabled: false

  # Email Configuration
  email:
    enabled: false
    from: "serversentry@localhost"
    to: ""
    subject: "[ServerSentry] Alert: {status}"
    smtp_server: "localhost"
    smtp_port: 587

# Anomaly Detection
anomaly_detection:
  enabled: true
  default_sensitivity: 2.0
  data_retention_days: 30
  minimum_data_points: 10

# Composite Checks
composite_checks:
  enabled: true
  config_directory: config/composite

# Performance Monitoring
performance:
  track_plugin_performance: true
  track_system_performance: true
  performance_log_retention_days: 7

# Security Settings
security:
  file_permissions:
    config_files: 644
    log_files: 644
    directories: 755

# Advanced Features
advanced:
  enable_json_output: true
  enable_webhook_notifications: true
  enable_template_system: true
  enable_diagnostics: true
EOF
    print_success "Created main YAML configuration file"
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
      print_success "Created $plugin plugin configuration"
    fi
  done

  print_success "Configuration set up"
}

# Set up cron jobs
setup_cron() {
  print_info "Setting up cron jobs..."

  # Create a temp file for the new crontab
  local temp_crontab
  temp_crontab=$(mktemp)

  # Get existing crontab
  crontab -l 2>/dev/null >"$temp_crontab" || echo "" >"$temp_crontab"

  # Check if our cron job already exists
  if grep -q "serversentry" "$temp_crontab"; then
    print_warning "ServerSentry cron job already exists"
  else
    # Add our cron job
    # shellcheck disable=SC2129
    echo "# ServerSentry periodic check (every 5 minutes)" >>"$temp_crontab"
    echo "*/5 * * * * $BASE_DIR/bin/serversentry check >/dev/null 2>&1" >>"$temp_crontab"

    # Add periodic system report job (daily at midnight)
    echo "# ServerSentry daily system report" >>"$temp_crontab"
    echo "0 0 * * * $BASE_DIR/bin/serversentry status > $BASE_DIR/logs/daily_report.log 2>&1" >>"$temp_crontab"

    # Install the new crontab
    crontab "$temp_crontab"
    print_success "Cron jobs installed"
  fi

  # Clean up
  rm -f "$temp_crontab"
}

# Create symbolic link to make serversentry available system-wide
create_symlink() {
  print_info "Creating symbolic link..."

  local bin_dir="/usr/local/bin"

  # Use OS-specific binary paths
  case "$(compat_get_os)" in
  macos)
    # Try Homebrew paths first on macOS
    if [[ -d "/opt/homebrew/bin" ]]; then
      bin_dir="/opt/homebrew/bin"
    elif [[ -d "/usr/local/bin" ]]; then
      bin_dir="/usr/local/bin"
    fi
    ;;
  linux)
    bin_dir="/usr/local/bin"
    ;;
  esac

  # Check if we have permission to create the symlink
  if [[ -w "$bin_dir" ]]; then
    ln -sf "$BASE_DIR/bin/serversentry" "$bin_dir/serversentry"
    print_success "Created symbolic link at $bin_dir/serversentry"
  else
    print_warning "Cannot create symbolic link. Permission denied."
    print_info "To create the symlink manually, run:"
    print_info "sudo ln -sf \"$BASE_DIR/bin/serversentry\" \"$bin_dir/serversentry\""
  fi
}

# Configure webhooks interactively
configure_webhooks() {
  print_info "Configuring webhooks..."

  echo "Which notification providers would you like to enable?"
  echo "1) Microsoft Teams"
  echo "2) Slack"
  echo "3) Discord"
  echo "4) Email"
  echo "5) None/Skip"

  read -r -p "Enter your choices (e.g., 1 2 3): " -a choices

  local notification_channels=""

  for choice in "${choices[@]}"; do
    case "$choice" in
    1)
      echo ""
      echo "Microsoft Teams Configuration:"
      read -r -p "Enter Teams webhook URL: " teams_webhook_url

      # Create the Teams configuration file
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

      print_success "Teams webhook configured"
      ;;

    2)
      echo ""
      echo "Slack Configuration:"
      read -r -p "Enter Slack webhook URL: " slack_webhook_url

      # Create the Slack configuration file
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

      print_success "Slack webhook configured"
      ;;

    3)
      echo ""
      echo "Discord Configuration:"
      read -r -p "Enter Discord webhook URL: " discord_webhook_url

      # Create the Discord configuration file
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

      print_success "Discord webhook configured"
      ;;

    4)
      echo ""
      echo "Email Configuration:"
      read -r -p "Enter email recipient(s) (comma-separated): " email_recipients
      read -r -p "Enter sender email (default: serversentry@hostname): " email_sender

      if [ -z "$email_sender" ]; then
        email_sender="serversentry@$(compat_get_hostname)"
      fi

      echo "Select email send method:"
      echo "1) mail (system mail command)"
      echo "2) sendmail (sendmail command)"
      echo "3) smtp (direct SMTP)"

      read -r -p "Enter your choice (1-3): " email_method_choice

      local email_send_method="mail"
      local smtp_config=""

      case "$email_method_choice" in
      1) email_send_method="mail" ;;
      2) email_send_method="sendmail" ;;
      3)
        email_send_method="smtp"
        read -r -p "SMTP Server: " smtp_server
        read -r -p "SMTP Port (default: 25): " smtp_port
        smtp_port=${smtp_port:-25}
        read -r -p "SMTP Username (optional): " smtp_user

        if [ -n "$smtp_user" ]; then
          read -r -p "SMTP Password: " -s smtp_password
          echo ""
        fi

        read -r -p "Use TLS? (y/n): " -n 1 use_tls
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

      print_success "Email notification configured"
      ;;

    5)
      print_info "Skipping webhook configuration"
      ;;

    *)
      print_warning "Invalid choice: $choice"
      ;;
    esac
  done

  # Update main config with notification channels
  if [ -n "$notification_channels" ]; then
    compat_sed_inplace "s/notification_channels=.*/notification_channels=$notification_channels/" "$BASE_DIR/config/serversentry.yaml"
    print_success "Updated notification channels in main configuration"
  fi
}

# Configure process monitoring
configure_process_monitoring() {
  print_info "Configuring process monitoring..."

  read -r -p "Would you like to monitor specific processes? (y/n): " -n 1 monitor_processes
  echo ""

  if [[ $monitor_processes =~ ^[Yy]$ ]]; then
    read -r -p "Enter process names to monitor (comma-separated): " process_names

    # Update the process plugin configuration
    compat_sed_inplace "s/process_names=.*/process_names=$process_names/" "$BASE_DIR/config/plugins/process.conf"
    print_success "Process monitoring configured"
  else
    print_info "Skipping process monitoring configuration"
  fi
}

# Show usage instructions
show_usage() {
  echo ""
  print_info "Installation complete! Here's how to use ServerSentry:"
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
  # Check privileges first
  check_privileges

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
      print_error "Unknown option: $1"
      print_info "Use --help for usage information"
      exit 1
      ;;
    esac
  fi

  # Interactive installation
  print_info "Starting ServerSentry v2 installation..."

  check_dependencies
  setup_directories
  setup_configuration

  # Ask if user wants to set up webhooks
  read -r -p "Would you like to configure webhook notifications? (y/n): " -n 1 setup_webhooks
  echo ""

  if [[ $setup_webhooks =~ ^[Yy]$ ]]; then
    configure_webhooks
  else
    print_info "Skipping webhook configuration"
  fi

  # Ask if user wants to configure process monitoring
  read -r -p "Would you like to configure process monitoring? (y/n): " -n 1 setup_process
  echo ""

  if [[ $setup_process =~ ^[Yy]$ ]]; then
    configure_process_monitoring
  else
    print_info "Skipping process monitoring configuration"
  fi

  # Ask if user wants to set up cron jobs
  read -r -p "Would you like to set up cron jobs for automated monitoring? (y/n): " -n 1 setup_cron_jobs
  echo ""

  if [[ $setup_cron_jobs =~ ^[Yy]$ ]]; then
    setup_cron
  else
    print_info "Skipping cron job setup"
  fi

  # Ask if user wants to create a symbolic link
  read -r -p "Would you like to create a symbolic link in /usr/local/bin? (y/n): " -n 1 create_link
  echo ""

  if [[ $create_link =~ ^[Yy]$ ]]; then
    create_symlink
  else
    print_info "Skipping symbolic link creation"
  fi

  # Test the installation
  print_info "Testing the installation..."
  # Disable error handling for the test to avoid interference
  set +e
  BASE_DIR="$BASE_DIR" "$BASE_DIR/bin/serversentry" version
  local test_result=$?
  set -e

  # shellcheck disable=SC2181
  if [ $test_result -eq 0 ]; then
    # Consider: if command; then (direct exit code check)
    print_success "Installation test successful!"
  else
    print_error "Installation test failed. Please check the logs."
  fi

  # Show usage instructions
  show_usage

  # Show system compatibility information
  print_info "System compatibility information:"
  if declare -f compat_info >/dev/null 2>&1; then
    compat_info
  else
    echo "OS: $(compat_get_os 2>/dev/null || echo 'unknown')"
    echo "Package Manager: $(compat_get_package_manager 2>/dev/null || echo 'unknown')"
  fi

  print_success "ServerSentry v2 installation complete!"
}

# Run the main function
main "$@"
