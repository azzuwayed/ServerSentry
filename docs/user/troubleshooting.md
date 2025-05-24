# ServerSentry v2 - Troubleshooting Guide

🔧 **Comprehensive Troubleshooting Guide for ServerSentry v2**

This guide helps you diagnose and resolve common issues with ServerSentry installation, configuration, and operation.

## Quick Diagnostics

### First Steps for Any Issue

```bash
# Run comprehensive diagnostics
serversentry diagnostics run

# Check system status
serversentry status

# Check logging system health
serversentry logging health

# View recent logs (specialized)
serversentry logging tail main 50       # Main application log
serversentry logging tail error 20      # Error log only
serversentry logging tail audit 10      # Recent user actions

# Follow logs in real-time
serversentry logging follow performance  # Performance monitoring

# Check configuration validity
serversentry list-thresholds

# Test all logging functions
serversentry logging test
```

## Installation Issues

### 1. Permission Denied Errors

**Symptoms:**

```
bash: ./bin/serversentry: Permission denied
```

**Solutions:**

```bash
# Fix executable permissions
chmod +x bin/serversentry

# Check file permissions
ls -la bin/serversentry
# Should show: -rwxr-xr-x

# If still failing, check directory permissions
ls -la bin/
chmod 755 bin/
```

### 2. Command Not Found

**Symptoms:**

```
serversentry: command not found
```

**Solutions:**

```bash
# Use full path
./bin/serversentry status

# Add to PATH temporarily
export PATH="$PATH:$(pwd)/bin"

# Add to PATH permanently
echo 'export PATH="$PATH:/opt/serversentry/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify PATH
which serversentry
```

### 3. Bash Version Too Old

**Symptoms:**

```
Bash version X.X detected, but version 5.0+ is required
```

**Solutions:**

```bash
# Check current version
bash --version

# Ubuntu/Debian upgrade
sudo apt update && sudo apt install bash

# macOS upgrade (via Homebrew)
brew install bash

# CentOS/RHEL upgrade
sudo yum update bash
```

### 4. Missing Dependencies

**Symptoms:**

```
jq: command not found
curl: command not found
```

**Solutions:**

```bash
# Ubuntu/Debian
sudo apt install jq curl bc

# CentOS/RHEL
sudo yum install jq curl bc

# macOS (Homebrew)
brew install jq curl bc

# Verify installation
jq --version
curl --version
```

## Service Management Issues

### 1. Service Won't Start

**Symptoms:**

```
Failed to start monitoring service
```

**Diagnosis:**

```bash
# Check for errors
serversentry diagnostics run

# View detailed logs
tail -n 50 logs/serversentry.log

# Check for existing process
ps aux | grep serversentry

# Check PID file
cat serversentry.pid 2>/dev/null || echo "No PID file"
```

**Solutions:**

```bash
# Remove stale PID file
rm -f serversentry.pid

# Check port conflicts (if using network features)
netstat -tlnp | grep :PORT

# Start with verbose logging
serversentry -v start

# Start in foreground for debugging
FOREGROUND=true serversentry start
```

### 2. Service Stops Unexpectedly

**Symptoms:**

- Service shows as stopped when it should be running
- Missing PID file

**Diagnosis:**

```bash
# Check for crashes in logs
grep -i "error\|fatal\|crash" logs/*.log

# Check system resources
free -h
df -h
ps aux --sort=-%cpu | head -10

# Check for killed processes
dmesg | grep -i "killed process"
```

**Solutions:**

```bash
# Increase check interval to reduce load
serversentry update-threshold check_interval=120

# Disable resource-intensive features temporarily
# Edit config/serversentry.yaml:
anomaly_detection:
  enabled: false

# Monitor system resources
top -p $(pgrep serversentry)
```

### 3. High Resource Usage

**Symptoms:**

- High CPU usage from ServerSentry
- High memory consumption
- System slowdown

**Diagnosis:**

```bash
# Check ServerSentry performance
serversentry diagnostics performance

# Monitor resource usage
top -p $(cat serversentry.pid)
ps -p $(cat serversentry.pid) -o pid,ppid,cmd,%mem,%cpu

# Check plugin performance
serversentry diagnostics plugins
```

**Solutions:**

