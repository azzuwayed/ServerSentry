# ServerSentry Bash Script Linting Guide

This guide covers the tools and processes for maintaining high-quality bash scripts in the ServerSentry project.

## Tools Installed

### 1. ShellCheck (Primary Linter)

- **Purpose**: Static analysis for bash scripts
- **Catches**: Syntax errors, semantic issues, common pitfalls
- **Installation**: `brew install shellcheck`

### 2. shfmt (Formatter)

- **Purpose**: Automatic code formatting
- **Features**: Consistent indentation, spacing, structure
- **Installation**: `brew install shfmt`

## Quick Commands

### Check All Scripts

```bash
./check-lint.sh
```

This gives you a quick overview of all lint issues across your bash files.

### Fix All Scripts Automatically

```bash
./fix-lint.sh
```

This will:

- Format all bash scripts with `shfmt`
- Apply common automatic fixes
- Create backup files (`.backup` extension)
- Report remaining issues

### Manual Commands

#### Check a single file

```bash
shellcheck path/to/script.sh
```

#### Format a single file

```bash
shfmt -w -i 2 -ci -sr path/to/script.sh
```

#### Check all bash files

```bash
find . -name "*.sh" -exec shellcheck {} \;
```

## Configuration

### .shellcheckrc

The project includes a `.shellcheckrc` file that disables certain warnings:

- `SC1091`: Not following sourced files (expected for modular design)

You can customize this file to add more suppressions if needed.

## Common Issues and Fixes

### 1. SC2162: read without -r will mangle backslashes

**Problem**: `read -p "Enter value: " var`
**Fix**: `read -r -p "Enter value: " var`
**Auto-fixed**: ✅

### 2. SC2086: Double quote to prevent globbing

**Problem**: `command $var`
**Fix**: `command "$var"`
**Auto-fixed**: ❌ (requires manual review)

### 3. SC2129: Consider using { cmd1; cmd2; } >> file

**Problem**: Multiple redirects to same file
**Fix**: Group commands in braces
**Auto-fixed**: ❌ (requires manual review)

### 4. SC2181: Check exit code directly

**Problem**: `if [ $? -eq 0 ]; then`
**Fix**: `if command; then`
**Auto-fixed**: ❌ (requires manual review)

## Workflow Recommendations

### For New Scripts

1. Write your script
2. Run `shellcheck script.sh` early and often
3. Format with `shfmt -w -i 2 -ci -sr script.sh`
4. Fix any remaining issues manually

### For Existing Scripts

1. Run `./check-lint.sh` to see current status
2. Run `./fix-lint.sh` to auto-fix what's possible
3. Review and manually fix remaining issues
4. Remove backup files: `find . -name "*.backup" -delete`

### Before Committing

Always run a final check:

```bash
./check-lint.sh
```

## Manual Fix Examples

### Quoting Variables

```bash
# Before
rm -rf $temp_dir
echo $user_input

# After
rm -rf "$temp_dir"
echo "$user_input"
```

### Exit Code Checking

```bash
# Before
command
if [ $? -eq 0 ]; then
    echo "Success"
fi

# After
if command; then
    echo "Success"
fi
```

### Grouped Redirects

```bash
# Before
echo "line1" >> file.txt
echo "line2" >> file.txt
echo "line3" >> file.txt

# After
{
    echo "line1"
    echo "line2"
    echo "line3"
} >> file.txt
```

## Suppressing Warnings

For false positives, you can suppress specific warnings:

```bash
# shellcheck disable=SC2086
command $intentionally_unquoted

# Or for the whole file
# shellcheck disable=SC2086,SC2034
```

## Integration with VS Code

### Automatic Setup

The project includes a complete VS Code configuration for optimal bash development:

#### Extensions (`.vscode/extensions.json`)

Essential extensions will be recommended when you open the project:

- **ShellCheck**: Real-time linting integration
- **Shell Format**: Automatic formatting with shfmt
- **Bash Debug**: Debugging support for bash scripts
- **Enhanced Shell Syntax**: Better syntax highlighting
- **GitLens**: Enhanced Git integration

