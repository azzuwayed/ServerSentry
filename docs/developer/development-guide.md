# ServerSentry Development Guide

**Complete Guide for Developing ServerSentry Modules**

## 📋 Overview

This guide provides everything you need to develop high-quality, professional modules for the ServerSentry monitoring platform. ServerSentry follows enterprise-grade development standards with emphasis on modularity, reliability, and maintainability.

## 🚀 Quick Start

### 1. Read the Documentation

- **[Development Standards](development-standards.md)** - Complete development standards and guidelines
- **[Development Quick Reference](development-quick-reference.md)** - Quick reference and cheat sheet
- **[Sample Module](examples/sample_module.sh)** - Complete working example module
- **[Test Sample Module](examples/test_sample_module.sh)** - Comprehensive testing example

### 2. Set Up Your Environment

```bash
# Clone the repository
git clone <repository-url>
cd ServerSentry

# Set up BASE_DIR
export BASE_DIR="$(pwd)"

# Source core utilities
source lib/core/utils/error_utils.sh
source lib/core/utils/documentation_utils.sh
```

### 3. Create Your First Module

```bash
# Copy the template
cp examples/sample_module.sh lib/core/your_module.sh

# Edit the module
vim lib/core/your_module.sh

# Test your module
cp examples/test_sample_module.sh test_your_module.sh
# Edit test file and run
./test_your_module.sh
```

## 📚 Documentation Structure

### Core Documentation

| Document                         | Purpose                                   | Audience               |
| -------------------------------- | ----------------------------------------- | ---------------------- |
| `development-standards.md`       | Complete development standards            | All developers         |
| `development-quick-reference.md` | Quick reference guide                     | Experienced developers |
| `development-guide.md`           | This guide - overview and getting started | New developers         |

### Examples and Templates

| File                             | Purpose                  | Use Case                 |
| -------------------------------- | ------------------------ | ------------------------ |
| `examples/sample_module.sh`      | Complete working module  | Template for new modules |
| `examples/test_sample_module.sh` | Comprehensive test suite | Template for testing     |

### Analysis Tools

| Tool                                                      | Purpose             | Usage                    |
| --------------------------------------------------------- | ------------------- | ------------------------ |
| `tools/function-analysis/categorize_functions.sh`         | Function analysis   | Code quality assessment  |
| `tools/function-analysis/extract_lib_functions_simple.sh` | Function extraction | Documentation generation |

## 🏗️ Development Workflow

### Step 1: Planning

1. Define module purpose and scope
2. Identify required functions
3. Plan integration points
4. Review existing modules for patterns

### Step 2: Implementation

1. Copy the sample module template
2. Update module header and constants
3. Implement initialization function
4. Add core functionality functions
5. Include comprehensive error handling
6. Add complete documentation

### Step 3: Testing

1. Copy the test template
2. Implement function-specific tests
3. Add error path testing
4. Include integration tests
5. Verify all test cases pass

### Step 4: Integration

1. Update main system files if needed
2. Add module to loading sequence
3. Test integration with existing modules
4. Verify backward compatibility

### Step 5: Quality Assurance

1. Run function analysis tools
2. Verify documentation coverage
3. Check code quality standards
4. Perform final testing

## 🔧 Module Development Standards

For complete technical standards and requirements, see the **[Development Standards](development-standards.md)** document.

### Key Requirements Summary

- **Complete documentation** for every function
- **Input validation** using `util_error_validate_input`
- **Comprehensive error handling** with proper logging
- **Consistent naming** following `[module]_[action]_[object]` pattern
- **Cross-platform compatibility** (Linux and macOS)
- **Backward compatibility** - no breaking changes

## 📝 Code Examples

For complete code examples and templates, see:

- **[Development Standards](development-standards.md)** - Complete function templates and patterns
- **[Sample Module](examples/sample_module.sh)** - Working example module
- **[Test Sample Module](examples/test_sample_module.sh)** - Complete test suite example

### Quick Function Template

```bash
# Function: module_action_object
# Description: What this function does
# Parameters:
#   $1 (string): parameter description
# Returns:
#   0 - success, 1 - failure
# Example:
#   result=$(module_action_object "param1")
module_action_object() {
  if ! util_error_validate_input "module_action_object" "1" "$#"; then
    return 1
  fi

  local param1="$1"

  # Your logic here
  echo "result"
  return 0
}
```

## 🧪 Testing Guidelines

For complete testing standards and templates, see:

- **[Development Standards](development-standards.md)** - Complete testing requirements
- **[Test Sample Module](examples/test_sample_module.sh)** - Working test example

### Quick Test Template

```bash
#!/usr/bin/env bash
# Test script for [module]

source "lib/core/[module].sh"

test_function_name() {
  echo "Testing function_name..."

  # Test success case
  if function_name "valid_input"; then
    echo "✅ Success case passed"
  else
    echo "❌ Success case failed"
    return 1
  fi

  return 0
}

# Run tests
test_function_name || exit 1
echo "All tests passed!"
```

## 🔍 Available Utilities

For complete utility documentation, see **[Development Standards](development-standards.md)**.

### Essential Utilities

```bash
# Input validation (always use this)
util_error_validate_input "function_name" "expected_count" "$#"

# Logging (available everywhere)
log_debug "message" "module"
log_info "message" "module"
log_warning "message" "module"
log_error "message" "module"

# Safe command execution
util_error_safe_execute "command" timeout_seconds
```

## 📊 Quality Assurance

For complete quality standards and checklists, see **[Development Standards](development-standards.md)**.

### Quick Checklist

Before submitting code:

- [ ] Function documentation complete
- [ ] Input validation implemented
- [ ] Error handling comprehensive
- [ ] All tests pass

### Analysis Tools

```bash
# Function analysis
./tools/function-analysis/categorize_functions.sh
```

## 🎯 Best Practices

For complete best practices and patterns, see **[Development Standards](development-standards.md)**.

### Essential Do's

1. **Follow the Template** - Use the sample module as a starting point
2. **Document Everything** - Every function needs documentation
3. **Validate Inputs** - Always use `util_error_validate_input`
4. **Handle Errors** - Use proper error handling and logging
5. **Test Thoroughly** - Write tests for your functions

### Essential Don'ts

1. **Don't Skip Validation** - Always validate inputs
2. **Don't Use Global Variables** - Use local variables only
3. **Don't Skip Documentation** - Document every function
4. **Don't Break Compatibility** - Maintain backward compatibility

## 📞 Getting Help

### Resources

- **[Development Standards](development-standards.md)** - Complete technical documentation
- **[Sample Module](examples/sample_module.sh)** - Working example to copy
- **[Test Example](examples/test_sample_module.sh)** - Complete test template
- **Existing Modules** - Check `lib/core/` for patterns

## 🎉 Success Criteria

Your module is ready when:

- [ ] All functions are documented
- [ ] All tests pass
- [ ] Code follows standards
- [ ] Integration works correctly

---

**Remember**: Following these standards ensures your code integrates seamlessly with ServerSentry and maintains the high quality standards established throughout the project. Quality code is maintainable code!
