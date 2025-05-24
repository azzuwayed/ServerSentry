# ServerSentry v2

A modular, plugin-based server monitoring system written in Bash.

## Features

- **Plugin Architecture**: Easily extend monitoring capabilities
- **Cross-Platform**: Works on Linux and macOS
- **Flexible Configuration**: YAML-based configuration with environment variable overrides
- **Multiple Notification Channels**: Teams, Slack, Discord, and email support
- **Structured Logging**: Enhanced logging with levels and rotation

## Installation

```bash
git clone https://github.com/yourusername/ServerSentry.git
cd ServerSentry/v2
chmod +x bin/serversentry
```

Add to your PATH:

```bash
echo 'export PATH="$PATH:$(pwd)/bin"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

```bash
# Check system status
serversentry status

# Run a specific plugin check
serversentry check cpu

# Start monitoring in the background
serversentry start

# Stop monitoring
serversentry stop

# View logs
serversentry logs

# Configure ServerSentry
serversentry configure
```

## Configuration

Configuration files are located in the `config/` directory:

- `serversentry.yaml`: Main configuration
- `plugins/`: Plugin-specific configurations

## Creating Plugins

Plugins follow a simple interface:

1. Implement the required functions:

   - `[plugin_name]_plugin_info()`
   - `[plugin_name]_plugin_check()`
   - `[plugin_name]_plugin_configure()`

2. Place in the appropriate directory:

   - `lib/plugins/[plugin_name]/[plugin_name].sh`

3. Add configuration:
   - `config/plugins/[plugin_name].conf`

See the CPU plugin for an example.

## License

MIT
