#!/bin/bash
#
# ServerSentry v2 - Advanced Text-based User Interface (TUI)
#
# This module provides an enhanced interactive terminal interface with real-time monitoring,
# dashboards, configuration management, and system controls

# TUI Configuration
TUI_REFRESH_RATE=2
TUI_LOG_FILE="${BASE_DIR}/logs/tui.log"
TUI_STATE_FILE="${BASE_DIR}/logs/tui.state"

# Color definitions for TUI
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && [ "${NO_COLOR:-}" = "" ]; then
  TUI_RED='\033[0;31m'
  TUI_GREEN='\033[0;32m'
  TUI_YELLOW='\033[1;33m'
  TUI_BLUE='\033[0;34m'
  TUI_PURPLE='\033[0;35m'
  TUI_CYAN='\033[0;36m'
  TUI_WHITE='\033[1;37m'
  TUI_GRAY='\033[0;37m'
  TUI_BOLD='\033[1m'
  TUI_DIM='\033[2m'
  TUI_NC='\033[0m'
  TUI_CLEAR='\033[2J'
  TUI_HOME='\033[H'
else
  TUI_RED='' TUI_GREEN='' TUI_YELLOW='' TUI_BLUE='' TUI_PURPLE=''
  TUI_CYAN='' TUI_WHITE='' TUI_GRAY='' TUI_BOLD='' TUI_DIM=''
  TUI_NC='' TUI_CLEAR='' TUI_HOME=''
fi

# Initialize advanced TUI system
init_advanced_tui() {
  log_debug "Initializing advanced TUI system"

  # Source required modules
  if [ -f "$BASE_DIR/lib/ui/cli/commands.sh" ]; then
    source "$BASE_DIR/lib/ui/cli/commands.sh"
  fi

  # Create TUI log file
  if [ ! -f "$TUI_LOG_FILE" ]; then
    touch "$TUI_LOG_FILE"
  fi

  # Set up signal handlers for TUI
  trap 'handle_tui_exit' INT TERM
  trap 'handle_tui_resize' WINCH

  # Hide cursor
  printf '\033[?25l'

  return 0
}

# Handle TUI exit
handle_tui_exit() {
  # Show cursor
  printf '\033[?25h'

  # Clear screen
  clear

  echo "Exiting ServerSentry TUI..."
  exit 0
}

# Handle terminal resize
handle_tui_resize() {
  # Get new terminal size
  get_terminal_size

  # Redraw current screen
  case "$current_screen" in
  "dashboard") show_dashboard ;;
  "plugins") show_plugin_screen ;;
  "composite") show_composite_screen ;;
  "anomaly") show_anomaly_screen ;;
  "notifications") show_notification_screen ;;
  "logs") show_log_screen ;;
  esac
}

# Get terminal size
get_terminal_size() {
  if command -v tput >/dev/null 2>&1; then
    TERM_WIDTH=$(tput cols 2>/dev/null || echo "80")
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo "24")
  else
    TERM_WIDTH=80
    TERM_HEIGHT=24
  fi
}

# Main TUI entry point
start_advanced_tui() {
  init_advanced_tui
  get_terminal_size

  local current_screen="dashboard"
  local selected_option=0
  local auto_refresh=true

  while true; do
    case "$current_screen" in
    "dashboard")
      show_dashboard
      handle_dashboard_input current_screen selected_option auto_refresh
      ;;
    "plugins")
      show_plugin_screen
      handle_plugin_input current_screen selected_option
      ;;
    "composite")
      show_composite_screen
      handle_composite_input current_screen selected_option
      ;;
    "anomaly")
      show_anomaly_screen
      handle_anomaly_input current_screen selected_option
      ;;
    "notifications")
      show_notification_screen
      handle_notification_input current_screen selected_option
      ;;
    "logs")
      show_log_screen
      handle_log_input current_screen selected_option
      ;;
    "config")
      show_config_screen
      handle_config_input current_screen selected_option
      ;;
    "exit")
      handle_tui_exit
      ;;
    esac
  done
}

