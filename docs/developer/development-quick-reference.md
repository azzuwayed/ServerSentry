# ServerSentry Development Quick Reference

**Quick Start Guide for New Module Development**

## 🚀 Module Creation Checklist

### 1. File Setup

```bash
# Create new module file
touch lib/core/[module_name].sh
chmod +x lib/core/[module_name].sh
```

### 2. Copy Header Template

```bash
#!/usr/bin/env bash
#
# ServerSentry v2 - [Module Name]
#
# [Brief description]

# Prevent multiple sourcing
if [[ "${[MODULE_NAME]_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
[MODULE_NAME]_MODULE_LOADED=true
export [MODULE_NAME]_MODULE_LOADED

# Set BASE_DIR fallback
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
```

### 3. Function Template

```bash
# Function: [module]_[action]_[object]
# Description: What this function does
# Parameters:
#   $1 (string): parameter description
#   $2 (numeric): parameter description (optional, default: value)
# Returns:
#   0 - success
#   1 - failure
# Example:
#   result=$([module]_[action]_[object] "param1" "param2")
# Dependencies:
#   - util_error_validate_input
[module]_[action]_[object]() {
  if ! util_error_validate_input "[function_name]" "2" "$#"; then
    return 1
  fi

  local param1="$1"
  local param2="${2:-default_value}"

  # Validation
  if [[ ! "$param1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid parameter: $param1" "[module]"
    return 1
  fi

  # Logic here
  local result
  if ! result=$(some_operation "$param1"); then
    log_error "Operation failed: $param1" "[module]"
    return 1
  fi

  echo "$result"
  log_debug "Success: $param1" "[module]"
  return 0
}
```

### 4. Module Footer

```bash
# Export functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f [module]_init
  export -f [module]_[function]
fi

# Initialize module
if ! [module]_init; then
  log_error "Failed to initialize [module] module" "[module]"
fi
```

## 📋 Essential Patterns

### Input Validation

```bash
# Always start functions with this
if ! util_error_validate_input "function_name" "2" "$#"; then
  return 1
fi
```

### Parameter Validation

```bash
# String validation
if [[ ! "$param" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  log_error "Invalid parameter: $param" "module"
  return 1
fi

# File validation
if [[ ! -f "$file_path" ]]; then
  log_error "File not found: $file_path" "module"
  return 1
fi

# Numeric validation
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
  log_error "Invalid number: $number" "module"
  return 1
fi
```

### Safe Command Execution

```bash
local result
if ! result=$(util_error_safe_execute "command here" 10); then
  log_error "Command failed" "module"
  return 1
fi
```

### Error Handling

```bash
# Check operation success
if ! operation_function "$param"; then
  log_error "Operation failed for: $param" "module"
  return 1
fi

# Validate results
if [[ -z "$result" ]]; then
  log_warning "Empty result from operation" "module"
  return 1
fi
```

## 🔧 Common Function Types

### Initialization Function

```bash
[module]_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid parameters for [module]_init: expected 0, got $#" "[module]"
    return 1
  fi

  # Create directories
  local dirs=("$CONFIG_DIR" "$DATA_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create directory: $dir" "[module]"
        return 1
      fi
    fi
  done

  log_debug "[Module] initialized successfully" "[module]"
  return 0
}
```

### Configuration Function

```bash
[module]_get_config() {
  if ! util_error_validate_input "[module]_get_config" "2" "$#"; then
    return 1
  fi

  local key="$1"
  local default_value="$2"
  local config_file="$CONFIG_DIR/[module].conf"

  if [[ ! -f "$config_file" ]]; then
    echo "$default_value"
    return 0
  fi

  local value
  value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  echo "${value:-$default_value}"
}
```

### Data Processing Function

```bash
[module]_process_data() {
  if ! util_error_validate_input "[module]_process_data" "1" "$#"; then
    return 1
  fi

  local input_data="$1"
  local processing_type="${2:-standard}"

  if [[ -z "$input_data" ]]; then
    log_error "Empty input data" "[module]"
    return 1
  fi

  local result
  case "$processing_type" in
    "standard")
      result=$(echo "$input_data" | process_standard)
      ;;
    "advanced")
      result=$(echo "$input_data" | process_advanced)
      ;;
    *)
      log_error "Invalid processing type: $processing_type" "[module]"
      return 1
      ;;
  esac

  echo "$result"
  return 0
}
```

## 📊 Testing Template

