#!/usr/bin/env bash
#
# ServerSentry Function Analysis Tool
#
# Unified tool for comprehensive function analysis across the codebase

set -euo pipefail

# Load ServerSentry environment bootstrap
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Find and source the bootstrap file
  bootstrap_file=""
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Search upward for serversentry-env.sh
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      bootstrap_file="$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  if [[ -n "$bootstrap_file" ]]; then
    # Disable auto-init and quiet mode for tools
    export SERVERSENTRY_AUTO_INIT=false
    export SERVERSENTRY_QUIET=true
    # shellcheck source=/dev/null
    source "$bootstrap_file" || {
      echo "❌ ERROR: Failed to load ServerSentry environment bootstrap" >&2
      exit 1
    }
  else
    echo "❌ ERROR: Could not find serversentry-env.sh bootstrap file" >&2
    echo "   Please ensure you're running from within the ServerSentry project" >&2
    exit 1
  fi
fi

# Load common library
readonly COMMON_LIB="${SERVERSENTRY_TOOLS_DIR}/function-analysis/lib/common.sh"
if [[ ! -f "$COMMON_LIB" ]]; then
  echo "❌ Common library not found: $COMMON_LIB" >&2
  exit 1
fi

# shellcheck source=lib/common.sh
source "$COMMON_LIB"

# Configuration
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION="2.0.0"

# Function: show_usage
# Description: Display usage information
# Parameters: None
# Returns: None
# Example:
#   show_usage
# Dependencies: None
show_usage() {
  cat <<EOF
🔍 ServerSentry Function Analysis Tool v${VERSION}

USAGE:
  $SCRIPT_NAME [OPTIONS] [SCOPE]

SCOPE:
  all         Analyze entire codebase (default)
  lib         Analyze lib/ directory only
  core        Analyze lib/core/ directory only
  plugins     Analyze lib/plugins/ directory only
  ui          Analyze lib/ui/ directory only
  tests       Analyze tests/ directory only

OPTIONS:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -q, --quiet    Suppress non-essential output
  -f, --format   Output format: text|json|csv (default: text)
  -o, --output   Output directory (default: logs/)

EXAMPLES:
  $SCRIPT_NAME                    # Analyze entire codebase
  $SCRIPT_NAME lib                # Analyze lib/ directory only
  $SCRIPT_NAME --format json      # Output in JSON format
  $SCRIPT_NAME -v core            # Verbose analysis of lib/core/

OUTPUT FILES:
  functions.txt       - Complete function definitions
  analysis.md         - Detailed analysis report
  summary.json        - Summary statistics (if JSON format)
  categories.txt      - Categorized functions

EOF
}

# Function: parse_arguments
# Description: Parse command line arguments
# Parameters:
#   $@ - command line arguments
# Returns:
#   Sets global variables for configuration
# Example:
#   parse_arguments "$@"
# Dependencies:
#   - analysis_log
parse_arguments() {
  # Default values
  SCOPE="all"
  VERBOSE=false
  QUIET=false
  OUTPUT_FORMAT="text"
  OUTPUT_DIR="$LOGS_DIR"

  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      show_usage
      exit 0
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -q | --quiet)
      QUIET=true
      shift
      ;;
    -f | --format)
      if [[ $# -lt 2 ]]; then
        analysis_log "ERROR" "Option --format requires a value"
        exit 1
      fi
      OUTPUT_FORMAT="$2"
      if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|csv)$ ]]; then
        analysis_log "ERROR" "Invalid format: $OUTPUT_FORMAT. Use: text, json, or csv"
        exit 1
      fi
      shift 2
      ;;
    -o | --output)
      if [[ $# -lt 2 ]]; then
        analysis_log "ERROR" "Option --output requires a value"
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    all | lib | core | plugins | ui | tests)
      SCOPE="$1"
      shift
      ;;
    *)
      analysis_log "ERROR" "Unknown option: $1"
      show_usage
      exit 1
      ;;
    esac
  done

  # Validate output directory
  if ! mkdir -p "$OUTPUT_DIR"; then
    analysis_log "ERROR" "Failed to create output directory: $OUTPUT_DIR"
    exit 1
  fi

  # Set logging level based on verbosity
  if [[ "$QUIET" == "true" ]]; then
    LOG_LEVEL="ERROR"
  elif [[ "$VERBOSE" == "true" ]]; then
    LOG_LEVEL="DEBUG"
  else
    LOG_LEVEL="INFO"
  fi
}

