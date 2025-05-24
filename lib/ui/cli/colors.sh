#!/bin/bash
#
# ServerSentry v2 - CLI Colors and Output Enhancement
#
# This module provides colorized output and enhanced CLI features

# Color definitions
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && [ "${NO_COLOR:-}" = "" ]; then
  # Terminal supports colors
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[1;33m'
  export BLUE='\033[0;34m'
  export PURPLE='\033[0;35m'
  export CYAN='\033[0;36m'
  export WHITE='\033[1;37m'
  export GRAY='\033[0;37m'
  export BOLD='\033[1m'
  export DIM='\033[2m'
  export UNDERLINE='\033[4m'
  export NC='\033[0m' # No Color

  # Status colors
  export COLOR_OK="$GREEN"
  export COLOR_WARNING="$YELLOW"
  export COLOR_ERROR="$RED"
  export COLOR_INFO="$CYAN"
  export COLOR_DEBUG="$GRAY"
else
  # No color support
  export RED=''
  export GREEN=''
  export YELLOW=''
  export BLUE=''
  export PURPLE=''
  export CYAN=''
  export WHITE=''
  export GRAY=''
  export BOLD=''
  export DIM=''
  export UNDERLINE=''
  export NC=''

  export COLOR_OK=''
  export COLOR_WARNING=''
  export COLOR_ERROR=''
  export COLOR_INFO=''
  export COLOR_DEBUG=''
fi

# Print colored message
print_color() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

# Print status messages with icons and colors
print_status() {
  local status="$1"
  local message="$2"

  case "$status" in
  "ok" | "success")
    echo -e "${COLOR_OK}✅ ${message}${NC}"
    ;;
  "warning" | "warn")
    echo -e "${COLOR_WARNING}⚠️  ${message}${NC}"
    ;;
  "error" | "fail")
    echo -e "${COLOR_ERROR}❌ ${message}${NC}"
    ;;
  "info")
    echo -e "${COLOR_INFO}ℹ️  ${message}${NC}"
    ;;
  "debug")
    echo -e "${COLOR_DEBUG}🔍 ${message}${NC}"
    ;;
  *)
    echo -e "${message}"
    ;;
  esac
}

# Create a visual progress bar
create_progress_bar() {
  local current="$1"
  local total="$2"
  local width="${3:-30}"
  local fill_char="${4:-█}"
  local empty_char="${5:-░}"

  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  local bar=""
  for ((i = 0; i < filled; i++)); do
    bar+="$fill_char"
  done
  for ((i = 0; i < empty; i++)); do
    bar+="$empty_char"
  done

  echo -e "${BLUE}[${bar}]${NC} ${percentage}%"
}

# Create a visual metric bar (like for CPU/Memory usage)
create_metric_bar() {
  local value="$1"
  local threshold="$2"
  local label="$3"
  local width="${4:-20}"

  # Handle floating point values
  local value_int
  if command -v bc >/dev/null 2>&1; then
    value_int=$(echo "$value / 1" | bc)
  else
    # Fallback: convert float to int by removing decimal
    value_int=${value%.*}
  fi

  local filled=$((value_int * width / 100))
  local empty=$((width - filled))

  # Determine color based on threshold
  local color
  if command -v bc >/dev/null 2>&1; then
    if [[ $(echo "$value >= $threshold" | bc) -eq 1 ]]; then
      color="$RED"
    elif [[ $(echo "$value >= $threshold - 20" | bc) -eq 1 ]]; then
      color="$YELLOW"
    else
      color="$GREEN"
    fi
  else
    # Fallback comparison for systems without bc
    if [[ $value_int -ge $threshold ]]; then
      color="$RED"
    elif [[ $value_int -ge $((threshold - 20)) ]]; then
      color="$YELLOW"
    else
      color="$GREEN"
    fi
  fi

  local bar=""
  for ((i = 0; i < filled; i++)); do
    bar+="█"
  done
  for ((i = 0; i < empty; i++)); do
    bar+="░"
  done

  echo -e "${label} ${color}[${bar}]${NC} ${value}%"
}

