#!/bin/bash
#
# ServerSentry - Log Rotation and Cleanup Module
# Handles log file rotation, compression, and cleanup

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

# Source dependencies
source "$SCRIPT_DIR/lib/utils.sh"

# Configuration file for log rotation
LOGROTATE_CONFIG_FILE="$SCRIPT_DIR/config/logrotate.conf"
LOG_ARCHIVE_DIR="$SCRIPT_DIR/logs/archive"

# Default log rotation settings
DEFAULT_MAX_SIZE_MB=10           # Rotate when log file exceeds this size in MB
DEFAULT_MAX_AGE_DAYS=30          # Delete logs older than this many days
DEFAULT_MAX_FILES=10             # Keep at most this many rotated log files
DEFAULT_COMPRESS=true            # Whether to compress rotated logs
DEFAULT_ROTATE_ON_START=false    # Whether to rotate logs on application start

# Ensure logrotate config file exists
ensure_logrotate_config() {
    if [ ! -f "$LOGROTATE_CONFIG_FILE" ]; then
        log_message "INFO" "Creating default log rotation configuration"
        ensure_dir_exists "$(dirname "$LOGROTATE_CONFIG_FILE")"
        cat > "$LOGROTATE_CONFIG_FILE" <<EOF
# ServerSentry Log Rotation Configuration

# Maximum size in MB before rotation (0 = no size limit)
max_size_mb=$DEFAULT_MAX_SIZE_MB

# Maximum age in days before deletion (0 = never delete based on age)
max_age_days=$DEFAULT_MAX_AGE_DAYS

# Maximum number of rotated log files to keep (0 = keep all)
max_files=$DEFAULT_MAX_FILES

# Compress rotated logs (true/false)
compress=$DEFAULT_COMPRESS

# Rotate logs on application start (true/false)
rotate_on_start=$DEFAULT_ROTATE_ON_START

# End of configuration
EOF
    fi
}

# Load log rotation configuration
load_logrotate_config() {
    ensure_logrotate_config
    
    if [ -f "$LOGROTATE_CONFIG_FILE" ]; then
        # Load configuration with defaults as fallbacks
        MAX_SIZE_MB=$(grep -E "^max_size_mb=" "$LOGROTATE_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_MAX_SIZE_MB")
        MAX_AGE_DAYS=$(grep -E "^max_age_days=" "$LOGROTATE_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_MAX_AGE_DAYS")
        MAX_FILES=$(grep -E "^max_files=" "$LOGROTATE_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_MAX_FILES")
        COMPRESS=$(grep -E "^compress=" "$LOGROTATE_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_COMPRESS")
        ROTATE_ON_START=$(grep -E "^rotate_on_start=" "$LOGROTATE_CONFIG_FILE" | cut -d= -f2 || echo "$DEFAULT_ROTATE_ON_START")
        
        log_message "INFO" "Loaded log rotation configuration"
    else
        log_message "WARNING" "Log rotation configuration not found, using defaults"
        MAX_SIZE_MB="$DEFAULT_MAX_SIZE_MB"
        MAX_AGE_DAYS="$DEFAULT_MAX_AGE_DAYS"
        MAX_FILES="$DEFAULT_MAX_FILES"
        COMPRESS="$DEFAULT_COMPRESS"
        ROTATE_ON_START="$DEFAULT_ROTATE_ON_START"
    fi
}

