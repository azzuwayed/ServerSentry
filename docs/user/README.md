# ServerSentry v2 User Documentation

🚀 **Welcome to ServerSentry v2** - Enterprise-grade server monitoring with statistical intelligence.

This comprehensive guide covers installation, configuration, and usage of all ServerSentry v2 features including anomaly detection, real-time dashboards, and intelligent alerting.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Monitoring Service](#monitoring-service)
5. [Advanced Features](#advanced-features)
6. [Configuration](#configuration)
7. [Monitoring Plugins](#monitoring-plugins)
8. [Notification System](#notification-system)
9. [Anomaly Detection](#anomaly-detection)
10. [Composite Checks](#composite-checks)
11. [System Diagnostics](#system-diagnostics)
12. [TUI Dashboard](#tui-dashboard)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)

## Quick Start

Get ServerSentry v2 running in under 5 minutes:

```bash
# 1. Clone and setup
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry/v2
chmod +x bin/serversentry

# 2. Run demo to see all features
./demo.sh

# 3. Launch interactive dashboard
./bin/serversentry tui

# 4. Check system status
./bin/serversentry status

# 5. Start background monitoring
./bin/serversentry start
```

## Installation

### System Requirements

**Minimum Requirements:**

- Linux, macOS, or Unix-like system
- Bash 4.0+
- 10MB RAM
- 50MB disk space

**Required Commands:**

- `ps`, `grep`, `awk`, `sed`, `tail`, `head`, `cat`, `date`

**Optional (Enhanced Features):**

- `jq` - JSON processing for advanced output
- `yq` - YAML validation for configuration
- `bc` - Mathematical calculations for anomaly detection
- `curl` - HTTP requests for webhook notifications

### Installation Steps

```bash
# Clone repository
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry/v2

# Make executable
chmod +x bin/serversentry

# Optional: Add to PATH
echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
serversentry version
serversentry diagnostics quick
```

## Basic Usage

### Essential Commands

```bash
# System monitoring
serversentry status          # Visual system status
serversentry check cpu       # Check specific plugin
serversentry list           # List available plugins

# Service management
serversentry start          # Start background monitoring
serversentry stop           # Stop monitoring
serversentry tui            # Launch interactive dashboard

# Information and help
serversentry version        # Show version
serversentry help          # Command help
serversentry logs view     # View recent logs
```

### First-Time Setup

1. **Run Initial Diagnostics:**

   ```bash
   serversentry diagnostics run
   ```

2. **Configure Basic Settings:**

   ```bash
   # Edit main configuration
   serversentry configure

   # Or edit directly
   nano config/serversentry.yaml
   ```

3. **Test Core Functionality:**
   ```bash
   serversentry status
   serversentry check cpu
   serversentry check memory
   ```

## Monitoring Service

The ServerSentry monitoring service provides continuous, automated monitoring of your system by running as a background daemon. This is the core feature that enables 24/7 monitoring, automated alerting, and historical data collection.

### Quick Start

```bash
# Start the monitoring service
serversentry start

# Check service status
serversentry status

# View monitoring activity in real-time
serversentry tui

# Stop the service
serversentry stop
```

### Key Features

- **Continuous Monitoring**: Automated plugin checks every 60 seconds (configurable)
- **Background Operation**: Runs as a daemon with PID tracking
- **Anomaly Detection**: Statistical analysis of metrics for intelligent alerting
- **Periodic Reporting**: Automated system health reports every 24 hours
- **Smart Alerting**: Threshold-based and anomaly-based notifications with silence periods
- **Resource Efficient**: Minimal system overhead with configurable intervals

### Configuration

```bash
# Custom monitoring interval (default: 60 seconds)
MONITOR_INTERVAL=120 serversentry start

# Configure periodic monitoring settings
nano config/periodic.yaml
```

### Monitoring Activity

The service automatically:

- Monitors CPU, memory, disk, and process metrics
- Detects statistical anomalies in system behavior
- Generates comprehensive system reports
- Sends notifications when issues are detected
- Maintains historical data for trend analysis

**📖 For detailed monitoring service documentation, see: [Monitoring Service Guide](monitoring-service.md)**

This covers service management, configuration options, troubleshooting, best practices, and advanced features.

## Advanced Features

ServerSentry v2 includes enterprise-grade features across three phases:

### Phase 1 - Foundation Enhancement

- ✅ **Generic Webhook System** - Flexible HTTP endpoint integration
- ✅ **Notification Templates** - Customizable message formatting
- ✅ **Enhanced CLI** - Color-coded output and improved usability
- ✅ **Template Management** - Create, validate, and test templates

### Phase 2 - Advanced Features

- ✅ **Composite Checks** - Multi-metric logical conditions
- ✅ **Plugin Health Tracking** - Performance monitoring and versioning
- ✅ **Dynamic Configuration Reload** - No-restart configuration updates

### Phase 3 - Intelligence Layer

- ✅ **Statistical Anomaly Detection** - Z-score analysis and pattern recognition
- ✅ **Advanced TUI Dashboard** - Real-time 7-screen interface
- ✅ **Comprehensive Self-Diagnostics** - System health validation

## Configuration

### Main Configuration File

Location: `config/serversentry.yaml`

```yaml
# Core Settings
enabled: true
log_level: info # debug, info, warning, error
check_interval: 60 # seconds

# Plugin Configuration
plugins:
  enabled: [cpu, memory, disk, process]
  cpu_threshold: 85
  memory_threshold: 90
  disk_threshold: 90

# Notification Settings
notifications:
  enabled: true
  providers: [teams, webhook]
  default_template: "default"

# Advanced Features
anomaly_detection:
  enabled: true
  default_sensitivity: 2.0
  window_size: 20

composite_checks:
  enabled: true

# TUI Settings
tui:
  auto_refresh: true
  refresh_interval: 2
  simple_mode: false

# Diagnostics
diagnostics:
  enabled: true
  auto_cleanup_days: 30
```

### Configuration Management Commands

```bash
# View current configuration
serversentry list-thresholds

# Update specific threshold
serversentry update-threshold cpu_threshold=80

# Reload configuration without restart
serversentry reload config

# Validate configuration
serversentry diagnostics run
```

## Monitoring Plugins

### Core Plugins Overview

| Plugin      | Metrics               | Default Thresholds          | Anomaly Support       |
| ----------- | --------------------- | --------------------------- | --------------------- |
| **CPU**     | Usage %, Load Average | Warning: 75%, Critical: 85% | ✅ Trends, Spikes     |
| **Memory**  | RAM %, Swap %         | Warning: 80%, Critical: 90% | ✅ Patterns, Outliers |
| **Disk**    | Space %, Inodes       | Warning: 80%, Critical: 90% | ✅ Trends Only        |
| **Process** | Count, Status         | Custom per process          | ✅ Process Changes    |

### CPU Plugin

**Configuration:** `config/plugins/cpu.conf`

```bash
# Thresholds
cpu_threshold=85                # Critical threshold
cpu_warning_threshold=75        # Warning threshold
cpu_check_interval=30          # Check frequency (seconds)

# Anomaly detection
cpu_anomaly_enabled=true
cpu_anomaly_sensitivity=2.0
cpu_detect_trends=true
cpu_detect_spikes=true
```

**Usage:**

```bash
serversentry check cpu           # Manual check
serversentry anomaly config cpu  # Configure anomaly detection
```

### Memory Plugin

**Configuration:** `config/plugins/memory.conf`

```bash
# Thresholds
memory_threshold=90
memory_warning_threshold=80
memory_include_swap=true        # Include swap in calculations
memory_check_interval=30

# Anomaly detection
memory_anomaly_enabled=true
memory_anomaly_sensitivity=1.8  # More sensitive than CPU
```

### Disk Plugin

**Configuration:** `config/plugins/disk.conf`

```bash
# Monitoring settings
disk_threshold=90
disk_warning_threshold=80
disk_monitored_paths="/"        # Space-separated paths
disk_check_inodes=true         # Monitor inode usage

# Anomaly detection
disk_anomaly_enabled=true
disk_detect_spikes=false       # Disk spikes often normal
disk_detect_trends=true        # Monitor growing usage
```

### Process Plugin

**Configuration:** `config/plugins/process.conf`

```bash
# Monitored processes
process_monitored_processes="sshd,nginx,mysql"
process_require_all=false      # false = alert if ANY missing
process_check_interval=60

# Process-specific settings
process_sshd_required=true
process_nginx_min_count=1
process_mysql_max_count=5
```

## Notification System

### Supported Providers

ServerSentry v2 supports 5 notification providers:

1. **Microsoft Teams** - Rich cards with metrics
2. **Slack** - Formatted messages with channel routing
3. **Discord** - Embedded messages with color coding
4. **Email** - HTML/text emails with reports
5. **Generic Webhooks** - JSON payloads for custom integrations

### Configuration

#### Microsoft Teams

**Configuration:** `config/notifications/teams.conf`

```bash
teams_webhook_url="https://your-teams-webhook-url"
teams_enabled=true
teams_template="teams_default"
teams_timeout=30
```

#### Slack

**Configuration:** `config/notifications/slack.conf`

```bash
slack_webhook_url="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
slack_channel="#monitoring"
slack_username="ServerSentry"
slack_enabled=true
```

#### Discord

**Configuration:** `config/notifications/discord.conf`

```bash
discord_webhook_url="https://discord.com/api/webhooks/YOUR/WEBHOOK"
discord_username="ServerSentry"
discord_avatar_url=""
discord_enabled=true
```

#### Email

**Configuration:** `config/notifications/email.conf`

```bash
email_smtp_server="smtp.gmail.com"
email_smtp_port=587
email_username="your-email@gmail.com"
email_password="your-app-password"
email_from="serversentry@yourdomain.com"
email_to="admin@yourdomain.com"
email_enabled=true
```

#### Generic Webhooks

**Configuration:** `config/notifications/webhook.conf`

```bash
webhook_url="https://your-api-endpoint.com/webhook"
webhook_method="POST"
webhook_headers="Content-Type: application/json"
webhook_timeout=30
webhook_enabled=true
```

### Webhook Management

```bash
# Add webhook
serversentry webhook add https://your-webhook-url.com/endpoint

# Test webhooks
serversentry webhook test

# List configured webhooks
serversentry webhook list

# Check webhook status
serversentry webhook status

# Remove webhook
serversentry webhook remove 1
```

### Template System

#### Available Templates

```bash
# List templates
serversentry template list

# Test template generation
serversentry template test teams alert
serversentry template test webhook test

# Create custom template
serversentry template create my_alert teams

# Validate template
serversentry template validate config/templates/my_template.template
```

#### Template Variables

Available variables in templates:

```bash
{hostname}          # Server hostname
{timestamp}         # Alert timestamp
{plugin_name}       # Triggering plugin name
{status_message}    # Alert description
{status_text}       # OK/WARNING/CRITICAL
{current_value}     # Current metric value
{threshold}         # Configured threshold
{metrics}           # JSON metrics data
{anomaly_type}      # Anomaly classification (if applicable)
{composite_rule}    # Composite check rule (if applicable)
```

#### Custom Template Example

**File:** `config/templates/teams_custom.template`

```
**{status_text} Alert from {hostname}**

🔍 **Plugin:** {plugin_name}
📊 **Current Value:** {current_value}
⚠️ **Threshold:** {threshold}
🕒 **Time:** {timestamp}

**Message:** {status_message}

---
*ServerSentry v2 - Enterprise Monitoring*
```

## Anomaly Detection

ServerSentry v2 includes advanced statistical anomaly detection using Z-score analysis, pattern recognition, and trend detection.

### How It Works

1. **Data Collection:** Historical metrics stored (up to 1000 data points)
2. **Statistical Analysis:** Z-score calculations with configurable sensitivity
3. **Pattern Recognition:** Trend analysis using linear regression
4. **Spike Detection:** Sudden change identification (3σ threshold)
5. **Smart Notifications:** Consecutive anomaly thresholds with cooldowns

### Configuration

#### Default Configurations

**CPU Anomaly Detection:**

```bash
# config/anomaly/cpu_anomaly.conf
plugin="cpu"
enabled=true
sensitivity=2.0                  # Standard deviations
window_size=20                   # Analysis window
detect_trends=true
detect_spikes=true
notification_threshold=3         # Consecutive anomalies
cooldown=1800                   # 30 minutes
```

**Memory Anomaly Detection:**

```bash
# config/anomaly/memory_anomaly.conf
plugin="memory"
enabled=true
sensitivity=1.8                  # More sensitive
window_size=25
detect_trends=true
detect_spikes=true
notification_threshold=2
cooldown=1200                   # 20 minutes
```

### Anomaly Detection Commands

```bash
# List anomaly configurations
serversentry anomaly list

# Test anomaly detection
serversentry anomaly test

# View anomaly summary
serversentry anomaly summary        # Last 7 days
serversentry anomaly summary 14     # Last 14 days

# Configure anomaly detection
serversentry anomaly config cpu     # Edit CPU config
serversentry anomaly config memory  # Edit memory config

# Enable/disable anomaly detection
serversentry anomaly enable cpu
serversentry anomaly disable disk
```

### Understanding Anomaly Types

**Statistical Outliers:**

- `high_outlier` - Value significantly above normal range
- `low_outlier` - Value significantly below normal range

**Pattern Anomalies:**

- `steep_upward_trend` - Rapid increasing pattern
- `steep_downward_trend` - Rapid decreasing pattern
- `positive_spike` - Sudden sharp increase
- `negative_spike` - Sudden sharp decrease

### Anomaly Response

When anomalies are detected:

1. **Logged** - Recorded in `logs/anomaly/results/`
2. **Analyzed** - Consecutive anomaly counting
3. **Notified** - Alerts sent based on thresholds
4. **Cooled Down** - Prevents notification spam

## Composite Checks

Composite checks allow complex multi-metric conditions using logical operators.

### Composite Check Rules

**Syntax:**

```bash
"<metric1> <operator> <value> <logical> <metric2> <operator> <value>"
```

**Examples:**

```bash
# High resource usage
"cpu.value > 80 AND memory.value > 85"

# Critical alert conditions
"(cpu.value > 90 OR memory.value > 95) AND disk.value > 90"

# Emergency conditions
"cpu.value > 95 OR memory.value > 98 OR disk.value > 95"

# Complex business logic
"cpu.value > 70 AND memory.value > 80 AND disk.value < 95"
```

### Composite Check Configuration

**Default Configurations:**

```bash
# config/composite/critical_resources.conf
name="critical_resources"
description="Critical resource usage alert"
enabled=true
rule="cpu.value > 90 AND memory.value > 95"
severity=2
cooldown=600
notify_on_trigger=true
notify_on_recovery=false
```

### Composite Check Commands

```bash
# List composite checks
serversentry composite list

# Test composite checks
serversentry composite test
serversentry composite test critical_resources  # Test specific check

# Create composite check
serversentry composite create high_load "cpu.value > 80 AND memory.value > 85"

# Enable/disable composite checks
serversentry composite enable high_load
serversentry composite disable critical_resources
```

### Advanced Composite Logic

**Supported Operators:**

- Comparison: `>`, `<`, `>=`, `<=`, `==`, `!=`
- Logical: `AND`, `OR`, `NOT`
- Grouping: `(`, `)`

**Available Metrics:**

- `cpu.value` - CPU usage percentage
- `memory.value` - Memory usage percentage
- `disk.value` - Disk usage percentage
- `process.count` - Process count

## System Diagnostics

Comprehensive system health checking with detailed reporting.

### Diagnostic Categories

1. **System Health** - Disk, memory, load average
2. **Configuration** - YAML syntax, required fields, permissions
3. **Dependencies** - Required/optional commands
4. **Performance** - Plugin execution times
5. **Plugins** - Plugin availability and functionality

### Diagnostic Commands

```bash
# Full system diagnostics
serversentry diagnostics run

# Quick health check
serversentry diagnostics quick

# View diagnostic summary
serversentry diagnostics summary
serversentry diagnostics summary 14    # Last 14 days

# Manage diagnostic reports
serversentry diagnostics reports       # List reports
serversentry diagnostics view         # View latest report
serversentry diagnostics view report.json  # View specific report

# Configuration and maintenance
serversentry diagnostics config       # Edit diagnostics config
serversentry diagnostics cleanup      # Clean old reports
serversentry diagnostics cleanup 60   # Clean reports older than 60 days
```

### Diagnostic Levels

**Severity Levels:**

- **INFO (0)** - Informational, no action needed
- **WARNING (1)** - Attention recommended
- **ERROR (2)** - Action required
- **CRITICAL (3)** - Immediate action required

### Diagnostic Configuration

**Configuration:** `config/diagnostics.conf`

```bash
# Diagnostic categories
check_system_health=true
check_configuration=true
check_dependencies=true
check_performance=true
check_plugins=true

# Performance thresholds
cpu_threshold_warning=80
memory_threshold_warning=85
disk_threshold_warning=90

# Report settings
generate_detailed_reports=true
keep_reports_days=30
compress_old_reports=true
```

### Understanding Diagnostic Reports

**Report Structure:**

```json
{
  "diagnostic_run": {
    "timestamp": "2024-11-24T07:45:00Z",
    "hostname": "server01"
  },
  "results": {
    "system_health": {...},
    "configuration": {...},
    "dependencies": {...}
  },
  "summary": {
    "total_checks": 15,
    "passed": 12,
    "warnings": 2,
    "errors": 1,
    "critical": 0
  }
}
```

## TUI Dashboard

The Text-based User Interface provides a real-time monitoring dashboard.

### Launching the TUI

```bash
# Launch advanced TUI (default)
serversentry tui

# Force simple TUI mode
SERVERSENTRY_SIMPLE_TUI=true serversentry tui
```

### TUI Navigation

**Screen Navigation:**

- `[1]` - Dashboard (overview with metrics)
- `[2]` - Plugins (plugin status and health)
- `[3]` - Composite (composite check rules)
- `[4]` - Anomaly (anomaly detection status)
- `[5]` - Notifications (notification providers)
- `[6]` - Logs (system logs)
- `[7]` - Config (configuration viewer)

**Controls:**

- `[r]` - Manual refresh
- `[a]` - Toggle auto-refresh (2-second interval)
- `[e]` - Edit configuration (config screen only)
- `[q]` - Quit TUI
- `Ctrl+C` - Emergency exit

### TUI Features

**Real-time Dashboard:**

- System status indicators with color coding
- Visual progress bars for resource usage
- Plugin health summary (good/warning/error counts)
- Recent activity log display

**Visual Elements:**

```
CPU:    [████████████░░░░░░░░] 60%  ✅
Memory: [███████████████████░] 95%  ⚠️
Disk:   [████████░░░░░░░░░░░░] 40%  ✅
```

**Status Indicators:**

- 🟢 ● Running/OK
- 🟡 ● Warning
- 🔴 ● Error/Critical
- ✅ Success
- ⚠️ Warning
- ❌ Error

## Troubleshooting

### Common Issues

#### 1. Command Not Found

```bash
# Ensure executable permissions
chmod +x bin/serversentry

# Add to PATH or use full path
./bin/serversentry status
```

#### 2. Plugin Checks Failing

```bash
# Check plugin availability
serversentry list

# Run diagnostics
serversentry diagnostics quick

# Check individual plugin
serversentry check cpu -v
```

#### 3. Notifications Not Working

```bash
# Test notification providers
serversentry webhook test
serversentry template test teams alert

# Check notification configuration
serversentry webhook status
serversentry template list
```

#### 4. TUI Not Working

```bash
# Use simple TUI mode
SERVERSENTRY_SIMPLE_TUI=true serversentry tui

# Check terminal compatibility
echo $TERM
tput cols  # Should show terminal width
```

#### 5. Anomaly Detection Issues

```bash
# Check anomaly configuration
serversentry anomaly list

# Test anomaly detection
serversentry anomaly test

# View anomaly logs
cat logs/anomaly/results/*.log
```

### Diagnostic Commands

```bash
# Check system requirements
serversentry diagnostics quick

# Verify configuration
serversentry list-thresholds

# Check log files
serversentry logs view

# Verbose output for debugging
serversentry -v status
serversentry -d check cpu  # Debug mode
```

### Log Files

**Important log locations:**

- `logs/serversentry.log` - Main application log
- `logs/anomaly/` - Anomaly detection data and results
- `logs/diagnostics/` - Diagnostic reports
- `logs/notifications.log` - Notification system log
- `logs/tui.log` - TUI interface log

## Best Practices

### Production Deployment

1. **Configure Monitoring:**

   ```bash
   # Set appropriate thresholds
   serversentry update-threshold cpu_threshold=80
   serversentry update-threshold memory_threshold=85

   # Enable anomaly detection
   serversentry anomaly enable cpu
   serversentry anomaly enable memory
   ```

2. **Set Up Notifications:**

   ```bash
   # Configure primary notification channel
   serversentry webhook add https://your-monitoring-webhook.com

   # Test notifications
   serversentry webhook test
   ```

3. **Schedule Regular Diagnostics:**
   ```bash
   # Add to cron for daily diagnostics
   echo "0 6 * * * /path/to/serversentry diagnostics run" | crontab -
   ```

### Performance Optimization

1. **Adjust Check Intervals:**

   ```yaml
   # config/serversentry.yaml
   check_interval: 60 # Increase for less frequent checks
   ```

2. **Configure Anomaly Windows:**

   ```bash
   # Smaller windows for faster response
   window_size=15

   # Larger windows for stability
   window_size=30
   ```

3. **Optimize Notifications:**

   ```bash
   # Increase cooldown to reduce spam
   cooldown=3600  # 1 hour

   # Increase consecutive threshold
   notification_threshold=5
   ```

### Security Considerations

1. **File Permissions:**

   ```bash
   # Secure configuration files
   chmod 600 config/notifications/*.conf

   # Secure log directory
   chmod 755 logs/
   ```

2. **Webhook Security:**

   - Use HTTPS endpoints only
   - Implement webhook authentication
   - Configure appropriate timeouts

3. **Data Privacy:**
   - Regular log cleanup
   - Secure credential storage
   - Network traffic encryption

### Monitoring Strategy

1. **Layered Approach:**

   - Basic thresholds for immediate alerts
   - Anomaly detection for pattern analysis
   - Composite checks for complex conditions

2. **Alert Fatigue Prevention:**

   - Appropriate cooldown periods
   - Consecutive alert thresholds
   - Severity-based notification routing

3. **Historical Analysis:**
   - Regular diagnostic reporting
   - Anomaly trend analysis
   - Performance baseline establishment

---

**ServerSentry v2 User Documentation** - Complete guide for enterprise-grade monitoring with statistical intelligence.

For additional support:

- Developer Guide: `docs/developer/README.md`
- API Reference: `docs/api/README.md`
- GitHub Issues: Create issue for bugs or feature requests