# Function: get_scope_directory
# Description: Get directory path for analysis scope
# Parameters:
#   $1 (string): scope name
# Returns:
#   Directory path via stdout
# Example:
#   dir=$(get_scope_directory "lib")
# Dependencies: None
get_scope_directory() {
  local scope="$1"

  case "$scope" in
  "all")
    echo "$WORKSPACE_ROOT"
    ;;
  "lib")
    echo "$WORKSPACE_ROOT/lib"
    ;;
  "core")
    echo "$WORKSPACE_ROOT/lib/core"
    ;;
  "plugins")
    echo "$WORKSPACE_ROOT/lib/plugins"
    ;;
  "ui")
    echo "$WORKSPACE_ROOT/lib/ui"
    ;;
  "tests")
    echo "$WORKSPACE_ROOT/tests"
    ;;
  *)
    analysis_log "ERROR" "Invalid scope: $scope"
    return 1
    ;;
  esac
}

# Function: analyze_functions
# Description: Main function analysis logic
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   analyze_functions
# Dependencies:
#   - analysis_log
#   - analysis_find_shell_scripts
#   - analysis_extract_functions
analyze_functions() {
  local scope_dir
  scope_dir=$(get_scope_directory "$SCOPE")

  if [[ ! -d "$scope_dir" ]]; then
    analysis_log "ERROR" "Scope directory not found: $scope_dir"
    return 1
  fi

  analysis_log "INFO" "Starting function analysis"
  analysis_log "INFO" "Scope: $SCOPE ($scope_dir)"
  analysis_log "INFO" "Output format: $OUTPUT_FORMAT"
  analysis_log "INFO" "Output directory: $OUTPUT_DIR"

  # Find shell scripts
  local scripts
  if ! scripts=$(analysis_find_shell_scripts "$scope_dir"); then
    analysis_log "ERROR" "Failed to find shell scripts in scope: $SCOPE"
    return 1
  fi

  local script_count
  script_count=$(echo "$scripts" | wc -l)
  analysis_log "INFO" "Found $script_count shell scripts"

  # Initialize output files
  local functions_file="$OUTPUT_DIR/functions.txt"
  local analysis_file="$OUTPUT_DIR/analysis.md"
  local categories_file="$OUTPUT_DIR/categories.txt"

  if ! analysis_validate_output_file "$functions_file" ||
    ! analysis_validate_output_file "$analysis_file" ||
    ! analysis_validate_output_file "$categories_file"; then
    return 1
  fi

  # Extract functions from all scripts
  local total_functions=0
  declare -A function_categories
  declare -A file_function_counts

  analysis_log "INFO" "Extracting function definitions..."

  {
    echo "# ServerSentry Function Definitions"
    echo "# Generated: $(analysis_generate_timestamp)"
    echo "# Scope: $SCOPE"
    echo "# Format: function_name|file|line|type"
    echo ""
  } >"$functions_file"

  while IFS= read -r script; do
    local rel_path
    rel_path=$(analysis_get_relative_path "$script")

    if [[ "$VERBOSE" == "true" ]]; then
      analysis_log "INFO" "Processing: $rel_path"
    fi

    local functions
    if functions=$(analysis_extract_functions "$script"); then
      local file_func_count=0

      while IFS='|' read -r func_name line_num func_type; do
        if [[ -n "$func_name" ]]; then
          echo "$func_name|$rel_path|$line_num|$func_type" >>"$functions_file"

          # Categorize function
          local category
          category=$(analysis_categorize_function "$func_name")
          function_categories["$category"]=$((${function_categories["$category"]:-0} + 1))

          ((total_functions++))
          ((file_func_count++))
        fi
      done <<<"$functions"

      file_function_counts["$rel_path"]=$file_func_count
    fi
  done <<<"$scripts"

  analysis_log "SUCCESS" "Extracted $total_functions functions from $script_count files"

  # Generate categorized output
  analysis_log "INFO" "Generating categorized analysis..."
  generate_categories_report "$categories_file" function_categories

  # Generate main analysis report
  analysis_log "INFO" "Generating analysis report..."
  generate_analysis_report "$analysis_file" "$total_functions" "$script_count" function_categories file_function_counts

  # Generate JSON output if requested
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local json_file="$OUTPUT_DIR/summary.json"
    analysis_log "INFO" "Generating JSON summary..."
    generate_json_summary "$json_file" "$total_functions" "$script_count" function_categories
  fi

  analysis_log "SUCCESS" "Analysis complete!"
  analysis_log "INFO" "Output files:"
  analysis_log "INFO" "  📋 Functions: $functions_file"
  analysis_log "INFO" "  📊 Analysis: $analysis_file"
  analysis_log "INFO" "  📂 Categories: $categories_file"

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    analysis_log "INFO" "  📄 JSON Summary: $OUTPUT_DIR/summary.json"
  fi

  return 0
}

