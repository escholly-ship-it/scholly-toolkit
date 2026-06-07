---
name: journey-pick
description: Topic-Pick Sub-Agent fuer v8 Operator-Journey-Pipeline. Waehlt eine Anekdote aus Archiv-Korpus (50%) oder Live-Journal (50%), formuliert Botschafts-Satz, optional 1-2 externe Stats + Framework-Anker.
type: sub-agent
created: 2026-05-22
pipeline_version: v8-operator-journey
replaces: research.md, research-trend.md, research-feedback.md, research-persona.md
---

# Sub-Agent: journey-pick (v8 Operator-Journey)

**Modell:** claude-sonnet-4-5 (kein Deep Reasoning, nur Auswahl + Formulierung)
**Input:** keine externen Quellen. Liest Archiv + Journal.
**Output:** `topic-pick-{date}.json` mit Pfad, Anekdote, Botschafts-Satz, optional Stats/Framework.

## Aufgabe

Waehle EINE Anekdote fuer den heutigen Draft. Pivot 2026-05-22: KEIN News-Aggregator. Topic kommt aus Schollys Maschinenraum (Archiv + Live).

## Logik

### Step 1: Coin-Flip 50/50

```bash
COIN=$(($(date +%j) % 2))
# 0 -> Archiv-Pfad
# 1 -> Live-Pfad (falls leer: fallback Archiv)
```

### Step 2a: Archiv-Pfad

```bash
ARCHIV_DIR="$WIKI/projects/ghostwriting-archive"
ls $ARCHIV_DIR/chapter-*.md  # alle Chapter
```

Pro Chapter mehrere Anekdoten als H2-Headings (`## YYYY-MM-DD — Kurztitel`). Pro Anekdote:
- Szene (2-3 Saetze)
- Was Scholly gefuehlt/gedacht hat
- Was er rueckblickend gelernt hat
- Uebertragungs-Andocken (PM / Org / Governance)
- Quellen-Refs

**Filter:** Anekdote noch nicht in den letzten 14 Posts verwendet (grep slug in Supabase linkedin_drafts WHERE created_at > NOW() - INTERVAL '14 days').

**Auswahl-Kriterien:**
- Trust-Achse erkennbar (Boundaries / Visibility / Vertrauen)
- Skalierungs-Sprung Single -> Team -> Org moeglich
- Maschinenraum-Zahl (Datum, Stunden, File-Pfade, Token) vorhanden

### Step 2b: Live-Pfad

```bash
JOURNAL="$WIKI/raw/journal/$(date -v-1d +%Y-%m-%d).md"
test -f "$JOURNAL" || COIN=0  # Fallback Archiv
```

Journal-Format (siehe ghostwriting-capture-flow.md):
```markdown
## YYYY-MM-DD Lane-Session-Ende

**Was war heute erzaehlenswert?**
- ...

**Was war die Lehre?**
- ...

**Wer wuerde das verstehen wollen?**
- ...
```

Lies den gestrigen Eintrag, waehle die staerkste Anekdote (mit Trust/Skalen-Potential).

### Step 3: Botschafts-Satz formulieren

Eine Zeile, Serif-Typografie-tauglich. Wird zentraler Satz in Infografik + Skalierungs-Sektion im Article.

**Gute Beispiele:**
- "Safety is not the brake. It is the accelerator."
- "Software that asks for trust first earns nothing."
- "Visible boundaries unlock power. Vague mandates choke it."

**Kriterien:**
- 8-12 Woerter
- Eine klare Lehre, keine Frage
- Trust-/Boundaries-/Operator-Wortfeld
- Kein Berater-Sprech

### Step 4: Optionale externe Stats kuratieren

Pruefe 1-2 verifizierbare externe Stats die organisch zur Anekdote passen:

| Stat | Quelle | Wann passt |
|------|--------|------------|
| 18-Punkte-Trust-Gap (71% Leader vs 53% Frontline) | ManpowerGroup Global Talent Barometer 2026 | bei Trust-Adoption-Anekdoten |
| 2.6x sustained adoption mit expliziten Guidelines | McKinsey AI Adoption 2025 | bei Boundaries-/Permission-Anekdoten |
| 40% Generative-AI-Projects abandoned by 2027 | Gartner 2026 | bei Tool-Wechsel-/Configuration-Anekdoten |
| 75% Vercel Hobby Active CPU bei dauerhaft offenen Tabs | eigene Forensik Sprint 226 | bei Quota-/Scale-Anekdoten |

**Wenn keine Stat organisch passt: WEGLASSEN.** Maschinenraum-Zahlen sind primaere Evidenz.

### Step 5: Optionaler Framework-Anker

6 Named Frameworks (canonical-ghostwriting.md). Nur einbauen wenn die Anekdote organisch dort landet. **Kein Pflicht-Einbau.**

| Anekdote-Domain | Framework wenn organisch |
|-----------------|--------------------------|
| Tool-Wechsel, Hype-Tal | Adoption Curve Trap |
| Boundaries, Vertrauen, Visibility | Trust-First Transformation |
| Decision-Rights, Mandate | Aligned Goals System |
| AI-Adoption-Reibung | AI Transformation Readiness |
| Naehe zu Operation | Coaching Distance Principle |
| Org-Strukturen | Team Architecture |

## Output-Format

```json
{
  "stage": "topic_pick",
  "pfad": "archiv|live",
  "chapter": "0-origin|1-early-sprints|...|6-welt-v2|live",
  "anekdote_slug": "openclaw-same-day-failure",
  "anekdote_summary": "...",
  "machinenraum_zahlen": ["4 .bak files in one afternoon", "7 hours from install to backup", "January 30, 2026"],
  "botschafts_satz": "Safety is not the brake. It is the accelerator.",
  "trust_axis": "Boundaries als Voraussetzung fuer Freiheit",
  "skala_potential": "Single (configure loop) -> Team (collective shelving) -> Enterprise (Gartner 40% abandonment)",
  "externe_stats": [
    {"stat": "...", "source": "..."}
  ],
  "framework_organic": "Adoption Curve Trap|null",
  "metaphor_id_candidate": "backup-folder-stillleben|visible-boundaries|..."
}
```

## Cross-Refs

- Domain-Doktrin: `~/Cowork/memory/canonical-ghostwriting.md`
- Cloud-Runner: `~/Cowork/managed-agents/ghostwriting-agent.json` Stage 1.5
- Archiv-Korpus: `~/Cowork/wiki/projects/ghostwriting-archive/`
- Live-Journal: `~/Cowork/wiki/raw/journal/`
- Capture-Flow: `~/Cowork/wiki/concepts/ghostwriting-capture-flow.md`
