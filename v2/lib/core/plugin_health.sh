#!/bin/bash
#
# ServerSentry v2 - Plugin Health & Versioning System
#
# This module tracks plugin health, versions, dependencies, and provides update notifications

# Plugin health configuration
PLUGIN_HEALTH_DIR="${BASE_DIR}/logs/plugin_health"
PLUGIN_REGISTRY_FILE="${BASE_DIR}/config/plugin_registry.json"

# Initialize plugin health system
init_plugin_health_system() {
  log_debug "Initializing plugin health system"

  # Create directories if they don't exist
  if [ ! -d "$PLUGIN_HEALTH_DIR" ]; then
    mkdir -p "$PLUGIN_HEALTH_DIR"
    log_debug "Created plugin health directory: $PLUGIN_HEALTH_DIR"
  fi

  # Create plugin registry if it doesn't exist
  if [ ! -f "$PLUGIN_REGISTRY_FILE" ]; then
    create_plugin_registry
  fi

  return 0
}

# Create initial plugin registry
create_plugin_registry() {
  log_debug "Creating plugin registry"

  cat >"$PLUGIN_REGISTRY_FILE" <<'EOF'
{
  "registry_version": "1.0",
  "last_updated": "",
  "plugins": {}
}
EOF

  log_debug "Created plugin registry: $PLUGIN_REGISTRY_FILE"
}

# Register a plugin with health tracking
register_plugin_health() {
  local plugin_name="$1"
  local plugin_version="${2:-1.0.0}"
  local plugin_description="${3:-No description}"
  local plugin_dependencies="${4:-[]}"

  log_debug "Registering plugin health: $plugin_name v$plugin_version"

  if ! command -v jq >/dev/null 2>&1; then
    log_warning "jq not available - plugin health registration skipped"
    return 1
  fi

  # Get plugin metadata if available
  local plugin_metadata="{}"
  if declare -f "${plugin_name}_plugin_metadata" >/dev/null; then
    plugin_metadata=$("${plugin_name}"_plugin_metadata 2>/dev/null || echo "{}")
  fi

  # Create plugin health entry
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local plugin_entry
  plugin_entry=$(
    cat <<EOF
{
  "name": "$plugin_name",
  "version": "$plugin_version",
  "description": "$plugin_description",
  "dependencies": $plugin_dependencies,
  "metadata": $plugin_metadata,
  "health": {
    "status": "unknown",
    "last_check": "$timestamp",
    "last_success": null,
    "last_failure": null,
    "failure_count": 0,
    "success_count": 0,
    "uptime_percentage": 0.0
  },
  "registered": "$timestamp",
  "last_updated": "$timestamp"
}
EOF
  )

  # Update registry
  local updated_registry
  updated_registry=$(jq ".plugins[\"$plugin_name\"] = $plugin_entry | .last_updated = \"$timestamp\"" "$PLUGIN_REGISTRY_FILE" 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "$updated_registry" >"$PLUGIN_REGISTRY_FILE"
    log_debug "Registered plugin health: $plugin_name"
  else
    log_error "Failed to register plugin health: $plugin_name"
    return 1
  fi

  return 0
}

# Update plugin health status
update_plugin_health() {
  local plugin_name="$1"
  local status="$2"         # success, failure, warning
  local status_message="$3" # optional status message
  local check_duration="$4" # optional check duration in ms

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local timestamp_epoch
  timestamp_epoch=$(date +%s)

  log_debug "Updating plugin health: $plugin_name -> $status"

  # Create health log entry
  local health_log="$PLUGIN_HEALTH_DIR/${plugin_name}_health.log"
  echo "$timestamp_epoch,$status,$status_message,$check_duration" >>"$health_log"

  # Update registry
  local update_cmd=""
  case "$status" in
  "success")
    update_cmd=".plugins[\"$plugin_name\"].health.last_success = \"$timestamp\" | .plugins[\"$plugin_name\"].health.success_count += 1 | .plugins[\"$plugin_name\"].health.status = \"healthy\""
    ;;
  "failure")
    update_cmd=".plugins[\"$plugin_name\"].health.last_failure = \"$timestamp\" | .plugins[\"$plugin_name\"].health.failure_count += 1 | .plugins[\"$plugin_name\"].health.status = \"failing\""
    ;;
  "warning")
    update_cmd=".plugins[\"$plugin_name\"].health.status = \"warning\""
    ;;
  *)
    update_cmd=".plugins[\"$plugin_name\"].health.status = \"unknown\""
    ;;
  esac

  # Always update last_check
  update_cmd="$update_cmd | .plugins[\"$plugin_name\"].health.last_check = \"$timestamp\""

  # Calculate uptime percentage
  local success_count failure_count
  success_count=$(jq -r ".plugins[\"$plugin_name\"].health.success_count // 0" "$PLUGIN_REGISTRY_FILE" 2>/dev/null)
  failure_count=$(jq -r ".plugins[\"$plugin_name\"].health.failure_count // 0" "$PLUGIN_REGISTRY_FILE" 2>/dev/null)

  if [ "$status" = "success" ]; then
    success_count=$((success_count + 1))
  elif [ "$status" = "failure" ]; then
    failure_count=$((failure_count + 1))
  fi

  local total_checks=$((success_count + failure_count))
  local uptime_percentage=0
  if [ "$total_checks" -gt 0 ]; then
    uptime_percentage=$(echo "scale=2; $success_count * 100 / $total_checks" | bc 2>/dev/null || echo "0")
  fi

  update_cmd="$update_cmd | .plugins[\"$plugin_name\"].health.uptime_percentage = $uptime_percentage"

  # Apply update
  local updated_registry
  updated_registry=$(jq "$update_cmd" "$PLUGIN_REGISTRY_FILE" 2>/dev/null)

  if [ $? -eq 0 ]; then
    echo "$updated_registry" >"$PLUGIN_REGISTRY_FILE"
  else
    log_error "Failed to update plugin health: $plugin_name"
    return 1
  fi

  return 0
}

