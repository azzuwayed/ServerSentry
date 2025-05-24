#!/bin/bash
#
# ServerSentry Codebase Analysis Tool
# Analyzes the current codebase structure to help prepare for v2 refactoring
#
# This script will:
# 1. Map the directory structure
# 2. Count lines of code by file type
# 3. Identify dependencies between modules
# 4. Find potential code smells
# 5. Generate a report for refactoring planning

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"

# Create output directory
REPORT_DIR="$PROJECT_ROOT/docs/refactoring_analysis"
mkdir -p "$REPORT_DIR"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}ServerSentry Codebase Analysis Tool${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""
echo "Project root: $PROJECT_ROOT"
echo "Report directory: $REPORT_DIR"
echo ""

# Check for required tools
for cmd in find grep wc sed awk; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error: Required command '$cmd' not found.${NC}"
    exit 1
  fi
done

# Function to print section header
print_section() {
  echo -e "\n${BLUE}$1${NC}"
  echo -e "${CYAN}$(printf '%.0s-' {1..50})${NC}"
}

# 1. Map directory structure
print_section "Mapping Directory Structure"
echo "Generating directory tree..."
{
  echo "# Directory Structure"
  echo '```'
  find "$PROJECT_ROOT" -type d -not -path "*/\.*" | sort | sed -e "s|$PROJECT_ROOT|.|" -e 's/[^-][^\/]*\//--/g' -e 's/^.\///'
  echo '```'
} >"$REPORT_DIR/directory_structure.md"
echo -e "${GREEN}✓${NC} Directory structure map saved to $REPORT_DIR/directory_structure.md"

# 2. Count lines of code by file type
print_section "Counting Lines of Code"
echo "Counting lines by file type..."
{
  echo "# Lines of Code by File Type"
  echo ""
  echo "| File Type | Files | Lines | Average |"
  echo "|-----------|-------|-------|---------|"

  # Count for shell scripts
  shell_files=$(find "$PROJECT_ROOT" -name "*.sh" -type f | wc -l)
  shell_lines=$(find "$PROJECT_ROOT" -name "*.sh" -type f -exec wc -l {} \; | awk '{total += $1} END {print total}')
  shell_avg=$((shell_lines / shell_files))
  echo "| Shell Scripts (.sh) | $shell_files | $shell_lines | $shell_avg |"

  # Count for markdown files
  md_files=$(find "$PROJECT_ROOT" -name "*.md" -type f | wc -l)
  md_lines=$(find "$PROJECT_ROOT" -name "*.md" -type f -exec wc -l {} \; | awk '{total += $1} END {print total}')
  md_avg=$((md_lines / md_files))
  echo "| Documentation (.md) | $md_files | $md_lines | $md_avg |"

  # Count for configuration files
  conf_files=$(find "$PROJECT_ROOT" -name "*.conf" -type f | wc -l)
  conf_lines=$(find "$PROJECT_ROOT" -name "*.conf" -type f -exec wc -l {} \; | awk '{total += $1} END {print total}')
  conf_avg=$((conf_lines / conf_files))
  echo "| Configuration (.conf) | $conf_files | $conf_lines | $conf_avg |"

  # Count for other files
  other_files=$(find "$PROJECT_ROOT" -type f -not -path "*/\.*" -not -name "*.sh" -not -name "*.md" -not -name "*.conf" | wc -l)
  other_lines=$(find "$PROJECT_ROOT" -type f -not -path "*/\.*" -not -name "*.sh" -not -name "*.md" -not -name "*.conf" -exec wc -l {} \; 2>/dev/null | awk '{total += $1} END {print total}')
  other_avg=$((other_lines / other_files))
  echo "| Other Files | $other_files | $other_lines | $other_avg |"

  # Total
  total_files=$((shell_files + md_files + conf_files + other_files))
  total_lines=$((shell_lines + md_lines + conf_lines + other_lines))
  total_avg=$((total_lines / total_files))
  echo "| **TOTAL** | **$total_files** | **$total_lines** | **$total_avg** |"
} >"$REPORT_DIR/lines_of_code.md"
echo -e "${GREEN}✓${NC} Lines of code analysis saved to $REPORT_DIR/lines_of_code.md"

# 3. Identify dependencies between modules
print_section "Analyzing Module Dependencies"
echo "Mapping source statements between files..."
{
  echo "# Module Dependencies"
  echo ""
  echo "This shows which files are sourced by other files, creating a dependency graph."
  echo ""
  echo "| File | Dependencies |"
  echo "|------|--------------|"

  find "$PROJECT_ROOT" -name "*.sh" -type f | sort | while read -r file; do
    rel_file=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    deps=$(grep -E "^\s*source" "$file" | sed 's/source\s*//' | tr -d '"' | tr -d "'" | sed 's/\$[A-Za-z_][A-Za-z0-9_]*\///' | sed 's/\$([^)]*)//g' | sort | uniq | tr '\n' ',' | sed 's/,$//')
    echo "| $rel_file | $deps |"
  done
} >"$REPORT_DIR/module_dependencies.md"
echo -e "${GREEN}✓${NC} Module dependencies saved to $REPORT_DIR/module_dependencies.md"

# 4. Find potential code smells
print_section "Identifying Potential Code Smells"
echo "Scanning for potential issues..."
{
  echo "# Potential Code Smells"
  echo ""
  echo "## Long Functions"
  echo "Functions with more than 50 lines:"
  echo ""
  echo "| File | Function | Lines |"
  echo "|------|----------|-------|"

  find "$PROJECT_ROOT" -name "*.sh" -type f | sort | while read -r file; do
    rel_file=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    awk '/^[a-zA-Z0-9_]+\(\)/ {name=$1; start=NR} /^}/ {if (name && NR-start > 50) printf "| %s | %s | %d |\n", "'"$rel_file"'", name, NR-start; name=""}' "$file"
  done

  echo ""
  echo "## Hardcoded Values"
  echo "Files with potentially hardcoded configuration values:"
  echo ""
  echo "| File | Line | Content |"
  echo "|------|------|---------|"

  find "$PROJECT_ROOT" -name "*.sh" -type f | sort | while read -r file; do
    rel_file=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    grep -n -E '(threshold|interval|timeout|retries|max_|min_)[[:space:]]*=[[:space:]]*[0-9]+' "$file" | head -5 | while IFS=: read -r line_num line_content; do
      echo "| $rel_file | $line_num | $line_content |"
    done
  done

  echo ""
  echo "## Global Variables"
  echo "Files with many global variables (uppercase variables):"
  echo ""
  echo "| File | Global Variables Count |"
  echo "|------|------------------------|"

  find "$PROJECT_ROOT" -name "*.sh" -type f | sort | while read -r file; do
    rel_file=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    count=$(grep -E '^[A-Z_]+=.+' "$file" | wc -l)
    if [ "$count" -gt 5 ]; then
      echo "| $rel_file | $count |"
    fi
  done

  echo ""
  echo "## Error Handling"
  echo "Files that may need improved error handling:"
  echo ""
  echo "| File | Line | Issue |"
  echo "|------|------|-------|"

  find "$PROJECT_ROOT" -name "*.sh" -type f | sort | while read -r file; do
    rel_file=$(echo "$file" | sed "s|$PROJECT_ROOT/||")
    grep -n -E 'command [^|&;]+ [^|&;]+$' "$file" | head -5 | while IFS=: read -r line_num line_content; do
      echo "| $rel_file | $line_num | Command without error check: \`$line_content\` |"
    done
  done
} >"$REPORT_DIR/code_smells.md"
echo -e "${GREEN}✓${NC} Code smell analysis saved to $REPORT_DIR/code_smells.md"

# 5. Generate a summary report
print_section "Generating Summary Report"
{
  echo "# ServerSentry Codebase Analysis Summary"
  echo ""
  echo "Analysis Date: $(date)"
  echo ""
  echo "## Overview"
  echo ""
  echo "- **Total Files:** $total_files"
  echo "- **Total Lines of Code:** $total_lines"
  echo "- **Shell Script Files:** $shell_files"
  echo "- **Shell Script Lines:** $shell_lines"
  echo ""
  echo "## Key Findings"
  echo ""
  echo "1. **Directory Structure**: The project has $(find "$PROJECT_ROOT" -type d -not -path "*/\.*" | wc -l) directories."
  echo "2. **Module Dependencies**: Found $(grep -r "source " "$PROJECT_ROOT" --include="*.sh" | wc -l) source statements across the codebase."
  echo "3. **Code Smells**: Identified potentially long functions, hardcoded values, and error handling issues."
  echo ""
  echo "## Recommendations for v2 Refactoring"
  echo ""
  echo "1. **Modularization**: Break down large files and functions into smaller, more focused components."
  echo "2. **Configuration Management**: Replace hardcoded values with a centralized configuration system."
  echo "3. **Error Handling**: Implement consistent error handling throughout the codebase."
  echo "4. **Testing**: Add unit tests for core functionality."
  echo "5. **Documentation**: Improve inline documentation and create comprehensive API references."
  echo ""
  echo "## Next Steps"
  echo ""
  echo "1. Review the detailed reports in the refactoring_analysis directory."
  echo "2. Prioritize areas for refactoring based on complexity and impact."
  echo "3. Create a detailed implementation plan for each component."
  echo "4. Set up a development environment for v2 with proper testing infrastructure."
  echo ""
  echo "See the V2_REFACTORING_PLAN.md document for the complete refactoring strategy."
} >"$REPORT_DIR/summary.md"
echo -e "${GREEN}✓${NC} Summary report saved to $REPORT_DIR/summary.md"

# Create a sample plugin to demonstrate the new architecture
print_section "Creating Sample Plugin Architecture"
SAMPLE_DIR="$PROJECT_ROOT/examples/v2_plugin_sample"
mkdir -p "$SAMPLE_DIR/plugins/cpu"
mkdir -p "$SAMPLE_DIR/core"

# Create sample plugin interface
{
  echo '#!/bin/bash'
  echo '#'
  echo '# ServerSentry v2 - Plugin Interface'
  echo '#'
  echo '# This file defines the standard interface that all plugins must implement'
  echo ''
  echo '# Every plugin must implement these functions:'
  echo '#'
  echo '# plugin_info() - Returns basic information about the plugin'
  echo '# plugin_check() - Performs the actual check and returns results'
  echo '# plugin_configure() - Configures the plugin with provided settings'
  echo ''
  echo 'plugin_interface_version="1.0"'
  echo ''
  echo '# Ensure plugins implement required functions'
  echo 'validate_plugin() {'
  echo '  local plugin_name="$1"'
  echo '  local required_functions=("plugin_info" "plugin_check" "plugin_configure")'
  echo '  '
  echo '  for func in "${required_functions[@]}"; do'
  echo '    if ! declare -f "${plugin_name}_${func}" > /dev/null; then'
  echo '      echo "Error: Plugin $plugin_name does not implement required function: $func"'
  echo '      return 1'
  echo '    fi'
  echo '  done'
  echo '  '
  echo '  return 0'
  echo '}'
  echo ''
  echo '# Register a plugin with the core system'
  echo 'register_plugin() {'
  echo '  local plugin_name="$1"'
  echo '  '
  echo '  # Validate plugin interface'
  echo '  validate_plugin "$plugin_name" || return 1'
  echo '  '
  echo '  # Get plugin info'
  echo '  local plugin_info'
  echo '  plugin_info=$(${plugin_name}_plugin_info)'
  echo '  '
  echo '  # Add to registered plugins'
  echo '  registered_plugins+=("$plugin_name")'
  echo '  '
  echo '  echo "Plugin registered: $plugin_name - $plugin_info"'
  echo '  return 0'
  echo '}'
} >"$SAMPLE_DIR/core/plugin_interface.sh"

# Create sample CPU plugin
{
  echo '#!/bin/bash'
  echo '#'
  echo '# ServerSentry v2 - CPU Monitoring Plugin'
  echo '#'
  echo '# This plugin monitors CPU usage and alerts when thresholds are exceeded'
  echo ''
  echo '# Plugin metadata'
  echo 'cpu_plugin_name="cpu"'
  echo 'cpu_plugin_version="1.0"'
  echo 'cpu_plugin_description="Monitors CPU usage and performance"'
  echo 'cpu_plugin_author="ServerSentry Team"'
  echo ''
  echo '# Default configuration'
  echo 'cpu_threshold=80'
  echo 'cpu_warning_threshold=70'
  echo 'cpu_check_interval=60'
  echo 'cpu_include_iowait=true'
  echo ''
  echo '# Return plugin information'
  echo 'cpu_plugin_info() {'
  echo '  echo "CPU Monitoring Plugin v${cpu_plugin_version}"'
  echo '}'
  echo ''
  echo '# Configure the plugin'
  echo 'cpu_plugin_configure() {'
  echo '  local config_file="$1"'
  echo '  '
  echo '  # Load configuration if file exists'
  echo '  if [ -f "$config_file" ]; then'
  echo '    source "$config_file"'
  echo '  fi'
  echo '  '
  echo '  # Validate configuration'
  echo '  if ! [[ "$cpu_threshold" =~ ^[0-9]+$ ]] || [ "$cpu_threshold" -gt 100 ]; then'
  echo '    echo "Error: Invalid CPU threshold: $cpu_threshold (must be 0-100)"'
  echo '    return 1'
  echo '  fi'
  echo '  '
  echo '  return 0'
  echo '}'
  echo ''
  echo '# Perform CPU check'
  echo 'cpu_plugin_check() {'
  echo '  local result'
  echo '  local status_code=0'
  echo '  local status_message="OK"'
  echo '  '
  echo '  # Get CPU usage (this is a simplified example)'
  echo '  if command -v top >/dev/null 2>&1; then'
  echo '    # Linux-style'
  echo '    result=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '\''{print 100 - $1}'\'')'
  echo '  elif command -v vm_stat >/dev/null 2>&1; then'
  echo '    # macOS-style'
  echo '    result=$(top -l 1 | grep "CPU usage" | awk '\''{print $3}'\'' | tr -d "%")'
  echo '  else'
  echo '    result="unknown"'
  echo '    status_code=3'
  echo '    status_message="Cannot determine CPU usage on this system"'
  echo '  fi'
  echo '  '
  echo '  # Check thresholds if we got a result'
  echo '  if [[ "$result" =~ ^[0-9.]+$ ]]; then'
  echo '    result=$(printf "%.1f" "$result")'
  echo '    '
  echo '    if (( $(echo "$result >= $cpu_threshold" | bc -l) )); then'
  echo '      status_code=2'
  echo '      status_message="CRITICAL: CPU usage is ${result}%, threshold: ${cpu_threshold}%"'
  echo '    elif (( $(echo "$result >= $cpu_warning_threshold" | bc -l) )); then'
  echo '      status_code=1'
  echo '      status_message="WARNING: CPU usage is ${result}%, threshold: ${cpu_warning_threshold}%"'
  echo '    else'
  echo '      status_message="OK: CPU usage is ${result}%"'
  echo '    fi'
  echo '  fi'
  echo '  '
  echo '  # Return standardized output format'
  echo '  cat <<EOF'
  echo '{'
  echo '  "plugin": "cpu",'
  echo '  "status_code": '"$status_code"','
  echo '  "status_message": "'"$status_message"'",'
  echo '  "metrics": {'
  echo '    "usage_percent": '"$result"','
  echo '    "threshold": '"$cpu_threshold"','
  echo '    "warning_threshold": '"$cpu_warning_threshold"''
  echo '  },'
  echo '  "timestamp": "'$(date +%s)'"'
  echo '}'
  echo 'EOF'
  echo '}'
} >"$SAMPLE_DIR/plugins/cpu/cpu.sh"

