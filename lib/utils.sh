#!/bin/bash
#
# ServerSentry - Utility functions (merged and improved)

# Get the root script directory (one level up from lib)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$SCRIPT_DIR/sysmon.log"

# Logging function (robust)
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [ "$level" == "ERROR" ] || [ "$level" == "WARNING" ]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
        ''|*[!0-9.]*|*.*.*) return 1;;
        *) return 0;;
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
        bytes=$(( bytes / 1024 ))
        ((unit_index++))
    done
    echo "$bytes ${units[$unit_index]}"
}

# Get timestamp in a standardized format
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Clean up old log files (cross-platform)
rotate_logs() {
    local size=0
    if [ -f "$LOG_FILE" ]; then
        if command_exists stat; then
            size=$(stat -c %s "$LOG_FILE" 2>/dev/null || stat -f %z "$LOG_FILE" 2>/dev/null || echo 0)
        fi
        if [ "$size" -gt 10485760 ]; then  # 10MB
            local timestamp=$(date "+%Y%m%d%H%M%S")
            mv "$LOG_FILE" "${LOG_FILE}.${timestamp}"
            touch "$LOG_FILE"
            log_message "INFO" "Log file rotated to ${LOG_FILE}.${timestamp}"
            # Keep only the 5 most recent log files
            ls -t "${LOG_FILE}."* 2>/dev/null | tail -n +6 | xargs -r rm
        fi
    fi
}

# Initialize on source
rotate_logs
