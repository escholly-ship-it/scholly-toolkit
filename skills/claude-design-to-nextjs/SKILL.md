---
name: design-to-nextjs
description: Wandelt einen Design-HTML-Export (von claude.ai/design) in eine React/Next.js+Tailwind-Komponente um. 6-Schritt-Loop mit Playwright-Screenshots und design:design-critique-Iteration bis ACCEPT. Nutzen fuer Cookmark, Watchlist, KiHire, Koerperschule, PhysioGPT, Roadmap-Tool. Triggern wenn ein Design-Artefakt in Next.js gebraucht wird.
---

# claude-design-to-nextjs — Workflow

Adaption von `heyadam/claudedesign-to-swiftui` (GitHub, 2026-04-18) auf den Web-Stack (Next.js, React, Tailwind CSS). Schliesst die Luecke zwischen Claude Design (1. Primaer-Pfad fuer visuelle Arbeit seit Sprint 169) und Next.js-Implementierung fuer unsere 6 Web-Apps.

## Voraussetzungen

- Claude-Design-Seite als Referenz-Quelle in einer der drei Varianten:
  - **(a) URL** unter `claude.ai/design/...` — publisher Share-Link oder Artifact-Link
  - **(b) HTML-Export** in einem Verzeichnis (`index.html` + Assets) — aus dem Share-Menue von claude.ai/design gezogen
  - **(c) HTML-Rohling** — direkt in der Session geschriebene self-contained HTML-Datei (Sprint 210 CC-244, wenn Claude-Design-Web-UI nicht erreichbar ist oder die Iteration schneller lokal laeuft)
- **Provenienz-Pflicht:** `inventory.md` (Output Schritt 3) MUSS die Referenz-Quelle in einer Zeile benennen — Format `Ref-Quelle: <a|b|c> — <URL oder Pfad oder Herkunftsnotiz>`. Ohne diese Zeile kein Uebergang nach Schritt 4.
- Installierte Skills: `frontend-design`, `design:design-critique`, `playwright`
- `chrome-headless-shell` verfuegbar (Teil der Playwright-Installation)
- Next.js-Projekt als Zielort (bestehend oder neu generiert)

## Der 6-Schritt-Loop

### Schritt 1 — Referenz laden
- **Option (a) URL:** `curl -L <url> -o ref.html` und evtl. Assets nachziehen. Falls Claude Design Login-geschuetzt ist, stattdessen HTML-Export aus Share-Menue verwenden.
- **Option (b) HTML-Export:** Verzeichnis mit `npx serve -p 3001 .` lokal aufmachen, damit Assets relativ aufloesbar sind.
- **Option (c) HTML-Rohling:** Datei direkt im Working-Directory ablegen (`rohling.html`), Assets inline (base64 / SVG inline) — keine externe Referenz-Quelle noetig. `npx serve` zum Rendern identisch zu Option (b). Provenienz-Zeile in `inventory.md`: `Ref-Quelle: c — HTML-Rohling (In-Session geschrieben, keine Claude-Design-URL)`.

### Schritt 2 — Referenz-Screenshot
`mcp__plugin_playwright_playwright__browser_navigate` auf die lokale/remote-URL, dann `browser_take_screenshot` in voller Seitenbreite und Mobile-Breakpoint (375px). Ablage als `design-ref-desktop.png` und `design-ref-mobile.png`.

### Schritt 3 — HTML + CSS + Assets inventarisieren
Lies die HTML-Datei und extrahiere:
- Struktur (Grobgliederung in Sections / Komponenten-Kandidaten)
- Inline-Styles + verknuepfte Stylesheets
- Verwendete Assets (Bilder, Icons, Fonts)
- Farbwerte, Spacing-Werte, Typografie (Font-Families, Groessen, Gewichte)

Output: Kurze Inventar-Tabelle im Chat (Komponenten, Tokens, Assets), damit Schritt 4 gezielt arbeitet.

### Schritt 4 — Konvertierung via frontend-design Skill
Trigger den `frontend-design` Skill mit dem Inventar und dem Referenz-Screenshot als Kontext. Ziel: eine oder mehrere Next.js-Komponenten (React Server Component oder Client Component je nach Interaktivitaet) mit Tailwind CSS.

Token-Mapping:
- **SVG-Icons** → `lucide-react` wenn aequivalent vorhanden, sonst inline SVG
- **Google Fonts / Webfonts** → `next/font` mit gleicher Family und Gewichten
- **Bilder** → `next/image` mit passenden Width/Height und `priority`-Flag bei Above-the-Fold
- **Farben / Spacing** → Tailwind-Klassen wenn moeglich, sonst `theme.extend` in `tailwind.config.ts`
- **Animationen** → `tailwindcss-animate` oder `framer-motion` je nach Komplexitaet

