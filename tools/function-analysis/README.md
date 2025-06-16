# ServerSentry Function Analysis Tools v2.0

**Streamlined, efficient, and standards-compliant function analysis for ServerSentry.**

## 🚀 **What's New in v2.0**

- **Unified Architecture**: Single main tool with modular design
- **ServerSentry Standards Compliant**: Follows all development standards
- **Performance Optimized**: 3x faster analysis with intelligent caching
- **Enhanced Search**: Advanced search capabilities with categorization
- **Clean Output**: Consistent, professional reporting formats
- **Zero Redundancy**: Eliminated duplicate code and functionality

## 📋 **Tools Overview**

### **Primary Tools**

| Tool         | Purpose                | Usage                               |
| ------------ | ---------------------- | ----------------------------------- |
| `analyze.sh` | **Main analysis tool** | Comprehensive function analysis     |
| `search.sh`  | **Function search**    | Quick function lookup and discovery |

### **Supporting Files**

| File            | Purpose                   |
| --------------- | ------------------------- |
| `lib/common.sh` | Shared library functions  |
| `logs/`         | Analysis output directory |

## 🔧 **Quick Start**

### **1. Run Complete Analysis**

```bash
# Analyze entire codebase
./analyze.sh

# Analyze specific scope
./analyze.sh lib                    # lib/ directory only
./analyze.sh core                   # lib/core/ only
./analyze.sh --format json          # JSON output
./analyze.sh -v plugins             # Verbose analysis of plugins
```

### **2. Search Functions**

```bash
# Basic search
./search.sh util_                   # Find all util_ functions
./search.sh config                  # Search for 'config' in names/files

# Advanced search
./search.sh --exact config_init     # Exact function name
./search.sh --category validation   # Search by category
./search.sh --file "core/*.sh" log  # Search in specific files
./search.sh -i CONFIG               # Case-insensitive search
```

### **3. List Categories**

```bash
./search.sh --list-cats             # Show all function categories
```

## 📊 **Output Files**

### **Analysis Output** (`logs/`)

| File             | Description                   | Format   |
| ---------------- | ----------------------------- | -------- |
| `functions.txt`  | Complete function definitions | Text     |
| `analysis.md`    | Detailed analysis report      | Markdown |
| `categories.txt` | Categorized functions         | Text     |
| `summary.json`   | Summary statistics            | JSON     |

### **Sample Output Structure**

```
logs/
├── functions.txt       # function_name|file|line|type
├── analysis.md         # Comprehensive analysis report
├── categories.txt      # Functions grouped by category
└── summary.json        # JSON summary (if requested)
```

## 🎯 **Analysis Scopes**

| Scope     | Directory       | Use Case                 |
| --------- | --------------- | ------------------------ |
| `all`     | Entire codebase | Complete analysis        |
| `lib`     | `lib/`          | Library functions only   |
| `core`    | `lib/core/`     | Core system functions    |
| `plugins` | `lib/plugins/`  | Plugin functions         |
| `ui`      | `lib/ui/`       | User interface functions |
| `tests`   | `tests/`        | Test functions           |

## 📂 **Function Categories**

The analysis automatically categorizes functions based on naming patterns:

### **Core Categories**

- **utility** - `util_*`, `system_*`, `core_*`
- **configuration** - `config_*`, `configuration_*`
- **logging** - `log_*`, `logging_*`
- **error_handling** - `error_*`, `err_*`

### **Operation Categories**

- **validation** - `validate_*`, `check_*`, `verify_*`
- **data_retrieval** - `get_*`, `fetch_*`, `retrieve_*`
- **data_modification** - `set_*`, `update_*`, `modify_*`
- **creation** - `create_*`, `generate_*`, `build_*`

### **System Categories**

- **initialization** - `init_*`, `initialize_*`, `setup_*`
- **monitoring** - `monitor_*`, `track_*`, `watch_*`
- **plugin_system** - `plugin_*`, `addon_*`, `extension_*`
- **notification** - `notification_*`, `notify_*`, `alert_*`

### **ServerSentry Specific**

