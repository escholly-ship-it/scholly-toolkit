#!/bin/bash
# Phase-Gate (Plugin-Version): Blockiert Phasen-Uebergaenge wenn Pflicht-Marker fehlen.
#
# Typ: PreToolUse (Edit|Write) mit if-Filter auf **/.sprint-phases* (Sprint 152 CC-98).
# Mechanismus: exit 2 + stderr → blockiert NUR diesen Write, nicht die Session.
#
# CC-141 (Sprint 166): An session-isolierte Marker angeglichen. Mirror zu
# ~/.claude/hooks/phase-gate.sh — muss semantisch identisch bleiben.
#
# Marker-Verzeichnis: $MARKERS_DIR (session-spezifisch seit CC-96 Sprint 148)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty' 2>/dev/null)

# Defense-in-Depth: Nur bei .sprint-phases eingreifen
if ! echo "$FILE_PATH" | grep -q 'sprint-phases'; then
  exit 0
fi

NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

# shellcheck disable=SC1091
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/session-paths.sh" "$INPUT"
TTL=360

marker_exists() {
  local marker="$1"
  [ -f "$MARKERS_DIR/$marker" ] && [ -n "$(find "$MARKERS_DIR/$marker" -mmin -$TTL 2>/dev/null)" ]
}

check() {
  local marker="$1" label="$2" action="$3"
  if ! marker_exists "$marker"; then
    echo "GATE BLOCKIERT — $label fehlt. $action Dann: mkdir -p $MARKERS_DIR && echo done > $MARKERS_DIR/$marker — PFLICHT-ANTWORT AN SCHOLLY: ⚠️ Phase-Gate blockiert: $label. Was ich jetzt tue: $action" >&2
    exit 2
  fi
}

# === PHASE A ===
if echo "$NEW_CONTENT" | grep -q 'A=done'; then
  check "a-arbeitsregeln" "Arbeitsregeln lesen"           "Read(arbeitsregeln.md) in 4 Teilen."
  check "a-backlog"       "Backlog lesen+verifizieren"     "Backlog lesen, jedes Item pruefen, veraltete bereinigen."
  check "a-experten"      "Experten-Team+Research-Check"   "Team zusammenstellen, Pflicht-Aktivierungen, Research-Datum pruefen."
  check "a-agent-teams"   "Agent-Teams-Check (R42)"        "Sichtbare Ja/Nein-Tabelle im Output."
  check "a-deliverables"  "Deliverables-Tabelle (R45)"     "Konkrete Lieferobjekte auflisten."
  check "a-version"       "Version-Check (R43)"            "claude --version ausfuehren."
  check "a-devops"        "DevOps-Checkpoint"              "Infrastruktur-Checkliste durchgehen."
  check "a-techdebt"      "Tech-Debt-Check (Regel 4)"      "Projekt-Backlog nach [TECH-DEBT] scannen, TODO/FIXME zaehlen. Escape: echo skip > ~/Cowork/.phase-markers/.skip-regel4"
  check "a-watch-triggers" "Watch-Trigger-Check (Regel 94)" "memory/watch-triggers.md prueft Aktivierungs-Bedingungen + Review-Ablauf."
fi

if echo "$NEW_CONTENT" | grep -q 'B=done'; then
  check "b-ideation" "Ideation dokumentiert" "Loesungsansatz skizzieren, mit Scholly abstimmen."
fi

if echo "$NEW_CONTENT" | grep -q 'C=done'; then
  check "c-planning" "Planning abgeschlossen" "Dateien identifizieren, Design-Gate pruefen, Reihenfolge+Risiken."
fi

