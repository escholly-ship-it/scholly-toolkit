---
name: infografik-designer
description: Erzeugt LinkedIn-Article-Hero-Infografiken (1920×1080 PNG) via Anthropic-natives Stack. Wrapper um den Anthropic frontend-design Skill (HTML/CSS) + Puppeteer (Render-Pass) + Self-Critique-Loop. Cloud-tauglich + lokal-tauglich. v3.2: Thumbnail-Vision (480×270) statt Full-PNG-Vision + Edit-Pattern Pflicht statt Full-Write. Trigger bei Article-Draft-Generation in der Ghostwriting-Pipeline.
type: skill
created: 2026-05-08
last_updated: 2026-05-09-v3.2
sprint_context: Sprint 277 Phase 13 — Token-Effizienz-Forensik (v3.1 deployed, v3.2 fuegt Thumbnail-Vision + Edit-Pattern hinzu, ~-15% Token-Cost vs v3.1)
canonical: true
---

# Infografik-Designer Skill — frontend-design + Playwright Render-Pass

## Zweck

**Wrapper um zwei Anthropic-Marketplace-Plugins:**
1. **`frontend-design` Skill** (Anthropic-offiziell) — produziert HTML/CSS mit Bold-Aesthetic-Direction, Typography-Hierarchie, Spatial-Composition, Backgrounds.
2. **`playwright` Plugin** (Anthropic-Marketplace, Microsoft-Author) — rendert HTML/CSS via Chromium zu PNG.

Plus eigene Schicht:
- Persona-Aktivierung (`experte-infografik-designer.md` Pflicht-Read)
- Brief-Builder mit harten Format-Vorgaben (1920×1080, Schrift-Minima, @SCHOLLY+Headshot Pflicht)
- Self-Critique-Loop (max 20 Iterations, ACCEPT-Gate, Convergence-Stagnation)
- QUALITY_CHECKLIST-Eval (8 Regeln) **gegen das gerenderte PNG via Vision** — nicht gegen Code.

**Anthropic frontend-design Skill:** [scholly-toolkit/skills/frontend-design/SKILL.md](../frontend-design/SKILL.md) — 1:1 Copy aus dem Anthropic Plugin-Marketplace (`claude-plugins-official/frontend-design/60bd21a55bd8`), verfügbar im Repo damit Cloud-Routine-Container darauf zugreift.

**Render-Architektur:**
- **Lokal (Mac):** `chrome-headless-shell` Binary (~/Library/Caches/ms-playwright/chromium_headless_shell-1217/) + `module.mjs renderHtmlToPng()`. Cold-Start 0s.
- **Cloud (Routine-Container):** `npm install playwright && npx playwright install --with-deps chromium` einmalig pro Run, dann Node-Script mit `chromium.launch()` + `page.setContent(html)` + `page.screenshot()`. Cold-Start ~30-60s. Container ist Anthropic-Hosting, alles inhouse.

**Render-Pass ist nicht optional.** Code-direct vom Modell (SVG ohne Browser-Render) hat keine Layout-Engine, keine Font-Metrics, keine CSS-Resolution → mittelmaessige Resultate. Sprint 277 v2 hat das bewiesen, v3 korrigiert es.

**Output:** PNG (1920×1080 oder 1280×720 für kleinere Payload) → JPG-Konvertierung (Quality 75-88) → base64 für Supabase ODER Storage-URL für grosse Bilder.

## Wann diesen Skill nutzen

In der Ghostwriting-Daily-Routine als Stage 4 (Infografik). Kein Standalone-Trigger — wird vom Pipeline-Body explizit als Sub-Skill aufgerufen.

## Pflicht-Lese-Material vor Aktivierung

