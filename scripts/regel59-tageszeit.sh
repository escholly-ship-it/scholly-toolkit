#!/bin/bash
# Regel 59: Tageszeit-Check vor zeitabhaengigem Text (CC-27, Sprint 117)
# PreToolUse Hook auf Edit|Write
# Scannt neuen Content nach Tageszeit-Greetings und validiert gegen Systemzeit.
# Exit 0 = OK, Exit 2 = blockiert mit PFLICHT-ANTWORT.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty' 2>/dev/null)

# Code-Dateien sofort durchlassen (Performance: <1ms)
if echo "$FILE_PATH" | grep -qE '\.(ts|tsx|js|jsx|py|sh|json|yaml|yml|css|scss|lock|toml|cfg|ini|sql)$'; then
  exit 0
fi

# Escape-Hatch: .skip-regel59 juenger als 30 Min
SKIP_FILE="/Users/scholly/Cowork/.phase-markers/.skip-regel59"
if [ -f "$SKIP_FILE" ]; then
  SKIP_AGE=$(find "$SKIP_FILE" -mmin -30 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SKIP_AGE" -gt 0 ]; then
    exit 0
  fi
  rm -f "$SKIP_FILE"
fi

NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

# Kein Content → durchlassen
[ -z "$NEW_CONTENT" ] && exit 0

# Tageszeit-Patterns erkennen (case-insensitive)
FOUND=""
if echo "$NEW_CONTENT" | grep -qiE 'Guten Morgen|Good Morning|Schoenen Morgen|Schönen Morgen'; then
  FOUND="MORGEN"
elif echo "$NEW_CONTENT" | grep -qiE 'Guten Abend|Good Evening|Schoenen Abend|Schönen Abend'; then
  FOUND="ABEND"
elif echo "$NEW_CONTENT" | grep -qiE 'Gute Nacht|Good Night|Schlaf gut'; then
  FOUND="NACHT"
elif echo "$NEW_CONTENT" | grep -qiE 'Schoenen Feierabend|Schönen Feierabend|Schoenen Nachmittag|Schönen Nachmittag'; then
  FOUND="NACHMITTAG"
fi

# Kein Tageszeit-Pattern → durchlassen
[ -z "$FOUND" ] && exit 0

# Gegen Systemzeit validieren
HOUR=$(date '+%H' | sed 's/^0//')

VALID=true
case "$FOUND" in
  MORGEN)      [ "$HOUR" -lt 5 ] || [ "$HOUR" -ge 12 ] && VALID=false ;;
  NACHMITTAG)  [ "$HOUR" -lt 12 ] || [ "$HOUR" -ge 18 ] && VALID=false ;;
  ABEND)       [ "$HOUR" -lt 17 ] || [ "$HOUR" -ge 23 ] && VALID=false ;;
  NACHT)       [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 21 ] && VALID=false ;;
esac

if [ "$VALID" = "false" ]; then
  NOW=$(date '+%H:%M')
  echo "STOPP — Regel 59: Tageszeit-Gruss '$FOUND' um $NOW ist falsch! PFLICHT-ANTWORT: Tageszeit-abhaengigen Text entfernen oder korrigieren. Aktuelle Uhrzeit: $NOW. Zeitneutral formulieren oder passenden Gruss waehlen. Escape: echo skip > ~/Cowork/.phase-markers/.skip-regel59" >&2
  exit 2
fi

exit 0
