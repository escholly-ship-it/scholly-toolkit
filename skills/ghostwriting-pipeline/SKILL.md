---
name: ghostwriting-pipeline
description: Multi-Agent Ghostwriting Pipeline — orchestriert 5 Sub-Skills (research, draft, review, infografik, publish-prep) zu einem End-to-End-Workflow von Topic-Auswahl bis Dashboard-Publish. Ersetzt den monolithischen ghostwriting-runner.sh durch verkettete spezialisierte Sub-Agents (Sprint 243 GW-24a).
type: skill
created: 2026-04-29
sprint: 243
---
# Ghostwriting Pipeline — Multi-Agent Orchestrator

**Sprint-Quelle:** GW-24a (Sprint 243)
**Architektur:** 5 spezialisierte Sub-Agents + Bash-Orchestrator
**Vorgaenger:** `~/Cowork/agents/ghostwriting-runner.sh` (monolithisch, 1.500+ Zeilen Prompt)

## Warum Multi-Agent?

Der monolithische Runner laeuft alles in einem `claude -p` Call durch — Research, Draft,
Stoppregeln-Check, Infografik-Generierung, Dashboard-Publish. Probleme:

1. **Kontext-Overhead:** Der Runner laedt alle Persona-Memories, Stoppregeln,
   Beispiel-Drafts in EINEN Context — auch wenn ein Schritt nur einen Teil braucht.
2. **Fehler-Propagation:** Ein Fehler in Schritt 4 (Infografik) zwingt den Runner alle
   Schritte 1-3 zu wiederholen.
3. **Validation-Kosten:** Stoppregeln-Check ist ein anderes Reasoning-Pattern als Draft-
   Erstellung — verschiedene Modelle (Opus fuer Reasoning, Haiku fuer Validation) machen
   Sinn.
4. **Beobachtbarkeit:** Bei einem Failure ist nicht klar welcher Schritt fehl-schlug.

Multi-Agent-Pipeline loest das durch:
- **Spezialisierte Sub-Agents** mit minimalen Personas (nur was sie brauchen)
- **File-based Handoffs** zwischen Stufen (Output Stufe N = Input Stufe N+1)
- **Modell-Routing pro Stufe** (Research = Sonnet, Draft = Opus, Review = Haiku, etc.)
- **Per-Stufe Idempotenz** (Restart bei Fehlschlag von der gestarteten Stufe)

## Pipeline-Architektur

```
Trigger (LaunchAgent oder GHA)
  │
  ├── Schritt 0: Pre-Flight (Bash) — STOPPREGEL 7, GW-114 Pillar-Quote, GW-94 Queue
  │
  ├── Stage 1: research/ — claude -p mit research-Sub-Agent
  │   Input: trend-radar.json + briefing.md + 7d-feedback.md
  │   Output: research/{date}-{slug}.json (sources, framework, hook-candidates)
  │
  ├── Stage 2: draft/ — claude -p mit draft-Sub-Agent
  │   Input: research-output + persona-scholly.md + content/CLAUDE.md
  │   Output: drafts/{date}-{slug}.md (status: draft, hook, body, hashtags)
  │
  ├── Stage 3: review/ — claude -p mit review-Sub-Agent (Sonnet, fast)
  │   Input: draft
  │   Output: review-report.json + ggf. revised-draft.md
  │   STOPP-Pflicht: STOPPREGELN 1, 5, 6, 7, 9, 10, 11, 12 muessen pass
  │
  ├── Stage 4: infografik/ — claude -p mit infografik-Sub-Agent (Opus + Vision)
  │   Input: draft
  │   Output: {date}-{slug}-infografik.html + .png + iteration-log
  │   Self-Critique-Loop: bis ACCEPT (max 8 Iterationen, GW-68)
  │
  └── Stage 5: publish-prep/ — claude -p mit publish-prep-Sub-Agent (Haiku, schnell)
      Input: draft + infografik
      Output: dashboards/{date}-{slug}.html + GCal-Event + Telegram-Push
```

## Files

- `SKILL.md` — diese Datei (Pipeline-Description)
- `sub-agents/research.md` — Research-Stage Agent-Definition
- `sub-agents/draft.md` — Draft-Stage Agent-Definition
- `sub-agents/review.md` — Review-Stage Agent-Definition
- `sub-agents/infografik.md` — Infografik-Stage Agent-Definition
- `sub-agents/publish-prep.md` — Publish-Prep-Stage Agent-Definition
- `~/Cowork/agents/pipeline/ghostwriting-pipeline-orchestrator.sh` — Bash-Orchestrator

## Verwendung

**Vollstaendiger Lauf:**
```bash
bash ~/Cowork/agents/pipeline/ghostwriting-pipeline-orchestrator.sh
```

**Einzelne Stage:**
```bash
bash ~/Cowork/agents/pipeline/ghostwriting-pipeline-orchestrator.sh --stage draft
```

**Dry-Run (zeigt was passieren wuerde):**
```bash
bash ~/Cowork/agents/pipeline/ghostwriting-pipeline-orchestrator.sh --dry-run
```

**Resume (von letztem Failure):**
```bash
bash ~/Cowork/agents/pipeline/ghostwriting-pipeline-orchestrator.sh --resume
```

## Modell-Routing

| Stage | Modell | Warum |
|-------|--------|-------|
| research | claude-sonnet-4-5 | WebSearch + Content-Synthesis, kein Deep Reasoning |
| draft | claude-opus-4-7 | Voice-Konsistenz + Stoppregel-Antizipation, hoechstes Quality-Niveau |
| review | claude-haiku-4-5 | Pattern-Matching gegen 12 Stoppregeln, Speed > Reasoning |
| infografik | claude-opus-4-7 | Vision-Critique + HTML/CSS-Iteration, Reasoning + Visual |
| publish-prep | claude-haiku-4-5 | Template-Filling + curl-Calls, kein Reasoning noetig |

**Token-Spar-Effekt:** Vom monolithischen Runner (~50K input tokens, alle Personas)
auf ~10K input tokens pro Stage = ~70% Reduktion bei gleicher Qualitaet.

## Idempotenz

Jede Stage prueft am Anfang ob ihr Output bereits existiert (z.B. `drafts/{date}-{slug}.md`)
und ueberspringt sich selbst falls ja. Bei Failure: Re-Run der Pipeline startet wieder
bei der ersten unfertigen Stage.

State-Tracking: `~/Cowork/.pipeline-state-{date}.json` mit Per-Stage-Status.

## Cross-Refs

- Vorgaenger: `~/Cowork/agents/ghostwriting-runner.sh`
- Phase D Migration-Plan: nach 14 Tagen erfolgreichen Multi-Agent-Laeufen wird der
  Monolith entfernt (Regel 92 Teardown-Pflicht)
- GHA Cloud-Pfad: `.github/workflows/ghostwriting-daily.yml` ruft den Orchestrator
- Persona-Briefings: jeder Sub-Agent liest nur die Persona-Sections die er braucht
  (Voice-Library statt Full-Persona)
