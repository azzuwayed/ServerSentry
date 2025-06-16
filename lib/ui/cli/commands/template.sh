#!/usr/bin/env bash
#
# ServerSentry CLI - Template Commands
#
# Focused module for template management commands

# Prevent multiple sourcing
if [[ "${CLI_TEMPLATE_COMMANDS_LOADED:-}" == "true" ]]; then
  return 0
fi
CLI_TEMPLATE_COMMANDS_LOADED=true
export CLI_TEMPLATE_COMMANDS_LOADED

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

# Function: cmd_template
# Description: Handle template management commands
# Parameters:
#   $1 (string): subcommand (list, validate, test, create)
#   $@ (strings): additional arguments
cmd_template() {
  local subcommand="$1"
  shift

  # Source the template system
  if [[ -f "${SERVERSENTRY_CORE_DIR}/templates.sh" ]]; then
    source "${SERVERSENTRY_CORE_DIR}/templates.sh"
    init_template_system
  else
    print_error "Template system not available"
    return 1
  fi

  case "$subcommand" in
  list)
    list_templates
    ;;
  validate)
    local template_file="$1"
    if [[ -z "$template_file" ]]; then
      print_error "Usage: serversentry template validate <template_file>"
      return 1
    fi
    validate_template "$template_file"
    ;;
  test)
    local provider="${1:-webhook}"
    local notification_type="${2:-test}"
    print_info "Testing template for provider='$provider' type='$notification_type'..."

    local content
    content=$(generate_notification_content "$notification_type" "$provider" 0 "Test notification message" "test" '{"test": true}')

    if [[ $? -eq 0 ]]; then
      print_success "Template test successful"
      echo ""
      echo "Generated content:"
      print_separator
      echo "$content"
    else
      print_error "Template test failed"
      return 1
    fi
    ;;
  create)
    local template_name="$1"
    local provider="$2"
    if [[ -z "$template_name" || -z "$provider" ]]; then
      print_error "Usage: serversentry template create <name> <provider>"
      echo "Example: serversentry template create my_alert teams"
      return 1
    fi

    local template_file="${TEMPLATE_DIR}/${provider}_${template_name}.template"
    mkdir -p "$(dirname "$template_file")"

    if [[ -f "$template_file" ]]; then
      print_error "Template already exists: $template_file"
      return 1
    fi

    # Create a basic template
    cat >"$template_file" <<'EOF'
{status_text} Alert from {hostname}

Message: {status_message}
Plugin: {plugin_name}
Time: {timestamp}

Metrics: {metrics}

---
ServerSentry v2
EOF

    print_success "Created template: $template_file"
    print_info "Edit this file to customize your template."
    ;;
  *)
    print_error "Usage: serversentry template [list|validate|test|create] ..."
    echo ""
    echo "Commands:"
    echo "  list                     List all available templates"
    echo "  validate <file>          Validate a template file"
    echo "  test [provider] [type]   Test template generation (default: webhook test)"
    echo "  create <name> <provider> Create a new custom template"
    return 1
    ;;
  esac
}

# Export the function
export -f cmd_template
