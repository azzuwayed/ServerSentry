#!/usr/bin/env python3
"""
Duplicate Function Consolidation Script

This script automatically updates files to use the unified frameworks
instead of duplicate function definitions.
"""

import os
import re
import glob
from pathlib import Path


class DuplicateConsolidator:
    def __init__(self, root_dir="."):
        self.root_dir = Path(root_dir)
        self.changes_made = 0
        self.files_updated = 0

        # Define function mappings
        self.test_functions = {
            "test_pass",
            "test_fail",
            "assert",
            "setup_test_environment",
            "cleanup_test_environment",
            "create_test_config",
            "print_test_header",
            "start_timer",
            "end_timer",
            "assert_performance",
        }

        self.ui_functions = {
            "print_header",
            "print_success",
            "print_error",
            "print_warning",
            "print_info",
            "print_separator",
            "print_dim",
            "print_status",
        }

        self.utility_functions = {
            "show_usage",
            "parse_arguments",
            "validate_dependencies",
            "is_excluded",
            "find_bash_files",
        }

    def should_add_test_framework(self, content):
        """Check if file should include test framework."""
        return any(func in content for func in self.test_functions)

    def should_add_ui_framework(self, content):
        """Check if file should include UI framework."""
        return any(func in content for func in self.ui_functions)

    def add_framework_import(self, content, framework_type):
        """Add framework import to file content."""
        if framework_type == "test":
            import_block = """
# Load unified test framework
if [[ -f "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/tests/lib/test_framework_core.sh"
fi
"""
        elif framework_type == "ui":
            import_block = """
# Load unified UI framework
if [[ -f "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh" ]]; then
  source "${SERVERSENTRY_ROOT}/lib/ui/common/print_utils.sh"
fi
"""
        else:
            return content

        # Find the best place to insert the import
        lines = content.split("\n")
        insert_index = 0

        # Look for existing bootstrap section
        for i, line in enumerate(lines):
            if "SERVERSENTRY_ENV_LOADED" in line:
                # Find the end of the bootstrap block
                for j in range(i, len(lines)):
                    if (
                        lines[j].strip() == "fi"
                        and "bootstrap" in "".join(lines[i:j]).lower()
                    ):
                        insert_index = j + 1
                        break
                break

        # Insert the import block
        lines.insert(insert_index, import_block)
        return "\n".join(lines)

    def remove_duplicate_functions(self, content, functions_to_remove):
        """Remove duplicate function definitions."""
        lines = content.split("\n")
        new_lines = []
        skip_until_end = False
        brace_count = 0

        i = 0
        while i < len(lines):
            line = lines[i]

            if skip_until_end:
                # Count braces to find function end
                brace_count += line.count("{")
                brace_count -= line.count("}")

                if brace_count <= 0:
                    skip_until_end = False
                    brace_count = 0
                i += 1
                continue

            # Check if this line starts a function we want to remove
            function_match = re.match(
                r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{", line.strip()
            )
            if function_match:
                func_name = function_match.group(1)
                if func_name in functions_to_remove:
                    # Start skipping this function
                    skip_until_end = True
                    brace_count = line.count("{") - line.count("}")
                    i += 1
                    continue

            new_lines.append(line)
            i += 1

        return "\n".join(new_lines)

    def update_file(self, file_path):
        """Update a single file to use unified frameworks."""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                original_content = f.read()

            content = original_content
            file_updated = False

            # Check if file needs test framework
            if self.should_add_test_framework(content):
                if "test_framework_core.sh" not in content:
                    content = self.add_framework_import(content, "test")
                    file_updated = True

                # Remove duplicate test functions
                content = self.remove_duplicate_functions(content, self.test_functions)
                if content != original_content:
                    file_updated = True

            # Check if file needs UI framework
            if self.should_add_ui_framework(content):
                if "print_utils.sh" not in content:
                    content = self.add_framework_import(content, "ui")
                    file_updated = True

                # Remove duplicate UI functions
                content = self.remove_duplicate_functions(content, self.ui_functions)
                if content != original_content:
                    file_updated = True

            # Write back if changed
            if file_updated and content != original_content:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)

                print(f"✅ Updated: {file_path}")
                self.files_updated += 1
                self.changes_made += 1
                return True

            return False

        except Exception as e:
            print(f"❌ Error updating {file_path}: {e}")
            return False

    def find_files_with_duplicates(self):
        """Find all files that contain duplicate functions."""
        patterns = ["**/*.sh"]
        files = []

        for pattern in patterns:
            files.extend(self.root_dir.glob(pattern))

        # Filter to files that actually contain duplicates
        files_with_duplicates = []
        for file_path in files:
            if not file_path.is_file():
                continue

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Check for duplicate functions
                has_duplicates = self.should_add_test_framework(
                    content
                ) or self.should_add_ui_framework(content)

                if has_duplicates:
                    files_with_duplicates.append(file_path)

            except Exception:
                continue

        return files_with_duplicates

    def run_consolidation(self):
        """Run the consolidation process."""
        print("🔧 Starting duplicate function consolidation...")

        # Find files with duplicates
        files_to_update = self.find_files_with_duplicates()
        print(f"📊 Found {len(files_to_update)} files with duplicate functions")

        if not files_to_update:
            print("✅ No files need updating!")
            return True

        # Update each file
        for file_path in files_to_update:
            self.update_file(file_path)

        # Summary
        print(f"\n📈 Consolidation Summary:")
        print(f"✅ Files updated: {self.files_updated}")
        print(f"🔧 Total changes: {self.changes_made}")

        if self.files_updated > 0:
            print("🎉 Duplicate function consolidation completed!")
            return True
        else:
            print("ℹ️  No changes were needed")
            return True


def main():
    """Main function."""
    consolidator = DuplicateConsolidator()
    success = consolidator.run_consolidation()
    return 0 if success else 1


if __name__ == "__main__":
    exit(main())
