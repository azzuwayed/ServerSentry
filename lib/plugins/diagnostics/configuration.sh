#!/usr/bin/env bash
#
# ServerSentry v2 - Configuration Diagnostics Module
#
# This module provides configuration validation and diagnostic functions

# Function: diagnostics_check_configuration
# Description: Comprehensive configuration diagnostics with validation
# Parameters: None
# Returns:
#   JSON results via stdout
#   0 - success
#   1 - failure
# Example:
#   config_results=$(diagnostics_check_configuration)
# Dependencies:
#   - util_error_validate_input
#   - util_json_create_object
#   - log_debug
diagnostics_check_configuration() {
  log_debug "Running configuration diagnostics"

  local checks=()
  local total=0 passed=0 warnings=0 errors=0 critical=0

  # YAML syntax validation
  if [[ "$(util_config_get_value "validate_yaml_syntax" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local yaml_check
    if yaml_check=$(diagnostics_check_yaml_syntax); then
      checks+=("$yaml_check")
      _diagnostics_count_result "$yaml_check" total passed warnings errors critical
    else
      log_error "YAML syntax diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Required fields validation
  if [[ "$(util_config_get_value "validate_required_fields" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local fields_check
    if fields_check=$(diagnostics_check_required_fields); then
      checks+=("$fields_check")
      _diagnostics_count_result "$fields_check" total passed warnings errors critical
    else
      log_error "Required fields diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # File permissions validation
  if [[ "$(util_config_get_value "validate_file_permissions" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local perms_check
    if perms_check=$(diagnostics_check_file_permissions); then
      checks+=("$perms_check")
      _diagnostics_count_result "$perms_check" total passed warnings errors critical
    else
      log_error "File permissions diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Log rotation validation
  if [[ "$(util_config_get_value "validate_log_rotation" "true" "$DIAGNOSTICS_NAMESPACE")" == "true" ]]; then
    local log_check
    if log_check=$(diagnostics_check_log_rotation); then
      checks+=("$log_check")
      _diagnostics_count_result "$log_check" total passed warnings errors critical
    else
      log_error "Log rotation diagnostic failed"
      errors=$((errors + 1))
      total=$((total + 1))
    fi
  fi

  # Create JSON array from checks
  local checks_json
  checks_json=$(util_json_create_array "${checks[@]}")

  # Create summary and final result
  local summary
  summary=$(util_json_create_object \
    "total" "$total" \
    "passed" "$passed" \
    "warnings" "$warnings" \
    "errors" "$errors" \
    "critical" "$critical")

  local result
  result=$(util_json_create_object \
    "checks" "$checks_json" \
    "summary" "$summary" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_yaml_syntax
# Description: Validate YAML configuration file syntax
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   yaml_result=$(diagnostics_check_yaml_syntax)
# Dependencies:
#   - yq or python (for YAML validation)
diagnostics_check_yaml_syntax() {
  local level=0 status="OK" message
  local config_files=()
  local syntax_errors=()

  # Find YAML configuration files
  if [[ -d "$BASE_DIR/config" ]]; then
    while IFS= read -r -d '' file; do
      config_files+=("$file")
    done < <(find "$BASE_DIR/config" -name "*.yml" -o -name "*.yaml" -type f -print0 2>/dev/null)
  fi

  if [[ ${#config_files[@]} -eq 0 ]]; then
    level=1
    status="WARNING"
    message="No YAML configuration files found"
  else
    # Validate each YAML file
    for config_file in "${config_files[@]}"; do
      local file_valid=false
      local error_msg=""

      # Try yq first (preferred)
      if command -v yq >/dev/null 2>&1; then
        if yq eval '.' "$config_file" >/dev/null 2>&1; then
          file_valid=true
        else
          error_msg="yq validation failed"
        fi
      # Try python as fallback
      elif command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
          file_valid=true
        else
          error_msg="Python YAML validation failed"
        fi
      elif command -v python >/dev/null 2>&1; then
        if python -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
          file_valid=true
        else
          error_msg="Python YAML validation failed"
        fi
      else
        error_msg="No YAML validator available (yq, python3, or python)"
      fi

      if [[ "$file_valid" != true ]]; then
        syntax_errors+=("$(basename "$config_file"): $error_msg")
      fi
    done

    # Determine overall status
    if [[ ${#syntax_errors[@]} -gt 0 ]]; then
      level=2
      status="ERROR"
      message="YAML syntax errors found in ${#syntax_errors[@]} files"
    else
      level=0
      status="OK"
      message="All ${#config_files[@]} YAML files have valid syntax"
    fi
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "yaml_syntax" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "files_checked" "${#config_files[@]}" \
      "syntax_errors" "${#syntax_errors[@]}" \
      "error_details" "$(printf '%s; ' "${syntax_errors[@]}")")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_required_fields
# Description: Validate that required configuration fields are present
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   fields_result=$(diagnostics_check_required_fields)
# Dependencies:
#   - util_config_get_value
diagnostics_check_required_fields() {
  local level=0 status="OK" message
  local missing_fields=()

  # Define required configuration fields
  local required_fields=(
    "log_level"
    "log_file"
    "plugin_dir"
    "config_dir"
    "notification_enabled"
  )

  # Check each required field
  for field in "${required_fields[@]}"; do
    local value
    value=$(util_config_get_value "$field" "" "main")

    if [[ -z "$value" ]]; then
      missing_fields+=("$field")
    fi
  done

  # Check for critical configuration files
  local required_files=(
    "$BASE_DIR/config/serversentry.conf"
    "$BASE_DIR/config/plugins.conf"
  )

  local missing_files=()
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing_files+=("$(basename "$file")")
    fi
  done

  # Determine overall status
  local total_missing=$((${#missing_fields[@]} + ${#missing_files[@]}))

  if [[ $total_missing -gt 0 ]]; then
    if [[ ${#missing_files[@]} -gt 0 ]]; then
      level=3
      status="CRITICAL"
      message="Critical configuration files missing: ${missing_files[*]}"
    else
      level=2
      status="ERROR"
      message="Required configuration fields missing: ${missing_fields[*]}"
    fi
  else
    level=0
    status="OK"
    message="All required configuration fields and files present"
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "required_fields" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "fields_checked" "${#required_fields[@]}" \
      "missing_fields" "${#missing_fields[@]}" \
      "files_checked" "${#required_files[@]}" \
      "missing_files" "${#missing_files[@]}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_file_permissions
# Description: Validate file and directory permissions
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   perms_result=$(diagnostics_check_file_permissions)
# Dependencies:
#   - stat command
diagnostics_check_file_permissions() {
  local level=0 status="OK" message
  local permission_issues=()

  # Define critical paths and their expected permissions
  local critical_paths=(
    "$BASE_DIR/config:755"
    "$BASE_DIR/logs:755"
    "$BASE_DIR/tmp:755"
    "$BASE_DIR/lib:755"
  )

  # Check directory permissions
  for path_perm in "${critical_paths[@]}"; do
    local path="${path_perm%:*}"
    local expected_perm="${path_perm#*:}"

    if [[ -d "$path" ]]; then
      local actual_perm
      if command -v stat >/dev/null 2>&1; then
        # Try different stat formats for compatibility
        if actual_perm=$(stat -c "%a" "$path" 2>/dev/null); then
          # Linux format worked
          :
        elif actual_perm=$(stat -f "%A" "$path" 2>/dev/null); then
          # macOS format worked
          :
        else
          actual_perm="unknown"
        fi
      else
        actual_perm="unknown"
      fi

      if [[ "$actual_perm" != "$expected_perm" && "$actual_perm" != "unknown" ]]; then
        permission_issues+=("$(basename "$path"): expected $expected_perm, got $actual_perm")
      elif [[ "$actual_perm" == "unknown" ]]; then
        permission_issues+=("$(basename "$path"): could not determine permissions")
      fi
    else
      permission_issues+=("$(basename "$path"): directory does not exist")
    fi
  done

  # Check configuration file permissions (should not be world-readable for security)
  local config_files=()
  if [[ -d "$BASE_DIR/config" ]]; then
    while IFS= read -r -d '' file; do
      config_files+=("$file")
    done < <(find "$BASE_DIR/config" -name "*.conf" -o -name "*.yml" -o -name "*.yaml" -type f -print0 2>/dev/null)
  fi

  for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
      # Check if file is world-readable (potential security issue)
      if [[ -r "$config_file" ]] && [[ "$(stat -c "%a" "$config_file" 2>/dev/null || stat -f "%A" "$config_file" 2>/dev/null)" =~ [0-9][0-9][4-7] ]]; then
        permission_issues+=("$(basename "$config_file"): world-readable (security risk)")
      fi
    fi
  done

  # Determine overall status
  if [[ ${#permission_issues[@]} -gt 0 ]]; then
    # Check if any issues are security-related
    local has_security_issues=false
    for issue in "${permission_issues[@]}"; do
      if [[ "$issue" =~ "world-readable" || "$issue" =~ "does not exist" ]]; then
        has_security_issues=true
        break
      fi
    done

    if [[ "$has_security_issues" == true ]]; then
      level=2
      status="ERROR"
      message="Security-related permission issues found"
    else
      level=1
      status="WARNING"
      message="Permission issues found: ${#permission_issues[@]} items"
    fi
  else
    level=0
    status="OK"
    message="File and directory permissions are correct"
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "file_permissions" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "paths_checked" "${#critical_paths[@]}" \
      "config_files_checked" "${#config_files[@]}" \
      "permission_issues" "${#permission_issues[@]}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Function: diagnostics_check_log_rotation
# Description: Validate log rotation configuration and status
# Parameters: None
# Returns:
#   JSON result via stdout
#   0 - success
#   1 - failure
# Example:
#   log_result=$(diagnostics_check_log_rotation)
# Dependencies:
#   - find command
diagnostics_check_log_rotation() {
  local level=0 status="OK" message
  local log_issues=()

  # Check if logs directory exists
  if [[ ! -d "$BASE_DIR/logs" ]]; then
    level=2
    status="ERROR"
    message="Logs directory does not exist"
  else
    # Check for old log files (potential rotation issues)
    local old_logs
    old_logs=$(find "$BASE_DIR/logs" -name "*.log" -mtime +30 -type f 2>/dev/null | wc -l)

    if [[ $old_logs -gt 10 ]]; then
      log_issues+=("$old_logs log files older than 30 days (rotation may not be working)")
    fi

    # Check log file sizes
    local large_logs
    large_logs=$(find "$BASE_DIR/logs" -name "*.log" -size +100M -type f 2>/dev/null | wc -l)

    if [[ $large_logs -gt 0 ]]; then
      log_issues+=("$large_logs log files larger than 100MB (rotation needed)")
    fi

    # Check disk space usage by logs
    local logs_size
    if command -v du >/dev/null 2>&1; then
      logs_size=$(du -sm "$BASE_DIR/logs" 2>/dev/null | awk '{print $1}' || echo "0")

      if [[ $logs_size -gt 1000 ]]; then
        log_issues+=("Logs directory using ${logs_size}MB (consider cleanup)")
      fi
    fi

    # Check for log rotation configuration
    local logrotate_config="/etc/logrotate.d/serversentry"
    if [[ ! -f "$logrotate_config" ]] && command -v logrotate >/dev/null 2>&1; then
      log_issues+=("No logrotate configuration found")
    fi

    # Determine overall status
    if [[ ${#log_issues[@]} -gt 0 ]]; then
      # Check severity of issues
      local has_critical_issues=false
      for issue in "${log_issues[@]}"; do
        if [[ "$issue" =~ "larger than 100MB" || "$issue" =~ "using.*MB" ]]; then
          has_critical_issues=true
          break
        fi
      done

      if [[ "$has_critical_issues" == true ]]; then
        level=2
        status="ERROR"
        message="Critical log rotation issues found"
      else
        level=1
        status="WARNING"
        message="Log rotation issues found: ${#log_issues[@]} items"
      fi
    else
      level=0
      status="OK"
      message="Log rotation appears to be working correctly"
    fi
  fi

  # Create result JSON
  local result
  result=$(util_json_create_object \
    "check_name" "log_rotation" \
    "level" "$level" \
    "status" "$status" \
    "message" "$message" \
    "metrics" "$(util_json_create_object \
      "old_logs_count" "${old_logs:-0}" \
      "large_logs_count" "${large_logs:-0}" \
      "logs_size_mb" "${logs_size:-0}" \
      "issues_found" "${#log_issues[@]}")" \
    "timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

  echo "$result"
  return 0
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f diagnostics_check_configuration
  export -f diagnostics_check_yaml_syntax
  export -f diagnostics_check_required_fields
  export -f diagnostics_check_file_permissions
  export -f diagnostics_check_log_rotation
fi
