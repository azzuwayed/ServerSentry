#!/usr/bin/env bash
#
# ServerSentry v2 - Compatibility Utilities
#
# Modern cross-platform compatibility functions for macOS and Linux

# Prevent multiple sourcing
if [[ "${COMPAT_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
COMPAT_UTILS_LOADED=true
export COMPAT_UTILS_LOADED

# Global variables for OS detection
COMPAT_OS=""
COMPAT_OS_VERSION=""
COMPAT_PACKAGE_MANAGER=""
COMPAT_BASH_PATH=""
COMPAT_BASH_VERSION=""

# === CORE COMPATIBILITY FUNCTIONS ===

# Function: compat_init
# Description: Initialize compatibility layer
# Returns:
#   0 - success
compat_init() {
  compat_detect_os
  compat_detect_bash
  compat_detect_package_manager
  return 0
}

# Function: compat_detect_os
# Description: Detect operating system and version
compat_detect_os() {
  case "$(uname -s)" in
  Darwin*)
    COMPAT_OS="macos"
    COMPAT_OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    ;;
  Linux*)
    COMPAT_OS="linux"
    if [[ -f /etc/os-release ]]; then
      COMPAT_OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2 2>/dev/null || echo "unknown")
    else
      COMPAT_OS_VERSION="unknown"
    fi
    ;;
  CYGWIN* | MINGW* | MSYS*)
    COMPAT_OS="windows"
    COMPAT_OS_VERSION="unknown"
    ;;
  *)
    COMPAT_OS="unknown"
    COMPAT_OS_VERSION="unknown"
    ;;
  esac
}

# Function: compat_detect_bash
# Description: Detect bash version and path
compat_detect_bash() {
  # Find the best available bash
  local bash_candidates=()

  # Add common bash locations based on OS
  case "$COMPAT_OS" in
  macos)
    bash_candidates=(
      "/usr/local/bin/bash"    # Homebrew
      "/opt/homebrew/bin/bash" # Apple Silicon Homebrew
      "/usr/bin/bash"          # System bash
      "/bin/bash"              # Fallback
    )
    ;;
  linux)
    bash_candidates=(
      "/usr/bin/bash"       # Standard location
      "/bin/bash"           # Alternative location
      "/usr/local/bin/bash" # Custom install
    )
    ;;
  *)
    bash_candidates=(
      "/usr/bin/bash"
      "/bin/bash"
      "/usr/local/bin/bash"
    )
    ;;
  esac

  # Also check what's in PATH
  if command -v bash >/dev/null 2>&1; then
    local path_bash
    path_bash=$(command -v bash)
    # Add to front of candidates if not already there
    if [[ ! " ${bash_candidates[*]} " =~ " ${path_bash} " ]]; then
      bash_candidates=("$path_bash" "${bash_candidates[@]}")
    fi
  fi

  # Find the first bash with version 4.0+
  for bash_path in "${bash_candidates[@]}"; do
    if [[ -x "$bash_path" ]]; then
      local version
      version=$("$bash_path" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
      if [[ -n "$version" ]]; then
        local major
        major=$(echo "$version" | cut -d. -f1)
        if [[ "$major" -ge 4 ]]; then
          COMPAT_BASH_PATH="$bash_path"
          COMPAT_BASH_VERSION="$version"
          return 0
        fi
      fi
    fi
  done

  # Fallback to system bash if no modern bash found
  COMPAT_BASH_PATH="/bin/bash"
  COMPAT_BASH_VERSION=$("$COMPAT_BASH_PATH" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
}

# Function: compat_detect_package_manager
# Description: Detect the system package manager
compat_detect_package_manager() {
  case "$COMPAT_OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="homebrew"
    elif command -v port >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="macports"
    else
      COMPAT_PACKAGE_MANAGER="none"
    fi
    ;;
  linux)
    if command -v apt-get >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="yum"
    elif command -v pacman >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="pacman"
    elif command -v zypper >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="zypper"
    elif command -v apk >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="apk"
    else
      COMPAT_PACKAGE_MANAGER="unknown"
    fi
    ;;
  *)
    COMPAT_PACKAGE_MANAGER="unknown"
    ;;
  esac
}

