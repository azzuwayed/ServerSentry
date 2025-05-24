#!/bin/bash
#
# ServerSentry v2 - Anomaly Detection System
#
# This module implements statistical anomaly detection for monitoring metrics
# Uses moving averages, standard deviations, and pattern analysis

# Anomaly detection configuration
ANOMALY_DATA_DIR="${BASE_DIR}/logs/anomaly"
ANOMALY_CONFIG_DIR="${BASE_DIR}/config/anomaly"
ANOMALY_RESULTS_DIR="${BASE_DIR}/logs/anomaly/results"

# Anomaly detection settings
ANOMALY_WINDOW_SIZE=20     # Number of data points for analysis
ANOMALY_SENSITIVITY=2.0    # Standard deviation multiplier for outliers
ANOMALY_MIN_DATA_POINTS=10 # Minimum data points before analysis

# Initialize anomaly detection system
anomaly_system_init() {
  log_debug "Initializing anomaly detection system"

  # Create directories if they don't exist
  for dir in "$ANOMALY_DATA_DIR" "$ANOMALY_CONFIG_DIR" "$ANOMALY_RESULTS_DIR"; do
    if [ ! -d "$dir" ]; then
      mkdir -p "$dir"
      log_debug "Created anomaly directory: $dir"
    fi
  done

  # Create default anomaly detection configurations
  anomaly_create_default_config

  return 0
}

# Create default anomaly detection configurations
anomaly_create_default_config() {
  # CPU anomaly detection config
  local cpu_anomaly_config="$ANOMALY_CONFIG_DIR/cpu_anomaly.conf"
  if [ ! -f "$cpu_anomaly_config" ]; then
    cat >"$cpu_anomaly_config" <<'EOF'
# CPU Anomaly Detection Configuration
plugin="cpu"
metric="value"
enabled=true
sensitivity=2.0
window_size=20
min_data_points=10
check_patterns=true
detect_spikes=true
detect_trends=true
notification_threshold=3  # Number of consecutive anomalies before notification
cooldown=1800             # Cooldown period in seconds
EOF
    log_debug "Created CPU anomaly detection config"
  fi

  # Memory anomaly detection config
  local memory_anomaly_config="$ANOMALY_CONFIG_DIR/memory_anomaly.conf"
  if [ ! -f "$memory_anomaly_config" ]; then
    cat >"$memory_anomaly_config" <<'EOF'
# Memory Anomaly Detection Configuration
plugin="memory"
metric="value"
enabled=true
sensitivity=1.8
window_size=25
min_data_points=12
check_patterns=true
detect_spikes=true
detect_trends=true
notification_threshold=2
cooldown=1200
EOF
    log_debug "Created Memory anomaly detection config"
  fi

  # Disk anomaly detection config
  local disk_anomaly_config="$ANOMALY_CONFIG_DIR/disk_anomaly.conf"
  if [ ! -f "$disk_anomaly_config" ]; then
    cat >"$disk_anomaly_config" <<'EOF'
# Disk Anomaly Detection Configuration
plugin="disk"
metric="value"
enabled=true
sensitivity=2.2
window_size=30
min_data_points=15
check_patterns=true
detect_spikes=false       # Disk spikes are often normal
detect_trends=true
notification_threshold=4
cooldown=3600
EOF
    log_debug "Created Disk anomaly detection config"
  fi
}

# Store metric data for anomaly detection
store_metric_data() {
  local plugin_name="$1"
  local metric_name="$2"
  local metric_value="$3"
  local timestamp="${4:-$(date +%s)}"

  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  # Store data point: timestamp,value
  echo "$timestamp,$metric_value" >>"$data_file"

  # Keep only recent data points (prevent unbounded growth)
  local max_points=1000
  if [ -f "$data_file" ]; then
    local line_count
    line_count=$(wc -l <"$data_file")
    if [ "$line_count" -gt "$max_points" ]; then
      # Keep only the most recent max_points
      tail -n "$max_points" "$data_file" >"${data_file}.tmp"
      mv "${data_file}.tmp" "$data_file"
    fi
  fi

  log_debug "Stored metric data: ${plugin_name}.${metric_name} = $metric_value"
}