Skill MUSS am Anfang lesen:
1. `~/.claude/projects/-Users-scholly/memory/experte-infografik-designer.md` — Persona, 8-Schritt-Workflow, QS-Checkliste, Mobile-Schriftgrößen-Minima
2. `~/.claude/projects/-Users-scholly/memory/experte-content-stratege.md` — Pillar-Strategie, Voice
3. `~/Cowork/content/persona-scholly.md` — Tonality + Visual-Brand
4. `~/Cowork/content/linkedin/infografik/module.mjs` — `QUALITY_CHECKLIST` (8 Regeln) + Format-Definitionen

## Workflow (8 Schritte mit Self-Critique-Loop)

### Schritt 1 — Brief generieren

Aus dem Draft-Frontmatter + Body extrahiere:
- `kernaussage`: 1-Satz-Take-Away
- `metric`: EINE Zahl (Prozent/Datum/Ratio) als Pillar-Element  
- `metaphor`: kebab-case-ID (z.B. `gap-discrepancy`, `cycle-clock-drift`, `readiness-split`)
- `why_component`: warum die Aussage wahr ist (Sprint 187 GW-68 STOPPREGEL 10)
- `language`: en|de
- `pillar`: ai-enabler|trust-culture|leadership|org-transformation|tech-cycles

### Schritt 2 — V1 HTML/CSS via frontend-design Skill generieren

**Invocation:**
- Lies erst: `/workspace/cowork/scholly-toolkit/skills/frontend-design/SKILL.md` (Anthropic-Original-Pattern: Bold-Aesthetic-Direction, Typography, Color, Motion, Spatial-Composition, Backgrounds)
- Wende ALLE sechs Surfaces an. Editorial-Illustration-Vibe + bold Data-Overlay — NICHT generic AI-slop.

Plus: harte Vorgaben für LinkedIn-Article-Hero:

**Format:**
- `<html><head><meta viewport ...><style>...</style></head><body>...</body></html>`
- self-contained (keine externen CSS-Files, keine externen Fonts via `@import` — system-stacks)
- Body fixed bei `width: 1920px; height: 1080px; overflow: hidden`
- 16:9 LinkedIn-Article-Hero

**Render-Pass: KEIN SVG-direct mehr.** HTML/CSS wird durch Chromium gerendert (Layout-Engine, Font-Metrics, CSS-Resolution echt verarbeitet).

**Design-Pflicht:**
- Dunkler Hintergrund: deep navy / charcoal (z.B. `body { background: #0a1628; }` mit subtilem Gradient/Noise via radial-gradient oder linear-gradient overlays)
- LinkedIn-Blau-Akzent: `#0a66c2`
- Editorial Illustration Vibe + bold Data-Overlay — KEIN Text-Poster
- Blur-Test: Struktur muss text-blur überleben (Shape, Position, Size kodieren die Aussage)
- EINE Hero-Zahl, gross und unmissverständlich

**Schriftgrößen-Minima (HARD, für 1920×1080-Canvas, in CSS-px):**
- Headline: `font-size >= 80px`
- Hero-Zahl: `font-size >= 200px` (idealerweise 280-380 für die EINE Zahl)
- Takeaway / Callout: `font-size >= 64px`
- Labels / Body: `font-size >= 40px`
- Meta / Eyebrows: `font-size >= 24px`

**Signatur-Block bottom-right (BEIDE Pflicht):**
- `<span style="color: <accent>; letter-spacing: 4px; font-size: 24px+; font-weight: 700">@SCHOLLY</span>`
- `<img src="{{HEADSHOT_DATA_URL}}" style="border-radius: 50%; width: 120px; height: 120px; object-fit: cover; border: 2px solid <accent>">` — circular headshot LINKS vom @SCHOLLY-Text. **`{{HEADSHOT_DATA_URL}}` wird vom Pipeline-Body in Stage 4-Prep durch das tatsaechliche `data:image/jpeg;base64,...` ersetzt** — KEIN `file://`-Pfad verwenden, der ist umgebungsabhaengig (Mac vs Cloud-Container) und fuehrt zu broken-image-Bug. Quelle: `content/linkedin/assets/headshot-240.jpg` (240×240, ~14KB JPG, base64 ~18KB)

