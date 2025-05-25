#!/usr/bin/env bash
#
# ServerSentry v2 - Array Utils Tests
#
# Comprehensive test suite for lib/core/utils/array_utils.sh

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# Source the test framework
source "$SCRIPT_DIR/../test_framework.sh"

# Source required modules
source "${BASE_DIR}/lib/core/utils/array_utils.sh"
source "${BASE_DIR}/lib/core/logging.sh"

# Test configuration
TEST_SUITE_NAME="Array Utilities Tests"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# === HELPER FUNCTIONS FOR TESTING ===

test_pass() {
  local message="$1"
  print_success "$message"
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
}

test_fail() {
  local message="$1"
  print_error "$message"
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
}

# Setup function
setup_array_utils_tests() {
  setup_test_environment "array_utils_test"
  cleanup_mocks
}

# Cleanup function
cleanup_array_utils_tests() {
  cleanup_test_environment
}

# === ARRAY CREATION AND MANIPULATION TESTS ===

# Test 1: util_array_create - Basic array creation
test_util_array_create_basic() {
  setup_array_utils_tests

  # Test creating array with basic elements
  local test_array
  util_array_create test_array "item1" "item2" "item3"

  if assert_equals "3" "${#test_array[@]}" "Array should have 3 elements" &&
    assert_equals "item1" "${test_array[0]}" "First element should be item1" &&
    assert_equals "item2" "${test_array[1]}" "Second element should be item2" &&
    assert_equals "item3" "${test_array[2]}" "Third element should be item3"; then
    test_pass "util_array_create creates basic arrays correctly"
  else
    test_fail "util_array_create failed with basic elements"
  fi

  cleanup_array_utils_tests
}

# Test 2: util_array_create - Empty array
test_util_array_create_empty() {
  setup_array_utils_tests

  local test_array
  util_array_create test_array

  if assert_equals "0" "${#test_array[@]}" "Empty array should have 0 elements"; then
    test_pass "util_array_create creates empty arrays correctly"
  else
    test_fail "util_array_create failed with empty array"
  fi

  cleanup_array_utils_tests
}

# Test 3: util_array_create - Array with special characters
test_util_array_create_special_chars() {
  setup_array_utils_tests

  local test_array
  util_array_create test_array "item with spaces" "item@#$%^&*()" "item\"with\"quotes" "item'with'quotes"

  if assert_equals "4" "${#test_array[@]}" "Array should have 4 elements" &&
    assert_equals "item with spaces" "${test_array[0]}" "First element with spaces" &&
    assert_equals "item@#$%^&*()" "${test_array[1]}" "Second element with special chars" &&
    assert_equals "item\"with\"quotes" "${test_array[2]}" "Third element with double quotes" &&
    assert_equals "item'with'quotes" "${test_array[3]}" "Fourth element with single quotes"; then
    test_pass "util_array_create handles special characters correctly"
  else
    test_fail "util_array_create failed with special characters"
  fi

  cleanup_array_utils_tests
}

# Test 4: util_array_push - Adding elements to array
test_util_array_push_basic() {
  setup_array_utils_tests

  local test_array=("initial1" "initial2")
  util_array_push test_array "new1" "new2"

  if assert_equals "4" "${#test_array[@]}" "Array should have 4 elements after push" &&
    assert_equals "initial1" "${test_array[0]}" "First original element preserved" &&
    assert_equals "initial2" "${test_array[1]}" "Second original element preserved" &&
    assert_equals "new1" "${test_array[2]}" "First new element added" &&
    assert_equals "new2" "${test_array[3]}" "Second new element added"; then
    test_pass "util_array_push adds elements correctly"
  else
    test_fail "util_array_push failed to add elements"
  fi

  cleanup_array_utils_tests
}

# Test 5: util_array_push - Adding to empty array
test_util_array_push_empty() {
  setup_array_utils_tests

  local test_array=()
  util_array_push test_array "first" "second"

  if assert_equals "2" "${#test_array[@]}" "Array should have 2 elements" &&
    assert_equals "first" "${test_array[0]}" "First element should be 'first'" &&
    assert_equals "second" "${test_array[1]}" "Second element should be 'second'"; then
    test_pass "util_array_push works with empty arrays"
  else
    test_fail "util_array_push failed with empty array"
  fi

  cleanup_array_utils_tests
}

