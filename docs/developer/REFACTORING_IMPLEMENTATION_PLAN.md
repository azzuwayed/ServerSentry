# ServerSentry v2 - Refactoring Implementation Plan

## 📋 Overview

This document outlines the systematic implementation plan for refactoring ServerSentry v2. The refactoring will be done in phases to ensure stability and maintain functionality throughout the process.

## 🎯 Goals

1. **Eliminate Code Redundancy**: Remove duplicate functions and logic
2. **Standardize Interfaces**: Consistent function naming and error handling
3. **Improve Performance**: Optimize configuration loading and plugin management
4. **Enhance Security**: Standardize input validation and sanitization
5. **Improve Maintainability**: Clear module boundaries and comprehensive documentation

## 📊 Current Status

### ✅ Phase 1: Utility Infrastructure (COMPLETED)

- [x] Created centralized utility modules
- [x] Implemented validation utilities (`validation_utils.sh`)
- [x] Implemented JSON utilities (`json_utils.sh`)
- [x] Implemented array utilities (`array_utils.sh`)
- [x] Implemented configuration utilities (`config_utils.sh`)
- [x] Refactored main utils.sh as loader with backward compatibility

### ✅ Phase 2: Core Module Refactoring (COMPLETED)

- [x] **Configuration Module Standardization**

  - [x] Updated `lib/core/config.sh` with standardized functions
  - [x] Implemented `config_init()`, `config_load()`, `config_get_value()`, `config_set_value()`
  - [x] Added configuration validation with `CONFIG_VALIDATION_RULES`
  - [x] Integrated with unified configuration utilities
  - [x] Added caching support and environment variable overrides

- [x] **Function Naming Standardization**

  - [x] Updated all core modules to use `module_action()` pattern
  - [x] `config_init()`, `config_load()` instead of `init_config()`, `load_config()`
  - [x] `logging_init()`, `logging_set_level()`, `logging_rotate()` instead of old patterns
  - [x] Updated main entry point `bin/serversentry` to use new function names
  - [x] Maintained backward compatibility where needed

- [x] **Core System Integration**

  - [x] Updated `bin/serversentry` entry point with proper initialization order
  - [x] Enhanced error handling with standardized patterns
  - [x] Proper logging initialization and configuration loading
  - [x] Plugin and notification system initialization

- [x] **Error Handling Standardization**
  - [x] Implemented consistent error handling patterns across modules
  - [x] Enhanced logging with context information
  - [x] Proper exit codes and cleanup mechanisms

### 🔄 Phase 3: Performance Optimization (IN PROGRESS)

#### Priority Tasks

1. **Configuration Caching Implementation** (Partially Complete)

   - [x] Basic caching infrastructure in config_utils.sh
   - [ ] Advanced metrics and cache statistics
   - [ ] Performance benchmarking

2. **Plugin System Optimization** (Needs Update)

   - [ ] Plugin loading registry implementation
   - [ ] Function availability caching
   - [ ] Plugin interface validation enhancement

3. **External Command Optimization** (Not Started)
   - [ ] Command caching implementation
   - [ ] Batch operations
   - [ ] Built-in alternatives for common commands

## 🔧 Phase 2: Core Module Refactoring

### Task 2.1: Refactor Configuration Module

**Objective**: Replace existing configuration logic with unified utilities

**Files to Modify**:

- `lib/core/config.sh`
- `lib/core/anomaly.sh` (config parsing)
- `lib/core/composite.sh` (config parsing)
- All plugin configuration files

**Implementation Steps**:

1. **Backup Original Files**

```bash
cp lib/core/config.sh lib/core/config.sh.backup
cp lib/core/anomaly.sh lib/core/anomaly.sh.backup
cp lib/core/composite.sh lib/core/composite.sh.backup
```

2. **Update main config.sh**

   - Replace `parse_config()` with `util_config_parse_yaml()`
   - Replace `get_config()` with `util_config_get_value()`
   - Implement configuration caching
   - Add standardized validation rules

3. **Update anomaly.sh**

   - Replace `parse_anomaly_config()` with `util_config_get_cached()`
   - Standardize configuration namespace
   - Add validation rules for anomaly settings

4. **Update composite.sh**
   - Replace configuration parsing with unified utilities
   - Implement configuration caching
   - Add validation for composite rules

**Validation Rules Example**:

```bash
# Configuration validation rules
declare -a config_validation_rules=(
    "enabled:boolean:"
    "log_level:log_level:"
    "check_interval:positive_numeric:"
    "plugins_enabled:required:"
    "notification_enabled:boolean:"
    "max_log_size:positive_numeric:"
    "webhook_url:url:"
    "email_to:email:"
)
```

