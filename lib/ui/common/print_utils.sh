#!/usr/bin/env bash
#
# ServerSentry UI Print Utilities
#
# Unified print utilities that provide consistent formatting
# and eliminate duplication across UI components.

# Prevent multiple sourcing
if [[ "${PRINT_UTILS_LOADED:-}" == "true" ]]; then
  return 0
fi
PRINT_UTILS_LOADED=true
export PRINT_UTILS_LOADED

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi

    # Load unified UI framework
    if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
      source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
    fi

    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

# Standard colors (only define if not already defined)
if [[ -z "${RED:-}" ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[1;33m'
  readonly BLUE='\033[0;34m'
  readonly PURPLE='\033[0;35m'
  readonly CYAN='\033[0;36m'
  readonly WHITE='\033[1;37m'
  readonly GRAY='\033[0;37m'
  readonly DIM='\033[2m'
  readonly BOLD='\033[1m'
  readonly NC='\033[0m' # No Color
fi

# Export color constants
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE GRAY DIM BOLD NC

# =============================================================================
# CORE PRINT FUNCTIONS
# =============================================================================

# Function: print_header
# Description: Print a formatted header
# Parameters:
#   $1 (string): header text
#   $2 (optional): width (default: 60)
print_header() {
  local text="$1"
  local width="${2:-60}"
  local padding=$(((width - ${#text}) / 2))

  echo ""
  echo -e "${BOLD}${BLUE}$(printf "%*s" "$width" | tr ' ' '=')${NC}"
  echo -e "${BOLD}${BLUE}$(printf "%*s" "$padding" "")${text}$(printf "%*s" "$padding" "")${NC}"
  echo -e "${BOLD}${BLUE}$(printf "%*s" "$width" | tr ' ' '=')${NC}"
  echo ""
}

# Function: print_success
# Description: Print a success message
# Parameters:
#   $1 (string): message text
print_success() {
  echo -e "${GREEN}✅ $*${NC}"
}

# Function: print_error
# Description: Print an error message
# Parameters:
#   $1 (string): message text
print_error() {
  echo -e "${RED}❌ $*${NC}" >&2
}

# Function: print_warning
# Description: Print a warning message
# Parameters:
#   $1 (string): message text
print_warning() {
  echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

# Function: print_info
# Description: Print an info message
# Parameters:
#   $1 (string): message text
print_info() {
  echo -e "${BLUE}ℹ️  $*${NC}"
}

# Function: print_separator
# Description: Print a separator line
# Parameters: None
print_separator() {
  echo -e "${DIM}$(printf "%*s" 60 | tr ' ' '-')${NC}"
}

# Function: print_dim
# Description: Print text in dim/gray color
# Parameters:
#   $1 (string): text to print
print_dim() {
  echo -e "${DIM}$*${NC}"
}

# Function: print_status
# Description: Print a status message
# Parameters:
#   $1 (string): status type (ok, warning, error, info)
#   $2 (string): message text
print_status() {
  local status="$1"
  local message="$2"

  case "$status" in
  "ok" | "success")
    echo -e "${GREEN}✅ $message${NC}"
    ;;
  "warning" | "warn")
    echo -e "${YELLOW}⚠️  $message${NC}"
    ;;
  "error" | "err")
    echo -e "${RED}❌ $message${NC}"
    ;;
  "info")
    echo -e "${BLUE}ℹ️  $message${NC}"
    ;;
  *)
    echo -e "${GRAY}• $message${NC}"
    ;;
  esac
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export all print utility functions (only if they exist)
if declare -f print_header >/dev/null 2>&1; then
  export -f print_header print_success print_error print_warning print_info
  export -f print_separator print_dim print_status
fi

# Export color constants (only if not already defined)
if [[ -z "${RED:-}" ]]; then
  export RED GREEN YELLOW BLUE PURPLE CYAN WHITE GRAY DIM BOLD NC
fi
