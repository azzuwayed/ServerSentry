#!/bin/bash
#
# ServerSentry - Installation script
# Installs and configures the ServerSentry monitoring tool
#
# This script has been refactored to use a modular approach with
# components stored in lib/install/ directory.

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the paths module
source "$SCRIPT_DIR/lib/utils/paths.sh"

# Get standardized paths
PROJECT_ROOT="$(get_project_root)"

# Source all required modules
source "$PROJECT_ROOT/lib/install/utils.sh"
source "$PROJECT_ROOT/lib/install/deps.sh"
source "$PROJECT_ROOT/lib/install/permissions.sh"
source "$PROJECT_ROOT/lib/install/config.sh"
source "$PROJECT_ROOT/lib/install/cron.sh"
source "$PROJECT_ROOT/lib/install/help.sh"
source "$PROJECT_ROOT/lib/install/menu.sh"

# Print the header
print_app_header

# Check if running as root (optional)
check_root

# Detect if this is an update or a new installation
is_update=$(check_update_status)

# Process command line arguments if provided
if [ $# -gt 0 ]; then
    case "$1" in
    --help | -h)
        show_help
        exit 0
        ;;
    --check-deps)
        check_dependencies
        exit $?
        ;;
    --set-perms)
        set_permissions
        exit $?
        ;;
    --create-config)
        create_config_files
        exit $?
        ;;
    --reset-config)
        reset_config_files
        exit $?
        ;;
    --manage-crons)
        manage_crons
        exit $?
        ;;
    --usage)
        show_usage
        exit 0
        ;;
    --install)
        install_serversentry
        exit $?
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
    esac
fi

# If no arguments provided, run in interactive mode
if [ "$is_update" = "true" ]; then
    # Show update/management menu for existing installation
    update_menu
else
    # Show installation menu for new installation
    install_menu
fi

exit 0
