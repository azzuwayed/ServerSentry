# ServerSentry v2 - User Manual

📖 **Comprehensive User Guide for ServerSentry v2**

This manual provides complete instructions for installing, configuring, and using ServerSentry v2 for server monitoring and alerting.

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Basic Usage](#basic-usage)
5. [Configuration](#configuration)
6. [Monitoring Features](#monitoring-features)
7. [Notifications](#notifications)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)

## Overview

ServerSentry v2 is an enterprise-grade server monitoring solution that provides:

- **Real-time system monitoring** (CPU, memory, disk, processes)
- **Statistical anomaly detection** with intelligent alerting
- **Multi-channel notifications** (Teams, Slack, Discord, Email, Webhooks)
- **Comprehensive diagnostics** and health checking
- **Modular plugin architecture** for extensibility

### Key Benefits

- **Intelligent Monitoring**: Goes beyond simple thresholds with statistical analysis
- **Enterprise Ready**: Production-grade performance with <2% CPU overhead
- **Easy Setup**: Simple installation with minimal dependencies
- **Flexible Alerting**: Multiple notification channels with customizable templates

## Installation

### System Requirements

- **Bash 5.0+** (check with `bash --version`)
- **Basic Unix utilities** (standard on most systems)
- **jq** (recommended for JSON processing)
- **curl** (for webhook notifications)

### Installation Steps

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/ServerSentry.git
   cd ServerSentry
   ```

2. **Make executable:**

   ```bash
   chmod +x bin/serversentry
   ```

3. **Optional: Add to PATH:**

   ```bash
   echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Verify installation:**
   ```bash
   ./bin/serversentry version
   ```

## Quick Start

### 1. Check System Status

```bash
serversentry status
```

### 2. Run Initial Diagnostics

```bash
serversentry diagnostics run
```

### 3. Configure Basic Settings

```bash
serversentry configure
```

### 4. Start Monitoring

```bash
serversentry start
```

**📋 For detailed information about how the monitoring service works internally, including the monitoring loop, daemon behavior, and production best practices, see the [Monitoring Service Guide](monitoring-service.md).**

## Basic Usage

### Essential Commands

```bash
# System status and monitoring
serversentry status                 # Check current system status
serversentry start                  # Start monitoring daemon
serversentry stop                   # Stop monitoring daemon

# Plugin management
serversentry check                  # Run all plugin checks
serversentry check cpu              # Run specific plugin check
serversentry list                   # List available plugins

# Configuration
serversentry configure              # Interactive configuration
serversentry list-thresholds        # View current thresholds
serversentry update-threshold cpu_threshold=85

# Diagnostics and health
serversentry diagnostics run        # Full system diagnostics
serversentry diagnostics quick      # Quick health check

# Logs and monitoring
serversentry logs view              # View recent logs
serversentry logs cleanup           # Clean up old logs
```

### Understanding Status Output

The `serversentry status` command shows:

- **Service Status**: Whether monitoring daemon is running
- **Plugin Results**: Status of each monitoring plugin
- **Resource Usage**: Current CPU, memory, and disk usage
- **Alert Status**: Any active alerts or warnings

## Configuration

### Main Configuration File

ServerSentry uses YAML configuration in `config/serversentry.yaml`:

```yaml
# Core System Settings
system:
  enabled: true
  log_level: info
  check_interval: 60
  check_timeout: 30
  max_log_size: 10485760
  max_log_archives: 10

# Plugin Configuration
plugins:
  enabled: [cpu, memory, disk, process]
  directory: lib/plugins
  config_directory: config/plugins

# Notification System
notifications:
  enabled: true
  channels: [teams, email]
  teams:
    webhook_url: "your_teams_webhook_url"
  email:
    smtp_server: "localhost"
    smtp_port: 25
    from_address: "serversentry@yourcompany.com"

# Anomaly Detection
anomaly_detection:
  enabled: true
  sensitivity: medium
  data_points: 100
  retention_days: 30
```

### Plugin Configuration

Individual plugins can be configured in `config/plugins/`:

```bash
# config/plugins/cpu.conf
cpu_warning_threshold=80
cpu_critical_threshold=95
cpu_check_interval=30

# config/plugins/memory.conf
memory_warning_threshold=85
memory_critical_threshold=95
include_swap=true

# config/plugins/disk.conf
disk_warning_threshold=90
disk_critical_threshold=98
monitored_paths=/,/var,/tmp
```

## Monitoring Features

### Core Plugins

#### CPU Monitoring

- **Metrics**: CPU usage percentage, load average
- **Thresholds**: Warning and critical levels
- **Alerts**: High CPU usage, load spikes

#### Memory Monitoring

- **Metrics**: RAM usage, swap usage, available memory
- **Thresholds**: Configurable warning/critical levels
- **Alerts**: Memory exhaustion warnings

#### Disk Monitoring

- **Metrics**: Disk usage percentage, available space
- **Paths**: Monitor multiple mount points
- **Alerts**: Disk space warnings

#### Process Monitoring

- **Metrics**: Process status, resource usage
- **Tracking**: Critical process availability
- **Alerts**: Process failure notifications

### Anomaly Detection

ServerSentry includes statistical anomaly detection:

```bash
# Configure anomaly detection
serversentry anomaly config

# View anomaly status
serversentry anomaly list

# Test anomaly detection
serversentry anomaly test

# View anomaly summary
serversentry anomaly summary 7  # Last 7 days
```

**Anomaly Types:**

- **Statistical outliers**: Values beyond normal ranges
- **Trend changes**: Sudden changes in patterns
- **Spike detection**: Unusual spikes in metrics

## Notifications

### Supported Providers

#### Microsoft Teams

```bash
# Configure Teams webhook
serversentry configure
# Enter Teams webhook URL when prompted
```

#### Slack

```bash
# Set Slack webhook in configuration
# config/notifications/slack.conf
webhook_url=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
channel=#monitoring
username=ServerSentry
```

#### Discord

```bash
# Configure Discord webhook
# config/notifications/discord.conf
webhook_url=https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK
```

#### Email (SMTP)

```bash
# Configure email notifications
# config/notifications/email.conf
smtp_server=mail.yourcompany.com
smtp_port=587
smtp_username=monitoring@yourcompany.com
smtp_password=your_password
```

### Testing Notifications

```bash
# Test all notification providers
serversentry webhook test

# Test specific provider
serversentry template test teams alert
```

## Advanced Features

### Composite Checks

Create complex monitoring rules:

```bash
# List composite checks
serversentry composite list

# Create custom composite check
serversentry composite create high_load "cpu.value > 90 AND memory.value > 85"

# Test composite checks
serversentry composite test
```

### System Diagnostics

Comprehensive system health checking:

```bash
# Full diagnostics
serversentry diagnostics run

# Quick health check
serversentry diagnostics quick

# View diagnostic reports
serversentry diagnostics reports

# Clean up old reports
serversentry diagnostics cleanup 30
```

### Template System

Customize notification messages:

```bash
# List available templates
serversentry template list

# Create custom template
serversentry template create my_alert teams

# Validate template
serversentry template validate /path/to/template
```

### Performance Monitoring

Monitor ServerSentry itself:

```bash
# View performance statistics
serversentry diagnostics performance

# Monitor system impact
top -p $(cat serversentry.pid)
```

## Troubleshooting

### Common Issues

#### 1. Service Won't Start

```bash
# Check for errors
serversentry diagnostics run

# View logs
serversentry logs view

# Check permissions
ls -la bin/serversentry
```

#### 2. Notifications Not Working

```bash
# Test notification configuration
serversentry webhook test

# Check notification logs
grep -i notification logs/*.log

# Validate configuration
serversentry diagnostics config
```

#### 3. High Resource Usage

```bash
# Check performance
serversentry diagnostics performance

# Adjust check interval
serversentry update-threshold check_interval=120

# Disable unnecessary plugins
serversentry configure
```

#### 4. Plugin Failures

```bash
# Check plugin status
serversentry list

# Test specific plugin
serversentry check cpu

# View plugin logs
grep -i plugin logs/*.log
```

### Log Analysis

```bash
# View recent activity
tail -f logs/serversentry.log

# Search for errors
grep -i error logs/*.log

# Check specific timeframe
grep "2024-12-" logs/serversentry.log
```

### Performance Optimization

```bash
# Reduce check frequency
export MONITOR_INTERVAL=120
serversentry start

# Disable unused features
# Edit config/serversentry.yaml
anomaly_detection:
  enabled: false
```

---

**📞 Need Help?**

- Check [Troubleshooting Guide](troubleshooting.md)
- Review [Configuration Guide](configuration.md)
- See [CLI Reference](cli-reference.md) for complete command documentation
