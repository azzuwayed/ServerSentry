#!/usr/bin/env bash
#
# ServerSentry ShellCheck Analyzer v2.0
# Enhanced bash script linting analysis with detailed reporting and options
#

set -euo pipefail

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="ServerSentry ShellCheck Analyzer"

# Colors and formatting
# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Configuration
SHOW_VERBOSE=false
SHOW_JSON=false
SHOW_SUMMARY_ONLY=false
SHOW_STATS=true
SHOW_PERFORMANCE=false
SEVERITY_FILTER=""
OUTPUT_FILE=""
EXCLUDE_PATTERNS=()
MAX_ISSUES_DISPLAY=50

# Statistics
START_TIME=""
END_TIME=""
FILE_ISSUE_COUNT=0

# Print functions
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${BOLD}${CYAN}$1${NC}"; }
print_dim() { echo -e "${DIM}$1${NC}"; }

# Usage information
show_usage() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BOLD}USAGE:${NC}
  $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
  -v, --verbose          Show detailed output for each file
  -j, --json             Output results in JSON format
  -s, --summary          Show summary only (no individual file details)
  -q, --quiet            Suppress statistics and performance info
  -p, --performance      Show performance metrics
  -f, --filter LEVEL     Filter by severity: error, warning, info, style
  -o, --output FILE      Write output to file
  -e, --exclude PATTERN  Exclude files matching pattern (can be used multiple times)
  -m, --max-issues N     Maximum issues to display per file (default: 50)
  -h, --help             Show this help message
  --version              Show version information

${BOLD}EXAMPLES:${NC}
  $0                           # Standard analysis
  $0 -v                        # Verbose output
  $0 -j -o results.json        # JSON output to file
  $0 -s -q                     # Summary only, quiet mode
  $0 -f error                  # Show only errors
  $0 -e "test*" -e "tmp*"      # Exclude test and tmp files

${BOLD}INTEGRATION:${NC}
  Run './fix-lint.sh' to automatically fix common issues
  Use with VS Code tasks for integrated development workflow
EOF
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -v | --verbose)
      SHOW_VERBOSE=true
      shift
      ;;
    -j | --json)
      SHOW_JSON=true
      shift
      ;;
    -s | --summary)
      SHOW_SUMMARY_ONLY=true
      shift
      ;;
    -q | --quiet)
      SHOW_STATS=false
      shift
      ;;
    -p | --performance)
      SHOW_PERFORMANCE=true
      shift
      ;;
    -f | --filter)
      SEVERITY_FILTER="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -e | --exclude)
      EXCLUDE_PATTERNS+=("$2")
      shift 2
      ;;
    -m | --max-issues)
      MAX_ISSUES_DISPLAY="$2"
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
    *)
      print_error "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
    esac
  done
}

# Check if pattern should be excluded
is_excluded() {
  local file="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# Filter issues by severity
filter_severity() {
  local output="$1"

  if [[ -z "$SEVERITY_FILTER" ]]; then
    echo "$output"
    return
  fi

  case "$SEVERITY_FILTER" in
  error)
    echo "$output" | grep "(error):" || true
    ;;
  warning)
    echo "$output" | grep "(warning):" || true
    ;;
  info)
    echo "$output" | grep "(info):" || true
    ;;
  style)
    echo "$output" | grep "(style):" || true
    ;;
  *)
    print_error "Invalid severity filter: $SEVERITY_FILTER"
    echo "$output"
    ;;
  esac
}

# Get file statistics
get_file_stats() {
  local file="$1"
  local size
  local lines

  if [[ -f "$file" ]]; then
    size=$(wc -c <"$file" 2>/dev/null || echo "0")
    lines=$(wc -l <"$file" 2>/dev/null || echo "0")
    echo "size:$size,lines:$lines"
  else
    echo "size:0,lines:0"
  fi
}

# Start performance timer
start_timer() {
  START_TIME=$(date +%s)
}

# End performance timer and return duration
end_timer() {
  END_TIME=$(date +%s)
  echo $((END_TIME - START_TIME))
}

# Format duration for display
format_duration() {
  local duration="$1"
  echo "${duration}s"
}

# Check individual file
check_file() {
  local file="$1"
  local file_stats
  local shellcheck_output
  local filtered_output
  local issue_count=0
  local file_duration=0

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    start_timer
  fi

  file_stats=$(get_file_stats "$file")

  # Run ShellCheck (handle errors gracefully)
  set +e # Temporarily disable exit on error
  shellcheck_output=$(shellcheck "$file" 2>&1)
  local shellcheck_exit=$?
  set -e # Re-enable exit on error

  if [[ $shellcheck_exit -eq 0 ]]; then
    # No issues found
    if [[ "$SHOW_VERBOSE" == true ]] || [[ "$SHOW_JSON" == false && "$SHOW_SUMMARY_ONLY" == false ]]; then
      if [[ "$SHOW_JSON" == false ]]; then
        print_success "$(basename "$file") - No issues found"
        if [[ "$SHOW_VERBOSE" == true ]]; then
          print_dim "  File: $file ($file_stats)"
        fi
      fi
    fi

    if [[ "$SHOW_PERFORMANCE" == true ]]; then
      file_duration=$(end_timer)
    fi

    # Return clean status
    FILE_ISSUE_COUNT=0
    return 0
  else
    # Issues found
    echo "DEBUG: About to filter severity" >&2
    filtered_output=$(filter_severity "$shellcheck_output")
    echo "DEBUG: Filtered output completed" >&2
    issue_count=$(echo "$filtered_output" | wc -l)
    echo "DEBUG: Issue count calculated: $issue_count" >&2

    if [[ "$SHOW_JSON" == false && "$SHOW_SUMMARY_ONLY" == false ]]; then
      echo "DEBUG: About to show file issues" >&2
      print_warning "$(basename "$file") - $issue_count issues found"

      if [[ "$SHOW_VERBOSE" == true ]]; then
        print_dim "  File: $file ($file_stats)"
      fi

      # Limit output if requested
      if [[ $issue_count -gt $MAX_ISSUES_DISPLAY ]]; then
        echo "$filtered_output" | head -n "$MAX_ISSUES_DISPLAY" | sed 's/^/  /'
        print_dim "  ... and $((issue_count - MAX_ISSUES_DISPLAY)) more issues (use -m to adjust limit)"
      else
        echo "$filtered_output" | sed 's/^/  /'
      fi
      echo
      echo "DEBUG: Completed showing file issues" >&2
    fi

    echo "DEBUG: About to check performance" >&2
    if [[ "$SHOW_PERFORMANCE" == true ]]; then
      file_duration=$(end_timer)
    fi
    echo "DEBUG: Performance check completed" >&2

    # Store issue count and return non-zero
    FILE_ISSUE_COUNT=$issue_count
    echo "DEBUG: About to return 1" >&2
    return 1
  fi
}

