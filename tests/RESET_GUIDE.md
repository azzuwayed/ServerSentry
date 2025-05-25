# ServerSentry v2 - Reset Guide

## Overview

The ServerSentry reset functionality allows you to restore the system to a fresh installation state, as if you just downloaded the software. This is useful for:

- **Testing**: Reset to clean state for testing scenarios
- **Troubleshooting**: Clear corrupted configurations or cache
- **Development**: Start fresh during development
- **Cleanup**: Remove all generated data and logs

## Quick Start

### Basic Reset (Interactive)

```bash
# From project root
./tests/reset_serversentry.sh

# Or using the wrapper
./bin/reset
```

### Force Reset (No Confirmation)

```bash
./tests/reset_serversentry.sh --force
```

### Preview Changes (Dry Run)

```bash
./tests/reset_serversentry.sh --dry-run
```

The dry-run mode provides a clean, summarized view of what would be reset without showing verbose command details.

## Reset Options

### Command Line Options

| Option          | Description                              |
| --------------- | ---------------------------------------- |
| `--force`       | Skip confirmation prompts                |
| `--keep-config` | Keep main configuration files            |
| `--dry-run`     | Show what would be done without doing it |
| `--help`        | Show help message                        |

### Usage Examples

```bash
# Interactive reset with confirmation
./tests/reset_serversentry.sh

# Reset without confirmation
./tests/reset_serversentry.sh --force

# Reset but keep configuration files
./tests/reset_serversentry.sh --keep-config

# Preview what would be reset
./tests/reset_serversentry.sh --dry-run

# Combine options
./tests/reset_serversentry.sh --force --keep-config
```

## What Gets Reset

### 🛑 Services and Processes

- **Monitoring Service**: Gracefully stops the monitoring daemon
- **Background Processes**: Terminates any running ServerSentry processes
- **PID Files**: Removes process ID files

### 🗑️ Runtime Files

- **PID Files**: `serversentry.pid`, `*.pid`
- **Lock Files**: `*.lock` files in base and tmp directories
- **Cache Files**: `.serversentry_cache` and similar

### 📝 Log Files and Archives

- **Main Logs**: `logs/serversentry.log`, `logs/error.log`, etc.
- **Archive Logs**: All files in `logs/archive/`
- **Specialized Logs**: Anomaly, diagnostics, periodic, composite logs
- **Compressed Logs**: All `.gz` files
- **Backup Files**: All `.bak` files

### 🗂️ Cache and Temporary Files

- **Tmp Directory**: All files in `tmp/` (except `.gitkeep`)
- **Plugin Cache**: `tmp/plugin_*` files
- **System Cache**: Various cache patterns
- **Temporary Files**: `*.tmp`, `temp_*`, `*_temp` files

### 🔌 Plugin State

- **Plugin Registry**: `logs/plugin_registry.json`
- **Performance Data**: `logs/plugin_performance.log`
- **Health Data**: `logs/plugin_health.log`
- **Plugin Cache Directories**: Various plugin cache locations

### 🔍 Diagnostic Reports

- **Diagnostic Reports**: All JSON reports in `logs/diagnostics/`
- **Diagnostic Logs**: All log files in diagnostic directories

### ⚙️ Configuration Files (Optional)

When `--keep-config` is **NOT** specified:

- **Main Config**: `config/serversentry.yaml`
- **Periodic Config**: `config/periodic.yaml`
- **Diagnostics Config**: `config/diagnostics.conf`
- **Plugin Configs**: All `.conf` files in `config/plugins/`
- **Notification Configs**: All files in `config/notifications/`
- **Composite Configs**: All files in `config/composite/`

### 🌍 Environment Files

- **Environment Files**: `.env`, `.env.local`, `.env.production`

## What Gets Preserved

### Always Preserved

- **Source Code**: All files in `lib/`, `bin/`, `docs/`
- **Tests**: All files in `tests/` (except generated reports)
- **Installation Scripts**: `bin/install.sh` and related
- **Directory Structure**: Essential directories are recreated

### Preserved with `--keep-config`

- **Main Configuration**: `config/serversentry.yaml`
- **Custom Settings**: User-modified configuration files

## Reset Process

### 1. Service Shutdown

```
🛑 Stopping ServerSentry Services
ℹ️  Stopping monitoring service (PID: 12345)
✅ Monitoring service stopped
✅ All ServerSentry services stopped
```

### 2. Runtime Cleanup

```
🗑️ Removing Runtime Files
ℹ️  Removing runtime file: serversentry.pid
✅ Runtime files removed
```

### 3. Log Clearing

```
📝 Clearing Log Files
ℹ️  Clearing logs in: logs
ℹ️  Clearing logs in: archive
ℹ️  Clearing log file: serversentry.log
✅ Log files cleared
```