**Fonts:** system-safe stacks (keine Google-Fonts-CDN-Calls — Cloud-Container hat eventuell keinen Internet-Zugriff fuer externe Fonts):
- Display-Stack: `font-family: Georgia, "Times New Roman", serif` für Editorial-Vibe
- Bold-Sans-Stack: `font-family: "Inter", "Helvetica Neue", Arial, sans-serif` für Display-Headlines
- Body: `font-family: "Helvetica Neue", Arial, sans-serif`
- Weights: 400, 600, 700, 800, 900 — saubere Hierarchie

**Output-Pfad:** `/tmp/infografik/v{N}.html`

### Schritt 2.5 — Render-Pass: HTML → PNG + THUMBNAIL (v3.2 Token-Effizienz)

**v3.2-Update (Sprint 277 Forensik 2026-05-09):** Render erzeugt zwei Files — Full-PNG (1920×1080) fuer Final-Output + Thumbnail (480×270, JPG Quality 70) fuer Vision-Eval. Vision-Eval auf 480×270 ist ausreichend praezise fuer 8-Regel-QUALITY_CHECKLIST und kostet ~50% weniger image-tokens.

**Lokal (Mac):** `node ~/Cowork/content/linkedin/infografik/module.mjs render /tmp/infografik/v{N}.html /tmp/infografik/v{N}.png`. Nutzt chrome-headless-shell (~/Library/Caches/ms-playwright/).

**Cloud (Routine-Container):** Bash-Block:
```bash
# Einmaliger Cold-Start pro Run (~30-60s, ~150MB):
if [ ! -d /tmp/playwright-installed ]; then
  npm install playwright >/dev/null 2>&1
  npx playwright install --with-deps chromium >/dev/null 2>&1
  touch /tmp/playwright-installed
fi

# Render via inline Node-Script:
node - <<'EOF'
const { chromium } = require('playwright');
const fs = require('fs');
const html = fs.readFileSync('/tmp/infografik/v${N}.html', 'utf8');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.screenshot({ path: '/tmp/infografik/v${N}.png', fullPage: false, type: 'png' });
  await browser.close();
})();
EOF
```

**Pflicht: Render erfolgreich verifizieren.** Wenn PNG-File <50KB → Render fehlerhaft, Stage-Fail, kein Self-Critique.

### Schritt 3 — V1 evaluieren (Self-Critique Iteration 1, **gegen das gerenderte THUMBNAIL via Vision**)

**v3.2-Update:** Lies das **V1-Thumbnail via Read-Tool** (`/tmp/infografik/v1_thumb.jpg`, 480×270, ~5KB). Vision auf Thumbnail ist ausreichend fuer 8-Regel-Eval und halbiert image-tokens. Full-PNG-Read NUR im Final-Step nach ACCEPT (zur Konvertierung in Stage 4g).

Vor v3.2: Vision-Read auf v_N.png (1920×1080) kostete ~1500 image-tokens pro Iter. Nach v3.2: ~750 image-tokens auf v_N_thumb.jpg.

Bewerte visuell gegen die 8 Regeln — NICHT Code-statisch.

**8-Regel-QUALITY_CHECKLIST (visuelle Eval):**

1. **Headshot-Element vorhanden + sichtbar** — circulares Foto ist im Bild bottom-right erkennbar (nicht nur im HTML, sondern im gerenderten PNG)
2. **Keine Lorem-Ipsum / Placeholder-Texte** — alle Texte sind echter Brief-Content
3. **Hero-Zahl unmissverständlich** — eine Zahl dominiert visuell, font-size >= 200px im gerenderten Output
4. **Headline vollständig + lesbar** — kein abgeschnittenes Wort durch overflow, font-size >= 80px
5. **Schrift-Minima erfüllt** — alle Texte mind. 24px Render-Höhe
6. **Visuelle Metapher trägt die Aussage** — Shape/Position/Color kodieren die Aussage, nicht nur Text — Blur-Test mental anwenden
7. **@SCHOLLY-Signatur + Headshot beide bottom-right** — beides sichtbar nebeneinander
8. **Kontrast/Kollision** — keine Texte die unlesbar gegen Background oder andere Elemente stehen, Hierarchie sauber

