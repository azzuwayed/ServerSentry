# ServerSentry v2 - Cross-Platform Compatibility Layer

## Overview

The ServerSentry compatibility layer provides a unified interface for system operations across different operating systems (macOS and Linux). This layer abstracts away OS-specific differences and provides consistent APIs for common operations.

## Architecture

The compatibility layer is implemented in `lib/core/utils/compat_utils.sh` and is automatically sourced by the main ServerSentry executable and other core components.

### Supported Platforms

- **macOS** (Darwin) - Intel and Apple Silicon
- **Linux** - All major distributions (Ubuntu, CentOS, RHEL, Debian, etc.)
- **Partial Windows support** - Detection only (not fully implemented)

## Core Functions

### System Detection

#### `compat_get_os()`

Returns the operating system type.

```bash
os=$(compat_get_os)
# Returns: "macos", "linux", "windows", or "unknown"
```

#### `compat_get_os_version()`

Returns the OS version string.

```bash
version=$(compat_get_os_version)
# macOS: "15.4.1"
# Linux: depends on distribution
```

#### `compat_get_package_manager()`

Detects the system package manager.

```bash
pm=$(compat_get_package_manager)
# macOS: "brew", "macports", or "none"
# Linux: "apt", "yum", "dnf", "pacman", "zypper", or "unknown"
```

### Bash Detection and Compatibility

#### `compat_get_bash_path()`

Returns the path to the best available bash executable.

```bash
bash_path=$(compat_get_bash_path)
# Example: "/usr/local/bin/bash"
```

#### `compat_get_bash_version()`

Returns the bash version string.

```bash
version=$(compat_get_bash_version)
# Example: "5.2.37"
```

#### `compat_bash_is_compatible()`

Checks if bash version is 4.0 or higher.

```bash
if compat_bash_is_compatible; then
    echo "Bash supports modern features"
fi
```

#### `compat_bash_supports_assoc_arrays()`

Checks if bash supports associative arrays (4.0+).

```bash
if compat_bash_supports_assoc_arrays; then
    declare -A my_array
fi
```

### Command and File Operations

#### `compat_command_exists(cmd)`

Cross-platform command existence check.

```bash
if compat_command_exists "jq"; then
    echo "jq is available"
fi
```

#### `compat_sed_inplace(expression, file)`

Cross-platform in-place file editing.

```bash
# Works on both macOS and Linux
compat_sed_inplace 's/old/new/g' "myfile.txt"
```

#### `compat_stat_size(file)`

Get file size in bytes.

```bash
size=$(compat_stat_size "/path/to/file")
```

#### `compat_stat_mtime(file)`

Get file modification time as Unix timestamp.

```bash
mtime=$(compat_stat_mtime "/path/to/file")
```

### System Information

#### `compat_get_memory_info()`

Get system memory information in MB.

```bash
memory=$(compat_get_memory_info)
# Returns: "total:16384 used:8192 free:8192"
```

#### `compat_get_cpu_usage()`

Get current CPU usage percentage.

```bash
cpu=$(compat_get_cpu_usage)
# Returns: "25.4"
```

#### `compat_get_load_average()`

Get system load average (1-minute).

```bash
load=$(compat_get_load_average)
# Returns: "2.45"
```

#### `compat_get_hostname()`

Get fully qualified hostname.

```bash
hostname=$(compat_get_hostname)
```

#### `compat_get_uptime()`

Get system uptime in seconds.

```bash
uptime=$(compat_get_uptime)
```

### Date and Time Operations

#### `compat_date(...)`

Cross-platform date command wrapper.

```bash
# ISO 8601 date
iso_date=$(compat_date --iso-8601)

# ISO 8601 with time and timezone
iso_datetime=$(compat_date --iso-8601=seconds)

# Regular date operations work normally
current_date=$(compat_date)
```

### Process Information

#### `compat_ps_cpu()`

Get CPU usage for all processes.

```bash
# Returns: PID %CPU COMMAND format
compat_ps_cpu
```

#### `compat_ps_memory()`

Get memory usage for all processes.

```bash
# Returns: PID %MEM RSS COMMAND format
compat_ps_memory
```

### Disk Operations

#### `compat_df(...)`

