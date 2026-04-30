#!/bin/bash
# CC-382-EXT (Sprint 246): Phase-Self-Validator
#
# Cloud-Migration-Vorbereitung: Skills enforcen Phase-Transitions ohne Hook-Abhaengigkeit.
# Wird am ENDE jeder Phase vom Skill aufgerufen. Gibt exit 1 zurueck wenn
# Pflicht-Schritte fehlen — Claude MUSS dann nachbessern.
#
# Universell — funktioniert lokal (mit Markers) UND in Cloud-Sessions
# (wo Markers in Cloud-Storage liegen).
#
# Usage:
#   validate-phase.sh A   # validiert Phase-A-Abschluss
#   validate-phase.sh D   # validiert Phase-D-Abschluss
#
# Exit-Codes:
#   0 = Phase sauber abgeschlossen
#   1 = Pflicht-Schritte fehlen — Claude muss nachbessern
#   2 = Fataler Fehler (kein Sprint-Tag, kein State-File)

set -uo pipefail

PHASE="${1:-}"
[ -z "$PHASE" ] && { echo "Usage: $0 <A|B|C|D|E|F|G>" >&2; exit 2; }

PHASE_LOWER=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')

SPRINT_TAG=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null | tr -d '[:space:]')
[ -z "$SPRINT_TAG" ] && { echo "FATAL: Keine Session-ID" >&2; exit 2; }

MARKERS_DIR="$HOME/Cowork/.phase-markers/$SPRINT_TAG"
PHASES_FILE="$HOME/Cowork/.sprint-phases-$SPRINT_TAG"
[ ! -f "$PHASES_FILE" ] && { echo "FATAL: Kein State-File $PHASES_FILE" >&2; exit 2; }

ERRORS=()

# Phase-spezifische Marker-Anforderungen
declare -A REQUIRED_MARKERS
REQUIRED_MARKERS[A]="a-arbeitsregeln a-backlog a-git-status a-hygiene a-techdebt a-deps a-deliverables a-experten a-version a-agent-teams"
REQUIRED_MARKERS[B]="b-ideation"
REQUIRED_MARKERS[C]="c-planning"
REQUIRED_MARKERS[D]="d-execution"
REQUIRED_MARKERS[E]="e-debug e-refactor e-testing e-doku-backup e-deploy e-abnahme"
REQUIRED_MARKERS[F]="f-personas f-retro"
REQUIRED_MARKERS[G]="g-backlog g-handover g-findings"

# 1. Marker-Check
markers_needed="${REQUIRED_MARKERS[$PHASE]:-}"
for marker in $markers_needed; do
  if [ ! -f "$MARKERS_DIR/$marker" ]; then
    ERRORS+=("Marker fehlt: $marker")
  fi
done

# 2. State-File-Check
state_val=$(grep "^${PHASE}=" "$PHASES_FILE" | cut -d= -f2)
if [ "$state_val" != "done" ] && [ "$state_val" != "skipped" ]; then
  ERRORS+=("State-File: ${PHASE}=${state_val:-leer} (erwartet: done|skipped)")
fi

# 3. Telegram-Push-Marker-Check (CC-382-EXT, korrigiert: NUR A, E, G)
# Scholly Sprint 246 Klarstellung: Communication NUR an Sprint-Goal-Bestaetigung,
# Review-Abnahme, Sprint-End-Zusammenfassung. Phasen B/C/D/F sind silent.
case "$PHASE" in
  A|E|G)
    if [ ! -f "$MARKERS_DIR/${PHASE_LOWER}-notified" ]; then
      ERRORS+=("Telegram-Push fehlt: $MARKERS_DIR/${PHASE_LOWER}-notified — phase-transition-notify.sh $PHASE \"<msg>\" aufrufen")
    fi
    ;;
  B|C|D|F)
    # Bewusst silent — keine Telegram-Pflicht
    ;;
esac

# 4. Phase-spezifische Zusatz-Checks
case "$PHASE" in
  D)
    # Phase D: Wenn Code-Repos dirty → Commit fehlt
    SPRINT_TYPE=$(grep "^SPRINT_TYPE=" "$PHASES_FILE" | cut -d= -f2 || echo "code")
    if [ "$SPRINT_TYPE" != "prozess" ] && [ "$SPRINT_TYPE" != "memory-only" ]; then
      for repo in ~/projects/roadmap ~/.claude; do
        if [ -d "$repo/.git" ]; then
          if [ -n "$(cd "$repo" && git status --porcelain 2>/dev/null | grep -E '^[MA]')" ]; then
            ERRORS+=("Phase D: Repo $repo hat uncommitted Code-Aenderungen → vor /sprint-review committen")
          fi
        fi
      done
    fi
    ;;
  E)
    # Phase E muss Kunden-Abnahme erteilt haben (e-abnahme Marker mit "ok"-Inhalt)
    if [ -f "$MARKERS_DIR/e-abnahme" ]; then
      content=$(cat "$MARKERS_DIR/e-abnahme")
      if [ "$content" != "ok" ] && [ "$content" != "done" ]; then
        ERRORS+=("Phase E: Kunden-Abnahme-Marker hat Inhalt '$content' (erwartet: 'ok' oder 'done')")
      fi
    fi
    ;;
esac

# Output
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo "✅ Phase $PHASE sauber abgeschlossen — Marker + State-File + Telegram-Push komplett"
  exit 0
fi

echo "🛑 Phase $PHASE NICHT sauber abgeschlossen — fehlende Pflicht-Schritte:"
for err in "${ERRORS[@]}"; do
  echo "  - $err"
done
echo ""
echo "→ Claude MUSS jetzt die fehlenden Schritte ausfuehren. Phase darf nicht als done gelten."
exit 1