# Test 6: util_array_pop - Removing last element
test_util_array_pop_basic() {
  setup_array_utils_tests

  local test_array=("item1" "item2" "item3")
  local popped_value

  popped_value=$(util_array_pop test_array)

  if assert_equals "2" "${#test_array[@]}" "Array should have 2 elements after pop" &&
    assert_equals "item3" "$popped_value" "Popped value should be last element" &&
    assert_equals "item1" "${test_array[0]}" "First element should remain" &&
    assert_equals "item2" "${test_array[1]}" "Second element should remain"; then
    test_pass "util_array_pop removes and returns last element correctly"
  else
    test_fail "util_array_pop failed: array size=${#test_array[@]}, popped='$popped_value'"
  fi

  cleanup_array_utils_tests
}

# Test 7: util_array_pop - Empty array
test_util_array_pop_empty() {
  setup_array_utils_tests

  local test_array=()
  local popped_value

  popped_value=$(util_array_pop test_array)

  if assert_equals "0" "${#test_array[@]}" "Array should remain empty" &&
    assert_equals "" "$popped_value" "Popped value should be empty"; then
    test_pass "util_array_pop handles empty arrays gracefully"
  else
    test_fail "util_array_pop failed with empty array"
  fi

  cleanup_array_utils_tests
}

# Test 8: util_array_shift - Removing first element
test_util_array_shift_basic() {
  setup_array_utils_tests

  local test_array=("item1" "item2" "item3")
  local shifted_value

  shifted_value=$(util_array_shift test_array)

  if assert_equals "2" "${#test_array[@]}" "Array should have 2 elements after shift" &&
    assert_equals "item1" "$shifted_value" "Shifted value should be first element" &&
    assert_equals "item2" "${test_array[0]}" "Second element should become first" &&
    assert_equals "item3" "${test_array[1]}" "Third element should become second"; then
    test_pass "util_array_shift removes and returns first element correctly"
  else
    test_fail "util_array_shift failed: array size=${#test_array[@]}, shifted='$shifted_value'"
  fi

  cleanup_array_utils_tests
}

# Test 9: util_array_unshift - Adding to beginning
test_util_array_unshift_basic() {
  setup_array_utils_tests

  local test_array=("item2" "item3")
  util_array_unshift test_array "item1" "item0"

  if assert_equals "4" "${#test_array[@]}" "Array should have 4 elements after unshift" &&
    assert_equals "item1" "${test_array[0]}" "First new element at beginning" &&
    assert_equals "item0" "${test_array[1]}" "Second new element" &&
    assert_equals "item2" "${test_array[2]}" "First original element shifted" &&
    assert_equals "item3" "${test_array[3]}" "Second original element shifted"; then
    test_pass "util_array_unshift adds elements to beginning correctly"
  else
    test_fail "util_array_unshift failed to add elements to beginning"
  fi

  cleanup_array_utils_tests
}

# Test 10: util_array_contains - Element existence check
test_util_array_contains_basic() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry" "date")

  if util_array_contains test_array "banana" &&
    util_array_contains test_array "apple" &&
    util_array_contains test_array "date" &&
    ! util_array_contains test_array "grape" &&
    ! util_array_contains test_array ""; then
    test_pass "util_array_contains checks element existence correctly"
  else
    test_fail "util_array_contains failed element existence checks"
  fi

  cleanup_array_utils_tests
}

# Test 11: util_array_contains - Case sensitivity
test_util_array_contains_case_sensitive() {
  setup_array_utils_tests

  local test_array=("Apple" "BANANA" "cherry")

  if util_array_contains test_array "Apple" &&
    util_array_contains test_array "BANANA" &&
    ! util_array_contains test_array "apple" &&
    ! util_array_contains test_array "banana" &&
    ! util_array_contains test_array "CHERRY"; then
    test_pass "util_array_contains is case sensitive"
  else
    test_fail "util_array_contains case sensitivity failed"
  fi

  cleanup_array_utils_tests
}

