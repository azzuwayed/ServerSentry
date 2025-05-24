# ServerSentry v2 - Configuration Guide

⚙️ **Complete Configuration Reference for ServerSentry v2**

This guide covers all configuration options, best practices, and advanced settings for ServerSentry.

## Configuration Overview

ServerSentry uses YAML-based configuration with a hierarchical structure for easy management and validation.

### Configuration Files Structure

```
config/
├── serversentry.yaml           # Main configuration
├── plugins/                    # Plugin-specific settings
│   ├── cpu.conf
│   ├── memory.conf
│   ├── disk.conf
│   └── process.conf
├── notifications/              # Notification provider settings
│   ├── teams.conf
│   ├── slack.conf
│   ├── discord.conf
│   ├── email.conf
│   └── webhook.conf
├── anomaly/                    # Anomaly detection configurations
│   ├── cpu_anomaly.conf
│   ├── memory_anomaly.conf
│   └── disk_anomaly.conf
├── composite/                  # Composite check rules
│   ├── critical_resources.conf
│   └── emergency_conditions.conf
└── templates/                  # Notification templates
    ├── teams_default.template
    ├── slack_default.template
    └── email_default.template
```

## Main Configuration (serversentry.yaml)

### Complete Configuration Example

```yaml
# ServerSentry v2 Configuration
# Main configuration file for the ServerSentry monitoring system

# Core System Settings
system:
  enabled: true
  log_level: info # debug, info, warning, error
  check_interval: 60 # seconds between checks
  check_timeout: 30 # seconds before timeout
  max_log_size: 10485760 # 10MB in bytes
  max_log_archives: 10 # number of archived logs to keep

# Plugin Configuration
plugins:
  enabled: [cpu, memory, disk, process]
  directory: lib/plugins
  config_directory: config/plugins

# Notification System
notifications:
  enabled: true
  channels: [teams, email] # enabled notification channels
  default_template: default
  timeout: 30 # notification timeout in seconds

  # Provider-specific settings
  teams:
    webhook_url: "your_teams_webhook_url"
    timeout: 30

  email:
    smtp_server: "localhost"
    smtp_port: 25
    from_address: "serversentry@yourcompany.com"
    to_addresses: ["admin@yourcompany.com"]

  slack:
    webhook_url: "your_slack_webhook_url"
    channel: "#monitoring"
    username: "ServerSentry"

  discord:
    webhook_url: "your_discord_webhook_url"
    username: "ServerSentry"

  webhook:
    enabled: false
    urls: []

# Anomaly Detection
anomaly_detection:
  enabled: true
  sensitivity: medium # low, medium, high, or numeric (1.0-4.0)
  data_points: 100 # historical data points to analyze
  retention_days: 30 # days to keep anomaly data
  min_data_points: 20 # minimum points before analysis

# Composite Checks
composite_checks:
  enabled: true
  config_directory: config/composite
  cooldown_default: 600 # default cooldown in seconds

# TUI (Text User Interface) Settings
tui:
  enabled: true
  auto_refresh: true
  refresh_interval: 2 # seconds
  simple_mode: false # simplified display mode

# Performance Settings
performance:
  enable_caching: true
  cache_duration: 300 # seconds
  optimize_startup: true
  preload_commands: true

# Security Settings
security:
  validate_inputs: true
  sanitize_paths: true
  secure_file_creation: true
  restricted_commands: []

# Advanced Settings
advanced:
  debug_mode: false
  trace_execution: false
  profile_performance: false
  experimental_features: false
```

### Configuration Sections Explained

#### System Settings

Controls core ServerSentry behavior and system-wide settings.

#### Plugin Configuration

Manages which monitoring plugins are enabled and their directories.

#### Notification System

Configures alert delivery through various channels.

#### Anomaly Detection

Controls statistical anomaly detection features.

#### Composite Checks

Manages complex multi-metric monitoring rules.

#### Performance Settings

Optimizes ServerSentry performance and resource usage.

## Plugin Configuration

### CPU Plugin (config/plugins/cpu.conf)

```bash
# CPU Monitoring Configuration
cpu_warning_threshold=80
cpu_critical_threshold=95
cpu_check_interval=30
cpu_include_load_average=true
cpu_load_warning_threshold=2.0
cpu_load_critical_threshold=5.0

# Anomaly detection for CPU
cpu_anomaly_enabled=true
cpu_anomaly_sensitivity=2.0
cpu_detect_trends=true
cpu_detect_spikes=true
```

### Memory Plugin (config/plugins/memory.conf)

```bash
# Memory Monitoring Configuration
memory_warning_threshold=85
memory_critical_threshold=95
memory_include_swap=true
memory_swap_warning_threshold=50
memory_check_interval=30

# Anomaly detection for memory
memory_anomaly_enabled=true
memory_anomaly_sensitivity=1.8
memory_detect_trends=true
memory_detect_spikes=true
```

### Disk Plugin (config/plugins/disk.conf)