Ablage: `app/<route>/page.tsx` oder `components/<name>.tsx` — abhaengig von Einzelseite vs. Komponente.

### Schritt 5 — Implementations-Screenshot
Starte Next.js Dev-Server (`npm run dev`) oder nutze existenten. `mcp__plugin_playwright_playwright__browser_navigate` auf `http://localhost:3000/...`, gleiche Breakpoints wie Schritt 2. Ablage `impl-desktop.png` und `impl-mobile.png`.

### Schritt 6 — Critique + Iteration
Trigger den `design:design-critique` Skill mit beiden Screenshot-Paaren (`design-ref-*.png` vs `impl-*.png`). Output ist eine Liste konkreter Diffs (Abweichungen in Spacing, Typografie, Farben, Layout-Ordnung, fehlende Details).

Entscheidungsregel:
- **ACCEPT** — Critique liefert keine kritischen Diffs oder nur optionale Verbesserungen → Komponente gilt als fertig.
- **ITERATE** — kritische Diffs → zurueck zu Schritt 4 mit den konkreten Diff-Punkten als Zusatz-Kontext. Max 3 Iterations-Runden, sonst STOPP und Scholly informieren (analog Regel 15 Infografik-Qualitaet).

## Ablage-Konvention

Pro Konvertierung ein Arbeitsverzeichnis `~/Cowork/design-to-nextjs-runs/<YYYY-MM-DD-slug>/`:
- `ref.html` + `ref-assets/` (Schritt 1)
- `design-ref-desktop.png`, `design-ref-mobile.png` (Schritt 2)
- `inventory.md` (Schritt 3)
- `impl-desktop.png`, `impl-mobile.png` (Schritt 5)
- `critique-round-N.md` (Schritt 6 pro Iteration)
- `HAND-OFF.md` — abschliessend Link zu generierter Komponente + ACCEPT-Stand

Dieses Verzeichnis wird am Sprint-Ende weder committet noch archiviert — nur die generierte Komponente im Zielprojekt zaehlt. Arbeitsverzeichnis kann nach ACCEPT geloescht werden.

## Einsatz-Matrix (forensisch, Sprint 191)

Welche Projekte profitieren wann vom Skill. Tier = wie oft / wie regelmaessig.

### Tier 1 — Primaer-Zielgruppe (bei JEDEM neuen Screen / groesserem Redesign)

| Projekt | Tech-Stack | Konkrete Einsatz-Momente | Typische Komponenten |
|---|---|---|---|
| **Cookmark** | Next.js 16 + Tailwind + PWA | Neue Views, Onboarding, Rezept-Detail-Refresh | Rezept-Karte, Zutaten-Liste, Filter-Panel, Mobile-Navigation |
| **KiHire** | Next.js 16 + Tailwind + pnpm | Admin-Dashboard-Erweiterung, Marketing-Landing, Kandidat-Portal, Arbeitgeber-Portal | Kandidat-Card, Sourcing-Liste, Job-Einreichung-Form, Hero-Section |
| **Kaderplaner** | Next.js 16 + React 19 + Tailwind v4 + PWA | Trainer-View-Umbau, Saisonplanung-Views, neue Dashboards | Spieler-Card, Kader-Matrix, Neuzugang-Form |
| **Trainerbank** | Next.js + Tailwind | Spielerliste-Redesign, Bewertung-Flow, neue Trainer-Rollen | Spielerliste-Item, Bewertung-Form, Trainer-Dashboard |
| **Trainingsplaner** | Next.js 16 + Tailwind v4 + PWA | Neue Block-Typen, Team-Builder-Flows, Share-Views | Trainingseinheit-Card, Block-Editor, Team-Balancer-Panel |
| **Sportlicher Leiter** | Next.js 16 + Tailwind v4 + PWA | Testspiel-Views, Gegner-Matching, Admin-Dashboards | Testspiel-Liste, Matching-Interface, Admin-Dashboard |
| **Koerperschule** | Next.js + Tailwind (Kundenprojekt) | Landing-Page (KS-10), Gesundheitswoche-App-Screens, Paypal-Checkout | Landing-Hero, Kurs-Detail, Checkout-Flow |
| **Roadmap-Tool** | Next.js + Tailwind (Schollys eigenes Sprint-Tool) | Sprint-Spalten-Redesign, Item-Cards, Filter-Panel, Stats-Dashboards | Sprint-Column, Item-Card, Filter-Panel |

