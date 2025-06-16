#!/usr/bin/env python3
"""
ServerSentry Project Cleanup and Audit Script

This script performs a comprehensive audit of the remaining files,
identifies redundancies, and streamlines the project structure.
"""

import os
import re
import glob
import shutil
from pathlib import Path
from collections import defaultdict
import hashlib


class ProjectAuditor:
    def __init__(self, root_dir="."):
        self.root_dir = Path(root_dir)
        self.issues = []
        self.redundant_files = []
        self.empty_dirs = []
        self.large_files = []
        self.duplicate_functions = defaultdict(list)
        self.unused_files = []

    def log_issue(self, severity, category, file_path, description):
        """Log an issue found during audit."""
        self.issues.append(
            {
                "severity": severity,
                "category": category,
                "file": str(file_path),
                "description": description,
            }
        )

    def find_shell_files(self):
        """Find all shell script files."""
        patterns = ["**/*.sh"]
        files = []
        for pattern in patterns:
            files.extend(self.root_dir.glob(pattern))
        return [f for f in files if f.is_file()]

    def find_duplicate_files(self):
        """Find duplicate files based on content hash."""
        print("🔍 Checking for duplicate files...")

        file_hashes = defaultdict(list)
        shell_files = self.find_shell_files()

        for file_path in shell_files:
            try:
                with open(file_path, "rb") as f:
                    content_hash = hashlib.md5(f.read()).hexdigest()
                file_hashes[content_hash].append(file_path)
            except Exception as e:
                self.log_issue(
                    "LOW", "FILE_ACCESS", file_path, f"Cannot read file: {e}"
                )

        # Find duplicates
        for content_hash, files in file_hashes.items():
            if len(files) > 1:
                self.redundant_files.extend(
                    files[1:]
                )  # Keep first, mark others as redundant
                self.log_issue(
                    "MEDIUM",
                    "DUPLICATE_FILES",
                    files[0],
                    f"Duplicate files found: {[str(f) for f in files]}",
                )

    def find_empty_directories(self):
        """Find empty directories that can be removed."""
        print("📁 Checking for empty directories...")

        for dir_path in self.root_dir.rglob("*"):
            try:
                if dir_path.is_dir() and not any(dir_path.iterdir()):
                    # Skip certain directories that should exist even if empty
                    skip_dirs = {".git", ".vscode", ".cursor", "logs", "tmp", "data"}
                    if dir_path.name not in skip_dirs:
                        self.empty_dirs.append(dir_path)
                        self.log_issue("LOW", "EMPTY_DIR", dir_path, "Empty directory")
            except (PermissionError, OSError) as e:
                # Skip directories we can't access
                continue

    def find_large_files(self, size_limit_mb=1):
        """Find unusually large shell files."""
        print("📏 Checking for large files...")

        size_limit = size_limit_mb * 1024 * 1024
        shell_files = self.find_shell_files()

        for file_path in shell_files:
            try:
                if file_path.stat().st_size > size_limit:
                    lines = sum(
                        1
                        for _ in open(file_path, "r", encoding="utf-8", errors="ignore")
                    )
                    self.large_files.append((file_path, lines))
                    self.log_issue(
                        "MEDIUM", "LARGE_FILE", file_path, f"Large file: {lines} lines"
                    )
            except Exception as e:
                self.log_issue(
                    "LOW", "FILE_ACCESS", file_path, f"Cannot analyze file: {e}"
                )

    def find_duplicate_functions(self):
        """Find duplicate function definitions across files."""
        print("🔧 Checking for duplicate functions...")

        function_pattern = re.compile(
            r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)\s*\{", re.MULTILINE
        )
        shell_files = self.find_shell_files()

        for file_path in shell_files:
            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()

                functions = function_pattern.findall(content)
                for func_name in functions:
                    self.duplicate_functions[func_name].append(file_path)
            except Exception as e:
                self.log_issue(
                    "LOW", "FILE_ACCESS", file_path, f"Cannot analyze functions: {e}"
                )

        # Report duplicates
        for func_name, files in self.duplicate_functions.items():
            if len(files) > 1:
                self.log_issue(
                    "MEDIUM",
                    "DUPLICATE_FUNCTION",
                    files[0],
                    f"Function '{func_name}' defined in multiple files: {[str(f) for f in files]}",
                )

    def check_file_organization(self):
        """Check for files that might be in wrong directories."""
        print("📂 Checking file organization...")

        shell_files = self.find_shell_files()

        for file_path in shell_files:
            file_name = file_path.name
            parent_dir = file_path.parent.name

            # Check for misplaced test files
            if "test" in file_name.lower() and "tests" not in str(file_path):
                self.log_issue(
                    "LOW",
                    "MISPLACED_FILE",
                    file_path,
                    "Test file not in tests directory",
                )

            # Check for utility files not in utils
            if "util" in file_name.lower() and "utils" not in str(file_path):
                self.log_issue(
                    "LOW",
                    "MISPLACED_FILE",
                    file_path,
                    "Utility file not in utils directory",
                )

            # Check for plugin files not in plugins
            if (
                "plugin" in file_name.lower()
                and "plugins" not in str(file_path)
                and "core" not in str(file_path)
            ):
                self.log_issue(
                    "LOW",
                    "MISPLACED_FILE",
                    file_path,
                    "Plugin file not in plugins directory",
                )

    def check_naming_conventions(self):
        """Check for inconsistent naming conventions."""
        print("📝 Checking naming conventions...")

        shell_files = self.find_shell_files()

        for file_path in shell_files:
            file_name = file_path.name

            # Check for inconsistent naming patterns
            if "_" in file_name and "-" in file_name:
                self.log_issue(
                    "LOW",
                    "NAMING_INCONSISTENCY",
                    file_path,
                    "Mixed underscore and hyphen in filename",
                )

            # Check for uppercase in filenames (should be lowercase)
            if any(c.isupper() for c in file_name):
                self.log_issue(
                    "LOW",
                    "NAMING_INCONSISTENCY",
                    file_path,
                    "Uppercase characters in filename",
                )

    def check_unused_files(self):
        """Check for potentially unused files."""
        print("🗑️  Checking for unused files...")

        shell_files = self.find_shell_files()
        all_content = ""

        # Read all files to build a corpus
        for file_path in shell_files:
            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    all_content += f.read() + "\n"
            except Exception:
                continue

        # Check if each file is referenced
        for file_path in shell_files:
            file_name = file_path.name
            base_name = file_path.stem

            # Skip certain files that are entry points
            skip_files = {"serversentry-env.sh", "serversentry"}
            if file_name in skip_files:
                continue

            # Check if file is sourced or referenced
            patterns = [
                f"source.*{re.escape(file_name)}",
                f"source.*{re.escape(base_name)}",
                f"\\..*{re.escape(file_name)}",
                f"{re.escape(base_name)}\\.sh",
            ]

            referenced = any(
                re.search(pattern, all_content, re.IGNORECASE) for pattern in patterns
            )

            if not referenced:
                # Additional check for executable files
                if not os.access(file_path, os.X_OK):
                    self.unused_files.append(file_path)
                    self.log_issue(
                        "MEDIUM", "UNUSED_FILE", file_path, "File appears to be unused"
                    )

    def analyze_complexity(self):
        """Analyze file complexity and suggest simplifications."""
        print("📊 Analyzing file complexity...")

        shell_files = self.find_shell_files()

        for file_path in shell_files:
            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()

                total_lines = len(lines)
                code_lines = sum(
                    1
                    for line in lines
                    if line.strip() and not line.strip().startswith("#")
                )
                comment_lines = sum(1 for line in lines if line.strip().startswith("#"))

                # Check for overly complex files
                if code_lines > 300:
                    self.log_issue(
                        "HIGH",
                        "COMPLEX_FILE",
                        file_path,
                        f"High complexity: {code_lines} code lines",
                    )
                elif code_lines > 200:
                    self.log_issue(
                        "MEDIUM",
                        "COMPLEX_FILE",
                        file_path,
                        f"Medium complexity: {code_lines} code lines",
                    )

                # Check comment ratio
                if total_lines > 50 and comment_lines / total_lines < 0.1:
                    self.log_issue(
                        "LOW",
                        "LOW_DOCUMENTATION",
                        file_path,
                        f"Low comment ratio: {comment_lines}/{total_lines}",
                    )

            except Exception as e:
                self.log_issue(
                    "LOW", "FILE_ACCESS", file_path, f"Cannot analyze complexity: {e}"
                )

    def run_audit(self):
        """Run the complete audit."""
        print("🚀 Starting comprehensive project audit...")
        print(f"📁 Auditing directory: {self.root_dir.absolute()}")

        self.find_duplicate_files()
        self.find_empty_directories()
        self.find_large_files()
        self.find_duplicate_functions()
        self.check_file_organization()
        self.check_naming_conventions()
        self.check_unused_files()
        self.analyze_complexity()

        return self.generate_report()

    def generate_report(self):
        """Generate audit report."""
        print("\n" + "=" * 60)
        print("📋 AUDIT REPORT")
        print("=" * 60)

        # Summary by severity
        severity_counts = defaultdict(int)
        for issue in self.issues:
            severity_counts[issue["severity"]] += 1

        print(f"\n📊 Issues Summary:")
        for severity in ["HIGH", "MEDIUM", "LOW"]:
            count = severity_counts[severity]
            if count > 0:
                print(f"  {severity}: {count} issues")

        # Detailed issues
        print(f"\n🔍 Detailed Issues:")
        for issue in sorted(self.issues, key=lambda x: (x["severity"], x["category"])):
            print(f"  [{issue['severity']}] {issue['category']}: {issue['file']}")
            print(f"    {issue['description']}")

        # Cleanup recommendations
        print(f"\n🧹 Cleanup Recommendations:")

        if self.redundant_files:
            print(f"  📄 Remove {len(self.redundant_files)} duplicate files:")
            for file_path in self.redundant_files[:5]:  # Show first 5
                print(f"    - {file_path}")
            if len(self.redundant_files) > 5:
                print(f"    ... and {len(self.redundant_files) - 5} more")

        if self.empty_dirs:
            print(f"  📁 Remove {len(self.empty_dirs)} empty directories:")
            for dir_path in self.empty_dirs[:5]:
                print(f"    - {dir_path}")
            if len(self.empty_dirs) > 5:
                print(f"    ... and {len(self.empty_dirs) - 5} more")

        if self.unused_files:
            print(f"  🗑️  Consider removing {len(self.unused_files)} unused files:")
            for file_path in self.unused_files[:5]:
                print(f"    - {file_path}")
            if len(self.unused_files) > 5:
                print(f"    ... and {len(self.unused_files) - 5} more")

        # Statistics
        total_shell_files = len(self.find_shell_files())
        print(f"\n📈 Project Statistics:")
        print(f"  Total shell files: {total_shell_files}")
        print(f"  Issues found: {len(self.issues)}")
        print(
            f"  Files needing attention: {len(set(issue['file'] for issue in self.issues))}"
        )

        return {
            "total_issues": len(self.issues),
            "severity_counts": dict(severity_counts),
            "redundant_files": self.redundant_files,
            "empty_dirs": self.empty_dirs,
            "unused_files": self.unused_files,
        }


def main():
    """Main function."""
    auditor = ProjectAuditor()
    results = auditor.run_audit()

    print(f"\n✅ Audit completed!")
    print(f"Found {results['total_issues']} issues across the project.")

    return 0 if results["total_issues"] == 0 else 1


if __name__ == "__main__":
    exit(main())
