# Test Reports Directory

This directory contains generated test reports from the ServerSentry test suite.

## Generated Files

- `test_report_YYYYMMDD_HHMMSS.html` - HTML test reports with metrics and summaries
- `coverage_report.html` - Code coverage reports
- `performance_report.json` - Performance benchmark results
- `test_results.xml` - JUnit-style XML reports for CI integration

## Usage

Reports are automatically generated when running:

```bash
./tests/run_enhanced_tests.sh --report --coverage
```

## Note

Generated report files are ignored by git (see `.gitignore`). Only this README and the directory structure are tracked.
