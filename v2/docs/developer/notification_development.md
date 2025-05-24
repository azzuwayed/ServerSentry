# ServerSentry v2 Notification Provider Development Guide

This guide explains how to develop custom notification providers for ServerSentry v2. Notification providers allow you to send alerts to different services or systems when monitoring thresholds are exceeded.

## Notification Provider Structure

Each notification provider consists of at least two files:

1. **Provider Implementation** (`lib/notifications/your_provider/your_provider.sh`)
2. **Provider Configuration** (`config/notifications/your_provider.conf`)

## Creating a Notification Provider

### Step 1: Create the Provider Directory

Create a directory for your provider in the `lib/notifications` directory:

```bash
mkdir -p lib/notifications/your_provider
```

### Step 2: Create the Provider Implementation

Create a file named after your provider in the provider directory:

```bash
touch lib/notifications/your_provider/your_provider.sh
```

Edit the file to implement the required functions:

```bash
#!/bin/bash
#
# ServerSentry v2 - Your Notification Provider
#
# Brief description of what your notification provider does

# Provider metadata
your_provider_provider_name="your_provider"
your_provider_provider_version="1.0"
your_provider_provider_description="Description of your provider"
your_provider_provider_author="Your Name"

# Default configuration
your_provider_url=""
your_provider_token=""
your_provider_notification_title="ServerSentry Alert"
# Add any other configuration variables your provider needs

# Return provider information (required)
your_provider_provider_info() {
  echo "Your Notification Provider v${your_provider_provider_version}"
}

# Configure the provider (required)
your_provider_provider_configure() {
  local config_file="$1"

  # Load global configuration first
  your_provider_url=$(get_config "your_provider_url" "")
  your_provider_token=$(get_config "your_provider_token" "")
  your_provider_notification_title=$(get_config "your_provider_notification_title" "ServerSentry Alert")

  # Load provider-specific configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$your_provider_url" ]; then
    log_error "Your provider URL not configured"
    return 1
  fi

  log_debug "Your notification provider configured"

  return 0
}

# Send notification (required)
your_provider_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="$4"

  # Determine status text
  local status_text
  case "$status_code" in
    0) status_text="OK" ;;
    1) status_text="WARNING" ;;
    2) status_text="CRITICAL" ;;
    *) status_text="UNKNOWN" ;;
  esac

  # Get the hostname
  local hostname
  hostname=$(hostname)

  # Format timestamp
  local timestamp
  timestamp=$(get_formatted_date)

  # Implement your notification logic here
  # This should use the provided parameters to send a notification

  log_debug "Sending notification via your_provider"

  # Example: Send via HTTP
  if ! command_exists curl; then
    log_error "Cannot send notification: 'curl' command not found"
    return 1
  fi

  # Create payload for your service
  local payload="..."

  # Send using curl (example)
  local response
  response=$(curl -s -H "Content-Type: application/json" -d "$payload" "$your_provider_url" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send notification: $response"
    return 1
  fi

  log_debug "Notification sent successfully"
  return 0
}
```

### Step 3: Create the Provider Configuration

Create a configuration file for your notification provider:

```bash
touch config/notifications/your_provider.conf
```

Edit the file to define default configuration:

```bash
# Your Notification Provider Configuration

# Provider URL (required)
your_provider_url="https://example.com/api/notify"

# API token/key (if needed)
your_provider_token="your-api-token"

# Notification title
your_provider_notification_title="ServerSentry Alert"

# Add any other configuration options your provider needs
```

## Notification Provider Interface

Every notification provider must implement these three functions:

1. **`your_provider_provider_info()`** - Returns basic information about the provider
2. **`your_provider_provider_configure()`** - Configures the provider with provided settings
3. **`your_provider_provider_send()`** - Sends notifications when called

## Notification Parameters

The `your_provider_provider_send()` function receives these parameters:

1. **`status_code`** - Numeric status code (0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN)
2. **`status_message`** - Human-readable status message
3. **`plugin_name`** - Name of the plugin that triggered the notification
4. **`details`** - JSON string with detailed metrics from the plugin

## Utilities

ServerSentry provides several utility functions that you can use in your notification providers:

- **`log_debug()`, `log_info()`, `log_warning()`, `log_error()`** - Logging functions
- **`command_exists()`** - Check if a command exists
- **`get_formatted_date()`** - Get formatted date string
- **`json_escape()`** - Escape strings for JSON
- **`url_encode()`** - URL encode a string

See `lib/core/utils.sh` for more utility functions.

## Examples

Check out the existing notification providers in the `lib/notifications` directory for examples:

- `teams` - Microsoft Teams webhook notifications
- `slack` - Slack webhook notifications
- `discord` - Discord webhook notifications
- `email` - Email notifications

## Testing Your Notification Provider

You can test your notification provider by enabling it and triggering an alert:

1. Add your provider to the `notification_channels` list in `config/serversentry.yaml`:

```yaml
notification_channels: [teams, your_provider]
```

2. Trigger a test alert:

```bash
./bin/serversentry check cpu
```

## Common Notification Services

Here are some common notification services you might want to integrate:

- **Slack**: Uses webhook URLs
- **Discord**: Uses webhook URLs
- **Microsoft Teams**: Uses webhook URLs
- **Email**: Requires SMTP configuration
- **Telegram**: Uses Bot API
- **PagerDuty**: Uses Events API
- **OpsGenie**: Uses Alert API