# Print a header with decorative border
print_header() {
  local title="$1"
  local width="${2:-50}"
  local char="${3:-=}"

  local padding=$(((width - ${#title} - 2) / 2))
  local border=""
  local title_line=""

  # Create border
  for ((i = 0; i < width; i++)); do
    border+="$char"
  done

  # Create title line
  title_line="$char"
  for ((i = 0; i < padding; i++)); do
    title_line+=" "
  done
  title_line+="$title"
  for ((i = 0; i < padding; i++)); do
    title_line+=" "
  done
  # Add extra space if title length is odd
  if [ $(((width - ${#title}) % 2)) -eq 1 ]; then
    title_line+=" "
  fi
  title_line+="$char"

  echo -e "${CYAN}${border}${NC}"
  echo -e "${CYAN}${title_line}${NC}"
  echo -e "${CYAN}${border}${NC}"
}

# Print a simple separator line
print_separator() {
  local char="${1:--}"
  local width="${2:-50}"
  local line=""

  for ((i = 0; i < width; i++)); do
    line+="$char"
  done

  echo -e "${GRAY}${line}${NC}"
}

# Show a spinner animation
show_spinner() {
  local pid="$1"
  local message="${2:-Working...}"
  local delay=0.1
  local spinstr='|/-\'

  while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
    local temp=${spinstr#?}
    printf "\r${BLUE}%c${NC} %s" "$spinstr" "$message"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  printf "\r%*s\r" $((${#message} + 3)) ""
}

# Colorize metric values based on thresholds
colorize_metric() {
  local value="$1"
  local threshold="$2"
  local label="$3"
  local unit="${4:-%}"

  local color
  local icon

  if [ "$value" -ge "$threshold" ]; then
    color="$RED"
    icon="🔴"
  elif [ "$value" -ge $((threshold - 20)) ]; then
    color="$YELLOW"
    icon="🟡"
  else
    color="$GREEN"
    icon="🟢"
  fi

  echo -e "${icon} ${label} ${color}${value}${unit}${NC}"
}

# Show a confirmation prompt with colors
confirm_prompt() {
  local message="$1"
  local default="${2:-n}"
  local prompt

  if [ "$default" = "y" ]; then
    prompt="${GREEN}[Y/n]${NC}"
  else
    prompt="${RED}[y/N]${NC}"
  fi

  echo -e "${YELLOW}${message}${NC} $prompt"
  read -r response

  case "$response" in
  [yY] | [yY][eE][sS])
    return 0
    ;;
  [nN] | [nN][oO])
    return 1
    ;;
  "")
    if [ "$default" = "y" ]; then
      return 0
    else
      return 1
    fi
    ;;
  *)
    echo -e "${RED}Please answer yes or no.${NC}"
    confirm_prompt "$message" "$default"
    ;;
  esac
}

# Print a table with headers and rows
print_table() {
  local -n headers_ref=$1
  local -n rows_ref=$2
  local separator="${3:-|}"

  # Calculate column widths
  local -a col_widths
  for ((i = 0; i < ${#headers_ref[@]}; i++)); do
    col_widths[i]=${#headers_ref[i]}
  done

  # Check row widths
  for row in "${rows_ref[@]}"; do
    IFS='|' read -ra COLS <<<"$row"
    for ((i = 0; i < ${#COLS[@]}; i++)); do
      if [ ${#COLS[i]} -gt "${col_widths[i]:-0}" ]; then
        col_widths[i]=${#COLS[i]}
      fi
    done
  done

  # Print header
  local header_line=""
  local separator_line=""
  for ((i = 0; i < ${#headers_ref[@]}; i++)); do
    printf "${BOLD}%-${col_widths[i]}s${NC}" "${headers_ref[i]}"
    if [ $i -lt $((${#headers_ref[@]} - 1)) ]; then
      printf " $separator "
    fi

    # Build separator line
    for ((j = 0; j < ${col_widths[i]}; j++)); do
      separator_line+="-"
    done
    if [ $i -lt $((${#headers_ref[@]} - 1)) ]; then
      separator_line+="---"
    fi
  done
  echo
  echo -e "${GRAY}$separator_line${NC}"

  # Print rows
  for row in "${rows_ref[@]}"; do
    IFS='|' read -ra COLS <<<"$row"
    for ((i = 0; i < ${#COLS[@]}; i++)); do
      printf "%-${col_widths[i]}s" "${COLS[i]}"
      if [ $i -lt $((${#COLS[@]} - 1)) ]; then
        printf " $separator "
      fi
    done
    echo
  done
}

# Export functions for use in other modules
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  export -f print_color
  export -f print_status
  export -f create_progress_bar
  export -f create_metric_bar
  export -f print_header
  export -f print_separator
  export -f show_spinner
  export -f colorize_metric
  export -f confirm_prompt
  export -f print_table
fi
