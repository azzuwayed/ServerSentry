#!/usr/bin/env bash
#
# ServerSentry v2 - CLI Colors and UI Utilities
#
# This module provides color codes, formatting functions, and UI utilities
# for command-line interface components

# Source core utilities for command checking
if [[ -f "$BASE_DIR/lib/core/utils.sh" ]]; then
  source "$BASE_DIR/lib/core/utils.sh"
fi

# Color detection
init_colors() {
  # Check if terminal supports colors
  if [[ -t 1 ]] && util_command_exists tput; then
    local colors
    colors=$(tput colors 2>/dev/null) || colors=0
    if [[ $colors -ge 8 ]]; then
      COLOR_SUPPORT=true
    else
      COLOR_SUPPORT=false
    fi
  else
    COLOR_SUPPORT=false
  fi

  # Override color support if NO_COLOR environment variable is set
  if [[ -n "${NO_COLOR:-}" ]]; then
    COLOR_SUPPORT=false
  fi

  # Initialize color codes based on support
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    # Text formatting
    RESET="$(tput sgr0 2>/dev/null)"
    BOLD="$(tput bold 2>/dev/null)"
    DIM="$(tput dim 2>/dev/null)"
    UNDERLINE="$(tput smul 2>/dev/null)"
    ITALIC="$(tput sitm 2>/dev/null)"
    BLINK="$(tput blink 2>/dev/null)"
    REVERSE="$(tput rev 2>/dev/null)"

    # Standard colors
    BLACK="$(tput setaf 0 2>/dev/null)"
    RED="$(tput setaf 1 2>/dev/null)"
    GREEN="$(tput setaf 2 2>/dev/null)"
    YELLOW="$(tput setaf 3 2>/dev/null)"
    BLUE="$(tput setaf 4 2>/dev/null)"
    MAGENTA="$(tput setaf 5 2>/dev/null)"
    CYAN="$(tput setaf 6 2>/dev/null)"
    WHITE="$(tput setaf 7 2>/dev/null)"

    # Bright colors (if supported)
    BRIGHT_BLACK="$(tput setaf 8 2>/dev/null)"
    BRIGHT_RED="$(tput setaf 9 2>/dev/null)"
    BRIGHT_GREEN="$(tput setaf 10 2>/dev/null)"
    BRIGHT_YELLOW="$(tput setaf 11 2>/dev/null)"
    BRIGHT_BLUE="$(tput setaf 12 2>/dev/null)"
    BRIGHT_MAGENTA="$(tput setaf 13 2>/dev/null)"
    BRIGHT_CYAN="$(tput setaf 14 2>/dev/null)"
    BRIGHT_WHITE="$(tput setaf 15 2>/dev/null)"

    # Background colors
    BG_BLACK="$(tput setab 0 2>/dev/null)"
    BG_RED="$(tput setab 1 2>/dev/null)"
    BG_GREEN="$(tput setab 2 2>/dev/null)"
    BG_YELLOW="$(tput setab 3 2>/dev/null)"
    BG_BLUE="$(tput setab 4 2>/dev/null)"
    BG_MAGENTA="$(tput setab 5 2>/dev/null)"
    BG_CYAN="$(tput setab 6 2>/dev/null)"
    BG_WHITE="$(tput setab 7 2>/dev/null)"
  else
    # No color support - set all to empty
    RESET="" BOLD="" DIM="" UNDERLINE="" ITALIC="" BLINK="" REVERSE=""
    BLACK="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
    BRIGHT_BLACK="" BRIGHT_RED="" BRIGHT_GREEN="" BRIGHT_YELLOW=""
    BRIGHT_BLUE="" BRIGHT_MAGENTA="" BRIGHT_CYAN="" BRIGHT_WHITE=""
    BG_BLACK="" BG_RED="" BG_GREEN="" BG_YELLOW=""
    BG_BLUE="" BG_MAGENTA="" BG_CYAN="" BG_WHITE=""
  fi

  # Semantic colors for consistent UI
  SUCCESS_COLOR="$GREEN"
  WARNING_COLOR="$YELLOW"
  ERROR_COLOR="$RED"
  INFO_COLOR="$BLUE"
  DEBUG_COLOR="$MAGENTA"
  CRITICAL_COLOR="$BRIGHT_RED"

  # Status symbols
  if util_command_exists printf; then
    # Use Unicode symbols if printf supports them
    SYMBOL_OK="✅"
    SYMBOL_WARNING="⚠️"
    SYMBOL_ERROR="❌"
    SYMBOL_INFO="ℹ️"
    SYMBOL_DEBUG="🔍"
    SYMBOL_CRITICAL="🚨"
    SYMBOL_RUNNING="🟢"
    SYMBOL_STOPPED="🔴"
    SYMBOL_UNKNOWN="❓"
  else
    # Fallback to ASCII symbols
    SYMBOL_OK="[OK]"
    SYMBOL_WARNING="[WARN]"
    SYMBOL_ERROR="[ERR]"
    SYMBOL_INFO="[INFO]"
    SYMBOL_DEBUG="[DBG]"
    SYMBOL_CRITICAL="[CRIT]"
    SYMBOL_RUNNING="[RUN]"
    SYMBOL_STOPPED="[STOP]"
    SYMBOL_UNKNOWN="[?]"
  fi

  # Export color variables
  export COLOR_SUPPORT RESET BOLD DIM UNDERLINE ITALIC BLINK REVERSE
  export BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
  export BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW
  export BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
  export BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
  export SUCCESS_COLOR WARNING_COLOR ERROR_COLOR INFO_COLOR DEBUG_COLOR CRITICAL_COLOR
  export SYMBOL_OK SYMBOL_WARNING SYMBOL_ERROR SYMBOL_INFO SYMBOL_DEBUG SYMBOL_CRITICAL
  export SYMBOL_RUNNING SYMBOL_STOPPED SYMBOL_UNKNOWN
}

