#!/usr/bin/env bash
# /cloud-smoke-test Helper — Sprint 263 (PAT-frei, API-basiert)
# Pruefte ehemals Filesystem-Pfade — jetzt nur HTTP-API-Endpoints.
#
# 6 Pflicht-Pruefungen:
#   Check 1: Slash-Menu Skill-Verfuegbarkeit (interaktiv, vom User zu pruefen)
#   Check 2: cloud-bootstrap.sh exit 0
#   Check 3: /api/verify HTTP 200
#   Check 4: /api/memory-read fuer kritische Files
#   Check 5: /api/sprint-cache GET
#   Check 6: PushNotification (interaktiv — nur Reminder)
#
# Usage: bash cloud-smoke-test.sh [--cloud|--local]
# Default: auto-detect.

set -uo pipefail

ROADMAP_API="${ROADMAP_API:-https://roadmap-escholly-ship-its-projects.vercel.app}"

# Auto-detect mode
if [ -d "/workspace/cowork" ] || [ -d "/home/user/cowork" ]; then
  MODE="cloud"
else
  MODE="local"
fi
case "${1:-}" in
  --cloud) MODE="cloud";;
  --local) MODE="local";;
esac

# Token-Quelle
if [ -z "${ROADMAP_API_TOKEN:-}" ]; then
  if [ -f "$HOME/.roadmap-api-token" ]; then
    ROADMAP_API_TOKEN=$(cat "$HOME/.roadmap-api-token" | tr -d '[:space:]')
  fi
fi

ok_count=0
total=0

echo "🧪 Cloud-Smoke-Test v2 (Mode: $MODE)"
echo "─────────────────────────────"

# Check 1 — interaktiv
echo "  Check 1: Slash-Menu Skill /sprint-start  [INTERAKTIV — bitte manuell pruefen via '/']"
total=$((total + 1))

# Check 2 — cloud-bootstrap.sh
total=$((total + 1))
if [ "$MODE" = "cloud" ]; then
  BOOT_SCRIPT="/workspace/cowork/scripts/cloud-bootstrap.sh"
  [ ! -f "$BOOT_SCRIPT" ] && BOOT_SCRIPT="/home/user/cowork/scripts/cloud-bootstrap.sh"
else
  BOOT_SCRIPT="$HOME/Cowork/scripts/cloud-bootstrap.sh"
fi
if [ -f "$BOOT_SCRIPT" ] && bash "$BOOT_SCRIPT" >/dev/null 2>&1; then
  echo "  Check 2: cloud-bootstrap.sh  [OK]"
  ok_count=$((ok_count + 1))
else
  echo "  Check 2: cloud-bootstrap.sh  [FAIL] — $BOOT_SCRIPT exit non-zero oder nicht vorhanden"
fi

# Check 3 — /api/verify
total=$((total + 1))
if [ -n "${ROADMAP_API_TOKEN:-}" ]; then
  HTTP=$(curl -sS -o /tmp/cs-verify.json -w "%{http_code}" \
    -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
    "$ROADMAP_API/api/verify")
  if [ "$HTTP" = "200" ]; then
    GS=$(python3 -c "import json; print(json.load(open('/tmp/cs-verify.json')).get('globalSprint','?'))" 2>/dev/null)
    echo "  Check 3: /api/verify HTTP 200 globalSprint=$GS  [OK]"
    ok_count=$((ok_count + 1))
  else
    echo "  Check 3: /api/verify HTTP $HTTP  [FAIL]"
  fi
else
  echo "  Check 3: /api/verify  [FAIL] — Token fehlt"
fi

# Check 4 — /api/memory-read fuer 3 kritische Files
total=$((total + 1))
MEM_OK=0
for FILE in "MEMORY.md" "verhaltensregeln.md" "skills/sprint-start/SKILL.md"; do
  HTTP=$(curl -sS -o /tmp/cs-mem.txt -w "%{http_code}" \
    -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
    "$ROADMAP_API/api/memory-read?path=$FILE")
  if [ "$HTTP" = "200" ]; then
    MEM_OK=$((MEM_OK + 1))
  fi
done
if [ "$MEM_OK" = "3" ]; then
  echo "  Check 4: /api/memory-read 3/3 Files (MEMORY.md, verhaltensregeln.md, sprint-start SKILL.md)  [OK]"
  ok_count=$((ok_count + 1))
else
  echo "  Check 4: /api/memory-read $MEM_OK/3 Files  [FAIL]"
fi

# Check 5 — /api/sprint-cache GET (Sprint 263 Cloud-Fix)
total=$((total + 1))
SPRINT_TAG=""
# 1. ENV-Var (Cloud-Mode)
if [ -n "${SPRINT_TAG_OVERRIDE:-}" ]; then
  SPRINT_TAG="$SPRINT_TAG_OVERRIDE"
# 2. Argument $2 (--cloud/--local + Tag)
elif [ -n "${2:-}" ] && [ "${2}" != "--local" ] && [ "${2}" != "--cloud" ]; then
  SPRINT_TAG="$2"
# 3. Lokal: Filesystem
elif [ -f "$HOME/Cowork/.current-sprint-tag" ]; then
  SPRINT_TAG=$(cat "$HOME/Cowork/.current-sprint-tag" | tr -d '[:space:]')
# 4. Cloud-Mode: aus /api/verify aktiver Session ableiten (Anchor-UUID Mac-CLI)
elif [ "$MODE" = "cloud" ] && [ -n "${ROADMAP_API_TOKEN:-}" ]; then
  # Hole alle phase_state Eintraege fuer aktiven Sprint, nimm den juengsten
  SPRINT_TAG=$(curl -sS -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
    "$ROADMAP_API/api/verify" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('activeSession',''))" 2>/dev/null || echo "")
fi
if [ -n "$SPRINT_TAG" ] && [ -n "${ROADMAP_API_TOKEN:-}" ]; then
  HTTP=$(curl -sS -o /tmp/cs-cache.json -w "%{http_code}" \
    -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
    "$ROADMAP_API/api/sprint-cache?session=$SPRINT_TAG")
  if [ "$HTTP" = "200" ]; then
    FOUND=$(python3 -c "import json; d=json.load(open('/tmp/cs-cache.json')); print(d.get('cache',{}).get('found', 'true' if d.get('cache') else 'false'))" 2>/dev/null)
    echo "  Check 5: /api/sprint-cache HTTP 200 (session=$SPRINT_TAG)  [OK]"
    ok_count=$((ok_count + 1))
  else
    echo "  Check 5: /api/sprint-cache HTTP $HTTP  [FAIL]"
  fi
else
  echo "  Check 5: /api/sprint-cache  [SKIP] — kein Session-Tag oder Token"
fi

# Check 6 — interaktiv
echo "  Check 6: PushNotification  [INTERAKTIV] — Cloud-Session muss PushNotification(status:'proactive', message:...) selber triggern"
total=$((total + 1))

echo "─────────────────────────────"
echo "Auto-Checks: $ok_count/4 grun (Check 1+6 interaktiv — Total $total Pruefungen)"
echo ""
if [ "$ok_count" = "4" ]; then
  echo "✅ Auto-Path OK. Verifiziere Check 1 (Slash-Menu) + 6 (PushNotification) manuell."
  exit 0
else
  echo "⚠️  $((4 - ok_count))/4 Auto-Check(s) gefailt — siehe Recovery in SKILL.md"
  exit 1
fi
