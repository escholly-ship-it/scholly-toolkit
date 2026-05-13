---
name: test-strategy
description: Test-Meta-Strategie pro Sprint. Klassifiziert Tests in Critical-Path vs Stub vs Coverage-Theater (AUTO-39 Lehre). Setzt Phase-A Test-Scope-Block + Phase-E Test-Diff-Pflicht (Regel 109) durch. Multivariant-Runner mit echten Sample-Inputs statt bash -n. Trigger bei "test strategy", "critical path test", "coverage scan", "regtest", "test persistenz", "phase E testing", "stub vs echt", "multivariant test".
---

# /test-strategy — Test-Meta-Strategie

**Initiative:** CC-322 (Sprint 244 angelegt). Sprint 262 Implementation.
**Bezug:** Regel 109 Test-Persistenz (`memory/arbeitsregeln.md`). Lehre AUTO-39 Sprint 241 (Stub-Tests fanden Bug NIE, Critical-Path-Test fand ihn beim ersten Run).

## Wann nutzen

- **Phase A Schritt 4d:** Test-Scope-Block pro Sprint-Item (statt nur Effort-Schaetzung)
- **Phase D vor Coding:** TDD — sample-input-driven Critical-Path-Test schreiben, dann Implementation
- **Phase E Schritt 3:** Test-Persistenz-Check (Regel 109) — `git diff --stat` muss Test-File-Aenderungen zeigen
- **Forensik:** Wenn Tests gruen aber Bug in Production durchrutscht

## Pflicht-Test-Layer pro Bash-Runner

1. **Critical-Path** (echter Sample-Input + Output-Erwartung)
2. **Error-Paths** (Exit-Codes pruefen)
3. **Output-Format** (grep gegen erwarteten String)
4. **Edge-Cases** (leerer Pool, falsches Datum, Cross-Day)

`bash -n` + file-existence sind KEIN Test. Stub-Tests duerfen den e-testing-Marker NICHT setzen.

## Workflow

### Step 1 — Test-Scope-Block (Phase A)

Pro Sprint-Item klassifizieren:
- **Test-needed:** Code-Touch in `~/projects/*` ODER `~/Cowork/agents/*.sh` ODER `~/Cowork/scripts/*.py`
- **Skip-Pfad:** `SPRINT_TYPE=prozess` ODER `memory-only` ODER 0 Code-Files im Diff
- **Test-Layer:** welche der 4 Layer pro Item?

### Step 2 — Coverage-Scan (Phase E vor e-testing-Marker)

```bash
bash ~/.claude/skills/test-strategy/scripts/test-coverage-scan.py
```

Prueft:
- Test-File-Patterns: `*.test.ts/.spec.ts/.test.sh/.bats`, `tests/`, `__tests__/`, `e2e/`
- `git diff --stat` zeigt mind. 1 Test-File-Aenderung im Sprint-Diff
- Stub-only-Detection (nur `bash -n` ohne assert): Warnung

### Step 3 — Multivariant-Runner

```bash
bash ~/.claude/skills/test-strategy/scripts/multivariant-runner.py <test-script.sh>
```

Laeuft Test mehrfach mit unterschiedlichen Sample-Inputs (A/B-Test-Pattern). Erzeugt Variance-Report.

## Sub-Agent

`agents/test-architect.md` — Sub-Agent fuer Test-Strategy-Design pro Sprint-Item.

## Cross-Reference

- Regel 109 Test-Persistenz (Volltext in `memory/arbeitsregeln.md`)
- AUTO-39 Sprint 241 Postmortem (in experte-qa-engineer.md)
- `/qa` Skill — Pflicht-Aktivierung in Phase E
- `/tech-debt` Skill — Test-Skip-Patterns als Schulden klassifizieren
