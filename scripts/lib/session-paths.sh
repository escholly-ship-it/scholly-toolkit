#!/bin/bash
# Session-Paths Helper (Plugin-Version) — Liefert session-spezifische Marker/Phases-Pfade.
# CC-141 (Sprint 166): Plugin-Scheme Hook an Session-isolierte Marker angleichen.
# Mirror zu ~/.claude/hooks/lib/session-paths.sh — muss identisch bleiben.
#
# Usage in Plugin-Hooks:
#   INPUT=$(cat)
#   source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/session-paths.sh" "$INPUT"
#   # nun gesetzt: SESSION_ID, MARKERS_DIR, PHASES_FILE, SESSION_MODE
#
# Detection-Reihenfolge:
#   1. stdin-JSON session_id (Hooks bekommen das von Claude Code)
#   2. CLAUDE_SESSION_ID env-var (Zukunftssicherung)
#   3. ~/Cowork/.current-sprint-tag (Skill-Bruecke, von sprint-start gesetzt)

_stdin_json="${1:-}"
SESSION_ID=""

if [ -n "$_stdin_json" ]; then
  SESSION_ID=$(echo "$_stdin_json" | jq -r '.session_id // empty' 2>/dev/null)
fi

if [ -z "$SESSION_ID" ] && [ -n "${CLAUDE_SESSION_ID:-}" ]; then
  SESSION_ID="$CLAUDE_SESSION_ID"
fi

if [ -z "$SESSION_ID" ] && [ -f "$HOME/Cowork/.current-sprint-tag" ]; then
  SESSION_ID=$(cat "$HOME/Cowork/.current-sprint-tag" 2>/dev/null | tr -d '[:space:]')
fi

if [ -z "$SESSION_ID" ]; then
  echo "session-paths.sh: FATAL — keine Session-ID (stdin, env, current-sprint-tag alle leer)" >&2
  return 1 2>/dev/null || exit 1
fi

SESSION_MODE="isolated"
MARKERS_DIR="$HOME/Cowork/.phase-markers/$SESSION_ID"
PHASES_FILE="$HOME/Cowork/.sprint-phases-$SESSION_ID"

export SESSION_ID SESSION_MODE MARKERS_DIR PHASES_FILE
