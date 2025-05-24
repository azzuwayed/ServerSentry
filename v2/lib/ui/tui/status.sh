#!/bin/bash
# TUI status and check module

source "$(dirname "$0")/utils.sh"

# Show system status
# Usage: tui_status
tui_status() {
  check_serversentry_bin || return
  local output
  output="$($SERVERSENTRY_BIN status 2>&1)"
  tui_show_message "$output" 20 80
}

# Run system check
# Usage: tui_check
tui_check() {
  check_serversentry_bin || return
  local output
  output="$($SERVERSENTRY_BIN check 2>&1)"
  tui_show_message "$output" 20 80
}

# (This module is intended to be sourced by tui.sh)
