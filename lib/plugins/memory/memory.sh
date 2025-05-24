#!/usr/bin/env bash
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

  # Try to get memory information using compatibility layer first
  local memory_info
  memory_info=$(compat_get_memory_info 2>/dev/null)

  if [[ -n "$memory_info" && "$memory_info" != "total:0 used:0 free:0" ]]; then
    # Parse the compatibility layer output
    total_memory=$(echo "$memory_info" | awk -F: '{print $2}' | awk '{print $1}')
    used_memory=$(echo "$memory_info" | awk -F: '{print $3}' | awk '{print $1}')
    free_memory=$(echo "$memory_info" | awk -F: '{print $4}' | awk '{print $1}')

    # Convert from MB to bytes for consistency
    total_memory=$(echo "$total_memory * 1024 * 1024" | bc 2>/dev/null || awk -v n="$total_memory" 'BEGIN{print n * 1024 * 1024}')
    used_memory=$(echo "$used_memory * 1024 * 1024" | bc 2>/dev/null || awk -v n="$used_memory" 'BEGIN{print n * 1024 * 1024}')
    free_memory=$(echo "$free_memory * 1024 * 1024" | bc 2>/dev/null || awk -v n="$free_memory" 'BEGIN{print n * 1024 * 1024}')
  else
    # Fallback to OS-specific methods
    local os_type
    os_type=$(compat_get_os)

    case "$os_type" in
    linux)
      # Linux-style - using /proc/meminfo if available
      if [[ -r /proc/meminfo ]]; then
        # Parse /proc/meminfo directly
        total_memory=$(awk '/MemTotal:/ {print $2 * 1024}' /proc/meminfo)

        if [ "$memory_include_buffers_cache" = "true" ]; then
          # Include buffers/cache in used memory
          local available_memory
          available_memory=$(awk '/MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
          if [[ -n "$available_memory" ]]; then
            used_memory=$((total_memory - available_memory))
          else
            local free_mem buffers cached
            free_mem=$(awk '/MemFree:/ {print $2 * 1024}' /proc/meminfo)
            buffers=$(awk '/^Buffers:/ {print $2 * 1024}' /proc/meminfo)
            cached=$(awk '/^Cached:/ {print $2 * 1024}' /proc/meminfo)
            used_memory=$((total_memory - free_mem - buffers - cached))
          fi
        else
          # Exclude buffers/cache from used memory
          local available_memory
          available_memory=$(awk '/MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
          if [[ -n "$available_memory" ]]; then
            used_memory=$((total_memory - available_memory))
          else
            local free_mem
            free_mem=$(awk '/MemFree:/ {print $2 * 1024}' /proc/meminfo)
            used_memory=$((total_memory - free_mem))
          fi
        fi

        free_memory=$((total_memory - used_memory))

      elif util_command_exists free; then
        # Fallback to free command
        local mem_info
        mem_info=$(free -b)
        total_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $2}')

        if [ "$memory_include_buffers_cache" = "true" ]; then
          used_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $3}')
        else
          used_memory=$(echo "$mem_info" | awk '/^Mem:/ {print $3 - $6 - $7}')
        fi

        free_memory=$((total_memory - used_memory))
      else
        result="unknown"
        status_code=3
        status_message="Cannot determine memory usage: required commands not found"
      fi
      ;;

    macos)
      # macOS-style - use sysctl and vm_stat
      if util_command_exists vm_stat && util_command_exists sysctl; then
        # Get page size and memory stats
        local page_size
        page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)

        local vm_stat_output
        vm_stat_output=$(vm_stat 2>/dev/null)

        # Calculate total physical memory
        total_memory=$(sysctl -n hw.memsize 2>/dev/null || echo 0)

        if [[ -n "$vm_stat_output" && "$total_memory" -gt 0 ]]; then
          # Parse memory pages
          local pages_free pages_active pages_inactive pages_speculative pages_wired
          pages_free=$(echo "$vm_stat_output" | awk '/Pages free:/ {print $3}' | tr -d '.')
          pages_active=$(echo "$vm_stat_output" | awk '/Pages active:/ {print $3}' | tr -d '.')
          pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
          pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative:/ {print $3}' | tr -d '.')
          pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down:/ {print $4}' | tr -d '.')

          # Calculate used memory using awk for better compatibility
          used_memory=$(awk -v active="$pages_active" -v wired="$pages_wired" -v inactive="$pages_inactive" -v page_size="$page_size" -v include_cache="$memory_include_buffers_cache" '
            BEGIN {
              used = (active + wired) * page_size
              if (include_cache == "true") {
                used += inactive * page_size
              }
              print int(used)
            }')

          # Calculate free memory
          free_memory=$(awk -v free="$pages_free" -v spec="$pages_speculative" -v page_size="$page_size" '
            BEGIN {
              print int((free + spec) * page_size)
            }')
        else
          result="unknown"
          status_code=3
          status_message="Cannot determine memory usage: unable to get memory statistics"
        fi
      else
        result="unknown"
        status_code=3
        status_message="Cannot determine memory usage: required commands not found"
      fi
      ;;

    *)
      # Unsupported OS
      result="unknown"
      status_code=3
      status_message="Unsupported OS type: $os_type"
      ;;
    esac
  fi

  # Calculate memory usage percentage if we have values
  if [[ "$total_memory" -gt 0 && "$used_memory" -ge 0 ]]; then
    # Calculate the percentage using awk for better compatibility
    result=$(awk -v used="$used_memory" -v total="$total_memory" 'BEGIN {printf "%.1f", used * 100 / total}')

    # Check thresholds using awk for comparison
    local threshold_check warning_check
    threshold_check=$(awk -v result="$result" -v threshold="$memory_threshold" 'BEGIN {print (result >= threshold) ? 1 : 0}')
    warning_check=$(awk -v result="$result" -v threshold="$memory_warning_threshold" 'BEGIN {print (result >= threshold) ? 1 : 0}')

    if [[ "$threshold_check" -eq 1 ]]; then
      status_code=2
      status_message="CRITICAL: Memory usage is ${result}%, threshold: ${memory_threshold}%"
    elif [[ "$warning_check" -eq 1 ]]; then
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