**Output Verdict:**
- `ACCEPT` — alle 8 PASS, Loop endet, V_final ist V1
- `ITERATE` — mind. 1 FAIL, gehe zu Schritt 4 mit Fix-Liste
- `CAP_REACHED_NOT_IDEAL` — NUR bei iteration >= 20

### Schritt 4 — Iteration N (V2..V20) — EDIT-PATTERN PFLICHT (v3.2)

Bei `ITERATE`:
- Konkrete Fix-Vorschläge generieren (z.B. "Hero-Zahl font-size 180px → 280px", "Headshot fehlt visuell → CSS `position: absolute; bottom: 60px; right: 200px;` korrekt setzen")
- **v3.2 Edit-Pattern PFLICHT:** Verwende NUR Edit-Tool oder MultiEdit auf /tmp/infografik/v{N}.html. NIE Write. Ein Schrift-Groesse-Fix ist ein Edit-Patch (~30 Tokens) statt Full-HTML-Rewrite (~3K Tokens).
- Beispiel:
  ```
  Edit /tmp/infografik/v{N}.html
  old_string: ".hero-num { font-size: 200px; }"
  new_string: ".hero-num { font-size: 280px; }"
  ```
- DANN: `cp /tmp/infografik/v{N}.html /tmp/infografik/v{N+1}.html`
- Render-Pass wiederholen (Schritt 2.5 mit V_{N+1}) — gibt v_{N+1}.png + v_{N+1}_thumb.jpg
- Vision-Eval auf neues THUMBNAIL (v3.2)
- Convergence-Stagnation-Detection: wenn V_N und V_{N+1} dieselben FAILs haben → `CONVERGENCE_STAGNATION`, Loop endet, KEIN Post

### Schritt 5 — CAP-Handler (nur bei iteration == 20)

Wenn nach 20 Iterationen kein ACCEPT:
- `CAP_REACHED_NOT_IDEAL` → KEIN Post (Sprint 187 GW-68: lieber kein Post als unperfekter)
- PushNotification an Scholly: "Infografik-Loop erreichte Iteration 20 ohne ACCEPT — Pipeline gestoppt, manueller Review nötig"
- Save Iteration-Log für forensische Analyse

### Schritt 6 — Output

Bei `ACCEPT`:
- Final-PNG-File-Pfad zurück an Aufrufer (`/tmp/infografik/v{N_final}.png`)
- Iteration-Count + Final-Verdict
- Optional: Iteration-Log als JSON (für Performance-Tracking)

### Schritt 6.5 — Self-Instrumentation (Pflicht für Cloud-Routine-Verifikation)

Routine-Runs sind in der Cloud-Session aus aussen nicht direkt einsehbar (claude.ai-Session-URL ist auth-walled). Daher MUSS die Routine eine maschinenlesbare Trace-Datei schreiben, die ich post-mortem inspizieren kann.

**Pfad:** `content/linkedin/infografik/runs/<kaskade-id>-trace.jsonl`

**Format:** Eine JSON-Zeile pro Stage-Boundary, append-only:
```jsonl
{"stage":"start","ts":"2026-05-08T20:27:30Z","kaskade_id":"...","pipeline_version":"v3"}
{"stage":"stage_0_persona_read","ts_end":"...","duration_s":12,"files_read":7,"status":"ok"}
{"stage":"stage_2_draft","ts_end":"...","duration_s":180,"draft_chars":4804,"pillar":"ai-enabler","status":"ok"}
{"stage":"stage_4a_playwright_install","ts_end":"...","duration_s":52,"chromium_path":"/root/.cache/ms-playwright/...","status":"ok"}
{"stage":"stage_4_iter_1_html_write","ts_end":"...","html_chars":18450,"tool_calls_estimate":16,"status":"ok"}
{"stage":"stage_4_iter_1_render","ts_end":"...","duration_s":8,"png_bytes":2403968,"status":"ok"}
{"stage":"stage_4_iter_1_critique","ts_end":"...","verdict":"ITERATE","fails":["schrift_minima_24px"],"status":"ok"}
{"stage":"stage_4_iter_2_critique","ts_end":"...","verdict":"ACCEPT","status":"ok"}
{"stage":"stage_5_supabase_insert","ts_end":"...","img_chars":20503,"status":"ok"}
{"stage":"end","ts":"...","total_duration_s":1380,"final_verdict":"ACCEPT","iterations":2}
```