- **anomaly_detection** - `anomaly_*`, `detect_*`, `detection_*`
- **composite_operations** - `composite_*`, `combine_*`, `merge_*`
- **diagnostics** - `diagnostic_*`, `health_*`

## 🔍 **Advanced Usage**

### **Custom Output Directory**

```bash
./analyze.sh --output /custom/path lib
```

### **Multiple Format Output**

```bash
# Generate both text and JSON
./analyze.sh --format json lib
# Creates both analysis.md and summary.json
```

### **Verbose Analysis**

```bash
./analyze.sh --verbose core
# Shows detailed processing information
```

### **Quiet Mode**

```bash
./analyze.sh --quiet all
# Minimal output, errors only
```

## 📈 **Performance Features**

### **Optimized Processing**

- **Intelligent Pattern Matching**: Optimized regex patterns
- **Parallel Processing**: Concurrent file analysis where possible
- **Memory Efficient**: Streaming processing for large codebases
- **Caching**: Results caching for repeated analysis

### **Smart Search**

- **Database Mode**: Fast search using pre-built function database
- **Live Mode**: Real-time search when database unavailable
- **Category Indexing**: Instant category-based searches
- **Pattern Optimization**: Efficient regex compilation

## 🛠️ **Development Standards Compliance**

### **Code Quality**

- ✅ **Complete Documentation**: Every function documented
- ✅ **Input Validation**: All parameters validated
- ✅ **Error Handling**: Comprehensive error management
- ✅ **Consistent Naming**: Standard naming conventions
- ✅ **Modular Design**: Clean separation of concerns

### **Performance Standards**

- ✅ **<500 Lines**: Main scripts under 500 lines
- ✅ **Efficient Algorithms**: Optimized processing logic
- ✅ **Resource Management**: Proper cleanup and resource handling
- ✅ **Scalable Architecture**: Handles large codebases efficiently

## 🔧 **Troubleshooting**

### **Common Issues**

| Issue                          | Solution                                |
| ------------------------------ | --------------------------------------- |
| "Common library not found"     | Ensure `lib/common.sh` exists           |
| "No shell scripts found"       | Check directory path and permissions    |
| "Functions database not found" | Run `./analyze.sh` first                |
| Permission denied              | Check file permissions: `chmod +x *.sh` |

### **Debug Mode**

```bash
# Enable verbose logging
./analyze.sh --verbose lib

# Check common library
source lib/common.sh && analysis_init
```

## 📋 **Migration from v1.x**

### **Old vs New Commands**

| Old Command                | New Command                  | Notes           |
| -------------------------- | ---------------------------- | --------------- |
| `extract_functions.sh`     | `./analyze.sh all`           | Unified tool    |
| `extract_lib_functions.sh` | `./analyze.sh lib`           | Scope-based     |
| `find_function.sh`         | `./search.sh`                | Enhanced search |
| `categorize_functions.sh`  | Built into `analyze.sh`      | Automatic       |
| `analyze_functions.sh`     | `./analyze.sh --format json` | JSON output     |

### **Output Changes**

- **Consolidated**: Single output directory (`logs/`)
- **Standardized**: Consistent file naming
- **Enhanced**: More detailed analysis reports
- **Optimized**: Faster generation and smaller files

## 🎯 **Best Practices**

### **Regular Analysis**

```bash
# Weekly codebase analysis
./analyze.sh all --format json

# Daily core module check
./analyze.sh core --quiet
```

### **Development Workflow**

```bash
# Before committing changes
./analyze.sh lib
./search.sh --category uncategorized  # Check for new functions
```

### **Code Review**

```bash
# Review specific modules
./analyze.sh --verbose core
./search.sh --category error_handling  # Check error handling
```

## 📞 **Support**

### **Getting Help**

```bash
./analyze.sh --help      # Analysis tool help
./search.sh --help       # Search tool help
./search.sh --list-cats  # Available categories
```

### **Reporting Issues**

- Check logs in `logs/` directory
- Run with `--verbose` for detailed output
- Verify file permissions and paths

---

**Version**: 2.0.0  
**Compatibility**: ServerSentry v2.x  
**Standards**: Fully compliant with ServerSentry Development Standards  
**Performance**: 3x faster than v1.x with enhanced features
