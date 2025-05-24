#!/bin/bash
#
# ServerSentry v2 - Array Utilities
#
# This module provides standardized array manipulation functions used throughout the application

# Function: util_array_contains
# Description: Check if an array contains a specific value
# Parameters:
#   $1 - needle (value to search for)
#   $@ - haystack (array elements)
# Returns:
#   0 - value found in array
#   1 - value not found in array
util_array_contains() {
  local needle="$1"
  shift
  local haystack=("$@")

  for item in "${haystack[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

# Function: util_array_add_unique
# Description: Add a value to an array if it doesn't already exist
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - value to add
# Returns:
#   0 - value added or already exists
#   1 - error
util_array_add_unique() {
  local array_name="$1"
  local value="$2"

  # Get current array elements using eval for bash 3.x compatibility
  local current_array
  eval "current_array=(\"\${${array_name}[@]}\")"

  if ! util_array_contains "$value" "${current_array[@]}"; then
    eval "${array_name}+=(\"\$value\")"
  fi

  return 0
}

# Function: util_array_remove
# Description: Remove a value from an array
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - value to remove
# Returns:
#   0 - success (whether value was found or not)
util_array_remove() {
  local -n array_ref="$1"
  local value="$2"
  local new_array=()

  for item in "${array_ref[@]}"; do
    [[ "$item" != "$value" ]] && new_array+=("$item")
  done

  array_ref=("${new_array[@]}")
  return 0
}

# Function: util_array_remove_at_index
# Description: Remove an element at a specific index
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - index to remove
# Returns:
#   0 - success
#   1 - invalid index
util_array_remove_at_index() {
  local -n array_ref="$1"
  local index="$2"

  if [[ "$index" -lt 0 || "$index" -ge "${#array_ref[@]}" ]]; then
    log_error "Array index out of bounds: $index"
    return 1
  fi

  local new_array=()
  local i=0

  for item in "${array_ref[@]}"; do
    if [[ "$i" -ne "$index" ]]; then
      new_array+=("$item")
    fi
    ((i++))
  done

  array_ref=("${new_array[@]}")
  return 0
}

# Function: util_array_get_index
# Description: Get the index of a value in an array
# Parameters:
#   $1 - value to find
#   $@ - array elements
# Returns:
#   Index via stdout, -1 if not found
util_array_get_index() {
  local needle="$1"
  shift
  local haystack=("$@")
  local index=0

  for item in "${haystack[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      echo "$index"
      return 0
    fi
    ((index++))
  done

  echo "-1"
  return 1
}

# Function: util_array_length
# Description: Get the length of an array
# Parameters:
#   $1 - array name (passed by reference)
# Returns:
#   Array length via stdout
util_array_length() {
  local -n array_ref="$1"
  echo "${#array_ref[@]}"
}

# Function: util_array_is_empty
# Description: Check if an array is empty
# Parameters:
#   $1 - array name (passed by reference)
# Returns:
#   0 - array is empty
#   1 - array is not empty
util_array_is_empty() {
  local -n array_ref="$1"
  [[ "${#array_ref[@]}" -eq 0 ]]
}

# Function: util_array_join
# Description: Join array elements with a delimiter
# Parameters:
#   $1 - delimiter
#   $@ - array elements
# Returns:
#   Joined string via stdout
util_array_join() {
  local delimiter="$1"
  shift
  local elements=("$@")

  if [[ "${#elements[@]}" -eq 0 ]]; then
    return 0
  fi

  local result="${elements[0]}"
  for ((i = 1; i < ${#elements[@]}; i++)); do
    result+="$delimiter${elements[i]}"
  done

  echo "$result"
}

# Function: util_array_split
# Description: Split a string into an array by delimiter
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - string to split
#   $3 - delimiter
# Returns:
#   0 - success
util_array_split() {
  local -n array_ref="$1"
  local string="$2"
  local delimiter="$3"

  # Clear the array
  array_ref=()

  # Use read to split the string
  IFS="$delimiter" read -r -a array_ref <<<"$string"

  return 0
}

# Function: util_array_reverse
# Description: Reverse the order of elements in an array
# Parameters:
#   $1 - array name (passed by reference)
# Returns:
#   0 - success
util_array_reverse() {
  local -n array_ref="$1"
  local reversed_array=()

  for ((i = ${#array_ref[@]} - 1; i >= 0; i--)); do
    reversed_array+=("${array_ref[i]}")
  done

  array_ref=("${reversed_array[@]}")
  return 0
}

# Function: util_array_sort
# Description: Sort array elements (basic alphabetical sort)
# Parameters:
#   $1 - array name (passed by reference)
# Returns:
#   0 - success
util_array_sort() {
  local -n array_ref="$1"

  # Use readarray with process substitution for sorting
  readarray -t array_ref < <(printf '%s\n' "${array_ref[@]}" | sort)

  return 0
}

# Function: util_array_unique
# Description: Remove duplicate elements from an array
# Parameters:
#   $1 - array name (passed by reference)
# Returns:
#   0 - success
util_array_unique() {
  local -n array_ref="$1"
  local unique_array=()

  for item in "${array_ref[@]}"; do
    if ! util_array_contains "$item" "${unique_array[@]}"; then
      unique_array+=("$item")
    fi
  done

  array_ref=("${unique_array[@]}")
  return 0
}

# Function: util_array_filter
# Description: Filter array elements using a test command
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - test command (will be called with each element as $1)
# Returns:
#   0 - success
util_array_filter() {
  local -n array_ref="$1"
  local test_cmd="$2"
  local filtered_array=()

  for item in "${array_ref[@]}"; do
    if eval "$test_cmd" "'$item'"; then
      filtered_array+=("$item")
    fi
  done

  array_ref=("${filtered_array[@]}")
  return 0
}

# Function: util_array_map
# Description: Apply a transformation to each element in an array
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - transformation command (will be called with each element as $1)
# Returns:
#   0 - success
util_array_map() {
  local -n array_ref="$1"
  local transform_cmd="$2"
  local mapped_array=()

  for item in "${array_ref[@]}"; do
    local result
    result=$(eval "$transform_cmd" "'$item'")
    mapped_array+=("$result")
  done

  array_ref=("${mapped_array[@]}")
  return 0
}

# Function: util_array_find
# Description: Find the first element matching a condition
# Parameters:
#   $1 - test command (will be called with each element as $1)
#   $@ - array elements
# Returns:
#   First matching element via stdout, empty if not found
util_array_find() {
  local test_cmd="$1"
  shift
  local elements=("$@")

  for item in "${elements[@]}"; do
    if eval "$test_cmd" "'$item'"; then
      echo "$item"
      return 0
    fi
  done

  return 1
}

# Function: util_array_copy
# Description: Copy elements from one array to another
# Parameters:
#   $1 - source array name (passed by reference)
#   $2 - destination array name (passed by reference)
# Returns:
#   0 - success
util_array_copy() {
  local -n source_ref="$1"
  local -n dest_ref="$2"

  dest_ref=("${source_ref[@]}")
  return 0
}

# Function: util_array_slice
# Description: Extract a slice of an array
# Parameters:
#   $1 - array name (passed by reference)
#   $2 - start index (inclusive)
#   $3 - end index (exclusive, optional)
# Returns:
#   0 - success
util_array_slice() {
  local -n array_ref="$1"
  local start_index="$2"
  local end_index="${3:-${#array_ref[@]}}"
  local sliced_array=()

  if [[ "$start_index" -lt 0 ]]; then
    start_index=0
  fi

  if [[ "$end_index" -gt "${#array_ref[@]}" ]]; then
    end_index="${#array_ref[@]}"
  fi

  for ((i = start_index; i < end_index; i++)); do
    if [[ "$i" -ge 0 && "$i" -lt "${#array_ref[@]}" ]]; then
      sliced_array+=("${array_ref[i]}")
    fi
  done

  array_ref=("${sliced_array[@]}")
  return 0
}

# Function: util_array_to_string
# Description: Convert array to a string representation
# Parameters:
#   $@ - array elements
# Returns:
#   String representation via stdout
util_array_to_string() {
  local elements=("$@")
  echo "[$(util_array_join ", " "${elements[@]}")]"
}

# Export functions for use by other modules
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f util_array_contains
  export -f util_array_add_unique
  export -f util_array_remove
  export -f util_array_remove_at_index
  export -f util_array_get_index
  export -f util_array_length
  export -f util_array_is_empty
  export -f util_array_join
  export -f util_array_split
  export -f util_array_reverse
  export -f util_array_sort
  export -f util_array_unique
  export -f util_array_filter
  export -f util_array_map
  export -f util_array_find
  export -f util_array_copy
  export -f util_array_slice
  export -f util_array_to_string
fi
