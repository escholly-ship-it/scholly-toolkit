---
name: lane
description: Lane-Resume oder Lane-Start im Lane/Vorhaben-Modell. Liest Lane-State + Backlog-Files direkt und liefert Anker-Block mit Top-Vorschlägen + Triage-Bucketing + Persona-Empfehlung. Trigger via Slash-Command `/lane <name>` (Mac-CLI) ODER Natural-Language "Lane: <name>" (Cloud-Remote-Session, sichtbar in Cloud-Desktop-App + Mobile-App). Sub-Command `auto-fix-all` LLM-nativ ab SV4 2026-05-26 (Triage-Pattern-Library-Lookup + Read+Edit Inline-Fixes, max 5 Items/Run, Confidence ≥ 0.7).
argument-hint: [lane-name] [auto-fix-all]
---

# Lane: $ARGUMENTS

> Welt-V2 LLM-Read-Direkt-Pattern (SV2 2026-05-25, SV4 2026-05-26 erweitert um Auto-Fix-Sub-Command). Du liest die Lane-State + Backlog-Files mit dem Read-Tool direkt, statt über Bash-Wrapper. Funktioniert auf Mac-CLI lokal + Cloud-Remote-Session (gespiegelt in Cloud-Desktop-App + Mobile-App).

## Sub-Command auto-fix-all (LLM-nativ ab SV4)

**Trigger-Patterns (zwei Surfaces):**
- Mac-CLI lokal: `/lane <name> auto-fix-all` ODER `/lane <name> fix-all`
- Cloud-Remote-Session Natural-Language: `Lane: <name> auto-fix-all` ODER `Lane: <name> fix-all`

Wenn das zweite Argument einer dieser Patterns ist:

1. Lies `~/Cowork/wiki/references/triage-pattern-library.md` komplett.
2. Lies alle `~/Cowork/wiki/projects/*-backlog.md` und filtere Items mit:
   - `auto_fixable: true` (oder `fix_pattern_id`-Feld ist gesetzt) im Item-YAML
   - Pattern-Library-Eintrag hat `Auto-Fixable: true` UND `Confidence: ≥ 0.7`
3. Wähle max 5 Items, sortiert nach Confidence absteigend.
4. Pro Item: führe die Pattern-spezifische Fix-Procedure aus (Read + Edit Tool-Calls, KEIN Bash). Beispiele:
   - `lane_drift_unarchived`: Item-Block in `wiki/projects/<slug>-backlog.md` lesen, identischen Block (mit ergänztem `delivery_artifact`-Feld) in `_archived-log.md` appendieren, Source-Block entfernen oder `status: archived` setzen.
   - `persona_next_research_overdue`: WebSearch zur Persona-Domain, Edit "Erlerntes Wissen"-Sektion + Frontmatter `next_research_due` auf +90d.
   - `memory_broken_link`: bei eindeutiger Renaming-Migration Link-Path umschreiben; sonst Cross-Ref entfernen.
   - `hausmeister_db_whitelist`: Supabase-RPC-Call (mcp_d65e329f-...-execute_sql) zum ALTER FUNCTION + Smoke-Call.
5. Output-Format pro Fix: `✅ <item-id> · pattern: <pattern_id> · Datei: <path> · Diff-Summary: <1-Zeile>`.
6. Am Ende: Summary-Block `Total Fixes: N` + `Skipped: M (Reason)` + `Tokens: ~Xk`.

**Anti-Pattern (verboten):** Auto-Fix-Pattern aufrufen das `Auto-Fixable: false` ist (z.B. `anthropic_native_migration` braucht Architektur-Decision, `permissive_rls_policy` braucht Domain-Knowledge). In dem Fall: skip + Reason in Summary.

## Read-Sequenz (deine Aufgabe als LLM)

