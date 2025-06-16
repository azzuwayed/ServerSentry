#!/usr/bin/env bash
#
# Example ServerSentry Script
#
# This demonstrates how to properly use the ServerSentry environment bootstrap

set -euo pipefail

# =============================================================================
# LOAD SERVERSENTRY ENVIRONMENT (Required for all scripts)
# =============================================================================

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
# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION="1.0.0"

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

# Function: show_usage
# Description: Display usage information
# Parameters: None
# Returns: None
show_usage() {
  cat <<EOF
📋 Example ServerSentry Script v${VERSION}

This script demonstrates proper use of the ServerSentry environment bootstrap.

USAGE:
  $SCRIPT_NAME [OPTIONS]

OPTIONS:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -t, --test     Run environment tests

EXAMPLES:
  $SCRIPT_NAME              # Show environment info
  $SCRIPT_NAME --test       # Test environment
  $SCRIPT_NAME --verbose    # Verbose output

EOF
}

# Function: show_environment_info
# Description: Display ServerSentry environment information
# Parameters: None
# Returns: None
show_environment_info() {
  serversentry_log "INFO" "ServerSentry Environment Information"
  echo ""
  echo "🏠 Root Directory: $SERVERSENTRY_ROOT"
  echo "📚 Library Directory: $SERVERSENTRY_LIB_DIR"
  echo "⚙️  Core Directory: $SERVERSENTRY_CORE_DIR"
  echo "🔧 Tools Directory: $SERVERSENTRY_TOOLS_DIR"
  echo "📝 Logs Directory: $SERVERSENTRY_LOGS_DIR"
  echo "📄 Config Directory: $SERVERSENTRY_CONFIG_DIR"
  echo ""

  # Show available utilities
  echo "🛠️  Available Utilities:"
  echo "  • serversentry_log() - Centralized logging"
  echo "  • serversentry_resolve_path() - Path resolution"
  echo "  • serversentry_find_script() - Script discovery"
  echo "  • serversentry_load_module() - Module loading"
  echo "  • serversentry_load_utility() - Utility loading"
  echo ""
}

# Function: test_environment
# Description: Test the ServerSentry environment
# Parameters: None
# Returns: 0 on success, 1 on failure
test_environment() {
  serversentry_log "INFO" "Testing ServerSentry environment..."

  # Test path resolution
  local test_path
  test_path=$(serversentry_resolve_path "lib/core")
  if [[ "$test_path" == "$SERVERSENTRY_CORE_DIR" ]]; then
    serversentry_log "SUCCESS" "Path resolution test passed"
  else
    serversentry_log "ERROR" "Path resolution test failed"
    return 1
  fi

  # Test relative path
  local rel_path
  rel_path=$(serversentry_get_relative_path "$SERVERSENTRY_CORE_DIR")
  if [[ "$rel_path" == "lib/core" ]]; then
    serversentry_log "SUCCESS" "Relative path test passed"
  else
    serversentry_log "ERROR" "Relative path test failed"
    return 1
  fi

  # Test script finding
  local found_script
  found_script=$(serversentry_find_script "serversentry-env.sh")
  if [[ -n "$found_script" ]]; then
    serversentry_log "SUCCESS" "Script finding test passed"
  else
    serversentry_log "ERROR" "Script finding test failed"
    return 1
  fi

  # Test environment validation
  if serversentry_validate_environment; then
    serversentry_log "SUCCESS" "Environment validation test passed"
  else
    serversentry_log "ERROR" "Environment validation test failed"
    return 1
  fi

  serversentry_log "SUCCESS" "All environment tests passed!"
  return 0
}

# Function: main
# Description: Main entry point
# Parameters: Command line arguments
# Returns: 0 on success, 1 on failure
main() {
  local verbose=false
  local run_test=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      show_usage
      exit 0
      ;;
    -v | --verbose)
      verbose=true
      shift
      ;;
    -t | --test)
      run_test=true
      shift
      ;;
    *)
      serversentry_log "ERROR" "Unknown option: $1"
      show_usage
      exit 1
      ;;
    esac
  done

  # Show header
  echo "🚀 Example ServerSentry Script v${VERSION}"
  echo "=========================================="
  echo ""

  if [[ "$run_test" == "true" ]]; then
    # Run environment tests
    if ! test_environment; then
      exit 1
    fi
  else
    # Show environment information
    show_environment_info
  fi

  if [[ "$verbose" == "true" ]]; then
    echo ""
    serversentry_log "INFO" "Verbose mode enabled"
    echo "📋 Script executed from: $(pwd)"
    echo "📋 Script path: ${BASH_SOURCE[0]}"
    echo "📋 Environment loaded: $SERVERSENTRY_ENV_LOADED"
  fi

  serversentry_log "SUCCESS" "Script completed successfully!"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
