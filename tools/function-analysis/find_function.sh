#!/usr/bin/env bash
#
# Quick Function Finder for ServerSentry
#

if [ $# -eq 0 ]; then
  echo "🔍 ServerSentry Function Finder"
  echo "Usage: $0 <search_term>"
  echo ""
  echo "Examples:"
  echo "  $0 config          # Find all config-related functions"
  echo "  $0 util_           # Find all utility functions"
  echo "  $0 init            # Find all initialization functions"
  echo "  $0 logging.sh      # Find all functions in logging.sh"
  echo ""
  exit 1
fi

search_term="$1"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_FILE="$SCRIPT_DIR/logs/all_functions.txt"

if [ ! -f "$FUNCTIONS_FILE" ]; then
  echo "❌ Function list not found. Run extract_functions.sh first"
  exit 1
fi

echo "🔍 Searching for functions matching: '$search_term'"
echo "=================================================="

# Search in function names and files
matches=$(grep -i "$search_term" "$FUNCTIONS_FILE" | grep -v "^#")

if [ -z "$matches" ]; then
  echo "❌ No functions found matching '$search_term'"
  echo ""
  echo "💡 Try a broader search or check these common patterns:"
  echo "  - util_*"
  echo "  - *_init"
  echo "  - *_config*"
  echo "  - *_system_*"
  echo "  - logging*"
  exit 1
fi

count=$(echo "$matches" | wc -l)
echo "✅ Found $count matching functions:"
echo ""

# Format output nicely
echo "$matches" | while IFS='|' read -r func_name file line type; do
  # Clean up whitespace
  func_name=$(echo "$func_name" | sed 's/^ *//')
  file=$(echo "$file" | sed 's/^ *//')
  line=$(echo "$line" | sed 's/^ *//')
  type=$(echo "$type" | sed 's/^ *//')

  echo "📋 $func_name"
  echo "   📁 File: $file"
  echo "   📍 Line: $line"
  echo "   🏷️  Type: $type"
  echo ""
done

echo "💡 To view a function:"
echo "   grep -A 10 'function_name()' filename.sh"