1. Lies Lane-State: `~/Cowork/wiki/lanes/$ARGUMENTS.md` (falls nicht vorhanden: Customer informieren + Lane-Start-Modus)
2. Lies alle Backlog-Files: `~/Cowork/wiki/projects/*-backlog.md` und suche in jedem File nach Items mit Feld `block_id: LANE-<LANE-NAME-UPPERCASE-HYPHENATED>` (z.B. `claude-code-infra` → `LANE-CLAUDE-CODE-INFRA`) für Cross-Projekt-Items
3. Lies Triage-Pattern-Library (falls Auto-Fix-Items mit `auto_fixable=true` vorhanden): `~/Cowork/wiki/references/triage-pattern-library.md`
4. Erkenne offene Items mit `status: todo` oder `status: in_progress`, sortiere nach Triage-Bucket (siehe unten)
5. **OTEL-Readiness-Check** (nur wenn `$ARGUMENTS` == `claude-code-infra` UND ein offenes Item `TOKEN-EFFIZIENZ-LOOP-REVISIT` im Backlog existiert) — siehe Sektion unten.

## OTEL-Readiness-Meter (Daten-Tor für den Token-Effizienz-Analyzer)

> Zweck: deterministisch sichtbar machen, wann die OTEL-Pipeline genug kontinuierliche Daten gesammelt hat, dass der Effizienz-Analyzer (Backlog `TOKEN-EFFIZIENZ-LOOP-REVISIT`) statistisch valide baubar ist — statt Kalender-Raten. Läuft NUR solange das Gate-Item offen ist (danach automatisch inert).

Wenn der Read-Sequenz-Schritt 5 zutrifft:

1. Query via `mcp__betterstack__telemetry_query` (source_id `2459375`, table `t520527.claude_code_otel`):
   ```sql
   SELECT count(DISTINCT JSONExtract(raw,'attributes','session.id','Nullable(String)')) AS sessions,
          count(DISTINCT toDate(dt)) AS tage,
          countIf(JSONExtract(raw,'attributes','event.name','Nullable(String)')='api_request') AS requests
   FROM s3Cluster(primary, t520527_claude_code_otel_s3)
   WHERE _row_type = 1 AND dt > now() - INTERVAL 30 DAY
   ```
2. **Schwelle (READY wenn ALLE drei erreicht):** `sessions ≥ 30` UND `tage ≥ 10` UND `requests ≥ 300`. (Light-Analyse — Kosten-Trend + Modell-Mix — ist ab ~halber Schwelle valide; die feineren Signale brauchen die volle.)
3. **MCP nicht verfügbar** (headless/Cloud-Routine — betterstack-MCP nicht attached): Schritt skippen, Anker-Zeile = `OTEL-Readiness: nur interaktiv prüfbar (MCP nicht attached)`.
4. **Wenn READY:** im Anker als **Bucket-1-Item** listen — `🟢 OTEL READY → TOKEN-EFFIZIENZ-ANALYZER baubar (Daten-Tor erreicht)`. Sonst nur als Status-Zeile (siehe Anker-Format).

**Daten-Modell-Hinweis (forensisch belegt 2026-06-07):** OTEL liefert NUR Logs (`_row_type=1`) + Metrics (`_row_type=2`). KEINE Spans (`_row_type=3` leer; Claude Code emittiert keine Traces, auch nicht mit `OTEL_TRACES_EXPORTER=otlp`). → Subagent-/Persona-Spawn-Drill-Down ist über OTEL nicht baubar, dafür ist `/usage` der Weg. Transmittiert nur aus Login-Shell-Sessions (`~/.zprofile`).

## Triage-Bucketing (5 Buckets, sortiert nach Priority)

| Bucket | Icon | Was | Trigger im Item-YAML |
|---|---|---|---|
| 0 | 🛑 SCHOLLY-DECISION | menschliche Entscheidung nötig | `human_decision_needed: true` |
| 1 | ⚡ JETZT+AUTO-FIX | sofort + auto-fixbar | `horizont: JETZT` + `auto_fixable: true` |
| 2 | 🔴 JETZT | sofort, manuell | `horizont: JETZT` |
| 3 | ⚡ AUTO-FIX | irgendwann auto | `auto_fixable: true` |
| 4 | 📋 Backlog | alles andere | default |

Bucket-0-Items werden ZUERST im Anker adressiert, dann Top-3 aus Buckets 1-4.

## Persona-Aktivierung (vor Top-Vorschlag, 2-4 Personas)