```bash
# Increase check intervals
serversentry update-threshold check_interval=180

# Disable unnecessary plugins
serversentry configure
# Uncheck plugins you don't need

# Disable performance-heavy features
# Edit config/serversentry.yaml:
anomaly_detection:
  enabled: false
tui:
  auto_refresh: false
```

## Plugin Issues

### 1. Plugin Check Failures

**Symptoms:**

```
❌ cpu: ERROR - Plugin check failed
❌ memory: ERROR - Plugin check failed
```

**Diagnosis:**

```bash
# Test individual plugins
serversentry check cpu -v
serversentry check memory -v
serversentry check disk -v

# Check plugin availability
serversentry list

# View plugin logs
grep -i plugin logs/*.log
```

**Solutions:**

```bash
# Check plugin permissions
ls -la lib/plugins/*/

# Verify plugin dependencies
serversentry diagnostics dependencies

# Reload plugins
serversentry reload plugins

# Reset plugin configuration
rm config/plugins/*.conf
serversentry configure
```

### 2. Incorrect Plugin Readings

**Symptoms:**

- CPU showing 0% when system is busy
- Memory readings don't match `free` command
- Disk usage incorrect

**Diagnosis:**

```bash
# Compare with system commands
serversentry check cpu
top -bn1 | grep "Cpu(s)"

serversentry check memory
free -h

serversentry check disk
df -h
```

**Solutions:**

```bash
# Check plugin configuration
cat config/plugins/cpu.conf
cat config/plugins/memory.conf
cat config/plugins/disk.conf

# Verify monitored paths for disk plugin
# Edit config/plugins/disk.conf:
disk_monitored_paths="/,/var,/home"

# Test with verbose output
serversentry -d check cpu
```

## Notification Issues

### 1. Notifications Not Sending

**Symptoms:**

- No alerts received despite threshold breaches
- Webhook test failures

**Diagnosis:**

```bash
# Test notification system
serversentry webhook test

# Check notification configuration
serversentry webhook list
serversentry webhook status

# View notification logs
grep -i notification logs/*.log
```

**Solutions:**

```bash
# Verify webhook URLs
curl -X POST "YOUR_WEBHOOK_URL" -H "Content-Type: application/json" -d '{"test": "message"}'

# Check notification provider settings
cat config/notifications/teams.conf
cat config/notifications/slack.conf

# Test individual providers
serversentry template test teams alert
serversentry template test slack alert

# Verify network connectivity
ping google.com
nslookup hooks.slack.com
```

### 2. Notification Spam

**Symptoms:**

- Too many notifications
- Repeated alerts for same issue

**Solutions:**

```bash
# Increase cooldown periods
# Edit config/notifications/*.conf:
cooldown=3600  # 1 hour

# Increase alert thresholds
serversentry update-threshold cpu_threshold=90
serversentry update-threshold memory_threshold=95

# Configure composite checks for complex conditions
serversentry composite create high_load "cpu.value > 85 AND memory.value > 90"
```

### 3. Email Notifications Failing

**Symptoms:**

```
Failed to send email notification
SMTP connection failed
```

**Diagnosis:**

```bash
# Test SMTP connectivity
telnet smtp.gmail.com 587

# Check email configuration
cat config/notifications/email.conf

# Test email sending
echo "Test message" | mail -s "Test" admin@yourcompany.com
```

**Solutions:**

```bash
# Verify SMTP settings
# Edit config/notifications/email.conf:
email_smtp_server="smtp.gmail.com"
email_smtp_port=587
email_use_tls=true

# Check firewall rules
sudo ufw status
sudo iptables -L | grep 587

# Use app passwords (Gmail)
# Generate app password in Google Account settings
```

## Configuration Issues

### 1. Invalid Configuration

**Symptoms:**

```
Configuration validation failed
Invalid YAML syntax
```

**Diagnosis:**

```bash
# Validate YAML syntax
yamllint config/serversentry.yaml

# Check configuration with built-in validator
serversentry diagnostics config

# Test configuration loading
serversentry validate-config
```

**Solutions:**

```bash
# Fix YAML syntax errors
# Check for proper indentation (spaces, not tabs)
# Verify quotes around strings

# Restore from backup
cp config/serversentry.yaml.backup config/serversentry.yaml

# Regenerate default configuration
mv config/serversentry.yaml config/serversentry.yaml.old
serversentry configure
```

