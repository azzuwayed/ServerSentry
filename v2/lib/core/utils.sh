#!/bin/bash
#
# ServerSentry v2 - Utilities
#
# This module provides common utility functions used throughout the application

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
  [ "$(id -u)" -eq 0 ]
}

# Get operating system type
get_os_type() {
  case "$(uname -s)" in
  Linux*) echo "linux" ;;
  Darwin*) echo "macos" ;;
  CYGWIN*) echo "windows" ;;
  MINGW*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

# Get OS distribution (for Linux)
get_linux_distro() {
  if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    echo "$ID"
  elif command_exists lsb_release; then
    # linuxbase.org
    lsb_release -si | tr '[:upper:]' '[:lower:]'
  elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]'
  elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    echo "debian"
  else
    # Fall back to uname
    uname -s
  fi
}

# Format bytes to human-readable string
format_bytes() {
  local bytes=$1
  local precision=${2:-2}

  # Ensure bc is available for floating point calculations
  if ! command_exists bc; then
    echo "${bytes}B"
    return
  fi

  # Use bc for comparisons to handle floating point values
  if [ $(echo "$bytes < 1024" | bc) -eq 1 ]; then
    echo "${bytes}B"
  elif [ $(echo "$bytes < 1048576" | bc) -eq 1 ]; then
    awk "BEGIN { printf \"%.${precision}f KB\", $bytes/1024 }"
  elif [ $(echo "$bytes < 1073741824" | bc) -eq 1 ]; then
    awk "BEGIN { printf \"%.${precision}f MB\", $bytes/1048576 }"
  else
    awk "BEGIN { printf \"%.${precision}f GB\", $bytes/1073741824 }"
  fi
}

# Convert to lowercase
to_lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert to uppercase
to_uppercase() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Trim whitespace
trim() {
  local var="$*"
  # remove leading whitespace
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace
  var="${var%"${var##*[![:space:]]}"}"
  echo -n "$var"
}

# Validate IP address
is_valid_ip() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a ip_array <<<"$ip"
    [[ ${ip_array[0]} -le 255 && ${ip_array[1]} -le 255 && ${ip_array[2]} -le 255 && ${ip_array[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

# Generate a random string
random_string() {
  local length=${1:-32}
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

# Check if a directory is writable
is_dir_writable() {
  local dir="$1"
  [ -d "$dir" ] && [ -w "$dir" ]
}

# Get timestamp
get_timestamp() {
  date +%s
}

# Get formatted date
get_formatted_date() {
  local format=${1:-"%Y-%m-%d %H:%M:%S"}
  date +"$format"
}

# Safe file write (write to temp file, then move)
safe_write() {
  local target_file="$1"
  local content="$2"

  local tmp_file="${target_file}.tmp"
  echo "$content" >"$tmp_file" || return 1
  mv "$tmp_file" "$target_file" || return 1

  return 0
}

# URL encode
url_encode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for ((pos = 0; pos < strlen; pos++)); do
    c=${string:$pos:1}
    case "$c" in
    [-_.~a-zA-Z0-9]) o="$c" ;;
    *) printf -v o '%%%02x' "'$c" ;;
    esac
    encoded+="$o"
  done

  echo "$encoded"
}

# JSON escape
json_escape() {
  local json="$1"
  echo "$json" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g'
}
