# Test-Patterns Critical-Path vs Stub

Aus AUTO-39 Sprint 241 (`apify-budget-guard.sh` Heredoc-Bug) abgeleitet.

## Critical-Path-Test-Pattern

```bash
# tests/apify-budget-guard.test.sh
test_multiple_sources_summed() {
  # Setup: Sample-Input-Logs mit 2 Quellen, jeder $0.30
  echo "source=actor1 cost=0.30" > /tmp/test-log.txt
  echo "source=actor2 cost=0.30" >> /tmp/test-log.txt

  # Run: das echte Skript
  bash apify-budget-guard.sh /tmp/test-log.txt --threshold 0.50
  rc=$?

  # Assert: Exit 1 erwartet (>0.50)
  [ $rc -eq 1 ] || { echo "FAIL: Exit $rc statt 1"; return 1; }
  echo "OK"
}
```

## Stub-Test (KEIN Test im Sinne Regel 109)

```bash
# tests/apify-budget-guard.stub.sh
test_syntax_check() {
  bash -n apify-budget-guard.sh || return 1
  [ -f apify-budget-guard.sh ] || return 1
  echo "OK"
}
```

Stub-Tests sind okay als ZUSAETZLICHE Schicht — aber NICHT als einzige Test-Schicht.

## TDD-Pattern fuer Bug-Fix-Sprints

1. **Bug-Reproduktion:** Critical-Path-Test mit Sample-Input der Bug triggert. Erwartung: Test fail.
2. **Fix:** Code aendern.
3. **Test wird gruen:** Bug ist behoben.
4. **Persistenz:** Test bleibt im Repo, schuetzt vor Regression.

## 4 Pflicht-Test-Layer pro Bash-Runner

1. **Critical-Path** — sample-input-driven Happy-Path
2. **Error-Paths** — Exit-Codes, Failure-Returns
3. **Output-Format** — grep gegen erwarteten String
4. **Edge-Cases** — leere Inputs, falsche Datums-Formate, Cross-Day-Boundaries

## Skip-Pfaede (Regel 109)

- `SPRINT_TYPE=prozess` (in `.sprint-phases`)
- `SPRINT_TYPE=memory-only`
- 0 Code-Files im Sprint-Diff (nur Memory/Doku/Config)

## Cross-Reference

- experte-qa-engineer.md — AUTO-39 Postmortem, Critical-Path-Insistance
- Regel 109 — Volltext der Persistenz-Pflicht
