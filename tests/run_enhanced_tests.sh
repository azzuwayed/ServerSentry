#!/usr/bin/env bash
#
# ServerSentry v2 - Enhanced Test Runner
#
# Runs all test suites with improved organization, parallel execution,
# and comprehensive reporting

set -e

# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal
  
  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi

# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi


# Load unified test framework
if [[ -f "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh"
fi

    current_dir="$(dirname "$current_dir")"
  done
  
  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi
# Initialize with minimal level for testing
if ! serversentry_init "minimal"; then
  echo "FATAL: Failed to initialize ServerSentry environment" >&2
  exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test framework and helpers using bootstrap paths
source "$SCRIPT_DIR/test_framework.sh"
source "$SCRIPT_DIR/helpers/test_helpers.sh"

# Source standardized color functions using bootstrap
if [[ -f "$SERVERSENTRY_UI_DIR/cli/colors.sh" ]]; then
  source "$SERVERSENTRY_UI_DIR/cli/colors.sh"
fi

# Test configuration
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
GENERATE_COVERAGE="${GENERATE_COVERAGE:-true}"
GENERATE_REPORT="${GENERATE_REPORT:-true}"
PERFORMANCE_TESTS="${PERFORMANCE_TESTS:-true}"
INTEGRATION_TESTS="${INTEGRATION_TESTS:-true}"

# Test results tracking
TOTAL_SUITES=0
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_SUITES=()
SUITE_RESULTS=()

# Test categories
declare -A TEST_CATEGORIES=(
  ["unit"]="Unit Tests"
  ["integration"]="Integration Tests"
  ["performance"]="Performance Tests"
  ["error_handling"]="Error Handling Tests"
  ["security"]="Security Tests"
)

# Function to print usage
print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p, --parallel JOBS     Number of parallel jobs (default: 4)
  -c, --coverage          Generate coverage report (default: true)
  -r, --report            Generate HTML report (default: true)
  --no-performance        Skip performance tests
  --no-integration        Skip integration tests
  --category CATEGORY     Run only specific category (unit|integration|performance|error_handling|security)
  --list                  List available test suites
  -h, --help              Show this help message

Examples:
  $0                      # Run all tests
  $0 --parallel 8         # Run with 8 parallel jobs
  $0 --category unit      # Run only unit tests
  $0 --no-performance     # Skip performance tests
EOF
}

# Function to list available test suites
list_test_suites() {
  echo "Available test suites:"
  echo ""

  for category in "${!TEST_CATEGORIES[@]}"; do
    echo "${TEST_CATEGORIES[$category]}:"

    case "$category" in
    "unit")
      find "$SCRIPT_DIR/unit" -name "*_test.sh" -type f | sort | while read -r test_file; do
        local test_name=$(basename "$test_file" .sh)
        echo "  - $test_name"
      done
      ;;
    "integration")
      find "$SCRIPT_DIR/integration" -name "*_test.sh" -type f | sort | while read -r test_file; do
        local test_name=$(basename "$test_file" .sh)
        echo "  - $test_name"
      done
      ;;
    "performance")
      if [[ -d "$SCRIPT_DIR/performance" ]]; then
        find "$SCRIPT_DIR/performance" -name "*_test.sh" -type f | sort | while read -r test_file; do
          local test_name=$(basename "$test_file" .sh)
          echo "  - $test_name"
        done
      fi
      ;;
    "error_handling")
      if [[ -d "$SCRIPT_DIR/unit/error_handling" ]]; then
        find "$SCRIPT_DIR/unit/error_handling" -name "*_test.sh" -type f | sort | while read -r test_file; do
          local test_name=$(basename "$test_file" .sh)
          echo "  - $test_name"
        done
      fi
      ;;
    "security")
      find "$SCRIPT_DIR/unit" -name "security_test.sh" -type f | sort | while read -r test_file; do
        local test_name=$(basename "$test_file" .sh)
        echo "  - $test_name"
      done
      find "$SCRIPT_DIR/integration" -name "*security*_test.sh" -type f | sort | while read -r test_file; do
        local test_name=$(basename "$test_file" .sh)
        echo "  - $test_name"
      done
      ;;
    esac
    echo ""
  done
}

