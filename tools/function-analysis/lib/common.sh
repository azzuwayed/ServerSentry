#!/usr/bin/env bash
#
# ServerSentry Function Analysis - Common Library
#
# This module provides shared functionality for function analysis tools

# Prevent multiple sourcing
if [[ "${FUNCTION_ANALYSIS_COMMON_LOADED:-}" == "true" ]]; then
  return 0
fi
FUNCTION_ANALYSIS_COMMON_LOADED=true
export FUNCTION_ANALYSIS_COMMON_LOADED

# Load ServerSentry environment bootstrap
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Find and source the bootstrap file
  bootstrap_file=""
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Search upward for serversentry-env.sh
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      bootstrap_file="$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  if [[ -n "$bootstrap_file" ]]; then
    # shellcheck source=/dev/null
    source "$bootstrap_file" || {
      echo "❌ ERROR: Failed to load ServerSentry environment bootstrap" >&2
      exit 1
    }
  else
    echo "❌ ERROR: Could not find serversentry-env.sh bootstrap file" >&2
    echo "   Please ensure you're running from within the ServerSentry project" >&2
    exit 1
  fi
fi

# Configuration using centralized paths
readonly LOGS_DIR="${SERVERSENTRY_TOOLS_DIR}/function-analysis/logs"
readonly WORKSPACE_ROOT="$SERVERSENTRY_ROOT"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Function: analysis_init
# Description: Initialize the analysis environment
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   analysis_init
# Dependencies: None
analysis_init() {
  # Create logs directory if it doesn't exist
  if ! mkdir -p "$LOGS_DIR"; then
    echo -e "${RED}❌ Failed to create logs directory: $LOGS_DIR${NC}" >&2
    return 1
  fi

  # Verify workspace root exists
  if [[ ! -d "$WORKSPACE_ROOT" ]]; then
    echo -e "${RED}❌ Workspace root not found: $WORKSPACE_ROOT${NC}" >&2
    return 1
  fi

  return 0
}

# Function: analysis_log
# Description: Standardized logging for analysis tools
# Parameters:
#   $1 (string): log level (INFO, WARN, ERROR, SUCCESS)
#   $2 (string): message
# Returns:
#   0 - success
# Example:
#   analysis_log "INFO" "Starting analysis"
# Dependencies: None
analysis_log() {
  if [[ $# -ne 2 ]]; then
    echo -e "${RED}❌ analysis_log requires exactly 2 parameters${NC}" >&2
    return 1
  fi

  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  case "$level" in
  "INFO")
    echo -e "${BLUE}ℹ️  [$timestamp] $message${NC}"
    ;;
  "WARN")
    echo -e "${YELLOW}⚠️  [$timestamp] $message${NC}"
    ;;
  "ERROR")
    echo -e "${RED}❌ [$timestamp] $message${NC}" >&2
    ;;
  "SUCCESS")
    echo -e "${GREEN}✅ [$timestamp] $message${NC}"
    ;;
  *)
    echo -e "${PURPLE}📝 [$timestamp] $message${NC}"
    ;;
  esac
}

# Function: analysis_find_shell_scripts
# Description: Find shell scripts in specified directory with validation
# Parameters:
#   $1 (string): directory path (optional, defaults to workspace root)
#   $2 (string): pattern filter (optional, defaults to "*.sh")
# Returns:
#   Shell script paths via stdout
# Example:
#   scripts=$(analysis_find_shell_scripts "lib" "*.sh")
# Dependencies:
#   - analysis_log
analysis_find_shell_scripts() {
  local search_dir="${1:-$WORKSPACE_ROOT}"
  local pattern="${2:-*.sh}"

  # Validate directory exists
  if [[ ! -d "$search_dir" ]]; then
    analysis_log "ERROR" "Directory not found: $search_dir"
    return 1
  fi

  # Find shell scripts
  local scripts
  if ! scripts=$(find "$search_dir" -name "$pattern" -type f 2>/dev/null | sort); then
    analysis_log "ERROR" "Failed to find shell scripts in: $search_dir"
    return 1
  fi

  if [[ -z "$scripts" ]]; then
    analysis_log "WARN" "No shell scripts found in: $search_dir"
    return 1
  fi

  echo "$scripts"
}

