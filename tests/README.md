# ServerSentry v2 Test Suite

This directory contains the comprehensive test suite for ServerSentry v2, implementing Phase 1 and Phase 2 enhancements.

## Directory Structure

```
tests/
├── unit/                           # Unit tests organized by component
│   ├── core/                      # Core functionality tests
│   ├── plugins/                   # Plugin-specific tests
│   ├── notifications/             # Notification system tests
│   ├── config/                    # Configuration tests
│   ├── error_handling/            # Error handling tests
│   └── persistence/               # Data persistence tests
├── integration/                   # Integration tests
│   ├── api/                      # API interface tests
│   └── scenarios/                # Real-world scenario tests
├── performance/                   # Performance and benchmark tests
├── fixtures/                     # Test data and configurations
│   ├── configs/                  # Test configuration files
│   ├── responses/                # Mock API responses
│   └── logs/                     # Sample log files
├── helpers/                      # Test utilities and helpers
├── reports/                      # Generated test reports
└── tmp/                         # Temporary test files
```

## Test Categories

### Unit Tests

**Core Tests** (`tests/unit/core/`)

- Configuration utilities
- Validation utilities
- JSON utilities
- Array utilities
- Command utilities

**Plugin Tests** (`tests/unit/plugins/`)

- CPU monitoring
- Memory monitoring
- Disk monitoring
- Process monitoring

**Notification Tests** (`tests/unit/notifications/`)

- Email notifications
- Slack notifications
- Teams notifications

**Configuration Tests** (`tests/unit/config/`)

- Configuration validation
- Environment variable overrides
- Configuration migration
- Dynamic reloading

**Error Handling Tests** (`tests/unit/error_handling/`)

- Network failure handling
- Disk full scenarios
- Permission denied errors
- Resource exhaustion

### Integration Tests

**API Tests** (`tests/integration/api/`)

- CLI interface testing
- Webhook endpoints
- Metrics API
- Health check endpoints

**Scenario Tests** (`tests/integration/scenarios/`)

- High load scenarios
- Network partition testing
- Service restart scenarios
- Upgrade testing

### Performance Tests

**Benchmark Tests** (`tests/performance/`)

- Configuration parsing performance
- Plugin execution benchmarks
- JSON processing performance
- Memory usage monitoring
- Concurrent execution testing
- Load testing scenarios

## Test Framework Features

### Enhanced Test Helpers

The test framework includes advanced utilities:

- **Mocking System**: HTTP server simulation using netcat
- **Property-Based Testing**: Random data generation and validation
- **Performance Measurement**: Execution time and memory monitoring
- **Error Simulation**: Network failure, disk full, CPU load simulation
- **Test Environment Isolation**: Isolated test environments
- **Parallel Execution**: Multi-threaded test execution
- **Coverage Tracking**: Function call tracking and HTML reports

### Test Data Management

**Fixtures** (`tests/fixtures/`)

- Pre-configured test data
- Mock API responses
- Sample configuration files
- Test log files

**Random Data Generation**

- Property-based testing with random inputs
- Configuration generators
- Metrics data generators
- Edge case generation

## Running Tests

### Available Test Runners

#### 1. Enhanced Test Runner (Primary) ⭐

**File**: `run_enhanced_tests.sh`

The main test runner with comprehensive features:

```bash
# Run all tests
./tests/run_enhanced_tests.sh

# Run specific categories
./tests/run_enhanced_tests.sh --category unit
./tests/run_enhanced_tests.sh --category integration
./tests/run_enhanced_tests.sh --category performance

# Run with parallel execution
./tests/run_enhanced_tests.sh --parallel 8

# Generate reports
./tests/run_enhanced_tests.sh --report --coverage

# List available tests
./tests/run_enhanced_tests.sh --list

# Get help
./tests/run_enhanced_tests.sh --help
```

**Features**:

- ✅ Parallel test execution
- ✅ Categorized test organization
- ✅ HTML report generation
- ✅ Coverage tracking
- ✅ Performance benchmarking
- ✅ Command-line options
- ✅ Test filtering
- ✅ Comprehensive reporting

#### 2. Simple Test Runner (Wrapper)

**File**: `run_tests.sh`

A simple wrapper for backward compatibility:

```bash
# Run all tests (calls enhanced runner)
./tests/run_tests.sh

# Pass arguments to enhanced runner
./tests/run_tests.sh --category unit
./tests/run_tests.sh --help
```

**Purpose**: Provides a simple interface that forwards all calls to the enhanced runner.

### Recommended Usage

#### For Daily Development

```bash
# Quick test run
./tests/run_tests.sh

# Run specific category
./tests/run_enhanced_tests.sh --category unit
```

#### For CI/CD

```bash
# Full test suite with reports
./tests/run_enhanced_tests.sh --parallel 4 --report --coverage
```

#### For Performance Testing

```bash
# Include performance benchmarks
./tests/run_enhanced_tests.sh --category performance
```

#### For Debugging

```bash
# Run single test file
./tests/unit/core/config_validation_test.sh

# Run with verbose output
export TEST_VERBOSE=true
./tests/run_enhanced_tests.sh --category unit
```

