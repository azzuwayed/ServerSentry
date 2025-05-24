# ServerSentry v2 - Development Guide

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Code Organization](#code-organization)
3. [Function Registry](#function-registry)
4. [Development Standards](#development-standards)
5. [Testing Guidelines](#testing-guidelines)
6. [Contributing Guidelines](#contributing-guidelines)

## 🏗️ Architecture Overview

ServerSentry v2 follows a modular, plugin-based architecture designed for scalability and maintainability.

### Core Principles

- **Separation of Concerns**: Each module has a single, well-defined responsibility
- **Plugin Architecture**: Extensible monitoring capabilities through plugins
- **Configuration-Driven**: Behavior controlled via YAML/config files
- **Fail-Safe Design**: Graceful degradation when components fail
- **Minimal Dependencies**: Pure Bash implementation for maximum compatibility

### System Layers

```
┌─────────────────────────────────────┐
│           Entry Point               │
│        bin/serversentry             │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│          User Interface             │
│    lib/ui/cli/     lib/ui/tui/      │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│          Core Systems               │
│  config  logging  plugin  utils     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│         Business Logic              │
│ anomaly composite diagnostics etc.  │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│        Plugin System                │
│   cpu   memory   disk   process     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│     Notification System             │
│  teams  slack  email  webhook       │
└─────────────────────────────────────┘
```

## 📁 Code Organization

### Directory Structure Standards

```
v2/
├── bin/                    # Executable entry points
├── lib/                    # Library modules
│   ├── core/              # Core system functionality
│   ├── plugins/           # Monitoring plugins
│   ├── notifications/     # Notification providers
│   └── ui/                # User interfaces
├── config/                # Configuration files
├── docs/                  # Documentation
├── tests/                 # Test suites
└── logs/                  # Runtime logs and data
```

### File Naming Conventions

- **Core modules**: `snake_case.sh` (e.g., `plugin_health.sh`)
- **Plugins**: Directory structure with `monitor.sh` entry point
- **Configs**: `snake_case.yaml` or `.conf` extensions
- **Tests**: Mirror source structure with `_test.sh` suffix

### Function Naming Standards

- **Public API**: `modulename_action` (e.g., `config_load`, `plugin_init`)
- **Private functions**: `_modulename_internal_action` (e.g., `_config_validate_yaml`)
- **Utility functions**: `util_action` (e.g., `util_is_numeric`)
- **Plugin functions**: `pluginname_action` (e.g., `cpu_get_usage`)

## 🔧 Function Registry

### Core System Functions

#### lib/core/config.sh

- `load_config()` - Main configuration loader
- `config_get(key)` - Get configuration value
- `config_set(key, value)` - Set configuration value
- `config_validate()` - Validate configuration integrity
- `_config_parse_yaml()` - Internal YAML parser
- `_config_expand_vars()` - Internal variable expansion

#### lib/core/logging.sh

- `log_info(message)` - Info level logging
- `log_warning(message)` - Warning level logging
- `log_error(message)` - Error level logging
- `log_debug(message)` - Debug level logging
- `logging_init()` - Initialize logging system
- `_log_format()` - Internal log formatter

#### lib/core/plugin.sh

- `init_plugin_system()` - Initialize plugin system
- `plugin_load(name)` - Load specific plugin
- `plugin_unload(name)` - Unload specific plugin
- `plugin_list()` - List available plugins
- `plugin_is_loaded(name)` - Check if plugin is loaded
- `_plugin_validate()` - Internal plugin validation

#### lib/core/utils.sh

- `util_is_numeric(value)` - Check if value is numeric
- `util_timestamp()` - Get current timestamp
- `util_human_readable_size(bytes)` - Convert bytes to human readable
- `util_percentage_bar(value)` - Create ASCII percentage bar
- `util_color_text(color, text)` - Apply color to text

### Plugin System Functions

#### Standard Plugin Interface

Each plugin must implement:

- `${PLUGIN_NAME}_init()` - Initialize plugin
- `${PLUGIN_NAME}_cleanup()` - Cleanup on shutdown
- `${PLUGIN_NAME}_get_metrics()` - Return current metrics
- `${PLUGIN_NAME}_validate_config()` - Validate plugin config

### Notification System Functions

#### Standard Notification Interface

Each notification provider must implement:

- `${PROVIDER}_init()` - Initialize provider
- `${PROVIDER}_send(message, level)` - Send notification
- `${PROVIDER}_test()` - Test connectivity
- `${PROVIDER}_validate_config()` - Validate provider config

## 📏 Development Standards

### Code Quality Standards

1. **Error Handling**

   ```bash
   # Always check return codes
   if ! some_command; then
       log_error "Command failed"
       return 1
   fi

   # Use set -eo pipefail at script start
   set -eo pipefail
   ```

2. **Variable Naming**

   ```bash
   # Constants in UPPER_CASE
   readonly DEFAULT_CONFIG_PATH="/etc/serversentry"

   # Local variables in lower_case
   local config_file="/path/to/config"

   # Global variables with prefix
   SERVERSENTRY_CONFIG_LOADED=false
   ```

3. **Function Documentation**

   ```bash
   # Function: function_name
   # Description: Brief description of what the function does
   # Parameters:
   #   $1 - parameter description
   #   $2 - parameter description
   # Returns:
   #   0 - success
   #   1 - error description
   # Globals:
   #   GLOBAL_VAR - description of global variable usage
   function_name() {
       # Implementation
   }
   ```

4. **Input Validation**

   ```bash
   function example_function() {
       local input="$1"

       # Validate required parameters
       if [[ -z "$input" ]]; then
           log_error "Input parameter required"
           return 1
       fi

       # Validate parameter format
       if ! util_is_numeric "$input"; then
           log_error "Input must be numeric"
           return 1
       fi
   }
   ```

### Security Standards

1. **File Permissions**

   - Executable scripts: `755`
   - Configuration files: `644`
   - Log files: `644`
   - Sensitive configs: `600`

2. **Input Sanitization**

   ```bash
   # Sanitize user input
   sanitized_input=$(printf '%s' "$user_input" | tr -d '[:cntrl:]')
   ```

3. **Secure Temporary Files**
   ```bash
   # Create secure temporary files
   temp_file=$(mktemp) || {
       log_error "Failed to create temporary file"
       return 1
   }
   trap 'rm -f "$temp_file"' EXIT
   ```

## 🧪 Testing Guidelines

### Test Structure

```
tests/
├── unit/                  # Unit tests for individual functions
│   ├── core/             # Tests for core modules
│   ├── plugins/          # Tests for plugins
│   └── notifications/    # Tests for notification providers
└── integration/          # Integration tests
    ├── end_to_end/       # Full system tests
    └── scenarios/        # Specific use case tests
```

### Test Naming Convention

- Unit tests: `test_${module}_${function}.sh`
- Integration tests: `test_${scenario}.sh`

### Test Framework Standards

```bash
#!/bin/bash
# Test: test_config_load
# Description: Test configuration loading functionality

source "$(dirname "$0")/../../lib/core/config.sh"
source "$(dirname "$0")/../test_framework.sh"

test_config_load_success() {
    # Arrange
    local test_config="/tmp/test_config.yaml"
    echo "enabled: true" > "$test_config"

    # Act
    local result
    result=$(CONFIG_FILE="$test_config" load_config 2>&1)
    local exit_code=$?

    # Assert
    assert_equals 0 "$exit_code" "Should return success"
    assert_contains "$result" "Configuration loaded" "Should log success message"

    # Cleanup
    rm -f "$test_config"
}

# Run tests
run_test test_config_load_success
```

### Coverage Requirements

- **Core modules**: 90% function coverage
- **Plugins**: 80% function coverage
- **Notification providers**: 85% function coverage
- **Integration tests**: All critical paths covered

## 🤝 Contributing Guidelines

### Before Making Changes

1. **Check Function Registry**: Ensure you're not duplicating existing functionality
2. **Review Architecture**: Understand how your changes fit into the overall system
3. **Update Documentation**: Keep this guide current with any new functions or patterns

### Code Review Checklist

- [ ] Follows naming conventions
- [ ] Includes proper error handling
- [ ] Has function documentation
- [ ] Includes unit tests
- [ ] Updates integration tests if needed
- [ ] Updates this development guide
- [ ] No code duplication
- [ ] Security considerations addressed

### Git Workflow

1. Create feature branch from `main`
2. Implement changes following standards
3. Add/update tests
4. Update documentation
5. Submit pull request with detailed description

### Refactoring Guidelines

When refactoring existing code:

1. **Identify Redundancy**: Use this guide to find duplicate functionality
2. **Maintain Compatibility**: Ensure existing APIs still work
3. **Update Tests**: Refactor tests alongside code
4. **Update Documentation**: Keep this guide accurate
5. **Performance Impact**: Consider performance implications

## 🔍 Common Patterns

### Configuration Pattern

```bash
# Standard configuration loading pattern
load_module_config() {
    local config_file="${CONFIG_DIR}/${MODULE_NAME}.yaml"

    if [[ ! -f "$config_file" ]]; then
        log_warning "Config file not found: $config_file"
        return 1
    fi

    # Load and validate configuration
    if ! _parse_yaml_config "$config_file"; then
        log_error "Invalid configuration: $config_file"
        return 1
    fi

    log_info "Configuration loaded: $config_file"
    return 0
}
```

### Plugin Registration Pattern

```bash
# Standard plugin registration
register_plugin() {
    local plugin_name="$1"
    local plugin_dir="${PLUGINS_DIR}/${plugin_name}"

    # Validate plugin structure
    if ! _validate_plugin_structure "$plugin_dir"; then
        return 1
    fi

    # Load plugin
    source "${plugin_dir}/monitor.sh"

    # Initialize plugin
    if ! "${plugin_name}_init"; then
        log_error "Failed to initialize plugin: $plugin_name"
        return 1
    fi

    LOADED_PLUGINS+=("$plugin_name")
    log_info "Plugin registered: $plugin_name"
}
```

### Error Handling Pattern

```bash
# Standard error handling with cleanup
process_with_cleanup() {
    local temp_file
    temp_file=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }

    # Set up cleanup trap
    trap 'rm -f "$temp_file"' EXIT

    # Main processing
    if ! do_main_work "$temp_file"; then
        log_error "Main processing failed"
        return 1
    fi

    log_info "Processing completed successfully"
    return 0
}
```

---

**Last Updated**: $(date)
**Version**: 2.0.0
**Maintainer**: Development Team