# Update log rotation configuration
update_logrotate_config() {
    local param="$1"
    local value="$2"
    
    ensure_logrotate_config
    
    # Validate parameters
    case "$param" in
        max_size_mb)
            # Validate is a positive number
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                log_message "ERROR" "Invalid max_size_mb: $value (must be a positive number)"
                return 1
            fi
            ;;
        max_age_days)
            # Validate is a positive number
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                log_message "ERROR" "Invalid max_age_days: $value (must be a positive number)"
                return 1
            fi
            ;;
        max_files)
            # Validate is a positive number
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                log_message "ERROR" "Invalid max_files: $value (must be a positive number)"
                return 1
            fi
            ;;
        compress|rotate_on_start)
            # Validate is boolean
            if ! [[ "$value" =~ ^(true|false)$ ]]; then
                log_message "ERROR" "Invalid value for $param: $value (must be true or false)"
                return 1
            fi
            ;;
        *)
            log_message "ERROR" "Unknown parameter: $param"
            return 1
            ;;
    esac
    
    # Update the configuration file
    if grep -q "^$param=" "$LOGROTATE_CONFIG_FILE"; then
        # Parameter exists, update it
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS requires a slightly different syntax for sed
            sed -i '' "s/^$param=.*/$param=$value/" "$LOGROTATE_CONFIG_FILE"
        else
            # Linux
            sed -i "s/^$param=.*/$param=$value/" "$LOGROTATE_CONFIG_FILE"
        fi
    else
        # Parameter doesn't exist, add it
        echo "$param=$value" >> "$LOGROTATE_CONFIG_FILE"
    fi
    
    log_message "INFO" "Updated $param to $value"
    return 0
}

# Compress a log file
compress_log_file() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        log_message "WARNING" "Cannot compress non-existent log file: $log_file"
        return 1
    fi
    
    # Check if gzip is available
    if command_exists gzip; then
        gzip -f "$log_file"
        log_message "INFO" "Compressed log file: $log_file"
        return 0
    else
        log_message "WARNING" "gzip not available, skipping compression of $log_file"
        return 1
    fi
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    local size=0
    
    if [ -f "$file" ]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            size=$(stat -f %z "$file" 2>/dev/null || echo 0)
        else
            # Linux
            size=$(stat -c %s "$file" 2>/dev/null || echo 0)
        fi
    fi
    
    echo "$size"
}

# Get file age in days
get_file_age_days() {
    local file="$1"
    local now=$(date +%s)
    local file_time=0
    local age_days=0
    
    if [ -f "$file" ]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            file_time=$(stat -f %m "$file" 2>/dev/null || echo "$now")
        else
            # Linux
            file_time=$(stat -c %Y "$file" 2>/dev/null || echo "$now")
        fi
        
        age_seconds=$((now - file_time))
        age_days=$((age_seconds / 86400))
    fi
    
    echo "$age_days"
}

# Rotate logs based on file size
rotate_log_file() {
    # Make sure archive directory exists
    ensure_dir_exists "$LOG_ARCHIVE_DIR"
    
    # Check if log file exists
    if [ ! -f "$LOG_FILE" ]; then
        log_message "INFO" "Log file does not exist yet, nothing to rotate"
        return 0
    fi
    
    # Check log file size
    local size_bytes=$(get_file_size "$LOG_FILE")
    local size_mb=$((size_bytes / 1048576))  # Convert to MB
    
    # Determine if rotation is needed
    local rotate_needed=false
    
    # Check size-based rotation if enabled
    if [ "$MAX_SIZE_MB" -gt 0 ] && [ "$size_mb" -ge "$MAX_SIZE_MB" ]; then
        rotate_needed=true
        log_message "INFO" "Log rotation triggered by size: $size_mb MB >= $MAX_SIZE_MB MB"
    fi
    
    # Rotate if needed
    if [ "$rotate_needed" = true ]; then
        local timestamp=$(date "+%Y%m%d%H%M%S")
        local rotated_log="${LOG_ARCHIVE_DIR}/serversentry-${timestamp}.log"
        
        # Move current log to archive
        mv "$LOG_FILE" "$rotated_log"
        touch "$LOG_FILE"
        log_message "INFO" "Log file rotated to ${rotated_log}"
        
        # Compress if enabled
        if [ "$COMPRESS" = "true" ]; then
            compress_log_file "$rotated_log"
        fi
    fi
}

