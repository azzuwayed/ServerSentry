# ServerSentry Development Standards

**Version:** 2.0  
**Last Updated:** May 2025  
**Project:** ServerSentry Monitoring Platform

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [File Structure Standards](#file-structure-standards)
3. [Code Organization](#code-organization)
4. [Function Development](#function-development)
5. [Documentation Standards](#documentation-standards)
6. [Error Handling](#error-handling)
7. [Testing Requirements](#testing-requirements)
8. [Integration Guidelines](#integration-guidelines)
9. [Performance Standards](#performance-standards)
10. [Security Requirements](#security-requirements)
11. [Examples and Templates](#examples-and-templates)

## 🎯 Project Overview

ServerSentry is a professional-grade, modular monitoring platform built with shell scripts. The project follows enterprise-level development standards with emphasis on:

- **Modular Architecture** - Clear separation of concerns
- **Professional Quality** - Enterprise-grade code standards
- **Backward Compatibility** - Zero breaking changes policy
- **Comprehensive Documentation** - 100% function documentation
- **Robust Error Handling** - Multi-level error management
- **Cross-Platform Support** - Linux and macOS compatibility

## 📁 File Structure Standards

### Directory Organization

```
lib/
├── core/                    # Core system modules
│   ├── utils/              # Utility functions
│   │   ├── error_utils.sh  # Error handling utilities
│   │   └── documentation_utils.sh # Documentation utilities
│   ├── diagnostics/        # Diagnostic modules
│   │   ├── system_health.sh
│   │   └── configuration.sh
│   ├── anomaly/            # Anomaly detection modules
│   │   ├── config.sh
│   │   ├── data.sh
│   │   ├── detection.sh
│   │   └── processing.sh
│   └── [system].sh         # Main orchestration files
├── plugins/                # Plugin system
│   ├── core/              # Core plugin utilities
│   └── available/         # Individual plugins
├── ui/                    # User interface components
└── notifications/         # Notification system
```

### File Naming Conventions

- **Module Files**: `[system]_[component].sh` (e.g., `anomaly_detection.sh`)
- **Utility Files**: `[purpose]_utils.sh` (e.g., `error_utils.sh`)
- **Main Files**: `[system].sh` (e.g., `anomaly.sh`)
- **Configuration**: `[system]_[type].conf` (e.g., `cpu_anomaly.conf`)

### File Size Guidelines

- **Main orchestration files**: < 500 lines
- **Specialized modules**: 500-800 lines maximum
- **Utility modules**: 300-600 lines
- **Individual functions**: < 100 lines (prefer 20-50 lines)

## 🏗️ Code Organization

### File Header Template

```bash
#!/usr/bin/env bash
#
# ServerSentry v2 - [Module Name]
#
# [Brief description of module purpose and functionality]
# [Additional context if needed]

# Prevent multiple sourcing
if [[ "${[MODULE_NAME]_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
[MODULE_NAME]_MODULE_LOADED=true
export [MODULE_NAME]_MODULE_LOADED

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
```

### Module Structure

1. **Header and Guards** (lines 1-25)
2. **Constants and Configuration** (lines 26-50)
3. **Initialization Functions** (lines 51-100)
4. **Core Functions** (grouped by functionality)
5. **Utility Functions** (helper functions)
6. **Export Statements** (end of file)
7. **Module Initialization** (final section)

### Variable Naming

- **Global Constants**: `UPPER_CASE_WITH_UNDERSCORES`
- **Module Variables**: `MODULE_VARIABLE_NAME`
- **Local Variables**: `lower_case_with_underscores`
- **Function Parameters**: `descriptive_parameter_name`

## 🔧 Function Development

### Function Naming Convention

```bash
[module]_[action]_[object]
```

Examples:

- `anomaly_detect_statistical_outliers`
- `plugin_load_configuration`
- `util_error_validate_input`

### Function Template

```bash
# Function: function_name
# Description: Clear, concise description of what the function does
# Parameters:
#   $1 (type): parameter description
#   $2 (type): parameter description (optional, default: value)
# Returns:
#   0 - success description
#   1 - failure description
# Example:
#   result=$(function_name "param1" "param2")
# Dependencies:
#   - dependency_function_1
#   - dependency_function_2
function_name() {
  # Input validation
  if ! util_error_validate_input "function_name" "2" "$#"; then
    return 1
  fi

  local param1="$1"
  local param2="${2:-default_value}"

  # Parameter validation
  if [[ ! "$param1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid parameter: $param1" "module_name"
    return 1
  fi

  # Function logic here
  local result
  if ! result=$(some_operation "$param1" "$param2"); then
    log_error "Operation failed for $param1" "module_name"
    return 1
  fi

  # Success logging and output
  log_debug "Operation completed successfully for $param1" "module_name"
  echo "$result"
  return 0
}
```

### Function Requirements

1. **Input Validation**: Always validate parameters using `util_error_validate_input`
2. **Error Handling**: Use proper error handling with logging
3. **Local Variables**: Declare all variables as local
4. **Return Codes**: Use consistent return codes (0=success, 1=failure)
5. **Logging**: Include appropriate debug/error logging
6. **Documentation**: Complete function documentation header

## 📚 Documentation Standards

### Function Documentation

Every function must include:

```bash
# Function: function_name
# Description: What the function does (1-2 sentences)
# Parameters:
#   $1 (string): description [required/optional, default: value]
#   $2 (numeric): description [validation rules]
# Returns:
#   0 - success (what success means)
#   1 - failure (what failure means)
# Example:
#   result=$(function_name "example" 42)
#   if function_name "test"; then echo "success"; fi
# Dependencies:
#   - required_function_1
#   - required_module.sh
```

### Code Comments

```bash
# High-level operation description
local variable="value"  # Inline comment for complex logic

# Multi-line comment for complex sections
# explaining the approach and reasoning
if complex_condition; then
  # Explain why this approach was chosen
  perform_operation
fi
```

### Module Documentation

Each module should include:

1. **Purpose Statement** - What the module does
2. **Key Functions** - Main functions provided
3. **Dependencies** - Required modules/utilities
4. **Configuration** - Required configuration variables
5. **Usage Examples** - How to use the module

## ⚠️ Error Handling

### Error Handling Standards

1. **Use Error Utilities**: Always use `util_error_validate_input` and related functions
2. **Consistent Return Codes**: 0 for success, 1 for failure
3. **Proper Logging**: Use appropriate log levels (error, warning, debug)
4. **Graceful Degradation**: Provide fallbacks when possible
5. **Error Context**: Include relevant context in error messages

### Error Handling Template

```bash
function_name() {
  # Input validation
  if ! util_error_validate_input "function_name" "2" "$#"; then
    return 1
  fi

  local param1="$1"
  local param2="$2"

  # Parameter validation
  if [[ ! -f "$param1" ]]; then
    log_error "File not found: $param1" "module_name"
    return 1
  fi

  # Safe execution with error handling
  local result
  if ! result=$(util_error_safe_execute "command '$param1'" 10); then
    log_error "Command execution failed for: $param1" "module_name"
    return 1
  fi

  # Validation of results
  if [[ -z "$result" ]]; then
    log_warning "Empty result from operation: $param1" "module_name"
    return 1
  fi

  echo "$result"
  return 0
}
```

## 🧪 Testing Requirements

### Testing Standards

1. **Function Testing**: Test each function individually
2. **Integration Testing**: Test module interactions
3. **Error Path Testing**: Test error conditions
4. **Cross-Platform Testing**: Test on Linux and macOS
5. **Performance Testing**: Verify performance requirements

### Testing Template

```bash
#!/usr/bin/env bash
# Test script for [module_name]

# Source the module
source "lib/core/[module_name].sh"

# Test function: test_[function_name]
test_function_name() {
  echo "Testing function_name..."

  # Test successful case
  local result
  if result=$(function_name "valid_input" "valid_param"); then
    echo "✅ Success case passed"
  else
    echo "❌ Success case failed"
    return 1
  fi

  # Test error case
  if function_name "invalid_input"; then
    echo "❌ Error case failed (should have returned error)"
    return 1
  else
    echo "✅ Error case passed"
  fi

  return 0
}

# Run tests
test_function_name || exit 1
echo "All tests passed!"
```

## 🔗 Integration Guidelines

### Module Integration

1. **Source Dependencies**: Always source required modules
2. **Check Availability**: Verify functions exist before calling
3. **Handle Missing Dependencies**: Provide graceful fallbacks
4. **Export Functions**: Export functions for cross-module use

### Integration Template

```bash
# Source required modules
if [[ -f "${BASE_DIR}/lib/core/utils/error_utils.sh" ]]; then
  source "${BASE_DIR}/lib/core/utils/error_utils.sh"
else
  echo "Warning: Error utilities not found, some features may be limited" >&2
fi

# Check for optional dependencies
if declare -f optional_function >/dev/null; then
  USE_OPTIONAL_FEATURE=true
else
  USE_OPTIONAL_FEATURE=false
  log_warning "Optional feature not available" "module_name"
fi

# Export functions for other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f function_name_1
  export -f function_name_2
fi
```

## ⚡ Performance Standards

### Performance Requirements

1. **Function Execution**: < 100ms for utility functions
2. **Module Loading**: < 500ms for module initialization
3. **Memory Usage**: Minimal global variable usage
4. **File Operations**: Use efficient file handling
5. **Caching**: Implement caching for expensive operations

### Performance Best Practices

```bash
# Use local variables
function_name() {
  local var1="$1"  # Good
  var2="$2"        # Bad - global variable
}

# Efficient file operations
if [[ -f "$file" ]]; then
  content=$(cat "$file")  # Good for small files
fi

# Use caching for expensive operations
get_cached_value() {
  local cache_key="$1"
  local cache_file="/tmp/cache_${cache_key}"

  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi

  # Expensive operation
  local result
  result=$(expensive_operation "$cache_key")
  echo "$result" > "$cache_file"
  echo "$result"
}
```

## 🔒 Security Requirements

### Security Standards

1. **Input Validation**: Validate all inputs
2. **Path Sanitization**: Sanitize file paths
3. **Command Injection Prevention**: Use safe command execution
4. **File Permissions**: Set appropriate permissions
5. **Sensitive Data**: Handle sensitive data securely

### Security Template

```bash
# Input validation
validate_input() {
  local input="$1"

  # Check for dangerous characters
  if [[ "$input" =~ [;&|`$] ]]; then
    log_error "Invalid characters in input: $input" "security"
    return 1
  fi

  # Validate format
  if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Input format validation failed: $input" "security"
    return 1
  fi

  return 0
}

# Safe command execution
safe_execute() {
  local command="$1"

  # Use util_error_safe_execute for safety
  if ! util_error_safe_execute "$command" 10; then
    log_error "Safe execution failed: $command" "security"
    return 1
  fi
}

# File permission handling
create_secure_file() {
  local file_path="$1"

  # Create file with restricted permissions
  touch "$file_path"
  chmod 600 "$file_path"

  # Verify ownership
  if [[ "$(stat -c %U "$file_path" 2>/dev/null)" != "$(whoami)" ]]; then
    log_error "File ownership verification failed: $file_path" "security"
    return 1
  fi
}
```

## 📝 Examples and Templates

### Complete Module Template

```bash
#!/usr/bin/env bash
#
# ServerSentry v2 - Example Module
#
# This module demonstrates the standard structure and patterns
# for developing new ServerSentry modules.

# Prevent multiple sourcing
if [[ "${EXAMPLE_MODULE_LOADED:-}" == "true" ]]; then
  return 0
fi
EXAMPLE_MODULE_LOADED=true
export EXAMPLE_MODULE_LOADED

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

# Module constants
EXAMPLE_CONFIG_DIR="${BASE_DIR}/config/example"
EXAMPLE_DATA_DIR="${BASE_DIR}/logs/example"

# Function: example_module_init
# Description: Initialize the example module with required directories and configuration
# Parameters: None
# Returns:
#   0 - success
#   1 - failure
# Example:
#   example_module_init
# Dependencies:
#   - util_error_validate_input
example_module_init() {
  if [[ "$#" -ne 0 ]]; then
    log_error "Invalid number of parameters for example_module_init: expected 0, got $#" "example"
    return 1
  fi

  # Create required directories
  local dirs=("$EXAMPLE_CONFIG_DIR" "$EXAMPLE_DATA_DIR")
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      if ! mkdir -p "$dir"; then
        log_error "Failed to create directory: $dir" "example"
        return 1
      fi
      log_debug "Created directory: $dir" "example"
    fi
  done

  log_debug "Example module initialized successfully" "example"
  return 0
}

# Function: example_process_data
# Description: Process data with validation and error handling
# Parameters:
#   $1 (string): input data to process
#   $2 (string): processing type (optional, default: "standard")
# Returns:
#   0 - success (outputs processed data)
#   1 - failure
# Example:
#   result=$(example_process_data "input_data" "advanced")
# Dependencies:
#   - util_error_validate_input
#   - util_error_safe_execute
example_process_data() {
  if ! util_error_validate_input "example_process_data" "1" "$#"; then
    return 1
  fi

  local input_data="$1"
  local processing_type="${2:-standard}"

  # Validate input data
  if [[ -z "$input_data" ]]; then
    log_error "Empty input data provided" "example"
    return 1
  fi

  # Validate processing type
  case "$processing_type" in
    "standard"|"advanced"|"minimal")
      log_debug "Using processing type: $processing_type" "example"
      ;;
    *)
      log_error "Invalid processing type: $processing_type" "example"
      return 1
      ;;
  esac

  # Process the data
  local result
  case "$processing_type" in
    "standard")
      result=$(echo "$input_data" | tr '[:lower:]' '[:upper:]')
      ;;
    "advanced")
      result=$(echo "$input_data" | sed 's/[^a-zA-Z0-9]/_/g')
      ;;
    "minimal")
      result="$input_data"
      ;;
  esac

  if [[ -z "$result" ]]; then
    log_error "Processing failed for input: $input_data" "example"
    return 1
  fi

  echo "$result"
  log_debug "Successfully processed data: $input_data -> $result" "example"
  return 0
}

# Export functions for cross-module use
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f example_module_init
  export -f example_process_data
fi

# Initialize the module
if ! example_module_init; then
  log_error "Failed to initialize example module" "example"
fi
```

### Quick Start Checklist

When creating a new module:

- [ ] Copy the module template
- [ ] Update module name and description
- [ ] Define module constants
- [ ] Implement initialization function
- [ ] Add core functionality functions
- [ ] Include proper error handling
- [ ] Add comprehensive documentation
- [ ] Export functions
- [ ] Test all functions
- [ ] Verify integration

### Development Workflow

1. **Plan**: Define module purpose and functions
2. **Template**: Start with the module template
3. **Implement**: Add functions following standards
4. **Document**: Complete all documentation
5. **Test**: Test individual functions and integration
6. **Review**: Verify compliance with standards
7. **Integrate**: Add to main system
8. **Validate**: Final testing and validation

## 🎯 Quality Assurance

### Code Review Checklist

- [ ] Function documentation complete
- [ ] Input validation implemented
- [ ] Error handling comprehensive
- [ ] Local variables used
- [ ] Consistent naming conventions
- [ ] Performance considerations addressed
- [ ] Security requirements met
- [ ] Cross-platform compatibility
- [ ] Integration tested
- [ ] Backward compatibility maintained

### Compliance Verification

Use the provided analysis tools:

```bash
# Function analysis
./tools/function-analysis/categorize_functions.sh

# Documentation coverage
./tools/function-analysis/check_documentation.sh

# Code quality assessment
./tools/function-analysis/quality_check.sh
```

## 📞 Support and Resources

### Getting Help

- **Documentation**: Check existing module documentation
- **Examples**: Review implemented modules in `lib/core/`
- **Templates**: Use provided templates as starting points
- **Analysis Tools**: Use tools in `tools/function-analysis/`

### Best Practices Summary

1. **Follow the Template**: Use established patterns
2. **Document Everything**: 100% documentation coverage
3. **Validate Inputs**: Always validate parameters
4. **Handle Errors**: Comprehensive error handling
5. **Test Thoroughly**: Test all code paths
6. **Maintain Compatibility**: Never break existing code
7. **Performance Matters**: Consider performance implications
8. **Security First**: Validate and sanitize all inputs

---

**Remember**: These standards ensure ServerSentry maintains its professional quality and enterprise-grade reliability. Following these guidelines will result in code that integrates seamlessly with the existing platform and maintains the high standards established throughout the project.
