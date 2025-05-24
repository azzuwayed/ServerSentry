#!/bin/bash
#
# ServerSentry v2 - Demo Script
#
# This script demonstrates the basic functionality of ServerSentry v2

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

echo "=== ServerSentry v2 Demo ==="
echo ""

# Make the main script executable
chmod +x "$SCRIPT_DIR/bin/serversentry"

# Run version command
echo "1. Checking version"
"$SCRIPT_DIR/bin/serversentry" version
echo ""

# List available plugins
echo "2. Listing available plugins"
"$SCRIPT_DIR/bin/serversentry" list || echo "No plugins found - this is expected on first run"
echo ""

# Run CPU check if available
echo "3. Running CPU check"
"$SCRIPT_DIR/bin/serversentry" check cpu || echo "CPU check failed - plugin may not be fully set up"
echo ""

# Run memory check if available
echo "4. Running memory check"
"$SCRIPT_DIR/bin/serversentry" check memory || echo "Memory check failed - plugin may not be fully set up"
echo ""

# Run disk check if available
echo "5. Running disk check"
"$SCRIPT_DIR/bin/serversentry" check disk || echo "Disk check failed - plugin may not be fully set up"
echo ""

# Run process check if available
echo "6. Running process check"
"$SCRIPT_DIR/bin/serversentry" check process || echo "Process check failed - plugin may not be fully set up"
echo ""

# Run status command (this checks all plugins)
echo "7. Checking overall status"
"$SCRIPT_DIR/bin/serversentry" status || echo "Status check failed - this is expected on first run"
echo ""

# Display logs
echo "8. Viewing logs"
"$SCRIPT_DIR/bin/serversentry" logs view | tail -n 10
echo ""

# Show help
echo "9. Showing help"
"$SCRIPT_DIR/bin/serversentry" help
echo ""

echo "Demo completed. See README.md for more information on how to use ServerSentry v2."
echo ""
echo "To start monitoring in the background, run:"
echo "  $SCRIPT_DIR/bin/serversentry start"
echo ""
echo "To stop monitoring, run:"
echo "  $SCRIPT_DIR/bin/serversentry stop"
