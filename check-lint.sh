#!/usr/bin/env bash
#
# ServerSentry ShellCheck Analyzer v3.0
# Enhanced bash script linting analysis with detailed reporting and comprehensive options
#

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="ServerSentry ShellCheck Analyzer"

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Configuration with defaults
SHOW_VERBOSE=false
SHOW_JSON=false
SHOW_SUMMARY_ONLY=false
SHOW_STATS=true
SHOW_PERFORMANCE=false
SEVERITY_FILTER=""
OUTPUT_FILE=""
EXCLUDE_PATTERNS=()
MAX_ISSUES_DISPLAY=50
MIN_SEVERITY_LEVEL=""

# Statistics tracking
declare -A FILE_STATS
declare -A SEVERITY_COUNTS
TOTAL_EXECUTION_TIME=0
FILES_PROCESSED=0

# Print functions
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${BOLD}${CYAN}$1${NC}"; }
print_dim() { echo -e "${DIM}$1${NC}"; }

# Enhanced usage information
show_usage() {
  cat <<EOF
${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BOLD}DESCRIPTION:${NC}
  Comprehensive bash script analysis using ShellCheck with enhanced reporting,
  filtering, and export capabilities for professional development workflows.

${BOLD}USAGE:${NC}
  $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
  ${BOLD}Output Control:${NC}
    -v, --verbose          Show detailed output for each file
    -j, --json             Output results in JSON format
    -s, --summary          Show summary only (no individual file details)
    -q, --quiet            Suppress statistics and performance info
    -p, --performance      Show detailed performance metrics

  ${BOLD}Filtering:${NC}
    -f, --filter LEVEL     Filter by severity: error, warning, info, style
    --min-severity LEVEL   Show only issues at or above this severity level
    -e, --exclude PATTERN  Exclude files matching pattern (can be used multiple times)
    -m, --max-issues N     Maximum issues to display per file (default: 50)

  ${BOLD}Output:${NC}
    -o, --output FILE      Write output to file
    --format FORMAT        Output format: text, json, csv (default: text)

  ${BOLD}Help:${NC}
    -h, --help             Show this help message
    --version              Show version information

${BOLD}EXAMPLES:${NC}
  $0                              # Standard analysis
  $0 -v -p                        # Verbose with performance metrics
  $0 -j -o results.json           # JSON output to file
  $0 -s -q                        # Quick summary only
  $0 -f error --min-severity error # Show only errors
  $0 -e "test*" -e "tmp*"         # Exclude test and tmp directories
  $0 --format csv -o report.csv   # CSV export for spreadsheet analysis

${BOLD}INTEGRATION:${NC}
  • Run './fix-lint.sh' to automatically fix common issues
  • Use with VS Code tasks for integrated development workflow
  • Pipe to other tools: $0 -j | jq '.summary.total_issues'
  • CI/CD integration: exit code 0 = clean, 1 = issues found

${BOLD}SEVERITY LEVELS:${NC}
  error   - Syntax errors, critical issues
  warning - Potential problems, bad practices
  info    - Suggestions for improvement
  style   - Style and formatting recommendations
EOF
}

# Enhanced argument parsing with validation
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
      if [[ -z "${2:-}" ]]; then
        print_error "Filter option requires a severity level"
        exit 1
      fi
      SEVERITY_FILTER="$2"
      shift 2
      ;;
    --min-severity)
      if [[ -z "${2:-}" ]]; then
        print_error "Min severity option requires a level"
        exit 1
      fi
      MIN_SEVERITY_LEVEL="$2"
      shift 2
      ;;
    -o | --output)
      if [[ -z "${2:-}" ]]; then
        print_error "Output option requires a filename"
        exit 1
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -e | --exclude)
      if [[ -z "${2:-}" ]]; then
        print_error "Exclude option requires a pattern"
        exit 1
      fi
      EXCLUDE_PATTERNS+=("$2")
      shift 2
      ;;
    -m | --max-issues)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        print_error "Max issues must be a positive number"
        exit 1
      fi
      MAX_ISSUES_DISPLAY="$2"
      shift 2
      ;;
    --format)
      if [[ -z "${2:-}" ]]; then
        print_error "Format option requires a format type"
        exit 1
      fi
      case "$2" in
      text | json | csv)
        if [[ "$2" == "json" ]]; then
          SHOW_JSON=true
        fi
        ;;
      *)
        print_error "Invalid format: $2. Use text, json, or csv"
        exit 1
        ;;
      esac
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

  # Validate severity levels
  for level in "$SEVERITY_FILTER" "$MIN_SEVERITY_LEVEL"; do
    if [[ -n "$level" ]] && [[ ! "$level" =~ ^(error|warning|info|style)$ ]]; then
      print_error "Invalid severity level: $level. Use: error, warning, info, style"
      exit 1
    fi
  done
}

