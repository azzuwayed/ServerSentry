#!/bin/bash
#
# ServerSentry - Periodic report commands
# Handles periodic report execution and configuration

# Get the project root directory (two levels up from this file)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" &>/dev/null && pwd)"

# Source required modules
source "$PROJECT_ROOT/lib/cli/utils.sh"
source "$PROJECT_ROOT/lib/utils/utils.sh"
source "$PROJECT_ROOT/lib/monitor/periodic.sh"

# Handle periodic report commands
cli_periodic() {
  local command="$1"

  if [ -z "$command" ]; then
    echo "Error: Periodic command is required (run, status, config)"
    echo "Usage: $0 --periodic COMMAND [ARGS]"
    return 1
  fi

  case "$command" in
  run)
    periodic_main run
    return $?
    ;;

  status)
    periodic_main status
    return $?
    ;;

  config)
    local param_name="$2"
    local param_value="$3"

    if [ -z "$param_name" ] || [ -z "$param_value" ]; then
      echo "Error: Parameter name and value required"
      echo "Usage: $0 --periodic config <parameter> <value>"
      echo "Parameters: report_interval, report_level, report_checks, force_report, report_time, report_days"
      return 1
    fi

    periodic_main config "$param_name" "$param_value"
    return $?
    ;;

  *)
    echo "Unknown periodic command: $command"
    echo "Available commands: run, status, config"
    return 1
    ;;
  esac
}
