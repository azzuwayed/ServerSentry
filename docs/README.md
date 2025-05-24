# ServerSentry v2 Documentation

📚 **Complete Documentation for ServerSentry v2**

Enterprise-grade server monitoring with statistical intelligence and advanced alerting capabilities.

## 📖 Documentation Sections

### 👥 **User Documentation**

**For system administrators, operators, and end users**

- **[Installation Guide](user/installation.md)** - Complete installation and setup instructions
- **[Quick Start Guide](user/quickstart.md)** - Get up and running in 5 minutes
- **[User Manual](user/manual.md)** - Comprehensive usage guide with examples
- **[Configuration Guide](user/configuration.md)** - Detailed configuration options and settings
- **[CLI Reference](user/cli-reference.md)** - Complete command-line interface documentation
- **[Troubleshooting](user/troubleshooting.md)** - Common issues and solutions

### 👨‍💻 **Developer Documentation**

**For developers extending and contributing to ServerSentry**

- **[Development Guide](developer/development-guide.md)** - Development setup and contribution guidelines
- **[Architecture Overview](developer/architecture.md)** - System design and component relationships
- **[Plugin Development](developer/plugin-development.md)** - Creating custom monitoring plugins
- **[Notification Development](developer/notification-development.md)** - Building notification providers
- **[API Reference](developer/api-reference.md)** - Function and module API documentation
- **[Testing Guide](developer/testing.md)** - Testing frameworks and best practices

### 🔧 **Administrator Documentation**

**For system administrators managing ServerSentry deployments**

- **[Deployment Guide](admin/deployment.md)** - Production deployment strategies
- **[Security Guide](admin/security.md)** - Security best practices and hardening
- **[Performance Tuning](admin/performance.md)** - Optimization and monitoring guidelines
- **[Backup & Recovery](admin/backup.md)** - Data protection and disaster recovery
- **[Monitoring ServerSentry](admin/monitoring.md)** - Monitoring the monitoring system
- **[Maintenance Guide](admin/maintenance.md)** - Regular maintenance and updates

### 📋 **API Documentation**

**For integration developers and automation**

- **[REST API](api/rest-api.md)** - RESTful API endpoints and specifications
- **[Webhook API](api/webhooks.md)** - Webhook integration and payload formats
- **[Plugin API](api/plugin-api.md)** - Plugin interface specifications
- **[Notification API](api/notification-api.md)** - Notification provider interface
- **[JSON Schemas](api/schemas.md)** - Data format specifications

## 🚀 Getting Started

### For New Users

1. Start with [Installation Guide](user/installation.md)
2. Follow the [Quick Start Guide](user/quickstart.md)
3. Explore the [User Manual](user/manual.md)

### For Developers

1. Read the [Development Guide](developer/development-guide.md)
2. Review the [Architecture Overview](developer/architecture.md)
3. Check specific development guides for your use case

### For Administrators

1. Review [Deployment Guide](admin/deployment.md)
2. Implement [Security Guide](admin/security.md) recommendations
3. Set up [Performance Tuning](admin/performance.md)

## 📁 Project Overview

### Key Features

- **Statistical Anomaly Detection** - Intelligent alerting beyond simple thresholds
- **Multi-Channel Notifications** - Teams, Slack, Discord, Email, Webhooks
- **Modular Plugin System** - Extensible monitoring components
- **Enterprise-Grade Performance** - <2% CPU overhead, minimal memory usage
- **Cross-Platform Support** - Linux, macOS, and Unix-like systems

### System Requirements

- **Bash 5.0+** (primary requirement)
- **jq** (recommended for JSON processing)
- **curl** (for webhook notifications)
- **Basic Unix utilities** (standard on most systems)

### Supported Platforms

- **Linux** (all major distributions)
- **macOS** (10.15+)
- **Unix-like systems** (FreeBSD, OpenBSD, etc.)

## 📞 Support & Community

### Getting Help

- **Documentation**: Start here for comprehensive guides
- **GitHub Issues**: Report bugs and request features
- **Discussions**: Community Q&A and general discussion

### Contributing

- Read [Development Guide](developer/development-guide.md)
- Check [API Reference](developer/api-reference.md)
- Follow [Testing Guide](developer/testing.md)

## 📋 Quick Reference

### Essential Commands

```bash
# Basic operations
serversentry status              # Check system status
serversentry start              # Start monitoring daemon
serversentry diagnostics run    # Run system diagnostics

# Plugin management
serversentry check              # Run all plugin checks
serversentry list               # List available plugins

# Configuration
serversentry configure          # Interactive configuration
serversentry list-thresholds    # View current thresholds
```

### Key Configuration Files

- `config/serversentry.yaml` - Main configuration
- `config/plugins/` - Plugin-specific settings
- `config/notifications/` - Notification provider settings
- `config/templates/` - Custom notification templates

### Important Directories

- `bin/` - Executable files
- `lib/core/` - Core system modules
- `lib/plugins/` - Monitoring plugins
- `lib/notifications/` - Notification providers
- `logs/` - Log files and monitoring data

## 📝 Documentation Notes

### Version Information

- **ServerSentry Version**: v2.0.0
- **Documentation Version**: 2024.12
- **Last Updated**: December 2024

### Documentation Standards

- All guides include practical examples
- Code snippets are tested and verified
- Links are regularly validated
- Content is kept current with releases

---

**📍 Start Here**: New to ServerSentry? Begin with the [Installation Guide](user/installation.md) and [Quick Start Guide](user/quickstart.md).
