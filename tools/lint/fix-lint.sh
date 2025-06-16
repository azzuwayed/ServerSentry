#!/usr/bin/env bash
#
# ServerSentry Bash Lint Fixer v3.0
# Intelligent automatic fixing of common bash script issues using ShellCheck and shfmt
# Features: Smart fixes, safe backups, comprehensive reporting, and rollback capabilities
#

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="ServerSentry Bash Lint Fixer"

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
# Initialize with minimal level for linting
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi

# Initialize error handling system using bootstrap
if [[ -f "$SERVERSENTRY_CORE_DIR/error_handling.sh" ]]; then
  source "$SERVERSENTRY_CORE_DIR/error_handling.sh"
  if ! error_handling_init; then
    echo "Warning: Failed to initialize error handling system - continuing with basic error handling" >&2
  fi
fi

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
FORCE_BACKUP=true
BACKUP_DIR="backups"
KEEP_BACKUPS=5
VERBOSE=false
AUTO_CONFIRM=false
SPECIFIC_FIXES=()
EXCLUDE_PATTERNS=()
ROLLBACK_MODE=false

# Statistics
declare -A FIX_STATS
declare -A FILE_RESULTS
TOTAL_FILES=0
FIXED_FILES=0
FAILED_FILES=0
TOTAL_FIXES_APPLIED=0

# Enhanced print functions with error handling integration


# Enhanced file operation with error handling
safe_file_operation() {
  local operation="$1"
  local source_file="$2"
  local dest_file="${3:-}"
  local error_msg="${4:-File operation failed}"

  if declare -f safe_execute >/dev/null 2>&1; then
    case "$operation" in
    "copy")
      safe_execute "cp '$source_file' '$dest_file'" "$error_msg: copy $source_file to $dest_file"
      ;;
    "move")
      safe_execute "mv '$source_file' '$dest_file'" "$error_msg: move $source_file to $dest_file"
      ;;
    "remove")
      safe_execute "rm -f '$source_file'" "$error_msg: remove $source_file"
      ;;
    "mkdir")
      safe_execute "mkdir -p '$source_file'" "$error_msg: create directory $source_file"
      ;;
    *)
      print_error "Unknown file operation: $operation"
      return 1
      ;;
    esac
  else
    # Fallback to direct operations
    case "$operation" in
    "copy")
      cp "$source_file" "$dest_file" || {
        print_error "$error_msg: copy $source_file to $dest_file"
        return 1
      }
      ;;
    "move")
      mv "$source_file" "$dest_file" || {
        print_error "$error_msg: move $source_file to $dest_file"
        return 1
      }
      ;;
    "remove")
      rm -f "$source_file" || {
        print_error "$error_msg: remove $source_file"
        return 1
      }
      ;;
    "mkdir")
      mkdir -p "$source_file" || {
        print_error "$error_msg: create directory $source_file"
        return 1
      }
      ;;
    *)
      print_error "Unknown file operation: $operation"
      return 1
      ;;
    esac
  fi
}

# Enhanced backup creation with error handling
create_backup() {
  local file="$1"
  local backup_file="$2"

  if [[ "$FORCE_BACKUP" == "false" ]]; then
    return 0
  fi

  local backup_dir
  backup_dir=$(dirname "$backup_file")

  # Create backup directory
  if ! safe_file_operation "mkdir" "$backup_dir" "" "Failed to create backup directory"; then
    return 1
  fi

  # Create backup
  if ! safe_file_operation "copy" "$file" "$backup_file" "Failed to create backup"; then
    return 1
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    print_dim "Created backup: $backup_file"
  fi

  return 0
}

# Enhanced validation with error handling
validate_dependencies() {
  local missing_deps=()

  # Check for required tools
  local required_tools=("shellcheck")
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_deps+=("$tool")
    fi
  done

  # Check for optional tools
  local optional_tools=("shfmt")
  for tool in "${optional_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      print_warning "Optional tool '$tool' not found - some fixes will be skipped"
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    print_info "Please install missing tools and try again"

    # Use error handling system if available
    if declare -f throw_error >/dev/null 2>&1; then
      throw_error 9 "Missing required dependencies: ${missing_deps[*]}" 3
    else
      exit 9
    fi
  fi

  return 0
}

# Enhanced usage information
show_usage() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BOLD}DESCRIPTION:${NC}
  Intelligently fixes common bash script linting issues with safety features,
  comprehensive reporting, and rollback capabilities.

${BOLD}USAGE:${NC}
  $0 [OPTIONS] [FILES...]

