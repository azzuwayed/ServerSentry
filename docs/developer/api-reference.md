# ServerSentry v2 - API Reference

This document provides a comprehensive API reference for all functions in the ServerSentry v2 codebase, organized by module and functionality.

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

| Function                         | Purpose                             | Parameters               | Returns              |
| -------------------------------- | ----------------------------------- | ------------------------ | -------------------- |
| `config_init()`                  | Initialize configuration system     | None                     | 0=success, 1=failure |
| `config_load()`                  | Main configuration loader           | None                     | 0=success, 1=failure |
| `config_parse_yaml(file)`        | Parse YAML configuration file       | `$1`: config file path   | 0=success, 1=failure |
| `config_apply_defaults()`        | Apply default configuration values  | None                     | 0=success            |
| `config_validate()`              | Validate configuration integrity    | None                     | 0=success, 1=failure |
| `config_load_env_overrides()`    | Load environment variable overrides | None                     | 0=success            |
| `config_create_default()`        | Create default configuration file   | None                     | 0=success, 1=failure |
| `config_get_value(key, default)` | Get configuration value             | `$1`: key, `$2`: default | Configuration value  |

### Logging System (`lib/core/logging.sh`)

| Function                     | Purpose                   | Parameters                                   | Returns              |
| ---------------------------- | ------------------------- | -------------------------------------------- | -------------------- |
| `logging_init()`             | Initialize logging system | None                                         | 0=success, 1=failure |
| `_log(level, name, message)` | Internal log function     | `$1`: level, `$2`: level name, `$3`: message | None                 |
| `log_debug(message)`         | Debug level logging       | `$1`: message                                | None                 |
| `log_info(message)`          | Info level logging        | `$1`: message                                | None                 |
| `log_warning(message)`       | Warning level logging     | `$1`: message                                | None                 |
| `log_error(message)`         | Error level logging       | `$1`: message                                | None                 |
| `log_critical(message)`      | Critical level logging    | `$1`: message                                | None                 |
| `logging_rotate()`           | Rotate log files          | None                                         | 0=success, 1=failure |

### Plugin Management (`lib/core/plugin.sh`)

| Function                         | Purpose                       | Parameters                                  | Returns                        |
| -------------------------------- | ----------------------------- | ------------------------------------------- | ------------------------------ |
| `plugin_system_init()`           | Initialize plugin system      | None                                        | 0=success, 1=failure           |
| `plugin_load(name)`              | Load specific plugin          | `$1`: plugin name                           | 0=success, 1=failure           |
| `plugin_validate(name)`          | Validate plugin interface     | `$1`: plugin name                           | 0=success, 1=failure           |
| `plugin_register(name)`          | Register plugin with system   | `$1`: plugin name                           | 0=success, 1=failure           |
| `plugin_run_check(name, notify)` | Run plugin check              | `$1`: plugin name, `$2`: send notifications | 0=success, 1=failure           |
| `plugin_is_registered(name)`     | Check if plugin is registered | `$1`: plugin name                           | 0=registered, 1=not registered |
| `plugin_list()`                  | List all registered plugins   | None                                        | Plugin list output             |
| `plugin_run_all_checks()`        | Run all plugin checks         | None                                        | Combined results               |

### Notification Management (`lib/core/notification.sh`)

| Function                                            | Purpose                        | Parameters                                                    | Returns              |
| --------------------------------------------------- | ------------------------------ | ------------------------------------------------------------- | -------------------- |
| `notification_system_init()`                        | Initialize notification system | None                                                          | 0=success, 1=failure |
| `notification_load_provider(name)`                  | Load notification provider     | `$1`: provider name                                           | 0=success, 1=failure |
| `notification_validate_provider(name)`              | Validate provider interface    | `$1`: provider name                                           | 0=success, 1=failure |
| `notification_register_provider(name)`              | Register notification provider | `$1`: provider name                                           | 0=success, 1=failure |
| `notification_send(code, message, plugin, metrics)` | Send notification              | `$1`: status code, `$2`: message, `$3`: plugin, `$4`: metrics | 0=success, 1=failure |
| `notification_list_providers()`                     | List registered providers      | None                                                          | Provider list output |