# Show main dashboard
show_dashboard() {
  clear
  printf "${TUI_HOME}"

  # Header
  draw_header "ServerSentry v2 - System Dashboard"

  # Get system metrics
  local plugin_results
  plugin_results=$(run_all_plugin_checks 2>/dev/null)

  # Dashboard layout
  local col1_width=$((TERM_WIDTH / 3))
  local col2_width=$((TERM_WIDTH / 3))
  local col3_width=$((TERM_WIDTH - col1_width - col2_width))

  # Row 1: System Status
  draw_system_status_panel "$plugin_results" "$col1_width"

  # Row 2: Resource Usage
  printf "\n"
  draw_resource_usage_panel "$plugin_results" "$col2_width"

  # Row 3: Recent Activity
  printf "\n"
  draw_activity_panel "$col3_width"

  # Navigation menu
  printf "\n"
  draw_navigation_menu

  # Footer
  draw_footer "Press [1-7] for navigation, [r] refresh, [a] auto-refresh, [q] quit"
}

# Draw header with title and timestamp
draw_header() {
  local title="$1"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  printf "${TUI_BOLD}${TUI_CYAN}"
  printf "╔"
  for ((i = 1; i < TERM_WIDTH - 1; i++)); do printf "═"; done
  printf "╗${TUI_NC}\n"

  printf "${TUI_BOLD}${TUI_CYAN}║${TUI_NC} "
  printf "${TUI_BOLD}$title${TUI_NC}"

  # Right-align timestamp
  local title_len=${#title}
  local timestamp_len=${#timestamp}
  local spaces=$((TERM_WIDTH - title_len - timestamp_len - 5))
  for ((i = 0; i < spaces; i++)); do printf " "; done
  printf "${TUI_DIM}$timestamp${TUI_NC}"
  printf " ${TUI_BOLD}${TUI_CYAN}║${TUI_NC}\n"

  printf "${TUI_BOLD}${TUI_CYAN}"
  printf "╚"
  for ((i = 1; i < TERM_WIDTH - 1; i++)); do printf "═"; done
  printf "╝${TUI_NC}\n"
}

# Draw system status panel
draw_system_status_panel() {
  local plugin_results="$1"
  local width="$2"

  printf "${TUI_BOLD}System Status:${TUI_NC}\n"
  printf "├─────────────────┐\n"

  # Monitor service status
  if is_monitoring_running; then
    printf "│ Service: ${TUI_GREEN}●${TUI_NC} Running │\n"
  else
    printf "│ Service: ${TUI_RED}●${TUI_NC} Stopped │\n"
  fi

  # Plugin status
  if command -v jq >/dev/null 2>&1 && [ -n "$plugin_results" ]; then
    local plugin_count
    plugin_count=$(echo "$plugin_results" | jq '.plugins | length' 2>/dev/null || echo "0")
    printf "│ Plugins: $plugin_count active │\n"

    # Health summary
    local healthy_count warning_count error_count
    healthy_count=$(echo "$plugin_results" | jq '[.plugins[] | select(.status_code == 0)] | length' 2>/dev/null || echo "0")
    warning_count=$(echo "$plugin_results" | jq '[.plugins[] | select(.status_code == 1)] | length' 2>/dev/null || echo "0")
    error_count=$(echo "$plugin_results" | jq '[.plugins[] | select(.status_code == 2)] | length' 2>/dev/null || echo "0")

    printf "│ Health: ${TUI_GREEN}$healthy_count${TUI_NC}/${TUI_YELLOW}$warning_count${TUI_NC}/${TUI_RED}$error_count${TUI_NC} │\n"
  else
    printf "│ Plugins: N/A       │\n"
    printf "│ Health: N/A        │\n"
  fi

  printf "└─────────────────┘\n"
}

# Draw resource usage panel
draw_resource_usage_panel() {
  local plugin_results="$1"
  local width="$2"

  printf "${TUI_BOLD}Resource Usage:${TUI_NC}\n"
  printf "├─────────────────────────────┐\n"

  if command -v jq >/dev/null 2>&1 && [ -n "$plugin_results" ]; then
    # CPU Usage
    local cpu_value
    cpu_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="cpu") | .metrics.value // "N/A"' 2>/dev/null)
    draw_metric_bar "CPU" "$cpu_value" 80 25

    # Memory Usage
    local memory_value
    memory_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="memory") | .metrics.value // "N/A"' 2>/dev/null)
    draw_metric_bar "Memory" "$memory_value" 85 25

    # Disk Usage
    local disk_value
    disk_value=$(echo "$plugin_results" | jq -r '.plugins[] | select(.name=="disk") | .metrics.value // "N/A"' 2>/dev/null)
    draw_metric_bar "Disk" "$disk_value" 90 25
  else
    printf "│ CPU:    [N/A]               │\n"
    printf "│ Memory: [N/A]               │\n"
    printf "│ Disk:   [N/A]               │\n"
  fi

  printf "└─────────────────────────────┘\n"
}

