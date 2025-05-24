#!/bin/bash
#
# ServerSentry v2 - JSON Utilities
#
# This module provides standardized JSON manipulation functions used throughout the application

# Function: util_json_set_value
# Description: Set a value in a JSON object at a specific path
# Parameters:
#   $1 - JSON string
#   $2 - path (e.g., ".metrics.cpu_usage")
#   $3 - value to set
# Returns:
#   Modified JSON via stdout
util_json_set_value() {
  local json="$1"
  local path="$2"
  local value="$3"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq --argjson v "$value" ".$path = \$v" 2>/dev/null || echo "$json"
  else
    # Fallback for simple cases without jq
    _json_set_simple "$json" "$path" "$value"
  fi
}

# Function: util_json_get_value
# Description: Get a value from a JSON object at a specific path
# Parameters:
#   $1 - JSON string
#   $2 - path (e.g., ".status_code")
# Returns:
#   Value via stdout
util_json_get_value() {
  local json="$1"
  local path="$2"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$path" 2>/dev/null || echo ""
  else
    # Fallback for simple cases without jq
    _json_get_simple "$json" "$path"
  fi
}

# Function: util_json_merge
# Description: Merge two JSON objects
# Parameters:
#   $1 - base JSON object
#   $2 - overlay JSON object
# Returns:
#   Merged JSON via stdout
util_json_merge() {
  local base="$1"
  local overlay="$2"

  if command -v jq >/dev/null 2>&1; then
    echo "$base" | jq ". + $overlay" 2>/dev/null || echo "$base"
  else
    # Simple fallback - just return base for now
    echo "$base"
  fi
}

# Function: util_json_create_object
# Description: Create a JSON object from key-value pairs
# Parameters:
#   $@ - key=value pairs
# Returns:
#   JSON object via stdout
util_json_create_object() {
  local json="{"
  local first=true

  for pair in "$@"; do
    if [[ "$pair" =~ ^([^=]+)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      if [[ "$first" == "true" ]]; then
        first=false
      else
        json+=","
      fi

      # Determine if value should be quoted
      if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ "$value" =~ ^(true|false|null)$ ]]; then
        json+="\"$key\":$value"
      else
        json+="\"$key\":\"$(util_json_escape "$value")\""
      fi
    fi
  done

  json+="}"
  echo "$json"
}

# Function: util_json_add_to_array
# Description: Add an item to a JSON array
# Parameters:
#   $1 - JSON array string
#   $2 - item to add
# Returns:
#   Modified JSON array via stdout
util_json_add_to_array() {
  local array="$1"
  local item="$2"

  if command -v jq >/dev/null 2>&1; then
    echo "$array" | jq ". += [$item]" 2>/dev/null || echo "$array"
  else
    # Simple fallback for arrays
    if [[ "$array" == "[]" ]]; then
      echo "[$item]"
    else
      # Remove closing bracket, add comma and item, add closing bracket
      echo "${array%]},${item}]"
    fi
  fi
}

# Function: util_json_validate
# Description: Validate JSON syntax
# Parameters:
#   $1 - JSON string to validate
# Returns:
#   0 - valid JSON
#   1 - invalid JSON
util_json_validate() {
  local json="$1"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq . >/dev/null 2>&1
  else
    # Basic validation without jq
    _json_validate_simple "$json"
  fi
}

# Function: util_json_escape
# Description: Escape special characters for JSON
# Parameters:
#   $1 - string to escape
# Returns:
#   Escaped string via stdout
util_json_escape() {
  local string="$1"

  # Escape backslashes first, then other characters
  string="${string//\\/\\\\}"
  string="${string//\"/\\\"}"
  string="${string//$'\n'/\\n}"
  string="${string//$'\r'/\\r}"
  string="${string//$'\t'/\\t}"

  echo "$string"
}

# Function: util_json_create_status_object
# Description: Create a standard status JSON object
# Parameters:
#   $1 - status code
#   $2 - status message
#   $3 - plugin name (optional)
#   $4 - metrics object (optional)
# Returns:
#   Status JSON object via stdout
util_json_create_status_object() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="${3:-}"
  local metrics="${4:-{}}"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local json="{"
  json+="\"status_code\":$status_code,"
  json+="\"status_message\":\"$(util_json_escape "$status_message")\","
  json+="\"timestamp\":\"$timestamp\""

  if [[ -n "$plugin_name" ]]; then
    json+=",\"plugin\":\"$(util_json_escape "$plugin_name")\""
  fi

  json+=",\"metrics\":$metrics"
  json+="}"

  echo "$json"
}

