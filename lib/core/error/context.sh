#!/usr/bin/env bash
#
# ServerSentry v2 - Error Context Module
#
# This module provides error context creation, logging, and stack trace generation

# Function: error_create_context
# Description: Create comprehensive error context with enhanced information
# Parameters:
#   $1 (numeric): exit code
#   $2 (numeric): line number
#   $3 (numeric): bash line number
#   $4 (string): failed command
#   $5 (string): function stack
#   $6 (numeric): severity level
# Returns:
#   JSON error context via stdout
# Example:
#   context=$(error_create_context 1 42 41 "cat /missing" "main" 2)
# Dependencies:
#   - util_error_validate_input
#   - error_get_severity_name
#   - error_get_user_friendly_message
error_create_context() {
  local exit_code="$1"
  local line_number="$2"
  local bash_line_number="$3"
  local failed_command="$4"
  local function_stack="$5"
  local severity="$6"

  # Validate inputs
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    echo '{"error": "Invalid exit code"}'
    return 1
  fi

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    echo '{"error": "Invalid failed command"}'
    return 1
  fi

  # Get timestamp in ISO format
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")

  # Get system information
  local hostname user pwd
  hostname=$(hostname 2>/dev/null || echo "unknown")
  user=$(whoami 2>/dev/null || echo "unknown")
  pwd=$(pwd 2>/dev/null || echo "unknown")

  # Get error message and severity name
  local error_message severity_name
  error_message=$(error_get_user_friendly_message "$exit_code" "$failed_command")
  severity_name=$(error_get_severity_name "$severity")

  # Escape strings for JSON
  local escaped_command escaped_stack escaped_message escaped_pwd
  escaped_command=$(echo "$failed_command" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
  escaped_stack=$(echo "$function_stack" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
  escaped_message=$(echo "$error_message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
  escaped_pwd=$(echo "$pwd" | sed 's/\\/\\\\/g; s/"/\\"/g')

  # Get additional system information
  local serversentry_version bash_version
  serversentry_version=$(error_get_serversentry_version)
  bash_version="${BASH_VERSION:-unknown}"

  # Create base JSON context
  local context="{
    \"timestamp\": \"$timestamp\",
    \"hostname\": \"$hostname\",
    \"user\": \"$user\",
    \"working_directory\": \"$escaped_pwd\",
    \"exit_code\": $exit_code,
    \"line_number\": ${line_number:-0},
    \"bash_line_number\": ${bash_line_number:-0},
    \"failed_command\": \"$escaped_command\",
    \"function_stack\": \"$escaped_stack\",
    \"severity\": ${severity:-1},
    \"severity_name\": \"$severity_name\",
    \"error_message\": \"$escaped_message\",
    \"process_id\": $$,
    \"parent_process_id\": ${PPID:-0},
    \"bash_version\": \"$bash_version\",
    \"serversentry_version\": \"$serversentry_version\""

  # Add stack trace if enabled
  if [[ "${ERROR_STACK_TRACE_ENABLED:-true}" == "true" ]]; then
    local stack_trace
    stack_trace=$(error_generate_stack_trace)
    local escaped_stack_trace
    escaped_stack_trace=$(echo "$stack_trace" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
    context="${context},\"stack_trace\": \"$escaped_stack_trace\""
  fi

  # Add system state information
  local system_info
  system_info=$(error_get_system_info_json)
  if [[ -n "$system_info" && "$system_info" != "{}" ]]; then
    # Remove the closing brace from context and system_info opening brace
    context="${context%\}}"
    system_info="${system_info#\{}"
    context="${context},${system_info}"
  else
    context="${context}}"
  fi

  echo "$context"
  return 0
}

# Function: error_log_with_context
# Description: Log error with full context to multiple destinations
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   0 - success
#   1 - failure
# Example:
#   error_log_with_context "$error_context"
# Dependencies:
#   - util_error_validate_input
#   - ERROR_LOG_FILE variable
error_log_with_context() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    return 1
  fi

  # Extract key information for logging using safer parsing
  local exit_code severity_name failed_command error_message
  exit_code=$(echo "$error_context" | grep -o '"exit_code": *[0-9]*' | grep -o '[0-9]*' || echo "unknown")
  severity_name=$(echo "$error_context" | grep -o '"severity_name": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  failed_command=$(echo "$error_context" | grep -o '"failed_command": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  error_message=$(echo "$error_context" | grep -o '"error_message": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")

  # Log to main log with structured format
  log_error "[$severity_name] Error $exit_code: $error_message" "error"
  log_debug "Failed command: $failed_command" "error"

  # Log full context to error log file
  local error_log_file="${ERROR_LOG_FILE:-${BASE_DIR}/logs/error.log}"
  local error_log_dir
  error_log_dir=$(dirname "$error_log_file")

  # Ensure error log directory exists
  if [[ ! -d "$error_log_dir" ]]; then
    if ! mkdir -p "$error_log_dir" 2>/dev/null; then
      log_warning "Cannot create error log directory: $error_log_dir" "error"
      return 1
    fi
  fi

  # Write to error log file with timestamp
  if [[ -w "$error_log_dir" ]]; then
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp ERROR_CONTEXT: $error_context" >>"$error_log_file" 2>/dev/null
  else
    log_warning "Cannot write to error log file: $error_log_file" "error"
  fi

  # Log to specialized error log if different
  if [[ -n "${ERROR_LOG:-}" && "$ERROR_LOG" != "$error_log_file" ]]; then
    local specialized_error_dir
    specialized_error_dir=$(dirname "$ERROR_LOG")

    if [[ -d "$specialized_error_dir" && -w "$specialized_error_dir" ]]; then
      echo "$timestamp ERROR_CONTEXT: $error_context" >>"$ERROR_LOG" 2>/dev/null
    fi
  fi

  return 0
}

# Function: error_generate_stack_trace
# Description: Generate detailed stack trace with enhanced information
# Parameters: None
# Returns:
#   Stack trace via stdout
# Example:
#   trace=$(error_generate_stack_trace)
# Dependencies: None
error_generate_stack_trace() {
  local stack_trace=""
  local i=1

  # Skip the first few frames (this function and error handlers)
  while [[ $i -lt ${#FUNCNAME[@]} ]]; do
    local func="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$((i - 1))]}"

    # Skip internal error handling functions
    if [[ "$func" =~ ^(error_|_error_|util_error_) ]]; then
      ((i++))
      continue
    fi

    # Skip if function name is empty or main
    if [[ -n "$func" && "$func" != "main" ]]; then
      # Get relative path for cleaner output
      local relative_file="$file"
      if [[ "$file" == "${BASE_DIR}"* ]]; then
        relative_file="${file#"${BASE_DIR}"/}"
      fi

      stack_trace+="  at $func ($relative_file:$line)\\n"
    fi

    ((i++))
  done

  # If no meaningful stack trace, provide basic information
  if [[ -z "$stack_trace" ]]; then
    local current_script="${BASH_SOURCE[1]:-unknown}"
    local current_line="${BASH_LINENO[0]:-0}"
    stack_trace="  at ${current_script}:${current_line}\\n"
  fi

  echo "$stack_trace"
}

# Function: error_get_system_info_json
# Description: Get system information in JSON format for error context
# Parameters: None
# Returns:
#   System information JSON via stdout
# Example:
#   info=$(error_get_system_info_json)
# Dependencies: None
error_get_system_info_json() {
  local system_info="{"

  # Get system load if available
  if [[ -r /proc/loadavg ]]; then
    local load_avg
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "unknown")
    system_info+="\"load_average\": \"$load_avg\","
  fi

  # Get memory information
  local memory_info=""
  if [[ -r /proc/meminfo ]]; then
    local mem_total mem_available
    mem_total=$(grep '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_available=$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")

    if [[ "$mem_total" -gt 0 && "$mem_available" -gt 0 ]]; then
      local mem_used_percent
      mem_used_percent=$(echo "scale=1; ($mem_total - $mem_available) * 100 / $mem_total" | bc 2>/dev/null || echo "0")
      memory_info="\"memory_usage_percent\": \"$mem_used_percent\","
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS memory information
    if command -v vm_stat >/dev/null 2>&1; then
      local vm_output
      vm_output=$(vm_stat 2>/dev/null)
      if [[ -n "$vm_output" ]]; then
        memory_info="\"memory_info\": \"available\","
      fi
    fi
  fi
  system_info+="$memory_info"

  # Get disk space for current directory
  local disk_usage
  disk_usage=$(df . 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "unknown")
  if [[ "$disk_usage" != "unknown" ]]; then
    system_info+="\"disk_usage_percent\": \"$disk_usage\","
  fi

  # Get uptime if available
  if [[ -r /proc/uptime ]]; then
    local uptime_seconds
    uptime_seconds=$(cat /proc/uptime 2>/dev/null | awk '{print int($1)}' || echo "0")
    system_info+="\"uptime_seconds\": $uptime_seconds,"
  elif command -v uptime >/dev/null 2>&1; then
    local uptime_info
    uptime_info=$(uptime 2>/dev/null | sed 's/.*up *//; s/, *[0-9]* user.*//' || echo "unknown")
    if [[ "$uptime_info" != "unknown" ]]; then
      system_info+="\"uptime\": \"$uptime_info\","
    fi
  fi

  # Get current shell and environment info
  system_info+="\"shell\": \"${SHELL:-unknown}\","
  system_info+="\"term\": \"${TERM:-unknown}\","
  system_info+="\"lang\": \"${LANG:-unknown}\","

  # Get error statistics if available
  local error_stats
  error_stats=$(error_get_error_statistics_json)
  if [[ -n "$error_stats" && "$error_stats" != "{}" ]]; then
    # Remove braces and add to system_info
    error_stats="${error_stats#\{}"
    error_stats="${error_stats%\}}"
    system_info+="$error_stats,"
  fi

  # Remove trailing comma and close JSON
  system_info="${system_info%,}}"

  echo "$system_info"
}

# Function: error_get_error_statistics_json
# Description: Get error statistics in JSON format
# Parameters: None
# Returns:
#   Error statistics JSON via stdout
# Example:
#   stats=$(error_get_error_statistics_json)
# Dependencies:
#   - ERROR_STATISTICS array or variables
error_get_error_statistics_json() {
  local stats="{"

  if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
    # Modern bash with associative array support
    if [[ -n "${ERROR_STATISTICS[total_errors]:-}" ]]; then
      stats+="\"total_errors\": ${ERROR_STATISTICS[total_errors]},"
      stats+="\"recovered_errors\": ${ERROR_STATISTICS[recovered_errors]:-0},"
      stats+="\"critical_errors\": ${ERROR_STATISTICS[critical_errors]:-0},"
      stats+="\"last_error_time\": ${ERROR_STATISTICS[last_error_time]:-0}"
    fi
  else
    # Fallback for older bash versions
    if [[ -n "${ERROR_STATISTICS_total_errors:-}" ]]; then
      stats+="\"total_errors\": ${ERROR_STATISTICS_total_errors},"
      stats+="\"recovered_errors\": ${ERROR_STATISTICS_recovered_errors:-0},"
      stats+="\"critical_errors\": ${ERROR_STATISTICS_critical_errors:-0},"
      stats+="\"last_error_time\": ${ERROR_STATISTICS_last_error_time:-0}"
    fi
  fi

  stats+="}"

  # Return empty object if no statistics
  if [[ "$stats" == "{}" ]]; then
    echo "{}"
  else
    echo "$stats"
  fi
}

# Function: error_get_serversentry_version
# Description: Get ServerSentry version information
# Parameters: None
# Returns:
#   Version string via stdout
# Example:
#   version=$(error_get_serversentry_version)
# Dependencies: None
error_get_serversentry_version() {
  # Try to get version from various sources
  local version="unknown"

  # Check for version file
  if [[ -f "${BASE_DIR}/VERSION" ]]; then
    version=$(cat "${BASE_DIR}/VERSION" 2>/dev/null | head -1 | tr -d '\n\r' || echo "unknown")
  elif [[ -f "${BASE_DIR}/version.txt" ]]; then
    version=$(cat "${BASE_DIR}/version.txt" 2>/dev/null | head -1 | tr -d '\n\r' || echo "unknown")
  fi

  # Check for git information if in a git repository
  if [[ "$version" == "unknown" && -d "${BASE_DIR}/.git" ]]; then
    if command -v git >/dev/null 2>&1; then
      local git_version
      git_version=$(cd "$BASE_DIR" && git describe --tags --always 2>/dev/null || echo "")
      if [[ -n "$git_version" ]]; then
        version="git-$git_version"
      fi
    fi
  fi

  # Fallback to default version
  if [[ "$version" == "unknown" ]]; then
    version="v2.0.0"
  fi

  echo "$version"
}

# Function: error_format_context_for_display
# Description: Format error context for human-readable display
# Parameters:
#   $1 (string): error context JSON
# Returns:
#   Formatted text via stdout
# Example:
#   display=$(error_format_context_for_display "$context")
# Dependencies:
#   - util_error_validate_input
error_format_context_for_display() {
  local error_context="$1"

  if ! util_error_validate_input "$error_context" "error_context" "required"; then
    echo "Invalid error context"
    return 1
  fi

  # Extract information using grep and sed for compatibility
  local timestamp hostname user exit_code severity_name error_message failed_command

  timestamp=$(echo "$error_context" | grep -o '"timestamp": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  hostname=$(echo "$error_context" | grep -o '"hostname": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  user=$(echo "$error_context" | grep -o '"user": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  exit_code=$(echo "$error_context" | grep -o '"exit_code": *[0-9]*' | grep -o '[0-9]*' || echo "unknown")
  severity_name=$(echo "$error_context" | grep -o '"severity_name": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  error_message=$(echo "$error_context" | grep -o '"error_message": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")
  failed_command=$(echo "$error_context" | grep -o '"failed_command": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "unknown")

  # Format for display
  cat <<EOF
Error Report
============
Time: $timestamp
Host: $hostname
User: $user
Severity: $severity_name (Exit Code: $exit_code)

Error: $error_message

Failed Command: $failed_command

EOF

  # Add stack trace if present
  local stack_trace
  stack_trace=$(echo "$error_context" | grep -o '"stack_trace": *"[^"]*"' | sed 's/.*": *"//; s/".*//' || echo "")
  if [[ -n "$stack_trace" ]]; then
    echo "Stack Trace:"
    echo "$stack_trace" | sed 's/\\n/\n/g'
    echo ""
  fi

  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f error_create_context
  export -f error_log_with_context
  export -f error_generate_stack_trace
  export -f error_get_system_info_json
  export -f error_get_error_statistics_json
  export -f error_get_serversentry_version
  export -f error_format_context_for_display
fi
