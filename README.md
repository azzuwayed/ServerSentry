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
- **Periodic System Reports**: Scheduled system health checks with configurable reporting levels
- **Log Rotation**: Automatic log file management with configurable retention policies

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

### Periodic System Reports

ServerSentry can send scheduled system reports via webhooks:

```bash
# Run a periodic check manually
./serversentry.sh --periodic run

# Show periodic reports configuration and status
./serversentry.sh --periodic status

# Configure periodic reports
./serversentry.sh --periodic config report_interval 86400   # Daily reports
./serversentry.sh --periodic config report_level detailed   # Detailed reports
./serversentry.sh --periodic config report_checks cpu,memory,disk,processes
./serversentry.sh --periodic config force_report true       # Send even when no issues
```

You can schedule reports to run at specific times:

```bash
# Run at 9 AM every weekday (Monday-Friday)
./serversentry.sh --periodic config report_time 09:00
./serversentry.sh --periodic config report_days 1,2,3,4,5
```

For automated execution, set up a cron job:

```bash
# Add to crontab (every hour)
0 * * * * /path/to/serversentry.sh --periodic run >> /path/to/serversentry.log 2>&1
```

### Log Rotation and Management

ServerSentry includes a built-in log rotation system to manage log file growth:

```bash
# Check current log status and configuration
./serversentry.sh --logs status

# Rotate logs immediately
./serversentry.sh --logs rotate

# Clean up old log files based on configured policies
./serversentry.sh --logs clean

# Configure log rotation settings
./serversentry.sh --logs config max_size_mb 20         # Rotate at 20MB
./serversentry.sh --logs config max_age_days 14        # Keep logs for 14 days
./serversentry.sh --logs config max_files 15           # Keep 15 archived logs
./serversentry.sh --logs config compress true          # Compress rotated logs
./serversentry.sh --logs config rotate_on_start false  # Don't rotate on startup
```

Logs are automatically rotated and cleaned based on these settings whenever ServerSentry runs.

### Configuration

ServerSentry uses these configuration files in the `config` directory:

1. `thresholds.conf`: Defines alert thresholds for different resources

   - `cpu_threshold`: CPU usage percentage threshold (default: 80)
   - `memory_threshold`: Memory usage percentage threshold (default: 80)
   - `disk_threshold`: Disk usage percentage threshold (default: 85)
   - `load_threshold`: System load average threshold (default: 2.0)
   - `check_interval`: Seconds between checks when monitoring (default: 60)
   - `process_checks`: Comma-separated list of process names to monitor

2. `webhooks.conf`: Contains webhook URLs for notifications (one per line)

3. `periodic.conf`: Controls scheduled system reports

   - `report_interval`: Time between reports in seconds (default: 86400 = daily)
   - `report_level`: Detail level (summary, detailed, minimal)
   - `report_checks`: System aspects to monitor (cpu, memory, disk, processes, etc.)
   - `force_report`: Whether to send reports even without issues (true/false)
   - `report_time`: Optional specific time for daily reports (HH:MM)
   - `report_days`: Optional specific days for reports (1-7, where 1=Monday)

4. `logrotate.conf`: Controls log file management
   - `max_size_mb`: Size in MB at which to rotate logs (default: 10)
   - `max_age_days`: Delete logs older than this many days (default: 30)
   - `max_files`: Maximum number of archived logs to keep (default: 10)
   - `compress`: Whether to compress rotated logs (default: true)
   - `rotate_on_start`: Whether to rotate logs on application start (default: false)

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
- `periodic.sh`: Scheduled system reporting

## Troubleshooting

- If notifications aren't working, use `--test-webhook` to verify configuration
- Check the log file at `./serversentry.log` for error messages
- Ensure curl is installed for webhook functionality
- For more comprehensive Teams integration help, see TEAMS_SETUP.md

## License

This project is licensed under the MIT License.
