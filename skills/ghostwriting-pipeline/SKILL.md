---
name: ghostwriting-pipeline
description: "[SUPERSEDED 2026-06-04: v8-LEGACY, NICHT-aktiv. Aktive v9-Ghostwriting = Cloud-Routine (Live-Prompt trig_01CRGQsB4zciwSGFLQmrkc8U) + memory/canonical-ghostwriting.md. Diese Multi-Agent-Pipeline (GW-24a-Experiment) ist nicht-wired, NICHT fuer v9 verwenden.] Ghostwriting Pipeline v8 Operator-Journey (Legacy) — Topic-Pick -> Draft -> Review -> Infografik -> Publish-Prep."
type: skill
created: 2026-04-29
updated: 2026-05-22
sprint: 243
pivot: 2026-05-22-operator-journey
---

# Ghostwriting Pipeline v8 — Operator-Journey (SUPERSEDED, v8-LEGACY)

> **⚠️ SUPERSEDED 2026-06-04 — v8-LEGACY, NICHT AKTIV.** Diese Multi-Agent-Pipeline (Topic-Pick / Draft / Review / Infografik-Sub-Agents) ist ein nicht-wired GW-24a-Experiment-Pfad und steht durchgehend auf **v8** (Drei-Schichten / Maschinenraum-Zahlen-Forensik / Trust-Pflicht / Single->Team->Enterprise). **Die AKTIVE Ghostwriting-Pipeline ist die Cloud-Routine** (Live-Prompt `trig_01CRGQsB4zciwSGFLQmrkc8U` via RemoteTrigger) **+ `~/Cowork/memory/canonical-ghostwriting.md`** — beide auf **v9** (Vibe-Coder / PM-Rollen-Transformation: Vier-Bewegungen, SR-V9, story-first/kein-Namens-Vorspann, Zahlen-als-Evidenz). **Weder diese Pipeline noch `managed-agents/ghostwriting-agent.json` als v9-Quelle verwenden** — beide sind historische v8-Backups.

**Pivot 2026-05-22 (historisch):** v7 News-Reaction ersetzt durch v8 Operator-Journey.

**v9-Source-of-Truth (aktiv):** Cloud-Routinen-Live-Prompt (`trig_01CRGQsB4zciwSGFLQmrkc8U`) + `~/Cowork/memory/canonical-ghostwriting.md` + `~/Cowork/wiki/personas/{content-stratege,content-copy}.md`. Die `managed-agents/ghostwriting-agent.json` ist v8-LEGACY-Backup (nicht live-synced).

Diese SKILL.md ist **Architektur-Doku eines Legacy-Pfads**, nicht ausgefuehrter Code.

## Pipeline-Architektur v8

```
Cloud-Routine Trigger (taeglich 09:00)
  |
  +-- Stage 0: Pre-Read (canonical-ghostwriting.md, persona-scholly.md, 3 Welt-V2-Personas)
  |
  +-- Stage 1: Stale-Cleanup + SR-7 Block-Check (linkedin_drafts Supabase)
  |
  +-- Stage 1.5: TOPIC-PICK (Operator-Journey, NICHT News-Reaction)
  |     Coin-Flip 50/50:
  |       0 -> Archiv-Pfad: wiki/projects/ghostwriting-archive/chapter-*.md, Anekdote waehlen
  |       1 -> Live-Pfad: ~/Cowork/wiki/raw/journal/$(date -v-1d +%Y-%m-%d).md
  |     Botschafts-Satz formulieren (Serif-Typografie-tauglich, eine Zeile)
  |     Optional: 1-2 externe Stats + Framework-Anker (nur wenn organisch)
  |
  +-- Stage 2: DRAFT (Article + Teaser, Drei-Schichten Story 20% / Lessons 50% / Transfer 30%)
  |     - Teaser 1300-1900 chars
  |     - Article 2500-5500 chars mit Lead/Story/Three Lessons/Skalierungs-Sektion/Bio
  |     - Trust-Achse als rote Linie
  |
  +-- Stage 3: REVIEW (Stoppregeln v8)
  |     - SR-1, SR-5, SR-6, SR-9, SR-11 bleiben
  |     - SR-V8-1 Drei-Schichten / SR-V8-2 Trust-Achse / SR-V8-3 Maschinenraum-Zahlen
  |     - SR-V8-4 Skalierungs-Sprung / SR-V8-5 Voice-Anti-Pattern
  |     - DEPRECATED: SR-NEWS-ANKER, SR-POSITION-PFLICHT, SR-NO-MEMOIR
  |
  +-- Stage 4: INFOGRAFIK (Lehr-Botschaft First, NICHT Hero-Zahl-First)
  |     - Drei-Sekunden-Test (Bild -> Lehre -> Teilen-Impuls)
  |     - Emotional-szenische Metapher (Repertoire: visible-boundaries, comic-frame, etc.)
  |     - Serif-Botschaft 48-72px zentral
  |     - 11-Regel-Quality-Checklist
  |     - Self-Critique-Loop max 8 Iter
  |
  +-- Stage 5: Supabase-Insert via Edge-Function (pillar=ai-operator-journey)
  |
  +-- Stage 6: Dashboard + GCal + Trace + Commit + Push + PushNotification
```