### Advanced Options

```bash
# Skip performance tests
./tests/run_enhanced_tests.sh --no-performance

# Skip integration tests
./tests/run_enhanced_tests.sh --no-integration

# List available test suites
./tests/run_enhanced_tests.sh --list

# Run individual test files
./tests/unit/core/core_config_utils_test.sh
./tests/performance/benchmark_test.sh
./tests/integration/scenarios/high_load_scenario.sh
```

## Test Development Guidelines

### Writing New Tests

1. **Follow Naming Convention**

   - Unit tests: `{component}_{function}_test.sh`
   - Integration tests: `{scenario}_test.sh`
   - Performance tests: `{benchmark}_test.sh`

2. **Use Test Framework**

   ```bash
   source "$SCRIPT_DIR/../test_framework.sh"
   source "$SCRIPT_DIR/../helpers/test_helpers.sh"
   ```

3. **Implement Required Functions**

   ```bash
   setup_test_name_tests()    # Setup function
   cleanup_test_name_tests()  # Cleanup function
   test_specific_feature()    # Individual test functions
   main()                     # Main execution function
   ```

4. **Use Assertions**
   ```bash
   assert_equals "expected" "actual" "Test description"
   assert_true condition "Test description"
   assert_file_exists "/path/to/file" "Test description"
   ```

### Property-Based Testing

Use property-based testing for comprehensive validation:

```bash
test_property "property_name" test_function_name 10

test_function_name() {
  local iteration="$1"
  local random_config=$(generate_random_config "monitoring")
  # Test logic here
  return 0  # or 1 for failure
}
```

### Performance Testing

Measure execution time and memory usage:

```bash
execution_time=$(measure_execution_time "command_to_test" 5)
memory_usage=$(monitor_memory_usage "$pid" 10 1)

assert_performance "test_name" "$execution_time" "$threshold"
```

### Error Simulation

Simulate various error conditions:

```bash
simulate_network_failure 5        # 5 seconds
simulate_disk_full "$dir" "100M"  # 100MB file
simulate_cpu_load 10 4            # 10 seconds, 4 processes
```

## Test Reports

### HTML Reports

Generated reports include:

- Test execution summary
- Success/failure rates
- Performance metrics
- Coverage information
- Detailed test results

Reports are saved to `tests/reports/test_report_YYYYMMDD_HHMMSS.html`

### Coverage Reports

Coverage tracking includes:

- Function call frequency
- Code path coverage
- Uncovered functions
- Coverage percentage

Coverage reports are saved to `tests/reports/coverage_report.html`

## Continuous Integration

### GitHub Actions Integration

```yaml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: |
          chmod +x tests/run_enhanced_tests.sh
          tests/run_enhanced_tests.sh --parallel 4 --coverage --report
      - name: Upload Reports
        uses: actions/upload-artifact@v2
        with:
          name: test-reports
          path: tests/reports/
```

### Quality Gates

- Minimum 80% test coverage
- All tests must pass before merge
- Performance tests within acceptable limits
- Security tests must pass

## Troubleshooting

### Common Issues

1. **Permission Errors**

   ```bash
   chmod +x tests/run_enhanced_tests.sh
   chmod +x tests/unit/**/*_test.sh
   ```

2. **Missing Dependencies**

   ```bash
   # Install required tools
   brew install jq bc netcat  # macOS
   apt-get install jq bc netcat  # Ubuntu
   ```

3. **Test Failures**
   - Check test logs in `tests/tmp/`
   - Review error messages in test output
   - Verify system requirements
   - Check file permissions

### Debug Mode

Enable debug output:

```bash
export TEST_DEBUG=true
./tests/run_enhanced_tests.sh
```

### Verbose Output

Get detailed test execution information:

```bash
export TEST_VERBOSE=true
./tests/run_enhanced_tests.sh
```

## Contributing

### Adding New Tests

1. Create test file in appropriate directory
2. Follow naming conventions
3. Implement required functions
4. Add test to enhanced test runner
5. Update documentation
6. Test locally before submitting

### Test Review Checklist

- [ ] Test follows naming convention
- [ ] Proper setup/cleanup functions
- [ ] Comprehensive test coverage
- [ ] Error handling tested
- [ ] Performance considerations
- [ ] Documentation updated
- [ ] CI integration verified

## Performance Benchmarks

### Current Benchmarks

- Configuration parsing: < 0.100s
- Plugin execution: < 0.500s
- JSON processing: < 0.050s
- Memory usage: < 10MB during operations
- Parallel speedup: > 2x with 4 jobs

### Monitoring Performance

Performance tests track:

- Execution time trends
- Memory usage patterns
- CPU utilization
- I/O performance
- Network latency

## Security Testing

### Security Test Coverage

- Input validation
- Configuration security
- Permission handling
- Network security
- Data sanitization
- Injection prevention

### Security Benchmarks

- All security tests must pass
- No sensitive data in logs
- Proper permission handling
- Secure configuration defaults
- Network communication security

---

For more information, see the individual test files and the main ServerSentry documentation.