# Print functions with color support
print_success() {
  echo "${SUCCESS_COLOR}${BOLD}$*${RESET}"
}

print_warning() {
  echo "${WARNING_COLOR}${BOLD}$*${RESET}"
}

print_error() {
  echo "${ERROR_COLOR}${BOLD}$*${RESET}"
}

print_info() {
  echo "${INFO_COLOR}$*${RESET}"
}

print_debug() {
  echo "${DEBUG_COLOR}$*${RESET}"
}

print_critical() {
  echo "${CRITICAL_COLOR}${BOLD}$*${RESET}"
}

# Status printing functions
print_status() {
  local status="$1"
  shift
  local message="$*"

  case "$status" in
  "ok" | "success")
    echo "${SUCCESS_COLOR}${SYMBOL_OK}${RESET} $message"
    ;;
  "warning" | "warn")
    echo "${WARNING_COLOR}${SYMBOL_WARNING}${RESET} $message"
    ;;
  "error" | "err")
    echo "${ERROR_COLOR}${SYMBOL_ERROR}${RESET} $message"
    ;;
  "info")
    echo "${INFO_COLOR}${SYMBOL_INFO}${RESET} $message"
    ;;
  "debug")
    echo "${DEBUG_COLOR}${SYMBOL_DEBUG}${RESET} $message"
    ;;
  "critical" | "crit")
    echo "${CRITICAL_COLOR}${SYMBOL_CRITICAL}${RESET} $message"
    ;;
  "running")
    echo "${SUCCESS_COLOR}${SYMBOL_RUNNING}${RESET} $message"
    ;;
  "stopped")
    echo "${ERROR_COLOR}${SYMBOL_STOPPED}${RESET} $message"
    ;;
  *)
    echo "${BLUE}${SYMBOL_UNKNOWN}${RESET} $message"
    ;;
  esac
}

# Header printing function
print_header() {
  local text="$1"
  local width="${2:-60}"

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    local separator
    separator=$(printf "%*s" "$width" | tr ' ' '=')
    echo "${BOLD}${BLUE}$separator${RESET}"
    echo "${BOLD}${BLUE}$text${RESET}"
    echo "${BOLD}${BLUE}$separator${RESET}"
  else
    local separator
    separator=$(printf "%*s" "$width" | tr ' ' '=')
    echo "$separator"
    echo "$text"
    echo "$separator"
  fi
}

# Separator function
print_separator() {
  local width="${1:-60}"
  local char="${2:--}"

  local separator
  separator=$(printf "%*s" "$width" | tr " " "$char")
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${DIM}$separator${RESET}"
  else
    echo "$separator"
  fi
}

# Progress bar function
create_progress_bar() {
  local current="$1"
  local total="$2"
  local width="${3:-30}"
  local label="${4:-Progress}"

  local percentage=0
  if [[ "$total" -gt 0 ]]; then
    if util_command_exists bc; then
      percentage=$(echo "scale=0; $current * 100 / $total" | bc)
    else
      percentage=$((current * 100 / total))
    fi
  fi

  local filled_width=$((percentage * width / 100))
  local empty_width=$((width - filled_width))

  local filled
  filled=$(printf "%*s" "$filled_width" | tr ' ' '█')
  local empty
  empty=$(printf "%*s" "$empty_width" | tr ' ' '░')

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "%s: [${GREEN}%s${DIM}%s${RESET}] %3d%% (%d/%d)\n" \
      "$label" "$filled" "$empty" "$percentage" "$current" "$total"
  else
    printf "%s: [%s%s] %3d%% (%d/%d)\n" \
      "$label" "$filled" "$empty" "$percentage" "$current" "$total"
  fi
}

