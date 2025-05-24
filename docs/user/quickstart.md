# ServerSentry v2 - Quick Start Guide

⚡ **Get ServerSentry monitoring up and running in 5 minutes**

This guide will have you monitoring your server with intelligent alerting in just a few simple steps.

## Prerequisites

- Linux, macOS, or Unix-like system
- Bash 5.0+ installed
- Basic command line familiarity

## Step 1: Install ServerSentry (2 minutes)

### Option A: Quick Install

```bash
# One-line installer (recommended)
curl -fsSL https://raw.githubusercontent.com/yourusername/ServerSentry/main/install.sh | bash
```

### Option B: Manual Install

```bash
# Clone and setup
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry
chmod +x bin/serversentry

# Add to PATH (optional but recommended)
echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Verify Installation

```bash
serversentry version
# Should show: ServerSentry v2.0.0
```

## Step 2: Basic Configuration (1 minute)

### Quick Setup

```bash
# Run interactive configuration wizard
serversentry configure
```

The wizard will prompt you for:

- **Monitoring thresholds** (use defaults for now)
- **Notification preferences** (skip for basic monitoring)
- **Check interval** (60 seconds is recommended)

### Manual Configuration (Alternative)

```bash
# Basic configuration is already included
# Just verify it exists
cat config/serversentry.yaml
```

## Step 3: Test the System (1 minute)

### Check System Status

```bash
# See current system status
serversentry status
```

You should see output like:

```
✅ Monitoring service is stopped
✅ cpu: OK (45%) - Normal CPU usage
✅ memory: OK (62%) - Normal memory usage
✅ disk: OK (34%) - Normal disk usage
```

### Run System Diagnostics

```bash
# Verify everything is working
serversentry diagnostics quick
```

### Test Individual Plugins

```bash
# Test each monitoring component
serversentry check cpu
serversentry check memory
serversentry check disk
```

## Step 4: Start Monitoring (30 seconds)

### Start the Monitoring Service

```bash
# Begin continuous monitoring
serversentry start
```

### Verify Service is Running

```bash
# Check that monitoring is active
serversentry status
```

You should now see:

```
✅ Monitoring service is running (PID: 12345)
```

## Step 5: Explore Features (30 seconds)

### View Real-time Logs

```bash
# See monitoring activity in real-time
tail -f logs/serversentry.log
```

### List Available Commands

```bash
# Explore all available commands
serversentry help
```

### Check Plugin Health

```bash
# See all available monitoring plugins
serversentry list
```

## You're Done! 🎉

ServerSentry is now monitoring your system with:

- **CPU monitoring** - Alerts when usage is high
- **Memory monitoring** - Tracks RAM and swap usage
- **Disk monitoring** - Monitors storage space
- **Process monitoring** - Checks critical processes
- **Intelligent alerting** - Statistical anomaly detection

## What's Next?

### Add Notifications (5 minutes)

Set up alerts to Teams, Slack, Discord, or email:

```bash
# Configure Teams webhook
serversentry configure
# Enter your Teams webhook URL when prompted

# Test notifications
serversentry webhook test
```

### Enable Advanced Features (10 minutes)

```bash
# Configure anomaly detection
serversentry anomaly config

# Set up composite checks
serversentry composite list

# View comprehensive diagnostics
serversentry diagnostics run
```

### Customize Monitoring (15 minutes)

```bash
# Adjust thresholds
serversentry update-threshold cpu_threshold=85
serversentry update-threshold memory_threshold=90

# Configure specific plugins
nano config/plugins/cpu.conf
nano config/plugins/memory.conf
```

## Common Next Steps

### 1. Production Setup

```bash
# Set appropriate thresholds for your environment
serversentry update-threshold cpu_threshold=80
serversentry update-threshold memory_threshold=85
serversentry update-threshold disk_threshold=90

# Enable anomaly detection
serversentry anomaly enable cpu
serversentry anomaly enable memory
```

### 2. Notification Setup

```bash
# Add webhook for alerts
serversentry webhook add https://your-webhook-url.com

# Configure email notifications
nano config/notifications/email.conf
```

### 3. Dashboard Access

```bash
# Launch interactive dashboard (if supported)
serversentry tui
```

## Troubleshooting Quick Issues

### Service Won't Start

```bash
# Check for errors
serversentry diagnostics run

# View logs for details
serversentry logs view
```

### Commands Not Found

```bash
# Use full path if not in PATH
./bin/serversentry status

# Or add to PATH
export PATH="$PATH:$(pwd)/bin"
```

### Permission Issues

```bash
# Fix executable permissions
chmod +x bin/serversentry

# Check file permissions
ls -la bin/serversentry
```

## Quick Reference

### Essential Commands

```bash
serversentry status              # Check system status
serversentry start              # Start monitoring
serversentry stop               # Stop monitoring
serversentry check             # Run all checks
serversentry logs view         # View recent logs
serversentry diagnostics run   # Full system check
```

### Key Files

- `config/serversentry.yaml` - Main configuration
- `logs/serversentry.log` - Main log file
- `serversentry.pid` - Process ID file (when running)

---

**📍 Success!** ServerSentry is now protecting your server.

**Next Steps:**

- See [User Manual](manual.md) for complete feature documentation
- Check [Configuration Guide](configuration.md) for advanced settings
- Visit [Troubleshooting](troubleshooting.md) if you encounter issues