# === INFORMATION GETTERS ===

# Function: compat_get_os
# Description: Get detected OS
compat_get_os() {
  echo "$COMPAT_OS"
}

# Function: compat_get_os_version
# Description: Get detected OS version
compat_get_os_version() {
  echo "$COMPAT_OS_VERSION"
}

# Function: compat_get_package_manager
# Description: Get detected package manager
compat_get_package_manager() {
  echo "$COMPAT_PACKAGE_MANAGER"
}

# === CROSS-PLATFORM FILE OPERATIONS ===

# Function: compat_sed_inplace
# Description: Cross-platform sed in-place editing
# Parameters:
#   $1 - sed expression
#   $2 - file path
compat_sed_inplace() {
  local expression="$1"
  local file="$2"

  case "$COMPAT_OS" in
  macos)
    sed -i '' "$expression" "$file"
    ;;
  linux)
    sed -i "$expression" "$file"
    ;;
  *)
    # Fallback method that works everywhere
    local temp_file
    temp_file=$(mktemp)
    sed "$expression" "$file" >"$temp_file" && mv "$temp_file" "$file"
    ;;
  esac
}

# Function: compat_stat_size
# Description: Get file size across platforms
# Parameters:
#   $1 - file path
# Returns:
#   File size in bytes via stdout
compat_stat_size() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "0"
    return 1
  fi

  case "$COMPAT_OS" in
  macos)
    stat -f%z "$file" 2>/dev/null || echo "0"
    ;;
  linux)
    stat -c%s "$file" 2>/dev/null || echo "0"
    ;;
  *)
    ls -l "$file" 2>/dev/null | awk '{print $5}' || echo "0"
    ;;
  esac
}

# Function: compat_stat_mtime
# Description: Get file modification time across platforms
# Parameters:
#   $1 - file path
# Returns:
#   Modification time (Unix timestamp) via stdout
compat_stat_mtime() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "0"
    return 1
  fi

  case "$COMPAT_OS" in
  macos)
    stat -f%m "$file" 2>/dev/null || echo "0"
    ;;
  linux)
    stat -c%Y "$file" 2>/dev/null || echo "0"
    ;;
  *)
    echo "0"
    ;;
  esac
}

# Function: compat_date_iso
# Description: Get ISO 8601 date format across platforms
# Returns:
#   ISO 8601 formatted date via stdout
compat_date_iso() {
  case "$COMPAT_OS" in
  macos)
    date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date "+%Y-%m-%d %H:%M:%S"
    ;;
  linux)
    date --iso-8601=seconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z"
    ;;
  *)
    date "+%Y-%m-%d %H:%M:%S"
    ;;
  esac
}

# === CROSS-PLATFORM SYSTEM INFORMATION ===

# Function: compat_get_cpu_count
# Description: Get CPU core count across platforms
# Returns:
#   Number of CPU cores via stdout
compat_get_cpu_count() {
  case "$COMPAT_OS" in
  macos)
    sysctl -n hw.ncpu 2>/dev/null || echo "1"
    ;;
  linux)
    nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "1"
    ;;
  *)
    echo "1"
    ;;
  esac
}

# Function: compat_get_memory_total
# Description: Get total system memory across platforms
# Returns:
#   Total memory in bytes via stdout
compat_get_memory_total() {
  case "$COMPAT_OS" in
  macos)
    local mem_bytes
    mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    echo "${mem_bytes:-0}"
    ;;
  linux)
    if [[ -r /proc/meminfo ]]; then
      local mem_kb
      mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
      echo "$((mem_kb * 1024))"
    else
      echo "0"
    fi
    ;;
  *)
    echo "0"
    ;;
  esac
}

# Function: compat_get_load_average
# Description: Get system load average across platforms
# Returns:
#   Load average (1 minute) via stdout
compat_get_load_average() {
  case "$COMPAT_OS" in
  macos | linux)
    if command -v uptime >/dev/null 2>&1; then
      uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' '
    else
      echo "0.00"
    fi
    ;;
  *)
    echo "0.00"
    ;;
  esac
}

# === NETWORK UTILITIES ===

