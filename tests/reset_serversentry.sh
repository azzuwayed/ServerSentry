#!/usr/bin/env bash
#
# ServerSentry v2 - System Reset Script
#
# This script resets ServerSentry to a fresh installation state by:
# - Stopping all running services
# - Removing generated configuration files
# - Clearing all logs and cache files
# - Removing temporary files and PID files
# - Resetting to default state
#
# Usage: ./tests/reset_serversentry.sh [--force] [--keep-config]

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# Color definitions for output
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]] && command -v tput >/dev/null 2>&1; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  PURPLE=""
  CYAN=""
  WHITE=""
  BOLD=""
  RESET=""
fi

# Print functions
print_header() {
  echo -e "${PURPLE}${BOLD}$1${RESET}"
}

print_success() {
  echo -e "${GREEN}✅ $1${RESET}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${RESET}"
}

print_error() {
  echo -e "${RED}❌ $1${RESET}"
}

print_info() {
  echo -e "${CYAN}ℹ️  $1${RESET}"
}

print_separator() {
  local width="${1:-60}"
  printf '%*s\n' "$width" '' | tr ' ' '='
}

# Configuration
FORCE_RESET=false
KEEP_CONFIG=false
DRY_RUN=false

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --force)
      FORCE_RESET=true
      shift
      ;;
    --keep-config)
      KEEP_CONFIG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help | -h)
      show_help
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      show_help
      exit 1
      ;;
    esac
  done
}

# Show help message
show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Reset ServerSentry to a fresh installation state.

Options:
  --force         Skip confirmation prompts
  --keep-config   Keep main configuration files (serversentry.yaml)
  --dry-run       Show what would be done without actually doing it
  --help, -h      Show this help message

Examples:
  $0                    # Interactive reset with confirmation
  $0 --force            # Reset without confirmation
  $0 --keep-config      # Reset but keep main configuration
  $0 --dry-run          # Preview what would be reset

This script will:
  1. Stop all ServerSentry services
  2. Remove PID files and lock files
  3. Clear all log files and archives
  4. Remove cache and temporary files
  5. Clear plugin state and performance data
  6. Reset diagnostic reports
  7. Optionally remove configuration files

EOF
}

# Execute command with dry-run support
execute_command() {
  local description="$1"
  local command="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    # Only show high-level actions in dry run, not every individual command
    return 0
  else
    print_info "$description"
    eval "$command" 2>/dev/null || true
  fi
}

# Execute command with dry-run support (verbose version for detailed operations)
execute_command_verbose() {
  local description="$1"
  local command="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] $description"
  else
    eval "$command" 2>/dev/null || true
  fi
}

# Stop ServerSentry services
stop_services() {
  print_header "Stopping ServerSentry Services"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would stop ServerSentry services:"
    print_info "  • Check for monitoring service PID file"
    print_info "  • Gracefully stop running processes (SIGTERM)"
    print_info "  • Force stop if needed after 10 second timeout (SIGKILL)"
    print_info "  • Stop any other ServerSentry processes"
    print_success "All ServerSentry services would be stopped"
    return 0
  fi

  # Check for running monitoring service
  local pid_file="$BASE_DIR/serversentry.pid"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null || echo "")

    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      execute_command_verbose "Stopping monitoring service (PID: $pid)" "kill -TERM '$pid'"

      # Wait for graceful shutdown
      local wait_count=0
      while [[ $wait_count -lt 10 ]] && ps -p "$pid" >/dev/null 2>&1; do
        sleep 1
        ((wait_count++))
      done

      # Force kill if still running
      if ps -p "$pid" >/dev/null 2>&1; then
        execute_command_verbose "Force stopping monitoring service" "kill -KILL '$pid'"
      fi

      print_success "Monitoring service stopped"
    else
      print_warning "PID file exists but process not running"
    fi
  else
    print_info "No monitoring service PID file found"
  fi

  # Stop any other ServerSentry processes
  local serversentry_pids
  serversentry_pids=$(pgrep -f "serversentry" 2>/dev/null || echo "")

  if [[ -n "$serversentry_pids" ]]; then
    for pid in $serversentry_pids; do
      if ps -p "$pid" >/dev/null 2>&1; then
        execute_command_verbose "Stopping ServerSentry process (PID: $pid)" "kill -TERM '$pid'"
      fi
    done

    # Wait and force kill if necessary
    sleep 2
    serversentry_pids=$(pgrep -f "serversentry" 2>/dev/null || echo "")
    if [[ -n "$serversentry_pids" ]]; then
      for pid in $serversentry_pids; do
        if ps -p "$pid" >/dev/null 2>&1; then
          execute_command_verbose "Force stopping ServerSentry process (PID: $pid)" "kill -KILL '$pid'"
        fi
      done
    fi
  fi

  print_success "All ServerSentry services stopped"
}

