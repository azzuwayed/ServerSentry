#!/bin/bash
#
# ServerSentry - Log management commands
# Handles log rotation, status, and configuration

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/log/logrotate.sh"

# Handle log management commands
cli_logs() {
  local command="$1"

  if [ -z "$command" ]; then
    echo "Error: Log command is required (status, rotate, clean, config)"
    echo "Usage: $0 --logs COMMAND [ARGS]"
    return 1
  fi

  case "$command" in
  status)
    logrotate_main status
    return $?
    ;;

  rotate)
    logrotate_main rotate
    return $?
    ;;

  clean)
    logrotate_main clean
    return $?
    ;;

  config)
    local param_name="$2"
    local param_value="$3"

    if [ -z "$param_name" ] || [ -z "$param_value" ]; then
      echo "Error: Parameter name and value required"
      echo "Usage: $0 --logs config <parameter> <value>"
      echo "Parameters: max_size_mb, max_age_days, max_files, compress, rotate_on_start"
      return 1
    fi

    logrotate_main config "$param_name" "$param_value"
    return $?
    ;;

  *)
    echo "Unknown log command: $command"
    echo "Available commands: status, rotate, clean, config"
    return 1
    ;;
  esac
}
