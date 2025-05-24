# Potential Code Smells

## Long Functions
Functions with more than 50 lines:

| File | Function | Lines |
|------|----------|-------|
| lib/cli/check.sh | cli_check() | 62 |
| lib/cli/status.sh | cli_status() | 61 |
| lib/cli/webhook.sh | cli_test_webhook() | 56 |
| lib/config/config_compatibility.sh | update_threshold() | 53 |
| lib/config/config_compatibility.sh | add_webhook() | 51 |
| lib/config/config_manager.sh | manage_webhooks() | 109 |
| lib/config/config.sh | update_threshold() | 66 |
| lib/install/config.sh | create_config_files() | 132 |
| lib/install/cron.sh | test_cron_job() | 62 |
| lib/install/menu.sh | install_menu() | 94 |
| lib/install/menu.sh | configure_webhooks() | 64 |
| lib/install/menu.sh | update_menu() | 93 |
| lib/install/permissions.sh | set_permissions() | 54 |
| lib/log/logrotate.sh | update_logrotate_config() | 59 |
| lib/log/logrotate.sh | cleanup_old_logs() | 55 |
| lib/monitor/monitor.sh | get_cpu_usage() | 79 |
| lib/monitor/monitor.sh | get_memory_usage() | 75 |
| lib/monitor/periodic.sh | update_periodic_parameter() | 80 |
| lib/monitor/periodic.sh | should_send_report() | 62 |
| lib/monitor/periodic.sh | generate_system_report() | 163 |
| lib/monitor/periodic.sh | show_periodic_status() | 97 |
| lib/notify/formatters.sh | format_webhook_payload() | 97 |
| lib/notify/sender.sh | send_webhook_notification() | 51 |
| lib/notify/system_info.sh | get_system_info_data() | 136 |
| lib/notify/teams_cards.sh | create_progress_bar() | 75 |
| lib/notify/teams_cards.sh | create_adaptive_card() | 203 |
| lib/notify/teams_cards.sh | create_teams_message_card() | 124 |

## Hardcoded Values
Files with potentially hardcoded configuration values:

| File | Line | Content |
|------|------|---------|
| lib/cli/config.sh | 19 |     echo "Error: Threshold value is required (e.g., cpu_threshold=85)" |
| lib/cli/config.sh | 28 |     echo "Error: Invalid format. Use NAME=VALUE (e.g., cpu_threshold=85)" |
| lib/cli/utils.sh | 66 |   echo -e "  ${GREEN}-u, --update N=VALUE${NC}   ⚙️  Update threshold (e.g., cpu_threshold=85)" |
| lib/config/config_manager.sh | 280 | cpu_threshold=80 |
| lib/config/config_manager.sh | 281 | memory_threshold=80 |
| lib/config/config_manager.sh | 282 | disk_threshold=85 |
| lib/config/config_manager.sh | 283 | load_threshold=2.0 |
| lib/config/config_manager.sh | 284 | check_interval=60 |
| lib/install/config.sh | 67 | cpu_threshold=80 |
| lib/install/config.sh | 68 | memory_threshold=80 |
| lib/install/config.sh | 69 | disk_threshold=85 |
| lib/install/config.sh | 70 | load_threshold=2.0 |
| lib/install/config.sh | 71 | check_interval=60 |
| lib/install/help.sh | 73 |   echo -e "    ↳ Update configuration threshold (e.g., cpu_threshold=90)\n" |
| lib/notify/teams_cards.sh | 170 |     local cpu_threshold=80 |
| lib/notify/teams_cards.sh | 171 |     local memory_threshold=80 |
| lib/notify/teams_cards.sh | 172 |     local disk_threshold=85 |
| serversentry.sh | 128 |             echo "Error: Threshold value is required (e.g., cpu_threshold=85)" |
| tools/analyze_codebase.sh | 293 |   echo 'cpu_threshold=80' |
| tools/analyze_codebase.sh | 294 |   echo 'cpu_warning_threshold=70' |
| tools/analyze_codebase.sh | 295 |   echo 'cpu_check_interval=60' |
| tools/analyze_codebase.sh | 377 |   echo 'cpu_threshold=85' |
| tools/analyze_codebase.sh | 380 |   echo 'cpu_warning_threshold=75' |

## Global Variables
Files with many global variables (uppercase variables):

| File | Global Variables Count |
|------|------------------------|
| lib/cli/utils.sh |       12 |
| lib/config/config_compatibility.sh |        7 |
| lib/config/config.sh |       11 |
| lib/install/utils.sh |        7 |
| lib/log/logrotate.sh |        9 |
| lib/monitor/periodic.sh |        8 |
| tools/analyze_codebase.sh |       10 |
| tools/migrate_to_v2.sh |       11 |

## Error Handling
Files that may need improved error handling:

| File | Line | Issue |
|------|------|-------|
| install.sh | 36 | Command without error check: `# Process command line arguments if provided` |
| lib/cli/logs.sh | 19 | Command without error check: `    echo "Error: Log command is required (status, rotate, clean, config)"` |
| lib/cli/periodic.sh | 19 | Command without error check: `    echo "Error: Periodic command is required (run, status, config)"` |
| lib/install/cron.sh | 136 | Command without error check: `  # Extract command part (everything after the time fields)` |
| lib/install/cron.sh | 139 | Command without error check: `  # Split command and redirection` |
| lib/install/cron.sh | 155 | Command without error check: `  echo -e "${CYAN}Executing command from crontab:${NC}"` |
| lib/install/cron.sh | 158 | Command without error check: `  # Execute the exact command from crontab` |
| lib/install/deps.sh | 12 | Command without error check: `# Check if a command exists and output formatted status` |
| lib/monitor/monitor.sh | 196 | Command without error check: `        # Using df command for specified partition` |
| lib/notify/main.sh | 24 | Command without error check: `    log_message "WARNING" "curl command not found, webhook notifications will not work"` |
| lib/notify/sender.sh | 44 | Command without error check: `        log_message "ERROR" "curl command not found, cannot send webhook notification"` |
| lib/notify/sender.sh | 45 | Command without error check: `        echo "[ERROR] curl command not found, cannot send webhook notification"` |
| serversentry.sh | 73 | Command without error check: `# Process command line arguments` |
| serversentry.sh | 143 | Command without error check: `            echo "Error: Periodic command is required (run, status, config)"` |
| serversentry.sh | 161 | Command without error check: `            echo "Error: Log command is required (status, rotate, clean, config)"` |
| tools/analyze_codebase.sh | 39 | Command without error check: `    echo -e "${RED}Error: Required command '$cmd' not found.${NC}"` |