# Test 12: util_array_contains - Special characters
test_util_array_contains_special_chars() {
  setup_array_utils_tests

  local test_array=("item with spaces" "item@#$%" "item\"quotes\"" "item'quotes'")

  if util_array_contains test_array "item with spaces" &&
    util_array_contains test_array "item@#$%" &&
    util_array_contains test_array "item\"quotes\"" &&
    util_array_contains test_array "item'quotes'" &&
    ! util_array_contains test_array "item with  spaces"; then
    test_pass "util_array_contains handles special characters correctly"
  else
    test_fail "util_array_contains failed with special characters"
  fi

  cleanup_array_utils_tests
}

# Test 13: util_array_index_of - Finding element index
test_util_array_index_of_basic() {
  setup_array_utils_tests

  local test_array=("zero" "one" "two" "three" "two")
  local index

  index=$(util_array_index_of test_array "one")
  if assert_equals "1" "$index" "Index of 'one' should be 1"; then
    test_pass "util_array_index_of finds correct index"
  else
    test_fail "util_array_index_of failed: expected 1, got $index"
  fi

  # Test first occurrence of duplicate
  index=$(util_array_index_of test_array "two")
  if assert_equals "2" "$index" "Index of first 'two' should be 2"; then
    test_pass "util_array_index_of finds first occurrence of duplicates"
  else
    test_fail "util_array_index_of duplicate handling failed: expected 2, got $index"
  fi

  # Test non-existent element
  index=$(util_array_index_of test_array "nonexistent")
  if assert_equals "-1" "$index" "Index of non-existent element should be -1"; then
    test_pass "util_array_index_of returns -1 for non-existent elements"
  else
    test_fail "util_array_index_of non-existent handling failed: expected -1, got $index"
  fi

  cleanup_array_utils_tests
}

# Test 14: util_array_remove - Removing elements by value
test_util_array_remove_basic() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry" "banana" "date")
  util_array_remove test_array "banana"

  if assert_equals "3" "${#test_array[@]}" "Array should have 3 elements after removal" &&
    assert_equals "apple" "${test_array[0]}" "First element preserved" &&
    assert_equals "cherry" "${test_array[1]}" "Third element becomes second" &&
    assert_equals "date" "${test_array[2]}" "Last element preserved"; then
    test_pass "util_array_remove removes first occurrence correctly"
  else
    test_fail "util_array_remove failed to remove element correctly"
  fi

  cleanup_array_utils_tests
}

# Test 15: util_array_remove - Non-existent element
test_util_array_remove_nonexistent() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry")
  local original_size=${#test_array[@]}

  util_array_remove test_array "grape"

  if assert_equals "$original_size" "${#test_array[@]}" "Array size should remain unchanged" &&
    assert_equals "apple" "${test_array[0]}" "Elements should remain unchanged" &&
    assert_equals "banana" "${test_array[1]}" "Elements should remain unchanged" &&
    assert_equals "cherry" "${test_array[2]}" "Elements should remain unchanged"; then
    test_pass "util_array_remove handles non-existent elements gracefully"
  else
    test_fail "util_array_remove failed with non-existent element"
  fi

  cleanup_array_utils_tests
}

# Test 16: util_array_remove_all - Removing all occurrences
test_util_array_remove_all_basic() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry" "banana" "date" "banana")
  util_array_remove_all test_array "banana"

  if assert_equals "3" "${#test_array[@]}" "Array should have 3 elements after removing all bananas" &&
    assert_equals "apple" "${test_array[0]}" "First element preserved" &&
    assert_equals "cherry" "${test_array[1]}" "Second non-banana element" &&
    assert_equals "date" "${test_array[2]}" "Third non-banana element"; then
    test_pass "util_array_remove_all removes all occurrences correctly"
  else
    test_fail "util_array_remove_all failed to remove all occurrences"
  fi

  cleanup_array_utils_tests
}