**Testing Plan**:

- [ ] Unit tests for configuration loading
- [ ] Regression tests for existing functionality
- [ ] Performance comparison before/after
- [ ] Configuration validation edge cases

### Task 2.2: Standardize Function Naming

**Objective**: Implement consistent `module_action()` naming pattern

**Function Mapping**:

| Current Function             | New Function                 | Module          |
| ---------------------------- | ---------------------------- | --------------- |
| `init_config()`              | `config_init()`              | config.sh       |
| `load_config()`              | `config_load()`              | config.sh       |
| `init_logging()`             | `logging_init()`             | logging.sh      |
| `rotate_logs()`              | `logging_rotate()`           | logging.sh      |
| `init_plugin_system()`       | `plugin_system_init()`       | plugin.sh       |
| `load_plugin()`              | `plugin_load()`              | plugin.sh       |
| `run_plugin_check()`         | `plugin_run_check()`         | plugin.sh       |
| `init_notification_system()` | `notification_system_init()` | notification.sh |

**Implementation Strategy**:

1. Create alias functions for backward compatibility
2. Update internal calls to use new names
3. Add deprecation warnings for old functions
4. Update documentation and examples

**Example Refactoring**:

```bash
# In config.sh
config_init() {
    log_debug "Initializing configuration system"
    # ... implementation
}

# Backward compatibility (with deprecation warning)
init_config() {
    log_warning "Function init_config() is deprecated, use config_init() instead"
    config_init "$@"
}
```

### Task 2.3: Plugin System Optimization

**Objective**: Implement plugin loading optimization and caching

**Current Issues**:

- Plugins sourced multiple times
- No function availability caching
- Inefficient plugin validation

**Optimization Implementation**:

1. **Plugin Loading Registry**

```bash
# Global plugin state tracking
declare -A PLUGIN_LOADED
declare -A PLUGIN_FUNCTIONS
declare -A PLUGIN_METADATA

plugin_load_once() {
    local plugin_name="$1"

    # Check if already loaded
    if [[ "${PLUGIN_LOADED[$plugin_name]}" == "true" ]]; then
        log_debug "Plugin already loaded: $plugin_name"
        return 0
    fi

    # Load plugin
    local plugin_file="${PLUGIN_DIR}/${plugin_name}/${plugin_name}.sh"
    if ! util_validate_file_exists "$plugin_file" "Plugin file"; then
        return 1
    fi

    source "$plugin_file" || return 1
    PLUGIN_LOADED[$plugin_name]="true"

    # Cache function availability
    _plugin_cache_functions "$plugin_name"

    log_info "Plugin loaded and cached: $plugin_name"
    return 0
}

_plugin_cache_functions() {
    local plugin_name="$1"
    local required_functions=("info" "check" "configure")

    for func in "${required_functions[@]}"; do
        local func_name="${plugin_name}_plugin_${func}"
        if declare -f "$func_name" >/dev/null; then
            PLUGIN_FUNCTIONS["${func_name}"]="available"
        else
            PLUGIN_FUNCTIONS["${func_name}"]="missing"
        fi
    done
}
```

2. **Plugin Interface Validation**

```bash
plugin_validate_interface() {
    local plugin_name="$1"
    local validation_failed=false

    local required_functions=("info" "check" "configure")
    for func in "${required_functions[@]}"; do
        local func_name="${plugin_name}_plugin_${func}"
        if [[ "${PLUGIN_FUNCTIONS[$func_name]}" != "available" ]]; then
            log_error "Plugin missing required function: $func_name"
            validation_failed=true
        fi
    done

    if [[ "$validation_failed" == "true" ]]; then
        return 1
    fi

    return 0
}
```

### Task 2.4: Error Handling Standardization

**Objective**: Implement consistent error handling patterns

**Standard Error Handling Pattern**:

```bash
module_function() {
    local param1="$1"
    local param2="$2"

    # Input validation
    if ! util_require_param "$param1" "param1"; then
        return 1
    fi

    if ! util_validate_numeric "$param2" "param2"; then
        return 1
    fi

    # Main operation with error handling
    local result
    if ! result=$(some_operation "$param1" "$param2" 2>&1); then
        log_error_context "Operation failed" "param1=$param1, param2=$param2"
        return 1
    fi

    log_debug "Operation completed successfully"
    echo "$result"
    return 0
}
```

**Error Context Enhancement**:

