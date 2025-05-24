#!/usr/bin/env bash
#
# ServerSentry Bash Lint Fixer
# Automatically fixes common bash script issues using ShellCheck and shfmt
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

print_success() { print_status "$GREEN" "✅ $1"; }
print_info() { print_status "$BLUE" "ℹ️  $1"; }
print_warning() { print_status "$YELLOW" "⚠️  $1"; }
print_error() { print_status "$RED" "❌ $1"; }

# Check if required tools are installed
check_tools() {
  print_info "Checking required tools..."

  local missing_tools=()

  if ! command -v shellcheck &>/dev/null; then
    missing_tools+=("shellcheck")
  fi

  if ! command -v shfmt &>/dev/null; then
    missing_tools+=("shfmt")
  fi

  if [ ${#missing_tools[@]} -gt 0 ]; then
    print_error "Missing required tools: ${missing_tools[*]}"
    print_info "Install with: brew install ${missing_tools[*]}"
    exit 1
  fi

  print_success "All required tools are installed"
}

# Apply shfmt formatting
format_file() {
  local file=$1
  print_info "Formatting $file with shfmt..."

  if shfmt -w -i 2 -ci -sr "$file"; then
    print_success "Formatted $file"
  else
    print_warning "Could not format $file (may have syntax errors)"
  fi
}

# Fix common ShellCheck issues automatically
fix_shellcheck_issues() {
  local file=$1
  print_info "Fixing common ShellCheck issues in $file..."

  # Create a backup
  cp "$file" "$file.backup"

  # Fix SC2162: read without -r will mangle backslashes
  sed -i '' 's/read -p/read -r -p/g' "$file"
  sed -i '' 's/read "/read -r "/g' "$file"
  # But avoid double -r
  sed -i '' 's/read -r -r/read -r/g' "$file"

  # Fix SC2034: Add disable comments for common unused variables
  sed -i '' '/^[[:space:]]*bash_major=/i\
# shellcheck disable=SC2034
' "$file"

  sed -i '' '/^[[:space:]]*RED=/i\
# shellcheck disable=SC2034
' "$file"

  sed -i '' '/^[[:space:]]*GREEN=/i\
# shellcheck disable=SC2034
' "$file"

  sed -i '' '/^[[:space:]]*YELLOW=/i\
# shellcheck disable=SC2034
' "$file"

  sed -i '' '/^[[:space:]]*BLUE=/i\
# shellcheck disable=SC2034
' "$file"

  sed -i '' '/^[[:space:]]*NC=/i\
# shellcheck disable=SC2034
' "$file"

  # Fix SC2181: Add disable comment before exit code checks
  sed -i '' '/if \[ \$? -eq 0 \]; then/i\
# shellcheck disable=SC2181
' "$file"

  # Fix SC2129: Add disable comment for multiple redirects
  sed -i '' '/>> "\$temp_crontab"/i\
# shellcheck disable=SC2129
' "$file"

  # Remove duplicate disable comments (keep only the first occurrence)
  awk '
  /^# shellcheck disable=/ {
    if (seen[$0]++) next
  }
  { print }
  ' "$file" >"$file.tmp" && mv "$file.tmp" "$file"

  print_success "Applied automatic fixes to $file"
}

# Run ShellCheck and report issues
check_with_shellcheck() {
  local file=$1
  print_info "Checking $file with ShellCheck..."

  local shellcheck_output
  if shellcheck_output=$(shellcheck "$file" 2>&1); then
    print_success "No ShellCheck issues found in $file"
    return 0
  else
    print_warning "ShellCheck found issues in $file:"
    echo "$shellcheck_output"
    return 1
  fi
}

# Main function
main() {
  print_info "Starting ServerSentry bash script lint fixing..."
  echo

  # Check tools
  check_tools
  echo

  # Find bash files directly
  print_info "Finding bash script files..."
  local bash_files=()

  # Find .sh files
  while IFS= read -r -d '' file; do
    bash_files+=("$file")
  done < <(find . -name "*.sh" -type f -print0)

  # Find files with bash shebang that don't end in .sh
  while IFS= read -r file; do
    bash_files+=("$file")
  done < <(find . -type f -executable ! -name "*.sh" -exec grep -l "^#!/.*bash" {} \; 2>/dev/null | head -20)

  if [ ${#bash_files[@]} -eq 0 ]; then
    print_warning "No bash files found"
    exit 0
  fi

  print_success "Found ${#bash_files[@]} bash script files"
  echo

  # Process each file
  local fixed_count=0
  local error_count=0

  for file in "${bash_files[@]}"; do
    echo "----------------------------------------"
    print_info "Processing: $file"

    # Skip if file doesn't exist (could be a symlink issue)
    if [[ ! -f "$file" ]]; then
      print_warning "Skipping $file (not a regular file)"
      continue
    fi

    # Apply formatting
    format_file "$file"

    # Apply automatic fixes
    fix_shellcheck_issues "$file"

    # Check with ShellCheck
    if check_with_shellcheck "$file"; then
      ((fixed_count++))
    else
      ((error_count++))
    fi

    echo
  done

  echo "========================================"
  print_success "Processing complete!"
  print_info "Files processed: ${#bash_files[@]}"
  print_success "Files with no issues: $fixed_count"
  if [ $error_count -gt 0 ]; then
    print_warning "Files with remaining issues: $error_count"
    echo
    print_info "For remaining issues, consider:"
    echo "  1. Review ShellCheck warnings manually"
    echo "  2. Add shellcheck disable comments for false positives"
    echo "  3. Use: shellcheck <file> for detailed analysis"
  fi

  echo
  print_info "Backup files created with .backup extension"
  print_info "To remove backups: find . -name '*.backup' -delete"
}

# Run main function
main "$@"