# Function to collect test files by category
collect_test_files() {
  local category="$1"
  local test_files=()

  case "$category" in
  "unit")
    while IFS= read -r -d '' file; do
      test_files+=("$file")
    done < <(find "$SCRIPT_DIR/unit" -name "*_test.sh" -type f -print0 | sort -z)
    ;;
  "integration")
    if [[ "$INTEGRATION_TESTS" == "true" ]]; then
      while IFS= read -r -d '' file; do
        test_files+=("$file")
      done < <(find "$SCRIPT_DIR/integration" -name "*_test.sh" -type f -print0 | sort -z)
    fi
    ;;
  "performance")
    if [[ "$PERFORMANCE_TESTS" == "true" && -d "$SCRIPT_DIR/performance" ]]; then
      while IFS= read -r -d '' file; do
        test_files+=("$file")
      done < <(find "$SCRIPT_DIR/performance" -name "*_test.sh" -type f -print0 | sort -z)
    fi
    ;;
  "error_handling")
    if [[ -d "$SCRIPT_DIR/unit/error_handling" ]]; then
      while IFS= read -r -d '' file; do
        test_files+=("$file")
      done < <(find "$SCRIPT_DIR/unit/error_handling" -name "*_test.sh" -type f -print0 | sort -z)
    fi
    ;;
  "security")
    # Include both unit and integration security tests
    while IFS= read -r -d '' file; do
      test_files+=("$file")
    done < <(find "$SCRIPT_DIR/unit" "$SCRIPT_DIR/integration" -name "*security*_test.sh" -type f -print0 2>/dev/null | sort -z)
    ;;
  esac

  printf '%s\n' "${test_files[@]}"
}

