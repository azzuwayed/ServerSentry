# ServerSentry v2 Plugin Development Guide

This guide explains how to develop custom plugins for ServerSentry v2 following the Updated development standards. Plugins allow you to extend the monitoring capabilities of ServerSentry to suit your specific needs.

**📚 Important**: This guide should be used in conjunction with the Updated development standards:

- **[DEVELOPMENT_STANDARDS.md](Updated/DEVELOPMENT_STANDARDS.md)** - Complete development standards
- **[DEVELOPMENT_QUICK_REFERENCE.md](Updated/DEVELOPMENT_QUICK_REFERENCE.md)** - Quick reference guide
- **[examples/sample_module.sh](Updated/examples/sample_module.sh)** - Complete working example

## Plugin Structure

Each plugin follows the Updated module structure with proper headers, validation, and error handling:

1. **Plugin Implementation** (`lib/plugins/your_plugin/your_plugin.sh`)
2. **Plugin Configuration** (`config/plugins/your_plugin.conf`)

## Creating a Plugin

### Step 1: Create the Plugin Directory

Create a directory for your plugin in the `lib/plugins` directory:

```bash
mkdir -p lib/plugins/your_plugin
```

### Step 2: Create the Plugin Implementation

Create a file named after your plugin in the plugin directory following Updated standards:

```bash
touch lib/plugins/your_plugin/your_plugin.sh
```

Edit the file to implement the required functions using the Updated module template:

