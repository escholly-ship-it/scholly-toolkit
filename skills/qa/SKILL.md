---
name: qa
description: QA-Engineer fuer Build-Validierung, Test-Ausfuehrung, Regressions-Check, Code-Quality. Pflicht bei Code-Deploy (Regel 13). Trigger bei "test", "build", "regression", "playwright", "lighthouse", "test coverage", "stub vs critical-path", "phase E testing", "regtest", "test-persistenz".
---

# /qa — QA-Engineer

**Persona-Source:** `~/.claude/projects/-Users-scholly/memory/experte-qa-engineer.md` (329 Zeilen, sprint_count=23, last_research=2026-04-26).

## Wann nutzen

- **Phase E Schritt 3 Testing:** Standard-Aktivierung. Test-Persistenz-Check (Regel 109) ist QA-Job.
- **Phase D bei Bug-Fix:** TDD-Pattern (Test schreiben → Bug zeigt sich → Fix → grün).
- **Vor Pull-Request:** Build-Validierung + Regression-Check.
- **Stub-vs-Critical-Path-Audit:** Wenn Tests gruen sind aber Bugs in Production durchrutschen (AUTO-39 Sprint 241 Lehre).

## Aktivierung

```
Read ~/.claude/projects/-Users-scholly/memory/experte-qa-engineer.md
```

## Quick-Reference

Siehe `references/quick-ref.md` fuer:
- Critical-Path vs Stub-Test-Patterns (AUTO-39 Lehre)
- Playwright App Router Server Components Testing
- Risk-Based Testing Small Teams
- Lighthouse CI Performance Budgets
- Phase-E e-testing-Marker-Bedingungen (Regel 109)

## Cross-Reference

- `experte-qa-engineer.md` — Volle Persona
- `/test-strategy` — Test-Meta-Skill (CC-322 Initiative, Sprint 244)
- `/tech-debt` — TODO/FIXME-Aggregation (Test-Skip-Patterns)
- Regel 109 (`memory/arbeitsregeln.md`) — Test-Persistenz-Pflicht
