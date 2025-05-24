# Module Dependencies

This shows which files are sourced by other files, creating a dependency graph.

| File | Dependencies |
|------|--------------|
| install.sh |  lib/install/config.sh, lib/install/cron.sh, lib/install/deps.sh, lib/install/help.sh, lib/install/menu.sh, lib/install/permissions.sh, lib/install/utils.sh, lib/utils/paths.sh |
| lib/cli/check.sh |  lib/cli/utils.sh, lib/config/config.sh, lib/monitor/monitor.sh, lib/utils/utils.sh |
| lib/cli/config.sh |  lib/cli/utils.sh, lib/config/config.sh, lib/utils/utils.sh |
| lib/cli/logs.sh |  lib/cli/utils.sh, lib/log/logrotate.sh, lib/utils/utils.sh |
| lib/cli/monitor.sh |  lib/cli/utils.sh, lib/config/config.sh, lib/monitor/monitor.sh, lib/utils/utils.sh |
| lib/cli/periodic.sh |  lib/cli/utils.sh, lib/monitor/periodic.sh, lib/utils/utils.sh |
| lib/cli/status.sh |  lib/cli/utils.sh, lib/config/config.sh, lib/monitor/monitor.sh, lib/utils/utils.sh |
| lib/cli/utils.sh |        /install/menu.sh,       /install/utils.sh, ../utils/paths.sh |
| lib/cli/webhook.sh |  ../utils/paths.sh, lib/cli/utils.sh, lib/config/config_manager.sh, lib/monitor/monitor.sh, lib/notify/main.sh, lib/utils/utils.sh |
| lib/config/config_compatibility.sh |        /notify/main.sh, config_manager.sh |
| lib/config/config_manager.sh |  ../utils/paths.sh |
| lib/config/config.sh |          lib/notify/main.sh,     lib/utils.sh |
| lib/install/config.sh |  lib/install/utils.sh |
| lib/install/cron.sh |  lib/install/utils.sh |
| lib/install/deps.sh |  lib/install/utils.sh |
| lib/install/help.sh |  lib/install/utils.sh |
| lib/install/menu.sh |  lib/install/config.sh, lib/install/cron.sh, lib/install/deps.sh, lib/install/help.sh, lib/install/permissions.sh, lib/install/utils.sh |
| lib/install/permissions.sh |  lib/install/utils.sh |
| lib/install/utils.sh |  |
| lib/log/logrotate.sh |  ../utils/paths.sh, ../utils/utils.sh |
| lib/monitor/monitor.sh |      lib/config/config_manager.sh,     lib/notify/main.sh, ../utils/paths.sh, ../utils/utils.sh |
| lib/monitor/periodic.sh |  ../utils/paths.sh, ../utils/utils.sh, lib/config/config_manager.sh, lib/monitor/monitor.sh, lib/notify/main.sh |
| lib/notify/formatters.sh |      lib/utils.sh,     system_info.sh,     teams_cards.sh |
| lib/notify/main.sh |  ../utils/paths.sh, ../utils/utils.sh, lib/notify/formatters.sh, lib/notify/sender.sh, lib/notify/system_info.sh, lib/notify/teams_cards.sh |
| lib/notify/sender.sh |      formatters.sh,     lib/utils.sh |
| lib/notify/system_info.sh |      lib/utils.sh |
| lib/notify/teams_cards.sh |      lib/utils.sh,     system_info.sh |
| lib/utils/paths.sh |  |
| lib/utils/utils.sh |  paths.sh |
| serversentry.sh |      /log/logrotate.sh, /cli/check.sh, /cli/config.sh, /cli/logs.sh, /cli/monitor.sh, /cli/periodic.sh, /cli/status.sh, /cli/utils.sh, /cli/webhook.sh, lib/utils/paths.sh, lib/utils/utils.sh |
| tools/analyze_codebase.sh |  |
| tools/migrate_to_v2.sh |  |
