# ServerSentry v2

🚀 **Enterprise-Grade Server Monitoring with Statistical Intelligence**

A comprehensive, modular server monitoring system featuring statistical anomaly detection, real-time dashboards, and intelligent alerting. Built with Bash for maximum compatibility and minimal dependencies.

## ✨ Key Features

### 🧠 **Intelligence Layer**

- **Statistical Anomaly Detection** - Z-score analysis, pattern recognition, trend detection
- **Composite Logic Checks** - Complex multi-metric conditions with logical operators
- **Self-Diagnostics** - Comprehensive system health validation and reporting

### 📊 **Professional Monitoring**

- **Real-Time TUI Dashboard** - 7-screen interactive interface with live metrics
- **Visual Progress Bars** - Color-coded resource usage with Unicode graphics
- **Multi-Provider Notifications** - Teams, Slack, Discord, Email, Webhook support
- **Template System** - Customizable notification content with variables

### 🔧 **Advanced Architecture**

- **Plugin-Based Design** - Modular, extensible monitoring components
- **Dynamic Configuration** - Hot-reload without service interruption
- **Plugin Health Tracking** - Performance monitoring and versioning
- **Cross-Platform Support** - Linux, macOS, and Unix-like systems

### 📈 **Enterprise Features**

- **JSON Reporting** - Structured data output for integration
- **Historical Analysis** - Trend tracking and pattern learning
- **Performance Optimization** - <2% CPU overhead, minimal memory usage
- **Automated Maintenance** - Log rotation, data cleanup, health checks

## 🚀 Quick Start

### Installation

```bash
# Clone and setup
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry/v2
chmod +x bin/serversentry

# Optional: Add to PATH
echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Basic Usage

```bash
# Launch interactive dashboard
serversentry tui

# Check system status with visual output
serversentry status

# Run comprehensive diagnostics
serversentry diagnostics run

# Test anomaly detection
serversentry anomaly test

# Start background monitoring
serversentry start
```

## 🎛️ Advanced Usage

### Anomaly Detection

```bash
# List anomaly configurations
serversentry anomaly list

# Configure CPU anomaly detection
serversentry anomaly config cpu

# View anomaly summary for last 14 days
serversentry anomaly summary 14

# Enable/disable anomaly detection
serversentry anomaly enable memory
serversentry anomaly disable disk
```

### Composite Checks

```bash
# List composite check rules
serversentry composite list

# Test composite checks
serversentry composite test

# Create custom composite check
serversentry composite create critical_alert "cpu.value > 90 AND memory.value > 95"

# Enable/disable composite checks
serversentry composite enable critical_alert
```

### System Diagnostics

```bash
# Full system diagnostics
serversentry diagnostics run

# Quick health check
serversentry diagnostics quick

# View diagnostic reports
serversentry diagnostics reports
serversentry diagnostics view

# Clean up old reports
serversentry diagnostics cleanup 30
```

### Webhook Management

```bash
# Add webhook endpoint
serversentry webhook add https://your-webhook-url.com/endpoint

# Test webhook connectivity
serversentry webhook test

# List configured webhooks
serversentry webhook list
```

### Template Management

```bash
# List available templates
serversentry template list

# Test template generation
serversentry template test teams alert

# Create custom template
serversentry template create my_alert teams

# Validate template syntax
serversentry template validate /path/to/template
```

## 📁 Project Structure

```
v2/
├── bin/
│   └── serversentry                 # Main executable
├── lib/
│   ├── core/                        # Core system modules
│   │   ├── anomaly.sh              # Statistical anomaly detection
│   │   ├── composite.sh            # Multi-metric logic checks
│   │   ├── diagnostics.sh          # System health diagnostics
│   │   ├── plugin_health.sh        # Plugin performance tracking
│   │   ├── reload.sh               # Dynamic configuration reload
│   │   └── templates.sh            # Notification template system
│   ├── plugins/                     # Monitoring plugins
│   │   ├── cpu/                    # CPU monitoring
│   │   ├── memory/                 # Memory monitoring
│   │   ├── disk/                   # Disk space monitoring
│   │   └── process/                # Process monitoring
│   ├── notifications/              # Notification providers
│   │   ├── teams/                  # Microsoft Teams
│   │   ├── slack/                  # Slack
│   │   ├── discord/                # Discord
│   │   ├── email/                  # Email (SMTP)
│   │   └── webhook/                # Generic webhooks
│   └── ui/
│       ├── cli/                    # Command-line interface
│       └── tui/                    # Text-based user interface
├── config/                         # Configuration files
│   ├── anomaly/                    # Anomaly detection configs
│   ├── composite/                  # Composite check rules
│   ├── notifications/              # Notification settings
│   ├── plugins/                    # Plugin configurations
│   └── templates/                  # Notification templates
└── logs/                           # Log files and data
    ├── anomaly/                    # Anomaly detection data
    ├── diagnostics/                # Diagnostic reports
    └── archive/                    # Archived logs
```

## 🔧 Configuration

### Main Configuration (`config/serversentry.yaml`)

```yaml
# Core settings
enabled: true
log_level: info
check_interval: 60

