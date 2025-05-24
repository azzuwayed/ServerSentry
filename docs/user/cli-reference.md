# ServerSentry v2 - CLI Reference

📋 **Complete Command-Line Interface Reference for ServerSentry v2**

This reference covers all available commands, options, and usage examples for the ServerSentry CLI.

## Command Syntax

```bash
serversentry [global_options] command [command_options] [arguments]
```

## Global Options

```bash
-v, --verbose        Enable verbose output
-d, --debug          Enable debug mode
-c, --config FILE    Use custom configuration file
-h, --help           Show help message
--version            Show version information
```

## Core Commands

### System Management

#### `status`

Check system status and monitoring service state.

```bash
serversentry status [options]

Options:
  -j, --json          Output in JSON format
  -q, --quiet         Minimal output (exit codes only)
  -a, --all           Show detailed plugin information
```

**Examples:**

```bash
# Basic status check
serversentry status

# JSON output for automation
serversentry status --json

# Detailed status with all plugin information
serversentry status --all
```

#### `start`

Start the monitoring daemon service.

```bash
serversentry start [options]

Options:
  -f, --foreground    Run in foreground (don't daemonize)
  -i, --interval SEC  Override check interval (seconds)
  --pid-file FILE     Custom PID file location
```

**Examples:**

```bash
# Start monitoring daemon
serversentry start

# Start with custom interval (2 minutes)
serversentry start --interval 120

# Run in foreground for debugging
serversentry start --foreground
```

#### `stop`

Stop the monitoring daemon service.

```bash
serversentry stop [options]

Options:
  -f, --force         Force stop (kill -9)
  --timeout SEC       Wait timeout before force kill
```

**Examples:**

```bash
# Gracefully stop monitoring
serversentry stop

# Force stop if not responding
serversentry stop --force
```

#### `restart`

Restart the monitoring daemon service.

```bash
serversentry restart [options]

Options:
  --timeout SEC       Wait timeout for graceful stop
  -f, --force         Force restart if graceful fails
```

### Plugin Management

#### `check`

Run monitoring plugin checks.

```bash
serversentry check [plugin] [options]

Options:
  -a, --all           Run all enabled plugins (default)
  -j, --json          Output in JSON format
  -t, --threshold     Override default threshold
  --timeout SEC       Plugin execution timeout
```

**Examples:**

```bash
# Run all plugin checks
serversentry check

# Check specific plugin
serversentry check cpu
serversentry check memory
serversentry check disk

# JSON output for scripting
serversentry check cpu --json

# Override threshold for this run
serversentry check cpu --threshold 90
```

#### `list`

List available plugins and their status.

```bash
serversentry list [options]

Options:
  -a, --available     Show all available plugins
  -e, --enabled       Show only enabled plugins (default)
  -d, --disabled      Show only disabled plugins
  -j, --json          Output in JSON format
```

**Examples:**

```bash
# List enabled plugins
serversentry list

# List all available plugins
serversentry list --available

# JSON output for automation
serversentry list --json
```

### Configuration Management

#### `configure`

Interactive configuration management.

```bash
serversentry configure [component] [options]

Components:
  plugins             Configure plugin settings
  notifications       Configure notification providers
  anomaly             Configure anomaly detection
  thresholds          Configure alert thresholds

Options:
  --reset             Reset to default configuration
  --backup            Create configuration backup
```

**Examples:**

```bash
# Interactive configuration wizard
serversentry configure

# Configure specific component
serversentry configure plugins
serversentry configure notifications

# Reset configuration to defaults
serversentry configure --reset
```

#### `update-threshold`

Update configuration thresholds.

```bash
serversentry update-threshold key=value [key=value...]

Options:
  --validate          Validate but don't apply changes
  --backup            Backup before applying changes
```

**Examples:**

```bash
# Update CPU threshold
serversentry update-threshold cpu_threshold=85

# Update multiple thresholds
serversentry update-threshold cpu_threshold=80 memory_threshold=90

# Validate changes without applying
serversentry update-threshold cpu_threshold=75 --validate
```

#### `list-thresholds`

Display current configuration values.

```bash
serversentry list-thresholds [options]

Options:
  -j, --json          Output in JSON format
  -f, --filter TERM   Filter by configuration key
  -s, --section NAME  Show specific configuration section
```

**Examples:**

```bash
# Show all thresholds
serversentry list-thresholds

# Show only CPU-related settings
serversentry list-thresholds --filter cpu

# Show notification settings
serversentry list-thresholds --section notifications
```

### Diagnostics

#### `diagnostics`

Run system diagnostics and health checks.

```bash
serversentry diagnostics command [options]

Commands:
  run                 Run full system diagnostics
  quick               Quick health check
  config              Validate configuration
  dependencies        Check system dependencies
  performance         Performance analysis
  reports             List diagnostic reports
  view [report]       View diagnostic report
  cleanup [days]      Clean up old reports

Options:
  -j, --json          Output in JSON format
  -v, --verbose       Detailed output
  --save              Save report to file
```

