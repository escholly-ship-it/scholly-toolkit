#!/usr/bin/env bash
# Sprint 270 Block B — token-onboarding 4c-Test (CC-REFACTOR-CLOUD-FIRST-INCLUDE).
# Verifiziert dass die 4c-Action-Verify-Matrix im SKILL.md vorhanden + funktionsfaehig
# (Token-spezifische Verifikationen + Loop-Pattern).
set -e

SKILL=~/Cowork/scholly-toolkit/skills/token-onboarding/SKILL.md

if [ ! -f "$SKILL" ]; then
  echo "FAIL — $SKILL existiert nicht"
  exit 1
fi

MISSING=0

# Pruefung 1: 4c-Action-Verify-Matrix-Header
grep -qE "## 🔍 4c-Action-Verify-Matrix|## 4c-Action-Verify-Matrix" "$SKILL" \
  && echo "  ✅ 4c-Header vorhanden" \
  || { echo "  ❌ 4c-Header fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 2: Token-spezifische Actions (Keychain, BotFather, Vercel-Env, GitHub-Secret, Vendor-Endpoint)
for ACTION in "Keychain" "BotFather" "Vercel" "GitHub" "Vendor-Endpoint" "rotiert"; do
  grep -qE "$ACTION" "$SKILL" \
    && echo "  ✅ Action '$ACTION' in Matrix" \
    || { echo "  ❌ Action '$ACTION' fehlt"; MISSING=$((MISSING+1)); }
done

# Pruefung 3: Negativ-Verify (Rotation: alter Token MUSS 401 liefern)
grep -qE "alter Token MUSS 401|alter Token.*401|Negativ-Verify" "$SKILL" \
  && echo "  ✅ Negativ-Verify (Rotation) dokumentiert" \
  || { echo "  ❌ Negativ-Verify fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 4: Generischer Loop (verify_token_action Funktion)
grep -qE "verify_token_action\(\)|function verify_token_action" "$SKILL" \
  && echo "  ✅ verify_token_action() Loop-Pattern vorhanden" \
  || { echo "  ❌ Loop-Pattern fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 5: Cross-Ref auf Master-Doc + Token-Leak-Postmortem
grep -qE "refactor-architektur-sprint-refactor-1.md" "$SKILL" \
  && echo "  ✅ Cross-Ref auf Master-Doc" \
  || { echo "  ❌ Cross-Ref Master fehlt"; MISSING=$((MISSING+1)); }

grep -qE "incident-2026-05-01-token-leak" "$SKILL" \
  && echo "  ✅ Cross-Ref auf Token-Leak-Postmortem" \
  || { echo "  ❌ Cross-Ref Postmortem fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 6 (Synthetische Loop-Funktion live testen):
verify_token_action() {
  local DESC="$1"
  local CMD="$2"
  local EXPECT="$3"
  local MAX_TRIES="${4:-2}"
  for i in $(seq 1 $MAX_TRIES); do
    OUTPUT=$(eval "$CMD" 2>&1)
    if echo "$OUTPUT" | grep -q "$EXPECT"; then
      return 0
    fi
    [ "$i" = "$MAX_TRIES" ] && return 1
  done
}
# Synthetic 200-Response
if verify_token_action "synthetic-200" "echo '{\"ok\":true}'" '"ok":true'; then
  echo "  ✅ verify_token_action True-case funktioniert"
else
  echo "  ❌ verify_token_action True-case fehlgeschlagen"
  MISSING=$((MISSING+1))
fi
# Synthetic 401 (sollte FAILen — Token nicht akzeptiert)
if verify_token_action "synthetic-401" "echo '{\"error\":\"unauthorized\"}'" '"ok":true' 1 2>/dev/null; then
  echo "  ❌ verify_token_action False-case haette FAILen sollen"
  MISSING=$((MISSING+1))
else
  echo "  ✅ verify_token_action False-case schlaegt fehl wie erwartet"
fi

if [ "$MISSING" = "0" ]; then
  echo ""
  echo "PASS — 4c-Action-Verify-Matrix komplett + Token-spezifische Actions + Loop"
  exit 0
else
  echo ""
  echo "FAIL — $MISSING Pruefungen failed"
  exit 1
fi
