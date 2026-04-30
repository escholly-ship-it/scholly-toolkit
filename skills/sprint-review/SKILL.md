---
name: sprint-review
description: Sprint-Zeremonie Phase E — Qualitaetssicherung + Kunden-Abnahme (6 Schritte)
---

# Phase E — Review (Qualitaetssicherung + Kunden-Abnahme)

**CC-271 (Sprint 226) — skill-review-invoked Marker PFLICHT:** Als ERSTE Aktion diesen Skills setzen:
```bash
SPRINT_TAG=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null | tr -d '[:space:]')
MARKERS_DIR="$HOME/Cowork/.phase-markers/$SPRINT_TAG"
echo done > "$MARKERS_DIR/skill-review-invoked"
```
Ohne diesen Marker blockiert phase-gate.sh den E=done-Write. Freihand-Review (ohne Skill-Invocation) ist damit technisch unmoeglich.

**CC-325 (Sprint 234) — TTL-Refresh PFLICHT bei Stretch-Sprints:** Direkt nach skill-review-invoked-Marker ALLE Phase-Marker `touch`-en. Verhindert TTL-Block bei Sprints >6h (a-*, b-*, c-*, d-* Marker waeren sonst stale).
```bash
find "$MARKERS_DIR" -type f -name "[abcd]-*" -exec touch {} +
```
Damit laeuft das 6h-TTL-Fenster ab Skill-Invocation neu, nicht ab erstem Marker-Set. Ohne diesen Schritt blockierte phase-gate.sh in Stretch-Sprints (Sprint 229 Erfahrung).

**CC-278 (Sprint 232) — Auto-Migrate Tag PFLICHT vor Marker-Set:** Sprint-Tag kann zwischen Phase A und Phase E rotieren (z.B. Resume nach `/model`-Switch, Claude-Code-Restart). Phase-Marker leben dann unter altem Tag und sind unsichtbar. Vor dem Setzen des `skill-review-invoked` Markers `auto_migrate_tag_if_needed` ausfuehren — analog zu sprint-retro Schritt 0:
```bash
source ~/.claude/hooks/lib/session-paths.sh "" \
  && source ~/.claude/hooks/lib/auto-migrate-tag.sh \
  && auto_migrate_tag_if_needed
```
Bisher wurde Tag-Drift erst in Phase F vom retro-Skill aufgefangen. Damit erbt Phase E die alten Marker bei Mid-Sprint-Tag-Drift.

**SMI-49 Phase-Auto-Write (Sprint 219):** Direkt am Start diesen Skills MUSS `current_phase='E'` in Supabase gesetzt werden, damit das schollmayer.info Hero-Widget die Phase korrekt anzeigt. Via Supabase MCP:
```sql
UPDATE roadmap_config SET current_phase='E', current_sprint_meta_updated_at=NOW() WHERE key='global_sprint';
```
Bei statischem Astro-Output: zusaetzlich `git commit --allow-empty -m "trigger redeploy phase=E" && git push` im schollmayer-info Repo (andernfalls zeigt Widget veraltete Phase bis naechster Code-Commit).

Alle 6 Schritte in dieser Reihenfolge. Kein Feature ist "fertig" bis alle abgehakt sind.

**Reihenfolge-Regel (CC-75, Sprint 153):** Kunden-Abnahme kommt VOR Doku+Backup.
Grund: Bei "Nicht OK" wuerde ein vorzeitiges Backup unnoetige Commits erzeugen, die im Fix-Zyklus ueberschrieben werden. Backup erst wenn Scholly freigegeben hat.