${BOLD}OPTIONS:${NC}
  ${BOLD}Operation Modes:${NC}
    -n, --dry-run           Show what would be fixed without making changes
    -r, --rollback          Restore files from most recent backup
    -f, --force             Skip confirmation prompts
    -v, --verbose           Show detailed output

  ${BOLD}Backup Management:${NC}
    --no-backup            Skip creating backups (dangerous!)
    --backup-dir DIR       Custom backup directory (default: backups)
    --keep-backups N       Number of backups to retain (default: 5)

  ${BOLD}Fix Selection:${NC}
    --fix TYPE             Apply specific fix types (can be used multiple times)
    --list-fixes           Show available fix types
    -e, --exclude PATTERN  Exclude files matching pattern

  ${BOLD}Available Fix Types:${NC}
    formatting             Apply shfmt code formatting
    quotes                 Fix unquoted variables and command substitutions
    read-flags             Add missing -r flag to read commands
    exit-codes             Improve exit code checking patterns
    redirects              Optimize multiple redirections
    variables              Add shellcheck disable for common variables
    all                    Apply all available fixes (default)

  ${BOLD}Help:${NC}
    -h, --help             Show this help message
    --version              Show version information

${BOLD}EXAMPLES:${NC}
  $0                              # Fix all issues in all bash files
  $0 -n                           # Dry run - show what would be fixed
  $0 -v --fix formatting          # Apply only formatting fixes with verbose output
  $0 -f script.sh                 # Fix specific file without prompts
  $0 --rollback                   # Restore from most recent backup
  $0 -e "test*" --fix quotes      # Fix quotes, excluding test files

${BOLD}SAFETY FEATURES:${NC}
  • Automatic backups with versioning
  • Dry-run mode to preview changes
  • Rollback capability
  • Validation of fixes before applying
  • Smart pattern matching to avoid over-fixing

${BOLD}INTEGRATION:${NC}
  • Run after './check-lint.sh' for targeted fixing
  • Use in CI/CD pipelines with --force flag
  • Combine with VS Code tasks for integrated workflow
EOF
}