### 2. Configuration Not Loading

**Symptoms:**

- Changes to configuration not taking effect
- Default values being used

**Solutions:**

```bash
# Reload configuration
serversentry reload config

# Restart service
serversentry stop
serversentry start

# Check file permissions
ls -la config/*.yaml
chmod 644 config/serversentry.yaml

# Verify configuration file path
serversentry -c /path/to/config.yaml status
```

## Anomaly Detection Issues

### 1. No Anomalies Detected

**Symptoms:**

- Anomaly detection enabled but no anomalies found
- System clearly having issues but no alerts

**Diagnosis:**

```bash
# Check anomaly configuration
serversentry anomaly list

# Test anomaly detection
serversentry anomaly test

# View anomaly data
ls -la logs/anomaly/
cat logs/anomaly/results/*.log
```

**Solutions:**

```bash
# Adjust sensitivity
# Edit config/anomaly/*.conf:
sensitivity=1.5  # More sensitive

# Reduce window size for faster detection
window_size=10

# Enable all anomaly types
detect_trends=true
detect_spikes=true

# Allow more time for data collection
# Anomaly detection needs at least 20 data points
```

### 2. Too Many False Positives

**Symptoms:**

- Constant anomaly alerts
- Normal system behavior triggering alerts

**Solutions:**

```bash
# Reduce sensitivity
# Edit config/anomaly/*.conf:
sensitivity=3.0  # Less sensitive

# Increase notification threshold
notification_threshold=5

# Increase cooldown period
cooldown=7200  # 2 hours

# Disable spike detection if system is naturally spiky
detect_spikes=false
```

## Log Issues

### 1. Log Files Too Large

**Symptoms:**

- Disk space issues
- Large log files affecting performance
- Log partition full warnings

**Solutions:**

```bash
# Check current log system status
serversentry logging status

# Check logging system health
serversentry logging health

# Manually rotate logs
serversentry logging rotate

# Clean up old log archives
serversentry logging cleanup 30    # Keep last 30 days

# Configure automatic rotation in config/serversentry.yaml:
logging:
  file:
    max_size: 5242880         # 5MB per file
    max_archives: 5           # Keep 5 archives
    compression: true         # Enable compression

  # Archive management
  archive:
    retention_days: 30        # Auto-cleanup after 30 days
    cleanup_on_startup: true  # Clean on restart
```

### 2. Missing Log Entries

**Symptoms:**

- No recent entries in logs
- Missing error messages
- Debug information not appearing

**Solutions:**

```bash
# Check current log level
serversentry logging level

# Increase log verbosity temporarily
serversentry logging level debug

# Test logging system
serversentry logging test

# Check specialized logs
serversentry logging tail error 50      # View error log
serversentry logging tail audit 20      # View audit log
serversentry logging tail security 10   # View security log

# Check file permissions
ls -la logs/
chmod 755 logs/
chmod 644 logs/*.log

# View logging configuration
serversentry logging config
```

### 3. Log Format Issues

**Symptoms:**

- Unreadable log format
- JSON parsing errors
- Missing structured data

**Solutions:**

```bash
# Check current log format
serversentry logging format

# Switch to standard format
serversentry logging format standard

# Enable JSON for log analysis tools
serversentry logging format json

# Configure in serversentry.yaml:
logging:
  global:
    output_format: standard        # or json, structured
    timestamp_format: "%Y-%m-%d %H:%M:%S"
    include_caller: true          # For debugging
```

### 4. Component-Specific Log Issues

**Symptoms:**

- Too much plugin debug output
- Missing notification logs
- Security events not logged

**Solutions:**

```bash
# Configure component-specific levels in serversentry.yaml:
logging:
  components:
    plugins: warning      # Reduce plugin verbosity
    notifications: info   # Enable notification logs
    security: debug       # Increase security logging
    performance: info     # Enable performance logs

# View specialized logs
serversentry logging tail performance 50
serversentry logging follow security    # Real-time monitoring
```

### 5. Log Monitoring and Alerts

**Symptoms:**

- Unable to monitor log health
- No alerts for log issues

**Solutions:**

