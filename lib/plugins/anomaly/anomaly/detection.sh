#!/usr/bin/env bash
#
# ServerSentry v2 - Anomaly Detection Core Module
#
# This module implements statistical anomaly detection algorithms including
# outlier detection, trend analysis, and spike detection using moving averages
# and standard deviations.

# Prevent multiple sourcing
if [[ "${ANOMALY_DETECTION_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
ANOMALY_DETECTION_MODULE_LOADED=true
export ANOMALY_DETECTION_MODULE_LOADED

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

# Function: anomaly_detection_init
# Description: Initialize the anomaly detection core module
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   anomaly_detection_init
# Dependencies:
#   - util_error_validate_input
anomaly_detection_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for anomaly_detection_init: expected 0, got $#" "anomaly_detection"
    return 1
  fi

  # Validate required commands
  local required_commands=("awk" "bc" "tail" "head")
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_error "Required command not found: $cmd" "anomaly_detection"
      return 1
    fi
  done

  log_debug "Anomaly detection core module initialized" "anomaly_detection"
  return 0
}

# Function: anomaly_calculate_statistics
# Description: Calculate comprehensive statistics for a dataset including mean, standard deviation, median, and quartiles
# Parameters:
#   $1 (string): data file path
#   $2 (numeric): window size for analysis
# Returns:
#   0 - success (outputs: count,mean,std_dev,median,q1,q3,min,max)
#   1 - failure or insufficient data
# Example:
#   stats=$(anomaly_calculate_statistics "/path/to/data.dat" 20)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_calculate_statistics() {
  if ! util_error_validate_input "anomaly_calculate_statistics" "2" "$#"; then
    return 1
  fi

  local data_file="$1"
  local window_size="$2"

  # Validate inputs
  if [[ ! -f "$data_file" ]]; then
    echo "0,0,0,0,0,0,0,0" # count,mean,std_dev,median,q1,q3,min,max
    return 1
  fi

  if [[ ! "$window_size" =~ ^[0-9]+$ ]] || [[ "$window_size" -le 0 ]]; then
    log_error "Invalid window size: $window_size" "anomaly_detection"
    return 1
  fi

  # Get recent data points with safe execution
  local values
  if ! values=$(util_error_safe_execute "tail -n $window_size '$data_file' | cut -d',' -f2" 10); then
    log_error "Failed to extract values from data file: $data_file" "anomaly_detection"
    echo "0,0,0,0,0,0,0,0"
    return 1
  fi

  if [[ -z "$values" ]]; then
    echo "0,0,0,0,0,0,0,0"
    return 1
  fi

  # Calculate comprehensive statistics using awk
  echo "$values" | awk '
  BEGIN {
    count = 0
    sum = 0
    sum_sq = 0
    min_val = ""
    max_val = ""
  }
  {
    if ($1 != "" && $1 ~ /^-?[0-9]*\.?[0-9]+$/) {
      values[++count] = $1
      sum += $1
      sum_sq += $1 * $1

      if (min_val == "" || $1 < min_val) min_val = $1
      if (max_val == "" || $1 > max_val) max_val = $1
    }
  }
  END {
    if (count == 0) {
      print "0,0,0,0,0,0,0,0"
      exit
    }

    mean = sum / count
    variance = (sum_sq / count) - (mean * mean)
    std_dev = sqrt(variance > 0 ? variance : 0)

    # Sort values for median and quartiles
    asort(values)

    # Calculate median
    if (count % 2 == 1) {
      median = values[int(count/2) + 1]
    } else {
      median = (values[count/2] + values[count/2 + 1]) / 2
    }

    # Calculate quartiles
    q1_pos = int(count * 0.25)
    q3_pos = int(count * 0.75)

    if (q1_pos < 1) q1_pos = 1
    if (q3_pos > count) q3_pos = count

    q1 = values[q1_pos]
    q3 = values[q3_pos]

    printf "%.0f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", count, mean, std_dev, median, q1, q3, min_val, max_val
  }'
}

