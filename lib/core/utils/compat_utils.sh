#!/usr/bin/env bash
#
# ServerSentry v2 - Compatibility Utilities
#
# This file provides cross-platform compatibility functions for macOS and Linux

# Global variables for OS detection
COMPAT_OS=""
COMPAT_OS_VERSION=""
COMPAT_PACKAGE_MANAGER=""
COMPAT_BASH_PATH=""
COMPAT_BASH_VERSION=""

# Initialize compatibility layer
compat_init() {
  compat_detect_os
  compat_detect_bash
  compat_detect_package_manager
  return 0
}

# Detect operating system
compat_detect_os() {
  case "$(uname -s)" in
  Darwin*)
    COMPAT_OS="macos"
    COMPAT_OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    ;;
  Linux*)
    COMPAT_OS="linux"
    if [[ -f /etc/os-release ]]; then
      COMPAT_OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
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

# Detect bash version and path
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

# Detect package manager
compat_detect_package_manager() {
  case "$COMPAT_OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="brew"
    elif command -v port >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="macports"
    else
      COMPAT_PACKAGE_MANAGER="none"
    fi
    ;;
  linux)
    if command -v apt-get >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="dnf"
    elif command -v pacman >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="pacman"
    elif command -v zypper >/dev/null 2>&1; then
      COMPAT_PACKAGE_MANAGER="zypper"
    else
      COMPAT_PACKAGE_MANAGER="unknown"
    fi
    ;;
  *)
    COMPAT_PACKAGE_MANAGER="unknown"
    ;;
  esac
}

# Get OS information
compat_get_os() {
  echo "$COMPAT_OS"
}

compat_get_os_version() {
  echo "$COMPAT_OS_VERSION"
}

compat_get_package_manager() {
  echo "$COMPAT_PACKAGE_MANAGER"
}

compat_get_bash_path() {
  echo "$COMPAT_BASH_PATH"
}

compat_get_bash_version() {
  echo "$COMPAT_BASH_VERSION"
}

# Check if bash version is compatible (4.0+)
compat_bash_is_compatible() {
  local version="$COMPAT_BASH_VERSION"
  if [[ "$version" == "unknown" ]]; then
    return 1
  fi

  local major
  major=$(echo "$version" | cut -d. -f1)
  [[ "$major" -ge 4 ]]
}

# Check if bash supports associative arrays (4.0+)
compat_bash_supports_assoc_arrays() {
  compat_bash_is_compatible
}

# Cross-platform sed in-place editing
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

# Cross-platform date command
compat_date() {
  case "$COMPAT_OS" in
  macos)
    # macOS date has different syntax for some operations
    case "$1" in
    --iso-8601)
      date '+%Y-%m-%d'
      ;;
    --iso-8601=seconds)
      date '+%Y-%m-%dT%H:%M:%S%z'
      ;;
    *)
      date "$@"
      ;;
    esac
    ;;
  linux)
    date "$@"
    ;;
  *)
    date "$@"
    ;;
  esac
}

# Cross-platform stat command
compat_stat_size() {
  local file="$1"
  case "$COMPAT_OS" in
  macos)
    stat -f%z "$file" 2>/dev/null
    ;;
  linux)
    stat -c%s "$file" 2>/dev/null
    ;;
  *)
    # Fallback using ls
    ls -l "$file" 2>/dev/null | awk '{print $5}'
    ;;
  esac
}

compat_stat_mtime() {
  local file="$1"
  case "$COMPAT_OS" in
  macos)
    stat -f%m "$file" 2>/dev/null
    ;;
  linux)
    stat -c%Y "$file" 2>/dev/null
    ;;
  *)
    # This is harder to do portably, return empty
    echo ""
    ;;
  esac
}

# Cross-platform process listing
compat_ps_cpu() {
  case "$COMPAT_OS" in
  macos)
    ps -eo pid,pcpu,comm | tail -n +2
    ;;
  linux)
    ps -eo pid,pcpu,comm --no-headers
    ;;
  *)
    ps -eo pid,pcpu,comm 2>/dev/null | tail -n +2
    ;;
  esac
}

compat_ps_memory() {
  case "$COMPAT_OS" in
  macos)
    ps -eo pid,pmem,rss,comm | tail -n +2
    ;;
  linux)
    ps -eo pid,pmem,rss,comm --no-headers
    ;;
  *)
    ps -eo pid,pmem,rss,comm 2>/dev/null | tail -n +2
    ;;
  esac
}

# Cross-platform disk usage
compat_df() {
  case "$COMPAT_OS" in
  macos)
    df -H "$@"
    ;;
  linux)
    df -H "$@"
    ;;
  *)
    df "$@"
    ;;
  esac
}

# Cross-platform memory information
compat_get_memory_info() {
  case "$COMPAT_OS" in
  macos)
    # macOS uses vm_stat
    local page_size
    page_size=$(vm_stat | grep "page size" | awk '{print $8}' | tr -d '.')
    vm_stat | awk -v page_size="$page_size" '
        /Pages free/ { free = $3 * page_size / 1024 / 1024 }
        /Pages active/ { active = $3 * page_size / 1024 / 1024 }
        /Pages inactive/ { inactive = $3 * page_size / 1024 / 1024 }
        /Pages wired/ { wired = $4 * page_size / 1024 / 1024 }
        END { 
          total = free + active + inactive + wired
          used = active + inactive + wired
          printf "total:%.0f used:%.0f free:%.0f\n", total, used, free
        }'
    ;;
  linux)
    # Linux uses /proc/meminfo
    awk '/MemTotal:|MemAvailable:|MemFree:/ {
        if ($1 == "MemTotal:") total = $2
        if ($1 == "MemAvailable:") available = $2
        if ($1 == "MemFree:") free = $2
      } END {
        if (available) used = total - available
        else used = total - free
        printf "total:%.0f used:%.0f free:%.0f\n", total/1024, used/1024, (available ? available : free)/1024
      }' /proc/meminfo
    ;;
  *)
    echo "total:0 used:0 free:0"
    ;;
  esac
}