```bash
#!/usr/bin/env bash
# Test script for [module]

source "lib/core/[module].sh"

test_[function_name]() {
  echo "Testing [function_name]..."

  # Success case
  local result
  if result=$([function_name] "valid_input"); then
    echo "✅ Success case passed"
  else
    echo "❌ Success case failed"
    return 1
  fi

  # Error case
  if [function_name] ""; then
    echo "❌ Error case failed"
    return 1
  else
    echo "✅ Error case passed"
  fi

  return 0
}

# Run all tests
test_[function_name] || exit 1
echo "All tests passed!"
```

## 🎯 Quality Checklist

Before submitting code:

- [ ] **Header**: Complete file header with module guards
- [ ] **Functions**: All functions follow naming convention
- [ ] **Documentation**: Every function has complete documentation
- [ ] **Validation**: Input validation on all functions
- [ ] **Error Handling**: Comprehensive error handling
- [ ] **Local Variables**: All variables declared as local
- [ ] **Logging**: Appropriate debug/error logging
- [ ] **Export**: Functions exported at end of file
- [ ] **Testing**: All functions tested
- [ ] **Integration**: Module integrates with existing system

## 🔍 Common Validation Patterns

```bash
# Plugin name validation
if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  log_error "Invalid plugin name: $plugin_name" "module"
  return 1
fi

# File path validation
if [[ ! -f "$file_path" ]]; then
  log_error "File not found: $file_path" "module"
  return 1
fi

# Directory validation
if [[ ! -d "$directory" ]]; then
  log_error "Directory not found: $directory" "module"
  return 1
fi

# Numeric validation
if [[ ! "$number" =~ ^[0-9]+$ ]] || [[ "$number" -le 0 ]]; then
  log_error "Invalid number: $number" "module"
  return 1
fi

# Boolean validation
if [[ ! "$boolean" =~ ^(true|false)$ ]]; then
  log_error "Invalid boolean: $boolean" "module"
  return 1
fi

# Email validation (basic)
if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  log_error "Invalid email: $email" "module"
  return 1
fi

# URL validation (basic)
if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+.*$ ]]; then
  log_error "Invalid URL: $url" "module"
  return 1
fi
```

## 📝 Documentation Examples

### Simple Function

```bash
# Function: util_format_timestamp
# Description: Format Unix timestamp to human-readable date
# Parameters:
#   $1 (numeric): Unix timestamp
# Returns:
#   Formatted date string via stdout
# Example:
#   date_str=$(util_format_timestamp 1640995200)
```

### Complex Function

```bash
# Function: anomaly_detect_statistical_outliers
# Description: Detect statistical anomalies using Z-score analysis and configurable sensitivity
# Parameters:
#   $1 (string): plugin name (alphanumeric, underscore, hyphen only)
#   $2 (string): metric name (alphanumeric, underscore, hyphen only)
#   $3 (numeric): current value (positive or negative decimal)
#   $4 (string): data file path (must exist and be readable)
#   $5 (numeric): sensitivity threshold (optional, default: 2.0, range: 0.1-10.0)
#   $6 (numeric): minimum data points (optional, default: 10, minimum: 3)
# Returns:
#   0 - anomaly detected (outputs JSON result)
#   1 - no anomaly or insufficient data
# Example:
#   result=$(anomaly_detect_statistical_outliers "cpu" "usage" 95.5 "/path/to/data.dat" 2.0 10)
# Dependencies:
#   - anomaly_calculate_statistics
#   - util_error_validate_input
```

## 🚨 Common Mistakes to Avoid

1. **Missing Input Validation**: Always validate inputs first
2. **Global Variables**: Use local variables only
3. **No Error Handling**: Handle all error conditions
4. **Missing Documentation**: Document every function
5. **Inconsistent Naming**: Follow naming conventions
6. **No Logging**: Include appropriate logging
7. **Missing Exports**: Export functions at end of file
8. **No Testing**: Test all functions thoroughly

## 🔧 Useful Utilities Available

```bash
# Error handling
util_error_validate_input "function_name" "expected_count" "$#"
util_error_safe_execute "command" timeout_seconds
util_error_handle_network_failure "operation" max_retries

# Documentation
util_doc_generate_function_header "function_name"
util_doc_validate_function_documentation "file_path"

# Logging (available everywhere)
log_debug "message" "module"
log_info "message" "module"
log_warning "message" "module"
log_error "message" "module"
```

## 📞 Getting Help

- **Full Documentation**: See `DEVELOPMENT_STANDARDS.md`
- **Examples**: Check `lib/core/anomaly/` for complete examples
- **Templates**: Use the templates in this guide
- **Analysis Tools**: Run `./tools/function-analysis/categorize_functions.sh`

---

**Remember**: Follow the patterns, validate everything, handle errors gracefully, and document thoroughly!