# Metric bar for showing usage vs threshold
create_metric_bar() {
  local value="$1"
  local threshold="$2"
  local label="${3:-Metric}"
  local width="${4:-30}"

  # Ensure numeric values
  if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$threshold" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$label: Invalid numeric values (value=$value, threshold=$threshold)"
    return 1
  fi

  local percentage
  if util_command_exists bc; then
    percentage=$(echo "scale=0; $value" | bc)
  else
    percentage=$(echo "$value" | cut -d. -f1)
  fi

  # Determine color based on threshold
  local bar_color="$GREEN"
  if [[ "$percentage" -ge "$threshold" ]]; then
    bar_color="$RED"
  elif [[ "$percentage" -ge $((threshold * 80 / 100)) ]]; then
    bar_color="$YELLOW"
  fi

  local filled_width=$((percentage * width / 100))
  local threshold_pos=$((threshold * width / 100))
  local empty_width=$((width - filled_width))

  local filled
  filled=$(printf "%*s" "$filled_width" | tr ' ' '█')
  local empty
  empty=$(printf "%*s" "$empty_width" | tr ' ' '░')

  # Create threshold marker
  local bar="$filled$empty"
  if [[ "$threshold_pos" -le "$width" ]]; then
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      # Insert threshold marker at appropriate position
      local before_threshold="${bar:0:$threshold_pos}"
      local after_threshold="${bar:$((threshold_pos + 1))}"
      bar="${before_threshold}${RED}|${RESET}${after_threshold}"
    fi
  fi

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "%s: [${bar_color}%s${RESET}] %.1f%% (threshold: %.1f%%)\n" \
      "$label" "$bar" "$value" "$threshold"
  else
    printf "%s: [%s] %.1f%% (threshold: %.1f%%)\n" \
      "$label" "$bar" "$value" "$threshold"
  fi
}

# Table printing functions
print_table_header() {
  local -a headers=("$@")
  local separator=""

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "${BOLD}${BLUE}"
  fi

  for header in "${headers[@]}"; do
    printf "%-20s" "$header"
    separator+="--------------------"
  done
  printf "\n"

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "${RESET}${DIM}%s${RESET}\n" "$separator"
  else
    printf "%s\n" "$separator"
  fi
}

print_table_row() {
  local -a columns=("$@")
  for column in "${columns[@]}"; do
    printf "%-20s" "$column"
  done
  printf "\n"
}

# Spinner for long-running operations
show_spinner() {
  local pid="$1"
  local message="${2:-Working...}"
  local delay=0.1
  local spinstr='|/-\'

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "${BLUE}%s${RESET} " "$message"
  else
    printf "%s " "$message"
  fi

  while ps -p "$pid" >/dev/null 2>&1; do
    local temp=${spinstr#?}
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      printf "${YELLOW}[%c]${RESET}" "$spinstr"
    else
      printf "[%c]" "$spinstr"
    fi
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b"
  done
  printf "   \b\b\b"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    printf "${GREEN}Done!${RESET}\n"
  else
    printf "Done!\n"
  fi
}

# Box drawing for important messages
print_box() {
  local text="$1"
  local width="${2:-60}"
  local padding=2

  local content_width=$((width - 2 * padding - 2))
  local top_bottom
  top_bottom=$(printf "%*s" "$width" | tr ' ' '=')

  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo "${BOLD}${BLUE}${top_bottom}${RESET}"
    printf "${BOLD}${BLUE}|${RESET}%*s${BOLD}${BLUE}|${RESET}\n" "$((width - 2))" ""
    printf "${BOLD}${BLUE}|${RESET}%*s%-*s%*s${BOLD}${BLUE}|${RESET}\n" \
      "$padding" "" "$content_width" "$text" "$padding" ""
    printf "${BOLD}${BLUE}|${RESET}%*s${BOLD}${BLUE}|${RESET}\n" "$((width - 2))" ""
    echo "${BOLD}${BLUE}${top_bottom}${RESET}"
  else
    echo "$top_bottom"
    printf "|%*s|\n" "$((width - 2))" ""
    printf "|%*s%-*s%*s|\n" "$padding" "" "$content_width" "$text" "$padding" ""
    printf "|%*s|\n" "$((width - 2))" ""
    echo "$top_bottom"
  fi
}

# Initialize colors when this file is sourced
init_colors