# Remove PID and lock files
remove_runtime_files() {
  print_header "Removing Runtime Files"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would remove runtime files:"
    print_info "  • PID files (serversentry.pid, *.pid)"
    print_info "  • Lock files (*.lock)"
    print_info "  • Cache files (.serversentry_cache)"
    print_success "Runtime files would be removed"
    return 0
  fi

  local runtime_files=(
    "$BASE_DIR/serversentry.pid"
    "$BASE_DIR/*.pid"
    "$BASE_DIR/*.lock"
    "$BASE_DIR/tmp/*.pid"
    "$BASE_DIR/tmp/*.lock"
    "$BASE_DIR/.serversentry_cache"
  )

  for pattern in "${runtime_files[@]}"; do
    if [[ "$pattern" == *"*"* ]]; then
      # Handle glob patterns
      for file in $pattern; do
        if [[ -f "$file" ]]; then
          execute_command_verbose "Removing runtime file: $(basename "$file")" "rm -f '$file'"
        fi
      done
    else
      # Handle specific files
      if [[ -f "$pattern" ]]; then
        execute_command_verbose "Removing runtime file: $(basename "$pattern")" "rm -f '$pattern'"
      fi
    fi
  done

  print_success "Runtime files removed"
}

# Clear log files and archives
clear_logs() {
  print_header "Clearing Log Files"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would clear all log files and archives:"
    print_info "  • Main logs (serversentry.log, error.log, audit.log, performance.log)"
    print_info "  • Archive logs (logs/archive/)"
    print_info "  • Specialized logs (anomaly, diagnostics, periodic, composite)"
    print_info "  • Compressed logs (*.gz files)"
    print_info "  • Backup files (*.bak files)"
    print_success "Log files would be cleared"
    return 0
  fi

  local log_directories=(
    "$BASE_DIR/logs"
    "$BASE_DIR/logs/archive"
    "$BASE_DIR/logs/anomaly"
    "$BASE_DIR/logs/diagnostics"
    "$BASE_DIR/logs/periodic"
    "$BASE_DIR/logs/composite"
    "$BASE_DIR/logs/config_backups"
  )

  for log_dir in "${log_directories[@]}"; do
    if [[ -d "$log_dir" ]]; then
      execute_command_verbose "Clearing logs in: $(basename "$log_dir")" "find '$log_dir' -type f -name '*.log' -delete"
      execute_command_verbose "Clearing JSON files in: $(basename "$log_dir")" "find '$log_dir' -type f -name '*.json' -delete"
      execute_command_verbose "Clearing compressed logs in: $(basename "$log_dir")" "find '$log_dir' -type f -name '*.gz' -delete"
      execute_command_verbose "Clearing backup files in: $(basename "$log_dir")" "find '$log_dir' -type f -name '*.bak' -delete"
    fi
  done

  # Clear main log files
  local main_logs=(
    "$BASE_DIR/logs/serversentry.log"
    "$BASE_DIR/logs/error.log"
    "$BASE_DIR/logs/audit.log"
    "$BASE_DIR/logs/performance.log"
  )

  for log_file in "${main_logs[@]}"; do
    if [[ -f "$log_file" ]]; then
      execute_command_verbose "Clearing log file: $(basename "$log_file")" "truncate -s 0 '$log_file' || > '$log_file'"
    fi
  done

  print_success "Log files cleared"
}

