#!/bin/bash
#
# ServerSentry - Configuration commands
# Manages configuration settings and thresholds

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/config/config.sh"

# Update a threshold or configuration value
cli_update() {
  local param="$1"

  if [ -z "$param" ]; then
    echo "Error: Threshold value is required (e.g., cpu_threshold=85)"
    echo "Usage: $0 --update NAME=VALUE"
    return 1
  fi

  local THRESHOLD_NAME=$(echo "$param" | cut -d= -f1)
  local THRESHOLD_VALUE=$(echo "$param" | cut -d= -f2)

  if [ -z "$THRESHOLD_NAME" ] || [ -z "$THRESHOLD_VALUE" ]; then
    echo "Error: Invalid format. Use NAME=VALUE (e.g., cpu_threshold=85)"
    return 1
  fi

  update_threshold "$THRESHOLD_NAME" "$THRESHOLD_VALUE"
  local status=$?

  if [ $status -eq 0 ]; then
    echo -e "${GREEN}Updated $THRESHOLD_NAME to $THRESHOLD_VALUE${NC}"
  fi

  return $status
}

# List all thresholds and configuration
cli_list() {
  # Load configuration
  load_thresholds
  load_webhooks

  # Print current configuration
  print_config

  return 0
}