# Draw metric bar
draw_metric_bar() {
  local label="$1"
  local value="$2"
  local warning_threshold="$3"
  local bar_width="${4:-20}"

  printf "│ %-7s " "$label"

  if [ "$value" = "N/A" ] || ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf "[%-${bar_width}s] N/A │\n" "N/A"
    return
  fi

  # Calculate filled portion
  local filled=$((value * bar_width / 100))
  local empty=$((bar_width - filled))

  # Choose color based on value
  local color
  if [ "$value" -ge "$warning_threshold" ]; then
    color="$TUI_RED"
  elif [ "$value" -ge $((warning_threshold - 20)) ]; then
    color="$TUI_YELLOW"
  else
    color="$TUI_GREEN"
  fi

  # Draw bar
  printf "${color}["
  for ((i = 0; i < filled; i++)); do printf "█"; done
  for ((i = 0; i < empty; i++)); do printf " "; done
  printf "]${TUI_NC} %3d%% │\n" "$value"
}

# Draw activity panel
draw_activity_panel() {
  local width="$1"

  printf "${TUI_BOLD}Recent Activity:${TUI_NC}\n"
  printf "├─────────────────────────────────┐\n"

  # Show recent log entries
  if [ -f "$LOG_FILE" ]; then
    tail -n 5 "$LOG_FILE" | while read -r line; do
      local short_line
      short_line=$(echo "$line" | cut -c1-30)
      printf "│ %-31s │\n" "$short_line"
    done
  else
    printf "│ No recent activity              │\n"
    printf "│                                 │\n"
    printf "│                                 │\n"
    printf "│                                 │\n"
    printf "│                                 │\n"
  fi

  printf "└─────────────────────────────────┘\n"
}

# Draw navigation menu
draw_navigation_menu() {
  printf "\n${TUI_BOLD}Navigation:${TUI_NC}\n"
  printf "${TUI_CYAN}[1]${TUI_NC} Dashboard  "
  printf "${TUI_CYAN}[2]${TUI_NC} Plugins  "
  printf "${TUI_CYAN}[3]${TUI_NC} Composite  "
  printf "${TUI_CYAN}[4]${TUI_NC} Anomaly  "
  printf "${TUI_CYAN}[5]${TUI_NC} Notifications  "
  printf "${TUI_CYAN}[6]${TUI_NC} Logs  "
  printf "${TUI_CYAN}[7]${TUI_NC} Config\n"
}

# Draw footer
draw_footer() {
  local message="$1"

  printf "\n"
  printf "${TUI_DIM}$message${TUI_NC}\n"
}

# Handle dashboard input
handle_dashboard_input() {
  local screen_var="$1"
  local option_var="$2"
  local refresh_var="$3"

  # Read input with timeout for auto-refresh
  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;; # Refresh
    "a" | "A")
      local current_refresh
      eval "current_refresh=\$$refresh_var"
      if [ "$current_refresh" = "true" ]; then
        eval "$refresh_var=false"
      else
        eval "$refresh_var=true"
      fi
      ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  elif [ "$(eval echo \$"$refresh_var")" = "true" ]; then
    # Auto-refresh timeout reached
    return
  fi
}

# Show plugin management screen
show_plugin_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "Plugin Management"

  printf "${TUI_BOLD}Available Plugins:${TUI_NC}\n"
  printf "═══════════════════\n"

  # List plugins with status
  local plugin_results
  plugin_results=$(run_all_plugin_checks 2>/dev/null)

  if command -v jq >/dev/null 2>&1 && [ -n "$plugin_results" ]; then
    echo "$plugin_results" | jq -r '.plugins[] | "\(.name)|\(.status_code)|\(.status_message)|\(.metrics.value // "N/A")"' | while IFS='|' read -r name status_code message value; do
      local status_icon
      case "$status_code" in
      "0") status_icon="${TUI_GREEN}✅${TUI_NC}" ;;
      "1") status_icon="${TUI_YELLOW}⚠️${TUI_NC}" ;;
      "2") status_icon="${TUI_RED}❌${TUI_NC}" ;;
      *) status_icon="${TUI_GRAY}❓${TUI_NC}" ;;
      esac

      printf "$status_icon %-12s %-25s %s\n" "$name" "$message" "$value"
    done
  else
    printf "No plugin data available\n"
  fi

  printf "\n${TUI_BOLD}Plugin Health:${TUI_NC}\n"
  if [ -f "$BASE_DIR/lib/core/plugin_health.sh" ]; then
    source "$BASE_DIR/lib/core/plugin_health.sh"
    get_plugin_health_summary 2>/dev/null | head -10
  else
    printf "Plugin health system not available\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle plugin screen input
