#!/usr/bin/env bash
#
# ServerSentry Function Extractor
# Comprehensive function analysis after refactoring
#

echo "🔍 ServerSentry Function Analysis"
echo "=================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/logs"

# Create output files in the logs subdirectory
FUNCTIONS_LIST="$SCRIPT_DIR/logs/all_functions.txt"
USAGE_REPORT="$SCRIPT_DIR/logs/function_usage.txt"
SUMMARY_REPORT="$SCRIPT_DIR/logs/function_summary.md"

echo "📋 Extracting all function definitions..."

# Extract all function definitions
{
  echo "# All Function Definitions in ServerSentry"
  echo "# Generated: $(date)"
  echo "# Format: FUNCTION_NAME | FILE | LINE_NUMBER | TYPE"
  echo ""

  # Pattern 1: function_name() {
  find . -name "*.sh" -type f -exec grep -Hn "^[a-zA-Z_][a-zA-Z0-9_]*() {" {} \; | while IFS=: read -r file line func_def; do
    func_name=$(echo "$func_def" | sed 's/() {.*//')
    echo "$func_name | $file | $line | standard"
  done

  # Pattern 2: function function_name() {
  find . -name "*.sh" -type f -exec grep -Hn "^function [a-zA-Z_][a-zA-Z0-9_]*() {" {} \; | while IFS=: read -r file line func_def; do
    func_name=$(echo "$func_def" | sed 's/^function //' | sed 's/() {.*//')
    echo "$func_name | $file | $line | function_keyword"
  done

  # Pattern 3: function function_name {
  find . -name "*.sh" -type f -exec grep -Hn "^function [a-zA-Z_][a-zA-Z0-9_]* {" {} \; | while IFS=: read -r file line func_def; do
    func_name=$(echo "$func_def" | sed 's/^function //' | sed 's/ {.*//')
    echo "$func_name | $file | $line | function_no_parens"
  done
} >"$FUNCTIONS_LIST"

echo "📊 Analyzing function usage..."

# Create usage analysis
{
  echo "# Function Usage Analysis"
  echo "# Generated: $(date)"
  echo ""

  echo "## Functions by Category"
  echo ""

  echo "### Core System Functions"
  grep "lib/core" "$FUNCTIONS_LIST" | sort
  echo ""

  echo "### Plugin Functions"
  grep "plugins/" "$FUNCTIONS_LIST" | sort
  echo ""

  echo "### UI Functions"
  grep "lib/ui" "$FUNCTIONS_LIST" | sort
  echo ""

  echo "### Notification Functions"
  grep "lib/notifications" "$FUNCTIONS_LIST" | sort
  echo ""

  echo "### Test Functions"
  grep "tests/" "$FUNCTIONS_LIST" | sort
  echo ""

  echo "### Utility Scripts"
  grep -E "\./[^/]+\.sh" "$FUNCTIONS_LIST" | sort
  echo ""

} >"$USAGE_REPORT"

echo "📈 Generating summary report..."