# Remove cache and temporary files
clear_cache_and_temp() {
  print_header "Clearing Cache and Temporary Files"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would clear cache and temporary files:"
    print_info "  • tmp/ directory contents (except .gitkeep)"
    print_info "  • Plugin cache files (plugin_*, *_cache, temp_*, *.tmp)"
    print_info "  • System cache files (.serversentry_cache, cache/)"
    print_info "  • Temporary system files (/tmp/serversentry_*)"
    print_success "Cache and temporary files would be cleared"
    return 0
  fi

  # Clear tmp directory contents
  if [[ -d "$BASE_DIR/tmp" ]]; then
    execute_command_verbose "Clearing tmp directory" "find '$BASE_DIR/tmp' -type f ! -name '.gitkeep' -delete"
    execute_command_verbose "Clearing tmp subdirectories" "find '$BASE_DIR/tmp' -type d ! -name 'tmp' -exec rm -rf {} + 2>/dev/null || true"
  fi

  # Clear plugin cache files
  local cache_patterns=(
    "$BASE_DIR/tmp/plugin_*"
    "$BASE_DIR/tmp/*_cache"
    "$BASE_DIR/tmp/temp_*"
    "$BASE_DIR/tmp/*_temp"
    "$BASE_DIR/tmp/*.tmp"
  )

  for pattern in "${cache_patterns[@]}"; do
    execute_command_verbose "Clearing cache pattern: $(basename "$pattern")" "rm -f $pattern"
  done

  # Clear system cache files
  local system_cache_files=(
    "$BASE_DIR/.serversentry_cache"
    "$BASE_DIR/cache"
    "/tmp/serversentry_*"
  )

  for cache_file in "${system_cache_files[@]}"; do
    if [[ -e "$cache_file" ]]; then
      execute_command_verbose "Removing cache: $(basename "$cache_file")" "rm -rf '$cache_file'"
    fi
  done

  print_success "Cache and temporary files cleared"
}

# Reset plugin state
reset_plugin_state() {
  print_header "Resetting Plugin State"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would reset plugin state:"
    print_info "  • Plugin registry (plugin_registry.json)"
    print_info "  • Performance data (plugin_performance.log)"
    print_info "  • Health logs (plugin_health.log)"
    print_info "  • Plugin cache directories"
    print_success "Plugin state would be reset"
    return 0
  fi

  # Clear plugin registry and performance data
  local plugin_state_files=(
    "$BASE_DIR/logs/plugin_registry.json"
    "$BASE_DIR/logs/plugin_performance.log"
    "$BASE_DIR/logs/plugin_health.log"
  )

  for state_file in "${plugin_state_files[@]}"; do
    if [[ -f "$state_file" ]]; then
      execute_command_verbose "Clearing plugin state: $(basename "$state_file")" "rm -f '$state_file'"
    fi
  done

  # Clear plugin cache directories
  local plugin_cache_dirs=(
    "$BASE_DIR/logs/plugins"
    "$BASE_DIR/cache/plugins"
  )

  for cache_dir in "${plugin_cache_dirs[@]}"; do
    if [[ -d "$cache_dir" ]]; then
      execute_command_verbose "Clearing plugin cache directory: $(basename "$cache_dir")" "rm -rf '$cache_dir'"
    fi
  done

  print_success "Plugin state reset"
}

# Clear diagnostic reports
clear_diagnostics() {
  print_header "Clearing Diagnostic Reports"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would clear diagnostic reports:"
    print_info "  • Diagnostic JSON reports (*.json)"
    print_info "  • Diagnostic log files (*.log)"
    print_info "  • Reports directory contents"
    print_success "Diagnostic reports would be cleared"
    return 0
  fi

  local diagnostic_dirs=(
    "$BASE_DIR/logs/diagnostics/reports"
    "$BASE_DIR/logs/diagnostics"
  )

  for diag_dir in "${diagnostic_dirs[@]}"; do
    if [[ -d "$diag_dir" ]]; then
      execute_command_verbose "Clearing diagnostic reports in: $(basename "$diag_dir")" "find '$diag_dir' -type f -name '*.json' -delete"
      execute_command_verbose "Clearing diagnostic logs in: $(basename "$diag_dir")" "find '$diag_dir' -type f -name '*.log' -delete"
    fi
  done

  print_success "Diagnostic reports cleared"
}

