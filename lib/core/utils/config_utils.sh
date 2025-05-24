#!/bin/bash
#
# ServerSentry v2 - Configuration Utilities
#
# This module provides unified configuration parsing and management functions

# Check bash version for associative array support
if [[ ${BASH_VERSION%%.*} -ge 4 ]]; then
  # Global configuration cache (only for bash 4+)
  declare -A CONFIG_CACHE
  declare -A CONFIG_TIMESTAMPS
  CACHE_SUPPORTED=true
else
  # Fallback for older bash versions
  CACHE_SUPPORTED=false
fi

# Function: util_config_parse_yaml
# Description: Unified YAML configuration parser
# Parameters:
#   $1 - config file path
#   $2 - namespace for variables (optional, defaults to config)
#   $3 - use defaults (optional, defaults to true)
# Returns:
#   0 - success
#   1 - failure
util_config_parse_yaml() {
  local config_file="$1"
  local namespace="${2:-config}"
  local use_defaults="${3:-true}"

  # Validate input
  if ! util_validate_file_exists "$config_file" "Configuration file"; then
    return 1
  fi

  log_debug "Parsing YAML configuration: $config_file (namespace: $namespace)"

  # Determine parser to use
  if command -v yq >/dev/null 2>&1; then
    _config_parse_with_yq "$config_file" "$namespace"
  else
    _config_parse_basic "$config_file" "$namespace"
  fi

  local parse_result=$?

  if [[ "$parse_result" -eq 0 && "$use_defaults" == "true" ]]; then
    _config_apply_defaults "$namespace"
  fi

  return "$parse_result"
}

# Function: util_config_get_cached
# Description: Get configuration from cache or load if not cached
# Parameters:
#   $1 - config file path
#   $2 - namespace for variables (optional)
#   $3 - cache duration in seconds (optional, defaults to 300)
# Returns:
#   0 - success
#   1 - failure
util_config_get_cached() {
  local config_file="$1"
  local namespace="${2:-config}"
  local cache_duration="${3:-300}"

  # Temporarily disable caching to fix configuration loading
  # TODO: Fix caching mechanism to work with dot notation conversion
  util_config_parse_yaml "$config_file" "$namespace"
  return $?
}

# Function: util_config_get_value
# Description: Get a configuration value with optional default
# Parameters:
#   $1 - key name (supports dot notation)
#   $2 - default value (optional)
#   $3 - namespace (optional, defaults to config)
# Returns:
#   Configuration value via stdout
util_config_get_value() {
  local key="$1"
  local default_value="${2:-}"
  local namespace="${3:-config}"

  # Convert dot notation to underscore for bash variable names
  local var_key
  var_key=$(echo "$key" | tr '.' '_')
  local var_name="${namespace}_${var_key}"
  local value="${!var_name:-}"

  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "$default_value"
  fi
}

# Function: util_config_set_value
# Description: Set a configuration value
# Parameters:
#   $1 - key name (supports dot notation)
#   $2 - value
#   $3 - namespace (optional, defaults to config)
# Returns:
#   0 - success
util_config_set_value() {
  local key="$1"
  local value="$2"
  local namespace="${3:-config}"

  # Convert dot notation to underscore for bash variable names
  local var_key
  var_key=$(echo "$key" | tr '.' '_')
  local var_name="${namespace}_${var_key}"

  # Sanitize the value
  value=$(util_sanitize_input "$value")

  eval "${var_name}='${value}'"
  log_debug "Set config value: $var_name = $value"

  return 0
}

# Function: util_config_validate_values
# Description: Validate configuration values against rules
# Parameters:
#   $1 - validation rules array name (passed by reference)
#   $2 - namespace (optional, defaults to config)
# Returns:
#   0 - all validations passed
#   1 - validation failed
util_config_validate_values() {
  local rules_array_name="$1"
  local namespace="${2:-config}"
  local validation_failed=false

  # Get array elements using eval for bash 3.x compatibility
  local rules_count
  eval "rules_count=\${#${rules_array_name}[@]}"

  local i
  for ((i = 0; i < rules_count; i++)); do
    local rule
    eval "rule=\${${rules_array_name}[$i]}"

    if [[ "$rule" =~ ^([^:]+):([^:]+):(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local type="${BASH_REMATCH[2]}"
      local constraint="${BASH_REMATCH[3]}"

      local value
      value=$(util_config_get_value "$key" "" "$namespace")

      case "$type" in
      required)
        if ! util_require_param "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      numeric)
        if [[ -n "$value" ]] && ! util_validate_numeric "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      positive_numeric)
        if [[ -n "$value" ]] && ! util_validate_positive_numeric "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      boolean)
        if [[ -n "$value" ]] && ! util_validate_boolean "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      log_level)
        if [[ -n "$value" ]] && ! util_validate_log_level "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      url)
        if [[ -n "$value" ]] && ! util_validate_url "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      email)
        if [[ -n "$value" ]] && ! util_validate_email "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      file_exists)
        if [[ -n "$value" ]] && ! util_validate_file_exists "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      dir_exists)
        if [[ -n "$value" ]] && ! util_validate_dir_exists "$value" "$key"; then
          validation_failed=true
        fi
        ;;
      range)
        if [[ -n "$value" ]] && [[ "$constraint" =~ ^([0-9]+)-([0-9]+)$ ]]; then
          local min="${BASH_REMATCH[1]}"
          local max="${BASH_REMATCH[2]}"
          if [[ "$value" -lt "$min" || "$value" -gt "$max" ]]; then
            log_error "Value out of range for $key: $value (must be $min-$max)"
            validation_failed=true
          fi
        fi
        ;;
      enum)
        if [[ -n "$value" ]] && [[ "$constraint" =~ ^\[(.+)\]$ ]]; then
          local enum_values="${BASH_REMATCH[1]}"
          IFS=',' read -r -a valid_values <<<"$enum_values"
          if ! util_array_contains "$value" "${valid_values[@]}"; then
            log_error "Invalid value for $key: $value (must be one of: ${enum_values})"
            validation_failed=true
          fi
        fi
        ;;
      *)
        log_warning "Unknown validation type: $type for key: $key"
        ;;
      esac
    else
      log_warning "Invalid validation rule format: $rule"
    fi
  done

  if [[ "$validation_failed" == "true" ]]; then
    return 1
  else
    return 0
  fi
}