**Examples:**

```bash
# Full system diagnostics
serversentry diagnostics run

# Quick health check
serversentry diagnostics quick

# Check configuration validity
serversentry diagnostics config

# Performance analysis
serversentry diagnostics performance

# List available reports
serversentry diagnostics reports

# View latest report
serversentry diagnostics view

# Clean up reports older than 30 days
serversentry diagnostics cleanup 30
```

### Notification Management

#### `webhook`

Manage webhook endpoints and test notifications.

```bash
serversentry webhook command [arguments] [options]

Commands:
  add URL             Add webhook endpoint
  remove ID           Remove webhook by ID
  list                List configured webhooks
  test [ID]           Test webhook delivery
  status              Check webhook health

Options:
  --method METHOD     HTTP method (POST, PUT, etc.)
  --headers HEADERS   Custom HTTP headers
  --timeout SEC       Request timeout
```

**Examples:**

```bash
# Add webhook endpoint
serversentry webhook add https://your-webhook-url.com/alerts

# List all webhooks
serversentry webhook list

# Test all webhooks
serversentry webhook test

# Test specific webhook
serversentry webhook test 1

# Remove webhook
serversentry webhook remove 1
```

### Template Management

#### `template`

Manage notification templates.

```bash
serversentry template command [arguments] [options]

Commands:
  list                List available templates
  create NAME TYPE    Create new template
  test TYPE MSG       Test template rendering
  validate FILE       Validate template syntax
  edit NAME           Edit existing template

Options:
  --provider TYPE     Template provider (teams, slack, discord, email)
  --variables         Show available template variables
```

**Examples:**

```bash
# List all templates
serversentry template list

# Create new Teams template
serversentry template create my_alert teams

# Test template rendering
serversentry template test teams alert

# Validate template file
serversentry template validate config/templates/my_template.template

# Show available variables
serversentry template --variables
```

### Anomaly Detection

#### `anomaly`

Manage anomaly detection features.

```bash
serversentry anomaly command [arguments] [options]

Commands:
  list                List anomaly configurations
  config [plugin]     Configure anomaly detection
  enable [plugin]     Enable anomaly detection
  disable [plugin]    Disable anomaly detection
  test                Test anomaly detection
  summary [days]      Show anomaly summary

Options:
  --sensitivity NUM   Set sensitivity level (1.0-4.0)
  --window-size NUM   Set analysis window size
  -j, --json          Output in JSON format
```

**Examples:**

```bash
# List anomaly configurations
serversentry anomaly list

# Configure CPU anomaly detection
serversentry anomaly config cpu

# Enable anomaly detection for memory
serversentry anomaly enable memory

# Test anomaly detection
serversentry anomaly test

# Show anomalies from last 7 days
serversentry anomaly summary 7
```

### Composite Checks

#### `composite`

Manage composite monitoring rules.

```bash
serversentry composite command [arguments] [options]

Commands:
  list                List composite check rules
  create NAME RULE    Create new composite check
  test [name]         Test composite check evaluation
  enable NAME         Enable composite check
  disable NAME        Disable composite check
  remove NAME         Remove composite check

Options:
  --severity LEVEL    Set severity level (1-3)
  --cooldown SEC      Set cooldown period
  -j, --json          Output in JSON format
```

**Examples:**

```bash
# List all composite checks
serversentry composite list

# Create new composite check
serversentry composite create high_load "cpu.value > 80 AND memory.value > 85"

# Test composite check evaluation
serversentry composite test high_load

# Enable composite check
serversentry composite enable high_load

# Test all composite checks
serversentry composite test
```

### Log Management

#### `logs`

Manage system logs and monitoring data.

```bash
serversentry logs command [arguments] [options]

Commands:
  view [file]         View log files
  cleanup [days]      Clean up old logs
  rotate              Force log rotation
  follow              Follow logs in real-time

Options:
  -n, --lines NUM     Number of lines to show (default: 50)
  -f, --follow        Follow logs (tail -f behavior)
  --grep PATTERN      Filter log entries
  --since TIME        Show logs since specified time
```

**Examples:**

```bash
# View recent log entries
serversentry logs view

# Follow logs in real-time
serversentry logs follow

# View last 100 lines
serversentry logs view --lines 100

# Filter logs for errors
serversentry logs view --grep ERROR

# Clean up logs older than 30 days
serversentry logs cleanup 30
```

## Advanced Commands

### TUI (Text User Interface)

#### `tui`

Launch interactive dashboard (if available).

```bash
serversentry tui [options]

Options:
  --simple            Use simple mode
  --refresh SEC       Set refresh interval
  --no-colors         Disable colors
```

**Examples:**

```bash
# Launch TUI dashboard
serversentry tui

# Simple mode for compatibility
serversentry tui --simple

# Custom refresh interval
serversentry tui --refresh 5
```

### Development and Testing

#### `validate-config`

Validate configuration files.

```bash
serversentry validate-config [file] [options]

Options:
  --strict            Strict validation mode
  --warnings          Show warnings as errors
```