# Function: util_json_create_error_object
# Description: Create a standard error JSON object
# Parameters:
#   $1 - error message
#   $2 - error code (optional)
#   $3 - details (optional)
# Returns:
#   Error JSON object via stdout
util_json_create_error_object() {
  local error_message="$1"
  local error_code="${2:-1}"
  local details="${3:-}"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local json="{"
  json+="\"error\":true,"
  json+="\"error_code\":$error_code,"
  json+="\"error_message\":\"$(util_json_escape "$error_message")\","
  json+="\"timestamp\":\"$timestamp\""

  if [[ -n "$details" ]]; then
    json+=",\"details\":\"$(util_json_escape "$details")\""
  fi

  json+="}"

  echo "$json"
}

# Function: util_json_extract_metrics
# Description: Extract metrics from a plugin result JSON
# Parameters:
#   $1 - plugin result JSON
# Returns:
#   Metrics JSON object via stdout
util_json_extract_metrics() {
  local result="$1"

  util_json_get_value "$result" ".metrics"
}

# Function: util_json_pretty_print
# Description: Pretty print JSON if jq is available
# Parameters:
#   $1 - JSON string
# Returns:
#   Pretty printed JSON via stdout
util_json_pretty_print() {
  local json="$1"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq . 2>/dev/null || echo "$json"
  else
    echo "$json"
  fi
}

# Internal function: Simple JSON value setter without jq
_json_set_simple() {
  local json="$1"
  local path="$2"
  local value="$3"

  # This is a very basic implementation for simple cases
  # For complex JSON manipulation, jq is recommended

  if [[ "$path" =~ ^\.(.*) ]]; then
    local key="${BASH_REMATCH[1]}"

    # Handle simple key replacement
    if [[ "$json" =~ \"$key\":[^,}]* ]]; then
      # Key exists, replace value
      if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ "$value" =~ ^(true|false|null)$ ]]; then
        echo "$json" | sed "s/\"$key\":[^,}]*/\"$key\":$value/"
      else
        echo "$json" | sed "s/\"$key\":[^,}]*/\"$key\":\"$(util_json_escape "$value")\"/"
      fi
    else
      # Key doesn't exist, add it
      if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ "$value" =~ ^(true|false|null)$ ]]; then
        echo "$json" | sed "s/}$/,\"$key\":$value}/"
      else
        echo "$json" | sed "s/}$/,\"$key\":\"$(util_json_escape "$value")\"}/"
      fi
    fi
  else
    echo "$json"
  fi
}

# Internal function: Simple JSON value getter without jq
_json_get_simple() {
  local json="$1"
  local path="$2"

  if [[ "$path" =~ ^\.(.*) ]]; then
    local key="${BASH_REMATCH[1]}"

    # Extract value for key
    if [[ "$json" =~ \"$key\":[[:space:]]*\"([^\"]+)\" ]]; then
      echo "${BASH_REMATCH[1]}"
    elif [[ "$json" =~ \"$key\":[[:space:]]*([0-9]+(\.[0-9]+)?) ]]; then
      echo "${BASH_REMATCH[1]}"
    elif [[ "$json" =~ \"$key\":[[:space:]]*(true|false|null) ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  fi
}

# Internal function: Simple JSON validation without jq
_json_validate_simple() {
  local json="$1"

  # Very basic JSON validation - check for balanced braces
  local open_braces
  local close_braces

  open_braces=$(echo "$json" | tr -cd '{' | wc -c)
  close_braces=$(echo "$json" | tr -cd '}' | wc -c)

  if [[ "$open_braces" -eq "$close_braces" ]] && [[ "$open_braces" -gt 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_json_set_value
  export -f util_json_get_value
  export -f util_json_merge
  export -f util_json_create_object
  export -f util_json_add_to_array
  export -f util_json_validate
  export -f util_json_escape
  export -f util_json_create_status_object
  export -f util_json_create_error_object
  export -f util_json_extract_metrics
  export -f util_json_pretty_print
fi