Cross-platform disk usage command.

```bash
# Get disk usage in human-readable format
compat_df -H /
```

### Package Management

#### `compat_package_installed(package)`

Check if a package is installed.

```bash
if compat_package_installed "curl"; then
    echo "curl is installed"
fi
```

#### `compat_install_package(package)`

Install a package using the system package manager.

```bash
compat_install_package "jq"
```

### Utility Functions

#### `compat_is_root()`

Check if running as root/administrator.

```bash
if compat_is_root; then
    echo "Running with admin privileges"
fi
```

#### `compat_get_user()`

Get current username.

```bash
user=$(compat_get_user)
```

#### `compat_mkdir(dir, mode)`

Create directory with proper permissions.

```bash
compat_mkdir "/path/to/dir" 755
```

#### `compat_chmod(mode, file)`

Set file permissions.

```bash
compat_chmod 644 "/path/to/file"
```

## Integration with Existing Code

### Automatic Integration

The compatibility layer is automatically sourced by:

- Main ServerSentry executable (`bin/serversentry`)
- Installation script (`bin/install.sh`)
- Core utilities (`lib/core/utils.sh`)

### Backward Compatibility

Existing functions are wrapped to use the compatibility layer when available:

```bash
# These functions now use the compatibility layer internally
command_exists "jq"      # Uses compat_command_exists()
get_os_type()           # Uses compat_get_os()
get_timestamp()         # Uses compat_date()
```

### Plugin Updates

Plugins have been updated to use compatibility functions:

```bash
# CPU Plugin
result=$(compat_get_cpu_usage)

# Memory Plugin
memory_info=$(compat_get_memory_info)

# Disk Plugin
df_output=$(compat_df -kP)
```

## Best Practices

### 1. Always Use Compatibility Functions

Instead of direct system calls, use the compatibility layer:

```bash
# Good
if compat_command_exists "jq"; then
    # Use jq
fi

# Avoid
if command -v jq >/dev/null 2>&1; then
    # Use jq
fi
```

### 2. Handle Platform Differences

When adding new functionality, consider platform differences:

```bash
case "$(compat_get_os)" in
    macos)
        # macOS-specific code
        ;;
    linux)
        # Linux-specific code
        ;;
    *)
        # Fallback or error
        ;;
esac
```

### 3. Error Handling

Always provide fallbacks for unsupported operations:

```bash
result=$(compat_get_cpu_usage 2>/dev/null)
if [[ -z "$result" || "$result" == "0.0" ]]; then
    # Fallback method
    result="unknown"
fi
```

### 4. Testing Across Platforms

Test your code on both macOS and Linux to ensure compatibility:

```bash
# Test script example
source lib/core/utils/compat_utils.sh
compat_info
```

## Platform-Specific Notes

### macOS

- Uses Homebrew bash when available (`/usr/local/bin/bash`)
- Memory information from `vm_stat` and `sysctl`
- CPU usage from `iostat`
- Package management via Homebrew

### Linux

- Uses system bash (`/usr/bin/bash` or `/bin/bash`)
- Memory information from `/proc/meminfo`
- CPU usage from `/proc/stat`
- Package management via distribution package manager

## Troubleshooting

### Common Issues

1. **Bash Version Too Old**: Ensure bash 4.0+ is installed
2. **Missing Commands**: Install required system tools
3. **Permission Issues**: Ensure proper file permissions

### Debug Information

Use `compat_info` to display comprehensive system information:

```bash
source lib/core/utils/compat_utils.sh
compat_info
```

Output example:

```
Compatibility Information:
  OS: macos 15.4.1
  Package Manager: brew
  Bash Path: /usr/local/bin/bash
  Bash Version: 5.2.37
  Bash Compatible: yes
  Associative Arrays: yes
  User: username
  Root: no
  Hostname: hostname.local
```

## Future Enhancements

- Windows support (via WSL or native)
- FreeBSD support
- Alpine Linux optimizations
- Additional system information functions
- Performance optimizations

## Contributing

When adding new compatibility functions:

1. Follow the naming convention: `compat_*`
2. Handle all supported platforms
3. Provide reasonable fallbacks
4. Document the function
5. Test on multiple platforms