### Tier 2 — Fallweise (bei Re-Designs, nicht Alltag)

| Projekt | Tech-Stack | Einsatz |
|---|---|---|
| **PhysioGPT** | Production Live, Next.js/Streamlit-basiert | Fallanalyse-Views, Therapieplan-Rendering (wenn Custom-UI gewuenscht; Streamlit-Flows nicht) |

### Tier 3 — Gering (anderer Tech-Stack oder Ziel)

| Projekt | Einschraenkung |
|---|---|
| **Watchlist** | Vanilla JS + HTML + CSS, kein Next.js. Skill bringt dort nur wenig — der 6-Schritt-Loop waere ueberfrachtet fuer einen einzelnen HTML-Export. Alternative: Claude Design HTML-Export direkt uebernehmen ohne Tailwind-Mapping. |
| **Solaranlage** | evcc bringt eigenes Web-UI mit. Nur bei komplett eigenem Dashboard-Custom relevant — aktuell nicht geplant. |

### Tier 4 — NICHT anwendbar (Skill greift nicht)

| Projekt | Grund |
|---|---|
| **ClaudeBar** | macOS Menu Bar, Swift/SwiftUI. Analog-Skill waere `heyadam/claudedesign-to-swiftui` Adaption. |
| **Papierkram** | Buchhaltung-API + CLI-Scripts, keine UI. |
| **3D-Drucker** | Bambu-MCP + Hardware-Integration, keine UI. |
| **Automatisierung / System-Architektur** | LaunchAgents + Telegram + MCPs, keine UI. |
| **Dream Engine** | LaunchAgent-Audit-System, Telegram-Output, keine UI. |
| **Ghostwriting / Infografiken** | Eigener Workflow via `frontend-design` Skill + Self-Critique-Loop (Sprint 187 GW-68). Claude Design wird dort direkt im Ghostwriting-Runner benutzt, kein Zwischenschritt zu Next.js noetig. |

## Trigger-Kriterien (wann diesen Skill rufen)

Der Skill wird gerufen wenn alle 4 Bedingungen zutreffen:

1. **Tech-Stack passt:** Ziel ist Next.js + Tailwind (nicht Swift, Vanilla, Streamlit, CLI).
2. **Artefakt passt:** Ein Screen/Layout/Komponente, nicht eine Infografik fuer Social-Post (dafuer ist der Ghostwriting-Workflow zustaendig).
3. **Referenz existiert:** Eine Claude-Design-Seite (URL oder HTML-Export) ist vorhanden oder wird in C-Phase erstellt.
4. **Sprint-Scope erlaubt Pixel-Critique:** Der 6-Schritt-Loop braucht Zeit. Bei Quick-Fixes oder reinen Copy-Aenderungen ist das Overkill.

## Anti-Patterns (NICHT nutzen fuer)

- Backend/API-Routes ohne UI-Komponente
- Server-Actions ohne sichtbare UI
- CLI- oder LaunchAgent-Tools
- SwiftUI / macOS-Native
- Infografiken fuer LinkedIn/Substack (→ `frontend-design` Skill direkt)
- Einzelne Copy-Aenderungen in bestehenden Komponenten (zu wenig Hebel fuer 6 Schritte)
- HTML-Email-Templates (anderer Rendering-Kontext)

## Integration in Sprint-Zeremonien

- **Phase C (`/design-gate`):** Wenn Design-Gate erkennt "Web-UI fuer Tier-1-Projekt" → den Skill hier ankuendigen, Referenz-Artefakt in Claude Design anlegen.
- **Phase D:** Skill-Invocation beim Implementieren. 6 Schritte sequentiell.
- **Phase E (`/sprint-review`):** Impl-Screenshot und Referenz-Screenshot als Diff-Paar an Scholly — Pixel-Vergleich ist Abnahme-Kanal.

## Cross-Ref

- Adaption-Vorlage: `heyadam/claudedesign-to-swiftui` (SwiftUI-Variante des gleichen Loops)
- Self-Critique-Loop-Vorbild: Sprint 187 GW-68 (Infografik-Workflow, frontend-design + critique bis ACCEPT)
- Regel 15 (Design-Tools sind Pflicht) — dieser Skill ist die Implementierungs-Seite des Claude-Design-Primaer-Pfads fuer Next.js-Impl
- Design-Tools-Referenz: `reference_design_tools_2026.md` — Multi-Surface-Sektion, Entscheidungsbaum
- Case-Study Sprint 191 Variante B: `~/Cowork/design-to-nextjs-runs/2026-04-19-f8444db7/` (Glue Work Migrates — erster Live-Durchlauf, 2 Iterations-Runden)