### Utility Functions (`lib/core/utils/`)

| Function                              | Purpose                        | Parameters                       | Returns                    |
| ------------------------------------- | ------------------------------ | -------------------------------- | -------------------------- |
| `util_command_exists(cmd)`            | Check if command exists        | `$1`: command name               | 0=exists, 1=not exists     |
| `util_is_root()`                      | Check if running as root       | None                             | 0=root, 1=not root         |
| `util_get_os_type()`                  | Get operating system type      | None                             | OS type string             |
| `util_get_linux_distro()`             | Get Linux distribution         | None                             | Distribution name          |
| `util_format_bytes(bytes, precision)` | Format bytes to human readable | `$1`: bytes, `$2`: precision     | Formatted string           |
| `util_to_lowercase(str)`              | Convert to lowercase           | `$1`: string                     | Lowercase string           |
| `util_to_uppercase(str)`              | Convert to uppercase           | `$1`: string                     | Uppercase string           |
| `util_trim(str)`                      | Trim whitespace                | `$1`: string                     | Trimmed string             |
| `util_is_valid_ip(ip)`                | Validate IP address            | `$1`: IP address                 | 0=valid, 1=invalid         |
| `util_random_string(length)`          | Generate random string         | `$1`: length                     | Random string              |
| `util_is_dir_writable(dir)`           | Check if directory is writable | `$1`: directory path             | 0=writable, 1=not writable |
| `util_get_timestamp()`                | Get current timestamp          | None                             | Unix timestamp             |
| `util_get_formatted_date(format)`     | Get formatted date             | `$1`: date format                | Formatted date             |
| `util_safe_write(file, content)`      | Safe file write operation      | `$1`: target file, `$2`: content | 0=success, 1=failure       |
| `util_url_encode(str)`                | URL encode string              | `$1`: string                     | URL encoded string         |
| `util_json_escape(str)`               | JSON escape string             | `$1`: string                     | JSON escaped string        |

---

## 🔌 Plugin System Functions

### Standard Plugin Interface

Each plugin must implement these functions:

| Function Pattern                     | Purpose                     | Parameters             | Returns              |
| ------------------------------------ | --------------------------- | ---------------------- | -------------------- |
| `${PLUGIN}_plugin_info()`            | Get plugin information      | None                   | Plugin info string   |
| `${PLUGIN}_plugin_check()`           | Run plugin monitoring check | None                   | JSON result          |
| `${PLUGIN}_plugin_configure(config)` | Configure plugin            | `$1`: config file path | 0=success, 1=failure |

### Validation Utilities (`lib/core/utils/validation_utils.sh`)

| Function                                           | Purpose                     | Parameters                          | Returns            |
| -------------------------------------------------- | --------------------------- | ----------------------------------- | ------------------ |
| `util_require_param(param, name)`                  | Validate required parameter | `$1`: param value, `$2`: param name | 0=valid, 1=invalid |
| `util_validate_numeric(val, name)`                 | Validate numeric parameter  | `$1`: value, `$2`: param name       | 0=valid, 1=invalid |
| `util_validate_boolean(val, name)`                 | Validate boolean parameter  | `$1`: value, `$2`: param name       | 0=valid, 1=invalid |
| `util_validate_string_length(str, min, max, name)` | Validate string length      | String and length parameters        | 0=valid, 1=invalid |
| `util_validate_path_safe(path, name)`              | Validate path safety        | `$1`: path, `$2`: param name        | 0=safe, 1=unsafe   |

### JSON Utilities (`lib/core/utils/json_utils.sh`)