# Main analysis function
run_analysis() {
  local results=()
  local total_files=0
  local clean_files=0
  local files_with_issues=0
  local total_issues=0
  local overall_start_time
  local overall_duration

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    overall_start_time=$(date +%s)
  fi

  # Header
  if [[ "$SHOW_JSON" == false ]]; then
    print_header "🔍 $SCRIPT_NAME v$SCRIPT_VERSION"
    echo "=============================================="
    if [[ -n "$SEVERITY_FILTER" ]]; then
      print_info "Filtering by severity: $SEVERITY_FILTER"
    fi
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
      print_info "Excluding patterns: ${EXCLUDE_PATTERNS[*]}"
    fi
    echo
  fi

  # Check if ShellCheck is installed
  if ! command -v shellcheck &>/dev/null; then
    print_error "ShellCheck not found. Install with: brew install shellcheck"
    exit 1
  fi

  # Find and process bash files
  local exit_code

  # Get list of files first
  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find . -name "*.sh" -type f -print0)

  for file in "${files[@]}"; do
    # Skip excluded patterns
    if is_excluded "$file"; then
      continue
    fi

    total_files=$((total_files + 1))

    # Check file and get result (handle errors gracefully)
    set +e # Temporarily disable exit on error
    if check_file "$file"; then
      exit_code=0
    else
      exit_code=1
    fi
    set -e # Re-enable exit on error

    if [[ $exit_code -eq 0 ]]; then
      clean_files=$((clean_files + 1))
    else
      files_with_issues=$((files_with_issues + 1))
      total_issues=$((total_issues + FILE_ISSUE_COUNT))
    fi

  done

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    overall_duration=$(($(date +%s) - overall_start_time))
  fi

  echo "DEBUG: About to show results" >&2

  # Output results
  if [[ "$SHOW_JSON" == true ]]; then
    # Simple JSON output for now
    echo "{"
    echo "  \"analyzer\": \"$SCRIPT_NAME\","
    echo "  \"version\": \"$SCRIPT_VERSION\","
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"summary\": {"
    echo "    \"total_files\": $total_files,"
    echo "    \"clean_files\": $clean_files,"
    echo "    \"files_with_issues\": $files_with_issues,"
    echo "    \"total_issues\": $total_issues"
    echo "  }"
    echo "}"
  else
    # Summary (always show if not JSON mode)
    echo "=============================================="
    print_header "📊 Analysis Summary"
    echo
    print_info "Total files analyzed: $total_files"
    print_success "Clean files: $clean_files"

    if [[ $files_with_issues -gt 0 ]]; then
      print_warning "Files with issues: $files_with_issues"
      print_warning "Total issues found: $total_issues"
      echo
      echo "💡 To fix issues automatically, run: ${BOLD}./fix-lint.sh${NC}"
      echo "💡 For detailed help, run: ${BOLD}$0 --help${NC}"
    else
      print_success "All files are clean! 🎉"
    fi

    if [[ "$SHOW_PERFORMANCE" == true ]]; then
      echo
      print_info "Performance: $(format_duration "$overall_duration") total"
      if [[ $total_files -gt 0 ]]; then
        local avg_time
        avg_time=$((overall_duration / total_files))
        print_info "Average per file: $(format_duration "$avg_time")"
      fi
    fi

    if [[ "$SHOW_STATS" == true ]]; then
      echo
      print_dim "Run with --verbose for detailed output, --json for machine-readable format"
    fi
  fi

  # Write to output file if specified
  if [[ -n "$OUTPUT_FILE" ]]; then
    if [[ "$SHOW_JSON" == true ]]; then
      # Re-run analysis with JSON output to file
      {
        echo "{"
        echo "  \"analyzer\": \"$SCRIPT_NAME\","
        echo "  \"version\": \"$SCRIPT_VERSION\","
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"summary\": {"
        echo "    \"total_files\": $total_files,"
        echo "    \"clean_files\": $clean_files,"
        echo "    \"files_with_issues\": $files_with_issues,"
        echo "    \"total_issues\": $total_issues"
        echo "  }"
        echo "}"
      } >"$OUTPUT_FILE"
    fi
    print_info "Results written to: $OUTPUT_FILE"
  fi

  # Return appropriate exit code
  if [[ $files_with_issues -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

# Main execution
main() {
  parse_arguments "$@"
  run_analysis
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