### 4. Cache Cleanup

```
🗂️ Clearing Cache and Temporary Files
ℹ️  Clearing tmp directory
ℹ️  Clearing cache pattern: plugin_*
✅ Cache and temporary files cleared
```

### 5. Plugin Reset

```
🔌 Resetting Plugin State
ℹ️  Clearing plugin state: plugin_registry.json
✅ Plugin state reset
```

### 6. Diagnostics Cleanup

```
🔍 Clearing Diagnostic Reports
ℹ️  Clearing diagnostic reports in: reports
✅ Diagnostic reports cleared
```

### 7. Configuration Reset (Optional)

```
⚙️ Resetting Configuration Files
ℹ️  Removing configuration: serversentry.yaml
ℹ️  Clearing plugin configurations
✅ Configuration files reset
```

### 8. Environment Cleanup

```
🌍 Clearing Environment Files
ℹ️  Removing environment file: .env
✅ Environment files cleared
```

### 9. Directory Recreation

```
📁 Recreating Essential Directories
ℹ️  Creating directory: logs
ℹ️  Creating .gitkeep in tmp
✅ Essential directories recreated
```

### 10. Verification

```
✅ Verifying Reset Completion
✅ No ServerSentry processes running
✅ No PID files found
✅ All log files cleared
✅ All cache files cleared
✅ Reset completed successfully - ServerSentry is in fresh state
```

## After Reset

### Next Steps

1. **Reconfigure** (if needed):

   ```bash
   ./bin/install.sh
   ```

2. **Start Fresh**:

   ```bash
   ./bin/serversentry status
   ```

3. **Run Diagnostics**:
   ```bash
   ./bin/serversentry diagnostics run
   ```

### Fresh State Verification

After reset, ServerSentry should be in the same state as a fresh download:

- ✅ No running processes
- ✅ No configuration files (unless `--keep-config`)
- ✅ Empty log files
- ✅ Clean cache directories
- ✅ Default directory structure

## Troubleshooting

### Reset Issues

#### Processes Won't Stop

```bash
# Check for stubborn processes
ps aux | grep serversentry

# Force kill if necessary
pkill -9 -f serversentry

# Then run reset again
./tests/reset_serversentry.sh --force
```

#### Permission Errors

```bash
# Ensure you have write permissions
ls -la logs/ tmp/ config/

# Fix permissions if needed
chmod -R u+w logs/ tmp/ config/
```

#### Verification Warnings

If verification shows warnings:

1. **Check the specific warnings** in the output
2. **Manual cleanup** may be needed for stubborn files
3. **Rerun reset** with `--force` if needed

### Recovery

If reset causes issues:

1. **Reinstall**:

   ```bash
   ./bin/install.sh
   ```

2. **Restore from backup** (if you have one)

3. **Check git status** to see what changed:
   ```bash
   git status
   git diff
   ```

## Safety Features

### Confirmation Prompt

By default, the script asks for confirmation:

```
Are you sure you want to reset ServerSentry? (y/N):
```

### Dry Run Mode

Preview changes without making them:

```bash
./tests/reset_serversentry.sh --dry-run
```

**Output Features:**
- Clean, summarized view of actions
- Bullet-point format for easy reading
- No verbose command details
- Clear indication of what would be affected

### Graceful Shutdown

- Services are stopped gracefully with SIGTERM
- 10-second timeout before force kill
- Proper cleanup sequence

### Verification

- Checks that processes are actually stopped
- Verifies files are actually removed
- Reports any remaining issues

## Integration with Testing

### Test Scenarios

```bash
# Reset before each test run
./tests/reset_serversentry.sh --force

# Run tests
./tests/run_enhanced_tests.sh

# Reset after tests
./tests/reset_serversentry.sh --force
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Reset ServerSentry
  run: ./tests/reset_serversentry.sh --force

- name: Run Tests
  run: ./tests/run_enhanced_tests.sh
```

## Best Practices

### When to Reset

- **Before testing** new features
- **After major changes** to configuration
- **When troubleshooting** mysterious issues
- **Before deployment** testing

### What to Backup

Before reset, consider backing up:

- **Custom configurations** in `config/`
- **Important logs** in `logs/`
- **Custom scripts** or modifications

### Development Workflow

```bash
# 1. Make changes
vim lib/core/something.sh

# 2. Test changes
./bin/serversentry status

# 3. Reset for clean test
./tests/reset_serversentry.sh --force

# 4. Test from fresh state
./bin/serversentry status
```

---

**Note**: This reset functionality is designed to be safe and comprehensive. It will restore ServerSentry to a fresh installation state while preserving the source code and essential directory structure.
