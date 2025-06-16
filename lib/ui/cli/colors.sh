#!/usr/bin/env bash

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi
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
    if [[ -z "${BOLD:-}" ]]; then
      BOLD="$(tput bold 2>/dev/null)"
    fi
    if [[ -z "${DIM:-}" ]]; then
      DIM="$(tput dim 2>/dev/null)"
    fi
    if [[ -z "${UNDERLINE:-}" ]]; then
      UNDERLINE="$(tput smul 2>/dev/null)"
    fi
    if [[ -z "${ITALIC:-}" ]]; then
      ITALIC="$(tput sitm 2>/dev/null)"
    fi
    if [[ -z "${BLINK:-}" ]]; then
      BLINK="$(tput blink 2>/dev/null)"
    fi
    if [[ -z "${REVERSE:-}" ]]; then
      REVERSE="$(tput rev 2>/dev/null)"
    fi

    # Standard colors (only set if not already defined)
    if [[ -z "${BLACK:-}" ]]; then
      BLACK="$(tput setaf 0 2>/dev/null)"
    fi
    if [[ -z "${RED:-}" ]]; then
      RED="$(tput setaf 1 2>/dev/null)"
    fi
    if [[ -z "${GREEN:-}" ]]; then
      GREEN="$(tput setaf 2 2>/dev/null)"
    fi
    if [[ -z "${YELLOW:-}" ]]; then
      YELLOW="$(tput setaf 3 2>/dev/null)"
    fi
    if [[ -z "${BLUE:-}" ]]; then
      BLUE="$(tput setaf 4 2>/dev/null)"
    fi
    if [[ -z "${MAGENTA:-}" ]]; then
      MAGENTA="$(tput setaf 5 2>/dev/null)"
    fi
    if [[ -z "${CYAN:-}" ]]; then
      CYAN="$(tput setaf 6 2>/dev/null)"
    fi
    if [[ -z "${WHITE:-}" ]]; then
      WHITE="$(tput setaf 7 2>/dev/null)"
    fi

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
    # No color support - set all to empty (only if not already defined)
    if [[ -z "${RESET:-}" ]]; then RESET=""; fi
    if [[ -z "${BOLD:-}" ]]; then BOLD=""; fi
    if [[ -z "${DIM:-}" ]]; then DIM=""; fi
    if [[ -z "${UNDERLINE:-}" ]]; then UNDERLINE=""; fi
    if [[ -z "${ITALIC:-}" ]]; then ITALIC=""; fi
    if [[ -z "${BLINK:-}" ]]; then BLINK=""; fi
    if [[ -z "${REVERSE:-}" ]]; then REVERSE=""; fi
    if [[ -z "${BLACK:-}" ]]; then BLACK=""; fi
    if [[ -z "${RED:-}" ]]; then RED=""; fi
    if [[ -z "${GREEN:-}" ]]; then GREEN=""; fi
    if [[ -z "${YELLOW:-}" ]]; then YELLOW=""; fi
    if [[ -z "${BLUE:-}" ]]; then BLUE=""; fi
    if [[ -z "${MAGENTA:-}" ]]; then MAGENTA=""; fi
    if [[ -z "${CYAN:-}" ]]; then CYAN=""; fi
    if [[ -z "${WHITE:-}" ]]; then WHITE=""; fi
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

print_debug() {
  echo "${DEBUG_COLOR}$*${RESET}"
}

print_critical() {
  echo "${CRITICAL_COLOR}${BOLD}$*${RESET}"
}

# Status printing functions

# Header printing function

# Separator function

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
  local warning_threshold
  if util_command_exists bc; then
    warning_threshold=$(echo "scale=1; $threshold * 80 / 100" | bc)
    if [[ $(echo "$percentage >= $threshold" | bc) -eq 1 ]]; then
      bar_color="$RED"
    elif [[ $(echo "$percentage >= $warning_threshold" | bc) -eq 1 ]]; then
      bar_color="$YELLOW"
    fi
  else
    # Fallback for systems without bc - convert to integers
    local int_percentage=${percentage%.*}
    local int_threshold=${threshold%.*}
    warning_threshold=$((int_threshold * 80 / 100))
    if [[ "$int_percentage" -ge "$int_threshold" ]]; then
      bar_color="$RED"
    elif [[ "$int_percentage" -ge "$warning_threshold" ]]; then
      bar_color="$YELLOW"
    fi
  fi

  # Calculate bar dimensions using integer arithmetic
  local int_percentage=${percentage%.*} # Remove decimal part
  local int_threshold=${threshold%.*}   # Remove decimal part

  local filled_width=$((int_percentage * width / 100))
  local threshold_pos=$((int_threshold * width / 100))
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
