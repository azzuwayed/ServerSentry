# ServerSentry v2 - Complete Function Registry

This document provides a comprehensive registry of all functions in the ServerSentry v2 codebase, organized by module and functionality.

## 📋 Table of Contents

1. [Core System Functions](#core-system-functions)
2. [Plugin System Functions](#plugin-system-functions)
3. [Notification System Functions](#notification-system-functions)
4. [User Interface Functions](#user-interface-functions)
5. [Utility Functions](#utility-functions)
6. [Configuration Functions](#configuration-functions)
7. [Function Usage Patterns](#function-usage-patterns)

---

## 🔧 Core System Functions

### Configuration Management (`lib/core/config.sh`)

| Function                   | Purpose                             | Parameters               | Returns              |
| -------------------------- | ----------------------------------- | ------------------------ | -------------------- |
| `init_config()`            | Initialize configuration system     | None                     | 0=success, 1=failure |
| `load_config()`            | Main configuration loader           | None                     | 0=success, 1=failure |
| `parse_config(file)`       | Parse YAML configuration file       | `$1`: config file path   | 0=success, 1=failure |
| `apply_defaults()`         | Apply default configuration values  | None                     | 0=success            |
| `validate_config()`        | Validate configuration integrity    | None                     | 0=success, 1=failure |
| `load_env_overrides()`     | Load environment variable overrides | None                     | 0=success            |
| `create_default_config()`  | Create default configuration file   | None                     | 0=success, 1=failure |
| `get_config(key, default)` | Get configuration value             | `$1`: key, `$2`: default | Configuration value  |

### Logging System (`lib/core/logging.sh`)

| Function                     | Purpose                   | Parameters                                   | Returns              |
| ---------------------------- | ------------------------- | -------------------------------------------- | -------------------- |
| `init_logging()`             | Initialize logging system | None                                         | 0=success, 1=failure |
| `_log(level, name, message)` | Internal log function     | `$1`: level, `$2`: level name, `$3`: message | None                 |
| `log_debug(message)`         | Debug level logging       | `$1`: message                                | None                 |
| `log_info(message)`          | Info level logging        | `$1`: message                                | None                 |
| `log_warning(message)`       | Warning level logging     | `$1`: message                                | None                 |
| `log_error(message)`         | Error level logging       | `$1`: message                                | None                 |
| `log_critical(message)`      | Critical level logging    | `$1`: message                                | None                 |
| `rotate_logs()`              | Rotate log files          | None                                         | 0=success, 1=failure |

### Plugin Management (`lib/core/plugin.sh`)

| Function                         | Purpose                       | Parameters                                  | Returns                        |
| -------------------------------- | ----------------------------- | ------------------------------------------- | ------------------------------ |
| `init_plugin_system()`           | Initialize plugin system      | None                                        | 0=success, 1=failure           |
| `load_plugin(name)`              | Load specific plugin          | `$1`: plugin name                           | 0=success, 1=failure           |
| `validate_plugin(name)`          | Validate plugin interface     | `$1`: plugin name                           | 0=success, 1=failure           |
| `register_plugin(name)`          | Register plugin with system   | `$1`: plugin name                           | 0=success, 1=failure           |
| `run_plugin_check(name, notify)` | Run plugin check              | `$1`: plugin name, `$2`: send notifications | 0=success, 1=failure           |
| `is_plugin_registered(name)`     | Check if plugin is registered | `$1`: plugin name                           | 0=registered, 1=not registered |
| `list_plugins()`                 | List all registered plugins   | None                                        | Plugin list output             |
| `run_all_plugin_checks()`        | Run all plugin checks         | None                                        | Combined results               |

### Notification Management (`lib/core/notification.sh`)

| Function                                            | Purpose                        | Parameters                                                    | Returns              |
| --------------------------------------------------- | ------------------------------ | ------------------------------------------------------------- | -------------------- |
| `init_notification_system()`                        | Initialize notification system | None                                                          | 0=success, 1=failure |
| `load_notification_provider(name)`                  | Load notification provider     | `$1`: provider name                                           | 0=success, 1=failure |
| `validate_notification_provider(name)`              | Validate provider interface    | `$1`: provider name                                           | 0=success, 1=failure |
| `register_notification_provider(name)`              | Register notification provider | `$1`: provider name                                           | 0=success, 1=failure |
| `send_notification(code, message, plugin, metrics)` | Send notification              | `$1`: status code, `$2`: message, `$3`: plugin, `$4`: metrics | 0=success, 1=failure |
| `list_notification_providers()`                     | List registered providers      | None                                                          | Provider list output |

### Utility Functions (`lib/core/utils.sh`)

| Function                         | Purpose                        | Parameters                       | Returns                    |
| -------------------------------- | ------------------------------ | -------------------------------- | -------------------------- |
| `command_exists(cmd)`            | Check if command exists        | `$1`: command name               | 0=exists, 1=not exists     |
| `is_root()`                      | Check if running as root       | None                             | 0=root, 1=not root         |
| `get_os_type()`                  | Get operating system type      | None                             | OS type string             |
| `get_linux_distro()`             | Get Linux distribution         | None                             | Distribution name          |
| `format_bytes(bytes, precision)` | Format bytes to human readable | `$1`: bytes, `$2`: precision     | Formatted string           |
| `to_lowercase(str)`              | Convert to lowercase           | `$1`: string                     | Lowercase string           |
| `to_uppercase(str)`              | Convert to uppercase           | `$1`: string                     | Uppercase string           |
| `trim(str)`                      | Trim whitespace                | `$1`: string                     | Trimmed string             |
| `is_valid_ip(ip)`                | Validate IP address            | `$1`: IP address                 | 0=valid, 1=invalid         |
| `random_string(length)`          | Generate random string         | `$1`: length                     | Random string              |
| `is_dir_writable(dir)`           | Check if directory is writable | `$1`: directory path             | 0=writable, 1=not writable |
| `get_timestamp()`                | Get current timestamp          | None                             | Unix timestamp             |
| `get_formatted_date(format)`     | Get formatted date             | `$1`: date format                | Formatted date             |
| `safe_write(file, content)`      | Safe file write operation      | `$1`: target file, `$2`: content | 0=success, 1=failure       |
| `url_encode(str)`                | URL encode string              | `$1`: string                     | URL encoded string         |
| `json_escape(str)`               | JSON escape string             | `$1`: string                     | JSON escaped string        |

---

## 🔌 Plugin System Functions

### Standard Plugin Interface

Each plugin must implement these functions:

| Function Pattern                     | Purpose                     | Parameters             | Returns              |
| ------------------------------------ | --------------------------- | ---------------------- | -------------------- |
| `${PLUGIN}_plugin_info()`            | Get plugin information      | None                   | Plugin info string   |
| `${PLUGIN}_plugin_check()`           | Run plugin monitoring check | None                   | JSON result          |
| `${PLUGIN}_plugin_configure(config)` | Configure plugin            | `$1`: config file path | 0=success, 1=failure |

### Plugin Health System (`lib/core/plugin_health.sh`)

| Function                                            | Purpose                             | Parameters                              | Returns              |
| --------------------------------------------------- | ----------------------------------- | --------------------------------------- | -------------------- |
| `init_plugin_health_system()`                       | Initialize plugin health tracking   | None                                    | 0=success, 1=failure |
| `create_plugin_registry()`                          | Create initial plugin registry      | None                                    | 0=success            |
| `register_plugin_health(name, version, desc, deps)` | Register plugin for health tracking | Plugin details                          | 0=success, 1=failure |
| `update_plugin_health(name, status, message)`       | Update plugin health status         | `$1`: name, `$2`: status, `$3`: message | 0=success, 1=failure |
| `get_plugin_health(name)`                           | Get plugin health status            | `$1`: plugin name                       | Health JSON          |
| `get_plugin_version(name)`                          | Get plugin version                  | `$1`: plugin name                       | Version string       |
| `check_plugin_updates(name)`                        | Check for plugin updates            | `$1`: plugin name                       | Update info JSON     |
| `get_plugin_health_summary()`                       | Get overall health summary          | None                                    | Summary JSON         |
| `list_plugin_health()`                              | List all plugin health status       | None                                    | Health list output   |
| `check_plugin_dependencies(name)`                   | Check plugin dependencies           | `$1`: plugin name                       | Dependency status    |
| `generate_plugin_health_report(file)`               | Generate health report              | `$1`: output file                       | 0=success, 1=failure |
| `cleanup_health_logs(days)`                         | Cleanup old health logs             | `$1`: days to keep                      | 0=success            |

### Plugin Performance Tracking (`lib/core/plugin.sh`)

| Function                            | Purpose                           | Parameters                                    | Returns                |
| ----------------------------------- | --------------------------------- | --------------------------------------------- | ---------------------- |
| `plugin_registry_save()`            | Save plugin registry to storage   | None                                          | 0=success, 1=failure   |
| `plugin_registry_load()`            | Load plugin registry from storage | None                                          | 0=success, 1=failure   |
| `plugin_performance_track()`        | Track plugin performance metrics  | `$1`: plugin, `$2`: operation, `$3`: duration | 0=success              |
| `plugin_get_performance_stats()`    | Get performance statistics        | `$1`: plugin name (optional)                  | Performance stats JSON |
| `plugin_optimize_loading()`         | Optimize plugin loading order     | None                                          | 0=success              |
| `plugin_cleanup_performance_logs()` | Clean up old performance logs     | `$1`: days to keep (default: 30)              | 0=success              |

### Command Caching Utilities (`lib/core/utils/command_utils.sh`)

| Function                           | Purpose                               | Parameters                               | Returns                |
| ---------------------------------- | ------------------------------------- | ---------------------------------------- | ---------------------- |
| `util_cached_command()`            | Execute command with caching          | `$1`: command, `$2`: duration, `$3`: key | Command output         |
| `util_command_cache_clear()`       | Clear command cache                   | `$1`: pattern (optional)                 | 0=success              |
| `util_command_cache_stats()`       | Get cache statistics                  | None                                     | Cache stats JSON       |
| `util_command_cache_cleanup()`     | Clean up expired cache entries        | `$1`: max age seconds (default: 3600)    | 0=success              |
| `util_batch_commands()`            | Execute multiple commands efficiently | `$@`: commands to execute                | Combined results       |
| `util_optimize_common_commands()`  | Pre-cache common system commands      | None                                     | 0=success              |
| `util_command_exists_cached()`     | Cached command existence check        | `$1`: command name                       | 0=exists, 1=not exists |
| `util_get_cached_timestamp()`      | Get cached timestamp                  | `$1`: cache duration (default: 1)        | Unix timestamp         |
| `util_get_cached_formatted_date()` | Get cached formatted date             | `$1`: format, `$2`: duration             | Formatted date         |

### Performance Measurement (`lib/core/utils/performance_utils.sh`)

| Function                               | Purpose                        | Parameters                                       | Returns                |
| -------------------------------------- | ------------------------------ | ------------------------------------------------ | ---------------------- |
| `util_performance_timer_start()`       | Start a performance timer      | `$1`: timer name                                 | 0=success              |
| `util_performance_timer_stop()`        | Stop timer and return duration | `$1`: timer name                                 | Duration in seconds    |
| `util_performance_measure()`           | Measure performance of command | `$1`: operation name, `$@`: command              | Command output         |
| `util_performance_counter_increment()` | Increment performance counter  | `$1`: counter name, `$2`: increment (default: 1) | 0=success              |
| `util_performance_counter_get()`       | Get counter value              | `$1`: counter name                               | Counter value          |
| `util_performance_benchmark_system()`  | Run system benchmark           | None                                             | Benchmark results JSON |
| `util_performance_get_stats()`         | Get performance statistics     | None                                             | Performance stats JSON |
| `util_performance_cleanup_logs()`      | Clean up old performance logs  | `$1`: days to keep (default: 7)                  | 0=success              |
| `util_performance_optimize_startup()`  | Run startup optimizations      | None                                             | 0=success              |

### Configuration Caching (`lib/core/utils/config_utils.sh`)

| Function                           | Purpose                       | Parameters                                  | Returns              |
| ---------------------------------- | ----------------------------- | ------------------------------------------- | -------------------- |
| `util_config_get_cached()`         | Get cached configuration      | `$1`: file, `$2`: namespace, `$3`: duration | 0=success, 1=failure |
| `util_config_parse_yaml()`         | Parse YAML with caching       | `$1`: file, `$2`: namespace, `$3`: defaults | 0=success, 1=failure |
| `util_config_validate_values()`    | Validate configuration values | `$1`: rules array, `$2`: namespace          | 0=valid, 1=invalid   |
| `util_config_load_env_overrides()` | Load environment overrides    | `$1`: prefix, `$2`: namespace               | 0=success            |

---

## 📢 Notification System Functions

### Standard Notification Provider Interface

Each notification provider must implement:

| Function Pattern                            | Purpose                  | Parameters                 | Returns              |
| ------------------------------------------- | ------------------------ | -------------------------- | -------------------- |
| `${PROVIDER}_provider_info()`               | Get provider information | None                       | Provider info string |
| `${PROVIDER}_provider_configure(config)`    | Configure provider       | `$1`: config file          | 0=success, 1=failure |
| `${PROVIDER}_provider_send(message, level)` | Send notification        | `$1`: message, `$2`: level | 0=success, 1=failure |

### Template System (`lib/core/templates.sh`)

| Function                                                                        | Purpose                               | Parameters                 | Returns              |
| ------------------------------------------------------------------------------- | ------------------------------------- | -------------------------- | -------------------- |
| `init_template_system()`                                                        | Initialize template system            | None                       | 0=success, 1=failure |
| `create_default_templates()`                                                    | Create default notification templates | None                       | 0=success, 1=failure |
| `process_template(file, code, message, plugin, metrics)`                        | Process notification template         | Template parameters        | Processed content    |
| `get_template(type, provider)`                                                  | Get template for notification         | `$1`: type, `$2`: provider | Template file path   |
| `generate_notification_content(type, provider, code, message, plugin, metrics)` | Generate notification content         | Notification parameters    | Generated content    |
| `list_templates()`                                                              | List available templates              | None                       | Template list output |
| `validate_template(file)`                                                       | Validate template syntax              | `$1`: template file        | 0=valid, 1=invalid   |

---

## 🔍 Advanced Features Functions

### Anomaly Detection (`lib/core/anomaly.sh`)

| Function                                                    | Purpose                               | Parameters                              | Returns              |
| ----------------------------------------------------------- | ------------------------------------- | --------------------------------------- | -------------------- |
| `init_anomaly_system()`                                     | Initialize anomaly detection          | None                                    | 0=success, 1=failure |
| `store_metric_data(plugin, metric, value)`                  | Store metric data for analysis        | `$1`: plugin, `$2`: metric, `$3`: value | 0=success, 1=failure |
| `detect_statistical_anomaly(plugin, metric, value, config)` | Detect statistical anomalies          | Anomaly parameters                      | 0=normal, 1=anomaly  |
| `calculate_statistics(file, window)`                        | Calculate statistical metrics         | `$1`: data file, `$2`: window size      | Statistics CSV       |
| `run_anomaly_detection()`                                   | Run anomaly detection for all metrics | None                                    | 0=success, 1=failure |
| `parse_anomaly_config(file)`                                | Parse anomaly configuration           | `$1`: config file                       | 0=success, 1=failure |
| `get_anomaly_summary(days)`                                 | Get anomaly detection summary         | `$1`: days to analyze                   | Summary output       |

### Composite Checks (`lib/core/composite.sh`)

| Function                                 | Purpose                             | Parameters                       | Returns               |
| ---------------------------------------- | ----------------------------------- | -------------------------------- | --------------------- |
| `init_composite_system()`                | Initialize composite check system   | None                             | 0=success, 1=failure  |
| `parse_composite_config(file)`           | Parse composite check configuration | `$1`: config file                | 0=success, 1=failure  |
| `evaluate_composite_rule(rule, results)` | Evaluate composite rule logic       | `$1`: rule, `$2`: plugin results | 0=pass, 1=fail        |
| `run_composite_check(config, results)`   | Run single composite check          | `$1`: config file, `$2`: results | Check result JSON     |
| `run_all_composite_checks(results)`      | Run all composite checks            | `$1`: plugin results             | Combined results JSON |
| `list_composite_checks()`                | List all composite checks           | None                             | Composite checks list |

### Diagnostics System (`lib/core/diagnostics.sh`)

| Function                               | Purpose                              | Parameters            | Returns                 |
| -------------------------------------- | ------------------------------------ | --------------------- | ----------------------- |
| `init_diagnostics_system()`            | Initialize diagnostics system        | None                  | 0=success, 1=failure    |
| `run_full_diagnostics()`               | Run comprehensive system diagnostics | None                  | Diagnostics report JSON |
| `check_system_resources()`             | Check system resource usage          | None                  | Resource check JSON     |
| `check_disk_space()`                   | Check disk space availability        | None                  | Disk space JSON         |
| `check_memory_usage()`                 | Check memory usage                   | None                  | Memory usage JSON       |
| `check_cpu_load()`                     | Check CPU load                       | None                  | CPU load JSON           |
| `check_network_connectivity()`         | Check network connectivity           | None                  | Network check JSON      |
| `check_serversentry_health()`          | Check ServerSentry health            | None                  | Health check JSON       |
| `generate_diagnostics_report(results)` | Generate diagnostics report          | `$1`: results JSON    | 0=success, 1=failure    |
| `get_diagnostic_summary(days)`         | Get diagnostic summary               | `$1`: days to analyze | Summary output          |
| `cleanup_diagnostic_reports(days)`     | Cleanup old diagnostic reports       | `$1`: days to keep    | 0=success               |

### Dynamic Reload (`lib/core/reload.sh`)

| Function                        | Purpose                            | Parameters            | Returns              |
| ------------------------------- | ---------------------------------- | --------------------- | -------------------- |
| `init_reload_system()`          | Initialize dynamic reload system   | None                  | 0=success, 1=failure |
| `setup_signal_handlers()`       | Setup signal handlers for reload   | None                  | 0=success            |
| `handle_reload_signal()`        | Handle configuration reload signal | None                  | 0=success            |
| `handle_plugin_reload_signal()` | Handle plugin reload signal        | None                  | 0=success            |
| `handle_log_rotation_signal()`  | Handle log rotation signal         | None                  | 0=success            |
| `perform_config_reload()`       | Perform configuration reload       | None                  | 0=success, 1=failure |
| `perform_plugin_reload()`       | Perform plugin reload              | None                  | 0=success, 1=failure |
| `validate_config_file(file)`    | Validate configuration file        | `$1`: config file     | 0=valid, 1=invalid   |
| `reload_notification_configs()` | Reload notification configurations | None                  | 0=success, 1=failure |
| `send_reload_signal(type)`      | Send reload signal to process      | `$1`: signal type     | 0=success, 1=failure |
| `show_reload_status()`          | Show reload system status          | None                  | Status output        |
| `get_reload_history(lines)`     | Get reload history                 | `$1`: number of lines | History output       |

---

## 🎨 User Interface Functions

### Command Line Interface (`lib/ui/cli/`)

| Function             | Purpose                        | Parameters              | Returns              |
| -------------------- | ------------------------------ | ----------------------- | -------------------- |
| `process_commands()` | Process command line arguments | `$@`: command arguments | 0=success, 1=failure |
| `show_help()`        | Display help information       | None                    | Help output          |
| `show_version()`     | Display version information    | None                    | Version output       |
| `show_status()`      | Display system status          | None                    | Status output        |

### Text User Interface (`lib/ui/tui/`)

Functions for the interactive TUI dashboard (to be documented based on actual implementation).

---

## 📊 Function Usage Patterns

### Error Handling Pattern

```bash
# Standard error handling with logging
function_name() {
    local param="$1"

    # Validate input
    if [[ -z "$param" ]]; then
        log_error "Parameter required"
        return 1
    fi

    # Main operation
    if ! operation_command; then
        log_error "Operation failed"
        return 1
    fi

    log_info "Operation completed successfully"
    return 0
}
```

### Configuration Pattern

```bash
# Standard configuration loading
load_module_config() {
    local config_file="${CONFIG_DIR}/${MODULE_NAME}.conf"

    if [[ ! -f "$config_file" ]]; then
        log_warning "Config not found, using defaults"
        return 0
    fi

    source "$config_file" || {
        log_error "Failed to load config: $config_file"
        return 1
    }

    return 0
}
```

### Plugin Interface Pattern

```bash
# Standard plugin function implementation
plugin_name_plugin_check() {
    local result='{"status_code": 0, "status_message": "OK", "metrics": {}}'

    # Perform monitoring check
    local metric_value
    metric_value=$(get_metric_value) || {
        result='{"status_code": 2, "status_message": "Failed to get metric", "metrics": {}}'
        echo "$result"
        return 1
    }

    # Update result with metrics
    result=$(echo "$result" | jq --argjson value "$metric_value" '.metrics.metric_name = $value')

    echo "$result"
    return 0
}
```

### Notification Pattern

```bash
# Standard notification provider implementation
provider_name_provider_send() {
    local message="$1"
    local level="$2"

    # Validate configuration
    if [[ -z "$webhook_url" ]]; then
        log_error "Provider not configured"
        return 1
    fi

    # Send notification
    local response
    response=$(curl -s -X POST "$webhook_url" -d "$message") || {
        log_error "Failed to send notification"
        return 1
    }

    log_debug "Notification sent successfully"
    return 0
}
```

---

## 🔄 Function Dependencies

### Core Dependencies

```
main()
├── load_config()
├── init_logging()
├── init_plugin_system()
│   ├── load_plugin()
│   ├── validate_plugin()
│   └── register_plugin()
├── init_notification_system()
│   ├── load_notification_provider()
│   ├── validate_notification_provider()
│   └── register_notification_provider()
└── process_commands()
```

### Plugin System Dependencies

```
run_plugin_check()
├── is_plugin_registered()
├── ${PLUGIN}_plugin_check()
└── send_notification()
    ├── generate_notification_content()
    │   ├── get_template()
    │   └── process_template()
    └── ${PROVIDER}_provider_send()
```

---

**Last Updated**: $(date)
**Total Functions Documented**: 100+
**Coverage**: All core modules, plugin interfaces, notification system