# Clean up old log files
cleanup_old_logs() {
    # Make sure archive directory exists
    ensure_dir_exists "$LOG_ARCHIVE_DIR"
    
    local deleted_count=0
    
    # Delete logs based on age
    if [ "$MAX_AGE_DAYS" -gt 0 ]; then
        # Get list of all log files in archive directory
        local log_files=()
        # Include both compressed and uncompressed logs
        while IFS= read -r file; do
            log_files+=("$file")
        done < <(find "$LOG_ARCHIVE_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) 2>/dev/null)
        
        # Check age of each file and delete if too old
        for file in "${log_files[@]}"; do
            local age_days=$(get_file_age_days "$file")
            if [ "$age_days" -ge "$MAX_AGE_DAYS" ]; then
                rm "$file"
                log_message "INFO" "Deleted old log file: $file (age: $age_days days)"
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi
    
    # Limit number of log files if configured
    if [ "$MAX_FILES" -gt 0 ]; then
        # Get list of all log files in archive directory, sorted by modification time (newest first)
        local log_files=()
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            while IFS= read -r file; do
                log_files+=("$file")
            done < <(find "$LOG_ARCHIVE_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -nr | cut -d' ' -f2-)
        else
            # Linux
            while IFS= read -r file; do
                log_files+=("$file")
            done < <(find "$LOG_ARCHIVE_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) -printf "%T@ %p\n" 2>/dev/null | sort -nr | cut -d' ' -f2-)
        fi
        
        # Keep only the desired number of most recent files
        local count=0
        for file in "${log_files[@]}"; do
            count=$((count + 1))
            if [ "$count" -gt "$MAX_FILES" ]; then
                rm "$file"
                log_message "INFO" "Deleted excess log file: $file (keeping max $MAX_FILES files)"
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi
    
    return $deleted_count
}

# Perform complete log maintenance
maintain_logs() {
    load_logrotate_config
    rotate_log_file
    cleanup_old_logs
}

# Show log rotation status
show_logrotate_status() {
    load_logrotate_config
    
    echo ""
    echo "Log Rotation Configuration:"
    echo "-------------------------"
    echo "Maximum size before rotation: $MAX_SIZE_MB MB"
    echo "Delete logs older than: $MAX_AGE_DAYS days"
    echo "Maximum rotated files to keep: $MAX_FILES"
    echo "Compress rotated logs: $COMPRESS"
    echo "Rotate on application start: $ROTATE_ON_START"
    
    echo ""
    echo "Current Log File:"
    echo "---------------"
    local size_bytes=$(get_file_size "$LOG_FILE")
    local size_mb=$(echo "scale=2; $size_bytes / 1048576" | bc 2>/dev/null || echo "$((size_bytes / 1048576))")
    echo "Path: $LOG_FILE"
    echo "Size: $size_mb MB"
    
    echo ""
    echo "Archived Logs:"
    echo "-------------"
    if [ -d "$LOG_ARCHIVE_DIR" ]; then
        local log_count=$(find "$LOG_ARCHIVE_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) 2>/dev/null | wc -l)
        local log_size=$(du -sh "$LOG_ARCHIVE_DIR" 2>/dev/null | cut -f1)
        echo "Count: $log_count files"
        echo "Total size: $log_size"
        echo "Directory: $LOG_ARCHIVE_DIR"
    else
        echo "No archived logs found"
    fi
    
    echo ""
}

# Main function for logrotate command
logrotate_main() {
    local command="$1"
    shift
    
    case "$command" in
        status)
            show_logrotate_status
            ;;
        rotate)
            load_logrotate_config
            rotate_log_file
            echo "Log rotation completed"
            ;;
        clean)
            load_logrotate_config
            local count=$(cleanup_old_logs)
            echo "Log cleanup completed. Removed $count log files."
            ;;
        config)
            if [ $# -ge 2 ]; then
                update_logrotate_config "$1" "$2"
            else
                echo "Usage: logrotate config <parameter> <value>"
                echo "Parameters: max_size_mb, max_age_days, max_files, compress, rotate_on_start"
                return 1
            fi
            ;;
        *)
            echo "Unknown logrotate command: $command"
            echo "Available commands: status, rotate, clean, config"
            return 1
            ;;
    esac
    
    return 0
}

# Initialize 
load_logrotate_config

# Rotate on start if configured
if [ "$ROTATE_ON_START" = "true" ]; then
    rotate_log_file
fi 