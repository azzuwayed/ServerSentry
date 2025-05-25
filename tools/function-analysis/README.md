# ServerSentry Function Analysis Tools

This directory contains tools for analyzing function definitions and usage across the ServerSentry codebase.

## Tools

### 1. `extract_functions.sh` (Recommended)

The main comprehensive function analysis tool.

**Usage:**

```bash
cd tools/function-analysis
./extract_functions.sh
```

**Generates:**

- `logs/all_functions.txt` - Complete list of all function definitions
- `logs/function_usage.txt` - Functions organized by category
- `logs/function_summary.md` - Detailed analysis report

### 2. `find_function.sh`

Quick search tool for finding specific functions.

**Usage:**

```bash
./find_function.sh <search_term>
```

**Examples:**

```bash
./find_function.sh config          # Find config-related functions
./find_function.sh util_           # Find utility functions
./find_function.sh logging.sh      # Find functions in logging.sh
```

### 3. `analyze_functions.sh`

Advanced analysis with dependency tracking (complex).

**Usage:**

```bash
./analyze_functions.sh
```

**Generates:**

- `logs/functions_analysis_report.md` - Detailed report with dependencies
- `logs/functions_analysis.json` - JSON format data
- `logs/functions_analysis.csv` - CSV format data

### 4. `analyze_functions_simple.sh`

Simplified version of the analysis tool.

**Usage:**

```bash
./analyze_functions_simple.sh
```

**Generates:**

- `logs/functions_report.md` - Basic analysis report
- `logs/functions_data.csv` - Function data in CSV format

## Quick Start

1. Run the main analysis:

   ```bash
   cd tools/function-analysis
   ./extract_functions.sh
   ```

2. Search for specific functions:

   ```bash
   ./find_function.sh util_
   ```

3. View the summary report:
   ```bash
   cat logs/function_summary.md
   ```

## Output Files

All generated files are stored in the `logs/` subdirectory to keep the tools directory organized:

- **Reports**: `logs/*.md` files with human-readable analysis
- **Data**: `logs/*.txt` and `logs/*.csv` files with raw function data
- **JSON**: `logs/*.json` files for programmatic access

## Function Patterns Found

Based on the analysis, common function patterns in ServerSentry include:

- `test_*`: Test functions (378 functions)
- `util_*`: Utility functions (76 functions)
- `generate_*`: Code generation functions (49 functions)
- `print_*`: Output formatting functions (47 functions)
- `create_*`: Object creation functions (28 functions)
- `setup_*`: Initialization functions (27 functions)
- `compat_*`: Cross-platform compatibility functions (26 functions)

## Notes

- All tools work from any directory but output files are generated in this directory
- The `find_function.sh` tool requires `logs/all_functions.txt` to exist (run `extract_functions.sh` first)
- Tools are designed to handle the post-refactoring codebase structure
