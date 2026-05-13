# Knowledge Manager Quick-Reference

Aus `experte-knowledge-manager.md` (Sprint 262 CC-SKILL-EXPERTEN-TOP5).

## Memory-Quality-Composite-Score (Regel 51)

| Gewichtung | Asset |
|-----------|-------|
| 40% | Experten-Personas (Frische, Tiefe) |
| 25% | Regeln (verhaltensregeln + arbeitsregeln) |
| 15% | Projekt-Memories |
| 10% | Referenzen (reference_*.md) |
| 10% | Frameworks (experten-team-framework etc.) |

Tier-1-Budget: <2700 Zeilen (rot bei 3000+).
Hart-Limit: 15.000 Zeilen.

## Sprache-Regel (Sprint 244 — Phase E Schritt 6)

- VERBOTEN: "Sprint-Ziel erreicht", "Liefer-Vertrag eingehalten" (von Claude)
- ERLAUBT: "Liefer-Status:", "Bitte Abnahme erteilen"
- Kunde definiert Ziel + nimmt ab.

## Carry-Over-Pattern toxisch (Sprint 261, Regel 114)

Items aus Sprint N nicht stillschweigend in Sprint N+1 verschieben. Master-Items mit `[NICHT DE-SCOPABLE]` einsetzen wenn Verschiebung unzulaessig.

## Phase-G-Pflichten

1. retros.md aktualisieren (letzte 20 Sprints, alteres → archive/)
2. MEMORY.md Index synchron mit Files
3. Notion-Hub Status pflegen
4. Recovery-Note nur bei Recovery-relevanten Aenderungen (Regel 31)

## 3-Schichten-Routing neuer Regeln

- IMMER (jede Session) → `verhaltensregeln.md`
- SPRINT (Sprint-Prozess) → `arbeitsregeln.md`
- DOMAIN (Persona-Wissen) → `experte-*.md`