# Function: generate_categories_report
# Description: Generate categorized functions report
# Parameters:
#   $1 (string): output file path
#   $2 (array): function categories associative array name
# Returns:
#   0 - success
# Example:
#   generate_categories_report "$file" function_categories
# Dependencies: None
generate_categories_report() {
  local output_file="$1"
  local -n categories_ref=$2

  {
    echo "# Function Categories Report"
    echo "# Generated: $(analysis_generate_timestamp)"
    echo "# Scope: $SCOPE"
    echo ""

    for category in $(printf '%s\n' "${!categories_ref[@]}" | sort); do
      local count=${categories_ref[$category]}
      echo "## $category ($count functions)"
      echo ""

      # Extract functions for this category from the main functions file
      while IFS='|' read -r func_name file line type; do
        local func_category
        func_category=$(analysis_categorize_function "$func_name")
        if [[ "$func_category" == "$category" ]]; then
          echo "- \`$func_name\` in \`$file\` (line $line)"
        fi
      done < <(grep -v "^#" "$OUTPUT_DIR/functions.txt" 2>/dev/null || true)

      echo ""
    done
  } >"$output_file"
}

# Function: generate_analysis_report
# Description: Generate main analysis report
# Parameters:
#   $1 (string): output file path
#   $2 (integer): total functions
#   $3 (integer): script count
#   $4 (array): function categories associative array name
#   $5 (array): file function counts associative array name
# Returns:
#   0 - success
# Example:
#   generate_analysis_report "$file" 100 10 categories counts
# Dependencies: None
generate_analysis_report() {
  local output_file="$1"
  local total_functions="$2"
  local script_count="$3"
  local -n categories_ref=$4
  local -n file_counts_ref=$5

  {
    echo "# ServerSentry Function Analysis Report"
    echo ""
    echo "**Generated:** $(analysis_generate_timestamp)"
    echo "**Scope:** $SCOPE"
    echo "**Tool Version:** $VERSION"
    echo ""

    echo "## Summary"
    echo ""
    echo "- **Total Functions:** $total_functions"
    echo "- **Total Files:** $script_count"
    echo "- **Average Functions per File:** $((total_functions / script_count))"
    echo ""

    echo "## Function Categories"
    echo ""
    echo "| Category | Count | Percentage |"
    echo "|----------|-------|------------|"

    for category in $(printf '%s\n' "${!categories_ref[@]}" | sort); do
      local count=${categories_ref[$category]}
      local percentage=$((count * 100 / total_functions))
      echo "| $category | $count | ${percentage}% |"
    done

    echo ""
    echo "## Files by Function Count"
    echo ""
    echo "| File | Function Count |"
    echo "|------|----------------|"

    for file in $(printf '%s\n' "${!file_counts_ref[@]}" | sort); do
      local count=${file_counts_ref[$file]}
      echo "| \`$file\` | $count |"
    done

    echo ""
    echo "## Analysis Insights"
    echo ""

    # Find most common category
    local max_count=0
    local max_category=""
    for category in "${!categories_ref[@]}"; do
      if [[ ${categories_ref[$category]} -gt $max_count ]]; then
        max_count=${categories_ref[$category]}
        max_category="$category"
      fi
    done

    echo "- **Most Common Function Type:** $max_category ($max_count functions)"
    echo "- **Function Density:** $((total_functions * 1000 / script_count)) functions per 1000 lines (estimated)"

    # Check for potential issues
    local uncategorized_count=${categories_ref["uncategorized"]:-0}
    if [[ $uncategorized_count -gt 0 ]]; then
      local uncategorized_percentage=$((uncategorized_count * 100 / total_functions))
      echo "- **⚠️ Uncategorized Functions:** $uncategorized_count (${uncategorized_percentage}%)"
    fi

    echo ""
    echo "## Recommendations"
    echo ""

    if [[ $uncategorized_count -gt $((total_functions / 10)) ]]; then
      echo "- Consider improving function naming conventions to reduce uncategorized functions"
    fi

    if [[ $((total_functions / script_count)) -gt 20 ]]; then
      echo "- Some files may benefit from being split into smaller, more focused modules"
    fi

    echo "- Review function categories to ensure proper code organization"
    echo "- Consider refactoring large function categories into separate modules"

  } >"$output_file"
}