# Check if pattern should be excluded
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

# Enhanced severity filtering with level hierarchy
filter_severity() {
  local output="$1"
  local filtered_output=""

  if [[ -z "$SEVERITY_FILTER" && -z "$MIN_SEVERITY_LEVEL" ]]; then
    echo "$output"
    return
  fi

  # Define severity levels with numeric values for comparison
  declare -A severity_levels=(
    [error]=4
    [warning]=3
    [info]=2
    [style]=1
  )

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi

    local line_severity=""
    for sev in error warning info style; do
      if [[ "$line" =~ \($sev\): ]]; then
        line_severity="$sev"
        break
      fi
    done

    # Apply filters
    local include_line=true

    if [[ -n "$SEVERITY_FILTER" && "$line_severity" != "$SEVERITY_FILTER" ]]; then
      include_line=false
    fi

    if [[ -n "$MIN_SEVERITY_LEVEL" && -n "$line_severity" ]]; then
      local min_level="${severity_levels[$MIN_SEVERITY_LEVEL]:-0}"
      local current_level="${severity_levels[$line_severity]:-0}"
      if [[ $current_level -lt $min_level ]]; then
        include_line=false
      fi
    fi

    if [[ "$include_line" == true ]]; then
      filtered_output+="$line"$'\n'
      # Count severity types
      if [[ -n "$line_severity" ]]; then
        ((SEVERITY_COUNTS[$line_severity]++)) || SEVERITY_COUNTS[$line_severity]=1
      fi
    fi
  done <<<"$output"

  echo -n "$filtered_output"
}

# Get comprehensive file statistics
get_file_stats() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "size:0,lines:0,executable:false"
    return
  fi

  local size lines executable="false"
  size=$(wc -c <"$file" 2>/dev/null || echo "0")
  lines=$(wc -l <"$file" 2>/dev/null || echo "0")

  if [[ -x "$file" ]]; then
    executable="true"
  fi

  echo "size:$size,lines:$lines,executable:$executable"
}

# Performance timing utilities
start_timer() {
  date +%s%N
}

end_timer() {
  local start_time="$1"
  local end_time
  end_time=$(date +%s%N)
  echo $(((end_time - start_time) / 1000000)) # Return milliseconds
}

# Format duration for display
format_duration() {
  local duration_ms="$1"
  if [[ $duration_ms -lt 1000 ]]; then
    echo "${duration_ms}ms"
  else
    echo "$((duration_ms / 1000)).$((duration_ms % 1000 / 100))s"
  fi
}

