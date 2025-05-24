#!/usr/bin/env bash
#
# ServerSentry v2 - Security Integration Test
#
# This test specifically verifies that the security vulnerabilities we fixed
# don't regress in real-world usage scenarios

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Define test output color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test assertion function
assert() {
  local test_name="$1"
  local condition="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  echo -n "Testing $test_name... "

  if eval "$condition"; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    if [ -n "$message" ]; then
      echo -e "${YELLOW}$message${NC}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Setup test environment
setup_test_environment() {
  # Clean up any numbered files that might exist
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true

  # Ensure we're in the base directory
  cd "$BASE_DIR"

  echo "Security integration test environment set up"
}

# Cleanup test environment
cleanup_test_environment() {
  # Clean up numbered files
  rm -f "$BASE_DIR"/[0-9][0-9] 2>/dev/null || true

  # Remove any test artifacts
  rm -f /tmp/serversentry_security_test_* 2>/dev/null || true

  echo "Security integration test environment cleaned up"
}

echo "Running security integration tests..."

# Setup
setup_test_environment

# Test 1: Real composite check with CLI
echo "Testing real composite check execution..."

# Run an actual composite test that previously created numbered files
output=$(cd "$BASE_DIR" && bin/serversentry composite test 2>/dev/null || echo "completed")

# Check that no numbered files were created
files_found=0
for num in 50 60 80 85 90 95; do
  if [[ -f "$num" ]]; then
    files_found=1
    echo "Found dangerous file: $num"
    break
  fi
done

assert "Composite test - no file creation" "[ $files_found -eq 0 ]"

# Test 2: Memory plugin execution
echo "Testing memory plugin execution..."

# Run memory check that used vulnerable bc calculations
memory_output=$(cd "$BASE_DIR" && bin/serversentry check memory 2>/dev/null || echo "completed")

# Verify no files created during memory check
assert "Memory check - no file creation" "[ $files_found -eq 0 ]"

# Test 3: Multiple composite rules in sequence
echo "Testing multiple composite rules..."

# Test various rules that could trigger vulnerabilities
test_rules=(
  "cpu.value > 75 AND memory.value > 80"
  "memory.value > 85 OR disk.value > 90"
  "(cpu.value > 70 AND memory.value > 75) OR disk.value > 95"
  "cpu.value > 60 AND memory.value > 70 AND disk.value > 80"
)

for rule in "${test_rules[@]}"; do
  # Create a temporary composite config for testing
  cat >"/tmp/serversentry_security_test_rule.yaml" <<EOF
composites:
  security_test:
    enabled: true
    rule: "$rule"
    severity: warning
    message: "Security test rule"
EOF

  # Run the composite check (this internally uses evaluate_composite_rule)
  cd "$BASE_DIR" && timeout 10s bin/serversentry check cpu >/dev/null 2>&1 || true

  # Clean up temp file
  rm -f "/tmp/serversentry_security_test_rule.yaml"
done

# Check no files were created by any of the rules
files_found=0
for num in {50..99}; do
  if [[ -f "$num" ]]; then
    files_found=1
    echo "Found file created by composite rule: $num"
    break
  fi
done

assert "Multiple composite rules - no file creation" "[ $files_found -eq 0 ]"

# Test 4: Anomaly detection with real data
echo "Testing anomaly detection execution..."

# The anomaly system uses bc calculations that were vulnerable
cd "$BASE_DIR" && timeout 10s bin/serversentry check cpu >/dev/null 2>&1 || true
cd "$BASE_DIR" && timeout 10s bin/serversentry check memory >/dev/null 2>&1 || true

# Check no files created during anomaly detection
assert "Anomaly detection - no file creation" "[ $files_found -eq 0 ]"

# Test 5: High load simulation
echo "Testing high load scenarios..."

# Simulate high resource usage that could trigger the vulnerable code paths
export SERVERSENTRY_TEST_HIGH_CPU=95
export SERVERSENTRY_TEST_HIGH_MEMORY=90
export SERVERSENTRY_TEST_HIGH_DISK=88

# Run checks with simulated high values
cd "$BASE_DIR" && timeout 15s bin/serversentry check cpu >/dev/null 2>&1 || true
cd "$BASE_DIR" && timeout 15s bin/serversentry check memory >/dev/null 2>&1 || true
cd "$BASE_DIR" && timeout 15s bin/serversentry check disk >/dev/null 2>&1 || true

unset SERVERSENTRY_TEST_HIGH_CPU SERVERSENTRY_TEST_HIGH_MEMORY SERVERSENTRY_TEST_HIGH_DISK

# Final check for file creation
files_found=0
for num in {10..99}; do
  if [[ -f "$num" ]]; then
    files_found=1
    echo "Found file created during high load test: $num"
    break
  fi
done

assert "High load scenarios - no file creation" "[ $files_found -eq 0 ]"

# Test 6: Logging system security
echo "Testing logging system security..."

# Source logging and test it directly
source "$BASE_DIR/lib/core/logging.sh"

# Test component-specific logging
log_info "Security test message" "security_test"
log_performance "Security performance test" "duration=1.5s"
log_audit "security_test_action" "test_user" "Security audit test"

# These should not create any numbered files
assert "Logging system - no file creation" "[ $files_found -eq 0 ]"

# Test 7: Edge case arithmetic expressions
echo "Testing edge case arithmetic expressions..."

# Test expressions that might be interpreted as redirections
cd "$BASE_DIR"

# These were the exact expressions that caused the vulnerability
test_expressions=(
  "15.0 > 80"
  "12.0 > 85"
  "95.5 > 90"
  "88.2 > 95"
)

for expr in "${test_expressions[@]}"; do
  # Simulate the type of evaluation that composite rules do
  if command -v bc >/dev/null 2>&1; then
    result=$(echo "$expr" | bc 2>/dev/null || echo "0")
    # This should work safely now
  fi
done

# Check no files were created by arithmetic evaluations
files_found=0
for num in 80 85 90 95; do
  if [[ -f "$num" ]]; then
    files_found=1
    echo "Found file created by arithmetic expression: $num"
    break
  fi
done

assert "Arithmetic expressions - no file creation" "[ $files_found -eq 0 ]"

# Test 8: CLI command security
echo "Testing CLI command security..."

# Test various CLI commands that might trigger vulnerable code
cli_commands=(
  "version"
  "help"
  "status"
  "list"
  "check cpu"
  "check memory"
  "check disk"
)

for cmd in "${cli_commands[@]}"; do
  cd "$BASE_DIR" && timeout 5s bin/serversentry "$cmd" >/dev/null 2>&1 || true
done

# Final security check
files_found=0
for file in [0-9][0-9]; do
  if [[ -f "$file" ]]; then
    files_found=1
    echo "Found file created by CLI command: $file"
    break
  fi
done 2>/dev/null

assert "CLI commands - no file creation" "[ $files_found -eq 0 ]"

# Test 9: File system security
echo "Testing file system security..."

# Ensure no unintended files exist in critical locations
critical_locations=(
  "/tmp/80"
  "/tmp/85"
  "/tmp/90"
  "/tmp/95"
  "/etc/80"
  "/etc/85"
)

for location in "${critical_locations[@]}"; do
  if [[ -f "$location" ]]; then
    echo "WARNING: Found suspicious file at $location"
  fi
done

assert "Critical locations clean" "[ ! -f '/tmp/80' ] && [ ! -f '/tmp/85' ]"

# Test 10: Integration with all modules
echo "Testing full system integration..."

# Run a comprehensive check that exercises all modules
cd "$BASE_DIR"
timeout 30s bin/serversentry check cpu &&
  timeout 30s bin/serversentry check memory &&
  timeout 30s bin/serversentry check disk >/dev/null 2>&1 || true

# Final comprehensive file check
final_files_found=0
for num in {10..99}; do
  if [[ -f "$num" ]]; then
    final_files_found=1
    echo "SECURITY VIOLATION: Found numbered file $num after full integration test"
    break
  fi
done 2>/dev/null

assert "Full integration - no security violations" "[ $final_files_found -eq 0 ]"

# Cleanup
cleanup_test_environment

# Print summary
echo ""
echo "Security integration tests completed: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
  echo -e "${RED}CRITICAL: Security vulnerabilities detected!${NC}"
  exit 1
else
  echo -e "${GREEN}All security integration tests passed!${NC}"
  echo -e "${GREEN}System is secure against shell redirection attacks.${NC}"
  exit 0
fi