# Function: analysis_extract_functions
# Description: Extract function definitions from a shell script
# Parameters:
#   $1 (string): file path
# Returns:
#   Function definitions via stdout (format: name|line|type)
# Example:
#   functions=$(analysis_extract_functions "script.sh")
# Dependencies:
#   - analysis_log
analysis_extract_functions() {
  if [[ $# -ne 1 ]]; then
    analysis_log "ERROR" "analysis_extract_functions requires exactly 1 parameter"
    return 1
  fi

  local file="$1"

  # Validate file exists and is readable
  if [[ ! -f "$file" ]]; then
    analysis_log "ERROR" "File not found: $file"
    return 1
  fi

  if [[ ! -r "$file" ]]; then
    analysis_log "ERROR" "File not readable: $file"
    return 1
  fi

  # Extract function definitions using optimized patterns
  {
    # Pattern 1: function_name() {
    grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*()[[:space:]]*{" "$file" 2>/dev/null |
      sed 's/^\([0-9]*\):[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\)().*/\2|\1|standard/'

    # Pattern 2: function function_name() {
    grep -n "^[[:space:]]*function[[:space:]]\+[a-zA-Z_][a-zA-Z0-9_]*()[[:space:]]*{" "$file" 2>/dev/null |
      sed 's/^\([0-9]*\):[[:space:]]*function[[:space:]]\+\([a-zA-Z_][a-zA-Z0-9_]*\)().*/\2|\1|function_keyword/'

    # Pattern 3: function function_name {
    grep -n "^[[:space:]]*function[[:space:]]\+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*{" "$file" 2>/dev/null |
      sed 's/^\([0-9]*\):[[:space:]]*function[[:space:]]\+\([a-zA-Z_][a-zA-Z0-9_]*\)[[:space:]]*{.*/\2|\1|function_no_parens/'
  } | sort -t'|' -k2,2n
}

# Function: analysis_categorize_function
# Description: Categorize a function based on naming patterns
# Parameters:
#   $1 (string): function name
# Returns:
#   Category name via stdout
# Example:
#   category=$(analysis_categorize_function "util_validate_input")
# Dependencies: None
analysis_categorize_function() {
  if [[ $# -ne 1 ]]; then
    echo "uncategorized"
    return 1
  fi

  local func_name="$1"

  # Core system functions
  if [[ "$func_name" =~ ^(util_|system_|core_|base_) ]]; then
    echo "utility"
  elif [[ "$func_name" =~ ^(config_|configuration_) ]]; then
    echo "configuration"
  elif [[ "$func_name" =~ ^(log_|logging_) ]]; then
    echo "logging"
  elif [[ "$func_name" =~ ^(error_|err_) ]]; then
    echo "error_handling"

  # Validation and checking
  elif [[ "$func_name" =~ ^(validate_|check_|verify_) ]]; then
    echo "validation"
  elif [[ "$func_name" =~ ^(test_|testing_) ]]; then
    echo "testing"

  # Data operations
  elif [[ "$func_name" =~ ^(get_|fetch_|retrieve_) ]]; then
    echo "data_retrieval"
  elif [[ "$func_name" =~ ^(set_|update_|modify_) ]]; then
    echo "data_modification"
  elif [[ "$func_name" =~ ^(create_|generate_|build_) ]]; then
    echo "creation"
  elif [[ "$func_name" =~ ^(parse_|format_|transform_) ]]; then
    echo "data_processing"

  # System operations
  elif [[ "$func_name" =~ ^(init_|initialize_|setup_) ]]; then
    echo "initialization"
  elif [[ "$func_name" =~ ^(cleanup_|clean_|remove_) ]]; then
    echo "cleanup"
  elif [[ "$func_name" =~ ^(monitor_|track_|watch_) ]]; then
    echo "monitoring"

  # Plugin and notification systems
  elif [[ "$func_name" =~ ^(plugin_|addon_|extension_) ]]; then
    echo "plugin_system"
  elif [[ "$func_name" =~ ^(notification_|notify_|alert_) ]]; then
    echo "notification"
  elif [[ "$func_name" =~ ^(send_|transmit_|deliver_) ]]; then
    echo "communication"

  # UI and interaction
  elif [[ "$func_name" =~ ^(ui_|tui_|cli_|interface_) ]]; then
    echo "user_interface"
  elif [[ "$func_name" =~ ^(print_|display_|show_|render_) ]]; then
    echo "output"
  elif [[ "$func_name" =~ ^(input_|prompt_|read_) ]]; then
    echo "input"

  # File operations
  elif [[ "$func_name" =~ ^(file_|io_|read_|write_) ]]; then
    echo "file_operations"
  elif [[ "$func_name" =~ ^(load_|save_|store_) ]]; then
    echo "persistence"

  # ServerSentry specific
  elif [[ "$func_name" =~ ^(anomaly_|detect_|detection_) ]]; then
    echo "anomaly_detection"
  elif [[ "$func_name" =~ ^(composite_|combine_|merge_) ]]; then
    echo "composite_operations"
  elif [[ "$func_name" =~ ^(diagnostic_|health_) ]]; then
    echo "diagnostics"

  # Internal/private functions
  elif [[ "$func_name" =~ ^_ ]]; then
    echo "internal"

  # Default
  else
    echo "uncategorized"
  fi
}

# Function: analysis_generate_timestamp
# Description: Generate standardized timestamp for reports
# Parameters: None
# Returns:
#   Timestamp string via stdout
# Example:
#   timestamp=$(analysis_generate_timestamp)
# Dependencies: None
analysis_generate_timestamp() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS date command
    date -u '+%Y-%m-%d %H:%M:%S UTC'
  else
    # Linux date command
    date '+%Y-%m-%d %H:%M:%S UTC' -u
  fi
}

# Function: analysis_get_relative_path
# Description: Get relative path from workspace root
# Parameters:
#   $1 (string): absolute file path
# Returns:
#   Relative path via stdout
# Example:
#   rel_path=$(analysis_get_relative_path "/full/path/to/file.sh")
# Dependencies: None
analysis_get_relative_path() {
  if [[ $# -ne 1 ]]; then
    echo "$1"
    return 1
  fi

  local file_path="$1"
  echo "${file_path#"$WORKSPACE_ROOT"/}"
}

# Function: analysis_validate_output_file
# Description: Validate and prepare output file
# Parameters:
#   $1 (string): output file path
# Returns:
#   0 - success
#   1 - failure
# Example:
#   analysis_validate_output_file "$output_file"
# Dependencies:
#   - analysis_log
analysis_validate_output_file() {
  if [[ $# -ne 1 ]]; then
    analysis_log "ERROR" "analysis_validate_output_file requires exactly 1 parameter"
    return 1
  fi

  local output_file="$1"
  local output_dir
  output_dir=$(dirname "$output_file")

  # Create directory if it doesn't exist
  if ! mkdir -p "$output_dir"; then
    analysis_log "ERROR" "Failed to create output directory: $output_dir"
    return 1
  fi

  # Clear existing file
  if ! >"$output_file"; then
    analysis_log "ERROR" "Failed to create/clear output file: $output_file"
    return 1
  fi

  return 0
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f analysis_init
  export -f analysis_log
  export -f analysis_find_shell_scripts
  export -f analysis_extract_functions
  export -f analysis_categorize_function
  export -f analysis_generate_timestamp
  export -f analysis_get_relative_path
  export -f analysis_validate_output_file
fi
