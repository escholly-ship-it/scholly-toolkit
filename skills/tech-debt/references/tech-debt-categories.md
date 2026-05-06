# Tech-Debt-Kategorien

Sprint 262 (CC-SKILL-TECH-DEBT). Schulden-Klassifikation als Referenz fuer den Refactor-Plan-Generator.

## 1. Code-Schulden (Inline-Marker)

| Pattern | Bedeutung | Wann ein STOPP-Gate |
|---------|-----------|---------------------|
| `TODO` | Geplante Erweiterung | nur bei >50 in einem File |
| `FIXME` | Bekannter Bug | sofort wenn in Production-Code |
| `HACK` | Workaround | sofort wenn Sicherheits-relevant |
| `XXX` | Achtung — kritisch | immer |

## 2. Backlog-Tags

| Tag | Bedeutung |
|-----|-----------|
| `[TECH-DEBT]` | Schulden-Item, Regel 4 STOPP-Gate |
| `[SCHULDEN]` | Synonym, alt — sollte zu `[TECH-DEBT]` migrieren |

Items mit diesen Tags blockieren neuen Feature-Sprint laut Regel 4.

## 3. Architektur-Schulden (manuell zu erkennen)

| Kategorie | Erkennungs-Signal | Beispiel |
|-----------|-------------------|----------|
| **God-Component** | File >500 LOC + viele Imports | `src/app/dashboard/page.tsx` mit 800 LOC |
| **Dead-Code** | Funktion exportiert aber nirgends importiert | `lib/legacy-api.ts` |
| **Untyped** | `any`-Cast Haeufung in TS-Datei | `>5 any in <100 LOC` |
| **Hard-Coded** | Secrets/URLs/Magic-Numbers im Code | Token-Plain-Text Postmortem Sprint 259 |
| **Test-Skip** | `.skip` / `.todo` Tests | regtest Sprint 228 AUTO-26 |
| **Stub-Test-only** | nur `bash -n` / file-existence | Sprint 241 AUTO-39 Lehre |

## 4. Migrations-Schulden

| Kategorie | Erkennung | Folge-Item |
|-----------|-----------|-----------|
| **Alt-Code nach Migration** | Verifikations-Grep findet Treffer ausserhalb archive/ | Regel 92 Teardown-Pflicht |
| **Caches** | obsolete Build-Caches | rm -rf in Phase E |
| **Env-Vars** | nicht mehr genutzt | Vercel/.env-Cleanup |
| **Hooks ungenutzt** | nicht in settings.json + nicht in Skill-Inline | archive-Ordner |

## 5. Prioritaet-Heuristik (fuer Refactor-Plan)

1. **Kritisch (sofort):** XXX, FIXME in Production-Code, hard-coded Secrets, Test-Skip mit Production-Path-Coverage
2. **Hoch (im naechsten Sprint):** [TECH-DEBT]-Backlog-Items, God-Components in Hot-Touch-Files
3. **Mittel (im Quartals-Refactor):** TODO-Haeufung (>50/File), Dead-Code, Migrations-Reste
4. **Niedrig (Opportunistisch):** TODO einzeln, Untyped-Drift in Cold-Code

## Cross-Reference

- Regel 4 (`memory/arbeitsregeln.md`) — Tech-Debt-Gate
- Regel 92 — Migration-Teardown-Pflicht
- Regel 109 — Test-Persistenz
- experte-qa-engineer.md — Stub-vs-Critical-Path-Test-Strategie