# Create sample plugin configuration
{
  echo '# CPU Plugin Configuration'
  echo ''
  echo '# Alert threshold (percentage)'
  echo 'cpu_threshold=85'
  echo ''
  echo '# Warning threshold (percentage)'
  echo 'cpu_warning_threshold=75'
  echo ''
  echo '# Check interval in seconds'
  echo 'cpu_check_interval=30'
  echo ''
  echo '# Whether to include I/O wait in CPU usage calculation'
  echo 'cpu_include_iowait=true'
} >"$SAMPLE_DIR/plugins/cpu/config.conf"

# Create sample main script
{
  echo '#!/bin/bash'
  echo '#'
  echo '# ServerSentry v2 - Sample Plugin Demo'
  echo '#'
  echo '# This demonstrates how the plugin architecture works'
  echo ''
  echo '# Get the directory where the script is located'
  echo 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"'
  echo ''
  echo '# Source the plugin interface'
  echo 'source "$SCRIPT_DIR/core/plugin_interface.sh"'
  echo ''
  echo '# Initialize plugin registry'
  echo 'declare -a registered_plugins'
  echo ''
  echo '# Load and register the CPU plugin'
  echo 'source "$SCRIPT_DIR/plugins/cpu/cpu.sh"'
  echo 'register_plugin "cpu"'
  echo ''
  echo '# Configure the plugin'
  echo 'cpu_plugin_configure "$SCRIPT_DIR/plugins/cpu/config.conf"'
  echo ''
  echo '# Run the plugin check'
  echo 'echo "Running CPU plugin check..."'
  echo 'result=$(cpu_plugin_check)'
  echo ''
  echo '# Display the result'
  echo 'echo "Plugin result:"'
  echo 'echo "$result" | jq'
} >"$SAMPLE_DIR/demo.sh"
chmod +x "$SAMPLE_DIR/demo.sh"

echo -e "${GREEN}✓${NC} Sample plugin architecture created in $SAMPLE_DIR"
echo -e "  Run ${CYAN}$SAMPLE_DIR/demo.sh${NC} to see the plugin system in action"

print_section "Analysis Complete"
echo -e "${GREEN}Codebase analysis complete!${NC}"
echo ""
echo "Reports saved to: $REPORT_DIR/"
echo "Sample v2 plugin architecture created in: $SAMPLE_DIR/"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review the analysis reports"
echo "2. Explore the sample plugin architecture"
echo "3. Begin implementing the v2 refactoring plan"
echo ""
echo -e "${CYAN}Happy refactoring!${NC}"