# Calculate basic statistics for a dataset
calculate_statistics() {
  local data_file="$1"
  local window_size="$2"

  if [ ! -f "$data_file" ]; then
    echo "0,0,0,0" # count,mean,std_dev,median
    return 1
  fi

  # Get recent data points
  local values
  values=$(tail -n "$window_size" "$data_file" | cut -d',' -f2)

  if [ -z "$values" ]; then
    echo "0,0,0,0"
    return 1
  fi

  # Calculate statistics using awk
  echo "$values" | awk '
  BEGIN {
    count = 0
    sum = 0
    sum_sq = 0
  }
  {
    values[++count] = $1
    sum += $1
    sum_sq += $1 * $1
  }
  END {
    if (count == 0) {
      print "0,0,0,0"
      exit
    }
    
    mean = sum / count
    variance = (sum_sq / count) - (mean * mean)
    std_dev = sqrt(variance > 0 ? variance : 0)
    
    # Calculate median
    asort(values)
    if (count % 2 == 1) {
      median = values[int(count/2) + 1]
    } else {
      median = (values[count/2] + values[count/2 + 1]) / 2
    }
    
    printf "%.0f,%.2f,%.2f,%.2f\n", count, mean, std_dev, median
  }'
}

# Detect statistical anomalies
detect_statistical_anomaly() {
  local plugin_name="$1"
  local metric_name="$2"
  local current_value="$3"
  local config_file="$4"

  # Load configuration
  if ! anomaly_parse_config "$config_file"; then
    return 1
  fi

  local data_file="$ANOMALY_DATA_DIR/${plugin_name}_${metric_name}.dat"

  # Calculate statistics for recent window
  local stats
  stats=$(calculate_statistics "$data_file" "$window_size")

  local count mean std_dev median
  IFS=',' read -r count mean std_dev median <<<"$stats"

  # Check if we have enough data points
  if [ "$count" -lt "$min_data_points" ]; then
    log_debug "Insufficient data points for anomaly detection: $count < $min_data_points"
    return 1
  fi

  # Detect outliers using standard deviation
  local is_anomaly=false
  local anomaly_type=""
  local anomaly_score=0

  # Z-score calculation
  if [[ $(echo "$std_dev > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    local z_score
    z_score=$(echo "scale=2; ($current_value - $mean) / $std_dev" | bc 2>/dev/null || echo "0")
    local abs_z_score
    abs_z_score=$(echo "$z_score" | sed 's/-//')

    # Check if anomaly based on sensitivity threshold
    if [[ $(echo "$abs_z_score > $sensitivity" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      is_anomaly=true
      anomaly_score="$z_score"

      # Determine anomaly type
      if [[ $(echo "$z_score > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        anomaly_type="high_outlier"
      else
        anomaly_type="low_outlier"
      fi
    fi
  fi

  # Additional pattern detection if enabled
  if [ "$check_patterns" = "true" ]; then
    # Detect trends
    if [ "$detect_trends" = "true" ]; then
      local trend_anomaly
      trend_anomaly=$(detect_trend_anomaly "$data_file" "$window_size")
      if [ "$trend_anomaly" != "none" ]; then
        is_anomaly=true
        anomaly_type="${anomaly_type},${trend_anomaly}"
      fi
    fi

    # Detect spikes
    if [ "$detect_spikes" = "true" ]; then
      local spike_anomaly
      spike_anomaly=$(detect_spike_anomaly "$data_file" "$current_value" "$mean" "$std_dev")
      if [ "$spike_anomaly" != "none" ]; then
        is_anomaly=true
        anomaly_type="${anomaly_type},${spike_anomaly}"
      fi
    fi
  fi

  # Return anomaly result
  if [ "$is_anomaly" = "true" ]; then
    cat <<EOF
{
  "plugin": "$plugin_name",
  "metric": "$metric_name",
  "current_value": $current_value,
  "is_anomaly": true,
  "anomaly_type": "$anomaly_type",
  "anomaly_score": $anomaly_score,
  "statistics": {
    "count": $count,
    "mean": $mean,
    "std_dev": $std_dev,
    "median": $median
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    return 0
  else
    cat <<EOF
{
  "plugin": "$plugin_name",
  "metric": "$metric_name",
  "current_value": $current_value,
  "is_anomaly": false,
  "statistics": {
    "count": $count,
    "mean": $mean,
    "std_dev": $std_dev,
    "median": $median
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    return 1
  fi
}

# Detect trend anomalies
detect_trend_anomaly() {
  local data_file="$1"
  local window_size="$2"

  if [ ! -f "$data_file" ]; then
    echo "none"
    return
  fi

  # Get recent values for trend analysis
  local values
  values=$(tail -n "$window_size" "$data_file" | cut -d',' -f2)

  if [ -z "$values" ]; then
    echo "none"
    return
  fi

  # Calculate trend using linear regression (simplified)
  local trend_direction
  trend_direction=$(echo "$values" | awk '
  BEGIN { 
    count = 0
    sum_x = 0
    sum_y = 0
    sum_xy = 0
    sum_x2 = 0
  }
  {
    count++
    x = count
    y = $1
    sum_x += x
    sum_y += y
    sum_xy += x * y
    sum_x2 += x * x
  }
  END {
    if (count < 3) {
      print "none"
      exit
    }
    
    # Calculate slope
    denominator = count * sum_x2 - sum_x * sum_x
    if (denominator == 0) {
      print "none"
      exit
    }
    
    slope = (count * sum_xy - sum_x * sum_y) / denominator
    
    # Determine trend significance
    if (slope > 2) {
      print "steep_upward_trend"
    } else if (slope < -2) {
      print "steep_downward_trend"
    } else {
      print "none"
    }
  }')

  echo "$trend_direction"
}

# Detect spike anomalies
detect_spike_anomaly() {
  local data_file="$1"
  local current_value="$2"
  local mean="$3"
  local std_dev="$4"

  # A spike is a sudden large change from recent values
  if [ ! -f "$data_file" ]; then
    echo "none"
    return
  fi

  # Get the last few values
  local recent_values
  recent_values=$(tail -n 5 "$data_file" | cut -d',' -f2)

  if [ -z "$recent_values" ]; then
    echo "none"
    return
  fi

  # Calculate average of recent values
  local recent_mean
  recent_mean=$(echo "$recent_values" | awk '{sum+=$1} END {print sum/NR}')

  # Check if current value is significantly different from recent pattern
  if [[ $(echo "$std_dev > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    local spike_threshold
    spike_threshold=$(echo "scale=2; $std_dev * 3" | bc 2>/dev/null || echo "0")

    local value_diff
    value_diff=$(echo "scale=2; $current_value - $recent_mean" | bc 2>/dev/null | sed 's/-//')

    if [[ $(echo "$value_diff > $spike_threshold" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      if [[ $(echo "$current_value > $recent_mean" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        echo "positive_spike"
      else
        echo "negative_spike"
      fi
    else
      echo "none"
    fi
  else
    echo "none"
  fi
}

# Parse anomaly detection configuration - REFACTORED
# Now uses unified configuration utilities
anomaly_parse_config() {
  local config_file="$1"
  local plugin_name="$2"

  # Use unified configuration parser with caching
  if ! util_config_get_cached "$config_file" "anomaly_${plugin_name}" 300; then
    log_error "Failed to parse anomaly configuration: $config_file"
    return 1
  fi

  log_debug "Anomaly configuration loaded for plugin: $plugin_name"
  return 0
}

# Get anomaly configuration value with defaults
anomaly_get_config_value() {
  local plugin_name="$1"
  local key="$2"
  local default_value="$3"

  local value
  value=$(util_config_get_value "$key" "$default_value" "anomaly_${plugin_name}")
  echo "$value"
}

# Run anomaly detection for all configured metrics - REFACTORED
anomaly_run_detection() {
  local plugin_results="$1"

  if ! util_require_param "$plugin_results" "plugin_results"; then
    return 1
  fi

  log_debug "Running anomaly detection"

  local anomaly_results="[]"

  # Process each plugin result using new JSON utilities
  if command_exists jq; then
    echo "$plugin_results" | jq -r '.plugins[]? | "\(.name)|\(.metrics.value // 0)"' | while IFS='|' read -r plugin_name metric_value; do
      if [[ -n "$plugin_name" && -n "$metric_value" ]]; then
        # Sanitize plugin name
        plugin_name=$(util_sanitize_input "$plugin_name")

        # Store the metric data
        store_metric_data "$plugin_name" "value" "$metric_value"

        # Check for anomaly configuration
        local config_file="$ANOMALY_CONFIG_DIR/${plugin_name}_anomaly.conf"
        if util_validate_file_exists "$config_file" "Anomaly config"; then
          # Load configuration using unified parser
          if anomaly_parse_config "$config_file" "$plugin_name"; then
            # Run anomaly detection
            local anomaly_result
            anomaly_result=$(detect_statistical_anomaly "$plugin_name" "value" "$metric_value" "$config_file")

            if [[ $? -eq 0 ]]; then
              # Anomaly detected
              log_info "Anomaly detected for ${plugin_name}: $metric_value"

              # Store anomaly result
              local result_file="$ANOMALY_RESULTS_DIR/${plugin_name}_$(date +%Y%m%d).log"
              echo "$anomaly_result" >>"$result_file"

              # Check if notification should be sent
              if anomaly_should_send_notification "$plugin_name" "$config_file"; then
                anomaly_send_notification "$plugin_name" "$anomaly_result"
              fi
            fi
          fi
        fi
      fi
    done
  else
    log_error "jq command not available for anomaly detection"
    return 1
  fi

  # Return completion status as JSON
  local completion_result
  completion_result=$(util_json_create_object "anomaly_detection_completed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")")
  echo "$completion_result"
}

# Check if anomaly notification should be sent - REFACTORED
anomaly_should_send_notification() {
  local plugin_name="$1"
  local config_file="$2"

  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  if ! util_require_param "$config_file" "config_file"; then
    return 1
  fi

  # Load configuration using unified parser
  if ! anomaly_parse_config "$config_file" "$plugin_name"; then
    return 1
  fi

  # Get configuration values with defaults
  local cooldown
  cooldown=$(anomaly_get_config_value "$plugin_name" "cooldown" "1800")

  local notification_threshold
  notification_threshold=$(anomaly_get_config_value "$plugin_name" "notification_threshold" "3")

  # Check cooldown
  local last_notification_file="$ANOMALY_RESULTS_DIR/${plugin_name}_last_notification"
  if util_validate_file_exists "$last_notification_file" "Last notification file"; then
    local last_notification
    last_notification=$(cat "$last_notification_file")
    local current_time
    current_time=$(date +%s)
    local time_diff=$((current_time - last_notification))

    if [[ "$time_diff" -lt "$cooldown" ]]; then
      log_debug "Anomaly notification for $plugin_name is in cooldown"
      return 1
    fi
  fi

  # Check consecutive anomaly threshold
  local consecutive_anomalies
  consecutive_anomalies=$(anomaly_get_consecutive_count "$plugin_name")

  if [[ "$consecutive_anomalies" -ge "$notification_threshold" ]]; then
    # Update last notification time
    if ! echo "$(date +%s)" >"$last_notification_file"; then
      log_error "Failed to update last notification file: $last_notification_file"
    fi
    return 0
  fi

  return 1
}

# Get consecutive anomaly count - REFACTORED
anomaly_get_consecutive_count() {
  local plugin_name="$1"

  if ! util_require_param "$plugin_name" "plugin_name"; then
    echo "0"
    return
  fi

  local today
  today=$(date +%Y%m%d)
  local result_file="$ANOMALY_RESULTS_DIR/${plugin_name}_${today}.log"

  if ! util_validate_file_exists "$result_file" "Anomaly result file"; then
    echo "0"
    return
  fi

  # Count recent consecutive anomalies
  local count=0
  local max_check=10 # Check last 10 entries

  # Use safer file reading
  if command_exists tail && command_exists tac; then
    tail -n "$max_check" "$result_file" | tac | while read -r line; do
      if [[ -n "$line" ]] && echo "$line" | jq -e '.is_anomaly == true' >/dev/null 2>&1; then
        count=$((count + 1))
      else
        break
      fi
    done | tail -n 1
  else
    # Fallback method
    echo "0"
  fi

  echo "${count:-0}"
}

# Send anomaly notification - REFACTORED
anomaly_send_notification() {
  local plugin_name="$1"
  local anomaly_result="$2"

  if ! util_require_param "$plugin_name" "plugin_name"; then
    return 1
  fi

  if ! util_require_param "$anomaly_result" "anomaly_result"; then
    return 1
  fi

  if ! command_exists jq; then
    log_warning "jq not available for anomaly notification"
    return 1
  fi

  # Validate JSON input
  if ! util_json_validate "$anomaly_result"; then
    log_error "Invalid JSON in anomaly result"
    return 1
  fi

  # Extract anomaly details using utility functions
  local current_value
  current_value=$(util_json_get_value "$anomaly_result" "current_value")

  local anomaly_type
  anomaly_type=$(util_json_get_value "$anomaly_result" "anomaly_type")

  local anomaly_score
  anomaly_score=$(util_json_get_value "$anomaly_result" "anomaly_score")

  # Create notification message with proper escaping
  local message="Anomaly detected in $(util_json_escape "$plugin_name"): Value $current_value (Score: $anomaly_score, Type: $anomaly_type)"

  # Send notification if notification system is available
  if declare -f send_notification >/dev/null; then
    send_notification 1 "$message" "anomaly" "$anomaly_result"
    log_info "Sent anomaly notification for $plugin_name"
  else
    log_warning "Notification system not available for anomaly: $plugin_name"
    return 1
  fi

  return 0
}

# Export standardized functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_system_init
  export -f anomaly_create_default_config
  export -f store_metric_data
  export -f detect_statistical_anomaly
  export -f detect_trend_anomaly
  export -f detect_spike_anomaly
  export -f anomaly_parse_config
  export -f anomaly_get_config_value
  export -f anomaly_run_detection
  export -f anomaly_should_send_notification
  export -f anomaly_get_consecutive_count
  export -f anomaly_send_notification
fi
