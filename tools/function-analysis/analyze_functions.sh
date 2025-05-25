#!/usr/bin/env bash
#
# ServerSentry Function Analysis Script
# Extracts all function definitions and their usage across the codebase
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create logs directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/logs"

# Output files in logs subdirectory
FUNCTIONS_REPORT="$SCRIPT_DIR/logs/functions_analysis_report.md"
FUNCTIONS_JSON="$SCRIPT_DIR/logs/functions_analysis.json"
FUNCTIONS_CSV="$SCRIPT_DIR/logs/functions_analysis.csv"

echo -e "${BLUE}🔍 ServerSentry Function Analysis${NC}"
echo "=================================="
echo ""

# Initialize report
cat >"$FUNCTIONS_REPORT" <<'EOF'
# ServerSentry Function Analysis Report

Generated on: $(date)

## Table of Contents
1. [Summary](#summary)
2. [Function Definitions](#function-definitions)
3. [Function Usage](#function-usage)
4. [Orphaned Functions](#orphaned-functions)
5. [Missing Functions](#missing-functions)
6. [Function Dependencies](#function-dependencies)

EOF

# Initialize JSON
echo '{"analysis_date": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "functions": {}, "usage": {}, "summary": {}}' >"$FUNCTIONS_JSON"

# Initialize CSV
echo "Function,File,Line,Type,Usage_Count,Called_In_Files" >"$FUNCTIONS_CSV"

echo -e "${YELLOW}📊 Step 1: Extracting function definitions...${NC}"

# Find all function definitions
declare -A functions
declare -A function_files
declare -A function_lines

# Extract function definitions with multiple patterns
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    # Pattern 1: function_name() {
    grep -n "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$file" 2>/dev/null | while IFS=: read -r line_num func_line; do
      func_name=$(echo "$func_line" | sed 's/() {.*//')
      echo "DEF|$func_name|$file|$line_num"
    done

    # Pattern 2: function function_name() {
    grep -n "^function [a-zA-Z_][a-zA-Z0-9_]*() {" "$file" 2>/dev/null | while IFS=: read -r line_num func_line; do
      func_name=$(echo "$func_line" | sed 's/^function //' | sed 's/() {.*//')
      echo "DEF|$func_name|$file|$line_num"
    done

    # Pattern 3: function function_name {
    grep -n "^function [a-zA-Z_][a-zA-Z0-9_]* {" "$file" 2>/dev/null | while IFS=: read -r line_num func_line; do
      func_name=$(echo "$func_line" | sed 's/^function //' | sed 's/ {.*//')
      echo "DEF|$func_name|$file|$line_num"
    done
  fi
done < <(find . -name "*.sh" -type f) >/tmp/function_definitions.txt

echo -e "${YELLOW}📊 Step 2: Extracting function usage...${NC}"

# Extract function calls
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    # Find function calls (function_name followed by space or parentheses)
    grep -n "[a-zA-Z_][a-zA-Z0-9_]*(" "$file" 2>/dev/null | while IFS=: read -r line_num func_line; do
      # Extract all potential function calls from the line
      echo "$func_line" | grep -o "[a-zA-Z_][a-zA-Z0-9_]*(" | sed 's/($//' | while read -r func_name; do
        # Skip common bash keywords and operators
        if [[ ! "$func_name" =~ ^(if|then|else|elif|fi|for|while|do|done|case|esac|function|local|export|declare|readonly|unset|shift|return|exit|break|continue|test|echo|printf|read|cat|grep|sed|awk|sort|uniq|head|tail|cut|tr|wc|find|xargs)$ ]]; then
          echo "USAGE|$func_name|$file|$line_num"
        fi
      done
    done
  fi
done < <(find . -name "*.sh" -type f) >/tmp/function_usage.txt

echo -e "${YELLOW}📊 Step 3: Processing data...${NC}"

# Process definitions
declare -A all_functions
declare -A function_def_files
declare -A function_def_lines

while IFS='|' read -r type func_name file line_num; do
  if [[ "$type" == "DEF" ]]; then
    all_functions["$func_name"]=1
    function_def_files["$func_name"]="$file"
    function_def_lines["$func_name"]="$line_num"
  fi
done </tmp/function_definitions.txt

# Process usage
declare -A function_usage_count
declare -A function_usage_files

while IFS='|' read -r type func_name file line_num; do
  if [[ "$type" == "USAGE" ]]; then
    if [[ -n "${all_functions[$func_name]:-}" ]]; then
      ((function_usage_count["$func_name"]++)) || function_usage_count["$func_name"]=1
      function_usage_files["$func_name"]+="$file:$line_num "
    fi
  fi
done </tmp/function_usage.txt

echo -e "${YELLOW}📊 Step 4: Generating reports...${NC}"

# Generate summary
total_functions=${#all_functions[@]}
used_functions=0
unused_functions=0

for func in "${!all_functions[@]}"; do
  if [[ "${function_usage_count[$func]:-0}" -gt 0 ]]; then
    ((used_functions++))
  else
    ((unused_functions++))
  fi
done

# Add summary to report
cat >>"$FUNCTIONS_REPORT" <<EOF

## Summary

- **Total Functions Defined:** $total_functions
- **Functions Used:** $used_functions
- **Unused Functions:** $unused_functions
- **Usage Rate:** $((used_functions * 100 / total_functions))%

EOF

# Generate detailed function list
echo "## Function Definitions" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"
echo "| Function Name | File | Line | Usage Count | Status |" >>"$FUNCTIONS_REPORT"
echo "|---------------|------|------|-------------|--------|" >>"$FUNCTIONS_REPORT"

for func in $(printf '%s\n' "${!all_functions[@]}" | sort); do
  file="${function_def_files[$func]}"
  line="${function_def_lines[$func]}"
  usage_count="${function_usage_count[$func]:-0}"

  if [[ "$usage_count" -eq 0 ]]; then
    status="🔴 Unused"
  elif [[ "$usage_count" -eq 1 ]]; then
    status="🟡 Low Usage"
  elif [[ "$usage_count" -le 5 ]]; then
    status="🟢 Normal"
  else
    status="🔥 High Usage"
  fi

  echo "| \`$func\` | \`$file\` | $line | $usage_count | $status |" >>"$FUNCTIONS_REPORT"

  # Add to CSV
  usage_files="${function_usage_files[$func]:-}"
  echo "$func,$file,$line,definition,$usage_count,\"$usage_files\"" >>"$FUNCTIONS_CSV"
done

# Generate unused functions section
echo "" >>"$FUNCTIONS_REPORT"
echo "## Orphaned Functions" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"
echo "Functions that are defined but never called:" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"

orphaned_count=0
for func in $(printf '%s\n' "${!all_functions[@]}" | sort); do
  if [[ "${function_usage_count[$func]:-0}" -eq 0 ]]; then
    file="${function_def_files[$func]}"
    line="${function_def_lines[$func]}"
    echo "- \`$func\` in \`$file\` (line $line)" >>"$FUNCTIONS_REPORT"
    ((orphaned_count++))
  fi
done

if [[ "$orphaned_count" -eq 0 ]]; then
  echo "✅ No orphaned functions found!" >>"$FUNCTIONS_REPORT"
fi

# Find potentially missing functions (called but not defined)
echo "" >>"$FUNCTIONS_REPORT"
echo "## Missing Functions" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"
echo "Functions that are called but not defined in the codebase:" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"

declare -A called_functions
while IFS='|' read -r type func_name file line_num; do
  if [[ "$type" == "USAGE" ]]; then
    called_functions["$func_name"]=1
  fi
done </tmp/function_usage.txt

missing_count=0
for func in $(printf '%s\n' "${!called_functions[@]}" | sort); do
  if [[ -z "${all_functions[$func]:-}" ]]; then
    echo "- \`$func\` (called but not defined)" >>"$FUNCTIONS_REPORT"
    ((missing_count++))
  fi
done

if [[ "$missing_count" -eq 0 ]]; then
  echo "✅ No missing functions found!" >>"$FUNCTIONS_REPORT"
fi

# Generate function dependencies
echo "" >>"$FUNCTIONS_REPORT"
echo "## Function Dependencies" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"
echo "Functions and what they call:" >>"$FUNCTIONS_REPORT"
echo "" >>"$FUNCTIONS_REPORT"

for func in $(printf '%s\n' "${!all_functions[@]}" | sort); do
  file="${function_def_files[$func]}"

  # Find what functions this function calls
  if [[ -f "$file" ]]; then
    start_line="${function_def_lines[$func]}"

    # Find the end of the function (next function or end of file)
    end_line=$(awk -v start="$start_line" '
            NR > start && /^[a-zA-Z_][a-zA-Z0-9_]*\(\) \{|^function [a-zA-Z_]/ { print NR-1; exit }
            END { if (NR >= start) print NR }
        ' "$file")

    # Extract function calls within this function
    calls=$(sed -n "${start_line},${end_line}p" "$file" |
      grep -o "[a-zA-Z_][a-zA-Z0-9_]*(" |
      sed 's/($//' |
      grep -v "^$func$" |
      sort | uniq |
      while read -r called_func; do
        if [[ -n "${all_functions[$called_func]:-}" ]]; then
          echo "$called_func"
        fi
      done | tr '\n' ' ')

    if [[ -n "$calls" ]]; then
      echo "- \`$func\` calls: $calls" >>"$FUNCTIONS_REPORT"
    fi
  fi
done

# Generate JSON report
cat >"$FUNCTIONS_JSON" <<EOF
{
  "analysis_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_functions": $total_functions,
    "used_functions": $used_functions,
    "unused_functions": $unused_functions,
    "missing_functions": $missing_count,
    "usage_rate_percent": $((used_functions * 100 / total_functions))
  },
  "functions": {
EOF

first=true
for func in $(printf '%s\n' "${!all_functions[@]}" | sort); do
  if [[ "$first" == "true" ]]; then
    first=false
  else
    echo "," >>"$FUNCTIONS_JSON"
  fi

  file="${function_def_files[$func]}"
  line="${function_def_lines[$func]}"
  usage_count="${function_usage_count[$func]:-0}"

  cat >>"$FUNCTIONS_JSON" <<EOF
    "$func": {
      "file": "$file",
      "line": $line,
      "usage_count": $usage_count,
      "status": "$(if [[ "$usage_count" -eq 0 ]]; then echo "unused"; elif [[ "$usage_count" -eq 1 ]]; then echo "low_usage"; elif [[ "$usage_count" -le 5 ]]; then echo "normal"; else echo "high_usage"; fi)"
    }
EOF
done

echo "" >>"$FUNCTIONS_JSON"
echo "  }" >>"$FUNCTIONS_JSON"
echo "}" >>"$FUNCTIONS_JSON"

# Cleanup
rm -f /tmp/function_definitions.txt /tmp/function_usage.txt

echo ""
echo -e "${GREEN}✅ Analysis Complete!${NC}"
echo ""
echo -e "${CYAN}📄 Reports Generated:${NC}"
echo "  📋 Markdown Report: $FUNCTIONS_REPORT"
echo "  📊 JSON Data: $FUNCTIONS_JSON"
echo "  📈 CSV Data: $FUNCTIONS_CSV"
echo ""
echo -e "${PURPLE}📊 Summary:${NC}"
echo "  Total Functions: $total_functions"
echo "  Used Functions: $used_functions"
echo "  Unused Functions: $unused_functions"
echo "  Missing Functions: $missing_count"
echo "  Usage Rate: $((used_functions * 100 / total_functions))%"
echo ""

if [[ "$unused_functions" -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Found $unused_functions unused functions - consider reviewing for cleanup${NC}"
fi

if [[ "$missing_count" -gt 0 ]]; then
  echo -e "${RED}❌ Found $missing_count missing functions - these may cause runtime errors${NC}"
fi

echo ""
echo -e "${BLUE}🔍 View the detailed report: cat $FUNCTIONS_REPORT${NC}"
