#!/usr/bin/env bash
#
# ServerSentry v2 - Error Recovery Module
#
# This module provides comprehensive error recovery strategies and mechanisms

# Function: error_attempt_recovery
# Description: Main error recovery dispatcher with enhanced strategy selection
# Parameters:
#   $1 (numeric): exit code
#   $2 (string): failed command
#   $3 (string): error context JSON
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_attempt_recovery 3 "cat /missing/file" "$error_context"
# Dependencies:
#   - util_error_validate_input
#   - error_recover_* functions
error_attempt_recovery() {
  local exit_code="$1"
  local failed_command="$2"
  local error_context="$3"

  # Validate inputs
  if ! util_error_validate_input "$exit_code" "exit_code" "numeric"; then
    return 1
  fi

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting error recovery for exit code: $exit_code" "error"

  # Dispatch to appropriate recovery strategy
  case "$exit_code" in
  "${ERROR_CODE_FILE_NOT_FOUND:-3}")
    error_recover_file_not_found "$failed_command"
    ;;
  "${ERROR_CODE_PERMISSION_DENIED:-4}")
    error_recover_permission_denied "$failed_command"
    ;;
  "${ERROR_CODE_NETWORK_ERROR:-5}")
    error_recover_network_error "$failed_command"
    ;;
  "${ERROR_CODE_TIMEOUT:-6}")
    error_recover_timeout "$failed_command"
    ;;
  "${ERROR_CODE_CONFIGURATION_ERROR:-7}")
    error_recover_configuration_error "$failed_command"
    ;;
  "${ERROR_CODE_PLUGIN_ERROR:-8}")
    error_recover_plugin_error "$failed_command"
    ;;
  "${ERROR_CODE_DEPENDENCY_ERROR:-9}")
    error_recover_dependency_error "$failed_command"
    ;;
  "${ERROR_CODE_RESOURCE_EXHAUSTED:-10}")
    error_recover_resource_exhausted "$failed_command"
    ;;
  *)
    log_debug "No recovery strategy available for exit code: $exit_code" "error"
    return 1
    ;;
  esac
}

