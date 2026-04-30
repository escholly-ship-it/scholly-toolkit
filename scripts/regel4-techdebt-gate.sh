#!/bin/bash
# Regel 4: Tech-Debt = Null VOR neuen Features (CC-27, Sprint 135)
# PreToolUse Hook auf Edit|Write
# Blockiert Phase-D-Start wenn kein Tech-Debt-Check in Phase A gelaufen ist.
# Der Check wird durch den Marker a-techdebt bestaetigt.
#
# Exit 0 = OK, Exit 2 = blockiert mit PFLICHT-ANTWORT.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty' 2>/dev/null)

# Nur triggern wenn .sprint-phases geschrieben wird und Phase D gesetzt werden soll
# ODER wenn phase-markers/d-* geschrieben wird
TRIGGER=false

if echo "$FILE_PATH" | grep -qE '\.sprint-phases$'; then
  NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
  if [ -n "$NEW_CONTENT" ] && echo "$NEW_CONTENT" | grep -qE '^D='; then
    TRIGGER=true
  fi
fi

# Nicht getriggert → durchlassen
[ "$TRIGGER" = "false" ] && exit 0

# Escape-Hatch
SKIP_FILE="/Users/scholly/Cowork/.phase-markers/.skip-regel4"
if [ -f "$SKIP_FILE" ]; then
  SKIP_AGE=$(find "$SKIP_FILE" -mmin -30 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SKIP_AGE" -gt 0 ]; then
    exit 0
  fi
  rm -f "$SKIP_FILE"
fi

# Tech-Debt-Marker pruefen
MARKER="/Users/scholly/Cowork/.phase-markers/a-techdebt"
if [ ! -f "$MARKER" ]; then
  echo "STOPP — Regel 4: Phase D kann nicht starten ohne Tech-Debt-Check! Der Marker a-techdebt fehlt. PFLICHT-ANTWORT: Zurueck zu Phase A → Tech-Debt-Check durchfuehren → Marker setzen. Escape: echo skip > ~/Cowork/.phase-markers/.skip-regel4" >&2
  exit 2
fi

exit 0
