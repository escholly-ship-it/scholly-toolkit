#!/bin/bash
# PreCompact Hook — Sprint-Kontext bei Context-Komprimierung bewahren (CC-17, Sprint 84)
# Gibt kritischen Sprint-Kontext als stdout zurück, der in die komprimierte Zusammenfassung einfließt.

MEMORY_DIR="/Users/scholly/.claude/projects/-Users-scholly/memory"
COWORK_DIR="/Users/scholly/Cowork"

# Sprint-Phases lesen (enthält Projekt + Sprint-Nr + aktuelle Phase)
PHASES_FILE="${COWORK_DIR}/.sprint-phases"

if [ ! -f "$PHASES_FILE" ]; then
    exit 0  # Kein aktiver Sprint — nichts zu bewahren
fi

PROJECT=$(grep '^project=' "$PHASES_FILE" | cut -d= -f2)
SPRINT=$(grep '^sprint=' "$PHASES_FILE" | cut -d= -f2)
CURRENT_PHASE=""
for phase in G F E D C B A; do
    val=$(grep "^${phase}=" "$PHASES_FILE" | cut -d= -f2)
    if [ "$val" = "done" ] || [ "$val" = "skipped" ]; then
        continue
    fi
    CURRENT_PHASE="$phase"
done

# Sprint-Kontext ausgeben — wird in die Komprimierung einbezogen
echo "=== SPRINT-KONTEXT (BEWAHREN) ==="
echo "Sprint: ${SPRINT} | Projekt: ${PROJECT} | Aktuelle Phase: ${CURRENT_PHASE:-abgeschlossen}"

# Deliverables aus .sprint-phases-Kontext (falls vorhanden)
CONTEXT_FILE="${COWORK_DIR}/.sprint-context"
if [ -f "$CONTEXT_FILE" ]; then
    echo ""
    cat "$CONTEXT_FILE"
fi

echo "=== ENDE SPRINT-KONTEXT ==="