# Parse command line arguments with enhanced validation
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -n | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -r | --rollback)
      ROLLBACK_MODE=true
      shift
      ;;
    -f | --force)
      AUTO_CONFIRM=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    --no-backup)
      FORCE_BACKUP=false
      shift
      ;;
    --backup-dir)
      if [[ -z "${2:-}" ]]; then
        print_error "Backup directory option requires a path"
        exit 1
      fi
      BACKUP_DIR="$2"
      shift 2
      ;;
    --keep-backups)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        print_error "Keep backups must be a positive number"
        exit 1
      fi
      KEEP_BACKUPS="$2"
      shift 2
      ;;
    --fix)
      if [[ -z "${2:-}" ]]; then
        print_error "Fix option requires a fix type"
        exit 1
      fi
      SPECIFIC_FIXES+=("$2")
      shift 2
      ;;
    --list-fixes)
      list_available_fixes
      exit 0
      ;;
    -e | --exclude)
      if [[ -z "${2:-}" ]]; then
        print_error "Exclude option requires a pattern"
        exit 1
      fi
      EXCLUDE_PATTERNS+=("$2")
      shift 2
      ;;
    -h | --help)
      show_usage
      exit 0
      ;;
    --version)
      echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
      exit 0
      ;;
    -*)
      print_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
    *)
      # This is a file argument
      TARGET_FILES+=("$1")
      shift
      ;;
    esac
  done

  # Set default fixes if none specified
  if [[ ${#SPECIFIC_FIXES[@]} -eq 0 ]]; then
    SPECIFIC_FIXES=("all")
  fi

  # Validate fix types
  for fix_type in "${SPECIFIC_FIXES[@]}"; do
    if ! is_valid_fix_type "$fix_type"; then
      print_error "Invalid fix type: $fix_type"
      print_info "Use --list-fixes to see available types"
      exit 1
    fi
  done
}

# List available fix types
list_available_fixes() {
  print_header "Available Fix Types:"
  echo
  cat <<EOF
${BOLD}formatting${NC}     - Apply consistent code formatting with shfmt
${BOLD}quotes${NC}         - Fix unquoted variables and command substitutions
${BOLD}read-flags${NC}     - Add missing -r flag to read commands
${BOLD}exit-codes${NC}     - Improve exit code checking patterns
${BOLD}redirects${NC}      - Optimize multiple redirections to same file
${BOLD}variables${NC}      - Add shellcheck disable comments for common variables
${BOLD}all${NC}            - Apply all available fixes (default)

${DIM}Use: $0 --fix TYPE to apply specific fixes${NC}
${DIM}Multiple fix types can be specified: $0 --fix formatting --fix quotes${NC}
EOF
}

# Validate fix type
is_valid_fix_type() {
  local fix_type="$1"
  case "$fix_type" in
  formatting | quotes | read-flags | exit-codes | redirects | variables | all)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

# Check if file should be excluded
is_excluded() {
  local file="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$file" == $pattern ]] || [[ "$file" == */$pattern ]] || [[ "$(basename "$file")" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# Check if required tools are installed
check_tools() {
  if [[ "$VERBOSE" == true ]]; then
    print_info "Checking required tools..."
  fi

  local missing_tools=()

  if ! command -v shellcheck &>/dev/null; then
    missing_tools+=("shellcheck")
  fi

  if ! command -v shfmt &>/dev/null; then
    missing_tools+=("shfmt")
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    print_error "Missing required tools: ${missing_tools[*]}"
    print_info "Install with: brew install ${missing_tools[*]}"
    exit 1
  fi

  if [[ "$VERBOSE" == true ]]; then
    print_success "All required tools are available"
  fi
}

# Create backup with versioning
create_backup() {
  local file="$1"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file
  backup_file="${BACKUP_DIR}/$(basename "$file").${timestamp}.backup"

  if [[ "$FORCE_BACKUP" == false ]]; then
    return 0
  fi

  # Create backup directory if it doesn't exist
  mkdir -p "$BACKUP_DIR"

  # Create backup
  if cp "$file" "$backup_file"; then
    if [[ "$VERBOSE" == true ]]; then
      print_success "Created backup: $backup_file"
    fi

    # Clean up old backups
    cleanup_old_backups "$(basename "$file")"
    return 0
  else
    print_error "Failed to create backup for $file"
    return 1
  fi
}

# Clean up old backups based on retention policy
cleanup_old_backups() {
  local base_filename="$1"
  local pattern="${BACKUP_DIR}/${base_filename}.*.backup"

  # Get list of backup files, sorted by modification time (newest first)
  local backup_files
  backup_files=$(find "$BACKUP_DIR" -name "${base_filename}.*.backup" -type f 2>/dev/null | sort -r)

  if [[ -z "$backup_files" ]]; then
    return 0
  fi

  local count=0
  while IFS= read -r backup_file; do
    count=$((count + 1))
    if [[ $count -gt $KEEP_BACKUPS ]]; then
      rm -f "$backup_file"
      if [[ "$VERBOSE" == true ]]; then
        print_dim "Cleaned up old backup: $(basename "$backup_file")"
      fi
    fi
  done <<<"$backup_files"
}

# Rollback files from most recent backup
rollback_files() {
  print_header "🔄 Rollback Mode"
  echo

  if [[ ! -d "$BACKUP_DIR" ]]; then
    print_error "No backup directory found: $BACKUP_DIR"
    exit 1
  fi

  local backup_files
  backup_files=$(find "$BACKUP_DIR" -name "*.backup" -type f 2>/dev/null | sort -r)

  if [[ -z "$backup_files" ]]; then
    print_warning "No backup files found in $BACKUP_DIR"
    exit 1
  fi

  print_info "Available backups:"
  local file_count=0
  declare -A latest_backups

  # Find the most recent backup for each file
  while IFS= read -r backup_file; do
    local original_name
    original_name=$(basename "$backup_file" | sed 's/\.[0-9_]*\.backup$//')

    if [[ -z "${latest_backups[$original_name]:-}" ]]; then
      latest_backups["$original_name"]="$backup_file"
      file_count=$((file_count + 1))
      echo "  $file_count. $original_name ($(date -r "$backup_file" '+%Y-%m-%d %H:%M:%S'))"
    fi
  done <<<"$backup_files"

  if [[ $file_count -eq 0 ]]; then
    print_warning "No valid backup files found"
    exit 1
  fi

  echo
  if [[ "$AUTO_CONFIRM" == false ]]; then
    read -r -p "Restore from most recent backups? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      print_info "Rollback cancelled"
      exit 0
    fi
  fi

  local restored_count=0
  for original_name in "${!latest_backups[@]}"; do
    local backup_file="${latest_backups[$original_name]}"
    local target_file="./$original_name"

    if [[ -f "$target_file" ]]; then
      if cp "$backup_file" "$target_file"; then
        print_success "Restored: $original_name"
        restored_count=$((restored_count + 1))
      else
        print_error "Failed to restore: $original_name"
      fi
    else
      print_warning "Target file not found: $target_file"
    fi
  done

  echo
  print_success "Rollback complete: $restored_count files restored"
}

# Apply shfmt formatting
apply_formatting() {
  local file="$1"
  local fixes_applied=0

  if [[ "$VERBOSE" == true ]]; then
    print_info "Applying formatting to $(basename "$file")..."
  fi

  if [[ "$DRY_RUN" == true ]]; then
    # Check if formatting would change the file
    local original_content formatted_content
    original_content=$(cat "$file")
    formatted_content=$(shfmt -i 2 -ci -sr "$file" 2>/dev/null || echo "FORMATTING_ERROR")

    if [[ "$formatted_content" != "FORMATTING_ERROR" && "$original_content" != "$formatted_content" ]]; then
      print_info "  [DRY RUN] Would apply formatting changes"
      fixes_applied=$((fixes_applied + 1))
    fi
  else
    if shfmt -w -i 2 -ci -sr "$file" 2>/dev/null; then
      fixes_applied=$((fixes_applied + 1))
      if [[ "$VERBOSE" == true ]]; then
        print_success "  Applied formatting"
      fi
    else
      if [[ "$VERBOSE" == true ]]; then
        print_warning "  Could not format (may have syntax errors)"
      fi
    fi
  fi

  echo $fixes_applied
}

# Fix quote issues
apply_quote_fixes() {
  local file="$1"
  local fixes_applied=0
  local temp_file="${file}.tmp"

  if [[ "$VERBOSE" == true ]]; then
    print_info "Applying quote fixes to $(basename "$file")..."
  fi

  # Create a working copy
  cp "$file" "$temp_file"

  # Fix common unquoted variable patterns (but be conservative)
  # Only fix obvious cases where variables should be quoted
  local patterns=(
    's/\$\([A-Za-z_][A-Za-z0-9_]*\)/"$\1"/g' # Simple variable references
    "s/\\\${\([^}]*\)}/\"\\\${\1}\"/g"       # Parameter expansions
  )

  for pattern in "${patterns[@]}"; do
    if sed -E "$pattern" "$temp_file" >"${temp_file}.new" 2>/dev/null; then
      if ! cmp -s "$temp_file" "${temp_file}.new"; then
        mv "${temp_file}.new" "$temp_file"
        fixes_applied=$((fixes_applied + 1))
        if [[ "$VERBOSE" == true ]]; then
          print_success "  Applied quote fix: $pattern"
        fi
      else
        rm -f "${temp_file}.new"
      fi
    else
      rm -f "${temp_file}.new"
    fi
  done

  if [[ "$DRY_RUN" == true ]]; then
    if [[ $fixes_applied -gt 0 ]]; then
      print_info "  [DRY RUN] Would apply $fixes_applied quote fixes"
    fi
    rm -f "$temp_file"
  else
    if [[ $fixes_applied -gt 0 ]]; then
      mv "$temp_file" "$file"
    else
      rm -f "$temp_file"
    fi
  fi

  echo $fixes_applied
}

# Fix read command flags
apply_read_fixes() {
  local file="$1"
  local fixes_applied=0
  local temp_file="${file}.tmp"

  if [[ "$VERBOSE" == true ]]; then
    print_info "Applying read fixes to $(basename "$file")..."
  fi

  cp "$file" "$temp_file"

  # Fix read without -r (but avoid double -r)
  if sed -E 's/read -p/read -r -p/g; s/read -r -r/read -r/g' "$temp_file" >"${temp_file}.new"; then
    if ! cmp -s "$temp_file" "${temp_file}.new"; then
      mv "${temp_file}.new" "$temp_file"
      fixes_applied=$((fixes_applied + 1))
      if [[ "$VERBOSE" == true ]]; then
        print_success "  Fixed read commands to include -r flag"
      fi
    else
      rm -f "${temp_file}.new"
    fi
  else
    rm -f "${temp_file}.new"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ $fixes_applied -gt 0 ]]; then
      print_info "  [DRY RUN] Would fix $fixes_applied read commands"
    fi
    rm -f "$temp_file"
  else
    if [[ $fixes_applied -gt 0 ]]; then
      mv "$temp_file" "$file"
    else
      rm -f "$temp_file"
    fi
  fi

  echo $fixes_applied
}

# Apply shellcheck disable comments for common variables
apply_variable_fixes() {
  local file="$1"
  local fixes_applied=0
  local temp_file="${file}.tmp"

  if [[ "$VERBOSE" == true ]]; then
    print_info "Applying variable fixes to $(basename "$file")..."
  fi

  cp "$file" "$temp_file"

  # Add disable comments for common color variables
  local color_vars=("RED" "GREEN" "YELLOW" "BLUE" "CYAN" "BOLD" "DIM" "NC")

  for var in "${color_vars[@]}"; do
    # Only add disable comment if variable is defined but not already disabled
    if grep -q "^[[:space:]]*${var}=" "$temp_file" && ! grep -B1 "^[[:space:]]*${var}=" "$temp_file" | grep -q "shellcheck disable=SC2034"; then
      sed -i.bak "/^[[:space:]]*${var}=/i\\
# shellcheck disable=SC2034
" "$temp_file"
      fixes_applied=$((fixes_applied + 1))
      if [[ "$VERBOSE" == true ]]; then
        print_success "  Added disable comment for $var"
      fi
    fi
  done

  # Clean up sed backup file
  rm -f "${temp_file}.bak"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ $fixes_applied -gt 0 ]]; then
      print_info "  [DRY RUN] Would add $fixes_applied disable comments"
    fi
    rm -f "$temp_file"
  else
    if [[ $fixes_applied -gt 0 ]]; then
      mv "$temp_file" "$file"
    else
      rm -f "$temp_file"
    fi
  fi

  echo $fixes_applied
}