## Sub-Agent-Files Status (Pivot v8)

| File | Status v8 | Begruendung |
|------|-----------|-------------|
| `sub-agents/research.md` | **DEPRECATED** | News-Reaction obsolet, Topic kommt aus Archiv/Live |
| `sub-agents/research-trend.md` | **DEPRECATED** | Trend-Radar obsolet |
| `sub-agents/research-feedback.md` | **DEPRECATED** | Feedback-Auswertung bleibt, aber NICHT mehr Pipeline-Pre-Stage |
| `sub-agents/research-persona.md` | **DEPRECATED** | Persona-Briefing direkt in managed-agent.json Stage 0 |
| `sub-agents/journey-pick.md` | **NEU** | Topic-Pick Archiv 50% + Live 50% (siehe managed-agent.json Stage 1.5) |
| `sub-agents/draft.md` | **UPDATE** | Drei-Schichten-Format + Trust-Achse |
| `sub-agents/review.md` | **UPDATE** | Stoppregeln v8 |
| `sub-agents/infografik.md` | **UPDATE** | Lehr-Botschaft First + Drei-Sekunden-Test |
| `sub-agents/publish-prep.md` | **BLEIBT** | Dashboard + GCal unveraendert |

## Token-Spar-Effekt v8

Vom Monolith (~50K input tokens) auf ~12K pro Pipeline-Lauf:
- Stage 1.5 Topic-Pick: 2K (Archiv-Scan oder Journal-Read, KEIN 4-Tier-Source-Universum)
- Stage 2 Draft: 4-6K (3-Schichten Format-Generation)
- Stage 3 Review: 1K (SR v8 Pattern-Pass)
- Stage 4 Infografik: 3-5K (Self-Critique-Loop)
- Stage 5/6: <1K (Edge-Function-POST + Commit)

Effekt: ~76% Token-Reduktion vs v7 (das 4-Tier-Source-Universum war Token-Senke).

## Cross-Refs

- **Source-of-Truth Runner (v9, aktiv):** Cloud-Routinen-Live-Prompt `trig_01CRGQsB4zciwSGFLQmrkc8U` + `~/Cowork/memory/canonical-ghostwriting.md`. (`managed-agents/ghostwriting-agent.json` = v8-LEGACY-Backup, NICHT live-synced, NICHT als v9-Quelle verwenden.)
- **Domain-Doktrin:** `~/Cowork/memory/canonical-ghostwriting.md`
- **Welt-V2-Personas:** `~/Cowork/wiki/personas/{content-stratege,content-copy,infografik-designer}.md`
- **Capture-Flow Concept:** `~/Cowork/wiki/concepts/ghostwriting-capture-flow.md`
- **Archiv-Korpus:** `~/Cowork/wiki/projects/ghostwriting-archive/`
- **Live-Journal:** `~/Cowork/wiki/raw/journal/`
- **Pivot-Decision:** `~/Cowork/wiki/decisions/decision-2026-05-22-ghostwriting-operator-journey-pivot.md`