# Get plugin health status
get_plugin_health() {
  local plugin_name="$1"

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not available"
    return 1
  fi

  jq -r ".plugins[\"$plugin_name\"].health // {\"status\": \"unknown\"}" "$PLUGIN_REGISTRY_FILE" 2>/dev/null
}

# Get plugin version
get_plugin_version() {
  local plugin_name="$1"

  if ! command -v jq >/dev/null 2>&1; then
    echo "unknown"
    return 1
  fi

  jq -r ".plugins[\"$plugin_name\"].version // \"unknown\"" "$PLUGIN_REGISTRY_FILE" 2>/dev/null
}

# Check for plugin updates (placeholder - would integrate with actual update mechanism)
check_plugin_updates() {
  local plugin_name="$1"

  log_debug "Checking for updates: $plugin_name"

  # This is a placeholder implementation
  # In a real system, this would check against a remote registry or repository

  local current_version
  current_version=$(get_plugin_version "$plugin_name")

  # Simulate version check (replace with actual update mechanism)
  local latest_version="$current_version"
  local update_available=false

  # Example: if plugin has a check_updates function, call it
  if declare -f "${plugin_name}_check_updates" >/dev/null; then
    latest_version=$("${plugin_name}"_check_updates 2>/dev/null || echo "$current_version")
    if [ "$latest_version" != "$current_version" ]; then
      update_available=true
    fi
  fi

  cat <<EOF
{
  "plugin": "$plugin_name",
  "current_version": "$current_version",
  "latest_version": "$latest_version",
  "update_available": $update_available,
  "checked": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Get plugin health summary
get_plugin_health_summary() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not available for health summary"
    return 1
  fi

  local total_plugins healthy_plugins failing_plugins warning_plugins unknown_plugins

  total_plugins=$(jq -r '.plugins | length' "$PLUGIN_REGISTRY_FILE" 2>/dev/null)
  healthy_plugins=$(jq -r '[.plugins[] | select(.health.status == "healthy")] | length' "$PLUGIN_REGISTRY_FILE" 2>/dev/null)
  failing_plugins=$(jq -r '[.plugins[] | select(.health.status == "failing")] | length' "$PLUGIN_REGISTRY_FILE" 2>/dev/null)
  warning_plugins=$(jq -r '[.plugins[] | select(.health.status == "warning")] | length' "$PLUGIN_REGISTRY_FILE" 2>/dev/null)
  unknown_plugins=$(jq -r '[.plugins[] | select(.health.status == "unknown")] | length' "$PLUGIN_REGISTRY_FILE" 2>/dev/null)

  cat <<EOF
{
  "total_plugins": $total_plugins,
  "healthy": $healthy_plugins,
  "failing": $failing_plugins,
  "warning": $warning_plugins,
  "unknown": $unknown_plugins,
  "health_percentage": $(echo "scale=2; $healthy_plugins * 100 / $total_plugins" | bc 2>/dev/null || echo "0"),
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# List all plugin health statuses
list_plugin_health() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Plugin Health Status (jq not available for detailed view)"
    return 1
  fi

  echo "Plugin Health Status:"
  echo "===================="

  jq -r '.plugins | to_entries[] | "\(.key)|\(.value.version)|\(.value.health.status)|\(.value.health.uptime_percentage)|\(.value.health.last_check)"' "$PLUGIN_REGISTRY_FILE" 2>/dev/null | while IFS='|' read -r name version status uptime last_check; do
    local status_icon
    case "$status" in
    "healthy") status_icon="✅" ;;
    "failing") status_icon="❌" ;;
    "warning") status_icon="⚠️" ;;
    *) status_icon="❓" ;;
    esac

    printf "%-15s %-8s %s %-8s %6.1f%% %s\n" "$name" "v$version" "$status_icon" "$status" "$uptime" "$last_check"
  done
}