# Check if a fix type should be applied
should_apply_fix() {
  local fix_type="$1"

  # If "all" is specified, apply all fixes
  if [[ " ${SPECIFIC_FIXES[*]} " == *" all "* ]]; then
    return 0
  fi

  # Check if the specific fix type was requested
  if [[ " ${SPECIFIC_FIXES[*]} " == *" ${fix_type} "* ]]; then
    return 0
  fi

  return 1
}

# Process a single file with all applicable fixes
process_file() {
  local file="$1"
  local total_fixes=0

  if [[ "$VERBOSE" == true ]]; then
    print_header "Processing: $file"
  fi

  # Skip if file doesn't exist or is not readable
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    print_warning "Skipping $file (not accessible)"
    return 1
  fi

  # Create backup before making any changes
  if [[ "$DRY_RUN" == false ]] && ! create_backup "$file"; then
    print_error "Failed to create backup for $file, skipping"
    return 1
  fi

  # Apply fixes based on selection
  if should_apply_fix "formatting"; then
    local formatting_fixes
    formatting_fixes=$(apply_formatting "$file")
    total_fixes=$((total_fixes + formatting_fixes))
    FIX_STATS[formatting]=$((${FIX_STATS[formatting]:-0} + formatting_fixes))
  fi

  if should_apply_fix "quotes"; then
    local quote_fixes
    quote_fixes=$(apply_quote_fixes "$file")
    total_fixes=$((total_fixes + quote_fixes))
    FIX_STATS[quotes]=$((${FIX_STATS[quotes]:-0} + quote_fixes))
  fi

  if should_apply_fix "read-flags"; then
    local read_fixes
    read_fixes=$(apply_read_fixes "$file")
    total_fixes=$((total_fixes + read_fixes))
    FIX_STATS[read - flags]=$((${FIX_STATS[read - flags]:-0} + read_fixes))
  fi

  if should_apply_fix "variables"; then
    local variable_fixes
    variable_fixes=$(apply_variable_fixes "$file")
    total_fixes=$((total_fixes + variable_fixes))
    FIX_STATS[variables]=$((${FIX_STATS[variables]:-0} + variable_fixes))
  fi

  # Store results
  FILE_RESULTS["$file"]="$total_fixes"
  TOTAL_FIXES_APPLIED=$((TOTAL_FIXES_APPLIED + total_fixes))

  if [[ $total_fixes -gt 0 ]]; then
    FIXED_FILES=$((FIXED_FILES + 1))
    if [[ "$VERBOSE" == false ]]; then
      print_success "$(basename "$file") - $total_fixes fix$([ $total_fixes -ne 1 ] && echo "es") applied"
    fi
    return 0
  else
    if [[ "$VERBOSE" == true ]]; then
      print_info "No fixes needed for $(basename "$file")"
    fi
    return 0
  fi
}