# Function: util_config_load_env_overrides
# Description: Load environment variable overrides for configuration
# Parameters:
#   $1 - environment prefix (e.g., SERVERSENTRY)
#   $2 - namespace (optional, defaults to config)
# Returns:
#   0 - success
util_config_load_env_overrides() {
  local env_prefix="$1"
  local namespace="${2:-config}"

  log_debug "Loading environment overrides with prefix: $env_prefix"

  # Look for environment variables with the specified prefix
  while IFS= read -r var; do
    if [[ "$var" =~ ^${env_prefix}_(.+)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Convert to lowercase
      key=$(echo "$key" | tr '[:upper:]' '[:lower:]')

      log_debug "Override from environment: $key = $value"
      util_config_set_value "$key" "$value" "$namespace"
    fi
  done < <(env | grep "^${env_prefix}_")

  return 0
}

# Function: util_config_create_default
# Description: Create a default configuration file
# Parameters:
#   $1 - config file path
#   $2 - config template content
# Returns:
#   0 - success
#   1 - failure
util_config_create_default() {
  local config_file="$1"
  local template_content="$2"

  log_debug "Creating default configuration: $config_file"

  # Create parent directory if it doesn't exist
  local config_dir
  config_dir=$(dirname "$config_file")

  if ! util_validate_dir_exists "$config_dir" "Configuration directory"; then
    log_info "Creating configuration directory: $config_dir"
    mkdir -p "$config_dir" || {
      log_error "Failed to create configuration directory: $config_dir"
      return 1
    }
  fi

  # Write template content to file
  echo "$template_content" >"$config_file" || {
    log_error "Failed to write default configuration: $config_file"
    return 1
  }

  chmod 644 "$config_file"
  log_info "Created default configuration: $config_file"

  return 0
}

# Internal function: Parse YAML with yq
_config_parse_with_yq() {
  local config_file="$1"
  local namespace="$2"

  log_debug "Using yq for YAML parsing"

  # Use yq to parse YAML into flattened key-value pairs with dot notation
  while IFS='=' read -r key value; do
    # Skip empty lines
    [[ -z "$key" ]] && continue

    # Remove quotes from value
    value=$(echo "$value" | sed 's/^"//;s/"$//')

    # Store in configuration namespace (util_config_set_value handles dot conversion)
    if [[ -n "$key" && -n "$value" ]]; then
      log_debug "Setting config: ${key} = $value"
      util_config_set_value "$key" "$value" "$namespace"
    fi
  done < <(yq eval -o=props "$config_file" 2>/dev/null | grep -v '^#' | grep '=')

  return $?
}

# Internal function: Basic YAML parser with nested structure support
_config_parse_basic() {
  local config_file="$1"
  local namespace="$2"

  log_debug "Using basic YAML parser with nested structure support"

  local current_section=""
  local indent_level=0

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    # Calculate indentation level
    local line_indent=0
    if [[ "$line" =~ ^([[:space:]]*) ]]; then
      line_indent=${#BASH_REMATCH[1]}
    fi

    # Handle section headers (keys without values)
    if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*$ ]]; then
      local section_key="${BASH_REMATCH[1]}"
      section_key=$(echo "$section_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [[ $line_indent -eq 0 ]]; then
        current_section="$section_key"
      elif [[ $line_indent -gt 0 ]]; then
        current_section="${current_section}.${section_key}"
      fi
      continue
    fi

    # Handle key-value pairs
    if [[ "$line" =~ ^[[:space:]]*([^:]+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Trim whitespace and brackets/quotes
      key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^\[//;s/\]$//;s/^"//;s/"$//')

      # Build full key path
      local full_key
      if [[ -n "$current_section" && $line_indent -gt 0 ]]; then
        full_key="${current_section}.${key}"
      else
        full_key="$key"
      fi

      # Store in configuration namespace (util_config_set_value handles dot conversion)
      if [[ -n "$full_key" && -n "$value" ]]; then
        log_debug "Setting config: ${full_key} = $value"
        util_config_set_value "$full_key" "$value" "$namespace"
      fi
    fi
  done <"$config_file"

  return 0
}

# Internal function: Apply default values
_config_apply_defaults() {
  local namespace="$1"

  log_debug "Applying default configuration values for namespace: $namespace"

  # Common defaults that can be applied to any namespace
  local defaults=(
    "enabled:true"
    "log_level:info"
    "check_interval:60"
    "timeout:30"
  )

  for default in "${defaults[@]}"; do
    if [[ "$default" =~ ^([^:]+):(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local default_value="${BASH_REMATCH[2]}"

      local current_value
      current_value=$(util_config_get_value "$key" "" "$namespace")

      if [[ -z "$current_value" ]]; then
        log_debug "Using default for ${key}: $default_value"
        util_config_set_value "$key" "$default_value" "$namespace"
      fi
    fi
  done
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_config_parse_yaml
  export -f util_config_get_cached
  export -f util_config_get_value
  export -f util_config_set_value
  export -f util_config_validate_values
  export -f util_config_load_env_overrides
  export -f util_config_create_default
fi