handle_plugin_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Show composite checks screen
show_composite_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "Composite Checks"

  printf "${TUI_BOLD}Active Composite Checks:${TUI_NC}\n"
  printf "═══════════════════════════\n"

  if [ -f "$BASE_DIR/lib/core/composite.sh" ]; then
    source "$BASE_DIR/lib/core/composite.sh"

    for config_file in "$COMPOSITE_CONFIG_DIR"/*.conf; do
      if [ -f "$config_file" ]; then
        if parse_composite_config "$config_file" 2>/dev/null; then
          local status_icon
          if [ "$enabled" = "true" ]; then
            status_icon="${TUI_GREEN}●${TUI_NC}"
          else
            status_icon="${TUI_RED}●${TUI_NC}"
          fi

          printf "$status_icon %-25s %s\n" "$name" "$rule"
        fi
      fi
    done
  else
    printf "Composite check system not available\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle composite screen input
handle_composite_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Show anomaly detection screen
show_anomaly_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "Anomaly Detection"

  printf "${TUI_BOLD}Anomaly Detection Status:${TUI_NC}\n"
  printf "══════════════════════════════\n"

  if [ -f "$BASE_DIR/lib/core/anomaly.sh" ]; then
    source "$BASE_DIR/lib/core/anomaly.sh"
    get_anomaly_summary 7 2>/dev/null | head -15
  else
    printf "Anomaly detection system not available\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle anomaly screen input
handle_anomaly_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Show notification screen
show_notification_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "Notification System"

  printf "${TUI_BOLD}Notification Providers:${TUI_NC}\n"
  printf "═════════════════════════\n"

  # Check notification providers
  local providers=("teams" "slack" "email" "discord" "webhook")
  for provider in "${providers[@]}"; do
    if [ -f "$BASE_DIR/lib/notifications/$provider/$provider.sh" ]; then
      printf "${TUI_GREEN}●${TUI_NC} %-10s Available\n" "$provider"
    else
      printf "${TUI_RED}●${TUI_NC} %-10s Not installed\n" "$provider"
    fi
  done

  printf "\n${TUI_BOLD}Recent Notifications:${TUI_NC}\n"
  printf "═══════════════════════\n"

  # Show recent notification logs if available
  if [ -f "$BASE_DIR/logs/notifications.log" ]; then
    tail -n 10 "$BASE_DIR/logs/notifications.log" | while read -r line; do
      local short_line
      short_line=$(echo "$line" | cut -c1-60)
      printf "%s\n" "$short_line"
    done
  else
    printf "No recent notifications\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle notification screen input
handle_notification_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Show log screen
show_log_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "System Logs"

  printf "${TUI_BOLD}Recent Log Entries:${TUI_NC}\n"
  printf "════════════════════\n"

  if [ -f "$LOG_FILE" ]; then
    tail -n $((TERM_HEIGHT - 10)) "$LOG_FILE" | while read -r line; do
      printf "%s\n" "$line"
    done
  else
    printf "No log file found\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle log screen input
handle_log_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Show configuration screen
show_config_screen() {
  clear
  printf "${TUI_HOME}"

  draw_header "Configuration"

  printf "${TUI_BOLD}Current Configuration:${TUI_NC}\n"
  printf "═══════════════════════\n"

  if [ -f "$MAIN_CONFIG" ]; then
    cat "$MAIN_CONFIG" | head -n $((TERM_HEIGHT - 10))
  else
    printf "Configuration file not found\n"
  fi

  draw_footer "Press [1-7] for navigation, [r] refresh, [q] quit"
}

# Handle config screen input
handle_config_input() {
  local screen_var="$1"
  local option_var="$2"

  local input
  if read -t $TUI_REFRESH_RATE -n 1 input 2>/dev/null; then
    case "$input" in
    "1") eval "$screen_var=dashboard" ;;
    "2") eval "$screen_var=plugins" ;;
    "3") eval "$screen_var=composite" ;;
    "4") eval "$screen_var=anomaly" ;;
    "5") eval "$screen_var=notifications" ;;
    "6") eval "$screen_var=logs" ;;
    "7") eval "$screen_var=config" ;;
    "r" | "R") return ;;
    "q" | "Q") eval "$screen_var=exit" ;;
    esac
  fi
}

# Export functions for use by main TUI
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f init_advanced_tui
  export -f start_advanced_tui
  export -f show_dashboard
  export -f handle_tui_exit
fi
