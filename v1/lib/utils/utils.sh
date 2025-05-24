#!/bin/bash
#
# ServerSentry - Utility functions (merged and improved)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source the paths module
source "$SCRIPT_DIR/paths.sh"

# Get the root script directory and log file path using path utilities
ROOT_DIR="$(get_project_root)"

# Get the log file path (use environment variable if set)
if [ -n "${SERVERSENTRY_LOG_FILE:-}" ]; then
    LOG_FILE="$SERVERSENTRY_LOG_FILE"
else
    LOG_FILE="$(get_file_path "log")"
fi

# Logging function (robust)
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
    if [ "$level" == "ERROR" ] || [ "$level" == "WARNING" ]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get the log directory path
get_log_dir() {
    local log_file_path="$(get_file_path "log")"
    dirname "$log_file_path"
}

# Create a directory if it doesn't exist
ensure_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_message "ERROR" "Failed to create directory: $dir"
            return 1
        }
    fi
    return 0
}

# Check if a file exists
file_exists() {
    [ -f "$1" ]
}

# Check if a string is a valid number (portable)
is_number() {
    case "$1" in
    '' | *[!0-9.]* | *.*.*) return 1 ;;
    *) return 0 ;;
    esac
}

# Check if a string is a valid URL (portable)
is_valid_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Print a horizontal line (portable)
print_line() {
    local cols=80
    if command_exists tput; then
        cols=$(tput cols 2>/dev/null || echo 80)
    fi
    printf '%*s\n' "$cols" '' | tr ' ' '-'
}

# Format bytes to human-readable form
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0
    while [ "$bytes" -ge 1024 ] && [ $unit_index -lt 4 ]; do
        bytes=$((bytes / 1024))
        ((unit_index++))
    done
    echo "$bytes ${units[$unit_index]}"
}

# Get timestamp in a standardized format
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Note: Log rotation is now handled by lib/logrotate.sh