# Reset configuration files (optional)
reset_configuration() {
  if [[ "$KEEP_CONFIG" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      print_info "[DRY RUN] Would keep configuration files (--keep-config specified)"
    else
      print_info "Keeping configuration files (--keep-config specified)"
    fi
    return 0
  fi

  print_header "Resetting Configuration Files"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would reset configuration files:"
    print_info "  • Main config (serversentry.yaml, periodic.yaml, diagnostics.conf)"
    print_info "  • Plugin configurations (config/plugins/*.conf)"
    print_info "  • Notification configurations (config/notifications/)"
    print_info "  • Composite configurations (config/composite/)"
    print_success "Configuration files would be reset"
    return 0
  fi

  # Configuration files to reset (but keep directories)
  local config_files=(
    "$BASE_DIR/config/serversentry.yaml"
    "$BASE_DIR/config/periodic.yaml"
    "$BASE_DIR/config/diagnostics.conf"
  )

  for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
      execute_command_verbose "Removing configuration: $(basename "$config_file")" "rm -f '$config_file'"
    fi
  done

  # Clear plugin configurations
  if [[ -d "$BASE_DIR/config/plugins" ]]; then
    execute_command_verbose "Clearing plugin configurations" "find '$BASE_DIR/config/plugins' -type f -name '*.conf' -delete"
  fi

  # Clear notification configurations
  if [[ -d "$BASE_DIR/config/notifications" ]]; then
    execute_command_verbose "Clearing notification configurations" "find '$BASE_DIR/config/notifications' -type f -delete"
  fi

  # Clear composite check configurations
  if [[ -d "$BASE_DIR/config/composite" ]]; then
    execute_command_verbose "Clearing composite configurations" "find '$BASE_DIR/config/composite' -type f -delete"
  fi

  print_success "Configuration files reset"
}

# Clear environment files
clear_environment() {
  print_header "Clearing Environment Files"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would clear environment files:"
    print_info "  • .env, .env.local, .env.production"
    print_success "Environment files would be cleared"
    return 0
  fi

  local env_files=(
    "$BASE_DIR/.env"
    "$BASE_DIR/.env.local"
    "$BASE_DIR/.env.production"
  )

  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      execute_command_verbose "Removing environment file: $(basename "$env_file")" "rm -f '$env_file'"
    fi
  done

  print_success "Environment files cleared"
}

# Recreate essential directories
recreate_directories() {
  print_header "Recreating Essential Directories"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would recreate essential directories:"
    print_info "  • logs/, logs/archive/, logs/diagnostics/, logs/periodic/"
    print_info "  • tmp/, config/, config/plugins/, config/notifications/"
    print_info "  • .gitkeep files where needed"
    print_success "Essential directories would be recreated"
    return 0
  fi

  local essential_dirs=(
    "$BASE_DIR/logs"
    "$BASE_DIR/logs/archive"
    "$BASE_DIR/logs/diagnostics"
    "$BASE_DIR/logs/periodic"
    "$BASE_DIR/tmp"
    "$BASE_DIR/config"
    "$BASE_DIR/config/plugins"
    "$BASE_DIR/config/notifications"
  )

  for dir in "${essential_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      execute_command_verbose "Creating directory: $(basename "$dir")" "mkdir -p '$dir' && chmod 755 '$dir'"
    fi
  done

  # Create .gitkeep files
  execute_command_verbose "Creating .gitkeep in tmp" "touch '$BASE_DIR/tmp/.gitkeep'"

  print_success "Essential directories recreated"
}

# Verify reset completion
verify_reset() {
  print_header "Verifying Reset Completion"

  local issues=0

  # Check for running processes
  local running_processes
  running_processes=$(pgrep -f "serversentry" 2>/dev/null || echo "")
  if [[ -n "$running_processes" ]]; then
    print_warning "ServerSentry processes still running: $running_processes"
    ((issues++))
  else
    print_success "No ServerSentry processes running"
  fi

  # Check for PID files
  if [[ -f "$BASE_DIR/serversentry.pid" ]]; then
    print_warning "PID file still exists"
    ((issues++))
  else
    print_success "No PID files found"
  fi

  # Check log file sizes
  local large_logs
  large_logs=$(find "$BASE_DIR/logs" -type f -name "*.log" -size +1k 2>/dev/null || echo "")
  if [[ -n "$large_logs" ]]; then
    print_warning "Some log files still contain data"
    ((issues++))
  else
    print_success "All log files cleared"
  fi

  # Check cache files
  local cache_files
  cache_files=$(find "$BASE_DIR/tmp" -type f ! -name ".gitkeep" 2>/dev/null || echo "")
  if [[ -n "$cache_files" ]]; then
    print_warning "Some cache files still exist"
    ((issues++))
  else
    print_success "All cache files cleared"
  fi

  if [[ $issues -eq 0 ]]; then
    print_success "Reset completed successfully - ServerSentry is in fresh state"
  else
    print_warning "Reset completed with $issues issues - manual cleanup may be needed"
  fi

  return $issues
}

# Show summary of what will be reset
show_reset_summary() {
  print_header "ServerSentry Reset Summary"
  echo ""
  echo "The following actions will be performed:"
  echo ""
  echo "🛑 Stop all ServerSentry services and processes"
  echo "🗑️  Remove PID files and lock files"
  echo "📝 Clear all log files and archives"
  echo "🗂️  Remove cache and temporary files"
  echo "🔌 Reset plugin state and performance data"
  echo "🔍 Clear diagnostic reports"
  echo "🌍 Clear environment files"

  if [[ "$KEEP_CONFIG" == "true" ]]; then
    echo "⚙️  Keep configuration files (--keep-config)"
  else
    echo "⚙️  Reset configuration files to defaults"
  fi

  echo "📁 Recreate essential directories"
  echo "✅ Verify reset completion"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    print_info "This is a dry run - no actual changes will be made"
  fi
}

# Main execution function
main() {
  # Parse command line arguments
  parse_arguments "$@"

  # Change to base directory
  cd "$BASE_DIR"

  # Show header
  print_separator 70
  print_header "ServerSentry v2 - System Reset Script"
  print_separator 70
  echo ""

  # Show summary
  show_reset_summary

  # Confirmation prompt (unless forced or dry run)
  if [[ "$FORCE_RESET" != "true" && "$DRY_RUN" != "true" ]]; then
    echo ""
    read -p "Are you sure you want to reset ServerSentry? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Reset cancelled"
      exit 0
    fi
    echo ""
  fi

  # Execute reset steps
  stop_services
  echo ""

  remove_runtime_files
  echo ""

  clear_logs
  echo ""

  clear_cache_and_temp
  echo ""

  reset_plugin_state
  echo ""

  clear_diagnostics
  echo ""

  reset_configuration
  echo ""

  clear_environment
  echo ""

  recreate_directories
  echo ""

  # Verify reset (skip for dry run)
  if [[ "$DRY_RUN" != "true" ]]; then
    verify_reset
    local verification_result=$?
    echo ""

    if [[ $verification_result -eq 0 ]]; then
      print_separator 70
      print_success "ServerSentry has been successfully reset to fresh installation state!"
      print_info "You can now run './bin/install.sh' to reconfigure or start fresh"
      print_separator 70
    else
      print_separator 70
      print_warning "Reset completed but some issues were detected"
      print_info "Check the warnings above and perform manual cleanup if needed"
      print_separator 70
    fi
  else
    print_separator 70
    print_info "Dry run completed - no actual changes were made"
    print_info "Run without --dry-run to perform the actual reset"
    print_separator 70
  fi
}

# Run main function with all arguments
main "$@"