# Function to run a test suite with enhanced reporting
run_test_suite_enhanced() {
  local test_name="$1"
  local test_script="$2"
  local category="$3"
  local start_time end_time duration

  echo ""
  print_separator 70
  print_header "Running $category: $test_name" 70
  print_separator 70

  if [[ ! -f "$test_script" ]]; then
    print_error "Test script not found: $test_script"
    FAILED_SUITES+=("$test_name (script not found)")
    SUITE_RESULTS+=("$test_name:MISSING:0:0:0:0")
    return 1
  fi

  if [[ ! -x "$test_script" ]]; then
    chmod +x "$test_script"
  fi

  start_time=$(date +%s.%N)
  local test_output
  local exit_code

  # Run the test and capture output
  if test_output=$("$test_script" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  end_time=$(date +%s.%N)
  duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")

  # Parse test results from output
  local tests_run=$(echo "$test_output" | grep -o "Tests.*completed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
  local tests_passed=$(echo "$test_output" | grep -o "Tests passed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
  local tests_failed=$(echo "$test_output" | grep -o "Tests failed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")

  # If no parsed results, try alternative patterns
  if [[ "$tests_run" == "0" ]]; then
    tests_run=$(echo "$test_output" | grep -c "PASS\|FAIL" || echo "1")
    tests_passed=$(echo "$test_output" | grep -c "PASS" || echo "0")
    tests_failed=$(echo "$test_output" | grep -c "FAIL" || echo "0")
  fi

  # Update totals
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
  TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
  TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))

  # Store suite results
  SUITE_RESULTS+=("$test_name:$exit_code:$tests_run:$tests_passed:$tests_failed:$duration")

  # Display results
  if [[ $exit_code -eq 0 ]]; then
    print_success "$test_name PASSED (${tests_run} tests, ${duration}s)"
    if [[ $tests_failed -gt 0 ]]; then
      print_warning "Warning: $tests_failed tests failed but suite passed"
    fi
  else
    print_error "$test_name FAILED (exit code: $exit_code, ${duration}s)"
    FAILED_SUITES+=("$test_name")

    # Show last few lines of output for failed tests
    print_warning "Last few lines of output:"
    echo "$test_output" | tail -10 | sed 's/^/  /'
  fi

  # Show detailed breakdown
  if [[ $tests_run -gt 0 ]]; then
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "   Tests: ${INFO_COLOR}$tests_run${RESET} | Passed: ${SUCCESS_COLOR}$tests_passed${RESET} | Failed: ${ERROR_COLOR}$tests_failed${RESET} | Duration: ${CYAN}${duration}s${RESET}"
    else
      echo "   Tests: $tests_run | Passed: $tests_passed | Failed: $tests_failed | Duration: ${duration}s"
    fi
  fi

  return $exit_code
}

# Function to run tests in parallel by category
run_category_tests() {
  local category="$1"
  local test_files

  print_header "Running ${TEST_CATEGORIES[$category]}" 70

  readarray -t test_files < <(collect_test_files "$category")

  if [[ ${#test_files[@]} -eq 0 ]]; then
    print_warning "No test files found for category: $category"
    return 0
  fi

  print_info "Found ${#test_files[@]} test files in category: $category"

  # Run tests sequentially for now (parallel implementation can be added)
  for test_file in "${test_files[@]}"; do
    local test_name=$(basename "$test_file" .sh)
    run_test_suite_enhanced "$test_name" "$test_file" "${TEST_CATEGORIES[$category]}"
  done
}

# Function to generate HTML report
generate_html_report() {
  local report_file="${SCRIPT_DIR}/reports/test_report_$(date +%Y%m%d_%H%M%S).html"

  mkdir -p "$(dirname "$report_file")"

  cat >"$report_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>ServerSentry Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background-color: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; color: #333; }
        .metric .value { font-size: 2em; font-weight: bold; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .warning { color: #ffc107; }
        .info { color: #17a2b8; }
        .suite-results { margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .status-pass { background-color: #d4edda; color: #155724; }
        .status-fail { background-color: #f8d7da; color: #721c24; }
        .duration { text-align: right; }
        .footer { margin-top: 30px; text-align: center; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ServerSentry Test Report</h1>
            <p>Generated on $(date)</p>
        </div>

        <div class="summary">
            <div class="metric">
                <h3>Total Suites</h3>
                <div class="value info">$TOTAL_SUITES</div>
            </div>
            <div class="metric">
                <h3>Total Tests</h3>
                <div class="value info">$TOTAL_TESTS</div>
            </div>
            <div class="metric">
                <h3>Tests Passed</h3>
                <div class="value passed">$TOTAL_PASSED</div>
            </div>
            <div class="metric">
                <h3>Tests Failed</h3>
                <div class="value failed">$TOTAL_FAILED</div>
            </div>
EOF

  # Calculate success rate
  if [[ $TOTAL_TESTS -gt 0 ]]; then
    local success_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    cat >>"$report_file" <<EOF
            <div class="metric">
                <h3>Success Rate</h3>
                <div class="value $([ $success_rate -ge 90 ] && echo "passed" || echo "warning")">$success_rate%</div>
            </div>
EOF
  fi

  cat >>"$report_file" <<EOF
        </div>

        <div class="suite-results">
            <h2>Test Suite Results</h2>
            <table>
                <thead>
                    <tr>
                        <th>Test Suite</th>
                        <th>Status</th>
                        <th>Tests Run</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Duration (s)</th>
                    </tr>
                </thead>
                <tbody>
EOF

  # Add suite results
  for result in "${SUITE_RESULTS[@]}"; do
    IFS=':' read -r suite_name exit_code tests_run tests_passed tests_failed duration <<<"$result"
    local status_class="status-pass"
    local status_text="PASS"

    if [[ "$exit_code" != "0" ]]; then
      status_class="status-fail"
      status_text="FAIL"
    fi

    cat >>"$report_file" <<EOF
                    <tr>
                        <td>$suite_name</td>
                        <td class="$status_class">$status_text</td>
                        <td>$tests_run</td>
                        <td class="passed">$tests_passed</td>
                        <td class="failed">$tests_failed</td>
                        <td class="duration">$duration</td>
                    </tr>
EOF
  done

  cat >>"$report_file" <<EOF
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p>ServerSentry v2 Test Suite - Generated by Enhanced Test Runner</p>
        </div>
    </div>
</body>
</html>
EOF

  print_success "HTML report generated: $report_file"
}

# Function to print comprehensive summary
print_comprehensive_summary() {
  echo ""
  print_separator 80
  print_header "COMPREHENSIVE TEST SUMMARY REPORT" 80
  print_separator 80

  echo ""
  print_info "Test Execution Summary:"
  if [[ "$COLOR_SUPPORT" == "true" ]]; then
    echo -e "  Total Test Suites: ${INFO_COLOR}$TOTAL_SUITES${RESET}"
    echo -e "  Total Tests: ${INFO_COLOR}$TOTAL_TESTS${RESET}"
    echo -e "  Tests Passed: ${SUCCESS_COLOR}$TOTAL_PASSED${RESET}"
    echo -e "  Tests Failed: ${ERROR_COLOR}$TOTAL_FAILED${RESET}"
  else
    echo "  Total Test Suites: $TOTAL_SUITES"
    echo "  Total Tests: $TOTAL_TESTS"
    echo "  Tests Passed: $TOTAL_PASSED"
    echo "  Tests Failed: $TOTAL_FAILED"
  fi

  if [[ $TOTAL_TESTS -gt 0 ]]; then
    local success_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    if [[ "$COLOR_SUPPORT" == "true" ]]; then
      echo -e "  Success Rate: ${CYAN}${success_rate}%${RESET}"
    else
      echo "  Success Rate: ${success_rate}%"
    fi
  fi

  # Show performance summary if performance tests were run
  if [[ "$PERFORMANCE_TESTS" == "true" ]]; then
    echo ""
    print_info "Performance Test Summary:"
    local total_duration=0
    for result in "${SUITE_RESULTS[@]}"; do
      IFS=':' read -r suite_name exit_code tests_run tests_passed tests_failed duration <<<"$result"
      total_duration=$(awk "BEGIN {printf \"%.3f\", $total_duration + $duration}")
    done
    echo "  Total Execution Time: ${total_duration}s"
  fi

  if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    echo ""
    print_success "🎉 ALL TEST SUITES PASSED! 🎉"
    print_success "ServerSentry v2 is ready for production!"
  else
    echo ""
    print_error "Failed Test Suites:"
    for suite in "${FAILED_SUITES[@]}"; do
      if [[ "$COLOR_SUPPORT" == "true" ]]; then
        echo -e "  ${ERROR_COLOR}• $suite${RESET}"
      else
        echo "  • $suite"
      fi
    done
    echo ""
    print_warning "Please fix the failing tests before deployment."
  fi
}

# Function to check prerequisites
check_prerequisites() {
  print_info "Checking prerequisites..."

  local missing_deps=()

  # Check for required commands
  for cmd in bash jq bc awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_error "Missing required dependencies:"
    for dep in "${missing_deps[@]}"; do
      if [[ "$COLOR_SUPPORT" == "true" ]]; then
        echo -e "  ${ERROR_COLOR}• $dep${RESET}"
      else
        echo "  • $dep"
      fi
    done
    print_warning "Please install missing dependencies and try again."
    return 1
  fi

  print_success "All prerequisites satisfied"
  return 0
}

# Function to setup test environment

# Main function
main() {
  local category=""
  local list_only=false

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -p | --parallel)
      PARALLEL_JOBS="$2"
      shift 2
      ;;
    -c | --coverage)
      GENERATE_COVERAGE="true"
      shift
      ;;
    -r | --report)
      GENERATE_REPORT="true"
      shift
      ;;
    --no-performance)
      PERFORMANCE_TESTS="false"
      shift
      ;;
    --no-integration)
      INTEGRATION_TESTS="false"
      shift
      ;;
    --category)
      category="$2"
      shift 2
      ;;
    --list)
      list_only=true
      shift
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
    esac
  done

  # List test suites if requested
  if [[ "$list_only" == "true" ]]; then
    list_test_suites
    exit 0
  fi

  # Validate category if specified
  if [[ -n "$category" && ! "${TEST_CATEGORIES[$category]+isset}" ]]; then
    print_error "Invalid category: $category"
    echo "Valid categories: ${!TEST_CATEGORIES[*]}"
    exit 1
  fi

  print_header "ServerSentry v2 Enhanced Test Runner" 80
  print_info "Parallel jobs: $PARALLEL_JOBS"
  print_info "Generate coverage: $GENERATE_COVERAGE"
  print_info "Generate report: $GENERATE_REPORT"
  print_info "Performance tests: $PERFORMANCE_TESTS"
  print_info "Integration tests: $INTEGRATION_TESTS"

  # Check prerequisites
  if ! check_prerequisites; then
    exit 1
  fi

  # Setup test environment
  setup_test_environment

  # Run tests
  if [[ -n "$category" ]]; then
    # Run specific category
    run_category_tests "$category"
  else
    # Run all categories
    for cat in unit integration performance error_handling security; do
      if [[ "$cat" == "performance" && "$PERFORMANCE_TESTS" != "true" ]]; then
        continue
      fi
      if [[ "$cat" == "integration" && "$INTEGRATION_TESTS" != "true" ]]; then
        continue
      fi
      if [[ "${TEST_CATEGORIES[$cat]+isset}" ]]; then
        run_category_tests "$cat"
      fi
    done
  fi

  # Generate reports
  if [[ "$GENERATE_COVERAGE" == "true" ]]; then
    generate_coverage_report || true
  fi

  if [[ "$GENERATE_REPORT" == "true" ]]; then
    generate_html_report
  fi

  # Print comprehensive summary
  print_comprehensive_summary

  # Exit with appropriate code
  if [[ ${#FAILED_SUITES[@]} -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
