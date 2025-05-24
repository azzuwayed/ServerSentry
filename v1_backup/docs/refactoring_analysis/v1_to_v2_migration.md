# ServerSentry v1 → v2 Migration Tracking

This document tracks the migration status of all v1 runtime `.sh` files to v2, summarizing their purpose, v2 equivalents, migration status, and notes. Any v1 logic not found in v2 is highlighted below.

---

## Summary

- **Complete/Improved:** Most core logic (monitoring, CLI, notifications, periodic, config, log) is migrated and improved in v2.
- **Partial/Missing:** Some helpers (e.g., install script, generic webhook logic, some CLI visual helpers) are not directly ported or are handled differently.
- **See notes for each file for details.**

---

| v1 File                            | Purpose                                      | v2 Equivalent                               | Migration Status  | Notes                               |
| ---------------------------------- | -------------------------------------------- | ------------------------------------------- | ----------------- | ----------------------------------- |
| serversentry.sh                    | Main entrypoint, CLI dispatcher              | bin/serversentry, lib/ui/cli/commands.sh    | Complete/Improved | v2 is modular, extensible           |
| install.sh                         | Installer, permissions, config, cron         | (No direct equivalent)                      | Missing           | v2 lacks a unified install script   |
| lib/monitor/monitor.sh             | Core monitoring logic (CPU, mem, disk, proc) | lib/plugins/{cpu,memory,disk,process}/\*.sh | Complete/Improved | v2 uses plugin architecture         |
| lib/monitor/periodic.sh            | Periodic checks, reporting                   | lib/core/periodic.sh                        | Complete/Improved | v2 has YAML config, state mgmt      |
| lib/notify/main.sh                 | Notification system entry                    | lib/core/notification.sh                    | Complete/Improved | v2 uses provider interface          |
| lib/notify/sender.sh               | Webhook sender                               | lib/notifications/\*/                       | Complete/Improved | v2 has provider modules             |
| lib/notify/formatters.sh           | Payload formatting                           | lib/notifications/\*/                       | Complete/Improved | v2 providers format payloads        |
| lib/notify/system_info.sh          | System info for notifications                | lib/notifications/\*/                       | Complete/Improved | v2 providers gather system info     |
| lib/notify/teams_cards.sh          | Teams adaptive cards                         | lib/notifications/teams/teams.sh            | Complete/Improved | v2 supports adaptive cards          |
| lib/notify/\*                      | Other notification helpers                   | lib/notifications/\*/                       | Complete/Improved | v2 modularizes providers            |
| lib/config/config.sh               | Config management                            | lib/core/config.sh                          | Complete/Improved | v2 uses YAML, more robust           |
| lib/config/config_manager.sh       | Config manager                               | lib/core/config.sh                          | Complete/Improved | v2 uses YAML, more robust           |
| lib/config/config_compatibility.sh | Backward compat for config                   | (No direct equivalent)                      | Missing           | v2 does not provide v1 compat layer |
| lib/log/logrotate.sh               | Log rotation, cleanup                        | lib/core/logging.sh                         | Complete/Improved | v2 logging is more robust           |
| lib/utils/utils.sh                 | Utility functions                            | lib/core/utils.sh                           | Complete/Improved | v2 utilities are more robust        |
| lib/utils/paths.sh                 | Path helpers                                 | lib/core/utils.sh                           | Complete/Improved | v2 uses BASE_DIR, helpers           |
| lib/cli/utils.sh                   | CLI helpers, colors, help                    | lib/ui/cli/commands.sh, lib/core/utils.sh   | Mostly Complete   | Some visual helpers not ported      |
| lib/cli/status.sh                  | Status command                               | lib/ui/cli/commands.sh (cmd_status)         | Complete/Improved | v2 status is plugin-based           |
| lib/cli/check.sh                   | One-time check                               | lib/ui/cli/commands.sh (cmd_check)          | Complete/Improved | v2 uses plugins for checks          |
| lib/cli/monitor.sh                 | Foreground monitoring                        | lib/ui/cli/commands.sh (cmd_start)          | Complete/Improved | v2 uses background/foreground       |
| lib/cli/periodic.sh                | Periodic CLI commands                        | lib/ui/cli/commands.sh (cmd_periodic)       | Complete/Improved | v2 periodic is in core/periodic.sh  |
| lib/cli/logs.sh                    | Log management CLI                           | lib/ui/cli/commands.sh (cmd_logs)           | Complete/Improved | v2 logging is more robust           |
| lib/cli/config.sh                  | Config CLI                                   | lib/ui/cli/commands.sh (cmd_configure)      | Complete/Improved | v2 config is YAML-based             |
| lib/cli/webhook.sh                 | Webhook CLI mgmt                             | lib/ui/cli/commands.sh (cmd_webhook)        | Complete/Improved | v2 uses provider/channel config     |

---

## Notable v1 Logic Not Found in v2

- **install.sh:** No unified install script in v2; setup may be manual or handled differently.
- **config_compatibility.sh:** No backward compatibility layer for v1 config in v2.
- **Generic webhook support:** v2 focuses on named providers (Teams, Slack, Discord, Email); generic webhook logic may need to be re-implemented if required.
- **Some CLI visual helpers:** Progress bars, colorized output, and interactive menus are less prominent in v2 CLI (but TUI is improved).

---

**This table will be updated as more files are reviewed or as v2 evolves.**
