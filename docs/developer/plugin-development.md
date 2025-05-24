# ServerSentry v2 Plugin Development Guide

This guide explains how to develop custom plugins for ServerSentry v2. Plugins allow you to extend the monitoring capabilities of ServerSentry to suit your specific needs.

## Plugin Structure

Each plugin consists of at least two files:

1. **Plugin Implementation** (`lib/plugins/your_plugin/your_plugin.sh`)
2. **Plugin Configuration** (`config/plugins/your_plugin.conf`)

## Creating a Plugin

### Step 1: Create the Plugin Directory

Create a directory for your plugin in the `lib/plugins` directory:

```bash
mkdir -p lib/plugins/your_plugin
```

### Step 2: Create the Plugin Implementation

Create a file named after your plugin in the plugin directory:

```bash
touch lib/plugins/your_plugin/your_plugin.sh
```

Edit the file to implement the required functions:

```bash
#!/bin/bash
#
# ServerSentry v2 - Your Plugin Name
#
# Brief description of what your plugin does

# Plugin metadata
your_plugin_plugin_name="your_plugin"
your_plugin_plugin_version="1.0"
your_plugin_plugin_description="Description of your plugin"
your_plugin_plugin_author="Your Name"

# Default configuration
your_plugin_threshold=90
your_plugin_warning_threshold=80
your_plugin_check_interval=60
# Add any other configuration variables your plugin needs

# Return plugin information (required)
your_plugin_plugin_info() {
  echo "Your Plugin v${your_plugin_plugin_version}"
}

# Configure the plugin (required)
your_plugin_plugin_configure() {
  local config_file="$1"

  # Load configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  # Add your validation logic here

  log_debug "Your plugin configured with: threshold=$your_plugin_threshold"

  return 0
}

# Perform the check (required)
your_plugin_plugin_check() {
  local result
  local status_code=0
  local status_message="OK"

  # Implement your check logic here
  # This should set result, status_code, and status_message

  # Get timestamp
  local timestamp
  timestamp=$(get_timestamp)

  # Return standardized output format
  cat <<EOF
{
  "plugin": "your_plugin",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "your_metric": ${result},
    "threshold": ${your_plugin_threshold},
    "warning_threshold": ${your_plugin_warning_threshold}
  },
  "timestamp": "${timestamp}"
}
EOF
}
```

### Step 3: Create the Plugin Configuration

Create a configuration file for your plugin:

```bash
touch config/plugins/your_plugin.conf
```

Edit the file to define default configuration:

```bash
# Your Plugin Configuration

# Alert threshold
your_plugin_threshold=90

# Warning threshold
your_plugin_warning_threshold=80

# Check interval in seconds
your_plugin_check_interval=60

# Add any other configuration options your plugin needs
```

## Plugin Interface

Every plugin must implement these three functions:

1. **`your_plugin_plugin_info()`** - Returns basic information about the plugin
2. **`your_plugin_plugin_configure()`** - Configures the plugin with provided settings
3. **`your_plugin_plugin_check()`** - Performs the actual check and returns results

## Status Codes

Your plugin should return one of the following status codes:

- **0**: OK - Everything is normal
- **1**: WARNING - Warning threshold exceeded
- **2**: CRITICAL - Critical threshold exceeded
- **3**: UNKNOWN - Check couldn't be performed

## Output Format

Your plugin must return a JSON output in the following format:

```json
{
  "plugin": "your_plugin",
  "status_code": 0,
  "status_message": "Status message here",
  "metrics": {
    "metric1": 42,
    "metric2": "value",
    "threshold": 90,
    "warning_threshold": 80
  },
  "timestamp": "1620000000"
}
```

## Utilities

ServerSentry provides several utility functions that you can use in your plugins:

- **`log_debug()`, `log_info()`, `log_warning()`, `log_error()`** - Logging functions
- **`command_exists()`** - Check if a command exists
- **`get_os_type()`** - Get the current OS type (linux, macos, windows)
- **`format_bytes()`** - Format bytes to human-readable string
- **`get_timestamp()`** - Get current timestamp

See `lib/core/utils.sh` for more utility functions.

## Examples

Check out the existing plugins in the `lib/plugins` directory for examples:

- `cpu` - CPU usage monitoring
- `memory` - Memory usage monitoring
- `disk` - Disk space monitoring
- `process` - Process monitoring

## Testing Your Plugin

You can test your plugin using the following command:

```bash
./bin/serversentry check your_plugin
```

## Adding Your Plugin to ServerSentry

To enable your plugin, add it to the `plugins_enabled` list in `config/serversentry.yaml`:

```yaml
plugins_enabled: [cpu, memory, disk, your_plugin]
```
