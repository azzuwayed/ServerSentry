#!/bin/bash
#
# SysMon - Installation script

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}SysMon - System Monitoring Tool Installer${NC}"
echo "==============================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Not running as root. Some operations may fail.${NC}"
    echo "It's recommended to run this script with sudo."
    echo ""
    read -p "Continue anyway? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 1
    fi
fi

# Check for required commands
echo "Checking for required commands..."
MISSING_COMMANDS=0

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${RED}✗${NC} $1 ${YELLOW}(recommended but not required)${NC}"
        MISSING_COMMANDS=$((MISSING_COMMANDS + 1))
    fi
}

check_command "bash"
check_command "curl"
check_command "grep"
check_command "awk"
check_command "sed"
check_command "bc"
check_command "jq"
check_command "crontab"

if [ $MISSING_COMMANDS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Some recommended commands are missing.${NC}"
    echo "You can install them on Debian/Ubuntu with:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install curl jq bc"
    echo ""
    read -p "Continue with installation anyway? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "Installation aborted."
        exit 1
    fi
fi

# Set proper permissions for scripts
echo ""
echo "Setting permissions..."
chmod +x "$SCRIPT_DIR/sysmon.sh"
chmod +x "$SCRIPT_DIR/lib/config.sh"
chmod +x "$SCRIPT_DIR/lib/monitor.sh"
chmod +x "$SCRIPT_DIR/lib/notify.sh"
chmod +x "$SCRIPT_DIR/lib/utils.sh"
echo -e "${GREEN}Done!${NC}"

# Create configurations
echo ""
echo "Creating configuration files..."
mkdir -p "$SCRIPT_DIR/config"
if [ ! -f "$SCRIPT_DIR/config/thresholds.conf" ]; then
    cat > "$SCRIPT_DIR/config/thresholds.conf" <<EOF
# SysMon Thresholds Configuration
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

if [ ! -f "$SCRIPT_DIR/config/webhooks.conf" ]; then
    cat > "$SCRIPT_DIR/config/webhooks.conf" <<EOF
# SysMon Webhooks Configuration
# Add one webhook URL per line
EOF
    echo -e "  ${GREEN}Created${NC} webhooks.conf"
else
    echo -e "  ${YELLOW}Skipped${NC} webhooks.conf (already exists)"
fi

# Setup cron job
echo ""
echo "Do you want to set up a cron job to run SysMon periodically?"
read -p "Setup cron job? (y/n): " setup_cron

if [[ "$setup_cron" =~ ^[Yy]$ ]]; then
    CRON_INTERVAL="*/5"
    echo ""
    echo "How often should SysMon run?"
    echo "1) Every 5 minutes (default)"
    echo "2) Every 15 minutes"
    echo "3) Every hour"
    echo "4) Custom"
    read -p "Select option (1-4): " cron_option
    
    case "$cron_option" in
        2)
            CRON_INTERVAL="*/15"
            ;;
        3)
            CRON_INTERVAL="0"
            ;;
        4)
            read -p "Enter cron schedule expression (e.g., */10 * * * *): " custom_cron
            ;;
    esac
    
    # Create the cron entry
    if [ -n "$custom_cron" ]; then
        CRON_ENTRY="$custom_cron $SCRIPT_DIR/sysmon.sh --check >> $SCRIPT_DIR/sysmon.log 2>&1"
    else
        CRON_ENTRY="$CRON_INTERVAL * * * * $SCRIPT_DIR/sysmon.sh --check >> $SCRIPT_DIR/sysmon.log 2>&1"
    fi
    
    # Add to crontab
    (crontab -l 2>/dev/null || echo "") | grep -v "$SCRIPT_DIR/sysmon.sh" | { cat; echo "$CRON_ENTRY"; } | crontab -
    
    echo -e "${GREEN}Cron job has been set up successfully!${NC}"
    echo "SysMon will run according to the schedule you specified."
else
    echo "Skipping cron job setup."
    echo "You can manually add a cron job later with:"
    echo "crontab -e"
fi

# Setup complete
echo ""
echo -e "${GREEN}SysMon installation complete!${NC}"
echo ""
echo "To use SysMon, run:"
echo "  $SCRIPT_DIR/sysmon.sh --help"
echo ""
echo "Remember to add webhook URLs for notifications:"
echo "  $SCRIPT_DIR/sysmon.sh --add-webhook https://your-webhook-url"
echo ""
echo "You can test the webhooks with:"
echo "  $SCRIPT_DIR/sysmon.sh --test-webhook"
echo ""
echo "To perform a one-time check of your system:"
echo "  $SCRIPT_DIR/sysmon.sh --check"
echo ""

exit 0