# Function: compat_get_interfaces
# Description: Get network interfaces across platforms
# Returns:
#   Network interface names via stdout (one per line)
compat_get_interfaces() {
  case "$COMPAT_OS" in
  macos)
    if command -v ifconfig >/dev/null 2>&1; then
      ifconfig -l 2>/dev/null | tr ' ' '\n' | grep -v '^$'
    fi
    ;;
  linux)
    if [[ -d /sys/class/net ]]; then
      ls /sys/class/net/ 2>/dev/null | grep -v '^lo$'
    elif command -v ip >/dev/null 2>&1; then
      ip link show 2>/dev/null | awk -F': ' '/^[0-9]+:/ {print $2}' | cut -d'@' -f1 | grep -v '^lo$'
    fi
    ;;
  esac
}

# === PROCESS UTILITIES ===

# Function: compat_get_process_list
# Description: Get process list across platforms
# Returns:
#   Process list via stdout
compat_get_process_list() {
  if command -v ps >/dev/null 2>&1; then
    case "$COMPAT_OS" in
    macos)
      ps -axo pid,ppid,comm,rss,%cpu
      ;;
    linux)
      ps -eo pid,ppid,comm,rss,pcpu
      ;;
    *)
      ps -ef
      ;;
    esac
  fi
}

# Function: compat_kill_process
# Description: Kill process across platforms
# Parameters:
#   $1 - process ID
#   $2 - signal (optional, defaults to TERM)
# Returns:
#   0 - success
#   1 - failure
compat_kill_process() {
  local pid="$1"
  local signal="${2:-TERM}"

  if command -v kill >/dev/null 2>&1; then
    kill -"$signal" "$pid" 2>/dev/null
  else
    return 1
  fi
}

# === PACKAGE MANAGEMENT ===

# Function: compat_install_package
# Description: Install package using detected package manager
# Parameters:
#   $1 - package name
# Returns:
#   0 - success
#   1 - failure
compat_install_package() {
  local package="$1"

  case "$COMPAT_PACKAGE_MANAGER" in
  homebrew)
    brew install "$package"
    ;;
  macports)
    port install "$package"
    ;;
  apt)
    apt-get update && apt-get install -y "$package"
    ;;
  dnf)
    dnf install -y "$package"
    ;;
  yum)
    yum install -y "$package"
    ;;
  pacman)
    pacman -S --noconfirm "$package"
    ;;
  zypper)
    zypper install -y "$package"
    ;;
  apk)
    apk add "$package"
    ;;
  *)
    log_error "Cannot install package: unsupported package manager" "compat_utils"
    return 1
    ;;
  esac
}

# Function: compat_package_installed
# Description: Check if package is installed
# Parameters:
#   $1 - package name
# Returns:
#   0 - package is installed
#   1 - package is not installed
compat_package_installed() {
  local package="$1"

  case "$COMPAT_PACKAGE_MANAGER" in
  homebrew)
    brew list "$package" >/dev/null 2>&1
    ;;
  macports)
    port installed "$package" >/dev/null 2>&1
    ;;
  apt)
    dpkg -l "$package" >/dev/null 2>&1
    ;;
  dnf | yum)
    rpm -q "$package" >/dev/null 2>&1
    ;;
  pacman)
    pacman -Q "$package" >/dev/null 2>&1
    ;;
  zypper)
    zypper search -i "$package" >/dev/null 2>&1
    ;;
  apk)
    apk info -e "$package" >/dev/null 2>&1
    ;;
  *)
    return 1
    ;;
  esac
}

# === INITIALIZATION AND EXPORTS ===

# Initialize compatibility layer on load
compat_init

# Export functions for cross-shell availability
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f compat_init
  export -f compat_detect_os
  export -f compat_detect_bash
  export -f compat_detect_package_manager
  export -f compat_get_os
  export -f compat_get_os_version
  export -f compat_get_package_manager
  export -f compat_sed_inplace
  export -f compat_stat_size
  export -f compat_stat_mtime
  export -f compat_date_iso
  export -f compat_get_cpu_count
  export -f compat_get_memory_total
  export -f compat_get_load_average
  export -f compat_get_interfaces
  export -f compat_get_process_list
  export -f compat_kill_process
  export -f compat_install_package
  export -f compat_package_installed
fi