# Function: generate_json_summary
# Description: Generate JSON summary report
# Parameters:
#   $1 (string): output file path
#   $2 (integer): total functions
#   $3 (integer): script count
#   $4 (array): function categories associative array name
# Returns:
#   0 - success
# Example:
#   generate_json_summary "$file" 100 10 categories
# Dependencies: None
generate_json_summary() {
  local output_file="$1"
  local total_functions="$2"
  local script_count="$3"
  local -n categories_ref=$4

  {
    echo "{"
    echo "  \"analysis\": {"
    echo "    \"timestamp\": \"$(analysis_generate_timestamp)\","
    echo "    \"scope\": \"$SCOPE\","
    echo "    \"tool_version\": \"$VERSION\""
    echo "  },"
    echo "  \"summary\": {"
    echo "    \"total_functions\": $total_functions,"
    echo "    \"total_files\": $script_count,"
    echo "    \"average_functions_per_file\": $((total_functions / script_count))"
    echo "  },"
    echo "  \"categories\": {"

    local first=true
    for category in $(printf '%s\n' "${!categories_ref[@]}" | sort); do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        echo ","
      fi
      local count=${categories_ref[$category]}
      local percentage=$((count * 100 / total_functions))
      echo -n "    \"$category\": {\"count\": $count, \"percentage\": $percentage}"
    done

    echo ""
    echo "  }"
    echo "}"
  } >"$output_file"
}

# Function: main
# Description: Main entry point
# Parameters:
#   $@ - command line arguments
# Returns:
#   0 - success
#   1 - failure
# Example:
#   main "$@"
# Dependencies:
#   - analysis_init
#   - parse_arguments
#   - analyze_functions
main() {
  # Initialize analysis environment
  if ! analysis_init; then
    echo "❌ Failed to initialize analysis environment" >&2
    exit 1
  fi

  # Parse command line arguments
  parse_arguments "$@"

  # Show header (unless quiet mode)
  if [[ "$QUIET" != "true" ]]; then
    echo -e "${BLUE}🔍 ServerSentry Function Analysis Tool v${VERSION}${NC}"
    echo "=============================================="
    echo ""
  fi

  # Run analysis
  if ! analyze_functions; then
    analysis_log "ERROR" "Function analysis failed"
    exit 1
  fi

  # Show completion message (unless quiet mode)
  if [[ "$QUIET" != "true" ]]; then
    echo ""
    echo -e "${GREEN}✅ Analysis completed successfully!${NC}"
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