```bash
# Enhanced error logging with automatic context
log_operation_error() {
    local operation="$1"
    local error_message="$2"
    local context="$3"

    local caller_function="${FUNCNAME[2]}"
    local caller_line="${BASH_LINENO[1]}"
    local caller_file="${BASH_SOURCE[2]##*/}"

    log_error "Operation '$operation' failed: $error_message"
    log_error "Context: $context"
    log_error "Location: $caller_file:$caller_function:$caller_line"
}
```

---

## 🔄 Phase 3: Performance Optimization

### Task 3.1: Configuration Caching Implementation

**Objective**: Implement comprehensive configuration caching

**Cache Strategy**:

- File modification time tracking
- Configurable cache duration
- Namespace-based cache keys
- Memory-efficient storage

**Implementation**:

```bash
# Enhanced caching with metrics
declare -A CONFIG_CACHE_HITS
declare -A CONFIG_CACHE_MISSES

config_get_with_metrics() {
    local config_file="$1"
    local namespace="$2"
    local cache_key="${config_file##*/}_${namespace}"

    if util_config_get_cached "$config_file" "$namespace"; then
        ((CONFIG_CACHE_HITS["$cache_key"]++))
        log_debug "Config cache hit: $cache_key"
    else
        ((CONFIG_CACHE_MISSES["$cache_key"]++))
        log_debug "Config cache miss: $cache_key"
    fi
}

config_show_cache_stats() {
    echo "Configuration Cache Statistics:"
    echo "==============================="

    for key in "${!CONFIG_CACHE_HITS[@]}"; do
        local hits="${CONFIG_CACHE_HITS[$key]:-0}"
        local misses="${CONFIG_CACHE_MISSES[$key]:-0}"
        local total=$((hits + misses))
        local hit_rate=0

        if [[ "$total" -gt 0 ]]; then
            hit_rate=$(echo "scale=2; $hits * 100 / $total" | bc)
        fi

        echo "$key: ${hit_rate}% hit rate ($hits hits, $misses misses)"
    done
}
```

### Task 3.2: External Command Optimization

**Objective**: Reduce external command calls by 50%

**Optimization Strategies**:

1. **Command Caching**

```bash
declare -A COMMAND_CACHE
declare -A COMMAND_CACHE_TIME

cached_command() {
    local command="$1"
    local cache_duration="${2:-60}"
    local cache_key="cmd_$(echo "$command" | md5sum | cut -d' ' -f1)"

    local current_time
    current_time=$(date +%s)
    local cache_time="${COMMAND_CACHE_TIME[$cache_key]:-0}"

    if [[ $((current_time - cache_time)) -lt "$cache_duration" ]]; then
        echo "${COMMAND_CACHE[$cache_key]}"
        return 0
    fi

    local result
    result=$(eval "$command") || return 1

    COMMAND_CACHE[$cache_key]="$result"
    COMMAND_CACHE_TIME[$cache_key]="$current_time"

    echo "$result"
}
```

2. **Batch Operations**

```bash
# Instead of multiple individual calls
for file in "${files[@]}"; do
    stat_result=$(stat "$file")
done

# Use batch operation
stat_results=$(stat "${files[@]}" 2>/dev/null)
```

3. **Built-in Alternatives**

```bash
# Replace external date calls with cached timestamp
get_cached_timestamp() {
    local cache_duration="${1:-1}"
    local current_time
    current_time=$(date +%s)

    if [[ -z "$CACHED_TIMESTAMP" ]] || [[ $((current_time - CACHED_TIMESTAMP_TIME)) -ge "$cache_duration" ]]; then
        CACHED_TIMESTAMP="$current_time"
        CACHED_TIMESTAMP_TIME="$current_time"
    fi

    echo "$CACHED_TIMESTAMP"
}
```

---

## 🔒 Phase 4: Security Enhancements

### Task 4.1: Input Sanitization Standardization

**Objective**: Implement consistent input sanitization across all modules

**Sanitization Strategy**:

