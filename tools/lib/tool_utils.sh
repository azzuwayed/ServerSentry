#!/usr/bin/env bash
#
# ServerSentry Tools - Shared Utilities
#
# Common utility functions used across multiple tools to eliminate duplication

# Prevent multiple sourcing
if [[ "${TOOL_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
TOOL_UTILS_LOADED=true
export TOOL_UTILS_LOADED

# =============================================================================
# COMMON TOOL FUNCTIONS
# =============================================================================

# Function: show_usage
# Description: Display usage information for a tool
# Parameters:
#   $1 (string): tool name
#   $2 (string): usage text
# Returns: None
show_usage() {
  local tool_name="$1"
  local usage_text="$2"

  echo "Usage: $tool_name $usage_text"
  echo ""
  echo "For more information, see the documentation or use --help"
}

# Function: parse_arguments
# Description: Parse common command line arguments
# Parameters:
#   $@ (strings): command line arguments
# Returns: Sets global variables for parsed options
parse_arguments() {
  # Initialize default values
  VERBOSE=false
  QUIET=false
  DRY_RUN=false
  HELP=false

  while [[ $# -gt 0 ]]; do
    case $1 in
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -q | --quiet)
      QUIET=true
      shift
      ;;
    -n | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      HELP=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    *)
      break
      ;;
    esac
  done

  # Export parsed options
  export VERBOSE QUIET DRY_RUN HELP

  # Return remaining arguments
  return 0
}

# Function: validate_dependencies
# Description: Validate that required commands are available
# Parameters:
#   $@ (strings): list of required commands
# Returns: 0 if all dependencies are met, 1 otherwise
validate_dependencies() {
  local missing_deps=()

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies:" >&2
    printf "  %s\n" "${missing_deps[@]}" >&2
    return 1
  fi

  return 0
}

# Function: is_excluded
# Description: Check if a file should be excluded based on patterns
# Parameters:
#   $1 (string): file path
#   $2 (array): exclusion patterns
# Returns: 0 if excluded, 1 if not excluded
is_excluded() {
  local file_path="$1"
  shift
  local exclusion_patterns=("$@")

  for pattern in "${exclusion_patterns[@]}"; do
    if [[ "$file_path" == $pattern ]]; then
      return 0
    fi
  done

  return 1
}

# Function: find_bash_files
# Description: Find bash script files in a directory
# Parameters:
#   $1 (string): directory to search
#   $2 (array): exclusion patterns (optional)
# Returns: List of bash files via stdout
find_bash_files() {
  local search_dir="${1:-.}"
  shift
  local exclusion_patterns=("$@")

  # Find all .sh files and files with bash shebang
  {
    find "$search_dir" -name "*.sh" -type f 2>/dev/null
    find "$search_dir" -type f -exec grep -l "^#!/.*bash" {} \; 2>/dev/null
  } | sort -u | while read -r file; do
    if ! is_excluded "$file" "${exclusion_patterns[@]}"; then
      echo "$file"
    fi
  done
}

# Function: log_message
# Description: Log a message with appropriate level
# Parameters:
#   $1 (string): log level (INFO, WARN, ERROR, DEBUG)
#   $2 (string): message
# Returns: None
log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Check if we should output based on verbosity settings
  case "$level" in
  DEBUG)
    [[ "${VERBOSE:-false}" == "true" ]] || return 0
    ;;
  INFO)
    [[ "${QUIET:-false}" == "true" ]] && return 0
    ;;
  WARN | ERROR)
    # Always show warnings and errors
    ;;
  esac

  # Color output if supported
  local color=""
  local reset=""
  if [[ -t 2 ]] && command -v tput >/dev/null 2>&1; then
    case "$level" in
    DEBUG) color="$(tput setaf 6)" ;; # Cyan
    INFO) color="$(tput setaf 2)" ;;  # Green
    WARN) color="$(tput setaf 3)" ;;  # Yellow
    ERROR) color="$(tput setaf 1)" ;; # Red
    esac
    reset="$(tput sgr0)"
  fi

  echo "${color}[$timestamp] [$level] $message${reset}" >&2
}

