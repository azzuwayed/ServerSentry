# ServerSentry - Enhanced System Monitoring & Alert Tool

ServerSentry is a robust Bash-based system monitoring solution that tracks critical system resources and sends detailed notifications when predefined thresholds are exceeded. It's designed to work seamlessly across different Linux and macOS environments with minimal dependencies.

## Features

- **Comprehensive Monitoring**: Tracks CPU, memory, disk usage, and critical processes
- **Cross-platform Compatibility**: Works on Linux and macOS systems
- **Real-time Alerts**: Sends notifications when resources exceed configurable thresholds
- **Rich Webhook Integration**: Supports Microsoft Teams, Slack, Discord, and generic webhooks
- **Adaptive Cards**: Provides visually appealing, interactive notifications (especially for Teams)
- **Process Monitoring**: Ensures critical services stay running
- **Detailed Reporting**: Generates rich system health reports with visual indicators
- **User-friendly CLI**: Simple command-line interface for all operations
- **Modular Architecture**: Well-organized codebase for easy maintenance and extensibility
- **Automatic Resource Detection**: Smart detection of system metrics across different environments

## Requirements

- Bash shell (version 4+)
- Basic system utilities (ps, free, df, etc.)
- cURL for webhook notifications
- jq for enhanced JSON processing (recommended but optional)
- cron for scheduling (optional)

## Installation

1. Clone or download this repository
2. Run the installation script:

```bash
chmod +x install.sh
./install.sh
```

The installation script handles dependency checks, setting permissions, creating configuration files, and optionally setting up cron jobs.

## Usage

```bash
./serversentry.sh --help             # Show help message
./serversentry.sh --check            # Perform a one-time system check
./serversentry.sh --monitor          # Start monitoring in foreground
./serversentry.sh --status           # Show current status and configuration
./serversentry.sh --test-webhook     # Test webhook notifications
./serversentry.sh --add-webhook URL  # Add a new webhook endpoint
./serversentry.sh --remove-webhook N # Remove webhook number N
./serversentry.sh --update NAME=VAL  # Update threshold (e.g., cpu_threshold=85)
./serversentry.sh --list             # List all thresholds and webhooks
```

### Configuration

ServerSentry uses two configuration files in the `config` directory:

1. `thresholds.conf`: Defines alert thresholds for different resources

   - `cpu_threshold`: CPU usage percentage threshold (default: 80)
   - `memory_threshold`: Memory usage percentage threshold (default: 80)
   - `disk_threshold`: Disk usage percentage threshold (default: 85)
   - `load_threshold`: System load average threshold (default: 2.0)
   - `check_interval`: Seconds between checks when monitoring (default: 60)
   - `process_checks`: Comma-separated list of process names to monitor

2. `webhooks.conf`: Contains webhook URLs for notifications (one per line)

### Setting Up Automated Monitoring

To run ServerSentry checks automatically, set up a cron job during installation or manually:

```bash
# Run ServerSentry check every 5 minutes
*/5 * * * * /path/to/serversentry.sh --check >> /path/to/serversentry.log 2>&1
```

## Microsoft Teams Integration

ServerSentry offers enhanced support for Microsoft Teams with rich Adaptive Cards. See the detailed setup guide:

```bash
cat TEAMS_SETUP.md
```

Key Teams integration features:

- Interactive Adaptive Cards with system metrics
- Visual progress bars for resource usage
- Color-coded alerts based on severity
- Collapsible system details
- Comprehensive system information

## Webhook Support

ServerSentry intelligently formats webhook payloads for:

- Microsoft Teams (with Adaptive Cards)
- Slack
- Discord
- Generic JSON webhooks

To add a webhook:

```bash
./serversentry.sh --add-webhook https://your-webhook-url
```

## Customizing Thresholds

Easily configure ServerSentry for your specific environment:

```bash
./serversentry.sh --update cpu_threshold=90
./serversentry.sh --update memory_threshold=85
./serversentry.sh --update disk_threshold=90
./serversentry.sh --update load_threshold=3.0
./serversentry.sh --update check_interval=300  # Check every 5 minutes
./serversentry.sh --update process_checks=nginx,mysql,apache2
```

## Architecture

ServerSentry uses a modular design with components in the `lib` directory:

- `utils.sh`: Common utility functions
- `config.sh`: Configuration management
- `monitor.sh`: System resource monitoring
- `notify.sh`: Notification handling with webhook support

## Troubleshooting

- If notifications aren't working, use `--test-webhook` to verify configuration
- Check the log file at `./serversentry.log` for error messages
- Ensure curl is installed for webhook functionality
- For more comprehensive Teams integration help, see TEAMS_SETUP.md

## License

This project is licensed under the MIT License.
