# ServerSentry v2 Documentation

Welcome to the comprehensive documentation for ServerSentry v2, an enterprise-grade server monitoring solution with statistical intelligence.

## Documentation Sections

### 📚 User Documentation

- **[User Guide](user/README.md)** - Complete user manual covering installation, configuration, and usage
- **[Monitoring Service Guide](user/monitoring-service.md)** - Detailed documentation for the background monitoring daemon

### 👨‍💻 Developer Documentation

- **[Plugin Development](developer/plugin_development.md)** - Guide for creating custom monitoring plugins
- **[Notification Development](developer/notification_development.md)** - Guide for developing notification providers

### 🔄 Migration Documentation

- **[V1 to V2 Migration](v1-to-v2/MIGRATION_CHECKLIST.md)** - Comprehensive migration checklist
- **[Implementation Phases](v1-to-v2/)** - Development phase documentation

## Quick Links

### Getting Started

- [Installation Guide](user/README.md#installation)
- [Quick Start](user/README.md#quick-start)
- [Basic Usage](user/README.md#basic-usage)

### Core Features

- [Monitoring Service](user/monitoring-service.md) - Background daemon and continuous monitoring
- [Plugin System](user/README.md#monitoring-plugins) - CPU, memory, disk, and process monitoring
- [Notification System](user/README.md#notification-system) - Teams, Slack, Discord, Email, Webhooks
- [TUI Dashboard](user/README.md#tui-dashboard) - Interactive terminal interface

### Advanced Features

- [Anomaly Detection](user/README.md#anomaly-detection) - Statistical analysis and intelligent alerting
- [Composite Checks](user/README.md#composite-checks) - Multi-metric logical conditions
- [System Diagnostics](user/README.md#system-diagnostics) - Self-diagnostic capabilities

### Configuration & Management

- [Configuration Guide](user/README.md#configuration) - Main configuration options
- [Monitoring Service Configuration](user/monitoring-service.md#configuration) - Service-specific settings
- [Troubleshooting](user/README.md#troubleshooting) - Common issues and solutions

## Key Features Overview

### 🚀 Enterprise-Grade Monitoring

- **Continuous Background Monitoring** - 24/7 system monitoring with configurable intervals
- **Statistical Anomaly Detection** - Intelligent alerting based on historical patterns
- **Multi-Channel Notifications** - Flexible alerting via Teams, Slack, Discord, Email, Webhooks
- **Real-time Dashboard** - Interactive TUI with 7 specialized screens

### 🔧 System Compatibility

- **Cross-Platform** - Linux, macOS, and Unix-like systems
- **Minimal Dependencies** - Pure Bash implementation with optional enhancements
- **Resource Efficient** - Low overhead monitoring suitable for production environments

### 📊 Monitoring Capabilities

- **Core System Metrics** - CPU, memory, disk space, and process monitoring
- **Threshold-Based Alerts** - Traditional monitoring with configurable thresholds
- **Composite Checks** - Complex logical conditions across multiple metrics
- **Historical Analysis** - Trend detection and pattern recognition

### ⚙️ Management Features

- **Dynamic Configuration** - Reload settings without service restart
- **Self-Diagnostics** - Built-in health checks and validation
- **Log Management** - Comprehensive logging with rotation capabilities
- **Template System** - Customizable notification templates

## Documentation Structure

```
docs/
├── README.md                           # This file - main documentation index
├── user/                              # End-user documentation
│   ├── README.md                      # Complete user guide
│   └── monitoring-service.md          # Monitoring service documentation
├── developer/                         # Developer documentation
│   ├── plugin_development.md         # Custom plugin development
│   └── notification_development.md   # Notification provider development
└── v1-to-v2/                        # Migration documentation
    ├── MIGRATION_CHECKLIST.md       # Migration checklist
    ├── phase2_implementation.md     # Phase 2 features
    └── phase3_implementation.md     # Phase 3 features
```

## Support and Community

- **Issues**: Report bugs and request features via GitHub issues
- **Discussions**: Community discussions and Q&A
- **Contributing**: See developer documentation for contribution guidelines

## Version Information

- **Current Version**: ServerSentry v2.0.0
- **Plugin Interface**: v2.0
- **Documentation Version**: 2024.05

---

**Need help?** Start with the [User Guide](user/README.md) or check the [Monitoring Service documentation](user/monitoring-service.md) for detailed service management information.
