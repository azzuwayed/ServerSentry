#!/bin/bash
#
# ServerSentry - Configuration Management (merged and improved)

# Get the root script directory (one level up from lib)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$SCRIPT_DIR/config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
WEBHOOKS_FILE="$CONFIG_DIR/webhooks.conf"

# Source utils if not already sourced
if [[ "$(type -t log_message)" != "function" ]]; then
    source "$SCRIPT_DIR/lib/utils.sh"
fi

# Default thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
LOAD_THRESHOLD=2.0
CHECK_INTERVAL=60 # seconds
PROCESS_CHECKS="" # Format: "process_name1,process_name2"

# Webhooks array
declare -a WEBHOOKS

# Initialize configuration directory and files
init_config() {
    # Create config directory if it doesn't exist
    if ! ensure_dir_exists "$CONFIG_DIR"; then
        log_message "ERROR" "Failed to create configuration directory"
        return 1
    fi

    # Create thresholds file if it doesn't exist
    if [ ! -f "$THRESHOLDS_FILE" ]; then
        cat >"$THRESHOLDS_FILE" <<EOF
# SysMon Thresholds Configuration
# Values are in percentage except for load and interval
cpu_threshold=$CPU_THRESHOLD
memory_threshold=$MEMORY_THRESHOLD
disk_threshold=$DISK_THRESHOLD
load_threshold=$LOAD_THRESHOLD
check_interval=$CHECK_INTERVAL
process_checks=$PROCESS_CHECKS
EOF
        log_message "INFO" "Created default thresholds configuration file"
    fi

    # Create webhooks file if it doesn't exist
    if [ ! -f "$WEBHOOKS_FILE" ]; then
        echo "# SysMon Webhooks Configuration" >"$WEBHOOKS_FILE"
        echo "# Add one webhook URL per line" >>"$WEBHOOKS_FILE"
        log_message "INFO" "Created webhooks configuration file"
    fi

    return 0
}

# Load thresholds from configuration file
load_thresholds() {
    if [ ! -f "$THRESHOLDS_FILE" ]; then
        init_config
    fi

    # Read thresholds from file
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key == \#* ]] && continue
        [[ -z $key ]] && continue

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        case "$key" in
        cpu_threshold)
            CPU_THRESHOLD="$value"
            ;;
        memory_threshold)
            MEMORY_THRESHOLD="$value"
            ;;
        disk_threshold)
            DISK_THRESHOLD="$value"
            ;;
        load_threshold)
            LOAD_THRESHOLD="$value"
            ;;
        check_interval)
            CHECK_INTERVAL="$value"
            ;;
        process_checks)
            PROCESS_CHECKS="$value"
            ;;
        esac
    done <"$THRESHOLDS_FILE"

    log_message "INFO" "Loaded thresholds configuration"
}

# Load webhooks from configuration file
load_webhooks() {
    if [ ! -f "$WEBHOOKS_FILE" ]; then
        init_config
    fi

    # Clear the existing webhooks array
    WEBHOOKS=()

    # Read webhooks from file
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line == \#* ]] && continue
        [[ -z $line ]] && continue

        # Trim whitespace and add to array
        line=$(echo "$line" | xargs)
        WEBHOOKS+=("$line")
    done <"$WEBHOOKS_FILE"

    log_message "INFO" "Loaded ${#WEBHOOKS[@]} webhook(s)"
}

# Update a threshold value
update_threshold() {
    local name="$1"
    local value="$2"

    # Validate the threshold name
    case "$name" in
    cpu_threshold | memory_threshold | disk_threshold | load_threshold | check_interval | process_checks)
        # Valid threshold name
        ;;
    *)
        log_message "ERROR" "Invalid threshold name: $name"
        return 1
        ;;
    esac

    # Validate the value (except for process_checks)
    if [ "$name" != "process_checks" ]; then
        if ! is_number "$value"; then
            log_message "ERROR" "Invalid threshold value: $value (must be a number)"
            return 1
        fi
    fi

    # Update the configuration file
    if [ -f "$THRESHOLDS_FILE" ]; then
        # Check if the threshold already exists in the file
        if grep -q "^$name=" "$THRESHOLDS_FILE"; then
            # Update existing threshold
            if sed --version 2>/dev/null | grep -q GNU; then
                sed -i "s/^$name=.*/$name=$value/" "$THRESHOLDS_FILE"
            else
                sed -i '' "s/^$name=.*/$name=$value/" "$THRESHOLDS_FILE"
            fi
        else
            # Add new threshold
            echo "$name=$value" >>"$THRESHOLDS_FILE"
        fi

        # Update the global variable
        case "$name" in
        cpu_threshold)
            CPU_THRESHOLD="$value"
            ;;
        memory_threshold)
            MEMORY_THRESHOLD="$value"
            ;;
        disk_threshold)
            DISK_THRESHOLD="$value"
            ;;
        load_threshold)
            LOAD_THRESHOLD="$value"
            ;;
        check_interval)
            CHECK_INTERVAL="$value"
            ;;
        process_checks)
            PROCESS_CHECKS="$value"
            ;;
        esac

        log_message "INFO" "Updated threshold: $name=$value"
        return 0
    else
        log_message "ERROR" "Thresholds configuration file not found"
        return 1
    fi
}

