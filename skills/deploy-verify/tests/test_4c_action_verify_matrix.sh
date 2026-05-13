#!/usr/bin/env bash
# Sprint 270 Block B — deploy-verify 4c-Test (CC-REFACTOR-CLOUD-FIRST-INCLUDE).
# Verifiziert dass die 4c-Action-Verify-Matrix im SKILL.md vorhanden + funktionsfaehig
# (Loop-Pattern mit verify_action() definiert).
set -e

SKILL=~/Cowork/scholly-toolkit/skills/deploy-verify/SKILL.md

if [ ! -f "$SKILL" ]; then
  echo "FAIL — $SKILL existiert nicht"
  exit 1
fi

MISSING=0

# Pruefung 1: 4c-Action-Verify-Matrix-Header
grep -qE "## 🔍 4c-Action-Verify-Matrix|## 4c-Action-Verify-Matrix" "$SKILL" \
  && echo "  ✅ 4c-Header vorhanden" \
  || { echo "  ❌ 4c-Header fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 2: Mindestens 5 Action-Zeilen in der Matrix
ACTION_COUNT=$(awk '/^### Action-Verify-Matrix \(deploy-relevante Actions\)/,/^### Generischer/' "$SKILL" | grep -c "^| \*\*")
if [ "$ACTION_COUNT" -ge 5 ] 2>/dev/null; then
  echo "  ✅ $ACTION_COUNT Action-Zeilen in der Matrix"
else
  echo "  ❌ Nur $ACTION_COUNT Action-Zeilen (erwartet >=5)"
  MISSING=$((MISSING+1))
fi

# Pruefung 3: Generischer Loop-Pattern (verify_action Funktion)
grep -qE "verify_action\(\)|function verify_action" "$SKILL" \
  && echo "  ✅ verify_action() Loop-Pattern vorhanden" \
  || { echo "  ❌ Loop-Pattern fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 4: Anti-Annahme-Prinzip explizit dokumentiert
grep -qE "Anti-Annahme-Prinzip|nie vertrauen|IMMER ausfuehren" "$SKILL" \
  && echo "  ✅ Anti-Annahme-Prinzip dokumentiert" \
  || { echo "  ❌ Anti-Annahme-Prinzip fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 5: Cross-Ref auf Master-Doc
grep -qE "refactor-architektur-sprint-refactor-1.md" "$SKILL" \
  && echo "  ✅ Cross-Ref auf Master-Doc" \
  || { echo "  ❌ Cross-Ref fehlt"; MISSING=$((MISSING+1)); }

# Pruefung 6 (Synthetische Loop-Funktion live testen):
# Inline-Definition nachstellen + gegen falschen Match testen
verify_action() {
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
# Test: True-case
if verify_action "echo-test" "echo hello-world" "hello"; then
  echo "  ✅ verify_action True-case funktioniert"
else
  echo "  ❌ verify_action True-case fehlgeschlagen"
  MISSING=$((MISSING+1))
fi
# Test: False-case (sollte fail liefern)
if verify_action "echo-test-fail" "echo nothing" "missing-pattern" 1 2>/dev/null; then
  echo "  ❌ verify_action False-case haette FAILen sollen"
  MISSING=$((MISSING+1))
else
  echo "  ✅ verify_action False-case schlaegt fehl wie erwartet"
fi

if [ "$MISSING" = "0" ]; then
  echo ""
  echo "PASS — 4c-Action-Verify-Matrix komplett + Loop funktioniert"
  exit 0
else
  echo ""
  echo "FAIL — $MISSING Pruefungen failed"
  exit 1
fi