#### Tasks (`.vscode/tasks.json`)

Integrated tasks accessible via `Ctrl+Shift+P` → "Tasks: Run Task":

- **ShellCheck: Analyze All Scripts** - Quick project-wide analysis
- **Fix: Auto-fix All Bash Scripts** - Run the comprehensive fixer
- **ShellCheck: Current File** - Lint the currently open file
- **Format: Current Bash File** - Format current file with shfmt
- **Test: ShellCheck All & Format All** - Complete workflow (default build task)

#### Keyboard Shortcuts (`.vscode/keybindings.json`)

Quick access while editing bash files:

- `Ctrl+Shift+L` - Lint current file
- `Ctrl+Shift+F` - Format current file
- `Ctrl+Shift+A` - Analyze all scripts
- `Ctrl+Shift+X` - Auto-fix all scripts
- `Ctrl+Shift+T` - Complete test workflow
- `F5` - Run demo.sh (when editing demo.sh)

#### Settings (`.vscode/settings.json`)

Optimized for bash development:

- **Real-time linting**: ShellCheck runs as you type
- **Auto-formatting**: Format on save, paste, and manual trigger
- **Enhanced terminal**: Better font, colors, and behavior
- **File associations**: Proper syntax highlighting for all shell files
- **Performance tuning**: Optimized for large codebases

### Quick Start with VS Code

1. Open the project in VS Code
2. Install recommended extensions when prompted
3. Open any `.sh` file
4. Start coding with real-time feedback!

### VS Code Workflow

1. **Edit**: Write your bash script with real-time ShellCheck feedback
2. **Format**: `Ctrl+Shift+F` to format current file
3. **Test**: `Ctrl+Shift+T` to run complete lint workflow
4. **Debug**: Use breakpoints and bash debugger if needed

## Troubleshooting

### ShellCheck not found

```bash
brew install shellcheck
```

### shfmt not found

```bash
brew install shfmt
```

### Permission denied

```bash
chmod +x script.sh
```

### Too many false positives

Edit `.shellcheckrc` to disable specific warnings:

```bash
disable=SC1091,SC2034,SC2086
```

### VS Code Extensions Not Installing

1. Open Command Palette (`Cmd+Shift+P`)
2. Run "Extensions: Show Recommended Extensions"
3. Install the recommended extensions manually

## Best Practices

1. **Use strict mode**: Add `set -euo pipefail` to scripts
2. **Quote variables**: Always quote `"$variables"`
3. **Check exit codes**: Use `if command; then` instead of `if [ $? -eq 0 ]`
4. **Use local variables**: Declare function variables as `local`
5. **Validate inputs**: Check arguments before using them
6. **Use arrays for lists**: Instead of space-separated strings
7. **Consistent formatting**: Let shfmt handle indentation and spacing
8. **Real-time feedback**: Use VS Code with ShellCheck extension for immediate feedback

## Files Overview

### Core Linting Scripts

- `fix-lint.sh`: Comprehensive auto-fixer
- `check-lint.sh`: Quick analysis tool
- `.shellcheckrc`: Configuration file

### VS Code Integration

- `.vscode/settings.json`: Editor configuration for bash development
- `.vscode/tasks.json`: Integrated task definitions
- `.vscode/keybindings.json`: Keyboard shortcuts for quick access
- `.vscode/extensions.json`: Recommended extensions

### Documentation

- `LINT-GUIDE.md`: This comprehensive guide

## Summary

You now have a **professional-grade bash development environment** with:

✅ **Automatic linting** with ShellCheck
✅ **Auto-formatting** with shfmt  
✅ **VS Code integration** with tasks and shortcuts
✅ **Real-time feedback** as you code
✅ **One-click fixes** for common issues
✅ **Comprehensive documentation**

**Quick Commands:**

- `./check-lint.sh` - See all issues
- `./fix-lint.sh` - Auto-fix everything possible
- `Ctrl+Shift+T` in VS Code - Complete workflow

Happy linting! 🚀