# Plugin configuration
plugins:
  enabled: [cpu, memory, disk, process]

# Notification settings
notifications:
  enabled: true
  providers: [teams, webhook]

# Anomaly detection
anomaly_detection:
  enabled: true
  default_sensitivity: 2.0

# Composite checks
composite_checks:
  enabled: true

# TUI settings
tui:
  auto_refresh: true
  refresh_interval: 2
```

### Plugin Configuration Example

```bash
# config/plugins/cpu.conf
cpu_threshold=85
cpu_warning_threshold=75
cpu_check_interval=30
cpu_anomaly_enabled=true
```

### Notification Provider Example

```bash
# config/notifications/teams.conf
teams_webhook_url="https://your-teams-webhook-url"
teams_template="teams_default"
teams_enabled=true
```

## 📊 Monitoring Capabilities

### Core Plugins

| Plugin      | Metrics               | Thresholds                  | Anomaly Detection     |
| ----------- | --------------------- | --------------------------- | --------------------- |
| **CPU**     | Usage %, Load Average | Warning: 75%, Critical: 85% | ✅ Trends, Spikes     |
| **Memory**  | RAM %, Swap %         | Warning: 80%, Critical: 90% | ✅ Patterns, Outliers |
| **Disk**    | Space %, Inodes       | Warning: 80%, Critical: 90% | ✅ Trends Only        |
| **Process** | Process Count, Status | Custom per process          | ✅ Process Anomalies  |

### Advanced Features

- **Statistical Analysis**: Z-score calculations, standard deviation monitoring
- **Pattern Recognition**: Trend analysis using linear regression
- **Spike Detection**: Sudden change identification (3σ threshold)
- **Composite Logic**: Multi-metric conditions with AND/OR/NOT operators
- **Smart Notifications**: Cooldown periods, consecutive alert thresholds

## 🔔 Notification System

### Supported Providers

- **Microsoft Teams** - Rich cards with metrics and graphs
- **Slack** - Formatted messages with channel routing
- **Discord** - Embedded messages with color coding
- **Email** - HTML/text emails with detailed reports
- **Generic Webhooks** - JSON payloads for custom integrations

### Template Variables

```bash
{hostname}          # Server hostname
{timestamp}         # Alert timestamp
{plugin_name}       # Triggering plugin
{status_message}    # Alert description
{metrics}           # JSON metrics data
{status_text}       # Status level (OK/WARNING/CRITICAL)
{threshold}         # Configured threshold
{current_value}     # Current metric value
```

## 🧪 Development

### Creating Custom Plugins

```bash
# Plugin structure
lib/plugins/myplugin/
├── myplugin.sh         # Plugin implementation
├── myplugin.conf       # Default configuration
└── README.md           # Plugin documentation

# Required functions
myplugin_plugin_info()      # Plugin metadata
myplugin_plugin_check()     # Monitoring logic
myplugin_plugin_configure() # Configuration setup
```

### API Integration

```bash
# JSON output for all commands
serversentry status --json
serversentry anomaly test --json
serversentry diagnostics run --json

# Structured data for external tools
curl -s http://localhost:8080/api/status | jq '.plugins[].metrics'
```

## 📋 System Requirements

### Minimum Requirements

- **OS**: Linux, macOS, or Unix-like system
- **Shell**: Bash 4.0+
- **Memory**: 10MB RAM
- **Storage**: 50MB disk space

### Required Commands

- `ps`, `grep`, `awk`, `sed`, `tail`, `head`, `cat`, `date`

### Optional (Enhanced Features)

- `jq` - JSON processing (advanced output formatting)
- `yq` - YAML processing (configuration validation)
- `bc` - Mathematical calculations (anomaly detection)
- `curl` - HTTP requests (webhook notifications)

## 🚀 Performance

- **CPU Overhead**: <2% during monitoring
- **Memory Usage**: 2-5MB for advanced features
- **Storage**: ~10KB per plugin per month (historical data)
- **Startup Time**: <1 second cold start
- **Plugin Execution**: <500ms average per check

## 🔒 Security

- **No Root Required**: Runs with standard user permissions
- **Secure Defaults**: Conservative thresholds and safe configurations
- **Data Privacy**: Local data storage, no external dependencies
- **Webhook Security**: HTTPS support, configurable timeouts
- **Log Security**: Automatic log rotation and cleanup

## 📚 Documentation

- **User Guide**: `docs/user/README.md`
- **Developer Guide**: `docs/developer/README.md`
- **API Reference**: `docs/api/README.md`
- **Migration Guide**: `docs/v1-to-v2/MIGRATION.md`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

See `docs/developer/CONTRIBUTING.md` for detailed guidelines.

## 📄 License

MIT License - see `LICENSE` file for details.

## 🎯 Roadmap

- [ ] Web dashboard interface
- [ ] Plugin marketplace
- [ ] Cloud integration (AWS, Azure, GCP)
- [ ] Container monitoring (Docker, Kubernetes)
- [ ] Database monitoring plugins
- [ ] Network monitoring capabilities

---

**ServerSentry v2** - Professional server monitoring with statistical intelligence.
Built for reliability, designed for scalability, optimized for performance.