# Enhanced file checking with better error handling
check_file() {
  local file="$1"
  local start_time end_time duration_ms=0
  local file_stats shellcheck_output filtered_output
  local issue_count=0

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    start_time=$(start_timer)
  fi

  file_stats=$(get_file_stats "$file")
  FILES_PROCESSED=$((FILES_PROCESSED + 1))

  # Run ShellCheck with comprehensive error handling
  if shellcheck_output=$(shellcheck "$file" 2>&1); then
    # No issues found
    if [[ "$SHOW_VERBOSE" == true ]] && [[ "$SHOW_JSON" == false && "$SHOW_SUMMARY_ONLY" == false ]]; then
      print_success "$(basename "$file") - Clean"
      if [[ "$SHOW_VERBOSE" == true ]]; then
        print_dim "  File: $file ($file_stats)"
      fi
    fi

    FILE_STATS["$file"]="clean:0"
  else
    # Process issues
    filtered_output=$(filter_severity "$shellcheck_output")
    if [[ -n "$filtered_output" ]]; then
      issue_count=$(echo -n "$filtered_output" | wc -l)
    else
      issue_count=0
    fi

    if [[ "$SHOW_JSON" == false && "$SHOW_SUMMARY_ONLY" == false ]]; then
      if [[ $issue_count -gt 0 ]]; then
        print_warning "$(basename "$file") - $issue_count issue$([ "$issue_count" -ne 1 ] && echo "s")"

        if [[ "$SHOW_VERBOSE" == true ]]; then
          print_dim "  File: $file ($file_stats)"
        fi

        # Display issues with smart truncation
        if [[ $issue_count -gt $MAX_ISSUES_DISPLAY ]]; then
          echo "$filtered_output" | head -n "$MAX_ISSUES_DISPLAY" | sed 's/^/  /'
          print_dim "  ... and $((issue_count - MAX_ISSUES_DISPLAY)) more issues (use -m to adjust limit)"
        else
          # shellcheck disable=SC2001
          echo "$filtered_output" | sed 's/^/  /'
        fi
        echo
      fi
    fi

    if [[ $issue_count -eq 0 ]]; then
      FILE_STATS["$file"]="clean:0"
    else
      FILE_STATS["$file"]="issues:$issue_count"
    fi
  fi

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    duration_ms=$(end_timer "$start_time")
    TOTAL_EXECUTION_TIME=$((TOTAL_EXECUTION_TIME + duration_ms))
    FILE_STATS["$file"]="${FILE_STATS["$file"]},duration:$duration_ms"
  fi

  if [[ $issue_count -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Find bash files with improved detection
find_bash_files() {
  local files=()

  # Find .sh files
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find . -name "*.sh" -type f -print0 2>/dev/null)

  # Find executable files with bash shebang
  while IFS= read -r file; do
    if [[ -f "$file" && -x "$file" ]]; then
      files+=("$file")
    fi
  done < <(find . -type f -executable \! -name "*.sh" -exec grep -l "^#!/.*bash" {} \; 2>/dev/null)

  # Remove duplicates and apply exclusions
  local unique_files=()
  for file in "${files[@]}"; do
    if [[ ! " ${unique_files[*]} " == *" ${file} "* ]] && ! is_excluded "$file"; then
      unique_files+=("$file")
    fi
  done

  printf '%s\n' "${unique_files[@]}"
}

# Enhanced JSON output generation
generate_json_output() {
  local total_files="$1"
  local clean_files="$2"
  local files_with_issues="$3"
  local total_issues="$4"

  cat <<EOF
{
  "metadata": {
    "analyzer": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scan_duration_ms": $TOTAL_EXECUTION_TIME,
    "filters": {
      "severity_filter": "${SEVERITY_FILTER:-null}",
      "min_severity": "${MIN_SEVERITY_LEVEL:-null}",
      "exclude_patterns": [$(printf '"%s",' "${EXCLUDE_PATTERNS[@]}" | sed 's/,$//')]
    }
  },
  "summary": {
    "total_files": $total_files,
    "clean_files": $clean_files,
    "files_with_issues": $files_with_issues,
    "total_issues": $total_issues,
    "severity_breakdown": {
      "error": ${SEVERITY_COUNTS[error]:-0},
      "warning": ${SEVERITY_COUNTS[warning]:-0},
      "info": ${SEVERITY_COUNTS[info]:-0},
      "style": ${SEVERITY_COUNTS[style]:-0}
    }
  },
  "performance": {
    "total_duration_ms": $TOTAL_EXECUTION_TIME,
    "files_processed": $FILES_PROCESSED,
    "average_time_per_file_ms": $([[ $FILES_PROCESSED -gt 0 ]] && echo $((TOTAL_EXECUTION_TIME / FILES_PROCESSED)) || echo 0)
  }
}
EOF
}

# Main analysis function with improved organization
run_analysis() {
  local files_array total_files=0 clean_files=0 files_with_issues=0 total_issues=0
  local overall_start_time overall_duration_ms=0

  # Initialize severity counters
  SEVERITY_COUNTS[error]=0
  SEVERITY_COUNTS[warning]=0
  SEVERITY_COUNTS[info]=0
  SEVERITY_COUNTS[style]=0

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    overall_start_time=$(start_timer)
  fi

  # Pre-flight checks
  if ! command -v shellcheck &>/dev/null; then
    print_error "ShellCheck not found. Install with: brew install shellcheck"
    exit 1
  fi

  # Display header (unless JSON mode)
  if [[ "$SHOW_JSON" == false ]]; then
    print_header "🔍 $SCRIPT_NAME v$SCRIPT_VERSION"
    echo "=============================================="
    if [[ -n "$SEVERITY_FILTER" ]]; then
      print_info "Filtering by severity: $SEVERITY_FILTER"
    fi
    if [[ -n "$MIN_SEVERITY_LEVEL" ]]; then
      print_info "Minimum severity level: $MIN_SEVERITY_LEVEL"
    fi
    if [[ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]]; then
      print_info "Excluding patterns: ${EXCLUDE_PATTERNS[*]}"
    fi
    echo
  fi

  # Find and process files
  readarray -t files_array < <(find_bash_files)
  total_files=${#files_array[@]}

  if [[ $total_files -eq 0 ]]; then
    if [[ "$SHOW_JSON" == false ]]; then
      print_warning "No bash files found to analyze"
    fi
    if [[ "$SHOW_JSON" == true ]]; then
      generate_json_output 0 0 0 0
    fi
    exit 0
  fi

  # Process each file
  for file in "${files_array[@]}"; do
    local file_issue_count=0

    if check_file "$file"; then
      clean_files=$((clean_files + 1))
    else
      files_with_issues=$((files_with_issues + 1))
      # Extract issue count from file stats
      if [[ "${FILE_STATS[$file]}" =~ issues:([0-9]+) ]]; then
        file_issue_count=${BASH_REMATCH[1]}
        total_issues=$((total_issues + file_issue_count))
      fi
    fi
  done

  if [[ "$SHOW_PERFORMANCE" == true ]]; then
    overall_duration_ms=$(end_timer "$overall_start_time")
    TOTAL_EXECUTION_TIME=$overall_duration_ms
  fi

  # Generate output
  if [[ "$SHOW_JSON" == true ]]; then
    generate_json_output "$total_files" "$clean_files" "$files_with_issues" "$total_issues"
  else
    # Text summary
    echo "=============================================="
    print_header "📊 Analysis Summary"
    echo
    print_info "Total files analyzed: $total_files"
    print_success "Clean files: $clean_files"

    if [[ $files_with_issues -gt 0 ]]; then
      print_warning "Files with issues: $files_with_issues"
      print_warning "Total issues found: $total_issues"

      # Show severity breakdown if available
      local has_severities=false
      for sev in error warning info style; do
        if [[ ${SEVERITY_COUNTS[$sev]} -gt 0 ]]; then
          has_severities=true
          break
        fi
      done

      if [[ "$has_severities" == true ]]; then
        echo
        print_info "Issue breakdown by severity:"
        for sev in error warning info style; do
          if [[ ${SEVERITY_COUNTS[$sev]} -gt 0 ]]; then
            echo "  $sev: ${SEVERITY_COUNTS[$sev]}"
          fi
        done
      fi

      echo
      echo "💡 To fix issues automatically, run: ${BOLD}./fix-lint.sh${NC}"
      echo "💡 For detailed help, run: ${BOLD}$0 --help${NC}"
    else
      print_success "All files are clean! 🎉"
    fi

    if [[ "$SHOW_PERFORMANCE" == true && $TOTAL_EXECUTION_TIME -gt 0 ]]; then
      echo
      print_info "Performance: $(format_duration "$TOTAL_EXECUTION_TIME") total"
      if [[ $total_files -gt 0 ]]; then
        local avg_time=$((TOTAL_EXECUTION_TIME / total_files))
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
      generate_json_output "$total_files" "$clean_files" "$files_with_issues" "$total_issues" >"$OUTPUT_FILE"
    else
      # For text output, re-run with JSON and save
      generate_json_output "$total_files" "$clean_files" "$files_with_issues" "$total_issues" >"$OUTPUT_FILE"
    fi
    if [[ "$SHOW_JSON" == false ]]; then
      print_info "Results written to: $OUTPUT_FILE"
    fi
  fi

  # Return appropriate exit code
  if [[ $files_with_issues -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# Main execution with error handling
main() {
  # Set up error handling
  trap 'print_error "Script interrupted or failed"; exit 1' ERR INT TERM

  parse_arguments "$@"
  run_analysis
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