```bash
# Disk Monitoring Configuration
disk_warning_threshold=90
disk_critical_threshold=98
disk_monitored_paths="/,/var,/tmp"
disk_check_inodes=true
disk_check_interval=60

# Anomaly detection for disk
disk_anomaly_enabled=true
disk_anomaly_sensitivity=2.5
disk_detect_trends=true
disk_detect_spikes=false
```

### Process Plugin (config/plugins/process.conf)

```bash
# Process Monitoring Configuration
process_monitored_processes="sshd,nginx,mysql"
process_require_all=false
process_check_interval=60

# Process-specific settings
process_sshd_required=true
process_nginx_min_count=1
process_mysql_max_count=5
```

## Notification Configuration

### Teams Notifications (config/notifications/teams.conf)

```bash
teams_enabled=true
teams_webhook_url="https://your-teams-webhook-url"
teams_template="teams_default"
teams_timeout=30
teams_include_metrics=true
```

### Email Notifications (config/notifications/email.conf)

```bash
email_enabled=false
email_smtp_server="smtp.gmail.com"
email_smtp_port=587
email_username="your-email@gmail.com"
email_password="your-app-password"
email_from="serversentry@yourdomain.com"
email_to="admin@yourdomain.com"
email_template="email_default"
email_use_tls=true
```

### Slack Notifications (config/notifications/slack.conf)

```bash
slack_enabled=false
slack_webhook_url="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
slack_channel="#monitoring"
slack_username="ServerSentry"
slack_template="slack_default"
slack_timeout=30
```

## Anomaly Detection Configuration

### CPU Anomaly Detection (config/anomaly/cpu_anomaly.conf)

```bash
plugin="cpu"
enabled=true
sensitivity=2.0
window_size=20
detect_trends=true
detect_spikes=true
notification_threshold=3
cooldown=1800
```

### Memory Anomaly Detection (config/anomaly/memory_anomaly.conf)

```bash
plugin="memory"
enabled=true
sensitivity=1.8
window_size=25
detect_trends=true
detect_spikes=true
notification_threshold=2
cooldown=1200
```

## Composite Check Configuration

### Critical Resources Check (config/composite/critical_resources.conf)

```bash
name="critical_resources"
description="Critical resource usage alert"
enabled=true
rule="cpu.value > 90 AND memory.value > 95"
severity=2
cooldown=600
notify_on_trigger=true
notify_on_recovery=false
```

## Configuration Management

### Interactive Configuration

```bash
# Run configuration wizard
serversentry configure

# Configure specific components
serversentry configure plugins
serversentry configure notifications
serversentry configure anomaly
```

### Command-Line Configuration

```bash
# Update thresholds
serversentry update-threshold cpu_threshold=85
serversentry update-threshold memory_threshold=90

# List current configuration
serversentry list-thresholds

# Validate configuration
serversentry diagnostics config
```

### Configuration Validation

```bash
# Validate YAML syntax
serversentry diagnostics run

# Check configuration consistency
serversentry validate-config

# Test configuration changes
serversentry test-config
```

## Environment Variables

ServerSentry supports environment variable overrides with the `SERVERSENTRY_` prefix:

```bash
# Override main settings
export SERVERSENTRY_SYSTEM_LOG_LEVEL=debug
export SERVERSENTRY_SYSTEM_CHECK_INTERVAL=30

# Override plugin settings
export SERVERSENTRY_PLUGINS_CPU_THRESHOLD=75
export SERVERSENTRY_PLUGINS_MEMORY_THRESHOLD=80

# Override notification settings
export SERVERSENTRY_NOTIFICATIONS_ENABLED=true
export SERVERSENTRY_NOTIFICATIONS_TEAMS_WEBHOOK_URL="https://your-webhook"
```

## Configuration Best Practices

### Production Environments

- Set appropriate thresholds for your workload
- Enable anomaly detection for intelligent alerting
- Configure multiple notification channels for redundancy
- Use composite checks for complex conditions
- Regular configuration backups

### Development Environments

- Lower thresholds for early detection
- Verbose logging for debugging
- Disable notifications or use test channels
- Enable debug features

### Security Considerations

- Secure notification credentials
- Restrict file permissions (600 for config files)
- Use environment variables for sensitive data
- Regular credential rotation

## Troubleshooting Configuration

### Common Configuration Issues

```bash
# Check configuration syntax
serversentry diagnostics config

# Validate YAML files
yaml-lint config/serversentry.yaml

# Test plugin configurations
serversentry check cpu
serversentry check memory
```

### Configuration Backup and Restore

```bash
# Backup configuration
tar -czf serversentry-config-$(date +%Y%m%d).tar.gz config/

# Restore configuration
tar -xzf serversentry-config-backup.tar.gz
```

---

**📍 Next Steps**: After configuration, see [User Manual](manual.md) for usage examples or [Troubleshooting](troubleshooting.md) for common issues.
