#!/bin/bash
#
# ServerSentry - Notification functionality (modular version)
# This file maintains the original interface while delegating to the modular implementation

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source the main module
source "$SCRIPT_DIR/notify/main.sh"

# The rest of this file just re-exports the functions from the modular structure
# All actual implementations have been moved to the notify/ subdirectory

# All functions below are maintained for backward compatibility
# They delegate to their modular counterparts

# These exports ensure that the function signatures and behavior 
# are identical to the original notify.sh implementation