| Vorhaben-Typ | Empfohlene Personas |
|---|---|
| Code-Sprint (Backend/Frontend) | backend-dev + frontend-dev + qa-engineer + devops |
| Refactor / Architektur | it-architekt + knowledge-manager + qa-engineer |
| Content / Ghostwriting | content-stratege + content-copy + visual-designer |
| Kunden-Projekt | ux-researcher + ux-ui + freelance-business |
| Infrastruktur / Skills | infrastruktur + devops + qa-engineer |
| Persona-System / Memory | knowledge-manager + it-architekt |

Bei Bau-Akt-Konsultation: explizit via `spawn_task` mit `subagent_type` (z.B. `qa-engineer`, `it-architekt`).

**Default-Stütze:** `it-architekt` ist Default-Persona bei Plan-Akt (immer dabei bei Refactor/Architektur). Bei gemischten Vorhaben-Typen (z.B. "Kunden-Projekt mit Backend-Sprint"): primären Typ wählen + `it-architekt` ergänzen.

### Experten-Auto-Load (SV5 Stage C ab 2026-05-26)

Bei Plan-Akt-Start: spawne die 2-4 empfohlenen Personas via `spawn_task` mit `subagent_type` AUTOMATISCH — **NUR WENN** Plan-Akt-Schritt 7 Token-Budget ≥30k angibt. Heuristik: 30k Plan-Akt-Bau × 30-50k Auto-Spawn-Cost = max ~50% Overhead-Bound. Bei kleineren Plan-Akten (<30k) ODER bei Customer-Override `/lane <name> no-spawn` → skip mit 1-Zeilen-Begründung im Plan-Akt-Output ("Auto-Spawn skipped: Token-Budget X<30k" oder "Auto-Spawn skipped: Customer-Override no-spawn"). Override-Trigger-Patterns: `/lane <name> no-spawn` ODER `Lane: <name> no-spawn` (Cloud-Remote).

## Anker-Block-Format (verbindlich)

Liefere genau dieses Format als finalen Output:

```
Lane: <name>
Letzter Stand: <aus letztem done+archived Item + delivery_artifact-Bilanz, max 2 Sätze>
Offene Risiken: <falls bekannt aus letzten Forensik-/Audit-Files, sonst weglassen>

[Nur Lane claude-code-infra + TOKEN-EFFIZIENZ-LOOP-REVISIT offen:]
OTEL-Readiness: <s>/30 Sessions · <t>/10 Tage · <r>/300 req — <🟢 READY / ⏳ noch nicht bereit>

[Wenn bucket-0-Items existieren — ZUERST:]
🛑 SCHOLLY-DECISION (bucket 0): <Top-1 mit pattern_id + Begründung>

Empfohlene Experten (Plan-Akt): <2-4 Personas basierend auf Vorhaben-Domain>

Top-3-Vorschläge (sortiert nach Triage-Bucket dann horizont/effort):
1. [Bucket-Icon] <Item-ID>: <Title> [Token: <est>]
2. [Bucket-Icon] <Item-ID>: <Title> [Token: <est>]
3. [Bucket-Icon] <Item-ID>: <Title> [Token: <est>]

Frage: Weitermachen mit Top-1, oder neues Vorhaben?
```

Wenn keine offenen Items: `Top-Vorschläge: keine offenen Items in dieser Lane.` plus Lane-Charta-Reminder mit Eintritts-Vorhaben-Optionen.

## Aufräum-Akt (nach Vorhaben-Abnahme)

Befolge `~/Cowork/.claude/rules/workflow.md` Aufräum-Akt — 4 Pflicht-Schritte (Persona-Update / Cross-Projekt-Check / Rolling-Slot / Cross-Persona-Konsultation) + Push-Backstop. Skip nur mit Begründung in `wiki/synthesis/cross-project-lessons.md`.

## Cross-Refs

- Lane-Modell canonical: `~/Cowork/wiki/concepts/lane-vorhaben-modell.md`
- Workflow (8-Schritt-Plan-Akt + Aufräum-Akt): `~/Cowork/.claude/rules/workflow.md`
- Aktive Lanes: `~/Cowork/wiki/lanes/`
- Backlog-Files: `~/Cowork/wiki/projects/*-backlog.md`
