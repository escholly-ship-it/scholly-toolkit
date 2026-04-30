#!/usr/bin/env bash
# CC-379 Sprint 250 — Test for phase-a-checks textual-deps
# Erstellt einen Stub-Cache mit Dummy-Items, prueft dass:
# 1. NICHT-GEFUNDEN-Verweise erkannt werden
# 2. IM-BACKLOG-Verweise erkannt werden
# 3. SPRINT-FUTURE-Verweise erkannt werden
# 4. Archived-Vorgaenger NICHT als Problem flaggen
# 5. BLOCKED:- und Scholly:-Felder ignoriert werden
# 6. Selbstreferenz nicht trifft
set -euo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Sprint-Global-File mocken (current = 250)
SPRINT_GLOBAL_OLD="$HOME/Cowork/.sprint-global"
SPRINT_GLOBAL_BACKUP="$TEST_DIR/.sprint-global-original"
[ -f "$SPRINT_GLOBAL_OLD" ] && cp "$SPRINT_GLOBAL_OLD" "$SPRINT_GLOBAL_BACKUP"

CACHE="$TEST_DIR/cache.json"
cat > "$CACHE" <<'EOF'
{
  "verify": { "globalSprint": 250 },
  "items": [
    { "id": "u-1",  "backlog_id": "TEST-1",  "title": "Item with non-existent dep",
      "sprint_nummer": 250, "abhaengigkeit": "depends:TEST-999", "archived": false },
    { "id": "u-2",  "backlog_id": "TEST-2",  "title": "Item with backlog dep",
      "sprint_nummer": 250, "abhaengigkeit": "Abhaengig von: TEST-100", "archived": false },
    { "id": "u-3",  "backlog_id": "TEST-3",  "title": "Item with future-sprint dep",
      "sprint_nummer": 250, "abhaengigkeit": "nach TEST-200", "archived": false },
    { "id": "u-4",  "backlog_id": "TEST-4",  "title": "Item with archived dep (OK)",
      "sprint_nummer": 250, "abhaengigkeit": "depends: TEST-300", "archived": false },
    { "id": "u-5",  "backlog_id": "TEST-5",  "title": "Item with previous-sprint dep (OK)",
      "sprint_nummer": 250, "abhaengigkeit": "siehe TEST-400", "archived": false },
    { "id": "u-6",  "backlog_id": "TEST-6",  "title": "Item with BLOCKED",
      "sprint_nummer": 250, "abhaengigkeit": "BLOCKED: TEST-999", "archived": false },
    { "id": "u-7",  "backlog_id": "TEST-7",  "title": "Item with Scholly action",
      "sprint_nummer": 250, "abhaengigkeit": "Scholly: TEST-999 entscheiden", "archived": false },
    { "id": "u-8",  "backlog_id": "TEST-8",  "title": "Item with self-reference",
      "sprint_nummer": 250, "abhaengigkeit": "nach TEST-8", "archived": false },
    { "id": "u-100","backlog_id": "TEST-100","title": "In Backlog",
      "sprint_nummer": null, "abhaengigkeit": null, "archived": false },
    { "id": "u-200","backlog_id": "TEST-200","title": "Future Sprint",
      "sprint_nummer": 251, "abhaengigkeit": null, "archived": false },
    { "id": "u-300","backlog_id": "TEST-300","title": "Archived (Done)",
      "sprint_nummer": 245, "abhaengigkeit": null, "archived": true },
    { "id": "u-400","backlog_id": "TEST-400","title": "Previous Sprint",
      "sprint_nummer": 249, "abhaengigkeit": null, "archived": false }
  ]
}
EOF

# current-Sprint = 250
echo "250" > "$SPRINT_GLOBAL_OLD"

OUTPUT=$(python3 ~/.claude/skills/sprint-start/phase-a-checks.py "$CACHE" textual-deps 2>&1)

# Restore sprint-global
[ -f "$SPRINT_GLOBAL_BACKUP" ] && cp "$SPRINT_GLOBAL_BACKUP" "$SPRINT_GLOBAL_OLD"

PASS=0
FAIL=0

assert_contains() {
  local needle="$1"
  local label="$2"
  if echo "$OUTPUT" | grep -q "$needle"; then
    echo "✅ PASS: $label"
    PASS=$((PASS+1))
  else
    echo "❌ FAIL: $label (expected to contain: $needle)"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local needle="$1"
  local label="$2"
  if echo "$OUTPUT" | grep -q "$needle"; then
    echo "❌ FAIL: $label (expected NOT to contain: $needle)"
    FAIL=$((FAIL+1))
  else
    echo "✅ PASS: $label"
    PASS=$((PASS+1))
  fi
}

# Erwartete Treffer: TEST-1 (nicht gefunden), TEST-2 (Backlog), TEST-3 (Future-Sprint)
assert_contains "TEST-1.*TEST-999.*NICHT GEFUNDEN" "TEST-1: nicht-existenter Vorgaenger erkannt"
assert_contains "TEST-2.*TEST-100.*IM BACKLOG"     "TEST-2: Backlog-Vorgaenger erkannt"
assert_contains "TEST-3.*TEST-200.*SPRINT 251"     "TEST-3: Future-Sprint-Vorgaenger erkannt"

# NICHT-Treffer: TEST-4 (archived), TEST-5 (Sprint 249), TEST-6 (BLOCKED), TEST-7 (Scholly:), TEST-8 (self)
assert_not_contains "TEST-4 .*TEST-300"  "TEST-4: archivierter Vorgaenger NICHT geflaggt"
assert_not_contains "TEST-5 .*TEST-400"  "TEST-5: vorheriger-Sprint-Vorgaenger NICHT geflaggt"
assert_not_contains "TEST-6 .*TEST-999"  "TEST-6: BLOCKED:-Feld NICHT geflaggt"
assert_not_contains "TEST-7 .*TEST-999"  "TEST-7: Scholly:-Action NICHT geflaggt"
assert_not_contains "TEST-8 .*TEST-8"    "TEST-8: Selbstreferenz NICHT geflaggt"

echo ""
echo "Summary: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
