#!/bin/bash
#
# ServerSentry v2 - Memory Monitoring Plugin
#
# This plugin monitors memory usage and alerts when thresholds are exceeded

# Plugin metadata
memory_plugin_name="memory"
memory_plugin_version="1.0"
memory_plugin_description="Monitors memory usage and performance"
memory_plugin_author="ServerSentry Team"

# Default configuration
memory_threshold=90
memory_warning_threshold=80
memory_check_interval=60
memory_include_swap=true
memory_include_buffers_cache=false

# Return plugin information
memory_plugin_info() {
  echo "Memory Monitoring Plugin v${memory_plugin_version}"
}

# Configure the plugin
memory_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if ! [[ "$memory_threshold" =~ ^[0-9]+$ ]] || [ "$memory_threshold" -gt 100 ]; then
    log_error "Invalid memory threshold: $memory_threshold (must be 0-100)"
    return 1
  fi

  if ! [[ "$memory_warning_threshold" =~ ^[0-9]+$ ]] || [ "$memory_warning_threshold" -gt 100 ]; then
    log_error "Invalid memory warning threshold: $memory_warning_threshold (must be 0-100)"
    return 1
  fi

  if [ "$memory_warning_threshold" -gt "$memory_threshold" ]; then
    log_warning "Warning threshold ($memory_warning_threshold) is higher than critical threshold ($memory_threshold), swapping values"
    local temp=$memory_threshold
    memory_threshold=$memory_warning_threshold
    memory_warning_threshold=$temp
  fi

  log_debug "Memory plugin configured with: threshold=$memory_threshold, warning=$memory_warning_threshold"

  return 0
}

# Perform memory check
memory_plugin_check() {
  local result
  local status_code=0
  local status_message="OK"
  local total_memory=0
  local used_memory=0
  local free_memory=0
  local swap_total=0
  local swap_used=0

  # Get memory usage based on OS
  local os_type
  os_type=$(get_os_type)

  case "$os_type" in
  linux)
    # Linux-style - using free
    if command_exists free; then
      # Get memory information
      local mem_info
      mem_info=$(free -b)

      # Parse total memory
      total_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')

      # Parse used memory (depending on configuration)
      if [ "$memory_include_buffers_cache" = "true" ]; then
        # Include buffers/cache in used memory
        used_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
      else
        # Exclude buffers/cache from used memory
        used_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $3 - $6 - $7}')
      fi

      # Calculate free memory
      free_memory=$((total_memory - used_memory))

      # Get swap information if needed
      if [ "$memory_include_swap" = "true" ]; then
        swap_total=$(echo "$mem_info" | awk '/^Swap:/ {print $2}')
        swap_used=$(echo "$mem_info" | awk '/^Swap:/ {print $3}')
      fi
    else
      result="unknown"
      status_code=3
      status_message="Cannot determine memory usage: 'free' command not found"
    fi
    ;;

  macos)
    # macOS-style - using vm_stat
    if command_exists vm_stat; then
      # Get page size and memory stats
      local page_size
      page_size=$(sysctl -n hw.pagesize)

      local vm_stat_output
      vm_stat_output=$(vm_stat)

      # Calculate total physical memory
      total_memory=$(sysctl -n hw.memsize)

      # Parse memory pages
      local pages_free
      pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')

      local pages_active
      pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')

      local pages_inactive
      pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')

      local pages_speculative
      pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')

      local pages_wired
      pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')

      # Calculate used memory - use bc for floating point arithmetic
      # Convert page values to integers first to avoid issues with bash arithmetic
      local active_memory
      local wired_memory
      active_memory=$(echo "$pages_active * $page_size" | bc)
      wired_memory=$(echo "$pages_wired * $page_size" | bc)
      used_memory=$(echo "$active_memory + $wired_memory" | bc)

      # If we include inactive memory in used count
      if [ "$memory_include_buffers_cache" = "true" ]; then
        local inactive_memory
        inactive_memory=$(echo "$pages_inactive * $page_size" | bc)
        used_memory=$(echo "$used_memory + $inactive_memory" | bc)
      fi

      # Calculate free memory
      local free_pages_memory
      local speculative_memory
      free_pages_memory=$(echo "$pages_free * $page_size" | bc)
      speculative_memory=$(echo "$pages_speculative * $page_size" | bc)
      free_memory=$(echo "$free_pages_memory + $speculative_memory" | bc)

      # Get swap information if needed
      if [ "$memory_include_swap" = "true" ]; then
        local swap_info
        swap_info=$(sysctl -n vm.swapusage)

        # Parse swap total and used
        swap_total=$(echo "$swap_info" | awk -F'[M ]' '{print $3}')
        swap_total=$(echo "$swap_total * 1024 * 1024" | bc) # Convert MB to bytes

        swap_used=$(echo "$swap_info" | awk -F'[M ]' '{print $6}')
        swap_used=$(echo "$swap_used * 1024 * 1024" | bc) # Convert MB to bytes
      fi
    else
      result="unknown"
      status_code=3
      status_message="Cannot determine memory usage: 'vm_stat' command not found"
    fi
    ;;

  *)
    # Unsupported OS
    result="unknown"
    status_code=3
    status_message="Unsupported OS type: $os_type"
    ;;
  esac

  # Calculate memory usage percentage if we have values
  if [ "$total_memory" -gt 0 ] && [ "$used_memory" -ge 0 ]; then
    # Calculate the percentage
    result=$(echo "scale=1; $used_memory * 100 / $total_memory" | bc)

    # Check thresholds
    if (($(echo "$result >= $memory_threshold" | bc -l))); then
      status_code=2
      status_message="CRITICAL: Memory usage is ${result}%, threshold: ${memory_threshold}%"
    elif (($(echo "$result >= $memory_warning_threshold" | bc -l))); then
      status_code=1
      status_message="WARNING: Memory usage is ${result}%, threshold: ${memory_warning_threshold}%"
    else
      status_message="OK: Memory usage is ${result}%"
    fi

    # Format memory values for output
    total_memory_human=$(format_bytes "$total_memory" 2>&1 || echo "$total_memory B")
    used_memory_human=$(format_bytes "$used_memory" 2>&1 || echo "$used_memory B")
    free_memory_human=$(format_bytes "$free_memory" 2>&1 || echo "$free_memory B")

    # Format swap if available
    if [ "$memory_include_swap" = "true" ] && [[ $(echo "$swap_total > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
      swap_total_human=$(format_bytes "$swap_total")
      swap_used_human=$(format_bytes "$swap_used")

      # Calculate swap percentage
      if [[ $(echo "$swap_total > 0" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        swap_percent=$(echo "scale=1; $swap_used * 100 / $swap_total" | bc)
      else
        swap_percent="0.0"
      fi

      # Add swap to status message
      status_message="${status_message} (Swap: ${swap_percent}%)"
    fi
  fi

  # Get timestamp
  local timestamp
  timestamp=$(get_timestamp)

  # Return standardized output format
  cat <<EOF
{
  "plugin": "memory",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "usage_percent": ${result:-0},
    "total_memory": ${total_memory:-0},
    "used_memory": ${used_memory:-0},
    "free_memory": ${free_memory:-0},
    "total_memory_human": "${total_memory_human:-0B}",
    "used_memory_human": "${used_memory_human:-0B}",
    "free_memory_human": "${free_memory_human:-0B}",
    "threshold": ${memory_threshold},
    "warning_threshold": ${memory_warning_threshold},
    "swap_total": ${swap_total:-0},
    "swap_used": ${swap_used:-0},
    "swap_percent": ${swap_percent:-0}
  },
  "timestamp": "${timestamp}"
}
EOF
}