# Test 17: util_array_slice - Extracting subarray
test_util_array_slice_basic() {
  setup_array_utils_tests

  local test_array=("zero" "one" "two" "three" "four" "five")
  local slice_result

  # Test normal slice
  util_array_slice test_array slice_result 1 3

  if assert_equals "3" "${#slice_result[@]}" "Slice should have 3 elements" &&
    assert_equals "one" "${slice_result[0]}" "First slice element" &&
    assert_equals "two" "${slice_result[1]}" "Second slice element" &&
    assert_equals "three" "${slice_result[2]}" "Third slice element"; then
    test_pass "util_array_slice extracts subarray correctly"
  else
    test_fail "util_array_slice failed: slice size=${#slice_result[@]}"
  fi

  cleanup_array_utils_tests
}

# Test 18: util_array_slice - Edge cases
test_util_array_slice_edge_cases() {
  setup_array_utils_tests

  local test_array=("zero" "one" "two" "three" "four")
  local slice_result

  # Test slice from beginning
  util_array_slice test_array slice_result 0 2
  if assert_equals "2" "${#slice_result[@]}" "Beginning slice should have 2 elements" &&
    assert_equals "zero" "${slice_result[0]}" "First element of beginning slice"; then
    test_pass "util_array_slice works from beginning"
  else
    test_fail "util_array_slice failed from beginning"
  fi

  # Test slice to end
  util_array_slice test_array slice_result 3
  if assert_equals "2" "${#slice_result[@]}" "End slice should have 2 elements" &&
    assert_equals "three" "${slice_result[0]}" "First element of end slice" &&
    assert_equals "four" "${slice_result[1]}" "Second element of end slice"; then
    test_pass "util_array_slice works to end"
  else
    test_fail "util_array_slice failed to end"
  fi

  cleanup_array_utils_tests
}

# Test 19: util_array_join - Joining array elements
test_util_array_join_basic() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry")
  local joined_result

  # Test with comma separator
  joined_result=$(util_array_join test_array ",")
  if assert_equals "apple,banana,cherry" "$joined_result" "Comma join should work"; then
    test_pass "util_array_join works with comma separator"
  else
    test_fail "util_array_join failed with comma: got '$joined_result'"
  fi

  # Test with space separator
  joined_result=$(util_array_join test_array " ")
  if assert_equals "apple banana cherry" "$joined_result" "Space join should work"; then
    test_pass "util_array_join works with space separator"
  else
    test_fail "util_array_join failed with space: got '$joined_result'"
  fi

  # Test with custom separator
  joined_result=$(util_array_join test_array " | ")
  if assert_equals "apple | banana | cherry" "$joined_result" "Custom separator should work"; then
    test_pass "util_array_join works with custom separator"
  else
    test_fail "util_array_join failed with custom separator: got '$joined_result'"
  fi

  cleanup_array_utils_tests
}

# Test 20: util_array_join - Empty array and single element
test_util_array_join_edge_cases() {
  setup_array_utils_tests

  # Test empty array
  local empty_array=()
  local joined_result
  joined_result=$(util_array_join empty_array ",")
  if assert_equals "" "$joined_result" "Empty array join should return empty string"; then
    test_pass "util_array_join handles empty arrays correctly"
  else
    test_fail "util_array_join failed with empty array: got '$joined_result'"
  fi

  # Test single element
  local single_array=("onlyone")
  joined_result=$(util_array_join single_array ",")
  if assert_equals "onlyone" "$joined_result" "Single element join should return element"; then
    test_pass "util_array_join handles single elements correctly"
  else
    test_fail "util_array_join failed with single element: got '$joined_result'"
  fi

  cleanup_array_utils_tests
}

# Test 21: util_array_split - Splitting string into array
test_util_array_split_basic() {
  setup_array_utils_tests

  local result_array
  util_array_split "apple,banana,cherry" "," result_array

  if assert_equals "3" "${#result_array[@]}" "Split should create 3 elements" &&
    assert_equals "apple" "${result_array[0]}" "First split element" &&
    assert_equals "banana" "${result_array[1]}" "Second split element" &&
    assert_equals "cherry" "${result_array[2]}" "Third split element"; then
    test_pass "util_array_split works with comma delimiter"
  else
    test_fail "util_array_split failed with comma delimiter"
  fi

  cleanup_array_utils_tests
}

