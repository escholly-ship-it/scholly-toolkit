---
name: tech-debt
description: Aggregiert Technische Schulden ueber alle Projekte (TODO/FIXME/HACK-Kommentare + Backlog-[TECH-DEBT]-Tags + God-Components) und erzeugt einen priorisierten Refactor-Plan. Trigger bei "tech debt", "refactor plan", "TODO scan", "schulden inventar", "tech debt audit". Nutzt Regel 4 (Schulden = Null vor neuen Features) als STOPP-Gate fuer Phase A.
---

# /tech-debt — Tech-Debt-Aggregation + Refactor-Plan

**Bezug:** Regel 4 (`memory/arbeitsregeln.md`): "Erst aufraeumen, dann bauen. Im Sprint Planning pruefen: Gibt es offene technische Schulden? → ZUERST einplanen."

## Wann nutzen

- **Phase A `/sprint-start`** Schritt 4b ruft diesen Skill auf (statt inline grep + Backlog-Scan)
- Manuell: bei Feature-Drift-Verdacht, vor groesseren Refactors, alle 13 Sprints im Quartals-Review
- Nach einem Bug-Fix-Sprint: nachschauen ob neue Schulden entstanden sind

## Was der Skill liefert

1. **Aggregations-Report** (Markdown): TODO/FIXME/HACK-Treffer pro Projekt + Backlog-`[TECH-DEBT]`-Items
2. **Hot-Spot-Ranking**: Files mit den meisten Schulden + Letzter-Touch-Datum (via git-blame)
3. **Refactor-Plan**: 3 Top-Items zur Auswahl mit Effort-Schaetzung (XS/S/M/L/XL)
4. **STOPP-Empfehlung** wenn `[TECH-DEBT]`-Items im aktiven Backlog vorhanden sind

## Workflow

### Step 1 — Aggregation

```bash
bash ~/.claude/skills/tech-debt/scripts/tech-debt-scan.py
```

Scannt:
- Source-Verzeichnisse: `~/projects/*/src`, `~/projects/*/scripts`
- Memory-Backlogs: `~/.claude/projects/-Users-scholly/memory/backlog-*.md`
- Patterns: `TODO`, `FIXME`, `HACK`, `XXX`, `[TECH-DEBT]`, `[SCHULDEN]`

Output: JSON-Report unter `/tmp/tech-debt-scan-<sprint>.json`.

### Step 2 — Refactor-Plan

```bash
bash ~/.claude/skills/tech-debt/scripts/refactor-plan-generator.py /tmp/tech-debt-scan-<sprint>.json
```

LLM-Pass: pro Hot-Spot Datei einen 1-Satz-Refactor-Vorschlag + Effort.

### Step 3 — Phase-A-Gate

Wenn `[TECH-DEBT]`-Backlog-Items > 0:
- STOPP, in Phase A 4b nachschauen
- Items vor neuen Features einplanen (Regel 4)

Wenn `TODO/FIXME/HACK > 10` global:
- Warnung, kein STOPP
- Im Chat melden

## Sub-Agent

`agents/tech-debt-strategist.md` — kann via `subagent_type=tech-debt-strategist` aktiviert werden fuer tiefere Refactor-Analyse.

## References

- `references/tech-debt-categories.md` — God-Component, Dead-Code, Untyped, Hard-Coded, Test-Skip-Patterns

## Cross-Reference

- Regel 4 (memory/arbeitsregeln.md) — Tech-Debt-Gate-Definition
- experte-qa-engineer.md — Test-Persistenz-Check (Regel 109)
- /test-strategy — Test-Coverage-Aspekt von Tech-Debt
