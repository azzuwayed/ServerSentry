#!/usr/bin/env bash
#
# ServerSentry Function Search Tool
#
# Quick and efficient function search across the codebase

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
🔍 ServerSentry Function Search Tool v${VERSION}

USAGE:
  $SCRIPT_NAME [OPTIONS] <search_term>

OPTIONS:
  -h, --help        Show this help message
  -i, --ignore-case Case-insensitive search
  -e, --exact       Exact function name match only
  -f, --file        Search in specific file pattern
  -c, --category    Search by function category
  -l, --list-cats   List all available categories

SEARCH MODES:
  Default           Search in function names and file paths
  --exact           Match exact function name
  --category        Search by function category
  --file            Search in specific files

EXAMPLES:
  $SCRIPT_NAME util_                    # Find all util_ functions
  $SCRIPT_NAME --exact config_init      # Find exact function name
  $SCRIPT_NAME --category validation    # Find all validation functions
  $SCRIPT_NAME --file "*.sh" log        # Search for 'log' in all .sh files
  $SCRIPT_NAME -i CONFIG                # Case-insensitive search for CONFIG

CATEGORIES:
  utility, configuration, logging, error_handling, validation, testing,
  data_retrieval, data_modification, creation, data_processing,
  initialization, cleanup, monitoring, plugin_system, notification,
  communication, user_interface, output, input, file_operations,
  persistence, anomaly_detection, composite_operations, diagnostics,
  internal, uncategorized

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
  SEARCH_TERM=""
  IGNORE_CASE=false
  EXACT_MATCH=false
  FILE_PATTERN=""
  CATEGORY_SEARCH=""
  LIST_CATEGORIES=false

  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      show_usage
      exit 0
      ;;
    -i | --ignore-case)
      IGNORE_CASE=true
      shift
      ;;
    -e | --exact)
      EXACT_MATCH=true
      shift
      ;;
    -f | --file)
      if [[ $# -lt 2 ]]; then
        analysis_log "ERROR" "Option --file requires a value"
        exit 1
      fi
      FILE_PATTERN="$2"
      shift 2
      ;;
    -c | --category)
      if [[ $# -lt 2 ]]; then
        analysis_log "ERROR" "Option --category requires a value"
        exit 1
      fi
      CATEGORY_SEARCH="$2"
      shift 2
      ;;
    -l | --list-cats)
      LIST_CATEGORIES=true
      shift
      ;;
    -*)
      analysis_log "ERROR" "Unknown option: $1"
      show_usage
      exit 1
      ;;
    *)
      if [[ -z "$SEARCH_TERM" ]]; then
        SEARCH_TERM="$1"
      else
        analysis_log "ERROR" "Multiple search terms not supported: $1"
        exit 1
      fi
      shift
      ;;
    esac
  done

  # Validate arguments
  if [[ "$LIST_CATEGORIES" == "true" ]]; then
    return 0
  fi

  if [[ -z "$SEARCH_TERM" && -z "$CATEGORY_SEARCH" ]]; then
    analysis_log "ERROR" "Search term or category required"
    show_usage
    exit 1
  fi
}

# Function: list_categories
# Description: List all available function categories
# Parameters: None
# Returns:
#   0 - success
# Example:
#   list_categories
# Dependencies:
#   - analysis_log
list_categories() {
  analysis_log "INFO" "Available function categories:"
  echo ""

  local categories=(
    "utility" "configuration" "logging" "error_handling" "validation"
    "testing" "data_retrieval" "data_modification" "creation"
    "data_processing" "initialization" "cleanup" "monitoring"
    "plugin_system" "notification" "communication" "user_interface"
    "output" "input" "file_operations" "persistence"
    "anomaly_detection" "composite_operations" "diagnostics"
    "internal" "uncategorized"
  )

  for category in "${categories[@]}"; do
    echo "  📂 $category"
  done

  echo ""
  analysis_log "INFO" "Use: $SCRIPT_NAME --category <category_name> to search by category"
}