```bash
# Enable log system monitoring in serversentry.yaml:
logging:
  advanced:
    monitoring:
      enabled: true
      self_check_interval: 300     # Check every 5 minutes
      disk_usage_threshold: 85     # Alert at 85% usage
      file_handle_threshold: 80    # Alert at 80% handles

# Manual health checks
serversentry logging health

# Check disk usage
df -h logs/
```

## Performance Issues

### 1. Slow Response Times

**Symptoms:**

- Commands take long time to execute
- Monitoring checks timing out

**Diagnosis:**

```bash
# Check system performance
serversentry diagnostics performance

# Time individual operations
time serversentry check cpu
time serversentry check memory

# Check system resources
iostat -x 1 5
vmstat 1 5
```

**Solutions:**

```bash
# Enable performance optimizations
# Edit config/serversentry.yaml:
performance:
  enable_caching: true
  optimize_startup: true
  preload_commands: true

# Increase timeout values
system:
  check_timeout: 60

# Reduce check frequency
system:
  check_interval: 120
```

### 2. Memory Leaks

**Symptoms:**

- ServerSentry memory usage increasing over time
- System memory exhaustion

**Diagnosis:**

```bash
# Monitor memory usage over time
while true; do
  ps -p $(cat serversentry.pid) -o pid,vsz,rss,pmem,time
  sleep 60
done

# Check for resource leaks
serversentry diagnostics memory
```

**Solutions:**

```bash
# Restart service regularly (temporary fix)
# Add to cron:
0 6 * * * /opt/serversentry/bin/serversentry restart

# Disable memory-intensive features
anomaly_detection:
  enabled: false

# Reduce data retention
anomaly_detection:
  data_points: 50
  retention_days: 7
```

## Network Issues

### 1. Webhook Timeouts

**Symptoms:**

```
Webhook timeout after 30 seconds
Connection refused
```

**Solutions:**

```bash
# Increase timeout values
# Edit config/notifications/*.conf:
timeout=60

# Test connectivity
curl -I https://your-webhook-url.com

# Check DNS resolution
nslookup your-webhook-url.com

# Test with different endpoint
serversentry webhook add https://httpbin.org/post
serversentry webhook test
```

### 2. Firewall Blocking

**Symptoms:**

- Network requests failing
- Unable to reach notification endpoints

**Solutions:**

```bash
# Check firewall status
sudo ufw status
sudo iptables -L

# Allow outbound HTTPS
sudo ufw allow out 443

# Test with proxy if needed
export https_proxy=http://proxy.company.com:8080
serversentry webhook test
```

## Emergency Recovery

### 1. Complete System Recovery

```bash
# Stop all ServerSentry processes
pkill -f serversentry

# Remove PID files
rm -f serversentry.pid

# Backup current configuration
cp -r config config.backup.$(date +%Y%m%d)

# Reset to default configuration
mv config/serversentry.yaml config/serversentry.yaml.old
serversentry configure

# Restart with minimal configuration
serversentry start
```

### 2. Factory Reset

```bash
# Stop ServerSentry
serversentry stop

# Backup important data
tar -czf serversentry-backup-$(date +%Y%m%d).tar.gz config/ logs/

# Reset configuration
rm -rf config/*
serversentry configure

# Clear logs (optional)
rm -rf logs/*
mkdir -p logs/{archive,anomaly,diagnostics}

# Restart fresh
serversentry start
```

## Getting Help

### Gather Diagnostic Information

Before seeking help, gather this information:

```bash
# System information
uname -a
bash --version
serversentry version

# Run full diagnostics
serversentry diagnostics run > diagnostics-output.txt

# Collect configuration
tar -czf config-backup.tar.gz config/

# Collect recent logs
tail -n 100 logs/*.log > recent-logs.txt

# System resource status
free -h > system-status.txt
df -h >> system-status.txt
ps aux | grep serversentry >> system-status.txt
```

### Support Channels

- **Documentation**: Check other guides in `docs/`
- **GitHub Issues**: Report bugs with diagnostic information
- **Community Forum**: Ask questions and share solutions

---

**📍 Still Having Issues?**

- Check [Configuration Guide](configuration.md) for setup issues
- See [User Manual](manual.md) for feature questions
- Review [Installation Guide](installation.md) for setup problems