| Function                                     | Purpose                  | Parameters                            | Returns           |
| -------------------------------------------- | ------------------------ | ------------------------------------- | ----------------- |
| `util_json_set_value(json, path, val)`       | Set JSON value at path   | `$1`: JSON, `$2`: path, `$3`: value   | Updated JSON      |
| `util_json_get_value(json, path)`            | Get JSON value at path   | `$1`: JSON, `$2`: path                | Extracted value   |
| `util_json_merge(base, overlay)`             | Merge two JSON objects   | `$1`: base JSON, `$2`: overlay JSON   | Merged JSON       |
| `util_json_create_object()`                  | Create empty JSON object | None                                  | Empty JSON object |
| `util_json_add_array_item(json, path, item)` | Add item to JSON array   | JSON, array path, and item parameters | Updated JSON      |

### Array Utilities (`lib/core/utils/array_utils.sh`)

| Function                                | Purpose                      | Parameters                         | Returns              |
| --------------------------------------- | ---------------------------- | ---------------------------------- | -------------------- |
| `util_array_contains(needle, haystack)` | Check if array contains item | `$1`: item, `$@`: array            | 0=found, 1=not found |
| `util_array_add_unique(array_ref, val)` | Add unique item to array     | `$1`: array reference, `$2`: value | None                 |
| `util_array_remove(array_ref, val)`     | Remove item from array       | `$1`: array reference, `$2`: value | None                 |
| `util_array_join(separator, array)`     | Join array with separator    | `$1`: separator, `$@`: array items | Joined string        |

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

| Function                                                                    | Purpose                               | Parameters                 | Returns              |
| --------------------------------------------------------------------------- | ------------------------------------- | -------------------------- | -------------------- |
| `template_system_init()`                                                    | Initialize template system            | None                       | 0=success, 1=failure |
| `template_create_defaults()`                                                | Create default notification templates | None                       | 0=success, 1=failure |
| `template_process(file, code, message, plugin, metrics)`                    | Process notification template         | Template parameters        | Processed content    |
| `template_get(type, provider)`                                              | Get template for notification         | `$1`: type, `$2`: provider | Template file path   |
| `template_generate_content(type, provider, code, message, plugin, metrics)` | Generate notification content         | Notification parameters    | Generated content    |
| `template_list()`                                                           | List available templates              | None                       | Template list output |
| `template_validate(file)`                                                   | Validate template syntax              | `$1`: template file        | 0=valid, 1=invalid   |

---

## 🔍 Advanced Features Functions

### Anomaly Detection (`lib/core/anomaly.sh`)

| Function                                                    | Purpose                               | Parameters                              | Returns              |
| ----------------------------------------------------------- | ------------------------------------- | --------------------------------------- | -------------------- |
| `anomaly_system_init()`                                     | Initialize anomaly detection          | None                                    | 0=success, 1=failure |
| `anomaly_store_metric(plugin, metric, value)`               | Store metric data for analysis        | `$1`: plugin, `$2`: metric, `$3`: value | 0=success, 1=failure |
| `anomaly_detect_statistical(plugin, metric, value, config)` | Detect statistical anomalies          | Anomaly parameters                      | 0=normal, 1=anomaly  |
| `anomaly_calculate_statistics(file, window)`                | Calculate statistical metrics         | `$1`: data file, `$2`: window size      | Statistics CSV       |
| `anomaly_run_detection()`                                   | Run anomaly detection for all metrics | None                                    | 0=success, 1=failure |
| `anomaly_parse_config(file)`                                | Parse anomaly configuration           | `$1`: config file                       | 0=success, 1=failure |
| `anomaly_get_summary(days)`                                 | Get anomaly detection summary         | `$1`: days to analyze                   | Summary output       |

### Composite Checks (`lib/core/composite.sh`)