# Function: create_backup
# Description: Create a backup of a file
# Parameters:
#   $1 (string): file path
#   $2 (string): backup suffix (optional, defaults to .bak)
# Returns: 0 on success, 1 on failure
create_backup() {
  local file_path="$1"
  local backup_suffix="${2:-.bak}"
  local backup_path="${file_path}${backup_suffix}"

  if [[ ! -f "$file_path" ]]; then
    log_message "ERROR" "File not found: $file_path"
    return 1
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_message "INFO" "DRY RUN: Would create backup: $backup_path"
    return 0
  fi

  if cp "$file_path" "$backup_path"; then
    log_message "DEBUG" "Created backup: $backup_path"
    return 0
  else
    log_message "ERROR" "Failed to create backup: $backup_path"
    return 1
  fi
}

# Function: restore_backup
# Description: Restore a file from backup
# Parameters:
#   $1 (string): original file path
#   $2 (string): backup suffix (optional, defaults to .bak)
# Returns: 0 on success, 1 on failure
restore_backup() {
  local file_path="$1"
  local backup_suffix="${2:-.bak}"
  local backup_path="${file_path}${backup_suffix}"

  if [[ ! -f "$backup_path" ]]; then
    log_message "ERROR" "Backup not found: $backup_path"
    return 1
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_message "INFO" "DRY RUN: Would restore from backup: $backup_path"
    return 0
  fi

  if mv "$backup_path" "$file_path"; then
    log_message "DEBUG" "Restored from backup: $backup_path"
    return 0
  else
    log_message "ERROR" "Failed to restore from backup: $backup_path"
    return 1
  fi
}

# Function: cleanup_backups
# Description: Clean up backup files
# Parameters:
#   $1 (string): directory to clean
#   $2 (string): backup suffix (optional, defaults to .bak)
# Returns: 0 on success
cleanup_backups() {
  local search_dir="${1:-.}"
  local backup_suffix="${2:-.bak}"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_message "INFO" "DRY RUN: Would clean up backup files with suffix: $backup_suffix"
    find "$search_dir" -name "*$backup_suffix" -type f 2>/dev/null | while read -r backup; do
      log_message "INFO" "DRY RUN: Would remove: $backup"
    done
    return 0
  fi

  local count=0
  find "$search_dir" -name "*$backup_suffix" -type f 2>/dev/null | while read -r backup; do
    if rm "$backup"; then
      log_message "DEBUG" "Removed backup: $backup"
      ((count++))
    else
      log_message "WARN" "Failed to remove backup: $backup"
    fi
  done

  log_message "INFO" "Cleaned up $count backup files"
  return 0
}

# Function: confirm_action
# Description: Ask user for confirmation
# Parameters:
#   $1 (string): prompt message
# Returns: 0 if confirmed, 1 if not confirmed
confirm_action() {
  local prompt="$1"

  # Skip confirmation in quiet mode or if not interactive
  if [[ "${QUIET:-false}" == "true" ]] || [[ ! -t 0 ]]; then
    return 0
  fi

  echo -n "$prompt (y/N): " >&2
  read -r response

  case "$response" in
  [yY] | [yY][eE][sS])
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

# Function: get_file_count
# Description: Get count of files matching a pattern
# Parameters:
#   $1 (string): directory
#   $2 (string): pattern
# Returns: Count via stdout
get_file_count() {
  local directory="$1"
  local pattern="$2"

  find "$directory" -name "$pattern" -type f 2>/dev/null | wc -l
}

# Function: format_duration
# Description: Format duration in seconds to human readable format
# Parameters:
#   $1 (numeric): duration in seconds
# Returns: Formatted duration via stdout
format_duration() {
  local duration="$1"

  if [[ "$duration" -lt 60 ]]; then
    echo "${duration}s"
  elif [[ "$duration" -lt 3600 ]]; then
    echo "$((duration / 60))m $((duration % 60))s"
  else
    echo "$((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"
  fi
}

# Function: get_script_dir
# Description: Get the directory containing the current script
# Parameters: None
# Returns: Script directory via stdout
get_script_dir() {
  local script_path="${BASH_SOURCE[1]}"
  cd "$(dirname "$script_path")" && pwd
}

# Function: get_project_root
# Description: Find the project root directory
# Parameters: None
# Returns: Project root directory via stdout
get_project_root() {
  local current_dir
  current_dir="$(get_script_dir)"

  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Fallback to current directory
  pwd
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export all utility functions
export -f show_usage parse_arguments validate_dependencies is_excluded find_bash_files
export -f log_message create_backup restore_backup cleanup_backups confirm_action
export -f get_file_count format_duration get_script_dir get_project_root

# Export variables that may be set by parse_arguments
export VERBOSE QUIET DRY_RUN HELP TOOL_UTILS_LOADED
