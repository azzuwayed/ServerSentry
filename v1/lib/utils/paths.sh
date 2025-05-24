#!/bin/bash
#
# ServerSentry - Path handling utilities
# This module provides consistent path resolution functions

# Determine the absolute path to the project root directory
get_project_root() {
  # If already defined, return it
  if [ -n "${SERVERSENTRY_ROOT:-}" ]; then
    echo "$SERVERSENTRY_ROOT"
    return 0
  fi

  # Otherwise, calculate it
  # This should work regardless of which script is calling this function
  local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  local project_root="$(cd "$script_path/../.." &>/dev/null && pwd)"

  # Cache it for future calls
  export SERVERSENTRY_ROOT="$project_root"
  echo "$project_root"
}

# Get the path to a specific directory
get_dir_path() {
  local dir_name="$1"
  local root_dir="$(get_project_root)"

  case "$dir_name" in
  "lib")
    echo "$root_dir/lib"
    ;;
  "config")
    echo "$root_dir/config"
    ;;
  "logs")
    echo "$root_dir/logs"
    ;;
  *)
    echo "$root_dir/$dir_name"
    ;;
  esac
}

# Get the path to a specific file
get_file_path() {
  local file_type="$1"
  local root_dir="$(get_project_root)"

  # Use HOME directory as fallback for logs if needed
  if [ "$file_type" = "log" ]; then
    # First try in the project root
    if [ -w "$root_dir" ] || [ -w "$root_dir/serversentry.log" ] 2>/dev/null; then
      echo "$root_dir/serversentry.log"
      return 0
    else
      # Use home directory as fallback
      local home_log_dir="$HOME/.serversentry"
      if [ ! -d "$home_log_dir" ]; then
        mkdir -p "$home_log_dir" 2>/dev/null || {
          echo "Error: Failed to create log directory: $home_log_dir" >&2
          return 1
        }
      fi
      echo "$home_log_dir/serversentry.log"
      return 0
    fi
  fi

  # For other file types, use normal paths
  case "$file_type" in
  "thresholds")
    echo "$root_dir/config/thresholds.conf"
    ;;
  "webhooks")
    echo "$root_dir/config/webhooks.conf"
    ;;
  "logrotate")
    echo "$root_dir/config/logrotate.conf"
    ;;
  "periodic")
    echo "$root_dir/config/periodic.conf"
    ;;
  *)
    echo "$root_dir/$file_type"
    ;;
  esac
}

# Ensure a directory exists
ensure_dir_exists() {
  local dir_path="$1"

  if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path" || {
      echo "Error: Failed to create directory: $dir_path" >&2
      return 1
    }
  fi
  return 0
}

# Get a unique temporary file path
get_temp_file_path() {
  local prefix="${1:-serversentry}"
  mktemp "/tmp/${prefix}.XXXXXX"
}
