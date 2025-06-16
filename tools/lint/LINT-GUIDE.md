# ServerSentry Bash Linting Guide v3.0

A comprehensive guide for maintaining high-quality bash scripts in the ServerSentry project using modern tools and best practices.

## 🎯 Quick Start

```bash
# Check all scripts for issues
./check-lint.sh

# Fix issues automatically
./fix-lint.sh

# Dry run to see what would be fixed
./fix-lint.sh --dry-run

# Rollback changes if needed
./fix-lint.sh --rollback
```

## 📋 Table of Contents

- [Tools Overview](#tools-overview)
- [Quick Commands](#quick-commands)
- [Advanced Usage](#advanced-usage)
- [Configuration](#configuration)
- [VS Code Integration](#vs-code-integration)
- [Common Issues & Fixes](#common-issues--fixes)
- [Best Practices](#best-practices)
- [Workflow Guidelines](#workflow-guidelines)
- [Troubleshooting](#troubleshooting)

## 🛠 Tools Overview

### Primary Tools

| Tool           | Purpose                   | Version | Installation              |
| -------------- | ------------------------- | ------- | ------------------------- |
| **ShellCheck** | Static analysis & linting | Latest  | `brew install shellcheck` |
| **shfmt**      | Code formatting           | Latest  | `brew install shfmt`      |

### Our Enhanced Scripts

| Script          | Purpose              | Features                                    |
| --------------- | -------------------- | ------------------------------------------- |
| `check-lint.sh` | Analysis & reporting | JSON output, filtering, performance metrics |
| `fix-lint.sh`   | Automatic fixing     | Smart fixes, backups, rollback, dry-run     |
| `.shellcheckrc` | Configuration        | Project-specific settings                   |

## ⚡ Quick Commands

### Basic Operations

```bash
# Analyze all bash files
./check-lint.sh

# Fix all issues automatically
./fix-lint.sh

# Check with verbose output
./check-lint.sh --verbose

# Preview fixes without applying
./fix-lint.sh --dry-run
```

### Filtering & Targeting

```bash
# Show only errors
./check-lint.sh --filter error

# Fix only formatting issues
./fix-lint.sh --fix formatting

# Exclude test files
./check-lint.sh --exclude "test*"

# Process specific files
./fix-lint.sh script1.sh script2.sh
```

### Export & Reporting

```bash
# Export JSON report
./check-lint.sh --json --output report.json

# Show performance metrics
./check-lint.sh --performance

# Quick summary only
./check-lint.sh --summary --quiet
```

## 🔧 Advanced Usage

### Check Script Advanced Options

```bash
# Comprehensive analysis with metrics
./check-lint.sh --verbose --performance --json --output analysis.json

# Filter by severity level (show warnings and above)
./check-lint.sh --min-severity warning

# Complex filtering
./check-lint.sh --filter error --exclude "backup*" --exclude "tmp*"

# CI/CD integration
./check-lint.sh --json --quiet && echo "All clean!" || echo "Issues found"
```

### Fix Script Advanced Options

```bash
# Selective fixing
./fix-lint.sh --fix formatting --fix quotes --verbose

# Safety features
./fix-lint.sh --dry-run --verbose  # Preview changes
./fix-lint.sh --no-backup         # Skip backups (dangerous!)
./fix-lint.sh --backup-dir ./my-backups  # Custom backup location

# Rollback and recovery
./fix-lint.sh --rollback           # Restore from recent backups
./fix-lint.sh --keep-backups 10   # Keep more backup versions

# Automation friendly
./fix-lint.sh --force --fix formatting  # No prompts
```

### Available Fix Types

| Fix Type     | Description                     | Example                         |
| ------------ | ------------------------------- | ------------------------------- |
| `formatting` | Apply shfmt code formatting     | Indentation, spacing, structure |
| `quotes`     | Fix unquoted variables          | `$var` → `"$var"`               |
| `read-flags` | Add missing -r to read          | `read -p` → `read -r -p`        |
| `variables`  | Add shellcheck disable comments | For color variables, etc.       |
| `all`        | Apply all fixes (default)       | Complete automatic fixing       |

## ⚙️ Configuration

### .shellcheckrc

```bash
# Current project configuration
disable=SC1091    # Not following sourced files (expected)

# You can add more exclusions:
# disable=SC1091,SC2034,SC2086
```

### Common Disable Patterns

```bash
# Single line disable
# shellcheck disable=SC2086
command $intentionally_unquoted

# Multiple rules
# shellcheck disable=SC2086,SC2034
source "$config_file"

# Whole file disable (use sparingly)
# shellcheck disable=SC2034
```

## 💻 VS Code Integration

### Recommended Extensions

The project includes `.vscode/extensions.json` with:

- **ShellCheck** - Real-time linting
- **Shell Format** - Automatic formatting
- **Bash Debug** - Debugging support
- **Enhanced Shell Syntax** - Better highlighting

### Keyboard Shortcuts

| Shortcut       | Action                 |
| -------------- | ---------------------- |
| `Ctrl+Shift+L` | Lint current file      |
| `Ctrl+Shift+F` | Format current file    |
| `Ctrl+Shift+A` | Analyze all scripts    |
| `Ctrl+Shift+X` | Auto-fix all scripts   |
| `Ctrl+Shift+T` | Complete test workflow |

### VS Code Tasks

Access via `Ctrl+Shift+P` → "Tasks: Run Task":

- **ShellCheck: Analyze All Scripts** - Project-wide analysis
- **Fix: Auto-fix All Bash Scripts** - Run the fixer
- **ShellCheck: Current File** - Lint current file
- **Format: Current Bash File** - Format with shfmt

### VS Code Settings

Optimized settings in `.vscode/settings.json`:

- Real-time ShellCheck feedback
- Auto-format on save
- Enhanced terminal configuration
- Performance tuning

## 🔍 Common Issues & Fixes

### SC2162: read without -r

```bash
# ❌ Problem
read -p "Enter value: " var

# ✅ Fix (automatic)
read -r -p "Enter value: " var
```

**Status**: ✅ Auto-fixed by `fix-lint.sh`

### SC2086: Double quote to prevent globbing

```bash
# ❌ Problem
rm -rf $temp_dir
echo $user_input

# ✅ Fix (manual review needed)
rm -rf "$temp_dir"
echo "$user_input"
```

**Status**: ⚠️ Manual review required (future enhancement planned)

### SC2034: Variable appears unused

```bash
# ❌ Problem
RED='\033[0;31m'

# ✅ Fix (automatic)
# shellcheck disable=SC2034
RED='\033[0;31m'
```

**Status**: ✅ Auto-fixed for common variables

### SC2181: Check exit code directly

```bash
# ❌ Problem
command
if [ $? -eq 0 ]; then
    echo "Success"
fi

# ✅ Fix (manual)
if command; then
    echo "Success"
fi
```

**Status**: ⚠️ Manual review recommended

### SC2129: Multiple redirects to same file

```bash
# ❌ Problem
echo "line1" >> file.txt
echo "line2" >> file.txt
echo "line3" >> file.txt

# ✅ Fix (manual)
{
    echo "line1"
    echo "line2"
    echo "line3"
} >> file.txt
```

**Status**: ⚠️ Manual optimization recommended

## 📋 Best Practices

### Script Headers

```bash
#!/usr/bin/env bash
#
# Script description
# Author: Your Name
# Version: 1.0
#

set -euo pipefail  # Strict mode
```

### Variable Handling

```bash
# ✅ Good: Always quote variables
rm -rf "$temp_dir"
echo "User said: $user_input"

# ✅ Good: Use local in functions
function process_data() {
    local input_file="$1"
    local output_file="$2"
    # ...
}

# ✅ Good: Check for required variables
: "${REQUIRED_VAR:?Missing required variable}"
```

### Error Handling

```bash
# ✅ Good: Check command success
if ! command -v git &>/dev/null; then
    echo "Git is required but not installed"
    exit 1
fi

# ✅ Good: Use specific exit codes
exit_with_error() {
    echo "Error: $1" >&2
    exit "${2:-1}"
}
```

### Arrays and Lists

```bash
# ✅ Good: Use arrays for multiple values
declare -a files=("file1.txt" "file2.txt" "file3.txt")

# ✅ Good: Iterate safely
for file in "${files[@]}"; do
    process_file "$file"
done
```

## 🔄 Workflow Guidelines

### For New Scripts

1. **Start with template**:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   ```

2. **Develop with real-time feedback**:

   - Use VS Code with ShellCheck extension
   - Run `./check-lint.sh script.sh` frequently

3. **Format regularly**:

   ```bash
   shfmt -w -i 2 -ci -sr script.sh
   ```

4. **Final check**:

   ```bash
   ./check-lint.sh script.sh
   ```

### For Existing Scripts

1. **Analyze current state**:

   ```bash
   ./check-lint.sh --verbose
   ```

2. **Apply automatic fixes**:

   ```bash
   ./fix-lint.sh --dry-run  # Preview first
   ./fix-lint.sh            # Apply fixes
   ```

3. **Review and test**:

   ```bash
   ./check-lint.sh          # Verify fixes
   # Test script functionality
   ```

4. **Handle remaining issues**:
   - Review manual fix suggestions
   - Add disable comments for false positives
   - Optimize code structure

### Before Committing

```bash
# Final quality check
./check-lint.sh --performance

# Ensure no critical issues
./check-lint.sh --filter error
```

### CI/CD Integration

```bash
# In your CI pipeline
./check-lint.sh --json --output lint-results.json
if [ $? -ne 0 ]; then
    echo "Linting issues found"
    exit 1
fi
```

## 🐛 Troubleshooting

### Tool Installation Issues

```bash
# macOS with Homebrew
brew install shellcheck shfmt

# Ubuntu/Debian
sudo apt update
sudo apt install shellcheck
snap install shfmt

# Manual installation check
command -v shellcheck || echo "ShellCheck not found"
command -v shfmt || echo "shfmt not found"
```

### Permission Issues

```bash
# Make scripts executable
chmod +x check-lint.sh fix-lint.sh

# Fix file permissions
find . -name "*.sh" -exec chmod +x {} \;
```

### Performance Issues

```bash
# For large codebases, use filtering
./check-lint.sh --exclude "vendor*" --exclude "node_modules*"

# Process specific directories
find ./src -name "*.sh" | head -20 | xargs ./check-lint.sh
```

### VS Code Issues

1. **Extensions not installing**:

   - Open Command Palette (`Cmd+Shift+P`)
   - Run "Extensions: Show Recommended Extensions"
   - Install manually

2. **ShellCheck not working**:

   - Check if shellcheck is in PATH
   - Restart VS Code after installation
   - Check `.vscode/settings.json`

3. **Formatting not working**:
   - Verify shfmt installation
   - Check file associations in settings
   - Try manual format: `Ctrl+Shift+F`

### Backup and Recovery

```bash
# List available backups
ls -la backups/

# Manual rollback for specific file
cp backups/script.sh.20231201_120000.backup script.sh

# Clean up old backups
find backups/ -name "*.backup" -mtime +30 -delete
```

## 📊 Quality Metrics

### Target Standards

- **Error rate**: 0 errors
- **Warning rate**: < 5 warnings per 100 lines
- **Style compliance**: 100% shfmt formatted
- **Coverage**: 100% of bash files checked

### Measuring Progress

```bash
# Get baseline metrics
./check-lint.sh --json --output baseline.json

# Track improvements
./check-lint.sh --json | jq '.summary'

# Performance tracking
./check-lint.sh --performance --verbose
```

## 🚀 Advanced Features

### Custom Fix Development

To add new fix types to `fix-lint.sh`:

1. Add to the fix type validation
2. Implement the fix function
3. Add to the processing pipeline
4. Update documentation

### Integration Examples

```bash
# Git pre-commit hook
#!/usr/bin/env bash
./check-lint.sh --quiet || exit 1

# Makefile target
lint:
./check-lint.sh

fix:
./fix-lint.sh --force

# GitHub Actions
- name: Lint bash scripts
  run: |
    ./check-lint.sh --json --output results.json
    cat results.json | jq '.summary'
```

## 📚 Resources

### Documentation

- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [shfmt GitHub](https://github.com/mvdan/sh)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)

### External Tools

- [bashdb](http://bashdb.sourceforge.net/) - Bash debugger
- [bats](https://github.com/bats-core/bats-core) - Bash testing framework
- [shellharden](https://github.com/anordal/shellharden) - Additional hardening

## 🎉 Summary

You now have a **professional-grade bash development environment** with:

✅ **Intelligent analysis** with enhanced filtering and reporting  
✅ **Smart automatic fixing** with safety features  
✅ **Comprehensive VS Code integration** with real-time feedback  
✅ **Flexible workflows** for any project size  
✅ **Backup and rollback** capabilities  
✅ **Performance optimization** and metrics  
✅ **CI/CD ready** with JSON export

### Essential Commands

| Command                    | Purpose                  |
| -------------------------- | ------------------------ |
| `./check-lint.sh`          | Analyze all files        |
| `./fix-lint.sh`            | Fix issues automatically |
| `./fix-lint.sh --dry-run`  | Preview changes          |
| `./fix-lint.sh --rollback` | Undo changes             |
| `./check-lint.sh --json`   | Export results           |

**Happy linting!** 🚀

---

Last updated: Version 3.0 - Enhanced tools with intelligent fixing and comprehensive reporting
