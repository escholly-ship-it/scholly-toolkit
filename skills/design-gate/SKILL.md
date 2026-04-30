---
name: design-gate
description: Design-Tool-Gate (Phase C Schritt 2) — Prueft ob Claude Design noetig ist und ob es laeuft
---

# Design-Tool-Gate (STOPP-Regel — Regel 15)

**Beruehrt dieser Sprint visuelle Elemente?**

**Claude Design ist seit Sprint 169 der Primaer-Pfad** (claude.ai/design Web-UI). Stitch wurde Sprint 170 (CC-152) vollstaendig entfernt.

## Entscheidungsbaum

```
Visuelle Arbeit im Sprint?
├── UI-Screen/Layout?
│   ├── Stufe 1: Claude Design (claude.ai/design → HTML/JSX-Export)
│   ├── Stufe 2: Claude Design (HTML-Export + CSS-Iteration)
│   └── Stufe 3: Implementierung via `claude-design-to-nextjs` Skill
│       (6-Schritt-Loop mit Playwright + design:design-critique bis ACCEPT)
│       Trigger: Tier-1-Projekte (Cookmark, KiHire, Kaderplaner, Trainerbank,
│       Trainingsplaner, Sportlicher Leiter, Koerperschule, Roadmap-Tool).
│       Details + Einsatz-Matrix in `~/.claude/skills/claude-design-to-nextjs/SKILL.md`.
├── Pitch-Deck / Slides?
│   ├── PRIMAER: Claude Design (HTML-Export → Print/PDF)
│   └── Fallback: Gamma
├── Daten-Infografik (LinkedIn, Report)?
│   ├── PRIMAER: Claude Design (HTML/SVG-Komposition, Tokens aus design-tokens.md)
│   └── Fallback: Satori+Sharp (COWORK-16 Generator) — bis Migration komplett
├── Illustration / Header / Metapher-Bild?
│   ├── Einmalig abstrakt? → Claude Design (SVG)
│   ├── Fotorealistisch? → Gemini Pro Browser ($0)
│   └── Konsistent-Serien? → ComfyUI lokal (nur wenn Gemini zu generisch)
├── Icon? → Iconify SVG-Import direkt (kein Vektor-Editor noetig)
├── Logo/Branding? → Claude Design (HTML/SVG-Export)
├── SVG-Grafik? → Claude Design (HTML/SVG-Export)
├── Diagramm? → Claude Design ODER Mermaid inline
├── Design-QS? → Manueller Review gegen design-tokens.md + WCAG-Checks
└── Keins davon? → Kein Design-Tool noetig → GATE PASSED
```

## RLS-Policies-Check bei neuen Supabase-Tabellen (CC-197, Sprint 193)

**PFLICHT bei JEDER neuen API-Route die auf einer Supabase-Tabelle ausser `roadmap_items` operiert.**

Grund: Sprint 182 CC-195 — API-Route mit anon-Key updatete 0 Rows, weil `project_priority` nur `SELECT public` + `ALL service_role` Policy hatte. Fehler: HTTP 400 "Cannot coerce the result to a single JSON object".

**Check-Schritt (Planning, vor dem Bauen):**
1. Tabelle identifizieren, die der neue Endpoint liest/schreibt.
2. `pg_policies` abfragen:
   ```sql
   SELECT policyname, cmd, roles, qual FROM pg_policies
   WHERE tablename = '<tabelle>';
   ```
   (Supabase MCP `execute_sql` oder Dashboard → Database → Policies.)
3. Pruefen: Existiert eine Policy die `anon`/`authenticated` fuer das benoetigte Command (SELECT/INSERT/UPDATE/DELETE) zulaesst?
4. Fehlt die Policy → Migration **mitplanen** (`CREATE POLICY ... ON <tabelle> FOR <cmd> TO public USING (...)`). KEIN Phase D ohne diese Migration im Plan.

**Pattern-Referenz:** `memory/experte-devops.md` Sprint 182 Learning.

## Tool-Health-Check (autonom, NICHT Scholly fragen)

**Claude Design (PRIMAER):** claude.ai/design — Web-UI verfuegbar wenn Session angemeldet. API/MCP noch nicht released (CC-150 trackt Release — Check alle 3 Sprints).
Quick-Check: Chrome MCP `browser_navigate` auf `https://claude.ai/design` → erreicht Login-Seite oder App? Keine 404.

## STOPP-Regeln

1. **UX/UI-Experte + Visual Designer MUESSEN im Team sein** wenn visuelle Arbeit ansteht
2. **Infografik-Designer MUSS aktiviert werden** bei Infografiken/Datenvisualisierungen
3. **Stufe 1: Rohling generieren** — Claude Design
4. **Stufe 2: Verfeinerung via Claude Design HTML-Export + CSS-Iteration** — Pixel-Perfektion
5. **Ohne BEIDE Stufen darf KEIN visueller Code geschrieben werden** — Phase D blockiert
6. **"Standard-Pattern" ist KEINE Ausnahme** — kein Experte darf "zu simpel" entscheiden
7. **Claude Design Release-Watch (CC-150):** Wenn in Phase A ein API/MCP-Release auftaucht → Ghostwriting-Runner + INFRA-API-WATCH entbloecken, nicht weiter mit Web-UI-only arbeiten.

## Design-Tokens
Referenz: `memory/design-tokens.md` (Single Source of Truth seit Figma-Teardown Sprint 167 — Dateiname bleibt historisch, Inhalt ist tool-agnostisch).
Aenderungen direkt dort pflegen, dann Sync in `globals.css`.