```bash
#!/usr/bin/env bash
#
# ServerSentry v2 - Your Plugin Name
#
# Brief description of what your plugin does

# Prevent multiple sourcing
if [[ "${YOUR_PLUGIN_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
YOUR_PLUGIN_MODULE_LOADED=true
export YOUR_PLUGIN_MODULE_LOADED

# Set BASE_DIR fallback if not set
if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  export BASE_DIR
fi

# Source core utilities
if [[ -f "${BASE_DIR}/lib/core/utils/error_utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils/error_utils.sh"
else
  echo "Warning: Core error utilities not found, some features may be limited" >&2
fi

# Plugin metadata
YOUR_PLUGIN_NAME="your_plugin"
YOUR_PLUGIN_VERSION="1.0"
YOUR_PLUGIN_DESCRIPTION="Description of your plugin"
YOUR_PLUGIN_AUTHOR="Your Name"

# Default configuration
YOUR_PLUGIN_THRESHOLD=90
YOUR_PLUGIN_WARNING_THRESHOLD=80
YOUR_PLUGIN_CHECK_INTERVAL=60

# Function: your_plugin_init
# Description: Initialize the plugin with required setup
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   your_plugin_init
# Dependencies:
#   - util_error_validate_input
your_plugin_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for your_plugin_init: expected 0, got $#" "your_plugin"
    return 1
  fi

  # Plugin initialization logic here
  log_debug "Your plugin initialized successfully" "your_plugin"
  return 0
}

# Function: your_plugin_get_info
# Description: Return plugin information (required)
# Parameters: None
# Returns:
#   Plugin info string via stdout
# Example:
#   info=$(your_plugin_get_info)
# Dependencies:
#   - util_error_validate_input
your_plugin_get_info() {
  if ! util_error_validate_input "your_plugin_get_info" "0" "$#"; then
    return 1
  fi

  echo "Your Plugin v${YOUR_PLUGIN_VERSION}"
  return 0
}

# Function: your_plugin_configure
# Description: Configure the plugin (required)
# Parameters:
#   $1 (string): configuration file path
# Returns:
#   0 - success
#   1 - failure
# Example:
#   your_plugin_configure "/path/to/config"
# Dependencies:
#   - util_error_validate_input
your_plugin_configure() {
  if ! util_error_validate_input "your_plugin_configure" "1" "$#"; then
    return 1
  fi

  local config_file="$1"

  # Validate config file
  if ! util_error_validate_input "$config_file" "config_file" "file"; then
    log_warning "Config file not found, using defaults: $config_file" "your_plugin"
    return 0
  fi

  # Load configuration if file exists
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  fi

  # Validate configuration values
  if ! util_error_validate_input "$YOUR_PLUGIN_THRESHOLD" "threshold" "numeric" "1-100"; then
    log_error "Invalid threshold value: $YOUR_PLUGIN_THRESHOLD" "your_plugin"
    return 1
  fi

  log_debug "Your plugin configured with: threshold=$YOUR_PLUGIN_THRESHOLD" "your_plugin"
  return 0
}

# Function: your_plugin_check
# Description: Perform the monitoring check (required)
# Parameters: None
# Returns:
#   0 - success (outputs JSON result)
#   1 - failure
# Example:
#   result=$(your_plugin_check)
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
your_plugin_check() {
  if ! util_error_validate_input "your_plugin_check" "0" "$#"; then
    return 1
  fi

  local result
  local status_code=0
  local status_message="OK"

  # Implement your check logic here using safe execution
  if ! result=$(util_error_safe_execute "your_monitoring_command" "Check failed" "" 1); then
    status_code=3
    status_message="UNKNOWN - Check couldn't be performed"
    result=0
  else
    # Evaluate result against thresholds
    if (( $(echo "$result >= $YOUR_PLUGIN_THRESHOLD" | bc -l) )); then
      status_code=2
      status_message="CRITICAL - Threshold exceeded"
    elif (( $(echo "$result >= $YOUR_PLUGIN_WARNING_THRESHOLD" | bc -l) )); then
      status_code=1
      status_message="WARNING - Warning threshold exceeded"
    fi
  fi

  # Get timestamp
  local timestamp
  timestamp=$(date +%s)

  # Return standardized JSON output
  cat <<EOF
{
  "plugin": "$YOUR_PLUGIN_NAME",
  "status_code": ${status_code},
  "status_message": "${status_message}",
  "metrics": {
    "your_metric": ${result},
    "threshold": ${YOUR_PLUGIN_THRESHOLD},
    "warning_threshold": ${YOUR_PLUGIN_WARNING_THRESHOLD}
  },
  "timestamp": "${timestamp}"
}
EOF

  return 0
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f your_plugin_init
  export -f your_plugin_get_info
  export -f your_plugin_configure
  export -f your_plugin_check
fi

# Initialize the plugin
if ! your_plugin_init; then
  log_error "Failed to initialize your plugin" "your_plugin"
fi
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

Every plugin must implement these functions following Updated standards:

1. **`your_plugin_init()`** - Initialize the plugin (follows Updated module pattern)
2. **`your_plugin_get_info()`** - Returns basic information about the plugin
3. **`your_plugin_configure(config_file)`** - Configures the plugin with provided settings
4. **`your_plugin_check()`** - Performs the actual check and returns results

All functions must:

- Use `util_error_validate_input` for parameter validation
- Include proper error handling and logging
- Follow the Updated documentation standards
- Use the module export pattern

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

ServerSentry provides comprehensive utility functions following Updated standards:

### Core Logging (with component parameter)

- **`log_debug(message, component)`** - Debug level logging
- **`log_info(message, component)`** - Info level logging
- **`log_warning(message, component)`** - Warning level logging
- **`log_error(message, component)`** - Error level logging
- **`log_critical(message, component)`** - Critical level logging

### Error Handling Utilities

- **`util_error_validate_input(value, param_name, type, validation_param)`** - Comprehensive input validation
- **`util_error_safe_execute(command, error_prefix, recovery_function, retries)`** - Safe command execution
- **`util_error_handle_network_failure(command, max_retries, delay)`** - Network error recovery

### System Utilities

- **`command_exists(command)`** - Check if a command exists
- **`get_os_type()`** - Get the current OS type (linux, macos, windows)
- **`get_linux_distro()`** - Get Linux distribution
- **`is_root()`** - Check if running as root

### Documentation Utilities

- **`util_doc_generate_function_header(function_name)`** - Generate function documentation
- **`util_doc_validate_function_documentation(file_path)`** - Validate documentation

See the Updated documentation for complete utility reference:

- `lib/core/utils/error_utils.sh` - Error handling utilities
- `lib/core/utils/documentation_utils.sh` - Documentation utilities
- `lib/core/utils.sh` - General utilities

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

For comprehensive testing, follow the Updated testing standards:

```bash
# Create a test file following Updated patterns
cp docs/developer/Updated/examples/test_sample_module.sh test_your_plugin.sh
# Edit the test file to test your plugin functions
./test_your_plugin.sh
```

## Adding Your Plugin to ServerSentry

To enable your plugin, add it to the `plugins_enabled` list in `config/serversentry.yaml`:

```yaml
plugins_enabled: [cpu, memory, disk, your_plugin]
```

## Development Best Practices

Follow the Updated development standards:

1. **Use the Updated module template** - Start with the proper header and structure
2. **Implement comprehensive error handling** - Use `util_error_validate_input` and related functions
3. **Include complete documentation** - Follow the Updated documentation standards
4. **Test thoroughly** - Use the Updated testing patterns
5. **Export functions properly** - Use the module export pattern

For complete development guidelines, see:

- **[DEVELOPMENT_STANDARDS.md](Updated/DEVELOPMENT_STANDARDS.md)**
- **[DEVELOPMENT_QUICK_REFERENCE.md](Updated/DEVELOPMENT_QUICK_REFERENCE.md)**
- **[examples/sample_module.sh](Updated/examples/sample_module.sh)**
