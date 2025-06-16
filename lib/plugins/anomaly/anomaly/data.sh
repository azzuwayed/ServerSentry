#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Data Management Module
#
# This module handles anomaly detection data storage, retrieval, cleanup,
# and maintenance operations for metric data and analysis results.

# Prevent multiple sourcing
if [[ "${ANOMALY_DATA_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_DATA_MODULE_LOADED=true
export ANOMALY_DATA_MODULE_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Search upward for bootstrap
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      export SERVERSENTRY_QUIET=true
      export SERVERSENTRY_AUTO_INIT=false
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done
fi

# Source core utilities
if [[ -f "${BASE_DIR}/lib/core/utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Data directories
ANOMALY_DATA_DIR="${BASE_DIR}/logs/anomaly"
ANOMALY_RESULTS_DIR="${BASE_DIR}/logs/anomaly/results"
ANOMALY_ARCHIVE_DIR="${BASE_DIR}/logs/anomaly/archive"

# Data management settings
ANOMALY_MAX_DATA_POINTS=1000
ANOMALY_DATA_RETENTION_DAYS=30
ANOMALY_ARCHIVE_RETENTION_DAYS=90

# Function: anomaly_data_init
# Description: Initialize the anomaly data management system
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_data_init
# Dependencies:
#   - util_error_validate_input
anomaly_data_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for anomaly_data_init: expected 0, got $#" "anomaly_data"
    return 1
  fi

  # Create required directories
  local dirs=("$ANOMALY_DATA_DIR" "$ANOMALY_RESULTS_DIR" "$ANOMALY_ARCHIVE_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create anomaly data directory: $dir" "anomaly_data"
        return 1
      fi
      log_debug "Created anomaly data directory: $dir" "anomaly_data"
    fi
  done

  # Set appropriate permissions
  for dir in "${dirs[@]}"; do
    if ! chmod 755 "$dir"; then
      log_warning "Failed to set permissions for directory: $dir" "anomaly_data"
    fi
  done

  log_debug "Anomaly data management initialized" "anomaly_data"
  return 0
}

# Function: anomaly_data_store_metric
# Description: Store metric data point for anomaly detection analysis
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name
#   $3 (numeric): metric value
#   $4 (numeric): timestamp (optional, defaults to current time)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_data_store_metric "cpu" "usage" 85.5 1640995200
# Dependencies:
#   - util_error_validate_input
#   - anomaly_data_rotate_if_needed
anomaly_data_store_metric() {
  if ! util_error_validate_input "anomaly_data_store_metric" "3" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local metric_value="$3"
  local timestamp="${4:-$(date +%s)}"

  # Validate inputs
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_data"
    return 1
  fi

  if [[ ! "$metric_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid metric name: $metric_name" "anomaly_data"
    return 1
  fi

  if [[ ! "$metric_value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
    log_error "Invalid metric value: $metric_value" "anomaly_data"
    return 1
  fi

  if [[ ! "$timestamp" =~ ^[0-9]+$ ]]; then
    log_error "Invalid timestamp: $timestamp" "anomaly_data"
    return 1
  fi

  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  # Store data point with format: timestamp,value,plugin,metric
  local data_entry="${timestamp},${metric_value},${plugin_name},${metric_name}"

  if ! echo "$data_entry" >>"$data_file"; then
    log_error "Failed to store metric data: $data_file" "anomaly_data"
    return 1
  fi

  # Rotate data file if it exceeds maximum points
  if ! anomaly_data_rotate_if_needed "$data_file"; then
    log_warning "Failed to rotate data file: $data_file" "anomaly_data"
  fi

  log_debug "Stored metric data: ${plugin_name}.${metric_name} = $metric_value at $timestamp" "anomaly_data"
  return 0
}

# Function: anomaly_data_get_recent
# Description: Get recent metric data points for analysis
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name
#   $3 (numeric): number of recent points to retrieve (default: 50)
# Returns:
#   0 - success (outputs data points)
#   1 - failure or no data
# Example:
#   data=$(anomaly_data_get_recent "cpu" "usage" 20)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_data_get_recent() {
  if ! util_error_validate_input "anomaly_data_get_recent" "2" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local num_points="${3:-50}"

  # Validate inputs
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_data"
    return 1
  fi

  if [[ ! "$metric_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid metric name: $metric_name" "anomaly_data"
    return 1
  fi

  if [[ ! "$num_points" =~ ^[0-9]+$ ]] || [[ "$num_points" -le 0 ]]; then
    log_error "Invalid number of points: $num_points" "anomaly_data"
    return 1
  fi

  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  if [[ ! -f "$data_file" ]]; then
    log_debug "No data file found for ${plugin_name}.${metric_name}" "anomaly_data"
    return 1
  fi

  # Get recent data points with safe execution
  local recent_data
  if ! recent_data=$(util_error_safe_execute "tail -n $num_points '$data_file'" 10); then
    log_error "Failed to retrieve recent data from: $data_file" "anomaly_data"
    return 1
  fi

  if [[ -z "$recent_data" ]]; then
    log_debug "No recent data found for ${plugin_name}.${metric_name}" "anomaly_data"
    return 1
  fi

  echo "$recent_data"
  return 0
}

# Function: anomaly_data_get_time_range
# Description: Get metric data points within a specific time range
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name
#   $3 (numeric): start timestamp
#   $4 (numeric): end timestamp
# Returns:
#   0 - success (outputs data points)
#   1 - failure or no data
# Example:
#   data=$(anomaly_data_get_time_range "cpu" "usage" 1640995200 1640998800)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_data_get_time_range() {
  if ! util_error_validate_input "anomaly_data_get_time_range" "4" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local start_timestamp="$3"
  local end_timestamp="$4"

  # Validate inputs
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_data"
    return 1
  fi

  if [[ ! "$metric_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid metric name: $metric_name" "anomaly_data"
    return 1
  fi

  for ts in "$start_timestamp" "$end_timestamp"; do
    if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
      log_error "Invalid timestamp: $ts" "anomaly_data"
      return 1
    fi
  done

  if [[ "$start_timestamp" -gt "$end_timestamp" ]]; then
    log_error "Start timestamp cannot be greater than end timestamp" "anomaly_data"
    return 1
  fi

  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  if [[ ! -f "$data_file" ]]; then
    log_debug "No data file found for ${plugin_name}.${metric_name}" "anomaly_data"
    return 1
  fi

  # Filter data by time range using awk
  local filtered_data
  if ! filtered_data=$(util_error_safe_execute "awk -F',' -v start=$start_timestamp -v end=$end_timestamp '\$1 >= start && \$1 <= end' '$data_file'" 10); then
    log_error "Failed to filter data by time range: $data_file" "anomaly_data"
    return 1
  fi

  if [[ -z "$filtered_data" ]]; then
    log_debug "No data found in time range for ${plugin_name}.${metric_name}" "anomaly_data"
    return 1
  fi

  echo "$filtered_data"
  return 0
}

# Function: anomaly_data_rotate_if_needed
# Description: Rotate data file if it exceeds maximum number of data points
# Parameters:
#   $1 (string): data file path
# Returns:
#   0 - success (rotation performed or not needed)
#   1 - failure
# Example:
#   anomaly_data_rotate_if_needed "/path/to/data.dat"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_data_rotate_if_needed() {
  if ! util_error_validate_input "anomaly_data_rotate_if_needed" "1" "$#"; then
    return 1
  fi

  local data_file="$1"

  if [[ ! -f "$data_file" ]]; then
    return 0 # No file to rotate
  fi

  # Count lines in the file
  local line_count
  if ! line_count=$(util_error_safe_execute "wc -l < '$data_file'" 10); then
    log_error "Failed to count lines in data file: $data_file" "anomaly_data"
    return 1
  fi

  # Remove any whitespace
  line_count=$(echo "$line_count" | tr -d ' ')

  if [[ ! "$line_count" =~ ^[0-9]+$ ]]; then
    log_error "Invalid line count result: $line_count" "anomaly_data"
    return 1
  fi

  # Check if rotation is needed
  if [[ "$line_count" -le "$ANOMALY_MAX_DATA_POINTS" ]]; then
    return 0 # No rotation needed
  fi

  log_debug "Rotating data file: $data_file (lines: $line_count)" "anomaly_data"

  # Create archive of old data
  local archive_file="${ANOMALY_ARCHIVE_DIR}/$(basename "$data_file").$(date +%Y%m%d_%H%M%S)"

  if ! cp "$data_file" "$archive_file"; then
    log_error "Failed to create archive: $archive_file" "anomaly_data"
    return 1
  fi

  # Keep only the most recent data points
  local temp_file="${data_file}.tmp"
  if ! util_error_safe_execute "tail -n $ANOMALY_MAX_DATA_POINTS '$data_file' > '$temp_file'" 10; then
    log_error "Failed to create rotated data file: $temp_file" "anomaly_data"
    rm -f "$temp_file"
    return 1
  fi

  # Replace original file with rotated data
  if ! mv "$temp_file" "$data_file"; then
    log_error "Failed to replace data file with rotated version: $data_file" "anomaly_data"
    rm -f "$temp_file"
    return 1
  fi

  log_debug "Data file rotated successfully: $data_file" "anomaly_data"
  return 0
}

# Function: anomaly_data_cleanup_old
# Description: Clean up old data files and archives based on retention policies
# Parameters:
#   $1 (numeric): data retention days (optional, uses default)
#   $2 (numeric): archive retention days (optional, uses default)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_data_cleanup_old 30 90
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_data_cleanup_old() {
  if ! util_error_validate_input "anomaly_data_cleanup_old" "0" "$#"; then
    return 1
  fi

  local data_retention_days="${1:-$ANOMALY_DATA_RETENTION_DAYS}"
  local archive_retention_days="${2:-$ANOMALY_ARCHIVE_RETENTION_DAYS}"

  # Validate retention periods
  if [[ ! "$data_retention_days" =~ ^[0-9]+$ ]] || [[ "$data_retention_days" -le 0 ]]; then
    log_error "Invalid data retention days: $data_retention_days" "anomaly_data"
    return 1
  fi

  if [[ ! "$archive_retention_days" =~ ^[0-9]+$ ]] || [[ "$archive_retention_days" -le 0 ]]; then
    log_error "Invalid archive retention days: $archive_retention_days" "anomaly_data"
    return 1
  fi

  local cleanup_count=0

  # Clean up old data files
  if [[ -d "$ANOMALY_DATA_DIR" ]]; then
    local old_data_files
    if old_data_files=$(find "$ANOMALY_DATA_DIR" -name "*.dat" -type f -mtime +"${data_retention_days}" 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          if rm -f "$file"; then
            log_debug "Removed old data file: $file" "anomaly_data"
            cleanup_count=$((cleanup_count + 1))
          else
            log_warning "Failed to remove old data file: $file" "anomaly_data"
          fi
        fi
      done <<<"$old_data_files"
    fi
  fi

  # Clean up old archive files
  if [[ -d "$ANOMALY_ARCHIVE_DIR" ]]; then
    local old_archive_files
    if old_archive_files=$(find "$ANOMALY_ARCHIVE_DIR" -type f -mtime +"${archive_retention_days}" 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          if rm -f "$file"; then
            log_debug "Removed old archive file: $file" "anomaly_data"
            cleanup_count=$((cleanup_count + 1))
          else
            log_warning "Failed to remove old archive file: $file" "anomaly_data"
          fi
        fi
      done <<<"$old_archive_files"
    fi
  fi

  # Clean up old result files
  if [[ -d "$ANOMALY_RESULTS_DIR" ]]; then
    local old_result_files
    if old_result_files=$(find "$ANOMALY_RESULTS_DIR" -name "*.log" -type f -mtime +"${data_retention_days}" 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          if rm -f "$file"; then
            log_debug "Removed old result file: $file" "anomaly_data"
            cleanup_count=$((cleanup_count + 1))
          else
            log_warning "Failed to remove old result file: $file" "anomaly_data"
          fi
        fi
      done <<<"$old_result_files"
    fi
  fi

  log_debug "Anomaly data cleanup completed: $cleanup_count files removed" "anomaly_data"
  return 0
}

# Function: anomaly_data_get_statistics
# Description: Get comprehensive statistics about stored anomaly data
# Parameters: None
# Returns:
#   0 - success (outputs JSON statistics)
#   1 - failure
# Example:
#   stats=$(anomaly_data_get_statistics)
# Dependencies:
#   - util_error_validate_input
anomaly_data_get_statistics() {
  if ! util_error_validate_input "anomaly_data_get_statistics" "0" "$#"; then
    return 1
  fi

  local total_data_files=0
  local total_data_points=0
  local total_archive_files=0
  local total_result_files=0
  local oldest_data=""
  local newest_data=""

  # Count data files and points
  if [[ -d "$ANOMALY_DATA_DIR" ]]; then
    local data_files
    if data_files=$(find "$ANOMALY_DATA_DIR" -name "*.dat" -type f 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          total_data_files=$((total_data_files + 1))

          # Count lines in file
          local line_count
          if line_count=$(wc -l <"$file" 2>/dev/null); then
            total_data_points=$((total_data_points + line_count))
          fi

          # Get oldest and newest timestamps
          if [[ -s "$file" ]]; then
            local first_timestamp
            local last_timestamp
            first_timestamp=$(head -n 1 "$file" | cut -d',' -f1 2>/dev/null)
            last_timestamp=$(tail -n 1 "$file" | cut -d',' -f1 2>/dev/null)

            if [[ -n "$first_timestamp" ]] && [[ "$first_timestamp" =~ ^[0-9]+$ ]]; then
              if [[ -z "$oldest_data" ]] || [[ "$first_timestamp" -lt "$oldest_data" ]]; then
                oldest_data="$first_timestamp"
              fi
            fi

            if [[ -n "$last_timestamp" ]] && [[ "$last_timestamp" =~ ^[0-9]+$ ]]; then
              if [[ -z "$newest_data" ]] || [[ "$last_timestamp" -gt "$newest_data" ]]; then
                newest_data="$last_timestamp"
              fi
            fi
          fi
        fi
      done <<<"$data_files"
    fi
  fi

  # Count archive files
  if [[ -d "$ANOMALY_ARCHIVE_DIR" ]]; then
    local archive_files
    if archive_files=$(find "$ANOMALY_ARCHIVE_DIR" -type f 2>/dev/null); then
      total_archive_files=$(echo "$archive_files" | grep -c . 2>/dev/null || echo "0")
    fi
  fi

  # Count result files
  if [[ -d "$ANOMALY_RESULTS_DIR" ]]; then
    local result_files
    if result_files=$(find "$ANOMALY_RESULTS_DIR" -name "*.log" -type f 2>/dev/null); then
      total_result_files=$(echo "$result_files" | grep -c . 2>/dev/null || echo "0")
    fi
  fi

  # Calculate disk usage
  local data_dir_size=0
  local archive_dir_size=0
  local results_dir_size=0

  if command -v du >/dev/null 2>&1; then
    if [[ -d "$ANOMALY_DATA_DIR" ]]; then
      data_dir_size=$(du -sb "$ANOMALY_DATA_DIR" 2>/dev/null | cut -f1 || echo "0")
    fi
    if [[ -d "$ANOMALY_ARCHIVE_DIR" ]]; then
      archive_dir_size=$(du -sb "$ANOMALY_ARCHIVE_DIR" 2>/dev/null | cut -f1 || echo "0")
    fi
    if [[ -d "$ANOMALY_RESULTS_DIR" ]]; then
      results_dir_size=$(du -sb "$ANOMALY_RESULTS_DIR" 2>/dev/null | cut -f1 || echo "0")
    fi
  fi

  # Format timestamps
  local oldest_date=""
  local newest_date=""
  if [[ -n "$oldest_data" ]]; then
    oldest_date=$(date -u -d "@$oldest_data" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  fi
  if [[ -n "$newest_data" ]]; then
    newest_date=$(date -u -d "@$newest_data" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  fi

  # Generate JSON statistics
  cat <<EOF
{
  "anomaly_data_statistics": {
    "data_files": {
      "count": $total_data_files,
      "total_data_points": $total_data_points,
      "disk_usage_bytes": $data_dir_size
    },
    "archive_files": {
      "count": $total_archive_files,
      "disk_usage_bytes": $archive_dir_size
    },
    "result_files": {
      "count": $total_result_files,
      "disk_usage_bytes": $results_dir_size
    },
    "time_range": {
      "oldest_timestamp": ${oldest_data:-null},
      "newest_timestamp": ${newest_data:-null},
      "oldest_date": "${oldest_date}",
      "newest_date": "${newest_date}"
    },
    "settings": {
      "max_data_points": $ANOMALY_MAX_DATA_POINTS,
      "data_retention_days": $ANOMALY_DATA_RETENTION_DAYS,
      "archive_retention_days": $ANOMALY_ARCHIVE_RETENTION_DAYS
    },
    "total_disk_usage_bytes": $((data_dir_size + archive_dir_size + results_dir_size)),
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF

  return 0
}

# Function: anomaly_data_export
# Description: Export anomaly data for a plugin in JSON format
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name (optional, exports all metrics if not specified)
#   $3 (numeric): start timestamp (optional)
#   $4 (numeric): end timestamp (optional)
# Returns:
#   0 - success (outputs JSON data)
#   1 - failure
# Example:
#   data=$(anomaly_data_export "cpu" "usage" 1640995200 1640998800)
# Dependencies:
#   - util_error_validate_input
#   - anomaly_data_get_time_range
#   - anomaly_data_get_recent
anomaly_data_export() {
  if ! util_error_validate_input "anomaly_data_export" "1" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local start_timestamp="$3"
  local end_timestamp="$4"

  # Validate plugin name
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid plugin name: $plugin_name" "anomaly_data"
    return 1
  fi

  local export_data='{"plugin": "'$plugin_name'", "export_timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "data": ['
  local first=true

  # Determine which metrics to export
  local metrics_to_export=()
  if [[ -n "$metric_name" ]]; then
    metrics_to_export=("$metric_name")
  else
    # Find all metrics for this plugin
    local data_files
    if data_files=$(find "$ANOMALY_DATA_DIR" -name "${plugin_name}_*.dat" -type f 2>/dev/null); then
      while read -r file; do
        if [[ -n "$file" ]]; then
          local filename
          filename=$(basename "$file")
          local extracted_metric
          extracted_metric="${filename#"${plugin_name}"_}"
          extracted_metric="${extracted_metric%.dat}"
          metrics_to_export+=("$extracted_metric")
        fi
      done <<<"$data_files"
    fi
  fi

  # Export data for each metric
  for metric in "${metrics_to_export[@]}"; do
    local metric_data=""

    # Get data based on time range
    if [[ -n "$start_timestamp" ]] && [[ -n "$end_timestamp" ]]; then
      metric_data=$(anomaly_data_get_time_range "$plugin_name" "$metric" "$start_timestamp" "$end_timestamp" 2>/dev/null)
    else
      metric_data=$(anomaly_data_get_recent "$plugin_name" "$metric" 1000 2>/dev/null)
    fi

    if [[ -n "$metric_data" ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        export_data+=','
      fi

      export_data+="{\"metric\": \"$metric\", \"data_points\": ["
      local point_first=true

      while IFS=',' read -r timestamp value plugin_check metric_check; do
        if [[ -n "$timestamp" ]] && [[ -n "$value" ]]; then
          if [[ "$point_first" == "true" ]]; then
            point_first=false
          else
            export_data+=','
          fi
          export_data+="{\"timestamp\": $timestamp, \"value\": $value, \"date\": \"$(date -u -d "@$timestamp" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")\"}"
        fi
      done <<<"$metric_data"

      export_data+="]}"
    fi
  done

  export_data+=']}'
  echo "$export_data"
  return 0
}

# Export all data management functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_data_init
  export -f anomaly_data_store_metric
  export -f anomaly_data_get_recent
  export -f anomaly_data_get_time_range
  export -f anomaly_data_rotate_if_needed
  export -f anomaly_data_cleanup_old
  export -f anomaly_data_get_statistics
  export -f anomaly_data_export
fi

# Initialize the module
if ! anomaly_data_init; then
  log_error "Failed to initialize anomaly data management module" "anomaly_data"
fi