# Function: search_functions_database
# Description: Search in the functions database
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   search_functions_database
# Dependencies:
#   - analysis_log
search_functions_database() {
  local functions_file="$LOGS_DIR/functions.txt"

  # Check if functions database exists
  if [[ ! -f "$functions_file" ]]; then
    analysis_log "ERROR" "Functions database not found: $functions_file"
    analysis_log "INFO" "Run './analyze.sh' first to generate the database"
    return 1
  fi

  # Perform search based on mode
  local results=""

  if [[ -n "$CATEGORY_SEARCH" ]]; then
    results=$(search_by_category "$functions_file")
  elif [[ "$EXACT_MATCH" == "true" ]]; then
    results=$(search_exact_function "$functions_file")
  else
    results=$(search_general "$functions_file")
  fi

  # Display results
  if [[ -z "$results" ]]; then
    analysis_log "WARN" "No functions found matching search criteria"
    return 1
  fi

  display_search_results "$results"
  return 0
}

# Function: search_by_category
# Description: Search functions by category
# Parameters:
#   $1 (string): functions file path
# Returns:
#   Search results via stdout
# Example:
#   results=$(search_by_category "$file")
# Dependencies:
#   - analysis_categorize_function
search_by_category() {
  local functions_file="$1"
  local results=""

  while IFS='|' read -r func_name file line type; do
    if [[ -n "$func_name" ]]; then
      local category
      category=$(analysis_categorize_function "$func_name")

      if [[ "$IGNORE_CASE" == "true" ]]; then
        if [[ "${category,,}" == "${CATEGORY_SEARCH,,}" ]]; then
          results+="$func_name|$file|$line|$type|$category"$'\n'
        fi
      else
        if [[ "$category" == "$CATEGORY_SEARCH" ]]; then
          results+="$func_name|$file|$line|$type|$category"$'\n'
        fi
      fi
    fi
  done < <(grep -v "^#" "$functions_file" 2>/dev/null || true)

  echo "$results"
}

# Function: search_exact_function
# Description: Search for exact function name match
# Parameters:
#   $1 (string): functions file path
# Returns:
#   Search results via stdout
# Example:
#   results=$(search_exact_function "$file")
# Dependencies: None
search_exact_function() {
  local functions_file="$1"
  local grep_options=""

  if [[ "$IGNORE_CASE" == "true" ]]; then
    grep_options="-i"
  fi

  # Search for exact function name match
  grep $grep_options "^${SEARCH_TERM}|" "$functions_file" 2>/dev/null || true
}

# Function: search_general
# Description: General search in function names and file paths
# Parameters:
#   $1 (string): functions file path
# Returns:
#   Search results via stdout
# Example:
#   results=$(search_general "$file")
# Dependencies: None
search_general() {
  local functions_file="$1"
  local grep_options=""

  if [[ "$IGNORE_CASE" == "true" ]]; then
    grep_options="-i"
  fi

  # Search in function names and file paths
  local results=""

  # Search in function names
  results+=$(grep $grep_options "$SEARCH_TERM" "$functions_file" 2>/dev/null || true)

  # If file pattern is specified, filter by file pattern
  if [[ -n "$FILE_PATTERN" ]]; then
    results=$(echo "$results" | grep "$FILE_PATTERN" || true)
  fi

  echo "$results"
}

# Function: display_search_results
# Description: Display formatted search results
# Parameters:
#   $1 (string): search results
# Returns: None
# Example:
#   display_search_results "$results"
# Dependencies:
#   - analysis_log
#   - analysis_categorize_function
display_search_results() {
  local results="$1"
  local count=0

  echo -e "${GREEN}🔍 Search Results${NC}"
  echo "=================="
  echo ""

  while IFS='|' read -r func_name file line type category; do
    if [[ -n "$func_name" ]]; then
      ((count++))

      # Get category if not provided
      if [[ -z "$category" ]]; then
        category=$(analysis_categorize_function "$func_name")
      fi

      echo -e "${BLUE}📋 Function:${NC} ${CYAN}$func_name${NC}"
      echo -e "${BLUE}📁 File:${NC} $file"
      echo -e "${BLUE}📍 Line:${NC} $line"
      echo -e "${BLUE}🏷️  Type:${NC} $type"
      echo -e "${BLUE}📂 Category:${NC} $category"
      echo ""
    fi
  done <<<"$results"

  if [[ $count -eq 0 ]]; then
    analysis_log "WARN" "No results to display"
  else
    analysis_log "SUCCESS" "Found $count matching function(s)"
    echo ""
    echo -e "${PURPLE}💡 Tips:${NC}"
    echo "  • View function: grep -A 10 '$func_name' <file>"
    echo "  • Search category: $SCRIPT_NAME --category <category>"
    echo "  • Exact match: $SCRIPT_NAME --exact <function_name>"
  fi
}