<!-- Modell-Switch-Signal entfernt (Sprint 217 Korrektur):
     Mid-Sprint-Wechsel widerspricht Schollys Workflow ("nur 1 Modell-Wahl
     beim Sprint-Start, ab da autonom"). Sprint laeuft im am Sprint-Start
     gewaehlten Modell durch. -->


## Schritt 1: Debugging + Bug Fixing

**Projekt-Typ-Detection (CC-209, Sprint 195):** `package.json` (Web/Node), `Package.swift` oder `*.xcodeproj` (Swift/macOS), `Cargo.toml` (Rust), `pyproject.toml` (Python). Fehlt alles → reines Memory-/Prozess-Projekt, Build-Check skippen.

**Build-Status (auto-auswaehlen):** !`cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" && if [ -f package.json ]; then echo "[Web/Node]"; npx tsc --noEmit 2>&1 | tail -5; elif [ -f Package.swift ] || ls *.xcodeproj >/dev/null 2>&1; then echo "[Swift/macOS] — xcodebuild manuell pruefen (z.B. 'xcodebuild -scheme <Scheme> -quiet build')"; elif [ -f Cargo.toml ]; then echo "[Rust]"; cargo check 2>&1 | tail -5; else echo "Kein Code-Projekt erkannt — Build-Check skippen"; fi`
**Lint (nur Web/Node):** !`cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" && if [ -f package.json ]; then npm run build 2>&1 | tail -10 || true; else echo "Skip — kein npm-Projekt"; fi`

- Build/Lint fehlerfrei?
- Betroffene Seiten visuell pruefen (Screenshot/Preview)
- Bugs sofort fixen, NICHT auf "spaeter" verschieben
**Marker:** `mkdir -p ~/Cowork/.phase-markers && echo done > ~/Cowork/.phase-markers/e-build`

### Schritt 1b (optional): /ultrareview fuer Code-Sprints (CC-93 Sprint 148)
**Nur bei Code-schweren Sprints (Hook-/Skill-Changes, Feature-Implementation).** Nicht fuer reine Doku/Memory-Sprints.

- Kommando: `/ultrareview` in der CLI ausfuehren
- Output: Dedizierter Review mit Bugs + Design-Issues
- Verfuegbarkeit: Pro + Max, 3 freie Reviews pro Account zum Testen, danach kostenpflichtig
- **Entscheidung dokumentieren:** Wenn Review Findings hat → in Phase E Schritt 1 als Bugs einplanen. Wenn keine Findings → weiter zu Schritt 2.
- **Skip-Kriterium:** Sprint ohne Code-Aenderungen (nur Memory/Doku) → /ultrareview ueberspringen (kein Mehrwert).

## Schritt 2: Refactoring + Technische Schulden
- Code aufgeraeumt: Keine Quick-Hacks, keine TODO-Kommentare die nicht im Backlog stehen
- Technische Schulden = Null (Regel 4)

### Schritt 2b (optional): /simplify fuer Code-Sprints (Sprint 150)
**Nur bei Code-Sprints mit >50 geaenderten Zeilen.** Nicht fuer Memory/Doku/Prozess-Sprints.

- Kommando: `/simplify` in der CLI ausfuehren
- Mechanik: Spawnt 3 parallele Review-Agents (Reuse, Quality, Efficiency), fixt gefundene Issues automatisch
- Output: Aufgeraeumte Commits nur auf geaenderte Dateien bezogen
- **Skip-Kriterium:** Reine Memory/Doku/Prozess-Sprints → `/simplify` ueberspringen (kein Mehrwert).
- Quelle: Boris Cherny (Claude Code Creator) empfiehlt `/simplify` als Standard-Verification vor Abnahme.

## Schritt 3: Testing
- Betroffene Features manuell durchtesten (alle relevanten Flows/Modi)
- Edge Cases pruefen die in Phase B/C identifiziert wurden
- Regressions-Check: Haben bestehende Features Schaden genommen?
- Mobile First (Regel 23): Viewport auf 375x812 stellen

### Aggregations-Visual-Check (CC-283, Sprint 226) — PFLICHT bei Listen/Aggregations-Render

Sprint 221 Case-Study: GW-102 Apify-Bug (Doppel-Eintrag im Dashboard) war nur visuell sichtbar — JSON-Diff zeigte ihn nicht. Phase E hatte nur JSON-Diff geprueft.

**Trigger:** Code-Aenderungen die Aggregations-Layer, Listen-Rendering, Dashboard-Views, Tabellen oder gruppierten Inhalt betreffen (z.B. Änderungen an `map()`, `filter()`, `reduce()`, API-Aggregations-Endpoints, Dashboard-Datenpipelines).

**Check (zusaetzlich zu JSON-Diff):**
1. `preview_screenshot` oder Browser-Render des betroffenen Views
2. Visuell pruefen: Sind alle erwarteten Items da? Keine Duplikate? Reihenfolge korrekt?
3. Bei Diskrepanz zwischen JSON-Diff (sieht ok aus) und visuellem Output → STOPP Schritt 3, zurueck zu Schritt 1.

**Skip-Kriterium:** Reine Config-/Memory-/Hook-Aenderungen ohne UI-Komponente.

### Menubar/Statusbar-Rendering-Check (CC-226, Sprint 196) — PFLICHT bei Menubar-/Statusbar-Apps

Sprint 190 Case-Study: ClaudeBar-Menubar zeigte Prozentzahl abgeschnitten (NSStatusItem-Length-Bug). `pgrep ClaudeBar` = "App laeuft" ≠ "UI rendert korrekt". Regression wurde erst in Phase D von Scholly entdeckt — Phase E Schritt 3 hatte nur Prozess-Aliveness geprueft.

**Trigger:** Swift/SwiftUI-App mit `NSStatusItem`, `MenuBarExtra` oder `statusBar` im Code, oder macOS-App die sich primaer in der Menubar/Statusbar praesentiert (Kandidaten: ClaudeBar).

**Check (ersetzt Prozess-Only-Verifikation):**
1. Prozess-Check: `pgrep -x <AppName>` — App laeuft
2. **Screenshot-Check PFLICHT:** Via `mcp__computer-use__screenshot` oder `screencapture -R <x,y,w,h> menubar-check.png` — Menubar-Region oben rechts (z.B. `screencapture -R 1100,0,340,28 menubar-check.png`) und visuell pruefen:
   - Icon/Label vollstaendig sichtbar (nicht abgeschnitten, kein `...`)
   - Prozentzahlen/Zahlen nicht abgeschnitten (volle Breite da)
   - Farbe/Kontrast im aktuellen macOS-Theme (Dark/Light) lesbar
   - Status-Icon korrekt (nicht Default-Fallback)
3. Bei Abweichung: STOPP Schritt 3 — zurueck zu Schritt 1 (Bug-Fix).

**Skip-Kriterium:** Reine Web-/CLI-/LaunchAgent-Projekte ohne Statusbar/Menubar-UI.

### Mobile-Scroll-Test (CC-196, Sprint 193) — PFLICHT bei jeder Seite mit Scroll-Inhalt

Sprint 182 Case-Study: `/prio`-Liste in iOS PWA war nicht scrollbar (`h-full overflow-hidden` am Body). Screenshot hatte Scroll-Bug nicht gezeigt. Abnahme verweigert.

**Check via Claude Preview (nur bei Web-Apps mit Listen/langen Seiten):**
```javascript
// preview_eval — liefert Diagnose zurueck
(() => {
  const el = document.scrollingElement || document.documentElement;
  const h = { scrollHeight: el.scrollHeight, clientHeight: el.clientHeight };
  el.scrollTop = el.scrollHeight;
  const after = el.scrollTop;
  return {
    ...h,
    scrollable: h.scrollHeight > h.clientHeight,
    reachedBottom: after > 0
  };
})()
```

**Regeln:**
- `scrollHeight <= clientHeight` auf einer Liste/langen Seite → **Warnung**: Body/Container hat vermutlich `overflow-hidden` oder `h-full` ohne Scroll-Parent. Root-Cause fixen, nicht durchwinken.
- Nach Scroll-to-Bottom: Screenshot am Ende erzwingen (`preview_screenshot`). So wird der unterste sichtbare Teil sichtbar — nicht nur der Top-Viewport.
- Skip-Kriterium: Seiten ohne nennenswerten Scroll-Inhalt (Loader, leere Zustaende, Error-Screens).

### Test-Diff-Pflicht (Regel 109, CC-323, Sprint 242) — PFLICHT vor `e-testing`-Marker

**Vor dem Setzen des `e-testing`-Markers:** Der Sprint-Diff MUSS mindestens eine Test-File-Aenderung enthalten, sonst STOPP.

```bash
# Sprint-Range bestimmen: Commits seit Sprint-Start (oder seit letztem `.sprint-tag`)
SPRINT_BASE=$(git log --since="$(date -v-3d +%Y-%m-%d)" --format="%H" --reverse | head -1)
[ -z "$SPRINT_BASE" ] && SPRINT_BASE=$(git rev-parse HEAD~10)

TEST_DIFF=$(git diff --stat "$SPRINT_BASE" HEAD -- \
  '*.test.*' '*.spec.*' 'tests/' '__tests__/' 'e2e/' '*.bats' 2>/dev/null)
CODE_DIFF=$(git diff --stat "$SPRINT_BASE" HEAD -- \
  '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.py' '*.sh' '*.swift' 2>/dev/null \
  | grep -vE '\.test\.|\.spec\.|tests/|__tests__/|e2e/|\.bats')

# Skip-Pfad pruefen
PHASES_FILE="$HOME/Cowork/.sprint-phases-$(cat ~/Cowork/.current-sprint-tag | tr -d '[:space:]')"
SPRINT_TYPE=$(grep -E "^SPRINT_TYPE=" "$PHASES_FILE" 2>/dev/null | cut -d= -f2)

if [ -z "$CODE_DIFF" ]; then
  echo "✅ Kein Code-Diff im Sprint — Test-Diff-Pflicht entfaellt."
elif [ "$SPRINT_TYPE" = "prozess" ] || [ "$SPRINT_TYPE" = "memory-only" ]; then
  echo "✅ SPRINT_TYPE=$SPRINT_TYPE — Test-Diff-Pflicht entfaellt."
elif [ -z "$TEST_DIFF" ]; then
  echo "❌ STOPP: Code geaendert, aber KEIN Test-File angefasst."
  echo "   Item-ID + Test-Plan nachreichen ODER SPRINT_TYPE=prozess setzen."
  exit 1
else
  echo "✅ Test-Diff vorhanden:"
  echo "$TEST_DIFF"
fi
```

**Skip-Pfade (Marker darf trotzdem gesetzt werden):**
1. Kein Code-Diff im Sprint (reine Memory/Doku/Config-Aenderung).
2. `.sprint-phases` enthaelt `SPRINT_TYPE=prozess` oder `SPRINT_TYPE=memory-only`.
3. Sprint hat ausschliesslich Refactoring-Items ohne neue Logik (selten — explizit dokumentieren).

**Bei STOPP:** Test-Datei nachschreiben (sample-input-driven Critical-Path-Test, NICHT bash -n / file-existence). Erst dann Marker setzen.

**Marker:** `echo done > ~/Cowork/.phase-markers/e-testing`

## Schritt 4: Production-Deployment verifizieren

**Deploy-Gate-Heuristik (CC-213, Sprint 192):** `/deploy-verify` NUR laufen wenn tatsaechlich Production-Code veraendert wurde.

```bash
# Diff gegen Production-Pfade pruefen
DEPLOY_DIFF=$(cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null && git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '^(src/|app/|pages/|public/|api/|supabase/|vercel\.json|next\.config|package\.json)' | head -5)
if [ -z "$DEPLOY_DIFF" ]; then
  echo "SKIP /deploy-verify — kein Production-Diff (nur Memory/Skill/Hook-Changes)."
else
  echo "RUN /deploy-verify — Production-Diff: $DEPLOY_DIFF"
fi
```

**Skip-Kriterien:** Memory/Skill/Hook-only Sprints (Aenderungen nur in `~/.claude/` oder `memory/`). Prozess-Arbeit ohne Deploy-Artefakte.
**Run-Kriterien:** Jede Aenderung unter `src/|app/|pages/|public/|api/|supabase/` oder an `package.json`/`vercel.json`/`next.config.*`.

Wenn **RUN:** Nutze `/deploy-verify`. Deploy muss VOR der Abnahme laufen, damit Scholly Production-URL/Screenshots sieht.
Wenn **SKIP:** Marker direkt setzen mit Grund, `/deploy-verify` ueberspringen.

**Marker:** `echo done > ~/Cowork/.phase-markers/e-deploy`

## Schritt 5: Kunden-Abnahme (STOPP-Pflicht — Regel 47)

**KEIN Weitermachen ohne Kunden-OK. Dieser Schritt gatet Schritt 6.**

**Sprint 217 Korrektur — Dies ist der ZWEITE und LETZTE Scholly-Interaktionspunkt im Sprint.** (Erster = Phase A Sprint-Ziel-Bestätigung.) Nach Scholly-OK laeuft ALLES bis zum Sprint-Ende komplett autonom durch (Schritt 6 Doku+Backup → Phase F Retro → Phase G Uebergabe). KEIN weiterer Trigger noetig.

### Pre-Abnahme-Gate: Keine verkleideten Scholly-Tasks (Regel 99 + Sprint-250-Verschaerfung — Cloud-tauglich)

**Kanonische Quelle: Diese Skill-Anweisung** (LLM-Self-Check). Bash-Hook ist lokaler Backup, NICHT Pflicht. Der Check funktioniert auch in Cloud-Sessions ohne Hook-Support — das LLM liest das Skill, fuehrt den Check selbst durch.

**LLM-Self-Check (PFLICHT, Cloud + Lokal):**

VOR dem Posten des Abnahme-Blocks: Pruefe den vollstaendigen Entwurf-Text gegen ALLE Verbots-Patterns. Wenn auch nur EINS trifft → Block neu schreiben oder Folge-Item anlegen.

**Verbotene Patterns** (case-insensitive, im gesamten Block):
- `Scholly[ -]?Action` / `Scholly[ -]?Klick` / `Scholly[ -]?muss` / `Scholly[ -]?soll`
- `Scholly[ -]?Hinweis` / `Scholly[ -]?Follow.?Up`
- `manueller? Eintrag` / `manuell.{0,30}(eintragen|hinzufuegen|setzen|aktivieren|nachtragen)`
- `manuell.{0,30}(durch|von).?Scholly`
- `Scholly[ -]?Klick.?(im|in).?(Dashboard|Supabase|Vercel|Notion)`
- `(Supabase|Vercel|Notion|GitHub).?(Dashboard|UI).{0,50}(eintragen|hinzufuegen|setzen|aktivieren)`
- `(im|in.{0,5}|via).?(Supabase|Vercel|Notion|Stripe).?(Dashboard|UI).?(noetig|erforderlich|ergaenzen)`

**Lokal (mit Bash):** Optional zum Sicherheitscheck:
```bash
echo "$DRAFT_TEXT" | bash ~/.claude/hooks/pre-abnahme-no-scholly-action.sh
```
Exit 0 = sauber, Exit 1 = WARN, Exit 2 = STOPP. **In Cloud-Sessions: Hook nicht aufrufbar — LLM-Self-Check oben ist verpflichtend.**

**3-Fragen-Check fuer jede Aktion die wie Scholly-Task aussieht:**
1. **Q1: Digital ausfuehrbar?** Mgmt-APIs (Vercel, Supabase, Notion, Stripe, GitHub, Apify), CLIs (vercel, supabase, gh, brew, npm), MCPs (notion, supabase, stripe, betterstack, vercel), Computer-Use, Claude-in-Chrome → JA → SELBST machen, in Sprint reinnehmen oder ad-hoc ausfuehren.
2. **Q2: Echter Nicht-Digital-Block?** (Hardware-Aktivierung, Behoerden-Besuch, Person-Interview) → Im Backlog als `Scholly:`-Abhaengigkeit mit Begruendung *warum* nicht digital. **NICHT im Abnahme-Block.**
3. **Q3: Einmal-Setup-Hindernis?** (Personal-Token, OAuth-Consent, ein-Mal-Browser-Login) → **Folge-Item im Backlog** ("CC-XXX: Setup + Workflow autonom"), Setup einmal durch Scholly + danach **dauerhaft Claude-Job**. **NICHT im Abnahme-Block des aktuellen Sprints.**

**Zulaessig im Abnahme-Block:** Nur das Wort "OK" zur Abnahme selbst (= der einzige Scholly-Klick im gesamten Sprint).

Cross-Ref: `memory/feedback_no_scholly_actions_for_digital.md` (Re-Check Sprint +5). Cloud-Migration-Plan: CC-391 Hook→Skill-Migration.

### Cross-Sprint-Migrations-Survey (Pflicht-Block, CC-377 Sprint 252 + CC-NEW Sprint 250 Scholly-Forderung — Cloud-tauglich)

**VOR dem Abnahme-Block — Cross-Sprint-Migrations-Survey generieren + im Abnahme-Block einbinden.**

Dieser Block stellt sicher dass kein Migrations-Item ueber mehrere Sprints unter den Radar rutscht. Pflicht ab Sprint 252 (CC-377 Carry-Over aus Sprint 249, Schollys Anforderung Sprint 245).

**Cloud-Pfad (kanonisch, funktioniert IMMER):**
```bash
TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null || echo "$ROADMAP_TOKEN")
curl -s -H "Authorization: Bearer $TOKEN" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/cross-project-overview
```
Endpoint liefert Markdown-Block direkt. In Cloud-Sessions ohne Bash: WebFetch auf URL.

**Lokal-Backup (Python-Skript):**
```bash
python3 ~/.claude/skills/sprint-review/cross-project-overview.py
```

Output: Markdown-Tabellen mit allen Master-Initiativen. Sprint 252 Stand:
- **Cloud-Migration P3-P6** (CC-CLOUD-MIGRATION) — Sessions+Memory in Cloud
- **Roadmap 2.0 α-ε + CUTOVER** (CC-394) — Astro+Supabase-Direct
- **Testing-Initiative** (CC-322 Regel 109) — Critical-Path-Tests pro App
- **Cookmark 2.0** (CT-35..42) — Multi-User-Refactor + Stripe
- **SSV-Cluster Migration** (CC-316 Spike) — Notion → Supabase fuer KP/TB/SL/CT-Cluster
- **Routinen-Initiative** (ROUTINEN-INITIATIVE-MASTER) — 11 Items S252-256 R1/R2/R5/Connectors
- **Hardening** (Sprint-250-Pakete) — Pre-Push, Auth+Telegram, SVG-Migration

Pro Initiative: Status, Liefer-Bilanz (done/total), aktive Items in Sprints, Memory-Ref. Quelle: Roadmap-API + Memory-Files.

Der Block MUSS im Abnahme-Posting unter dem Deliverables-Block erscheinen — Scholly-Forderung Sprint 250: "Am Sprintende benoetige ich die Uebersicht ueber den Fortschritt aller grossen Initiativen, aller grossen Projekte, die Cross-Projekt- und Cross-Sprint-Funktionen."

Initiativen-Definition liegt im API-Endpoint + Skript (`INITIATIVES`-Liste in `cross-project-overview.py`). Bei neuer Master-Initiative: Liste in beiden Quellen erweitern, dann verfuegbar.

**Abnahme-Block Format (CC-213 gekuerzt, Sprint 192):**
```
## Sprint [Nr] — Abnahme

| # | Deliverable | Evidenz |
|---|-------------|---------|
| D1 | [Titel] | [URL/Commit/Output] |

**Abweichungen:** [falls keine: "keine"]

**"OK" zur Abnahme, sonst konkrete Kritik.**
```

Telegram-Push (AUTO-10) SOFORT nach Block:
```bash
bash ~/Cowork/scripts/notify-scholly.sh kunden-abnahme "Sprint $(cat ~/Cowork/.sprint-global) — Abnahme noetig. Proof im Chat."
```

**Cloud-Mode-Fallback (CC-382, Sprint 247):** Bei Cloud-Sessions ohne Bash:
```
POST https://roadmap-escholly-ship-its-projects.vercel.app/api/notify-scholly
Authorization: Bearer <API_TOKEN>
Body: {"type":"kunden-abnahme","message":"Sprint X — Abnahme noetig. Proof im Chat.","sprint":<n>}
```

**STILLE PAUSE = SKILL-VERSTOSS.** Push MUSS raus VOR dem [wartet auf Scholly]-Block. Heute bei Kritik-Fix-Schleifen ebenfalls: jede Klaerungs-Frage an Scholly braucht erst `notify-scholly.sh phase-wait "..."`.

Bei Kritik sofort fixen.

**Bei "OK" → SOFORT AUTONOM ohne weitere Bestaetigung (Sprint 217 — minimal-Interaktion-Policy):**
1. Marker `e-abnahme` setzen
2. Schritt 6 (Doku+Backup) durchlaufen
3. Direkt im Anschluss `Skill(sprint-retro)` invoken — KEINE Pause, KEIN Trigger-Wort abwarten ("Uebergabe"/"Gute Nacht" sind nicht mehr noetig)
4. sprint-retro durchlaeuft Phase F+G autonom bis Counter-Inkrement + GitHub-Backup + Telegram-Notification
5. Erst NACH Phase G Ende ist die Session fertig

**Marker:** `echo done > ~/Cowork/.phase-markers/e-abnahme`

## Schritt 6: Dokumentation + Backup (NACH Abnahme — CC-75, Sprint 153)

**Notion-Update ist NICHT in Phase E** — er passiert in Phase G (nach Retro + Backlog), damit Kunden-Feedback, Retro-Erkenntnisse und Backlog-Aenderungen mit einfliessen. Siehe `/sprint-retro` Phase G Schritt 1a.

- Memory-Index aktualisieren — Status, Stand-Datum
- Im Code: Relevante Kommentare, saubere Typen

**Teardown-Verifikations-Grep (Regel 92, CC-217 Sprint 187 — STOPP-Pflicht wenn Teardown-Item in Sprint):**

Falls der Sprint ein Teardown/Migrations-Item enthielt (Titel oder Notizen mit "Teardown", "Migration", "entfernt", "raus", "ENTFERNT"): PFLICHT-Lauf von `~/.claude/hooks/regel92-teardown-grep.sh`.

```bash
# Keywords aus Backlog-Item extrahieren — Tools/Pakete/Scripts die ausgebaut wurden
# Beispiel Sprint 187: "satori|mflux|INFOGRAPHIC_SPEC|metaphors\.json"
KEYWORDS='<pipe-separated-liste>'
bash ~/.claude/hooks/regel92-teardown-grep.sh "$KEYWORDS" --allow-historic
```

- **Exit 0:** Sauber — alle Referenzen in Archive, Backlog-Item-Beschreibungen oder historischen Markern. Weiter.
- **Exit 2:** Blocker — es gibt aktive Referenzen ausserhalb. Phase E kann NICHT abgeschlossen werden. Jede Trefferzeile entweder umschreiben, als historisch markieren, oder in archive/ verschieben. Re-Run bis Exit 0.

### Cloud-Compat: Inline-Teardown-Check (CC-391, Sprint 254 — Pattern 5)

**Cloud-Pfad (kanonisch):** Cloud-Sessions ohne Bash fuehren den Teardown-Grep via Grep-Tool aus statt via Hook-Script.

**Self-Check:**
1. Sprint-Item-Liste pruefen — gibt es Teardown-Keywords (`Teardown|Migration|entfernt|raus|ENTFERNT`) in Titel/Notizen?
2. Wenn ja: Keywords der entfernten Tools/Pakete extrahieren (z.B. `satori|mflux|stitch`).
3. `Grep`-Tool ueber `~/.claude/projects/-Users-scholly/memory/` und `~/Cowork/` mit Pattern, exclude `archive/|node_modules/|venv/|site-packages/`.
4. Bei Treffern ausserhalb der Excludes: STOPP, jede Trefferzeile umschreiben/archivieren.

**Self-Test:** Teardown-Sprint mit Keyword `stitch` simulieren → Grep ueber Memory + Cowork → bei aktiven Treffern ausserhalb archive/ → STOPP, Phase E nicht durchwinken.

**Lokal-Backup:** Bash-Hook-Script wie oben.

Der Hook belegt dass die Migration wirklich durch ist — ohne den Lauf bleibt Regel 92 nominell erfuellt aber strukturell unerfuellt (Case-Study: Sprint 185 GW-55 war nominell done, Sprint 187 GW-63/64/65/66 mussten den unvollstaendigen Teardown nachziehen).

**Zur E/G-Backup-Duplikation (CC-123, Sprint 159):** Phase E *und* Phase G fuehren beide ein GitHub-Backup aus — das ist bewusst, kein Bug. Das Phase-E-Backup greift als Sicherung, falls die Session nach der Kunden-Abnahme abbricht (Crash, Power-Loss, versehentliches Exit), bevor Phase F+G laufen — dann ist der akzeptierte Stand mindestens bis hierhin gesichert. Das Phase-G-Backup ist der regulaere Abschluss am Sprint-Ende mit den Retro- und Backlog-Aenderungen. Ohne diese Duplikation wirkt es wie ein Bug — ist aber Absicht.

**STOPP — GitHub-Backup (Regel 26):**
- Memory geaendert? → `cd ~/.claude && git add -A projects/-Users-scholly/memory/ CLAUDE.md settings.json hooks/ skills/ && git commit -m "Backup nach [Projektname] Sprint [Nr]" && git push`
- Infrastruktur geaendert? → `cd ~/Cowork && git add -A && git commit -m "Backup nach [Kontext]" && git push`

**STOPP — Recovery-Note (Regel 31):** Drei Fragen pruefen:
1. Credential/Secret geaendert? (API-Key, PIN, Token, DB-ID)
2. Backup-Architektur geaendert? (neues Verzeichnis im git-add, neuer LaunchAgent, neues Repo)
3. Recovery-Runbook-Schritt veraltet oder neu noetig? (neue Dependency, neuer Verify-Schritt)
→ Wenn JA auf eine der drei → Apple Note "Claude Code — Disaster Recovery" aktualisieren.

**Marker:** `echo done > ~/Cowork/.phase-markers/e-doku-backup`

## Phase-State E=done setzen + Weiter zu Retro
Nutze das **Edit-Tool** um in `~/Cowork/.sprint-phases` die Zeile `E=` auf `E=done` zu aendern.
→ Nutze `/sprint-retro` fuer Phase F.
