#!/usr/bin/env bash
#
# ServerSentry CLI - Composite Commands
#
# Focused module for composite check management commands

# Prevent multiple sourcing
if [[ "${CLI_COMPOSITE_COMMANDS_LOADED:-}" == "true" ]]; then
  return 0
fi
CLI_COMPOSITE_COMMANDS_LOADED=true
export CLI_COMPOSITE_COMMANDS_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi

# Function: cmd_composite
# Description: Handle composite check management commands
# Parameters:
#   $1 (string): subcommand (list, test, enable, disable, create)
#   $@ (strings): additional arguments
cmd_composite() {
  local subcommand="$1"
  shift

  # Source the composite system
  if [[ -f "${SERVERSENTRY_CORE_DIR}/composite.sh" ]]; then
    source "${SERVERSENTRY_CORE_DIR}/composite.sh"
    init_composite_system
  else
    print_error "Composite check system not available"
    return 1
  fi

  case "$subcommand" in
  list)
    list_composite_checks
    ;;
  test)
    local check_name="$1"
    print_info "Testing composite checks..."

    # Get current plugin results
    local plugin_results
    plugin_results=$(run_all_plugin_checks)

    if [[ -n "$check_name" ]]; then
      # Test specific composite check
      local config_file="${COMPOSITE_CONFIG_DIR}/${check_name}.conf"
      if [[ -f "$config_file" ]]; then
        print_info "Running composite check: $check_name"
        run_composite_check "$config_file" "$plugin_results" | jq
      else
        print_error "Composite check not found: $check_name"
        echo "Available checks:"
        list_composite_checks
        return 1
      fi
    else
      # Test all composite checks
      print_info "Running all composite checks..."
      run_all_composite_checks "$plugin_results" | jq
    fi
    ;;
  enable)
    local check_name="$1"
    if [[ -z "$check_name" ]]; then
      print_error "Usage: serversentry composite enable <check_name>"
      return 1
    fi

    local config_file="${COMPOSITE_CONFIG_DIR}/${check_name}.conf"
    if [[ -f "$config_file" ]]; then
      # Enable the check by updating the config file
      sed -i.bak 's/enabled=false/enabled=true/' "$config_file"
      print_success "Enabled composite check: $check_name"
    else
      print_error "Composite check not found: $check_name"
      return 1
    fi
    ;;
  disable)
    local check_name="$1"
    if [[ -z "$check_name" ]]; then
      print_error "Usage: serversentry composite disable <check_name>"
      return 1
    fi

    local config_file="${COMPOSITE_CONFIG_DIR}/${check_name}.conf"
    if [[ -f "$config_file" ]]; then
      # Disable the check by updating the config file
      sed -i.bak 's/enabled=true/enabled=false/' "$config_file"
      print_success "Disabled composite check: $check_name"
    else
      print_error "Composite check not found: $check_name"
      return 1
    fi
    ;;
  create)
    local check_name="$1"
    local rule="$2"
    if [[ -z "$check_name" || -z "$rule" ]]; then
      print_error "Usage: serversentry composite create <check_name> \"<rule>\""
      echo "Example: serversentry composite create my_check \"cpu.value > 80 AND memory.value > 85\""
      return 1
    fi

    local config_file="${COMPOSITE_CONFIG_DIR}/${check_name}.conf"
    if [[ -f "$config_file" ]]; then
      print_error "Composite check already exists: $check_name"
      return 1
    fi

    # Create new composite check
    cat >"$config_file" <<EOF
# Custom Composite Check: $check_name
name="$check_name"
description="Custom composite check created via CLI"
enabled=true
severity=1
cooldown=300

# Rule: $rule
rule="$rule"

# Notification settings
notify_on_trigger=true
notify_on_recovery=false
notification_message="Composite check triggered: $check_name - {triggered_conditions}"
EOF

    print_success "Created composite check: $check_name"
    print_info "Config file: $config_file"
    ;;
  *)
    print_error "Usage: serversentry composite [list|test|enable|disable|create] ..."
    echo ""
    echo "Commands:"
    echo "  list                        List all composite checks"
    echo "  test [check_name]           Test composite checks (all or specific)"
    echo "  enable <check_name>         Enable a composite check"
    echo "  disable <check_name>        Disable a composite check"
    echo "  create <name> \"<rule>\"      Create a new composite check"
    echo ""
    echo "Rule Examples:"
    echo "  \"cpu.value > 80 AND memory.value > 85\""
    echo "  \"(cpu.value > 90 OR memory.value > 95) AND disk.value > 90\""
    echo "  \"cpu.value > 95 OR memory.value > 98 OR disk.value > 95\""
    return 1
    ;;
  esac
}

# Export the function
export -f cmd_composite
