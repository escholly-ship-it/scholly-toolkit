#!/usr/bin/env python3
"""
verify-first.py — CC-340 Verify-First-Pattern fuer Sprint-Items.

Prueft fuer alle JETZT-Items des aktuellen Sprints, ob die Schluesselwoerter
des Item-Titels schon im Codebase existieren — ein Hinweis darauf, dass die
Logik moeglicherweise schon implementiert ist.

Usage: verify-first.py <cache-file.json>

Reports only, kein STOPP. Output als Liste pro flagged Item.
"""
import json
import os
import re
import subprocess
import sys

STOPWORDS = {
    "der", "die", "das", "und", "in", "auf", "fuer", "mit", "im", "zu", "von",
    "als", "ein", "eine", "den", "dem", "des", "ist", "sind", "wird", "werden",
    "the", "and", "for", "in", "on", "of", "to", "by", "with", "is", "are",
    "be", "as", "at", "an", "or", "from", "this", "that",
    "neu", "alt", "siehe", "etc", "via", "mit", "ohne", "bei", "vor", "nach",
}

SEARCH_PATHS = [
    os.path.expanduser("~/.claude/skills"),
    os.path.expanduser("~/.claude/hooks"),
    os.path.expanduser("~/.claude/agents"),
    os.path.expanduser("~/Cowork/scripts"),
    os.path.expanduser("~/Cowork/agents"),
    os.path.expanduser("~/projects/roadmap/src"),
    os.path.expanduser("~/projects/roadmap-2/src"),
]

INCLUDE_GLOBS = ["*.md", "*.sh", "*.py", "*.ts", "*.tsx", "*.mjs", "*.js"]
EXCLUDE_PATHS = ["/archive/", "/node_modules/", "/.git/", "/dist/", "/.next/"]

SKIP_EFFORTS = {"XS"}
SKIP_HORIZONTS = {"SPAETER"}


def extract_keywords(title: str, max_n: int = 3) -> list[str]:
    """Extrahiere die groessten Substantive aus dem Titel."""
    title = re.sub(r"[\(\)\[\]:,\.;\-—'\"`]", " ", title)
    words = title.split()
    candidates = []
    for w in words:
        wl = w.lower().strip()
        if len(wl) < 5:
            continue
        if wl in STOPWORDS:
            continue
        if not re.match(r"^[\w\-]+$", w):
            continue
        candidates.append(w)
    candidates.sort(key=len, reverse=True)
    return candidates[:max_n]


def grep_keyword(keyword: str) -> list[str]:
    """Grep nach Keyword in SEARCH_PATHS."""
    cmd = ["grep", "-rln", "-i", keyword]
    for inc in INCLUDE_GLOBS:
        cmd.extend(["--include", inc])
    cmd.extend(p for p in SEARCH_PATHS if os.path.isdir(p))

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        lines = result.stdout.splitlines()
    except (subprocess.TimeoutExpired, Exception):
        return []

    filtered = []
    for line in lines:
        if any(ex in line for ex in EXCLUDE_PATHS):
            continue
        filtered.append(line)
    return filtered[:8]


def check_item(item: dict) -> dict | None:
    """Pruefe ein Sprint-Item. Gibt Befund zurueck oder None wenn skip/clean."""
    horizont = (item.get("horizont") or "").upper()
    effort = (item.get("effort") or "").upper()

    if effort in SKIP_EFFORTS:
        return None
    if horizont in SKIP_HORIZONTS:
        return None

    title = item.get("title", "")
    keywords = extract_keywords(title)
    if not keywords:
        return None

    hits_per_keyword: dict[str, list[str]] = {}
    for kw in keywords:
        hits = grep_keyword(kw)
        if hits:
            hits_per_keyword[kw] = hits

    if not hits_per_keyword:
        return None

    # Cluster Pfade: distinct Files
    all_files = set()
    for hits in hits_per_keyword.values():
        all_files.update(hits)

    return {
        "item": item,
        "keywords": keywords,
        "hits_per_keyword": hits_per_keyword,
        "n_files": len(all_files),
    }


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: verify-first.py <cache.json>", file=sys.stderr)
        return 2

    cache_file = sys.argv[1]
    try:
        cache = json.load(open(cache_file))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"FEHLER: {e}", file=sys.stderr)
        return 2

    global_sprint = cache.get("verify", {}).get("globalSprint")
    if not global_sprint:
        print("WARN: Kein globalSprint im Cache.")
        return 0

    items = [i for i in cache.get("items", []) if i.get("sprint_nummer") == global_sprint]
    if not items:
        print("(Keine Items im aktuellen Sprint.)")
        return 0

    findings = []
    for it in items:
        result = check_item(it)
        if result:
            findings.append(result)

    print(f"── verify-first ── ({len(items)} Items geprueft, {len(findings)} flagged)")
    if not findings:
        print("✅ Keine bestehende Logik erkannt — Implementation kann starten.")
        return 0

    print("⚠️  VERIFY-FIRST: bestehende Logik moeglich — VOR Implementation pruefen!\n")
    for f in findings:
        item = f["item"]
        print(f"  {item['backlog_id']} | {item['title'][:60]}")
        print(f"    Keywords: {', '.join(f['keywords'])}")
        print(f"    Treffer in {f['n_files']} Files (max 8 angezeigt):")
        seen_files = set()
        for kw, hits in f["hits_per_keyword"].items():
            for h in hits:
                if h in seen_files:
                    continue
                seen_files.add(h)
                if len(seen_files) > 8:
                    break
                # Kurze Pfad-Darstellung
                short = h.replace(os.path.expanduser("~"), "~")
                print(f"      [{kw}] {short}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