| Function                                 | Purpose                             | Parameters                       | Returns               |
| ---------------------------------------- | ----------------------------------- | -------------------------------- | --------------------- |
| `composite_system_init()`                | Initialize composite check system   | None                             | 0=success, 1=failure  |
| `composite_parse_config(file)`           | Parse composite check configuration | `$1`: config file                | 0=success, 1=failure  |
| `composite_evaluate_rule(rule, results)` | Evaluate composite rule logic       | `$1`: rule, `$2`: plugin results | 0=pass, 1=fail        |
| `composite_run_check(config, results)`   | Run single composite check          | `$1`: config file, `$2`: results | Check result JSON     |
| `composite_run_all_checks(results)`      | Run all composite checks            | `$1`: plugin results             | Combined results JSON |
| `composite_list_checks()`                | List all composite checks           | None                             | Composite checks list |

### Diagnostics System (`lib/core/diagnostics.sh`)

| Function                               | Purpose                              | Parameters            | Returns                 |
| -------------------------------------- | ------------------------------------ | --------------------- | ----------------------- |
| `diagnostics_system_init()`            | Initialize diagnostics system        | None                  | 0=success, 1=failure    |
| `diagnostics_run_full()`               | Run comprehensive system diagnostics | None                  | Diagnostics report JSON |
| `diagnostics_check_resources()`        | Check system resource usage          | None                  | Resource check JSON     |
| `diagnostics_check_disk_space()`       | Check disk space availability        | None                  | Disk space JSON         |
| `diagnostics_check_memory_usage()`     | Check memory usage                   | None                  | Memory usage JSON       |
| `diagnostics_check_cpu_load()`         | Check CPU load                       | None                  | CPU load JSON           |
| `diagnostics_check_network()`          | Check network connectivity           | None                  | Network check JSON      |
| `diagnostics_check_serversentry()`     | Check ServerSentry health            | None                  | Health check JSON       |
| `diagnostics_generate_report(results)` | Generate diagnostics report          | `$1`: results JSON    | 0=success, 1=failure    |
| `diagnostics_get_summary(days)`        | Get diagnostic summary               | `$1`: days to analyze | Summary output          |
| `diagnostics_cleanup_reports(days)`    | Cleanup old diagnostic reports       | `$1`: days to keep    | 0=success               |

---

## 🎨 User Interface Functions

### Command Line Interface (`lib/ui/cli/`)

| Function                 | Purpose                        | Parameters              | Returns              |
| ------------------------ | ------------------------------ | ----------------------- | -------------------- |
| `cli_process_commands()` | Process command line arguments | `$@`: command arguments | 0=success, 1=failure |
| `cli_show_help()`        | Display help information       | None                    | Help output          |
| `cli_show_version()`     | Display version information    | None                    | Version output       |
| `cli_show_status()`      | Display system status          | None                    | Status output        |

---

## 📊 Function Usage Patterns

### Error Handling Pattern

```bash
# Standard error handling with logging
function_name() {
    local param="$1"

    # Validate input
    if ! util_require_param "$param" "param"; then
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
    if ! metric_value=$(get_metric_value); then
        result='{"status_code": 2, "status_message": "Failed to get metric", "metrics": {}}'
        echo "$result"
        return 1
    fi

    # Update result with metrics
    result=$(util_json_set_value "$result" "metrics.metric_name" "$metric_value")

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
    if ! response=$(curl -s -X POST "$webhook_url" -d "$message"); then
        log_error "Failed to send notification"
        return 1
    fi

    log_debug "Notification sent successfully"
    return 0
}
```

---

## 🔄 Function Dependencies

### Core Dependencies

```
main()
├── config_load()
├── logging_init()
├── plugin_system_init()
│   ├── plugin_load()
│   ├── plugin_validate()
│   └── plugin_register()
├── notification_system_init()
│   ├── notification_load_provider()
│   ├── notification_validate_provider()
│   └── notification_register_provider()
└── cli_process_commands()
```

### Plugin System Dependencies

```
plugin_run_check()
├── plugin_is_registered()
├── ${PLUGIN}_plugin_check()
└── notification_send()
    ├── template_generate_content()
    │   ├── template_get()
    │   └── template_process()
    └── ${PROVIDER}_provider_send()
```

---

**Last Updated**: December 2024
**Total Functions Documented**: 100+
**Coverage**: All core modules, plugin interfaces, notification system
