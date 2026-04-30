#!/bin/bash
# End-to-End-Verifikation fuer Sprint-Ende (Regel 87, Sprint 115, migriert CC-25b Sprint 117)
# Prueft 4 technische Bedingungen BEVOR G=done gesetzt werden darf.
# Erstellt Marker ~/Cowork/.phase-markers/g-e2e-verified NUR wenn alle 4 bestehen.
#
# Aufruf: bash ~/.claude/hooks/verify-sprint-end.sh
# Exit 0 = alle Checks bestanden, Marker gesetzt
# Exit 1 = mindestens 1 Check fehlgeschlagen, kein Marker
#
# Wird technisch erzwungen durch phase-gate.sh (G=done blockiert ohne g-e2e-verified)

set -euo pipefail

MARKER_DIR="/Users/scholly/Cowork/.phase-markers"
GLOBAL_FILE="/Users/scholly/Cowork/.sprint-global"
SPRINT_PHASES="/Users/scholly/Cowork/.sprint-phases"

# GitHub Projects Config
source /Users/scholly/Cowork/scripts/gh-project-config.sh

# Beendeten Sprint aus .sprint-phases lesen
ENDED_SPRINT=$(grep '^sprint=' "$SPRINT_PHASES" 2>/dev/null | cut -d= -f2)
if [ -z "$ENDED_SPRINT" ]; then
  echo "❌ CHECK 0: Kein Sprint in .sprint-phases"
  exit 1
fi

GLOBAL_SPRINT=$(cat "$GLOBAL_FILE" 2>/dev/null | tr -d '[:space:]')
ERRORS=0

echo "=== End-to-End-Verifikation Sprint $ENDED_SPRINT ==="
echo ""

# CHECK 1: Counter muss > beendeter Sprint sein
echo "CHECK 1: Counter hochgezaehlt?"
if [ "$GLOBAL_SPRINT" -gt "$ENDED_SPRINT" ] 2>/dev/null; then
  echo "  ✅ Global=$GLOBAL_SPRINT > Beendet=$ENDED_SPRINT"
else
  echo "  ❌ Global=$GLOBAL_SPRINT <= Beendet=$ENDED_SPRINT — Counter NICHT hochgezaehlt!"
  ERRORS=$((ERRORS + 1))
fi

# CHECK 2: 0 Items im beendeten Sprint
echo "CHECK 2: 0 Items im beendeten Sprint?"
ITEMS_IN_ENDED=$(gh project item-list "$GH_PROJECT_NUMBER" --owner "$GH_PROJECT_OWNER" --format json --limit 500 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
ended = 'Sprint $ENDED_SPRINT'
count = sum(1 for i in data.get('items', []) if i.get('sprint', i.get('Sprint', '')) == ended)
print(count)
")

if [ "$ITEMS_IN_ENDED" = "0" ]; then
  echo "  ✅ Sprint $ENDED_SPRINT: 0 Items"
else
  echo "  ❌ Sprint $ENDED_SPRINT: $ITEMS_IN_ENDED Items noch vorhanden!"
  ERRORS=$((ERRORS + 1))
fi

# CHECK 3: Keine leeren vergangenen Sprint-Spalten (Board sauber)
echo "CHECK 3: Board sauber (keine leeren vergangenen Spalten)?"
SPRINT_OPTIONS=$(gh api graphql -f query="
  query {
    node(id: \"$GH_PROJECT_ID\") {
      ... on ProjectV2 {
        field(name: \"Sprint\") {
          ... on ProjectV2SingleSelectField {
            options { id name }
          }
        }
      }
    }
  }" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
opts = data['data']['node']['field']['options']
for o in opts:
    print(o['name'])
")

ALL_ITEMS_SPRINTS=$(gh project item-list "$GH_PROJECT_NUMBER" --owner "$GH_PROJECT_OWNER" --format json --limit 500 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for i in data.get('items', []):
    s = i.get('sprint', i.get('Sprint', ''))
    if s:
        print(s)
")

EMPTY_PAST=$(python3 -c "
import sys
schema = '''$SPRINT_OPTIONS'''.strip().split('\n')
items = '''$ALL_ITEMS_SPRINTS'''.strip().split('\n')
global_sprint = $GLOBAL_SPRINT
counts = {}
for s in items:
    s = s.strip()
    if s:
        counts[s] = counts.get(s, 0) + 1
empty = []
for opt in schema:
    opt = opt.strip()
    if not opt or opt == 'Backlog':
        continue
    try:
        num = int(opt.replace('Sprint ', ''))
        if num < global_sprint and counts.get(opt, 0) == 0:
            empty.append(opt)
    except ValueError:
        pass
print(len(empty))
if empty:
    print(','.join(empty), file=sys.stderr)
" 2>&1)

EMPTY_COUNT=$(echo "$EMPTY_PAST" | head -1)
if [ "$EMPTY_COUNT" = "0" ]; then
  echo "  ✅ Keine leeren vergangenen Sprint-Spalten"
else
  echo "  ❌ $EMPTY_COUNT leere vergangene Spalte(n): $(echo "$EMPTY_PAST" | tail -1)"
  ERRORS=$((ERRORS + 1))
fi

# CHECK 4: GENAU 5 Sprints gepackt (Regel 66 — 5-Sprint-Regel)
echo "CHECK 4: 5 Sprints gepackt?"
SPRINT_COUNT=$(echo "$SPRINT_OPTIONS" | grep -c "^Sprint " || true)
if [ "$SPRINT_COUNT" -ge 5 ]; then
  echo "  ✅ $SPRINT_COUNT Sprints gepackt"
elif [ "$SPRINT_COUNT" -ge 3 ]; then
  echo "  ⚠️ Nur $SPRINT_COUNT Sprints (Ziel: 5). Akzeptiert NUR wenn Backlog keine actionable Items hat."
  echo "     Pruefen: Gibt es Items im Backlog die in einen Sprint gepackt werden koennten?"
  ERRORS=$((ERRORS + 1))
else
  echo "  ❌ Nur $SPRINT_COUNT Sprint(s) gepackt (Minimum: 5)"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# ERGEBNIS
if [ "$ERRORS" -eq 0 ]; then
  echo "=== ALLE 4 CHECKS BESTANDEN ✅ ==="
  mkdir -p "$MARKER_DIR"
  echo "done" > "$MARKER_DIR/g-e2e-verified"
  echo "Marker g-e2e-verified gesetzt."
  exit 0
else
  echo "=== $ERRORS CHECK(S) FEHLGESCHLAGEN ❌ ==="
  echo "G=done ist BLOCKIERT bis alle Checks bestehen."
  echo "Kein Marker gesetzt."
  rm -f "$MARKER_DIR/g-e2e-verified"
  exit 1
fi
