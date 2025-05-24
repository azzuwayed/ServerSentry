# ServerSentry v2 - Monitoring Service Documentation

## Overview

The ServerSentry monitoring service provides continuous, automated monitoring of your system by running as a background daemon. This service performs regular plugin checks, anomaly detection, periodic reporting, and automated alerting.

## Service Management

### Starting the Service

```bash
# Start background monitoring daemon
serversentry start
```

**What happens when you start the service:**

- Creates a background monitoring process
- Saves the process ID (PID) to `serversentry.pid`
- Begins continuous monitoring loop
- Logs all activity to `logs/serversentry.log`

### Stopping the Service

```bash
# Stop the monitoring daemon
serversentry stop
```

This gracefully terminates the monitoring process and removes the PID file.

### Checking Service Status

```bash
# Check if the monitoring service is running
serversentry status
```

The status command shows:

- ✅ **Monitoring service is running** (if active)
- ⚠️ **Monitoring service is stopped** (if inactive)
- Current status of all plugins

You can also check manually:

```bash
# Check process directly
ps aux | grep serversentry

# View PID file
cat serversentry.pid
```

## How the Monitoring Service Works

### Monitoring Loop

The service runs a continuous monitoring loop that:

1. **Plugin Checks** - Runs all enabled plugins (CPU, memory, disk, process)
2. **Anomaly Detection** - Analyzes metrics for statistical anomalies
3. **Periodic Tasks** - Generates reports and maintains historical data
4. **Alert Processing** - Sends notifications when thresholds are exceeded
5. **Sleep Interval** - Waits for the configured interval before repeating

### Default Behavior

- **Check Interval**: 60 seconds (configurable)
- **Plugins Monitored**: All enabled plugins in `config/serversentry.yaml`
- **Logging**: All activity logged to `logs/serversentry.log`
- **Reports**: System reports generated every 24 hours

## Configuration

### Monitoring Interval

You can customize how frequently the monitoring service checks your system:

```bash
# Set custom interval (in seconds)
MONITOR_INTERVAL=30 serversentry start  # Check every 30 seconds

# Or export for persistent setting
export MONITOR_INTERVAL=120  # Check every 2 minutes
serversentry start
```

### Periodic Monitoring Configuration

The service uses `config/periodic.yaml` for advanced settings:

```yaml
# Enable periodic monitoring
enabled: true

# Interval between full system reports (in hours)
report_interval: 24

# Notification settings for periodic reports
notify_on_report: true

# Report retention (number of reports to keep)
report_retention: 30

# Silence period after alerts (in minutes)
silence_period: 60

# Emergency notification settings
emergency_contacts: []
emergency_threshold: 3
```

### Plugin Configuration

Control which plugins the monitoring service runs via `config/serversentry.yaml`:

```yaml
plugins:
  enabled: [cpu, memory, disk, process] # Plugins to monitor
  cpu_threshold: 85
  memory_threshold: 90
  disk_threshold: 90
```

## Monitoring Activities

### Real-time Plugin Monitoring

The service continuously monitors:

- **CPU Usage** - System load and processing utilization
- **Memory Usage** - RAM and swap utilization
- **Disk Space** - Available storage across monitored paths
- **Process Status** - Critical process availability

### Anomaly Detection

Statistical analysis of metrics to detect:

- Unusual spikes or drops in resource usage
- Trending patterns that may indicate problems
- Outlier values that deviate from historical norms

### Periodic Reporting

Automated generation of:

- **System Health Reports** - Comprehensive status summaries
- **Historical Data Collection** - Metrics for trend analysis
- **Performance Baselines** - Normal operating parameters

### Alert Management

Intelligent alerting with:

- **Threshold-based Alerts** - Traditional monitoring alerts
- **Anomaly Alerts** - Statistical deviation notifications
- **Silence Periods** - Prevent alert spam
- **Multi-channel Notifications** - Teams, Slack, Discord, Email, Webhooks

## Viewing Monitoring Activity

### Service Logs

```bash
# View recent monitoring activity
serversentry logs view

# Follow logs in real-time
tail -f logs/serversentry.log

# View last 20 log entries
tail -n 20 logs/serversentry.log
```

### TUI Dashboard