# Test 22: util_array_split - Different delimiters
test_util_array_split_delimiters() {
  setup_array_utils_tests

  local result_array

  # Test with space delimiter
  util_array_split "apple banana cherry" " " result_array
  if assert_equals "3" "${#result_array[@]}" "Space split should create 3 elements" &&
    assert_equals "apple" "${result_array[0]}" "First space split element"; then
    test_pass "util_array_split works with space delimiter"
  else
    test_fail "util_array_split failed with space delimiter"
  fi

  # Test with pipe delimiter
  util_array_split "apple|banana|cherry" "|" result_array
  if assert_equals "3" "${#result_array[@]}" "Pipe split should create 3 elements" &&
    assert_equals "apple" "${result_array[0]}" "First pipe split element"; then
    test_pass "util_array_split works with pipe delimiter"
  else
    test_fail "util_array_split failed with pipe delimiter"
  fi

  cleanup_array_utils_tests
}

# Test 23: util_array_reverse - Reversing array order
test_util_array_reverse_basic() {
  setup_array_utils_tests

  local test_array=("first" "second" "third" "fourth")
  util_array_reverse test_array

  if assert_equals "4" "${#test_array[@]}" "Array size should remain same" &&
    assert_equals "fourth" "${test_array[0]}" "Last becomes first" &&
    assert_equals "third" "${test_array[1]}" "Third becomes second" &&
    assert_equals "second" "${test_array[2]}" "Second becomes third" &&
    assert_equals "first" "${test_array[3]}" "First becomes last"; then
    test_pass "util_array_reverse reverses array correctly"
  else
    test_fail "util_array_reverse failed to reverse array"
  fi

  cleanup_array_utils_tests
}

# Test 24: util_array_reverse - Edge cases
test_util_array_reverse_edge_cases() {
  setup_array_utils_tests

  # Test empty array
  local empty_array=()
  util_array_reverse empty_array
  if assert_equals "0" "${#empty_array[@]}" "Empty array should remain empty"; then
    test_pass "util_array_reverse handles empty arrays"
  else
    test_fail "util_array_reverse failed with empty array"
  fi

  # Test single element
  local single_array=("only")
  util_array_reverse single_array
  if assert_equals "1" "${#single_array[@]}" "Single array should remain size 1" &&
    assert_equals "only" "${single_array[0]}" "Single element should remain unchanged"; then
    test_pass "util_array_reverse handles single element arrays"
  else
    test_fail "util_array_reverse failed with single element"
  fi

  cleanup_array_utils_tests
}

# Test 25: util_array_sort - Sorting array elements
test_util_array_sort_basic() {
  setup_array_utils_tests

  local test_array=("cherry" "apple" "banana" "date")
  util_array_sort test_array

  if assert_equals "4" "${#test_array[@]}" "Array size should remain same" &&
    assert_equals "apple" "${test_array[0]}" "First alphabetically" &&
    assert_equals "banana" "${test_array[1]}" "Second alphabetically" &&
    assert_equals "cherry" "${test_array[2]}" "Third alphabetically" &&
    assert_equals "date" "${test_array[3]}" "Fourth alphabetically"; then
    test_pass "util_array_sort sorts alphabetically"
  else
    test_fail "util_array_sort failed alphabetical sort"
  fi

  cleanup_array_utils_tests
}

# Test 26: util_array_sort - Numeric sorting
test_util_array_sort_numeric() {
  setup_array_utils_tests

  local test_array=("10" "2" "30" "1" "20")
  util_array_sort test_array "numeric"

  if assert_equals "5" "${#test_array[@]}" "Array size should remain same" &&
    assert_equals "1" "${test_array[0]}" "Smallest number first" &&
    assert_equals "2" "${test_array[1]}" "Second smallest" &&
    assert_equals "10" "${test_array[2]}" "Third in numeric order" &&
    assert_equals "20" "${test_array[3]}" "Fourth in numeric order" &&
    assert_equals "30" "${test_array[4]}" "Largest number last"; then
    test_pass "util_array_sort sorts numerically"
  else
    test_fail "util_array_sort failed numeric sort"
  fi

  cleanup_array_utils_tests
}