# Function: error_recover_file_not_found
# Description: Recovery strategy for file/directory not found errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_file_not_found "cat /missing/file"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_file_not_found() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting file not found recovery for: $failed_command" "error"

  # Extract file/directory path from command using enhanced pattern matching
  local path=""

  # Try different command patterns
  if [[ "$failed_command" =~ (mkdir|touch|cat|ls|cd)[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[2]}"
  elif [[ "$failed_command" =~ source[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[1]}"
  elif [[ "$failed_command" =~ \.[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[1]}"
  elif [[ "$failed_command" =~ ([^[:space:]]*\.(sh|conf|yaml|yml|json|txt))[[:space:]]* ]]; then
    path="${BASH_REMATCH[1]}"
  else
    log_debug "Cannot extract path from command: $failed_command" "error"
    return 1
  fi

  # Clean up the path (remove quotes, etc.)
  path=$(echo "$path" | sed 's/^["'\'']*//;s/["'\'']*$//')

  if [[ -z "$path" ]]; then
    log_debug "Empty path extracted from command" "error"
    return 1
  fi

  # Try to create parent directories
  local parent_dir
  parent_dir=$(dirname "$path" 2>/dev/null)

  if [[ -n "$parent_dir" && "$parent_dir" != "." && "$parent_dir" != "/" ]]; then
    log_debug "Creating missing directory: $parent_dir" "error"

    if util_error_safe_execute "mkdir -p '$parent_dir'" "Failed to create directory" "" 1; then
      log_info "Successfully created missing directory: $parent_dir" "error"

      # If the original command was trying to create a file, try to create it
      if [[ "$failed_command" =~ touch[[:space:]] ]]; then
        if util_error_safe_execute "touch '$path'" "Failed to create file" "" 1; then
          log_info "Successfully created missing file: $path" "error"
          return 0
        fi
      fi

      return 0
    fi
  fi

  # Try alternative locations for common files
  if [[ "$path" =~ \.(conf|config|yaml|yml)$ ]]; then
    local alt_paths=(
      "${BASE_DIR}/config/$(basename "$path")"
      "${BASE_DIR}/etc/$(basename "$path")"
      "/etc/serversentry/$(basename "$path")"
    )

    for alt_path in "${alt_paths[@]}"; do
      if [[ -f "$alt_path" ]]; then
        log_info "Found alternative config file: $alt_path" "error"
        # Create symlink to alternative location
        if util_error_safe_execute "ln -sf '$alt_path' '$path'" "Failed to create symlink" "" 1; then
          return 0
        fi
      fi
    done
  fi

  return 1
}

# Function: error_recover_permission_denied
# Description: Recovery strategy for permission denied errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_permission_denied "chmod 755 /protected/file"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_permission_denied() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting permission denied recovery for: $failed_command" "error"

  # Extract file path from command
  local path=""
  if [[ "$failed_command" =~ (chmod|chown|mkdir|touch|cat|ls|cp|mv)[[:space:]]+[^[:space:]]*[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[2]}"
  elif [[ "$failed_command" =~ (rm|rmdir)[[:space:]]+([^[:space:]]+) ]]; then
    path="${BASH_REMATCH[2]}"
  else
    log_debug "Cannot extract path from command: $failed_command" "error"
    return 1
  fi

  # Clean up the path
  path=$(echo "$path" | sed 's/^["'\'']*//;s/["'\'']*$//')

  if [[ -z "$path" || ! -e "$path" ]]; then
    log_debug "Path does not exist or is empty: $path" "error"
    return 1
  fi

  log_debug "Attempting to fix permissions for: $path" "error"

  # Try to make readable/writable for owner
  if util_error_safe_execute "chmod u+rw '$path'" "Failed to fix basic permissions" "" 1; then
    log_info "Successfully fixed basic permissions for: $path" "error"
    return 0
  fi

  # Try to fix directory permissions if it's a directory
  if [[ -d "$path" ]]; then
    if util_error_safe_execute "chmod u+rwx '$path'" "Failed to fix directory permissions" "" 1; then
      log_info "Successfully fixed directory permissions for: $path" "error"
      return 0
    fi
  fi

  # Try to change ownership to current user (if we have sudo access)
  if command -v sudo >/dev/null 2>&1; then
    local current_user
    current_user=$(whoami 2>/dev/null || echo "unknown")

    if [[ "$current_user" != "unknown" ]]; then
      if util_error_safe_execute "sudo chown '$current_user' '$path'" "Failed to change ownership" "" 1; then
        log_info "Successfully changed ownership of: $path" "error"
        return 0
      fi
    fi
  fi

  return 1
}

# Function: error_recover_network_error
# Description: Recovery strategy for network-related errors with exponential backoff
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_network_error "curl https://example.com"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_network_error() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting network error recovery for: $failed_command" "error"

  local max_retries=3
  local base_delay=2

  for ((i = 1; i <= max_retries; i++)); do
    local delay=$((base_delay * i))
    log_debug "Network retry attempt $i/$max_retries (delay: ${delay}s)" "error"

    sleep "$delay"

    # Test basic connectivity first
    if command -v ping >/dev/null 2>&1; then
      if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_debug "No internet connectivity detected" "error"
        continue
      fi
    fi

    # Retry the original command with timeout
    if util_error_safe_execute "timeout 30 $failed_command" "Network retry failed" "" 1; then
      log_info "Network recovery successful on attempt $i" "error"
      return 0
    fi
  done

  log_debug "Network recovery failed after $max_retries attempts" "error"
  return 1
}

# Function: error_recover_timeout
# Description: Recovery strategy for timeout errors with increased timeout
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_timeout "slow_operation"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_timeout() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting timeout recovery for: $failed_command" "error"

  # Remove existing timeout from command if present
  local clean_command
  clean_command=$(echo "$failed_command" | sed 's/^timeout [0-9]*[smh]* *//')

  # Try with progressively longer timeouts
  local timeouts=(60 120 300)

  for timeout in "${timeouts[@]}"; do
    log_debug "Timeout retry with ${timeout}s timeout" "error"

    if util_error_safe_execute "timeout ${timeout}s $clean_command" "Timeout retry failed" "" 1; then
      log_info "Timeout recovery successful with ${timeout}s timeout" "error"
      return 0
    fi
  done

  log_debug "Timeout recovery failed with all timeout values" "error"
  return 1
}

# Function: error_recover_configuration_error
# Description: Recovery strategy for configuration errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_configuration_error "load_config /path/to/config"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_configuration_error() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting configuration error recovery for: $failed_command" "error"

  # Extract config file path if present
  local config_path=""
  if [[ "$failed_command" =~ ([^[:space:]]*\.(conf|config|yaml|yml|json))[[:space:]]* ]]; then
    config_path="${BASH_REMATCH[1]}"
  fi

  # Try to backup and reset configuration
  if [[ -n "$config_path" && -f "$config_path" ]]; then
    local backup_path="${config_path}.backup.$(date +%Y%m%d_%H%M%S)"

    log_debug "Backing up configuration: $config_path -> $backup_path" "error"
    if util_error_safe_execute "cp '$config_path' '$backup_path'" "Failed to backup config" "" 1; then

      # Try to find a default configuration
      local default_configs=(
        "${config_path}.default"
        "${config_path}.example"
        "${BASE_DIR}/config/defaults/$(basename "$config_path")"
        "${BASE_DIR}/examples/$(basename "$config_path")"
      )

      for default_config in "${default_configs[@]}"; do
        if [[ -f "$default_config" ]]; then
          log_debug "Restoring from default config: $default_config" "error"
          if util_error_safe_execute "cp '$default_config' '$config_path'" "Failed to restore default config" "" 1; then
            log_info "Configuration restored from: $default_config" "error"
            return 0
          fi
        fi
      done

      # Try to create minimal valid configuration
      if _create_minimal_config "$config_path"; then
        log_info "Created minimal configuration: $config_path" "error"
        return 0
      fi
    fi
  fi

  # Try to reload configuration if function is available
  if declare -f reload_configuration >/dev/null 2>&1; then
    if util_error_safe_execute "reload_configuration" "Failed to reload configuration" "" 1; then
      log_info "Configuration reloaded successfully" "error"
      return 0
    fi
  fi

  return 1
}

# Function: error_recover_plugin_error
# Description: Recovery strategy for plugin-related errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_plugin_error "load_plugin cpu"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_plugin_error() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting plugin error recovery for: $failed_command" "error"

  # Extract plugin name from command
  local plugin_name=""
  if [[ "$failed_command" =~ plugin[[:space:]]+([^[:space:]]+) ]]; then
    plugin_name="${BASH_REMATCH[1]}"
  elif [[ "$failed_command" =~ ([^[:space:]]+)\.sh ]]; then
    plugin_name=$(basename "${BASH_REMATCH[1]}")
  fi

  # Try to reload the plugin system
  if declare -f plugin_system_init >/dev/null 2>&1; then
    if util_error_safe_execute "plugin_system_init" "Failed to reinitialize plugin system" "" 2; then
      log_info "Plugin system reinitialized successfully" "error"
      return 0
    fi
  fi

  # Try to reload specific plugin if identified
  if [[ -n "$plugin_name" ]]; then
    if declare -f plugin_reload >/dev/null 2>&1; then
      if util_error_safe_execute "plugin_reload '$plugin_name'" "Failed to reload plugin" "" 1; then
        log_info "Plugin reloaded successfully: $plugin_name" "error"
        return 0
      fi
    fi

    # Try to disable and re-enable the plugin
    if declare -f plugin_disable >/dev/null 2>&1 && declare -f plugin_enable >/dev/null 2>&1; then
      if util_error_safe_execute "plugin_disable '$plugin_name'" "Failed to disable plugin" "" 1; then
        sleep 1
        if util_error_safe_execute "plugin_enable '$plugin_name'" "Failed to re-enable plugin" "" 1; then
          log_info "Plugin reset successfully: $plugin_name" "error"
          return 0
        fi
      fi
    fi
  fi

  # Clear plugin cache if function is available
  if declare -f plugin_clear_cache >/dev/null 2>&1; then
    if util_error_safe_execute "plugin_clear_cache" "Failed to clear plugin cache" "" 1; then
      log_info "Plugin cache cleared successfully" "error"
      return 0
    fi
  fi

  return 1
}

# Function: error_recover_dependency_error
# Description: Recovery strategy for dependency-related errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_dependency_error "jq '.field' file.json"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_dependency_error() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting dependency error recovery for: $failed_command" "error"

  # Extract command name
  local cmd_name
  cmd_name=$(echo "$failed_command" | awk '{print $1}')

  if [[ -z "$cmd_name" ]]; then
    return 1
  fi

  # Check if command exists
  if command -v "$cmd_name" >/dev/null 2>&1; then
    log_debug "Command exists, dependency error may be transient" "error"
    return 0
  fi

  # Try to suggest installation for common missing dependencies
  local suggestions
  suggestions=$(error_suggest_dependency_installation "$cmd_name")

  if [[ -n "$suggestions" ]]; then
    log_info "Missing dependency: $cmd_name" "error"
    log_info "Installation suggestion: $suggestions" "error"

    # If we have package manager access, try to install
    if [[ "$suggestions" =~ ^(apt|yum|brew|pacman) ]]; then
      log_debug "Attempting automatic installation: $suggestions" "error"
      if util_error_safe_execute "$suggestions" "Failed to install dependency" "" 2; then
        log_info "Successfully installed dependency: $cmd_name" "error"
        return 0
      fi
    fi
  fi

  # Try to find alternative commands
  case "$cmd_name" in
  jq)
    if command -v python3 >/dev/null 2>&1; then
      log_info "Using python3 as jq alternative" "error"
      return 0
    fi
    ;;
  curl)
    if command -v wget >/dev/null 2>&1; then
      log_info "wget available as curl alternative" "error"
      return 0
    fi
    ;;
  wget)
    if command -v curl >/dev/null 2>&1; then
      log_info "curl available as wget alternative" "error"
      return 0
    fi
    ;;
  esac

  return 1
}