# Add a new webhook endpoint
add_webhook() {
    local url="$1"
    # Remove any escaping from the URL before storing
    url=$(echo "$url" | sed 's/\\//g')

    if ! is_valid_url "$url"; then
        log_message "ERROR" "Invalid webhook URL: $url"
        echo "[ERROR] Invalid webhook URL: $url"
        return 1
    fi
    load_webhooks
    for webhook in "${WEBHOOKS[@]}"; do
        if [ "$webhook" == "$url" ]; then
            log_message "WARNING" "Webhook already exists: $url"
            echo "[WARNING] Webhook already exists: $url"
            return 0
        fi
    done
    echo "$url" >>"$WEBHOOKS_FILE"
    WEBHOOKS+=("$url")
    log_message "INFO" "Added webhook: $url"
    echo "Webhook added: $url"
    # Immediately send a test notification
    if [[ "$(type -t send_webhook_notification)" != "function" ]]; then
        source "$SCRIPT_DIR/lib/notify/main.sh"
    fi
    echo "Testing webhook..."
    send_webhook_notification "$url" "Test" "This is a test notification from ServerSentry (add_webhook)."
    local status=$?
    if [ $status -eq 0 ]; then
        echo "[SUCCESS] Webhook test notification sent successfully."
    else
        echo "[ERROR] Webhook test notification failed. Please check the URL or your endpoint."
    fi
    return 0
}

# Remove a webhook endpoint by index
remove_webhook() {
    local index="$1"

    # Validate the index
    if ! [[ "$index" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Invalid webhook index: $index"
        return 1
    fi

    # Load existing webhooks
    load_webhooks

    # Check if the index is valid
    if [ "$index" -ge "${#WEBHOOKS[@]}" ]; then
        log_message "ERROR" "Webhook index out of range: $index"
        return 1
    fi

    # Remove the webhook from the array
    local removed_webhook="${WEBHOOKS[$index]}"
    unset 'WEBHOOKS[$index]'

    # Rebuild the webhooks file
    echo "# SysMon Webhooks Configuration" >"$WEBHOOKS_FILE"
    echo "# Add one webhook URL per line" >>"$WEBHOOKS_FILE"

    for webhook in "${WEBHOOKS[@]}"; do
        if [ -n "$webhook" ]; then # Only add non-empty webhooks
            echo "$webhook" >>"$WEBHOOKS_FILE"
        fi
    done

    log_message "INFO" "Removed webhook: $removed_webhook"
    return 0
}

# Print the current configuration
print_config() {
    echo "SysMon Configuration:"
    print_line
    echo "Thresholds:"
    echo "  CPU Usage Threshold: ${CPU_THRESHOLD}%"
    echo "  Memory Usage Threshold: ${MEMORY_THRESHOLD}%"
    echo "  Disk Usage Threshold: ${DISK_THRESHOLD}%"
    echo "  System Load Threshold: ${LOAD_THRESHOLD}"
    echo "  Check Interval: ${CHECK_INTERVAL} seconds"

    if [ -n "$PROCESS_CHECKS" ]; then
        echo "  Process Checks: ${PROCESS_CHECKS}"
    else
        echo "  Process Checks: None"
    fi

    print_line
    echo "Webhooks:"
    if [ ${#WEBHOOKS[@]} -eq 0 ]; then
        echo "  No webhooks configured"
    else
        for i in "${!WEBHOOKS[@]}"; do
            echo "  $i: ${WEBHOOKS[$i]}"
        done
    fi
    print_line
}

# Initialize configuration when this script is sourced
init_config