# Test 27: util_array_unique - Removing duplicates
test_util_array_unique_basic() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "apple" "cherry" "banana" "date")
  util_array_unique test_array

  if assert_equals "4" "${#test_array[@]}" "Array should have 4 unique elements" &&
    util_array_contains test_array "apple" &&
    util_array_contains test_array "banana" &&
    util_array_contains test_array "cherry" &&
    util_array_contains test_array "date"; then
    test_pass "util_array_unique removes duplicates correctly"
  else
    test_fail "util_array_unique failed to remove duplicates"
  fi

  cleanup_array_utils_tests
}

# Test 28: util_array_unique - No duplicates
test_util_array_unique_no_duplicates() {
  setup_array_utils_tests

  local test_array=("apple" "banana" "cherry")
  local original_size=${#test_array[@]}

  util_array_unique test_array

  if assert_equals "$original_size" "${#test_array[@]}" "Array size should remain unchanged" &&
    assert_equals "apple" "${test_array[0]}" "Elements should remain unchanged" &&
    assert_equals "banana" "${test_array[1]}" "Elements should remain unchanged" &&
    assert_equals "cherry" "${test_array[2]}" "Elements should remain unchanged"; then
    test_pass "util_array_unique handles arrays without duplicates"
  else
    test_fail "util_array_unique failed with no duplicates"
  fi

  cleanup_array_utils_tests
}

# Test 29: util_array_filter - Filtering with callback
test_util_array_filter_basic() {
  setup_array_utils_tests

  # Create a filter function for testing
  filter_starts_with_a() {
    [[ "$1" == a* ]]
  }

  local test_array=("apple" "banana" "apricot" "cherry" "avocado")
  local filtered_array

  util_array_filter test_array filtered_array filter_starts_with_a

  if assert_equals "3" "${#filtered_array[@]}" "Filtered array should have 3 elements" &&
    assert_equals "apple" "${filtered_array[0]}" "First filtered element" &&
    assert_equals "apricot" "${filtered_array[1]}" "Second filtered element" &&
    assert_equals "avocado" "${filtered_array[2]}" "Third filtered element"; then
    test_pass "util_array_filter filters with callback correctly"
  else
    test_fail "util_array_filter failed with callback"
  fi

  cleanup_array_utils_tests
}

# Test 30: util_array_map - Transforming elements
test_util_array_map_basic() {
  setup_array_utils_tests

  # Create a map function for testing
  map_to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
  }

  local test_array=("apple" "banana" "cherry")
  local mapped_array

  util_array_map test_array mapped_array map_to_uppercase

  if assert_equals "3" "${#mapped_array[@]}" "Mapped array should have 3 elements" &&
    assert_equals "APPLE" "${mapped_array[0]}" "First mapped element" &&
    assert_equals "BANANA" "${mapped_array[1]}" "Second mapped element" &&
    assert_equals "CHERRY" "${mapped_array[2]}" "Third mapped element"; then
    test_pass "util_array_map transforms elements correctly"
  else
    test_fail "util_array_map failed transformation"
  fi

  cleanup_array_utils_tests
}

# Test 31: Performance test - Large array operations
test_util_array_performance_large() {
  setup_array_utils_tests

  # Create large array
  local large_array=()
  for i in {1..1000}; do
    large_array+=("item_$i")
  done

  measure_execution_time util_array_contains large_array "item_500"

  if assert_execution_time_under "1" "Large array contains should complete within 1 second"; then
    test_pass "util_array_contains performs well with large arrays"
  else
    test_fail "util_array_contains performance issue: ${MEASURED_TIME}s"
  fi

  # Test sorting performance
  measure_execution_time util_array_sort large_array

  if assert_execution_time_under "2" "Large array sort should complete within 2 seconds"; then
    test_pass "util_array_sort performs well with large arrays"
  else
    test_fail "util_array_sort performance issue: ${MEASURED_TIME}s"
  fi

  cleanup_array_utils_tests
}