# Function: error_recover_resource_exhausted
# Description: Recovery strategy for resource exhaustion errors
# Parameters:
#   $1 (string): failed command
# Returns:
#   0 - recovery successful
#   1 - recovery failed
# Example:
#   error_recover_resource_exhausted "large_operation"
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
error_recover_resource_exhausted() {
  local failed_command="$1"

  if ! util_error_validate_input "$failed_command" "failed_command" "required"; then
    return 1
  fi

  log_debug "Attempting resource exhaustion recovery for: $failed_command" "error"

  # Clean up temporary files
  if util_error_safe_execute "_cleanup_temporary_files" "Failed to cleanup temp files" "" 1; then
    log_info "Cleaned up temporary files" "error"
  fi

  # Clear system caches if possible
  if command -v sync >/dev/null 2>&1; then
    util_error_safe_execute "sync" "Failed to sync filesystems" "" 1
  fi

  # Try to free up memory
  if [[ -w /proc/sys/vm/drop_caches ]]; then
    if util_error_safe_execute "echo 1 > /proc/sys/vm/drop_caches" "Failed to drop caches" "" 1; then
      log_info "Dropped system caches" "error"
    fi
  fi

  # Wait a moment for resources to be freed
  sleep 2

  # Retry the command with lower priority
  if util_error_safe_execute "nice -n 10 $failed_command" "Resource recovery retry failed" "" 1; then
    log_info "Resource exhaustion recovery successful" "error"
    return 0
  fi

  return 1
}