#### `reload`

Reload configuration without restart.

```bash
serversentry reload [component] [options]

Components:
  config              Reload main configuration
  plugins             Reload plugin configurations
  notifications       Reload notification settings
```

#### `logging`

Comprehensive logging system management and monitoring.

```bash
serversentry logging [subcommand] [options]

Subcommands:
  status              Show logging system status
  health              Check logging system health
  rotate              Rotate log files manually
  cleanup [days]      Clean up old log archives (default: 30 days)
  level [level]       Get/set log level (debug, info, warning, error, critical)
  test                Test all logging functions
  config              Show logging configuration
  tail [type] [lines] View recent log entries (default: main, 50 lines)
  follow [type]       Follow log file in real-time (default: main)
  format [format]     Get/set log format (standard, json, structured)

Log Types:
  main                Main application log
  performance         Performance metrics log
  error               Error and critical messages log
  audit               Audit trail log
  security            Security events log
```

**Examples:**

```bash
# Show logging system status
serversentry logging status

# Check logging system health
serversentry logging health

# Set log level to debug
serversentry logging level debug

# View last 100 error log entries
serversentry logging tail error 100

# Follow performance log in real-time
serversentry logging follow performance

# Test all logging functions
serversentry logging test

# Change log format to JSON
serversentry logging format json

# Manually rotate logs
serversentry logging rotate

# Clean up archives older than 60 days
serversentry logging cleanup 60
```

**Log Management Features:**

- **Specialized Log Files**: Separate logs for errors, performance, audit, and security
- **Component-Specific Logging**: Different log levels for different components
- **Multiple Formats**: Standard, JSON, and structured logging formats
- **Automatic Rotation**: Size-based and time-based log rotation
- **Health Monitoring**: Disk usage and accessibility checks
- **Real-time Following**: Live log monitoring capabilities

## Output Formats

### JSON Output

Many commands support `--json` option for structured output:

```bash
# JSON status output
serversentry status --json
{
  "service": {
    "status": "running",
    "pid": 12345,
    "uptime": 3600
  },
  "plugins": {
    "cpu": {"status": "ok", "value": 45},
    "memory": {"status": "ok", "value": 62}
  }
}
```

### Verbose Output

Use `-v` or `--verbose` for detailed information:

```bash
# Verbose plugin check
serversentry check cpu --verbose
[DEBUG] Loading CPU plugin from lib/plugins/cpu/
[INFO] CPU plugin initialized successfully
[DEBUG] Running CPU check with threshold 85%
[INFO] CPU usage: 45% (OK)
```

## Exit Codes

ServerSentry uses standard exit codes for automation:

- `0` - Success/OK
- `1` - Warning condition
- `2` - Critical condition
- `3` - Unknown/Error
- `4` - Configuration error
- `5` - Service not running

## Environment Variables

### Configuration Overrides

```bash
export SERVERSENTRY_SYSTEM_LOG_LEVEL=debug
export SERVERSENTRY_SYSTEM_CHECK_INTERVAL=120
export SERVERSENTRY_PLUGINS_CPU_THRESHOLD=80
```

### Runtime Options

```bash
export SERVERSENTRY_CONFIG_FILE=/path/to/config.yaml
export SERVERSENTRY_PID_FILE=/path/to/serversentry.pid
export MONITOR_INTERVAL=60
```

## Examples and Use Cases

### Basic Monitoring Setup

```bash
# Install and configure
serversentry configure

# Start monitoring
serversentry start

# Check status
serversentry status
```

### Automation and Scripting

```bash
#!/bin/bash
# Check if CPU usage is critical
if serversentry check cpu --json | jq -r '.status' | grep -q 'CRITICAL'; then
    echo "CPU usage is critical!"
    exit 2
fi
```

### Troubleshooting Script

```bash
#!/bin/bash
# Comprehensive health check
echo "=== ServerSentry Health Check ==="
serversentry diagnostics run
serversentry status --all
serversentry logs view --lines 20
```

### Notification Testing

```bash
# Test all notification channels
serversentry webhook test
serversentry template test teams alert
serversentry template test slack warning
```

## Integration Examples

### Cron Integration

```bash
# Check system every 5 minutes
*/5 * * * * /opt/serversentry/bin/serversentry check --json > /tmp/serversentry-status.json

# Daily diagnostics
0 6 * * * /opt/serversentry/bin/serversentry diagnostics run
```

### Monitoring Scripts

```bash
# Custom monitoring script
#!/bin/bash
STATUS=$(serversentry status --json)
CPU=$(echo "$STATUS" | jq -r '.plugins.cpu.value')
if [ "$CPU" -gt 90 ]; then
    serversentry webhook test
fi
```

---

**📍 Quick Reference**: Use `serversentry help` or `serversentry command --help` for context-specific help.

**See Also:**

- [User Manual](manual.md) for feature explanations
- [Configuration Guide](configuration.md) for setup details
- [Troubleshooting](troubleshooting.md) for common issues