# Check plugin dependencies
check_plugin_dependencies() {
  local plugin_name="$1"

  if ! command -v jq >/dev/null 2>&1; then
    echo "Dependency check skipped (jq not available)"
    return 1
  fi

  local dependencies
  dependencies=$(jq -r ".plugins[\"$plugin_name\"].dependencies[]?" "$PLUGIN_REGISTRY_FILE" 2>/dev/null)

  if [ -z "$dependencies" ]; then
    echo "No dependencies for $plugin_name"
    return 0
  fi

  echo "Checking dependencies for $plugin_name:"
  while IFS= read -r dependency; do
    if [ -n "$dependency" ]; then
      if command -v "$dependency" >/dev/null 2>&1; then
        echo "✅ $dependency - Available"
      else
        echo "❌ $dependency - Missing"
      fi
    fi
  done <<<"$dependencies"
}

# Generate plugin health report
generate_plugin_health_report() {
  local output_file="${1:-$PLUGIN_HEALTH_DIR/health_report_$(date +%Y%m%d_%H%M%S).json}"

  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq required for health report generation"
    return 1
  fi

  local summary
  summary=$(get_plugin_health_summary)

  local full_report
  full_report=$(jq -n \
    --argjson summary "$summary" \
    --slurpfile registry "$PLUGIN_REGISTRY_FILE" \
    '{
      "report_generated": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      "summary": $summary,
      "plugins": $registry[0].plugins
    }')

  echo "$full_report" >"$output_file"
  echo "Health report generated: $output_file"
}

# Cleanup old health logs
cleanup_health_logs() {
  local days_to_keep="${1:-30}"

  log_debug "Cleaning up health logs older than $days_to_keep days"

  find "$PLUGIN_HEALTH_DIR" -name "*_health.log" -type f -mtime +"$days_to_keep" -delete 2>/dev/null

  log_debug "Health log cleanup completed"
}

# Export functions for use by other modules
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f init_plugin_health_system
  export -f register_plugin_health
  export -f update_plugin_health
  export -f get_plugin_health
  export -f get_plugin_version
  export -f check_plugin_updates
  export -f get_plugin_health_summary
  export -f list_plugin_health
  export -f check_plugin_dependencies
  export -f generate_plugin_health_report
  export -f cleanup_health_logs
fi
