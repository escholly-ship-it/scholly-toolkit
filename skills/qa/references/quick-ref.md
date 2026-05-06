# QA Quick-Reference

Aus `experte-qa-engineer.md` (Sprint 262 CC-SKILL-EXPERTEN-TOP5). Volle Persona-Lehren in der Quelle.

## Critical-Path vs Stub-Tests (AUTO-39 Sprint 241 Lehre)

`bash -n` + file-existence sind KEIN Test. Pflicht-Test-Layer pro Bash-Runner:
1. **Critical-Path** mit echten Sample-Inputs (sample-input-driven)
2. **Error-Paths** (Exit-Codes pruefen)
3. **Output-Format** (grep gegen erwarteten String)
4. **Edge-Cases** (leerer Pool, falsches Datum, Cross-Day)

Stub-Tests fanden NIE den `apify-budget-guard.sh` Heredoc-Bug (Sprint 224-241), echter Test fand ihn beim ersten Run.

## Test-Persistenz (Regel 109, Sprint 242)

Phase-E-Marker `e-testing` darf nur gesetzt werden wenn `git diff --stat` mind. eine Test-File-Aenderung zeigt im Sprint-Diff. Skip-Pfad: `SPRINT_TYPE=prozess` ODER `memory-only` ODER 0 Code-Files im Diff.

Test-File-Patterns: `*.test.ts`, `*.test.sh`, `*.spec.ts`, `tests/`, `__tests__/`, `e2e/`, `*.bats`.

## Playwright App Router

- Server Components testen via Hydration-Marker
- API-Routes per fetch-Mock + Response-Schema
- E2E mit Browser-Pool, baseURL aus ENV

## Lighthouse CI Performance Budgets

- Build-Gate: Performance >85, Accessibility >95, Best-Practices >90
- Bei Failure: PR blockiert, Diff im PR-Comment

## Phase-E-Schritt-3-Pflichtablauf

1. Test-Diff pruefen (Regel 109)
2. Critical-Path-Test fuer geaenderten Code
3. Regression-Run gegen letzten Green-State
4. Lighthouse-CI bei Frontend-Touch

## Cross-Reference

- AUTO-39 Sprint 241 Postmortem (Persona Sprint 241 Block)
- Regel 109 Volltext (`memory/arbeitsregeln.md`)
- `/test-strategy` Sprint-262 Sub-Skill
