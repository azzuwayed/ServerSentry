#!/usr/bin/env python3
"""
Bootstrap Migration Script

This script migrates all files from the dual bootstrap system to the single bootstrap system.
"""

import os
import re
import glob
import shutil
from pathlib import Path

# New bootstrap pattern
NEW_BOOTSTRAP_PATTERN = """# Load ServerSentry environment
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
    current_dir="$(dirname "$current_dir")"
  done
  
  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi"""


def find_shell_files():
    """Find all shell script files that might need migration."""
    patterns = [
        "lib/core/*.sh",
        "lib/core/*/*.sh",
        "lib/plugins/*/*.sh",
        "lib/plugins/*/*/*.sh",
        "lib/ui/*/*.sh",
        "lib/core/utils/*.sh",
        "tests/*.sh",
        "tests/*/*.sh",
        "tests/*/*/*.sh",
        "tools/*.sh",
        "tools/*/*.sh",
        "docs/*/*.sh",
        "example-script.sh",
    ]

    files = []
    for pattern in patterns:
        files.extend(glob.glob(pattern))

    # Filter to only regular files
    return [f for f in files if os.path.isfile(f) and f.endswith(".sh")]


def needs_migration(file_path):
    """Check if a file needs migration."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        return "lib/serversentry-bootstrap.sh" in content
    except Exception:
        return False


def migrate_file(file_path):
    """Migrate a single file."""
    print(f"📝 Migrating: {file_path}")

    try:
        # Read the file
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Create backup
        backup_path = f"{file_path}.backup"
        shutil.copy2(file_path, backup_path)

        # Define the pattern to match the old bootstrap block
        # This matches the entire bootstrap block that uses lib/serversentry-bootstrap.sh
        old_pattern = re.compile(
            r"# Load ServerSentry environment.*?\n"
            r'if \[\[ -z "\$\{SERVERSENTRY_ENV_LOADED:-\}" \]\]; then\s*\n'
            r".*?"
            r"lib/serversentry-bootstrap\.sh.*?"
            r".*?"
            r"^fi\s*$",
            re.MULTILINE | re.DOTALL,
        )

        # Replace with new pattern
        new_content = old_pattern.sub(NEW_BOOTSTRAP_PATTERN, content)

        # Check if replacement was made
        if new_content == content:
            print(f"⚠️  No changes made to: {file_path}")
            os.remove(backup_path)
            return False

        # Write the new content
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(new_content)

        print(f"✅ Successfully migrated: {file_path}")
        os.remove(backup_path)
        return True

    except Exception as e:
        print(f"❌ Error migrating {file_path}: {e}")
        # Restore backup if it exists
        backup_path = f"{file_path}.backup"
        if os.path.exists(backup_path):
            shutil.move(backup_path, file_path)
        return False


def main():
    """Main migration function."""
    print("🚀 Starting bootstrap migration...")

    # Find all shell files
    shell_files = find_shell_files()
    print(f"📊 Found {len(shell_files)} shell files to check")

    # Filter files that need migration
    files_to_migrate = [f for f in shell_files if needs_migration(f)]
    print(f"🎯 Found {len(files_to_migrate)} files that need migration")

    if not files_to_migrate:
        print("✅ No files need migration!")
        return True

    # Migrate each file
    migrated_count = 0
    error_count = 0

    for file_path in files_to_migrate:
        if migrate_file(file_path):
            migrated_count += 1
        else:
            error_count += 1

    # Summary
    print(f"\n📈 Migration Summary:")
    print(f"✅ Files migrated: {migrated_count}")
    print(f"❌ Files with errors: {error_count}")
    print(f"📁 Total files checked: {len(shell_files)}")

    if error_count == 0:
        print("🎉 Bootstrap migration completed successfully!")
        return True
    else:
        print("⚠️  Bootstrap migration completed with errors")
        return False


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
