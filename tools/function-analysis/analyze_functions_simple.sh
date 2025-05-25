#!/usr/bin/env bash
#
# ServerSentry Function Analysis Script - Simple Version
#

echo "🔍 ServerSentry Function Analysis"
echo "=================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/logs"

# Output files in logs subdirectory
REPORT="$SCRIPT_DIR/logs/functions_report.md"
CSV="$SCRIPT_DIR/logs/functions_data.csv"

echo "📊 Analyzing functions across 76 shell files..."
echo ""

# Initialize files
echo "# ServerSentry Function Analysis Report" >"$REPORT"
echo "" >>"$REPORT"
echo "Generated: $(date)" >>"$REPORT"
echo "" >>"$REPORT"

echo "Function,File,Line,Type,Description" >"$CSV"

# Find all function definitions
echo "## Function Definitions" >>"$REPORT"
echo "" >>"$REPORT"
echo "| Function | File | Line | Type |" >>"$REPORT"
echo "|----------|------|------|------|" >>"$REPORT"

echo "📋 Extracting function definitions..."

# Pattern 1: function_name() {
find . -name "*.sh" -type f -exec grep -Hn "^[a-zA-Z_][a-zA-Z0-9_]*() {" {} \; | while IFS=: read -r file line func_def; do
  func_name=$(echo "$func_def" | sed 's/() {.*//')
  echo "| \`$func_name\` | \`$file\` | $line | Standard |" >>"$REPORT"
  echo "$func_name,$file,$line,standard,Function definition" >>"$CSV"
done

# Pattern 2: function function_name() {
find . -name "*.sh" -type f -exec grep -Hn "^function [a-zA-Z_][a-zA-Z0-9_]*() {" {} \; | while IFS=: read -r file line func_def; do
  func_name=$(echo "$func_def" | sed 's/^function //' | sed 's/() {.*//')
  echo "| \`$func_name\` | \`$file\` | $line | Function Keyword |" >>"$REPORT"
  echo "$func_name,$file,$line,function_keyword,Function definition with function keyword" >>"$CSV"
done

# Pattern 3: function function_name {
find . -name "*.sh" -type f -exec grep -Hn "^function [a-zA-Z_][a-zA-Z0-9_]* {" {} \; | while IFS=: read -r file line func_def; do
  func_name=$(echo "$func_def" | sed 's/^function //' | sed 's/ {.*//')
  echo "| \`$func_name\` | \`$file\` | $line | Function No Parens |" >>"$REPORT"
  echo "$func_name,$file,$line,function_no_parens,Function definition without parentheses" >>"$CSV"
done

echo ""
echo "📊 Generating usage statistics..."

# Create a temporary file with all function names
find . -name "*.sh" -type f -exec grep -H "^[a-zA-Z_][a-zA-Z0-9_]*() {" {} \; | sed 's/:.*() {.*//' | sed 's/.*\///' >/tmp/func_names.txt
find . -name "*.sh" -type f -exec grep -H "^function [a-zA-Z_][a-zA-Z0-9_]*" {} \; | sed 's/:.*function //' | sed 's/[() {].*//' >>/tmp/func_names.txt

echo "" >>"$REPORT"
echo "## Function Usage Analysis" >>"$REPORT"
echo "" >>"$REPORT"

# Count total functions
total_funcs=$(cat /tmp/func_names.txt | sort | uniq | wc -l)
echo "**Total Functions Found:** $total_funcs" >>"$REPORT"
echo "" >>"$REPORT"

# Find most used functions
echo "### Most Referenced Functions" >>"$REPORT"
echo "" >>"$REPORT"
echo "| Function | Usage Count | Files |" >>"$REPORT"
echo "|----------|-------------|-------|" >>"$REPORT"

# For each unique function, count its usage
cat /tmp/func_names.txt | sort | uniq | while read -r func_name; do
  if [[ -n "$func_name" ]]; then
    # Count occurrences across all files
    usage_count=$(find . -name "*.sh" -type f -exec grep -l "$func_name" {} \; | wc -l)
    files=$(find . -name "*.sh" -type f -exec grep -l "$func_name" {} \; | tr '\n' ' ')

    if [[ "$usage_count" -gt 1 ]]; then
      echo "| \`$func_name\` | $usage_count | \`$files\` |" >>"$REPORT"
    fi
  fi
done

echo "" >>"$REPORT"
echo "## Files by Function Count" >>"$REPORT"
echo "" >>"$REPORT"
echo "| File | Function Count |" >>"$REPORT"
echo "|------|----------------|" >>"$REPORT"

# Count functions per file
find . -name "*.sh" -type f | while read -r file; do
  func_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$file" 2>/dev/null || echo 0)
  func_count2=$(grep -c "^function [a-zA-Z_]" "$file" 2>/dev/null || echo 0)
  total_count=$((func_count + func_count2))

  if [[ "$total_count" -gt 0 ]]; then
    echo "| \`$file\` | $total_count |" >>"$REPORT"
  fi
done

# Generate some quick stats
echo "" >>"$REPORT"
echo "## Quick Statistics" >>"$REPORT"
echo "" >>"$REPORT"

# Core modules with most functions
echo "### Core Modules (Top Function Counts)" >>"$REPORT"
echo "" >>"$REPORT"
find ./lib/core -name "*.sh" -type f 2>/dev/null | while read -r file; do
  func_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$file" 2>/dev/null || echo 0)
  func_count2=$(grep -c "^function [a-zA-Z_]" "$file" 2>/dev/null || echo 0)
  total_count=$((func_count + func_count2))

  if [[ "$total_count" -gt 0 ]]; then
    echo "- \`$(basename "$file")\`: $total_count functions"
  fi
done >>"$REPORT"

echo "" >>"$REPORT"
echo "### Plugin Files" >>"$REPORT"
echo "" >>"$REPORT"
find ./plugins -name "*.sh" -type f 2>/dev/null | while read -r file; do
  func_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$file" 2>/dev/null || echo 0)
  func_count2=$(grep -c "^function [a-zA-Z_]" "$file" 2>/dev/null || echo 0)
  total_count=$((func_count + func_count2))

  if [[ "$total_count" -gt 0 ]]; then
    echo "- \`$(basename "$file")\`: $total_count functions"
  fi
done >>"$REPORT"

# Cleanup
rm -f /tmp/func_names.txt

echo "✅ Analysis Complete!"
echo ""
echo "📄 Reports Generated:"
echo "  📋 Markdown Report: $REPORT"
echo "  📊 CSV Data: $CSV"
echo ""
echo "📊 Summary:"
echo "  Total Functions: $total_funcs"
echo "  Report Size: $(wc -l <"$REPORT") lines"
echo "  CSV Records: $(wc -l <"$CSV") records"
echo ""
echo "🔍 View the report: cat $REPORT"
echo "📈 Open CSV in spreadsheet: open $CSV"