# Create markdown summary
{
  echo "# ServerSentry Function Analysis Summary"
  echo ""
  echo "Generated: $(date)"
  echo ""

  # Count totals
  total_functions=$(grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | wc -l)
  core_functions=$(grep "lib/core" "$FUNCTIONS_LIST" | wc -l)
  plugin_functions=$(grep "plugins/" "$FUNCTIONS_LIST" | wc -l)
  ui_functions=$(grep "lib/ui" "$FUNCTIONS_LIST" | wc -l)
  notification_functions=$(grep "lib/notifications" "$FUNCTIONS_LIST" | wc -l)
  test_functions=$(grep "tests/" "$FUNCTIONS_LIST" | wc -l)

  echo "## Overview"
  echo ""
  echo "- **Total Functions:** $total_functions"
  echo "- **Core Functions:** $core_functions"
  echo "- **Plugin Functions:** $plugin_functions"
  echo "- **UI Functions:** $ui_functions"
  echo "- **Notification Functions:** $notification_functions"
  echo "- **Test Functions:** $test_functions"
  echo ""

  echo "## Top Files by Function Count"
  echo ""
  echo "| File | Function Count |"
  echo "|------|----------------|"

  # Count functions per file
  grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | cut -d'|' -f2 | sed 's/^ *//' | sort | uniq -c | sort -nr | head -20 | while read count file; do
    echo "| \`$file\` | $count |"
  done

  echo ""
  echo "## Function Types"
  echo ""
  echo "| Type | Count |"
  echo "|------|-------|"

  grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | cut -d'|' -f4 | sed 's/^ *//' | sort | uniq -c | while read count type; do
    echo "| $type | $count |"
  done

  echo ""
  echo "## Core Module Breakdown"
  echo ""

  for module in $(find ./lib/core -name "*.sh" -type f | sort); do
    count=$(grep "$module" "$FUNCTIONS_LIST" | wc -l)
    if [ "$count" -gt 0 ]; then
      echo "- **$(basename "$module")**: $count functions"
      grep "$module" "$FUNCTIONS_LIST" | cut -d'|' -f1 | sed 's/^ *//' | sed 's/^/  - /'
      echo ""
    fi
  done

  echo "## Recently Modified Functions"
  echo ""
  echo "Based on your recent refactoring, here are some key function patterns:"
  echo ""

  # Look for common patterns that might indicate recent changes
  echo "### Utility Functions (util_*)"
  grep "util_" "$FUNCTIONS_LIST" | cut -d'|' -f1 | sed 's/^ *//' | sort | sed 's/^/- /'
  echo ""

  echo "### Configuration Functions (*_config*)"
  grep "_config" "$FUNCTIONS_LIST" | cut -d'|' -f1 | sed 's/^ *//' | sort | sed 's/^/- /'
  echo ""

  echo "### Initialization Functions (*_init)"
  grep "_init" "$FUNCTIONS_LIST" | cut -d'|' -f1 | sed 's/^ *//' | sort | sed 's/^/- /'
  echo ""

  echo "### System Functions (*_system_*)"
  grep "_system_" "$FUNCTIONS_LIST" | cut -d'|' -f1 | sed 's/^ *//' | sort | sed 's/^/- /'
  echo ""

} >"$SUMMARY_REPORT"

echo "🔍 Finding potential issues..."

# Look for potential issues
{
  echo ""
  echo "## Potential Issues"
  echo ""

  echo "### Functions with Similar Names (Potential Duplicates)"
  grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | cut -d'|' -f1 | sed 's/^ *//' | sort | uniq -d | while read func; do
    echo "- **$func** appears multiple times:"
    grep "$func" "$FUNCTIONS_LIST" | sed 's/^/  - /'
  done

  echo ""
  echo "### Long Function Names (>30 chars)"
  grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | while IFS='|' read -r func file line type; do
    func_clean=$(echo "$func" | sed 's/^ *//')
    if [ ${#func_clean} -gt 30 ]; then
      echo "- \`$func_clean\` (${#func_clean} chars) in $file"
    fi
  done

} >>"$SUMMARY_REPORT"

echo ""
echo "✅ Analysis Complete!"
echo ""
echo "📄 Files Generated:"
echo "  📋 All Functions: $FUNCTIONS_LIST"
echo "  📊 Usage Report: $USAGE_REPORT"
echo "  📈 Summary: $SUMMARY_REPORT"
echo ""

# Show quick stats
total=$(grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | wc -l)
echo "📊 Quick Stats:"
echo "  Total Functions: $total"
echo "  Core Functions: $(grep "lib/core" "$FUNCTIONS_LIST" | wc -l)"
echo "  Plugin Functions: $(grep "plugins/" "$FUNCTIONS_LIST" | wc -l)"
echo "  Test Functions: $(grep "tests/" "$FUNCTIONS_LIST" | wc -l)"
echo ""

echo "🔍 Most Common Function Prefixes:"
grep -v "^#" "$FUNCTIONS_LIST" | grep -v "^$" | cut -d'|' -f1 | sed 's/^ *//' | sed 's/_.*$//' | sort | uniq -c | sort -nr | head -10 | while read count prefix; do
  echo "  $prefix*: $count functions"
done

echo ""
echo "📖 View detailed report: cat $SUMMARY_REPORT"
echo "🔍 Search functions: grep 'function_name' $FUNCTIONS_LIST"
