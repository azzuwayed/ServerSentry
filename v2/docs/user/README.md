# ServerSentry v2 User Documentation

Welcome to the ServerSentry v2 user documentation. This guide will help you understand how to use and configure ServerSentry to monitor your systems effectively.

## Table of Contents

1. [Installation](#installation)
2. [Getting Started](#getting-started)
3. [Configuration](#configuration)
4. [Commands](#commands)
5. [Plugins](#plugins)
6. [Notifications](#notifications)
7. [Troubleshooting](#troubleshooting)

## Installation

To install ServerSentry v2, follow these steps:

```bash
# Clone the repository
git clone https://github.com/yourusername/ServerSentry.git

# Navigate to the ServerSentry directory
cd ServerSentry/v2

# Make the main script executable
chmod +x bin/serversentry

# Add to your PATH (optional)
echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
source ~/.bashrc
```

## Getting Started

Once installed, you can start using ServerSentry right away:

```bash
# Check the status of your system
serversentry status

# List available plugins
serversentry list

# Check a specific component
serversentry check cpu
```

## Configuration

ServerSentry uses YAML configuration files located in the `config/` directory:

- `serversentry.yaml`: Main configuration file
- `plugins/`: Plugin-specific configurations
- `notifications/`: Notification provider configurations

### Main Configuration

The main configuration file (`config/serversentry.yaml`) contains the following settings:

```yaml
# General settings
log_level: info
check_interval: 60

# Notification settings
notification_enabled: true
notification_channels: [teams]

# Plugin settings
plugins_enabled: [cpu, memory, disk]
```

## Commands

ServerSentry supports the following commands:

- `status`: Show current status of all monitors
- `start`: Start monitoring in background
- `stop`: Stop monitoring
- `check [plugin]`: Run a specific plugin check (or all if not specified)
- `list`: List available plugins
- `configure`: Configure ServerSentry
- `logs`: View or manage logs
- `version`: Show version information
- `help`: Show help message

## Plugins

ServerSentry comes with several built-in plugins:

- **CPU**: Monitors CPU usage
- **Memory**: Monitors memory usage
- **Disk**: Monitors disk space
- **Process**: Monitors running processes

Each plugin has its own configuration file in the `config/plugins/` directory.

### CPU Plugin

The CPU plugin monitors CPU usage and alerts when it exceeds thresholds:

```bash
# config/plugins/cpu.conf
cpu_threshold=85       # Critical threshold
cpu_warning_threshold=75  # Warning threshold
```

### Memory Plugin

The Memory plugin monitors memory usage:

```bash
# config/plugins/memory.conf
memory_threshold=90
memory_warning_threshold=80
memory_include_swap=true
```

### Disk Plugin

The Disk plugin monitors disk space:

```bash
# config/plugins/disk.conf
disk_threshold=90
disk_warning_threshold=80
disk_monitored_paths="/"
```

### Process Plugin

The Process plugin monitors critical processes:

```bash
# config/plugins/process.conf
process_monitored_processes="sshd,nginx,mysql"
```

## Notifications

ServerSentry can send notifications when monitoring thresholds are exceeded. Supported notification channels include:

- **Teams**: Microsoft Teams webhooks
- **Slack**: Slack webhooks
- **Discord**: Discord webhooks
- **Email**: Email notifications

### Configuring Notifications

To enable notifications, update the main configuration file:

```yaml
notification_enabled: true
notification_channels: [teams]
```

Then configure each notification provider in the `config/notifications/` directory.

## Troubleshooting

If you encounter issues with ServerSentry, check the following:

1. **Logs**: Check the logs in the `logs/` directory
2. **Permissions**: Ensure the script has necessary permissions
3. **Dependencies**: Verify all required commands are available
4. **Configuration**: Check configuration files for errors

For more detailed information, run commands with verbose output:

```bash
serversentry -v status
```

## Getting Help

If you need further assistance, please:

1. Check the documentation
2. Run `serversentry help`
3. Report issues on GitHub
