# ServerSentry - System Monitoring & Alert Tool

ServerSentry is a lightweight, yet robust Bash-based system monitoring tool that tracks various system resources and sends webhook notifications when issues are detected. It's designed to work across different Linux environments with minimal dependencies.

## Features

- Monitor critical system resources (CPU, memory, disk usage)
- Track process statuses and service health
- Set configurable thresholds for alerts
- Send webhook notifications when thresholds are exceeded (supports Slack, Discord, and more)
- Generate detailed system health logs for troubleshooting
- Support for multiple webhook endpoints
- User-friendly command-line interface for configuration
- Adaptive resource detection for compatibility across different systems

## Requirements

- Bash shell (version 4+)
- Basic Linux utilities (ps, free, df, etc.)
- cURL for webhook notifications
- awk for calculations (included in most Linux distributions)
- jq for advanced JSON processing (optional)
- cron for scheduling (optional)

## Installation

1. Clone or download this repository to your server
2. Run the installation script:

```bash
chmod +x install.sh
./install.sh
```

## Usage

ServerSentry provides a variety of command-line options to control its operation:

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

ServerSentry uses two configuration files located in the `config` directory:

1. `thresholds.conf`: Defines alert thresholds for different resources
   - `cpu_threshold`: CPU usage percentage threshold (default: 80)
   - `memory_threshold`: Memory usage percentage threshold (default: 80)
   - `disk_threshold`: Disk usage percentage threshold (default: 85)
   - `check_interval`: Seconds between checks when monitoring (default: 60)
   - `process_checks`: Comma-separated list of process names to monitor

2. `webhooks.conf`: Contains the webhook URLs for notifications
   - Add one URL per line
   - Supports special formatting for Slack, Discord, and other services

### Setting Up Automated Monitoring

For continuous monitoring, you can set up a cron job during installation or manually:

```bash
# Run ServerSentry check every 5 minutes
*/5 * * * * /path/to/serversentry.sh --check >> /path/to/serversentry.log 2>&1
```

## Webhook Integration

ServerSentry supports various webhook services, and automatically formats payloads for:

- Slack
- Discord
- Microsoft Teams
- Generic JSON webhooks

To add a webhook:

```bash
./serversentry.sh --add-webhook https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

## Customizing Thresholds

Set custom thresholds based on your server's requirements:

```bash
./serversentry.sh --update cpu_threshold=90
./serversentry.sh --update memory_threshold=85
./serversentry.sh --update disk_threshold=90
./serversentry.sh --update check_interval=300  # Check every 5 minutes
./serversentry.sh --update process_checks=nginx,mysql,apache2
```

## Troubleshooting

- If notifications aren't working, test your webhook with `--test-webhook`
- Check the log file at `./serversentry.log` for error messages
- Ensure curl is installed for webhook functionality
- For more accurate CPU metrics, consider installing the sysstat package

## License

This project is licensed under the MIT License - see the LICENSE file for details.