The interactive dashboard shows real-time monitoring status:

```bash
# Launch TUI dashboard
serversentry tui
```

The dashboard displays:

- **Service Status**: Shows if monitoring service is running
- **Real-time Metrics**: Live system resource usage
- **Plugin Health**: Status of all monitoring plugins
- **Recent Activity**: Latest monitoring events

### Status Reporting

```bash
# Detailed system status
serversentry status

# Quick diagnostic check
serversentry diagnostics quick

# View specific plugin status
serversentry check cpu
serversentry check memory
```

## Troubleshooting

### Service Won't Start

1. **Check for existing process:**

   ```bash
   ps aux | grep serversentry
   # Kill any orphaned processes
   pkill -f serversentry
   ```

2. **Check permissions:**

   ```bash
   # Ensure script is executable
   chmod +x bin/serversentry
   ```

3. **Check configuration:**
   ```bash
   # Validate configuration
   serversentry diagnostics run
   ```

### Service Stops Unexpectedly

1. **Check logs for errors:**

   ```bash
   tail -n 50 logs/serversentry.log | grep ERROR
   ```

2. **Check system resources:**

   ```bash
   # Ensure adequate resources
   serversentry diagnostics quick
   ```

3. **Check dependencies:**
   ```bash
   # Verify required commands available
   serversentry diagnostics run
   ```

### High Resource Usage

1. **Adjust monitoring interval:**

   ```bash
   # Reduce frequency
   MONITOR_INTERVAL=300 serversentry start  # 5 minutes
   ```

2. **Disable resource-intensive features:**

   ```yaml
   # In config/periodic.yaml
   anomaly_detection:
     enabled: false
   ```

3. **Reduce plugin load:**
   ```yaml
   # In config/serversentry.yaml
   plugins:
     enabled: [cpu, memory] # Monitor fewer plugins
   ```

## Best Practices

### Production Deployment

1. **Set appropriate monitoring interval:**

   ```bash
   # Balance between responsiveness and resource usage
   export MONITOR_INTERVAL=120  # 2 minutes for production
   ```

2. **Configure log rotation:**

   ```bash
   # Rotate logs regularly
   serversentry logs rotate
   ```

3. **Set up monitoring alerts:**
   ```bash
   # Test notification system
   serversentry webhook test
   serversentry template test
   ```

### Resource Optimization

1. **Monitor the monitor:**

   ```bash
   # Check ServerSentry's own resource usage
   ps aux | grep serversentry
   ```

2. **Tune anomaly detection:**

   ```yaml
   # Adjust sensitivity to reduce false positives
   anomaly_detection:
     default_sensitivity: 3.0 # Less sensitive
   ```

3. **Optimize report retention:**
   ```yaml
   # Balance between history and disk usage
   report_retention: 7 # Keep fewer reports
   ```

### High Availability

1. **Run as system service:**

   ```bash
   # Consider using systemd, cron, or process supervisor
   # to ensure service restarts automatically
   ```

2. **Monitor service health:**

   ```bash
   # Regular health checks
   */5 * * * * /path/to/serversentry status > /dev/null || /path/to/serversentry start
   ```

3. **Backup configuration:**
   ```bash
   # Regular config backups
   cp -r config/ config.backup.$(date +%Y%m%d)
   ```

## Advanced Features

### Integration with External Systems

The monitoring service can integrate with:

- **Log aggregation systems** via webhook notifications
- **Metrics databases** by parsing JSON output
- **Incident management tools** through custom templates
- **Automation systems** using composite check triggers

### Custom Monitoring Scripts

You can extend the monitoring service:

```bash
# Create custom plugins in lib/plugins/
# They'll be automatically discovered and monitored
```

### Performance Monitoring

Monitor ServerSentry's own performance:

```bash
# Check monitoring overhead
serversentry diagnostics run | grep -A 10 "Performance"
```

## Related Documentation

- [Configuration Guide](README.md#configuration)
- [Plugin System](README.md#monitoring-plugins)
- [Notification System](README.md#notification-system)
- [Anomaly Detection](README.md#anomaly-detection)
- [TUI Dashboard](README.md#tui-dashboard)
- [Troubleshooting](README.md#troubleshooting)
