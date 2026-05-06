#!/usr/bin/env python3
"""
tech-debt-scan.py — Aggregiert TODO/FIXME/HACK + Backlog-[TECH-DEBT]-Items.
Sprint 262 (CC-SKILL-TECH-DEBT).

Output: JSON-Report mit:
- code_findings: Treffer pro File mit Pattern, Zeile, Snippet
- backlog_findings: [TECH-DEBT]-Items aus memory/backlog-*.md
- hot_spots: Top 5 Files mit meisten Treffern (+ git-blame letzter Touch)
- summary: Counts pro Pattern

Usage: python3 tech-debt-scan.py [--projects-dir DIR] [--memory-dir DIR] [--out FILE]
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

PATTERNS = ["TODO", "FIXME", "HACK", "XXX"]
BACKLOG_TAGS = ["[TECH-DEBT]", "[SCHULDEN]"]

CODE_EXTS = (".py", ".ts", ".tsx", ".js", ".mjs", ".sh", ".swift")
EXCLUDE_DIRS = {"node_modules", ".next", ".astro", "dist", "build", ".build", ".vercel", ".git", "__pycache__", "archive", ".venv", "venv", "DerivedData"}


def find_code_findings(root: Path):
    findings = []
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in CODE_EXTS:
            continue
        if any(part in EXCLUDE_DIRS for part in path.parts):
            continue
        try:
            for line_no, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                for pattern in PATTERNS:
                    # nur Kommentare matchen (rough: # oder // oder /*)
                    if pattern in line and ("#" in line or "//" in line or "/*" in line):
                        snippet = line.strip()[:120]
                        findings.append({
                            "file": str(path),
                            "line": line_no,
                            "pattern": pattern,
                            "snippet": snippet,
                        })
                        break  # ein Treffer pro Zeile reicht
        except (OSError, UnicodeDecodeError):
            continue
    return findings


def find_backlog_findings(memory_dir: Path):
    findings = []
    for md in memory_dir.glob("backlog-*.md"):
        try:
            for line_no, line in enumerate(md.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                for tag in BACKLOG_TAGS:
                    if tag in line:
                        snippet = line.strip()[:160]
                        findings.append({
                            "file": str(md),
                            "line": line_no,
                            "tag": tag,
                            "snippet": snippet,
                        })
                        break
        except OSError:
            continue
    return findings


def hot_spots(code_findings, top_n=5):
    by_file = defaultdict(int)
    for f in code_findings:
        by_file[f["file"]] += 1
    sorted_files = sorted(by_file.items(), key=lambda kv: kv[1], reverse=True)[:top_n]
    out = []
    for file, count in sorted_files:
        last_touch = None
        try:
            r = subprocess.run(
                ["git", "log", "-1", "--format=%ai", "--", file],
                cwd=os.path.dirname(file), capture_output=True, text=True, timeout=5,
            )
            if r.returncode == 0:
                last_touch = r.stdout.strip()[:10]
        except (subprocess.SubprocessError, OSError):
            pass
        out.append({"file": file, "count": count, "last_touch": last_touch})
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--projects-dir", default=str(Path.home() / "projects"))
    p.add_argument("--memory-dir", default=str(Path.home() / ".claude/projects/-Users-scholly/memory"))
    p.add_argument("--out", default="/tmp/tech-debt-scan.json")
    args = p.parse_args()

    projects_dir = Path(args.projects_dir)
    memory_dir = Path(args.memory_dir)

    code = []
    if projects_dir.exists():
        for project in projects_dir.iterdir():
            if project.is_dir() and not project.name.startswith("."):
                code.extend(find_code_findings(project))
    backlog = find_backlog_findings(memory_dir) if memory_dir.exists() else []

    summary = defaultdict(int)
    for f in code:
        summary[f["pattern"]] += 1
    for f in backlog:
        summary[f["tag"]] += 1

    report = {
        "code_findings_count": len(code),
        "backlog_findings_count": len(backlog),
        "summary": dict(summary),
        "hot_spots": hot_spots(code),
        "code_findings": code[:200],  # Begrenzen, sonst wird das File riesig
        "backlog_findings": backlog,
    }

    Path(args.out).write_text(json.dumps(report, indent=2))

    # Console-Summary
    print(f"📊 Tech-Debt-Scan-Report: {args.out}")
    print(f"  Code-Findings: {len(code)}")
    print(f"  Backlog-Findings ([TECH-DEBT]): {len(backlog)}")
    print(f"  Patterns:")
    for k, v in sorted(summary.items()):
        print(f"    {k:14}: {v}")
    print(f"  Top Hot-Spots:")
    for hs in report["hot_spots"][:5]:
        print(f"    {hs['count']:3}× {hs['file']} (last: {hs['last_touch']})")

    # Phase-A-Gate (Regel 4)
    if backlog:
        print()
        print(f"⚠️  STOPP-Gate (Regel 4): {len(backlog)} [TECH-DEBT]-Items im aktiven Backlog. Vor neuen Features einplanen.")
        sys.exit(2)
    elif len(code) > 100:
        print()
        print(f"⚠️  WARN: {len(code)} TODO/FIXME/HACK gesamt — Code-Hygiene-Drift, Refactor-Sprint erwaegen.")
    else:
        print()
        print("✅ Keine STOPP-Gate-Verstosse. Code-Schulden im Rahmen.")


if __name__ == "__main__":
    main()
