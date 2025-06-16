#!/usr/bin/env python3
"""
Commands File Cleanup Script

This script removes extracted command implementations from the main commands.sh file.
"""

import re


def cleanup_commands_file():
    """Clean up the main commands.sh file by removing extracted implementations."""
    file_path = "lib/ui/cli/commands.sh"

    try:
        with open(file_path, "r") as f:
            content = f.read()

        # Remove the template command implementation
        template_pattern = r"# Command: template\ncmd_template\(\) \{.*?\n\}"
        content = re.sub(template_pattern, "", content, flags=re.DOTALL)

        # Remove the composite command implementation
        composite_pattern = r"# Command: composite\ncmd_composite\(\) \{.*?\n\}"
        content = re.sub(composite_pattern, "", content, flags=re.DOTALL)

        # Clean up extra whitespace
        content = re.sub(r"\n\n\n+", "\n\n", content)

        # Write back
        with open(file_path, "w") as f:
            f.write(content)

        print(f"✅ Cleaned up {file_path}")
        return True

    except Exception as e:
        print(f"❌ Error cleaning up {file_path}: {e}")
        return False


def main():
    """Main function."""
    print("🧹 Cleaning up commands.sh file...")
    success = cleanup_commands_file()
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())
