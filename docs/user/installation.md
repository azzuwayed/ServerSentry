# ServerSentry v2 - Installation Guide

🚀 **Complete Installation Instructions for ServerSentry v2**

This guide provides step-by-step installation instructions for all supported platforms.

## System Requirements

### Minimum Requirements

- **Operating System**: Linux, macOS, or Unix-like system
- **Bash Version**: 5.0 or higher
- **RAM**: 100MB available memory
- **Disk Space**: 200MB for installation and logs
- **Network**: Internet connection for initial setup (optional)

### Required Commands

Standard Unix utilities (available on most systems):

- `bash`, `ps`, `grep`, `awk`, `sed`, `cat`, `date`, `chmod`, `mkdir`

### Recommended Dependencies

- **jq** - JSON processing for enhanced functionality
- **curl** - HTTP requests for webhook notifications
- **bc** - Mathematical calculations for anomaly detection
- **mail/sendmail** - Email notifications (optional)

## Platform-Specific Installation

### Linux (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt update
sudo apt install jq curl bc

# Clone and setup ServerSentry
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry
chmod +x bin/serversentry

# Optional: Install to system
sudo cp bin/serversentry /usr/local/bin/
sudo mkdir -p /opt/serversentry
sudo cp -r . /opt/serversentry/
```

### Linux (CentOS/RHEL/Fedora)

```bash
# Install dependencies
sudo yum install jq curl bc  # CentOS/RHEL
# OR
sudo dnf install jq curl bc  # Fedora

# Clone and setup ServerSentry
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry
chmod +x bin/serversentry
```

### macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install jq curl bc

# Clone and setup ServerSentry
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry
chmod +x bin/serversentry
```

### FreeBSD/OpenBSD

```bash
# Install dependencies (FreeBSD)
sudo pkg install jq curl bc

# Install dependencies (OpenBSD)
sudo pkg_add jq curl bc

# Clone and setup ServerSentry
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry
chmod +x bin/serversentry
```

## Installation Methods

### Method 1: Quick Install (Recommended)

```bash
# One-line installer (downloads and sets up automatically)
curl -fsSL https://raw.githubusercontent.com/yourusername/ServerSentry/main/install.sh | bash
```

### Method 2: Manual Installation

```bash
# Clone repository
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry

# Run installer script
sudo ./bin/install.sh

# Or manual setup
chmod +x bin/serversentry
./bin/serversentry version
```

### Method 3: Portable Installation

```bash
# Download and extract
wget https://github.com/yourusername/ServerSentry/archive/v2.tar.gz
tar -xzf v2.tar.gz
cd ServerSentry-2

# Make executable and test
chmod +x bin/serversentry
./bin/serversentry diagnostics quick
```

## Post-Installation Setup

### 1. Verify Installation

```bash
# Check version and basic functionality
serversentry version
serversentry diagnostics quick
serversentry status
```

### 2. Configure Basic Settings

```bash
# Run interactive configuration
serversentry configure

# Or manually edit configuration
nano config/serversentry.yaml
```

### 3. Test Core Features

```bash
# Test plugin functionality
serversentry check cpu
serversentry check memory
serversentry check disk

# Test notification system (optional)
serversentry webhook test
```

### 4. Set Up Monitoring Service

```bash
# Start monitoring daemon
serversentry start

# Verify service is running
serversentry status
```

## Configuration

### Directory Structure

After installation, ServerSentry creates the following structure:

```
/opt/serversentry/          # Default installation directory
├── bin/serversentry        # Main executable
├── config/                 # Configuration files
├── lib/                    # Core libraries and plugins
├── logs/                   # Log files and monitoring data
└── tmp/                    # Temporary files
```

### Essential Configuration Files

- `config/serversentry.yaml` - Main configuration
- `config/plugins/*.conf` - Plugin-specific settings
- `config/notifications/*.conf` - Notification provider settings

## Troubleshooting Installation

### Common Issues

#### 1. Permission Denied

```bash
# Fix executable permissions
chmod +x bin/serversentry

# Check directory permissions
ls -la bin/
```

#### 2. Command Not Found

```bash
# Add to PATH temporarily
export PATH="$PATH:$(pwd)/bin"

# Add to PATH permanently
echo 'export PATH="$PATH:/opt/serversentry/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Missing Dependencies

```bash
# Check for required commands
serversentry diagnostics run

# Install missing dependencies based on platform
# See platform-specific sections above
```

#### 4. Bash Version Too Old

```bash
# Check bash version
bash --version

# Upgrade bash (platform-specific)
# Ubuntu/Debian: sudo apt install bash
# macOS: brew install bash
# CentOS/RHEL: sudo yum update bash
```

### Verification Commands

```bash
# System compatibility check
serversentry diagnostics run

# Feature availability check
serversentry list
serversentry webhook list
serversentry template list

# Performance check
time serversentry check cpu
```

## Uninstallation

### Remove ServerSentry

```bash
# Stop monitoring service
serversentry stop

# Remove from system PATH
# Edit ~/.bashrc and remove ServerSentry PATH entries

# Remove installation directory
sudo rm -rf /opt/serversentry

# Remove executable (if installed to system)
sudo rm -f /usr/local/bin/serversentry
```

### Clean Up Data

```bash
# Remove configuration and logs (optional)
rm -rf ~/.serversentry
rm -rf /var/log/serversentry
```

## Advanced Installation Options

### Docker Installation (Future)

```bash
# Pull Docker image
docker pull serversentry/serversentry:v2

# Run container
docker run -d --name serversentry serversentry/serversentry:v2
```

### Systemd Service Installation

```bash
# Create systemd service file
sudo cp extras/serversentry.service /etc/systemd/system/

# Enable and start service
sudo systemctl enable serversentry
sudo systemctl start serversentry
```

## Security Considerations

### File Permissions

```bash
# Secure configuration files
chmod 600 config/notifications/*.conf
chmod 755 bin/serversentry
chmod 644 config/serversentry.yaml
```

### Network Security

- Configure firewall rules for webhook endpoints
- Use HTTPS for all webhook URLs
- Implement proper authentication for notifications

---

**📍 Next Steps**: After installation, see the [Quick Start Guide](quickstart.md) to begin monitoring your system.