# Cross-platform CPU usage
compat_get_cpu_usage() {
  case "$COMPAT_OS" in
  macos)
    # Use iostat on macOS
    iostat -c 1 2 | tail -1 | awk '{print 100 - $6}'
    ;;
  linux)
    # Use /proc/stat on Linux
    grep 'cpu ' /proc/stat | awk '{
        idle = $5
        total = $2 + $3 + $4 + $5 + $6 + $7 + $8
        printf "%.1f\n", (total - idle) * 100 / total
      }'
    ;;
  *)
    echo "0.0"
    ;;
  esac
}

# Cross-platform load average
compat_get_load_average() {
  case "$COMPAT_OS" in
  macos | linux)
    uptime | awk -F'load averages?: ' '{print $2}' | awk '{print $1}'
    ;;
  *)
    echo "0.00"
    ;;
  esac
}

# Cross-platform hostname
compat_get_hostname() {
  case "$COMPAT_OS" in
  macos)
    hostname -f 2>/dev/null || hostname
    ;;
  linux)
    hostname -f 2>/dev/null || hostname
    ;;
  *)
    hostname
    ;;
  esac
}

# Get standard binary paths
compat_get_bin_paths() {
  case "$COMPAT_OS" in
  macos)
    echo "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
    ;;
  linux)
    echo "/usr/local/bin:/usr/bin:/bin"
    ;;
  *)
    echo "/usr/local/bin:/usr/bin:/bin"
    ;;
  esac
}

# Check if we're running as root
compat_is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# Get current user
compat_get_user() {
  id -un 2>/dev/null || whoami 2>/dev/null || echo "unknown"
}

# Cross-platform which command
compat_which() {
  local cmd="$1"
  command -v "$cmd" 2>/dev/null
}

# Check if command exists
compat_command_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# Create directory with proper permissions
compat_mkdir() {
  local dir="$1"
  local mode="${2:-755}"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    chmod "$mode" "$dir"
  fi
}

# Set file permissions properly
compat_chmod() {
  local mode="$1"
  local file="$2"

  if [[ -e "$file" ]]; then
    chmod "$mode" "$file"
  fi
}

# Get system uptime in seconds
compat_get_uptime() {
  case "$COMPAT_OS" in
  macos)
    # Use sysctl to get boot time and current time
    local boot_time current_time
    boot_time=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
    current_time=$(date +%s)
    if [[ -n "$boot_time" && -n "$current_time" ]]; then
      echo $((current_time - boot_time))
    else
      echo "0"
    fi
    ;;
  linux)
    awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "0"
    ;;
  *)
    echo "0"
    ;;
  esac
}

# Install package using system package manager
compat_install_package() {
  local package="$1"

  case "$COMPAT_PACKAGE_MANAGER" in
  brew)
    brew install "$package"
    ;;
  apt)
    apt-get update && apt-get install -y "$package"
    ;;
  yum)
    yum install -y "$package"
    ;;
  dnf)
    dnf install -y "$package"
    ;;
  pacman)
    pacman -S --noconfirm "$package"
    ;;
  zypper)
    zypper install -y "$package"
    ;;
  *)
    echo "Package manager not supported: $COMPAT_PACKAGE_MANAGER" >&2
    return 1
    ;;
  esac
}

# Check if package is installed
compat_package_installed() {
  local package="$1"

  case "$COMPAT_PACKAGE_MANAGER" in
  brew)
    brew list "$package" >/dev/null 2>&1
    ;;
  apt)
    dpkg -l "$package" >/dev/null 2>&1
    ;;
  yum | dnf)
    rpm -q "$package" >/dev/null 2>&1
    ;;
  pacman)
    pacman -Q "$package" >/dev/null 2>&1
    ;;
  zypper)
    zypper search -i "$package" | grep -q "$package"
    ;;
  *)
    # Fallback: check if command exists
    compat_command_exists "$package"
    ;;
  esac
}

# Print compatibility information
compat_info() {
  echo "Compatibility Information:"
  echo "  OS: $COMPAT_OS $COMPAT_OS_VERSION"
  echo "  Package Manager: $COMPAT_PACKAGE_MANAGER"
  echo "  Bash Path: $COMPAT_BASH_PATH"
  echo "  Bash Version: $COMPAT_BASH_VERSION"
  echo "  Bash Compatible: $(compat_bash_is_compatible && echo "yes" || echo "no")"
  echo "  Associative Arrays: $(compat_bash_supports_assoc_arrays && echo "yes" || echo "no")"
  echo "  User: $(compat_get_user)"
  echo "  Root: $(compat_is_root && echo "yes" || echo "no")"
  echo "  Hostname: $(compat_get_hostname)"
}

# Initialize on source
compat_init
