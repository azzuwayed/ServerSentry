#!/usr/bin/env bash
#
# Bootstrap Migration Script
#
# This script migrates all files from the dual bootstrap system to the single bootstrap system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
migrated_count=0
skipped_count=0
error_count=0

# Function to log messages
log() {
  local level="$1"
  local message="$2"

  case "$level" in
  "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
  "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
  "WARN") echo -e "${YELLOW}⚠️  $message${NC}" ;;
  "ERROR") echo -e "${RED}❌ $message${NC}" >&2 ;;
  esac
}

# Function to migrate a single file
migrate_file() {
  local file="$1"

  log "INFO" "Processing: $file"

  # Check if file contains the old bootstrap pattern
  if ! grep -q "lib/serversentry-bootstrap.sh" "$file" 2>/dev/null; then
    log "WARN" "  Skipping: No old bootstrap pattern found"
    ((skipped_count++))
    return 0
  fi

  # Create backup
  cp "$file" "${file}.backup"

  # Create temporary file for the new content
  local temp_file="${file}.tmp"

  # Process the file
  if sed -E '
    # Start of the bootstrap block - match the opening if statement
    /^[[:space:]]*# Load ServerSentry environment$/,/^[[:space:]]*if \[\[ -z "\$\{SERVERSENTRY_ENV_LOADED:-\}" \]\]; then$/ {
      # Keep the comment and if statement
      /^[[:space:]]*# Load ServerSentry environment$/p
      /^[[:space:]]*if \[\[ -z "\$\{SERVERSENTRY_ENV_LOADED:-\}" \]\]; then$/p
      # Skip everything else in this range
      d
    }

    # Match the complex bootstrap logic block and replace it
    /^[[:space:]]*# Find bootstrap helper$/,/^[[:space:]]*fi$/ {
      # Replace the entire block with new pattern
      /^[[:space:]]*# Find bootstrap helper$/ {
        i\
  # Set bootstrap control variables\
  export SERVERSENTRY_QUIET=true\
  export SERVERSENTRY_AUTO_INIT=false\
  export SERVERSENTRY_INIT_LEVEL=minimal\
  \
  # Find and source the main bootstrap file\
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\
  while [[ "$current_dir" != "/" ]]; do\
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then\
      source "$current_dir/serversentry-env.sh"\
      break\
    fi\
    current_dir="$(dirname "$current_dir")"\
  done\
  \
  # Verify bootstrap succeeded\
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then\
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2\
    exit 1\
  fi
        d
      }
      # Delete all other lines in this block
      d
    }

    # Print all other lines unchanged
    p
  ' "$file" >"$temp_file"; then

    # Replace original file with migrated version
    mv "$temp_file" "$file"
    log "SUCCESS" "  Migrated successfully"
    ((migrated_count++))

    # Remove backup if migration was successful
    rm -f "${file}.backup"

  else
    log "ERROR" "  Migration failed"
    ((error_count++))

    # Restore from backup
    mv "${file}.backup" "$file"
    rm -f "$temp_file"
  fi
}

# Main migration function
main() {
  log "INFO" "Starting bootstrap migration..."

  # Find all shell scripts that might need migration
  local files_to_check=(
    # Core modules
    lib/core/*.sh
    lib/core/*/*.sh

    # Plugins
    lib/plugins/*/*.sh
    lib/plugins/*/*/*.sh

    # UI components
    lib/ui/*/*.sh

    # Utilities
    lib/core/utils/*.sh

    # Tests
    tests/*.sh
    tests/*/*.sh
    tests/*/*/*.sh

    # Tools
    tools/*.sh
    tools/*/*.sh

    # Examples and docs
    docs/*/*.sh
    example-script.sh
  )

  # Process each file
  for pattern in "${files_to_check[@]}"; do
    # Use shell globbing with nullglob to handle non-matching patterns
    shopt -s nullglob
    for file in $pattern; do
      # Skip if not a regular file
      [[ -f "$file" ]] || continue

      # Skip if not readable
      [[ -r "$file" ]] || continue

      # Skip backup files
      [[ "$file" != *.backup ]] || continue

      # Migrate the file
      migrate_file "$file"
    done
    shopt -u nullglob
  done

  # Summary
  echo ""
  log "INFO" "Migration Summary:"
  log "SUCCESS" "  Files migrated: $migrated_count"
  log "WARN" "  Files skipped: $skipped_count"
  if [[ $error_count -gt 0 ]]; then
    log "ERROR" "  Files with errors: $error_count"
  fi

  if [[ $error_count -eq 0 ]]; then
    log "SUCCESS" "Bootstrap migration completed successfully!"
    return 0
  else
    log "ERROR" "Bootstrap migration completed with errors"
    return 1
  fi
}

# Run the migration
main "$@"