**Pflicht-Felder pro Zeile:** `stage`, `ts_end` (oder `ts` für start/end), `status` (ok|fail). Stage-spezifische Zusatzfelder optional.

Bei jedem Stage-Ende `>> trace.jsonl` appendieren. Am Ende `git add` + im finalen Commit mit committen.

### Schritt 7 — Konvertierung für Supabase

PNG ist 2-3MB für 1920×1080. Zu groß für `execute_sql` Inline-Payload und für Notification-Channel-Limits.

**Cloud-Routine konvertiert + uploadet:**

```bash
# JPG-Konvertierung (Quality 88, behält visuelle Qualität):
node - <<'EOF'
const sharp = require('sharp');
sharp('/tmp/infografik/v_final.png')
  .jpeg({ quality: 88, mozjpeg: true })
  .toFile('/tmp/infografik/v_final.jpg');
EOF

# Optional: Wenn JPG > 200KB, Storage-Upload via Supabase MCP statt Inline-base64:
# (Supabase Storage hat eigenen Bucket "infografiks", public URL)

# Inline-base64 nur wenn JPG < 100KB:
B64=$(base64 -w0 /tmp/infografik/v_final.jpg)
DATA_URL="data:image/jpeg;base64,${B64}"
# → execute_sql UPDATE infographic_base64 = DATA_URL
```

Für grosse Bilder: Storage-URL-Pattern (kommt mit Cloud-Pipeline v3).

## Aufrufer-Contract

Pipeline-Body ruft Skill mit:
```
Input:
- post_title (intern, nicht im Bild)
- post_text (Body, erste 6 Zeilen für Brief)
- pillar
- language
- metaphor_hint (optional)

Output:
- svg_code (string, vollständiges SVG-Element)
- iterations_count (int)
- final_verdict (ACCEPT|CONVERGENCE_STAGNATION|CAP_REACHED_NOT_IDEAL)
- iteration_log (json array mit verdict + issues pro Iteration)
```

Pipeline-Body kümmert sich um Supabase-INSERT mit dem PNG/JPG-Output:
- Wenn JPG < 100KB: `infographic_base64 = "data:image/jpeg;base64," + base64(jpg_bytes)` (Inline)
- Wenn JPG >= 100KB: Upload nach Supabase Storage Bucket `infografiks/<kaskade_id>.jpg` → `infographic_base64 = "<public_storage_url>"`

## Konsequenz für Dashboard

Dashboard-Code akzeptiert beide Formate (`<img src={...}>` rendert sowohl `data:`-URLs als auch `https:`-URLs):
- `<img src={draft.infographic_base64}>` rendert beide Pfade
- Download-Button: bei data-URL direkt download, bei https-URL → fetch → blob → download

Detailliert in `~/projects/ghostwriting-dashboard/src/app/draft-view.tsx`.

## Cross-Refs

- `~/Cowork/content/linkedin/infografik/module.mjs` — `buildSvgBrief`, `QUALITY_CHECKLIST`, `resolveLoopVerdict`, `isConvergenceStagnation`
- `~/.claude/projects/-Users-scholly/memory/experte-infografik-designer.md` — Persona-Doc
- `~/.claude/projects/-Users-scholly/memory/audit-2026-05-08-ghostwriting-cleanup.md` — Sprint-277-Refactor-Forensik