# Test 32: Edge cases and error conditions
test_util_array_edge_cases() {
  setup_array_utils_tests

  # Test with arrays containing empty strings
  local test_array=("" "nonempty" "" "another")

  if util_array_contains test_array "" &&
    ! util_array_contains test_array "empty"; then
    test_pass "util_array_contains handles empty strings correctly"
  else
    test_fail "util_array_contains failed with empty strings"
  fi

  # Test with very long strings
  local long_string
  long_string=$(printf 'a%.0s' {1..1000})
  local long_array=("short" "$long_string" "normal")

  if util_array_contains long_array "$long_string"; then
    test_pass "util_array_contains handles very long strings"
  else
    test_fail "util_array_contains failed with long strings"
  fi

  cleanup_array_utils_tests
}

# Test 33: Memory efficiency test
test_util_array_memory_efficiency() {
  setup_array_utils_tests

  # Test multiple operations on same array
  local test_array=("a" "b" "c" "d" "e")

  # Multiple operations that should not cause memory issues
  util_array_push test_array "f" "g"
  util_array_pop test_array
  util_array_reverse test_array
  util_array_sort test_array
  util_array_unique test_array

  if assert_true "[[ ${#test_array[@]} -gt 0 ]]" "Array should still have elements after operations"; then
    test_pass "Multiple array operations work without memory issues"
  else
    test_fail "Memory efficiency test failed"
  fi

  cleanup_array_utils_tests
}

# Test 34: Array operation chaining
test_util_array_operation_chaining() {
  setup_array_utils_tests

  local test_array=("cherry" "apple" "banana" "apple" "date")

  # Chain multiple operations
  util_array_sort test_array
  util_array_unique test_array
  util_array_push test_array "elderberry"

  if assert_equals "5" "${#test_array[@]}" "Chained operations should result in 5 elements" &&
    assert_equals "apple" "${test_array[0]}" "First should be apple (sorted)" &&
    assert_equals "elderberry" "${test_array[4]}" "Last should be elderberry (pushed)"; then
    test_pass "Array operation chaining works correctly"
  else
    test_fail "Array operation chaining failed"
  fi

  cleanup_array_utils_tests
}

# Main test execution
main() {
  log_info "Starting Array Utils comprehensive tests..."

  # Initialize test framework
  init_test_framework

  # Run all tests
  run_test test_util_array_create_basic
  run_test test_util_array_create_empty
  run_test test_util_array_create_special_chars
  run_test test_util_array_push_basic
  run_test test_util_array_push_empty
  run_test test_util_array_pop_basic
  run_test test_util_array_pop_empty
  run_test test_util_array_shift_basic
  run_test test_util_array_unshift_basic
  run_test test_util_array_contains_basic
  run_test test_util_array_contains_case_sensitive
  run_test test_util_array_contains_special_chars
  run_test test_util_array_index_of_basic
  run_test test_util_array_remove_basic
  run_test test_util_array_remove_nonexistent
  run_test test_util_array_remove_all_basic
  run_test test_util_array_slice_basic
  run_test test_util_array_slice_edge_cases
  run_test test_util_array_join_basic
  run_test test_util_array_join_edge_cases
  run_test test_util_array_split_basic
  run_test test_util_array_split_delimiters
  run_test test_util_array_reverse_basic
  run_test test_util_array_reverse_edge_cases
  run_test test_util_array_sort_basic
  run_test test_util_array_sort_numeric
  run_test test_util_array_unique_basic
  run_test test_util_array_unique_no_duplicates
  run_test test_util_array_filter_basic
  run_test test_util_array_map_basic
  run_test test_util_array_performance_large
  run_test test_util_array_edge_cases
  run_test test_util_array_memory_efficiency
  run_test test_util_array_operation_chaining

  # Print results
  print_test_results

  log_info "Array Utils tests completed!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