# Function: error_suggest_dependency_installation
# Description: Suggest installation commands for missing dependencies
# Parameters:
#   $1 (string): command name
# Returns:
#   Installation suggestion via stdout
# Example:
#   suggestion=$(error_suggest_dependency_installation "jq")
# Dependencies:
#   - util_error_validate_input
error_suggest_dependency_installation() {
  local cmd_name="$1"

  if ! util_error_validate_input "$cmd_name" "cmd_name" "required"; then
    return 1
  fi

  # Detect package manager
  local pkg_manager=""
  if command -v apt >/dev/null 2>&1; then
    pkg_manager="apt"
  elif command -v yum >/dev/null 2>&1; then
    pkg_manager="yum"
  elif command -v brew >/dev/null 2>&1; then
    pkg_manager="brew"
  elif command -v pacman >/dev/null 2>&1; then
    pkg_manager="pacman"
  fi

  # Suggest installation based on command and package manager
  case "$cmd_name" in
  jq)
    case "$pkg_manager" in
    apt) echo "sudo apt update && sudo apt install -y jq" ;;
    yum) echo "sudo yum install -y jq" ;;
    brew) echo "brew install jq" ;;
    pacman) echo "sudo pacman -S jq" ;;
    *) echo "Please install jq using your system's package manager" ;;
    esac
    ;;
  curl)
    case "$pkg_manager" in
    apt) echo "sudo apt update && sudo apt install -y curl" ;;
    yum) echo "sudo yum install -y curl" ;;
    brew) echo "brew install curl" ;;
    pacman) echo "sudo pacman -S curl" ;;
    *) echo "Please install curl using your system's package manager" ;;
    esac
    ;;
  wget)
    case "$pkg_manager" in
    apt) echo "sudo apt update && sudo apt install -y wget" ;;
    yum) echo "sudo yum install -y wget" ;;
    brew) echo "brew install wget" ;;
    pacman) echo "sudo pacman -S wget" ;;
    *) echo "Please install wget using your system's package manager" ;;
    esac
    ;;
  bc)
    case "$pkg_manager" in
    apt) echo "sudo apt update && sudo apt install -y bc" ;;
    yum) echo "sudo yum install -y bc" ;;
    brew) echo "brew install bc" ;;
    pacman) echo "sudo pacman -S bc" ;;
    *) echo "Please install bc using your system's package manager" ;;
    esac
    ;;
  *)
    echo "Please install $cmd_name using your system's package manager"
    ;;
  esac
}