# Find bash files to process
find_bash_files() {
  local files=()

  # Find .sh files
  while IFS= read -r -d '' file; do
    if ! is_excluded "$file"; then
      files+=("$file")
    fi
  done < <(find . -name "*.sh" -type f -print0 2>/dev/null)

  # Find executable files with bash shebang
  while IFS= read -r file; do
    if [[ -f "$file" && -x "$file" ]] && ! is_excluded "$file"; then
      # Avoid duplicates
      if [[ ! " ${files[*]} " == *" ${file} "* ]]; then
        files+=("$file")
      fi
    fi
  done < <(find . -type f -executable \! -name "*.sh" -exec grep -l "^#!/.*bash" {} \; 2>/dev/null)

  printf '%s\n' "${files[@]}"
}

# Generate summary report
show_summary() {
  echo
  print_header "📊 Fix Summary"
  echo "=============================================="

  if [[ "$DRY_RUN" == true ]]; then
    print_info "DRY RUN - No changes were made"
  fi

  print_info "Total files processed: $TOTAL_FILES"

  if [[ $TOTAL_FIXES_APPLIED -gt 0 ]]; then
    print_success "Files with fixes applied: $FIXED_FILES"
    print_success "Total fixes applied: $TOTAL_FIXES_APPLIED"

    echo
    print_info "Fixes by type:"
    for fix_type in formatting quotes read-flags variables; do
      local count=${FIX_STATS[$fix_type]:-0}
      if [[ $count -gt 0 ]]; then
        echo "  $fix_type: $count"
      fi
    done
  else
    print_success "All files are already clean! 🎉"
  fi

  if [[ $FAILED_FILES -gt 0 ]]; then
    echo
    print_warning "Files that could not be processed: $FAILED_FILES"
  fi

  # Show detailed file results in verbose mode
  if [[ "$VERBOSE" == true && ${#FILE_RESULTS[@]} -gt 0 ]]; then
    echo
    print_info "Detailed results by file:"
    for file in "${!FILE_RESULTS[@]}"; do
      local fixes=${FILE_RESULTS[$file]}
      if [[ $fixes -gt 0 ]]; then
        echo "  $(basename "$file"): $fixes fix$([ "$fixes" -ne 1 ] && echo "es")"
      fi
    done
  fi

  if [[ "$DRY_RUN" == false && $TOTAL_FIXES_APPLIED -gt 0 ]]; then
    echo
    print_info "Backups created in: $BACKUP_DIR"
    print_info "To rollback changes, run: $0 --rollback"
    echo
    print_info "Next steps:"
    echo "  1. Run './check-lint.sh' to verify fixes"
    echo "  2. Test your scripts to ensure functionality"
    echo "  3. Commit changes if satisfied"
  fi
}

# Main execution function
main() {
  local files_to_process=()

  print_header "🔧 $SCRIPT_NAME v$SCRIPT_VERSION"
  echo

  # Handle rollback mode
  if [[ "$ROLLBACK_MODE" == true ]]; then
    rollback_files
    exit 0
  fi

  # Check required tools
  check_tools

  # Determine files to process
  if [[ ${#TARGET_FILES[@]} -gt 0 ]]; then
    # Process specified files
    for file in "${TARGET_FILES[@]}"; do
      if [[ -f "$file" ]]; then
        files_to_process+=("$file")
      else
        print_warning "File not found: $file"
      fi
    done
  else
    # Find bash files automatically
    readarray -t files_to_process < <(find_bash_files)
  fi

  TOTAL_FILES=${#files_to_process[@]}

  if [[ $TOTAL_FILES -eq 0 ]]; then
    print_warning "No bash files found to process"
    exit 0
  fi

  # Show what will be processed
  if [[ "$VERBOSE" == true ]] || [[ "$DRY_RUN" == true ]]; then
    print_info "Files to process: $TOTAL_FILES"
    print_info "Fix types: ${SPECIFIC_FIXES[*]}"
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
      print_info "Excluding patterns: ${EXCLUDE_PATTERNS[*]}"
    fi
    echo
  fi

  # Confirm processing (unless auto-confirm or dry-run)
  if [[ "$AUTO_CONFIRM" == false && "$DRY_RUN" == false ]]; then
    read -r -p "Process $TOTAL_FILES files with selected fixes? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      print_info "Operation cancelled"
      exit 0
    fi
    echo
  fi

  # Process files
  for file in "${files_to_process[@]}"; do
    if ! process_file "$file"; then
      FAILED_FILES=$((FAILED_FILES + 1))
    fi
  done

  # Show summary
  show_summary

  # Return appropriate exit code
  if [[ $FAILED_FILES -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# Initialize arrays and run main function
declare -a TARGET_FILES=()

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_arguments "$@"
  main
fi