# Function: anomaly_detect_statistical_outliers
# Description: Detect statistical anomalies using Z-score analysis and configurable sensitivity
# Parameters:
#   $1 (string): plugin name
#   $2 (string): metric name
#   $3 (numeric): current value
#   $4 (string): data file path
#   $5 (numeric): sensitivity threshold (default: 2.0)
#   $6 (numeric): minimum data points (default: 10)
# Returns:
#   0 - anomaly detected (outputs JSON result)
#   1 - no anomaly or insufficient data
# Example:
#   result=$(anomaly_detect_statistical_outliers "cpu" "usage" 95.5 "/path/to/data.dat" 2.0 10)
# Dependencies:
#   - anomaly_calculate_statistics
#   - util_error_validate_input
anomaly_detect_statistical_outliers() {
  if ! util_error_validate_input "anomaly_detect_statistical_outliers" "4" "$#"; then
    return 1
  fi

  local plugin_name="$1"
  local metric_name="$2"
  local current_value="$3"
  local data_file="$4"
  local sensitivity="${5:-2.0}"
  local min_data_points="${6:-10}"

  # Validate numeric inputs
  if [[ ! "$current_value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
    log_error "Invalid current value: $current_value" "anomaly_detection"
    return 1
  fi

  if [[ ! "$sensitivity" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    log_error "Invalid sensitivity: $sensitivity" "anomaly_detection"
    return 1
  fi

  # Calculate statistics
  local stats
  if ! stats=$(anomaly_calculate_statistics "$data_file" 50); then
    log_debug "Failed to calculate statistics for $plugin_name.$metric_name" "anomaly_detection"
    return 1
  fi

  local count mean std_dev median q1 q3 min_val max_val
  IFS=',' read -r count mean std_dev median q1 q3 min_val max_val <<<"$stats"

  # Check if we have enough data points
  if [[ "$count" -lt "$min_data_points" ]]; then
    log_debug "Insufficient data points for $plugin_name.$metric_name: $count < $min_data_points" "anomaly_detection"
    return 1
  fi

  # Detect outliers using Z-score
  local is_anomaly=false
  local anomaly_type=""
  local anomaly_score=0
  local confidence_level="low"

  # Z-score calculation with error handling
  if [[ $(echo "$std_dev > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    local z_score
    z_score=$(echo "scale=4; ($current_value - $mean) / $std_dev" | bc 2>/dev/null || echo "0")
    local abs_z_score
    abs_z_score=$(echo "$z_score" | sed 's/-//')

    # Check if anomaly based on sensitivity threshold
    if [[ $(echo "$abs_z_score > $sensitivity" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      is_anomaly=true
      anomaly_score="$z_score"

      # Determine anomaly type and confidence
      if [[ $(echo "$z_score > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        anomaly_type="high_outlier"
      else
        anomaly_type="low_outlier"
      fi

      # Determine confidence level
      if [[ $(echo "$abs_z_score > 3" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        confidence_level="high"
      elif [[ $(echo "$abs_z_score > 2.5" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        confidence_level="medium"
      fi
    fi
  fi

  # Additional IQR-based detection for robustness
  local iqr
  iqr=$(echo "scale=4; $q3 - $q1" | bc 2>/dev/null || echo "0")

  if [[ $(echo "$iqr > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    local iqr_lower
    local iqr_upper
    iqr_lower=$(echo "scale=4; $q1 - (1.5 * $iqr)" | bc 2>/dev/null || echo "0")
    iqr_upper=$(echo "scale=4; $q3 + (1.5 * $iqr)" | bc 2>/dev/null || echo "0")

    if [[ $(echo "$current_value < $iqr_lower" | bc 2>/dev/null || echo "0") -eq 1 ]] ||
      [[ $(echo "$current_value > $iqr_upper" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      if [[ "$is_anomaly" != "true" ]]; then
        is_anomaly=true
        anomaly_type="iqr_outlier"
        confidence_level="medium"
      else
        anomaly_type="${anomaly_type},iqr_outlier"
      fi
    fi
  fi

  # Generate result JSON
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$is_anomaly" == "true" ]]; then
    cat <<EOF
{
  "plugin": "$plugin_name",
  "metric": "$metric_name",
  "current_value": $current_value,
  "is_anomaly": true,
  "anomaly_type": "$anomaly_type",
  "anomaly_score": $anomaly_score,
  "confidence_level": "$confidence_level",
  "statistics": {
    "count": $count,
    "mean": $mean,
    "std_dev": $std_dev,
    "median": $median,
    "q1": $q1,
    "q3": $q3,
    "min": $min_val,
    "max": $max_val,
    "iqr": $iqr
  },
  "thresholds": {
    "sensitivity": $sensitivity,
    "iqr_lower": $iqr_lower,
    "iqr_upper": $iqr_upper
  },
  "timestamp": "$timestamp"
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
    "median": $median,
    "q1": $q1,
    "q3": $q3,
    "min": $min_val,
    "max": $max_val
  },
  "timestamp": "$timestamp"
}
EOF
    return 1
  fi
}

# Function: anomaly_detect_trend_patterns
# Description: Detect trend anomalies using linear regression analysis and slope calculation
# Parameters:
#   $1 (string): data file path
#   $2 (numeric): window size for trend analysis
#   $3 (numeric): trend sensitivity threshold (default: 2.0)
# Returns:
#   0 - trend anomaly detected
#   1 - no trend anomaly
# Example:
#   trend=$(anomaly_detect_trend_patterns "/path/to/data.dat" 20 2.0)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_detect_trend_patterns() {
  if ! util_error_validate_input "anomaly_detect_trend_patterns" "2" "$#"; then
    return 1
  fi

  local data_file="$1"
  local window_size="$2"
  local trend_sensitivity="${3:-2.0}"

  if [[ ! -f "$data_file" ]]; then
    echo "none"
    return 1
  fi

  # Validate window size
  if [[ ! "$window_size" =~ ^[0-9]+$ ]] || [[ "$window_size" -lt 3 ]]; then
    echo "none"
    return 1
  fi

  # Get recent values for trend analysis
  local values
  if ! values=$(util_error_safe_execute "tail -n $window_size '$data_file' | cut -d',' -f2" 10); then
    echo "none"
    return 1
  fi

  if [[ -z "$values" ]]; then
    echo "none"
    return 1
  fi

  # Calculate trend using enhanced linear regression
  local trend_result
  trend_result=$(echo "$values" | awk -v sensitivity="$trend_sensitivity" '
  BEGIN {
    count = 0
    sum_x = 0
    sum_y = 0
    sum_xy = 0
    sum_x2 = 0
    sum_y2 = 0
  }
  {
    if ($1 != "" && $1 ~ /^-?[0-9]*\.?[0-9]+$/) {
      count++
      x = count
      y = $1
      sum_x += x
      sum_y += y
      sum_xy += x * y
      sum_x2 += x * x
      sum_y2 += y * y
    }
  }
  END {
    if (count < 3) {
      print "none"
      exit
    }

    # Calculate slope and correlation coefficient
    denominator = count * sum_x2 - sum_x * sum_x
    if (denominator == 0) {
      print "none"
      exit
    }

    slope = (count * sum_xy - sum_x * sum_y) / denominator

    # Calculate correlation coefficient for trend strength
    y_denominator = count * sum_y2 - sum_y * sum_y
    if (y_denominator <= 0) {
      correlation = 0
    } else {
      correlation = (count * sum_xy - sum_x * sum_y) / sqrt(denominator * y_denominator)
    }

    # Determine trend significance based on slope and correlation
    abs_slope = (slope < 0) ? -slope : slope
    abs_correlation = (correlation < 0) ? -correlation : correlation

    # Strong trend detection
    if (abs_slope > sensitivity && abs_correlation > 0.7) {
      if (slope > sensitivity) {
        print "steep_upward_trend"
      } else if (slope < -sensitivity) {
        print "steep_downward_trend"
      } else {
        print "none"
      }
    } else if (abs_slope > (sensitivity * 0.5) && abs_correlation > 0.5) {
      if (slope > 0) {
        print "moderate_upward_trend"
      } else {
        print "moderate_downward_trend"
      }
    } else {
      print "none"
    }
  }')

  echo "$trend_result"

  if [[ "$trend_result" != "none" ]]; then
    return 0
  else
    return 1
  fi
}

# Function: anomaly_detect_spike_patterns
# Description: Detect sudden spikes or drops in values compared to recent patterns
# Parameters:
#   $1 (string): data file path
#   $2 (numeric): current value
#   $3 (numeric): baseline mean
#   $4 (numeric): baseline standard deviation
#   $5 (numeric): spike sensitivity multiplier (default: 3.0)
# Returns:
#   0 - spike detected
#   1 - no spike detected
# Example:
#   spike=$(anomaly_detect_spike_patterns "/path/to/data.dat" 95.5 45.2 8.1 3.0)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
anomaly_detect_spike_patterns() {
  if ! util_error_validate_input "anomaly_detect_spike_patterns" "4" "$#"; then
    return 1
  fi

  local data_file="$1"
  local current_value="$2"
  local baseline_mean="$3"
  local baseline_std_dev="$4"
  local spike_sensitivity="${5:-3.0}"

  # Validate inputs
  if [[ ! -f "$data_file" ]]; then
    echo "none"
    return 1
  fi

  for val in "$current_value" "$baseline_mean" "$baseline_std_dev" "$spike_sensitivity"; do
    if [[ ! "$val" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
      echo "none"
      return 1
    fi
  done

  # Get the last few values for recent pattern analysis
  local recent_values
  if ! recent_values=$(util_error_safe_execute "tail -n 5 '$data_file' | cut -d',' -f2" 10); then
    echo "none"
    return 1
  fi

  if [[ -z "$recent_values" ]]; then
    echo "none"
    return 1
  fi

  # Calculate recent statistics and spike detection
  local spike_result
  spike_result=$(echo "$recent_values" | awk -v current="$current_value" -v mean="$baseline_mean" -v std_dev="$baseline_std_dev" -v sensitivity="$spike_sensitivity" '
  BEGIN {
    count = 0
    sum = 0
    sum_sq = 0
  }
  {
    if ($1 != "" && $1 ~ /^-?[0-9]*\.?[0-9]+$/) {
      values[++count] = $1
      sum += $1
      sum_sq += $1 * $1
    }
  }
  END {
    if (count == 0) {
      print "none"
      exit
    }

    # Calculate recent mean and variance
    recent_mean = sum / count
    recent_variance = (sum_sq / count) - (recent_mean * recent_mean)
    recent_std_dev = sqrt(recent_variance > 0 ? recent_variance : 0)

    # Multiple spike detection methods

    # Method 1: Deviation from recent pattern
    if (recent_std_dev > 0) {
      recent_z_score = (current - recent_mean) / recent_std_dev
      abs_recent_z = (recent_z_score < 0) ? -recent_z_score : recent_z_score

      if (abs_recent_z > sensitivity) {
        if (recent_z_score > 0) {
          print "positive_spike"
          exit
        } else {
          print "negative_spike"
          exit
        }
      }
    }

    # Method 2: Deviation from baseline
    if (std_dev > 0) {
      baseline_z_score = (current - mean) / std_dev
      abs_baseline_z = (baseline_z_score < 0) ? -baseline_z_score : baseline_z_score

      if (abs_baseline_z > (sensitivity * 1.5)) {
        if (baseline_z_score > 0) {
          print "extreme_positive_spike"
          exit
        } else {
          print "extreme_negative_spike"
          exit
        }
      }
    }

    # Method 3: Sudden change detection
    if (count >= 2) {
      last_value = values[count]
      value_change = current - last_value
      abs_change = (value_change < 0) ? -value_change : value_change

      # Calculate change relative to recent volatility
      if (recent_std_dev > 0) {
        change_ratio = abs_change / recent_std_dev
        if (change_ratio > (sensitivity * 2)) {
          if (value_change > 0) {
            print "sudden_increase"
            exit
          } else {
            print "sudden_decrease"
            exit
          }
        }
      }
    }

    print "none"
  }')

  echo "$spike_result"

  if [[ "$spike_result" != "none" ]]; then
    return 0
  else
    return 1
  fi
}

# Export all detection functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f anomaly_detection_init
  export -f anomaly_calculate_statistics
  export -f anomaly_detect_statistical_outliers
  export -f anomaly_detect_trend_patterns
  export -f anomaly_detect_spike_patterns
fi

# Initialize the module
if ! anomaly_detection_init; then
  log_error "Failed to initialize anomaly detection module" "anomaly_detection"
fi