# Internal function: Create minimal configuration
_create_minimal_config() {
  local config_path="$1"

  if [[ -z "$config_path" ]]; then
    return 1
  fi

  local config_dir
  config_dir=$(dirname "$config_path")

  # Ensure directory exists
  if ! mkdir -p "$config_dir" 2>/dev/null; then
    return 1
  fi

  # Create minimal config based on file extension
  case "$config_path" in
  *.yaml | *.yml)
    cat >"$config_path" <<EOF
# Minimal ServerSentry Configuration
# Generated automatically during error recovery

# Global settings
global:
  log_level: info

# Monitoring settings
monitoring:
  enabled: true
  interval: 60

# Plugin settings
plugins:
  enabled: true
EOF
    ;;
  *.json)
    cat >"$config_path" <<EOF
{
  "global": {
    "log_level": "info"
  },
  "monitoring": {
    "enabled": true,
    "interval": 60
  },
  "plugins": {
    "enabled": true
  }
}
EOF
    ;;
  *.conf | *)
    cat >"$config_path" <<EOF
# Minimal ServerSentry Configuration
# Generated automatically during error recovery

LOG_LEVEL=info
MONITORING_ENABLED=true
MONITORING_INTERVAL=60
PLUGINS_ENABLED=true
EOF
    ;;
  esac

  return 0
}

# Internal function: Cleanup temporary files
_cleanup_temporary_files() {
  local temp_dirs=("/tmp" "${BASE_DIR}/tmp" "${BASE_DIR}/logs/temp")
  local cleaned_count=0

  for temp_dir in "${temp_dirs[@]}"; do
    if [[ -d "$temp_dir" ]]; then
      # Clean ServerSentry temporary files
      find "$temp_dir" -name "serversentry_*" -type f -mtime +1 -delete 2>/dev/null && ((cleaned_count++))
      find "$temp_dir" -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null && ((cleaned_count++))
      find "$temp_dir" -name "temp_*" -type f -mtime +1 -delete 2>/dev/null && ((cleaned_count++))
    fi
  done

  log_debug "Cleaned up $cleaned_count temporary file groups" "error"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f error_attempt_recovery
  export -f error_recover_file_not_found
  export -f error_recover_permission_denied
  export -f error_recover_network_error
  export -f error_recover_timeout
  export -f error_recover_configuration_error
  export -f error_recover_plugin_error
  export -f error_recover_dependency_error
  export -f error_recover_resource_exhausted
  export -f error_suggest_dependency_installation
fi
