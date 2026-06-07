#!/usr/bin/env bash
# lane-drift-scan/scripts/scan.sh — finde status=done Items ohne _archived-log Eintrag
# Lane 2026-05-22 (CC-CROSS-LANE-DRIFT-SCAN), SV4 2026-05-26: detection-only — Archivierung via /lane <name> auto-fix-all (LLM-nativ)

set -uo pipefail
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Cowork/wiki/projects}"
ARCHIVE_LOG="$PROJECTS_DIR/_archived-log.md"

total_drift=0

for f in "$PROJECTS_DIR"/*-backlog.md; do
  [ "$(basename "$f")" = "_archived-log.md" ] && continue
  project=$(grep "^project:" "$f" | head -1 | sed 's/^project: *//')
  # Items: ## <id> — ... + folgender yaml mit status: done
  awk -v archive="$ARCHIVE_LOG" -v project="$project" '
    /^## / { id=$2; in_yaml=0; status="" }
    /^```yaml$/ { in_yaml=1; next }
    /^```$/ {
      if (in_yaml && status=="done" && id != "") {
        # Check ob id in archive-log
        cmd = "grep -c \"^## .* — " id " \" \"" archive "\" 2>/dev/null"
        cmd | getline archived
        close(cmd)
        if (archived == 0 || archived == "") {
          print project "|" id
        }
      }
      in_yaml=0
    }
    in_yaml && /^status:/ { status=$2 }
  ' "$f"
done | while IFS='|' read -r project id; do
  if [ -n "$id" ]; then
    total_drift=$((total_drift + 1))
    echo "DRIFT: $project · $id"
  fi
done

echo ""
echo "--- Drift-Bilanz ---"
TOTAL=$(for f in "$PROJECTS_DIR"/*-backlog.md; do
  [ "$(basename "$f")" = "_archived-log.md" ] && continue
  awk -v archive="$ARCHIVE_LOG" '
    /^## / { id=$2; in_yaml=0; status="" }
    /^```yaml$/ { in_yaml=1; next }
    /^```$/ {
      if (in_yaml && status=="done" && id != "") {
        cmd = "grep -c \"^## .* — " id " \" \"" archive "\" 2>/dev/null"
        cmd | getline archived
        close(cmd)
        if (archived == 0 || archived == "") print id
      }
      in_yaml=0
    }
    in_yaml && /^status:/ { status=$2 }
  ' "$f"
done | wc -l | tr -d ' ')
echo "Total Drift-Items: $TOTAL"
echo "Threshold für Auto-Finding: 5"
if [ "$TOTAL" -gt 5 ]; then
  echo "→ Hausmeister sollte AUTO-F-lane-drift-Finding anlegen"
fi
