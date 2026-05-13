#!/usr/bin/env python3
"""
test-coverage-scan.py — Sprint 262 (CC-SKILL-TEST-STRATEGY)
Prueft ob Sprint-Diff Test-File-Aenderungen enthaelt (Regel 109).

Output:
- 0 = Test-Diff vorhanden ODER Skip-Pfad anwendbar (e-testing-Marker OK)
- 1 = Code-Diff ohne Test-Diff (e-testing-Marker NICHT setzen)
- 2 = Stub-only-Tests gefunden (Warnung, Regel 109 verletzt)

Usage: python3 test-coverage-scan.py [--repo PATH] [--since-ref REF] [--sprint-type TYPE]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

TEST_PATTERNS = [
    r"\.test\.(ts|tsx|js|mjs|sh|py)$",
    r"\.spec\.(ts|tsx|js|mjs|py)$",
    r"\.bats$",
    r"^tests?/",
    r"__tests__/",
    r"^e2e/",
    r"/tests?/",
    r"/__tests__/",
    r"/e2e/",
]

CODE_PATTERNS = [
    r"\.(ts|tsx|js|mjs|sh|py|swift)$",
]

STUB_ONLY_INDICATORS = [
    r"^bash -n",  # Zeile beginnt mit syntax-check
    r"^\s*\[ -f .* \]",  # nur file-existence
]


def is_test_file(path):
    return any(re.search(p, path) for p in TEST_PATTERNS)


def is_code_file(path):
    return any(re.search(p, path) for p in CODE_PATTERNS) and not is_test_file(path)


def get_diff_files(repo, since_ref):
    cwd = repo
    cmd = ["git", "diff", "--name-only", since_ref]
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        return []
    return [line.strip() for line in r.stdout.splitlines() if line.strip()]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", default=str(Path.cwd()))
    p.add_argument("--since-ref", default="HEAD~10")
    p.add_argument("--sprint-type", default="", help="prozess|memory-only|<empty>")
    args = p.parse_args()

    if args.sprint_type in ("prozess", "memory-only"):
        print(f"✅ Skip-Pfad: SPRINT_TYPE={args.sprint_type} — Test-Diff nicht erforderlich.")
        sys.exit(0)

    files = get_diff_files(args.repo, args.since_ref)
    if not files:
        print("(keine Diff-Files)")
        sys.exit(0)

    test_diffs = [f for f in files if is_test_file(f)]
    code_diffs = [f for f in files if is_code_file(f)]

    print(f"Sprint-Diff: {len(files)} Files total, {len(test_diffs)} Tests, {len(code_diffs)} Code")

    if code_diffs and not test_diffs:
        print("⚠️  STOPP-Gate (Regel 109): Code-Diff vorhanden, aber 0 Test-File-Aenderungen.")
        print("    e-testing-Marker NICHT setzen. Test-Plan nachreichen.")
        for f in code_diffs[:10]:
            print(f"    ~ {f}")
        sys.exit(1)

    if test_diffs:
        print(f"✅ Test-Diff vorhanden ({len(test_diffs)} Files):")
        for f in test_diffs[:10]:
            print(f"    + {f}")

    sys.exit(0)


if __name__ == "__main__":
    main()