```bash
# Comprehensive input sanitization
sanitize_and_validate_input() {
    local input="$1"
    local validation_type="$2"
    local max_length="${3:-1024}"

    # Basic sanitization
    local sanitized
    sanitized=$(util_sanitize_input "$input")

    # Length validation
    if ! util_validate_string_length "$sanitized" 0 "$max_length" "input"; then
        return 1
    fi

    # Type-specific validation
    case "$validation_type" in
        path)
            if ! util_validate_path_safe "$sanitized" "path"; then
                return 1
            fi
            ;;
        config_value)
            # Additional config-specific sanitization
            sanitized=$(echo "$sanitized" | sed 's/[;&|`$()]//g')
            ;;
        plugin_name)
            if ! [[ "$sanitized" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log_error "Invalid plugin name format: $sanitized"
                return 1
            fi
            ;;
    esac

    echo "$sanitized"
    return 0
}
```

### Task 4.2: File Permission Standardization

**Objective**: Ensure consistent and secure file permissions

**Permission Standards**:

- Configuration files: `644`
- Executable scripts: `755`
- Log files: `644`
- Sensitive configs: `600`
- Directories: `755`

**Implementation**:

```bash
# Secure file creation with proper permissions
create_secure_config_file() {
    local file="$1"
    local content="$2"
    local is_sensitive="${3:-false}"

    # Create with restrictive permissions first
    touch "$file" || return 1

    if [[ "$is_sensitive" == "true" ]]; then
        chmod 600 "$file"
    else
        chmod 644 "$file"
    fi

    # Verify ownership
    if ! [[ -O "$file" ]]; then
        log_error "File ownership verification failed: $file"
        return 1
    fi

    # Write content securely
    echo "$content" > "$file" || return 1

    log_debug "Secure file created: $file"
    return 0
}
```

---

## 🧪 Testing Strategy

### Test Categories

1. **Unit Tests**

   - Individual function testing
   - Input validation testing
   - Error handling validation

2. **Integration Tests**

   - Module interaction testing
   - Configuration loading testing
   - Plugin system testing

3. **Performance Tests**

   - Before/after performance comparison
   - Memory usage monitoring
   - Cache effectiveness testing

4. **Security Tests**
   - Input sanitization testing
   - File permission verification
   - Path traversal prevention

### Test Implementation Plan

```bash
# Create test framework
mkdir -p tests/unit/utils
mkdir -p tests/integration/core
mkdir -p tests/performance
mkdir -p tests/security

# Test utilities
tests/test_framework.sh
tests/unit/test_validation_utils.sh
tests/unit/test_json_utils.sh
tests/unit/test_array_utils.sh
tests/unit/test_config_utils.sh

# Integration tests
tests/integration/test_config_loading.sh
tests/integration/test_plugin_system.sh
tests/integration/test_notification_system.sh

# Performance tests
tests/performance/test_config_caching.sh
tests/performance/test_plugin_loading.sh

# Security tests
tests/security/test_input_sanitization.sh
tests/security/test_file_permissions.sh
```

---

## 📈 Success Metrics

### Code Quality Metrics

- [ ] 40% reduction in duplicate code lines
- [ ] 100% function naming consistency
- [ ] 90% test coverage for core modules
- [ ] Zero critical security issues

### Performance Metrics

- [ ] 25% faster startup time
- [ ] 30% reduction in memory usage
- [ ] 50% fewer external command calls
- [ ] 80%+ configuration cache hit rate

### Maintainability Metrics

- [ ] Complete function registry documentation
- [ ] Standardized error handling in all modules
- [ ] Clear module boundaries
- [ ] Comprehensive developer documentation

---

## 🚀 Deployment Strategy

### Rolling Deployment Plan

1. **Phase 1**: Deploy utility modules (low risk)
2. **Phase 2**: Deploy core module refactoring (medium risk)
3. **Phase 3**: Deploy performance optimizations (low risk)
4. **Phase 4**: Deploy security enhancements (low risk)

### Rollback Plan

1. **Backup Strategy**

   - Git tags for each phase
   - Configuration backups
   - Database/state backups

2. **Rollback Triggers**

   - Performance regression > 10%
   - Functionality breaking changes
   - Security vulnerabilities introduced

3. **Rollback Process**
   - Automated rollback scripts
   - Configuration restoration
   - Service restart procedures

---

## 📅 Timeline

### Phase 2: Core Module Refactoring (Week 2)

- **Day 1-2**: Configuration module refactoring
- **Day 3-4**: Function naming standardization
- **Day 5-6**: Plugin system optimization
- **Day 7**: Error handling standardization

### Phase 3: Performance Optimization (Week 3)

- **Day 1-3**: Configuration caching implementation
- **Day 4-5**: External command optimization
- **Day 6-7**: Performance testing and tuning

### Phase 4: Security Enhancements (Week 4)

- **Day 1-3**: Input sanitization standardization
- **Day 4-5**: File permission standardization
- **Day 6-7**: Security testing and validation

---

**Document Version**: 1.0
**Last Updated**: $(date)
**Status**: Phase 1 Complete, Phase 2 In Progress
