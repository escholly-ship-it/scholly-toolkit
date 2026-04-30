#!/bin/bash
# SessionStart Hook — Automatisch Kontext laden (CC-18, Sprint 84)
# Lädt letzte Retro-Einträge + Dream Engine Flags bei Session-Start.
# CC-96 Sprint 148: Session-ID aus stdin capture fuer Multi-Session-Isolation.

# Session-ID aus stdin JSON (falls von Claude Code geliefert) persistieren
INPUT=$(cat 2>/dev/null || echo "")
if [ -n "$INPUT" ]; then
    SID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$SID" ]; then
        # Per-Session Marker-Dir + Phases-File vorbereiten
        mkdir -p "$HOME/Cowork/.phase-markers/$SID" 2>/dev/null
        # Aktuelle Session-Tag setzen (Skill-Brücke)
        echo "$SID" > "$HOME/Cowork/.current-sprint-tag"
    fi
fi

MEMORY_DIR="/Users/scholly/.claude/projects/-Users-scholly/memory"

echo "=== SESSION-KONTEXT (automatisch geladen) ==="

# Schicht 1: Verhaltensregeln (IMMER aktiv, CC-42 Sprint 154)
# CC-210 Sprint 192: Titel-Liste statt Volltext — Regeln werden on-demand gelesen.
VERHALTENSREGELN="${MEMORY_DIR}/verhaltensregeln.md"
if [ -f "$VERHALTENSREGELN" ]; then
    echo ""
    echo "--- Verhaltensregeln (Schicht 1 — IMMER, Volltext: verhaltensregeln.md) ---"
    grep -E '^## Regel' "$VERHALTENSREGELN" | sed 's/^## /  /'
fi

# Letzte Retro-Kurzzeile (CC-210 Sprint 192: 1 Header + 3 Zeilen statt tail -20)
RETROS="${MEMORY_DIR}/retros.md"
if [ -f "$RETROS" ]; then
    echo ""
    echo "--- Letzter Retro ---"
    # Retros.md ist reverse-chron (neueste zuerst). Ersten "## Sprint N" + 3 Folgezeilen.
    awk '/^## Sprint/ {found=1; count=0} found && count<4 {print; count++} found && count>=4 {exit}' "$RETROS"
fi

# Dream Engine Flags (CC-210 Sprint 192: Anzahl + Kategorien, Details bei Bedarf in dream-engine.md)
DREAM="${MEMORY_DIR}/dream-engine.md"
if [ -f "$DREAM" ]; then
    FLAG_COUNT=$(grep -cEi "flag|warning|ACHTUNG|SCHOLLY" "$DREAM" 2>/dev/null || echo 0)
    if [ "$FLAG_COUNT" -gt 0 ]; then
        echo ""
        echo "--- Dream Engine Flags: ${FLAG_COUNT} (Details: dream-engine.md) ---"
    fi
fi

# === TELEGRAM GUARD (Sprint 122) ===
# Telegram-Plugin darf NUR in ~/Cowork/.claude/settings.local.json stehen (lokal).
# In der globalen settings.json darf es NICHT stehen (sonst spawnt jede Desktop-Session einen Poller).
if grep -q '"telegram@claude-plugins-official"' /Users/scholly/.claude/settings.json 2>/dev/null; then
    echo ""
    echo "🚨 TELEGRAM GUARD: telegram in GLOBALER settings.json gefunden!"
    echo "   Darf NUR in ~/Cowork/.claude/settings.local.json stehen."
    echo "   → Entferne es SOFORT aus ~/.claude/settings.json"
fi

# === EFFORT-LEVEL EMPFEHLUNG (Sprint 136) ===
# Zeigt aktuellen Effort-Level und erinnert an /effort Kommando
CURRENT_EFFORT="${CLAUDE_CODE_EFFORT_LEVEL:-mittel}"
echo ""
echo "--- Effort-Level ---"
echo "Aktuell: ${CURRENT_EFFORT} | Aendern: /effort low|medium|high|max"
echo "Empfehlung: Claude wird bei Sprint-Start passenden Level vorschlagen."

# Globaler Sprint-Counter
GLOBAL_SPRINT=$(cat /Users/scholly/Cowork/.sprint-global 2>/dev/null)
if [ -n "$GLOBAL_SPRINT" ]; then
    echo ""
    echo "Globaler Sprint: ${GLOBAL_SPRINT}"
fi

# 2026-04-19 Housekeeping: Silent-Stop-Marker aelter als 30 Minuten loeschen.
# Ein Sprint = Session ≈ 15-30 Min (Scholly-Korrektur 2026-04-19) — Marker aus
# beendeten Sessions sind danach stale. 30 Min schuetzt parallel laufende
# Sessions (deren Marker frisch bleibt). Per-Session-Dedup via SESSION_TAG.
find "$HOME/Cowork" -maxdepth 1 -name ".silent-stop-sent-*" -type f -mmin +30 -delete 2>/dev/null

echo "=== ENDE SESSION-KONTEXT ==="
