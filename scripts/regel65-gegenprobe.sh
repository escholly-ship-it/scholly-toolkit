#!/bin/bash
# Regel 65: Erledigt-Markierung NUR nach Gegenprobe (CC-27, Sprint 117; CC-144 Sprint 168 Diff-Analyse; CC-164 Sprint 174 Set-Diff)
# CC-188 (Sprint 188): Single Source of Truth im Plugin — `~/.claude/hooks/regel65-gegenprobe.sh` entfernt.
# PreToolUse Hook auf Edit|Write (via scholly-toolkit/hooks/hooks.json).
# Erkennt wenn Items als "erledigt" markiert werden und blockiert wenn
# keine technische Gegenprobe (grep/ls/curl/screenshot) in dieser Session stattfand.
#
# CC-144 Fix (Sprint 168): Bei Edit werden Pattern-Treffer nur gezaehlt, wenn sie in
# HINZUGEFUEGTEN Zeilen auftauchen (new_string minus old_string). Keyword-Vorkommen in
# blossem Kontext (z.B. "## Erledigt" als Anker-Ueberschrift) loest nicht aus.
#
# CC-164 Fix (Sprint 174): Set-Diff via `comm` statt `diff` — Archive-Sweeps die Erledigt-
# Zeilen nur UMORDNEN (oder einzelne entfernen) erzeugen sonst falsche Trigger, weil `diff`
# verschobene Zeilen als "added" (^>) klassifiziert. Set-Diff (Zeilen-Multiset) triggert nur
# bei echten Neu-Zeilen.
#
# Witness-TTL: 10 Minuten. Exit 0 = OK, Exit 2 = blockiert mit PFLICHT-ANTWORT.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty' 2>/dev/null)

# Session-spezifische Pfade (CC-96 Sprint 148)
source "${CLAUDE_PLUGIN_ROOT:-/Users/scholly/Cowork/scholly-toolkit}/scripts/lib/session-paths.sh" "$INPUT"

# Escape-Hatch: .skip-regel65 juenger als 30 Min
SKIP_FILE="/Users/scholly/Cowork/.phase-markers/.skip-regel65"
if [ -f "$SKIP_FILE" ]; then
  SKIP_AGE=$(find "$SKIP_FILE" -mmin -30 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SKIP_AGE" -gt 0 ]; then
    exit 0
  fi
  rm -f "$SKIP_FILE"
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)

# Nur bei relevanten Dateien triggern
TRIGGER=false

# Completion-Gate Phase-Marker (immer triggern — keine Diff-Logik noetig)
if echo "$FILE_PATH" | grep -qE 'phase-markers/(g-notion|g-backlog|roadmap-sync|roadmap-backlog-check)$'; then
  TRIGGER=true
fi

# Backlog-Datei mit Erledigt-Markierung — Diff-Analyse
if echo "$FILE_PATH" | grep -q 'backlog-.*\.md$'; then
  # Pattern: klassische Erledigt-Marker
  PATTERN='~~.*~~|\[x\]|✅|erledigt|abgeschlossen|^done$|geloescht|entfernt|migriert'

  if [ "$TOOL_NAME" = "Edit" ] && [ -n "$NEW_STRING" ]; then
    # Set-Diff-Analyse (CC-164): Nur Zeilen die in new_string ECHT neu sind (nicht im Multiset von old_string).
    # `comm -13` auf sortierten Listen ignoriert Reorderings → Archive-Sweeps triggern nicht mehr falsch.
    NEW_LINES=$(comm -13 <(printf '%s\n' "$OLD_STRING" | sort) <(printf '%s\n' "$NEW_STRING" | sort))
    if [ -n "$NEW_LINES" ] && echo "$NEW_LINES" | grep -qiE "$PATTERN"; then
      TRIGGER=true
    fi
  elif [ "$TOOL_NAME" = "Write" ] && [ -n "$CONTENT" ]; then
    # Write = neue Datei oder komplettes Overwrite: ganzen Inhalt pruefen
    if echo "$CONTENT" | grep -qiE "$PATTERN"; then
      TRIGGER=true
    fi
  fi
fi

# Nicht getriggert → durchlassen
[ "$TRIGGER" = "false" ] && exit 0

# Witness-Datei pruefen (10 Minuten TTL) — Session-isoliert (Legacy-Fallback entfernt in CC-158 Sprint 171)
WITNESS_SESSION="$MARKERS_DIR/.regel65-verified"
if [ -f "$WITNESS_SESSION" ]; then
  FRESH=$(find "$WITNESS_SESSION" -mmin -10 2>/dev/null | wc -l | tr -d ' ')
  if [ "$FRESH" -gt 0 ]; then
    exit 0  # Gegenprobe kuerzlich durchgefuehrt
  fi
fi

# Blockieren: Keine frische Gegenprobe
echo "STOPP — Regel 65: Erledigt-Markierung ohne Gegenprobe! PFLICHT-ANTWORT: Bevor dieses Item als erledigt markiert werden darf, MUSS eine technische Gegenprobe erfolgen: Migration → grep -r ueber betroffene Dateien. Cleanup → ls/find bestaetigen. Feature → API-Call/Screenshot/Preview. Nach der Gegenprobe: mkdir -p $MARKERS_DIR && echo done > $MARKERS_DIR/.regel65-verified — Escape: echo skip > ~/Cowork/.phase-markers/.skip-regel65" >&2
exit 2