# Function: search_live
# Description: Perform live search without database
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   search_live
# Dependencies:
#   - analysis_log
#   - analysis_find_shell_scripts
search_live() {
  analysis_log "INFO" "Performing live search (no database found)"

  local search_dir="$WORKSPACE_ROOT"
  if [[ -n "$FILE_PATTERN" ]]; then
    search_dir="$WORKSPACE_ROOT"
  fi

  local scripts
  if ! scripts=$(analysis_find_shell_scripts "$search_dir"); then
    analysis_log "ERROR" "Failed to find shell scripts"
    return 1
  fi

  local results=""
  local grep_options="-n"

  if [[ "$IGNORE_CASE" == "true" ]]; then
    grep_options+="i"
  fi

  # Search for function definitions matching the search term
  while IFS= read -r script; do
    local rel_path
    rel_path=$(analysis_get_relative_path "$script")

    # Skip if file pattern specified and doesn't match
    if [[ -n "$FILE_PATTERN" && ! "$rel_path" =~ $FILE_PATTERN ]]; then
      continue
    fi

    # Search for function definitions
    local matches
    if [[ "$EXACT_MATCH" == "true" ]]; then
      matches=$(grep $grep_options "^[[:space:]]*${SEARCH_TERM}()[[:space:]]*{" "$script" 2>/dev/null || true)
      matches+=$'\n'$(grep $grep_options "^[[:space:]]*function[[:space:]]\+${SEARCH_TERM}[[:space:]]*(" "$script" 2>/dev/null || true)
    else
      matches=$(grep $grep_options "${SEARCH_TERM}" "$script" 2>/dev/null | grep -E "(^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)|^[[:space:]]*function[[:space:]]+[a-zA-Z_])" || true)
    fi

    if [[ -n "$matches" && "$matches" != $'\n' ]]; then
      while IFS=: read -r line_num line_content; do
        if [[ -n "$line_num" && -n "$line_content" ]]; then
          # Extract function name
          local func_name
          if [[ "$line_content" =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            func_name="${BASH_REMATCH[1]}"
          elif [[ "$line_content" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\(\) ]]; then
            func_name="${BASH_REMATCH[1]}"
          else
            continue
          fi

          results+="$func_name|$rel_path|$line_num|live_search"$'\n'
        fi
      done <<<"$matches"
    fi
  done <<<"$scripts"

  if [[ -z "$results" ]]; then
    analysis_log "WARN" "No functions found matching: $SEARCH_TERM"
    return 1
  fi

  display_search_results "$results"
  return 0
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
main() {
  # Initialize analysis environment
  if ! analysis_init; then
    echo "❌ Failed to initialize analysis environment" >&2
    exit 1
  fi

  # Parse command line arguments
  parse_arguments "$@"

  # Handle list categories request
  if [[ "$LIST_CATEGORIES" == "true" ]]; then
    list_categories
    exit 0
  fi

  # Show header
  echo -e "${BLUE}🔍 ServerSentry Function Search Tool v${VERSION}${NC}"
  echo "================================================"
  echo ""

  # Perform search
  if [[ -f "$LOGS_DIR/functions.txt" ]]; then
    if ! search_functions_database; then
      exit 1
    fi
  else
    if ! search_live; then
      exit 1
    fi
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
