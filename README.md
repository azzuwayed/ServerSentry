# SysMon - System Monitoring Tool

SysMon is a lightweight Bash-based system monitoring tool that tracks various system resources and sends webhook notifications when issues are detected.

## Features

- Monitor system resources (CPU, memory, disk usage)
- Track process statuses and service health
- Set configurable thresholds for alerts
- Send webhook notifications when thresholds are exceeded
- Generate basic system health logs
- Support for multiple webhook endpoints
- Command-line interface for configuration

## Requirements

- Bash shell
- Basic Linux utilities (ps, free, df, etc.)
- cURL for webhook notifications
- jq for advanced JSON processing (optional)
- cron for scheduling (optional)

## Installation

1. Clone or download this repository to your server
2. Run the installation script:

```bash
chmod +x install.sh
./install.sh