if echo "$NEW_CONTENT" | grep -qE 'D=done|D=in_progress'; then
  STATE_FILE="$PHASES_FILE"
  CURRENT_B=$(grep '^B=' "$STATE_FILE" 2>/dev/null | cut -d= -f2)
  CURRENT_C=$(grep '^C=' "$STATE_FILE" 2>/dev/null | cut -d= -f2)
  B_OK_IN_EDIT=$(echo "$NEW_CONTENT" | grep -qE '^B=(done|skipped)$' && echo 1 || echo 0)
  C_OK_IN_EDIT=$(echo "$NEW_CONTENT" | grep -qE '^C=(done|skipped)$' && echo 1 || echo 0)
  if [ "$CURRENT_B" != "done" ] && [ "$CURRENT_B" != "skipped" ] && [ "$B_OK_IN_EDIT" = "0" ]; then
    echo "GATE BLOCKIERT — Phase B (Planning) ist PFLICHT und nicht abgeschlossen." >&2
    exit 2
  fi
  if [ "$CURRENT_C" != "done" ] && [ "$CURRENT_C" != "skipped" ] && [ "$C_OK_IN_EDIT" = "0" ]; then
    echo "GATE BLOCKIERT — Phase C (Konzept) ist PFLICHT und nicht abgeschlossen." >&2
    exit 2
  fi
  if echo "$NEW_CONTENT" | grep -q 'D=in_progress'; then
    check "a-research-completed" "Experten-Weiterbildung (Regel 53)" "Alle faelligen Experten muessen Research abschliessen BEVOR Phase D startet."
  fi
fi

if echo "$NEW_CONTENT" | grep -q 'D=done'; then
  check "d-execution" "Execution abgeschlossen" "Alle Deliverables implementiert. Regel 25: Erkenntnisse in Experten-Memory."
fi

# CC-219 (Sprint 193): SPRINT_TYPE=prozess in .sprint-phases uebersteuert Build/Testing/Deploy-Marker.
if echo "$NEW_CONTENT" | grep -q 'E=done'; then
  SPRINT_TYPE=$(grep '^SPRINT_TYPE=' "$PHASES_FILE" 2>/dev/null | cut -d= -f2)
  if [ "$SPRINT_TYPE" = "prozess" ]; then
    for m in e-build e-testing e-deploy; do
      [ -f "$MARKERS_DIR/$m" ] || echo "sprint-type=prozess (auto-accept)" > "$MARKERS_DIR/$m"
    done
  fi
  check "e-build"        "Build/Lint verifiziert"       "Schritt 1: npx tsc --noEmit + npm run build fehlerfrei."
  check "e-testing"      "Testing Mobile-First"         "Schritt 3: Features testen, 375px Viewport, Regressions-Check."
  check "e-deploy"       "Deploy-Verify"                "Schritt 4: /deploy-verify — Production-URL + Health-Check."
  check "e-abnahme"      "Kunden-Abnahme (R47)"         "Schritt 5: Ergebnis Scholly praesentieren, auf Feedback warten."
  check "e-doku-backup"  "Doku+Backup (Memory-Index)"   "Schritt 6: Memory-Index aktualisieren, Recovery-Note pruefen, GitHub Backup (NACH Abnahme)."
fi

if echo "$NEW_CONTENT" | grep -q 'F=done'; then
  check "f-experten" "Experten-Memories aktualisiert" "Lernzyklus fuer JEDEN aktivierten Experten (Regel 25)."
  check "f-quality"  "Memory Quality Delta"            "memory-health.sh ausfuehren, Composite Score gegen Baseline vergleichen."
  check "f-retro"    "Retro in retros.md"              "Reflektieren + in retros.md persistieren."
fi

if echo "$NEW_CONTENT" | grep -q 'G=done'; then
  check "g-notion"       "Notion Projektseite+Hub"             "Notion Konzeptseite UND Projekte-Hub aktualisieren."
  check "g-backlog"      "Backlog aktualisiert"                "Erledigte Items raus, neue Items rein, Kunden-Feedback verarbeitet."
  check "g-e2e-verified" "End-to-End-Verifikation (Regel 87)"  "bash ~/Cowork/scripts/verify-sprint-end.sh — Counter, 0 Items, Board sauber, Sprints gepackt."
  check "g-backup"       "GitHub-Backup"                       "claude-config + cowork Repos pushen (Regel 26)."
fi

exit 0
