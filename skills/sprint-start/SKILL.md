---
name: sprint-start
description: Sprint-Zeremonie Phase A — Sprint-Ziel festlegen, Backlog verifizieren, Experten-Team zusammenstellen
---

# Phase A — Sprint-Ziel (Session-Start)

**Sprint-Datei (Projekt):** !`cat .sprint 2>/dev/null || echo "KEINE .sprint-Datei — muss angelegt werden!"`
**Globaler Sprint:** !`cat ~/Cowork/.sprint-global 2>/dev/null || echo "KEIN globaler Zaehler!"`
**Systemzeit:** !`date "+%Y-%m-%d %H:%M"`
**Git-Status:** !`git status --short 2>/dev/null | head -5 || echo "Kein Git-Repo"`

## API-Auth (CC-54, Sprint 139)
**Alle Roadmap-API-Aufrufe brauchen den Bearer Token:**
```bash
ROADMAP_TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null)
```
Danach bei jedem curl: `-H "Authorization: Bearer $ROADMAP_TOKEN"`

## Cloud-Compat: Inline-Hook-Patterns (CC-391, Sprint 254)

**Cloud-Sessions unterstuetzen KEINE Bash-Hooks.** Folgende Checks sind als LLM-Self-Check kanonisch in diesem Skill verdrahtet. Lokale Bash-Hooks unter `~/.claude/hooks/` bleiben als Backup, sind aber NICHT pflicht.

### Pattern 1 — Tageszeit-Gruss (Regel 59, ersetzt `regel59-tageszeit.sh`)

**Trigger:** VOR dem Schreiben jedes Markdown-/Text-Files (Code-Files: skip).

**Self-Check:** Enthaelt der Content einen Tageszeit-Gruss? Pattern-Familien:
- `M-Gruss` (5-11h erwartet): "G u t e n M o r g e n", "S c h o e n e n M o r g e n"
- `N-Gruss` (12-17h erwartet): "S c h o e n e n N a c h m i t t a g"
- `A-Gruss` (17-22h erwartet): "G u t e n A b e n d", "S c h o e n e n A b e n d"
- `Nacht-Gruss` (21-04h erwartet): "G u t e N a c h t", "S c h l a f g u t"
- `FE-Gruss` (16-22h erwartet): "S c h o e n e n F e i e r a b e n d"

(Patterns mit Spaces dokumentiert um Pre-Validation-Hook nicht zu triggern — Implementation matched ohne Spaces.)

**Aktion:** Aktuelle Stunde via `date '+%H'` ermitteln + gegen Pattern-Familie validieren.

**Bei Mismatch:** Text zeitneutral umschreiben ODER passenden Gruss waehlen. KEIN Write mit falschem Gruss.

**Self-Test:** "M-Gruss" um 23:30 schreiben → Skill MUSS den Gruss vorher entfernen oder zu "A-Gruss" aendern.

### Pattern 2 — Tech-Debt-Gate (Regel 4, ersetzt `regel4-techdebt-gate.sh`)

**Trigger:** Bevor Phase D startet (nach Schritt 4b).

**Self-Check:** Wurde der Tech-Debt-Check (`a-techdebt`-Marker) gesetzt? Wenn nein → STOPP, nicht zu Phase D wechseln. Cloud-Mode: pruefe via /api/hook-relay POST `{type:"phase-gate", phase:"D", markers:{...}}` ob `a-techdebt` in Phase-A-Markern enthalten ist (siehe Inventar fuer Phase-A-Pflichtmarker).

**Self-Test:** Sprint-Start ueberspringen + direkt `D=in_progress` setzen → STOPP-Pflicht greift, Skill weist auf fehlenden Tech-Debt-Check hin.

### Pattern 3 — ScheduleWakeup-Guard (CC-243, ersetzt `schedulewakeup-guard.sh`)

**Trigger:** Vor jedem `ScheduleWakeup`-Tool-Call mit `prompt` der `/sprint-start|/sprint-review|/sprint-retro` enthaelt.

**Self-Check:** Ist der aktuelle Sprint abgeschlossen (Phase G=done)?
- Cloud: GET `https://roadmap-escholly-ship-its-projects.vercel.app/api/verify` → `currentPhase === 'G' && phaseDone === true` ODER alle Phasen done.
- Lokal: `grep '^G=done' ~/Cowork/.sprint-phases-$SPRINT_TAG`

**Aktion:** Wenn Sprint NICHT done UND Prompt enthaelt Zeremonie-Keyword → ScheduleWakeup-Call NICHT ausfuehren. Stattdessen Sentinel verwenden: `prompt: "<<autonomous-loop-dynamic>>"` ODER Monitor-Tool / run_in_background.

**Ausnahme:** Sentinels `<<autonomous-loop-dynamic>>` + `<<autonomous-loop>>` IMMER erlaubt.

**Self-Test:** Mid-Sprint `ScheduleWakeup(prompt="/sprint-start")` aufrufen → Skill blockiert + schlaegt Sentinel vor.

### Pattern 4 — Auto-Migrate-Tag (CC-247/CC-319, ersetzt `lib/auto-migrate-tag.sh`)

**Trigger:** Am Anfang von sprint-review (Phase E) und sprint-retro (Phase F+G).

**Self-Check (Cloud-Mode):** POST `/api/hook-relay` mit:
```json
{
  "type": "auto-migrate-tag",
  "own_tag": "<aktueller SPRINT_TAG>",
  "own_score": "<Marker-Anzahl + State-Bit>",
  "candidate_tags": [{"tag": "<other_tag>", "score": 5, "mtime": 1700000000}]
}
```
Antwort liefert `action: pull|push|noop` + `source_tag/target_tag`.

**Lokal-Backup:** `source ~/.claude/hooks/lib/session-paths.sh "" && source ~/.claude/hooks/lib/auto-migrate-tag.sh && auto_migrate_tag_if_needed`.

**Self-Test:** Tag-Drift simulieren (zwei `.sprint-phases-*`-Files mit unterschiedlicher Marker-Anzahl) → Skill identifiziert reicheren Tag und uebernimmt dessen Marker.

## Schritt 0: State-Reset + Sprint-Phase-State initialisieren (PFLICHT)
Alte Marker UND Sprint-State aus dem vorherigen Sprint muessen geloescht werden, sonst greifen die Phase-Gates nicht.

**Session-isolierte Marker (CC-96 Sprint 148, CC-105 Sprint 154):** Marker werden IMMER unter `~/Cowork/.phase-markers/<session-id>/` isoliert. Session-ID kommt aus `session-start.sh` via `~/Cowork/.current-sprint-tag`. Legacy-Fallback auf globale Pfade wurde in Sprint 154 entfernt.
```bash
SPRINT_TAG=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null | tr -d '[:space:]')
if [ -z "$SPRINT_TAG" ]; then
  echo "FATAL: Keine Session-ID in ~/Cowork/.current-sprint-tag — session-start.sh hat nicht gelaufen. Neue Session starten."
  exit 1
fi
MARKERS_DIR="$HOME/Cowork/.phase-markers/$SPRINT_TAG"
PHASES_FILE="$HOME/Cowork/.sprint-phases-$SPRINT_TAG"
rm -rf "$MARKERS_DIR"/* 2>/dev/null
rm -f "$PHASES_FILE" 2>/dev/null
mkdir -p "$MARKERS_DIR"
echo "Session: $SPRINT_TAG | Markers: $MARKERS_DIR"
```

**Sprint-Phase-State SOFORT initialisieren (CC-72, Sprint 145):** Nutze das **Write-Tool** um `$PHASES_FILE` mit folgendem Inhalt zu erstellen:
```
project=[PROJEKTNAME oder "tbd" wenn noch unbekannt]
sprint=[GLOBALER_SPRINT]
A=
B=
C=
D=
E=
F=
G=
```
**Warum hier:** Tech-Debt-Check (Schritt 4b) liest `.sprint-phases` fuer das Projekt-Verzeichnis. Ohne Datei → Deadlock.

**Marker-Konvention (CC-80):** Marker ERST setzen wenn der Schritt ERFOLGREICH abgeschlossen ist. Nie praemptiv. Bei API-Fehler oder unvollstaendigem Ergebnis: Marker NICHT setzen.

## Pflicht-Schritte (strikt sequentiell)

### Schritt 1: Arbeitsregeln lesen (Schicht 2 — Prozessregeln)
Lies `memory/arbeitsregeln.md` KOMPLETT. `Read` ohne offset.

Die Schicht-1-Verhaltensregeln (`memory/verhaltensregeln.md`) sind bereits via SessionStart-Hook im Kontext — NICHT erneut laden. Schicht-3-Domainregeln werden bei Experten-Aktivierung on-demand geladen.

**CC-256 Hinweis (Sprint 217):** Der Phase-Gate (`phase-gate.sh`) prueft NUR das Marker-File `$MARKERS_DIR/a-arbeitsregeln`, NICHT die Form des Read-Calls. Ob du mit einem einzigen Full-Read (empfohlen) oder mit offset/limit-Teilen liest, ist dem Gate egal — Hauptsache der Marker wird nach erfolgreichem Lesen gesetzt. Falls das Gate bei `A=done` blockiert trotz gesetztem Marker: Fehlermeldung lesen — `marker_status=missing` heisst "Marker existiert nicht unter $MARKERS_DIR" (Session-Tag-Drift?), `stale` heisst ">6h alt" (neue Session noetig). Nicht auf den Read-Call schauen.

**Marker:** `echo done > $MARKERS_DIR/a-arbeitsregeln`

### Schritt 2: Backlog lesen
- Notion Konzept-Seite des Projekts oeffnen (ID aus MEMORY.md)
- Memory-Index des Projekts lesen
- Projekt-Backlog lesen

### Schritt 3: Backlog verifizieren
Jedes offene Item pruefen: Noch aktuell? Schon erledigt? Veraltet? Sofort bereinigen.
**Marker (nach Schritt 2+3):** `echo done > $MARKERS_DIR/a-backlog`

### Schritt 3a: Git-Status-Gate — Auto-Commit (CC-237 Sprint 208, CC-259 Sprint 211)

**Zweck:** Verhindert Sprint-194-Incident (5 Code-Files 24h uncommitted in Production).

**AUTONOM (Regel 22/34/41, feedback_pr_merge_selbst):** Bei dirty Code-Repos committet + pusht das Script AUTOMATISCH. KEINE Scholly-Rueckfrage. Commit+Deploy sind Claude-Job, immer.

```bash
bash ~/.claude/skills/sprint-start/git-status-gate.sh
```

**Exit 0:** Clean ODER Auto-Commit+Push erfolgreich. Weiter.
**Exit 1:** Git-Fehler (merge-conflict, push-reject, no-remote). Dann 1-Satz-Meldung an Scholly + autonom Root-Cause fixen. NIE als Ja/Nein/3-Optionen formulieren.

**Marker:** `echo done > $MARKERS_DIR/a-git-status` nach Exit 0.

### Schritt 3b: Backlog-Hygiene verifizieren + API-Cache anlegen (Regel 88, CC-73)

**CC-73 Optimierung (Sprint 155):** Statt 5x API-Call ueber die Session werden `/api/verify` + `/api/items` EINMAL hier parallel geladen und in ein Cache-File geschrieben. Schritte 4a und 4f lesen aus dem Cache.

```bash
CACHE_FILE="$HOME/Cowork/.sprint-start-cache-$SPRINT_TAG.json"

# Parallel beide Endpoints holen
VERIFY=$(curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" https://roadmap-escholly-ship-its-projects.vercel.app/api/verify) &
ITEMS=$(curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" https://roadmap-escholly-ship-its-projects.vercel.app/api/items)
wait

# In ein Cache-File schreiben
python3 -c "
import json, sys
cache = {'verify': json.loads('''$VERIFY'''), 'items': json.loads('''$ITEMS''')}
open('$CACHE_FILE','w').write(json.dumps(cache))
print(json.dumps(cache['verify'], indent=2))
"
```

**Alle checks = true** → Backlog sauber, weiter mit Schritt 4.
**findings vorhanden** → SOFORT bereinigen (Zombies, BLOCKED in Sprints, Misch-Sprints via PATCH). Nach PATCH: Cache neu laden (obigen Block erneut ausfuehren).

**Scholly-Abhaengigkeiten abfragen:** Items mit `Scholly:` im Abhaengigkeit-Feld anzeigen (aus Cache, siehe Schritt 4f). Scholly sagt "erledigt" → PATCH bereinigen + Cache invalidieren.
**Marker:** `echo done > $MARKERS_DIR/a-hygiene`

### Schritt 4: Sprint-Scope + Deliverables + Bestaetigung (Regel 54, 66, 45 — EIN Block)

**4a) Alle Sprint-Items lesen (CC-73: aus Cache):**
```bash
python3 -c "
import json
cache = json.load(open('$CACHE_FILE'))
for i in cache['items']:
    if i.get('sprint_nummer'):
        abh = i.get('abhaengigkeit') or '-'
        print(f'Sprint {i[\"sprint_nummer\"]} | {i[\"projekt\"]} | {i[\"backlog_id\"]} | {i[\"title\"][:60]} | {i.get(\"effort\",\"-\")} | {abh[:40]}')
"
```

**4a2) Dynamischen Sprint-Budget-Richtwert anzeigen (CC-262, Sprint 213):**
```bash
TARGET=$(cat ~/Cowork/.sprint-capacity-target 2>/dev/null || echo "8")
CAP_JSON=$(ls -t ~/Cowork/logs/capacity-*.json 2>/dev/null | head -1)
if [ -n "$CAP_JSON" ]; then
  python3 -c "
import json
d = json.load(open('$CAP_JSON'))
print(f\"📐 Sprint-Budget (empirisch, Fenster {d['window']} Sprints S{d['first_sprint']}-{d['last_sprint']}):\")
print(f\"   Sweetspot: {d['sweetspot']}P | P50: {d['p50']}P | P75: {d['p75']}P | P95: {d['p95']}P\")
print(f\"   Sentiment: {d['sauber_count']} sauber, {d['neutral_count']} neutral, {d['hektik_count']} hektik\")
print(f\"   Quelle: ~/Cowork/.sprint-capacity-target = {$TARGET} (Pack-Algo liest roadmap_config.capacity_target)\")
"
else
  echo "📐 Sprint-Budget: ${TARGET}P (Default — capacity-analysis.py noch nicht gelaufen)"
fi
```
Faellig neu rechnen bei `%13`-Check (Schritt 8). Ad-hoc via `python3 ~/Cowork/scripts/capacity-analysis.py`.

**4a3) Gescheiterte-Sprint-Check (Regel 76):** Item mit `GESCHEITERT` im notizen-Feld → Wiederholungs-Sprint (gleiches Ziel, NEUES Beispiel, autonom ohne Kunden-Iteration). Keine neuen Items.

**4a4) Effort-Vollstaendigkeit (CC-NEW-A, Sprint 244):** Jedes Sprint-Item MUSS einen Effort-Wert haben (XS/S/M/L/XL) ODER explizit als Konzept-Doku-Deliverable klassifiziert sein. Sprint 237 Lehre: 5/8 Items ohne Effort → Pack-Algo + P75-Vergleich blind, Hektik-Detektor unzuverlaessig.

```bash
python3 -c "
import json, os
sprint_tag = os.popen('cat ~/Cowork/.current-sprint-tag | tr -d \"[:space:]\"').read().strip()
cache = json.load(open(os.path.expanduser(f'~/Cowork/.sprint-start-cache-{sprint_tag}.json')))
gs = cache['verify']['globalSprint']
sprint_items = [i for i in cache['items'] if i.get('sprint_nummer') == gs]
no_effort = [i for i in sprint_items if not i.get('effort')]
if no_effort:
    print(f'⚠️  EFFORT FEHLT bei {len(no_effort)} Sprint-Items:')
    for i in no_effort:
        print(f'  {i[\"backlog_id\"]:15} | {i[\"title\"][:55]}')
    print('→ Pflicht: PATCH effort setzen ODER notizen mit \"[KONZEPT-DOKU]\"-Tag versehen.')
else:
    print(f'✅ Effort-Vollstaendigkeit: alle {len(sprint_items)} Sprint-Items haben Effort.')
"
```

**STOPP-Pflicht:** Bei Treffern PATCH `effort=<XS/S/M/L/XL>` ODER `notizen` mit Praefix `[KONZEPT-DOKU]` versehen. Konzept-Doku-Items zaehlen 0P im Pack-Algo. KEIN Item ohne Klassifikation in den Scope-Block (4e) durchwinken.

**4b) Tech-Debt-Check (Regel 4 — STOPP-Gate, CC-27):**
1. Projekt-Backlog nach `[TECH-DEBT]` / `[SCHULDEN]` Tag scannen
2. Projekt-Verzeichnis scannen (wenn Code-Projekt): `grep -r "TODO\|FIXME\|HACK\|XXX" ~/projects/$PROJECT_DIR/src`
3. STOPP wenn Backlog [TECH-DEBT] Items > 0 → ZUERST einplanen
4. WARNUNG wenn TODO/FIXME > 10 → im Chat melden, kein STOPP
5. Escape: Scholly "kann warten" → `echo skip > ~/.claude/hooks/.skip-regel4`
6. Reine Prozess-/Infra-Sprints: Nur Backlog-Check, kein Code-Scan

**Marker:** `echo done > $MARKERS_DIR/a-techdebt`

**4c) Thematische Konsistenz + Frist-Check (Regel 79):**
- **Thema-Check (STOPP):** Alle Items gleiches Projekt/Thema? Sonst 🛑 STOPP, Misch-Sprint aufteilen.
- **Frist-Check:** Zukunfts-Frist → blockiert (via PATCH `sprint_nummer=null`). Erreichte/ueberschrittene Frist → ggf. dringend.

**4c2) Dependency-Hard-Gate (CC-Sprint-242 Commitment, Regel 80) — STOPP-Pflicht:**

Jedes Sprint-Item mit `blocked_by_item_id` MUSS einen Vorgänger in einem `archived=true` Status oder in einem **früheren** Sprint haben. Sonst STOPP — Item nicht startbar.

```bash
python3 - <<'EOF'
import json, os
sprint_tag = os.popen("cat ~/Cowork/.current-sprint-tag | tr -d '[:space:]'").read().strip()
cache = json.load(open(os.path.expanduser(f"~/Cowork/.sprint-start-cache-{sprint_tag}.json")))
items = cache['items']
global_sprint = cache['verify']['globalSprint']
sprint_items = [i for i in items if i.get('sprint_nummer') == global_sprint]
items_by_id = {i['id']: i for i in items}

blockers = []
for it in sprint_items:
    bid = it.get('blocked_by_item_id')
    if not bid:
        continue
    blocker = items_by_id.get(bid)
    if not blocker:
        blockers.append((it['backlog_id'], 'BLOCKER NICHT GEFUNDEN'))
        continue
    if blocker.get('archived'):
        continue  # Done — OK
    blocker_sprint = blocker.get('sprint_nummer')
    if blocker_sprint is None:
        blockers.append((it['backlog_id'], f"Blocker {blocker['backlog_id']} im Backlog (kein Sprint)"))
    elif blocker_sprint >= global_sprint:
        blockers.append((it['backlog_id'], f"Blocker {blocker['backlog_id']} in Sprint {blocker_sprint} (nicht früher)"))

if blockers:
    print('🛑 STOPP — Dependency-Hard-Gate verletzt:')
    for bid, reason in blockers:
        print(f"  {bid}: {reason}")
    print('Items aus Sprint herausnehmen ODER Vorgänger zuerst abschliessen.')
    exit(2)
print('✅ Dependency-Hard-Gate: alle Vorgänger erledigt oder in früherem Sprint.')
EOF
```

**Bei STOPP:** Item entweder
1. Aus Sprint nehmen via PATCH `sprint_nummer=null`, in späteren Sprint einplanen, ODER
2. Vorgänger in vorigen Sprint vorziehen (PATCH `sprint_nummer=<global_sprint - 1>`), ODER
3. Vorgänger als done markieren wenn faktisch erledigt aber nicht eingetragen (`archived=true`).

**Kein Bypass.** Items mit unfertigen Vorgängern in einem Sprint sind ein Phase-A-Scope-Fehler — das Roadmap-Tool checkt `no_zombie_blocked` automatisch via `/api/verify`, aber dieser Hard-Gate macht es VOR dem Sprint-Ziel-Block sichtbar (statt erst in Phase D zu entdecken — Sprint 242 Lessons-Learned).

**Marker:** `echo done > $MARKERS_DIR/a-deps`

**4d) Detail-Anforderungen laden:** Fuer jede Backlog-ID zugehoeriges Markdown-Backlog lesen.

**4d1) Verify-First-Pattern fuer JETZT-Items (CC-340, Sprint 242) — PFLICHT:**

Sprint 234 Lehre: 5/23 Items waren bereits in fruehen Sprints implementiert (CC-271/272/283/297/333). ~10P Effort gespart durch grep-Verifikation vor Re-Implementation.

Fuer JEDES Sprint-Item mit `horizont = JETZT` (oder ohne expliziten Horizont) **vor** Phase-D-Beginn ein Schluesselwort grep ausfuehren:

```bash
python3 ~/.claude/skills/sprint-start/verify-first.py "$CACHE_FILE"
```

Logik (im Script):
1. Alle Items mit `sprint_nummer = <globaler_sprint>` aus Cache.
2. Pro Item: 2-3 Schluesselwoerter aus `title` extrahieren (groesste Substantive, keine Stopwords).
3. `grep -rln <keyword> ~/.claude/skills/ ~/.claude/hooks/ ~/Cowork/scripts/ ~/Cowork/agents/ ~/projects/ --include="*.md" --include="*.sh" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.mjs" 2>/dev/null | head -10` ueber alle Keywords kombiniert.
4. Treffer ausserhalb `archive/` + `node_modules/` + `.git/` → Item flaggen mit "VERIFY-FIRST: Treffer in <Pfaden> — VOR Implementation pruefen ob Logik schon existiert".
5. Reports only, kein STOPP. Output als Liste in Phase-A-Block 4e direkt unter der Scope-Tabelle.

Skip-Pfad: Items mit `effort=XS` oder `horizont=SPAETER` brauchen keine Verifikation.

**4d2) Supabase-Docs-Snippet (CC-115, Sprint 156):** Falls Sprint-Titel oder -Notizen Supabase-Keywords enthalten (`supabase`, `migration`, `rls`, `pg_policy`, `edge function`, `pgvector`, `realtime`, `pg_cron`): SSH-Docs-Hinweis aus `~/.claude/AGENTS.md` lesen und im Experten-Briefing (Schritt 5c) referenzieren. Kommandos: `ssh supabase.sh cat /supabase/docs/guides/<area>/<topic>.md` oder `ssh supabase.sh grep -r '<term>' /supabase/docs/`.

**4d3-4d8) Konsolidierte Phase-A-Checks (CC-210, Sprint 192):** Ein Script statt 6 inline-Bloecke. Cache wird nur einmal geladen.

```bash
python3 ~/.claude/skills/sprint-start/phase-a-checks.py "$CACHE_FILE"
```

Das Script fuehrt nacheinander aus:
- **freshness-num** (CC-129) — Numerische Zielwerte stale (memory-health.sh-Abgleich)
- **freshness-notes** (CC-134) — Notizen-Heuristik stale (9 Patterns: Subsumiert, Erledigt, Runner stabil, AUS SPRINT GENOMMEN, ...)
- **watch-review** (Regel 94) — Watch-Trigger Review-Faelligkeit
- **watch-rescan** (Regel 94) — Klassifikator-basierter Re-Scan aktiver Backlogs
- **watch-consistency** (Regel 94) — 3-Quellen-Konsistenz (WT-Datei ↔ MD ↔ Roadmap)
- **hook-heavy** (CC-178) — Hook/settings.json-Keyword-Warnung ab 2 Treffern
- **perm-audit** (CC-187) — Permission-Glob-Audit Dark-Spots
- **plugin-cache** (CC-208) — Waisen + Drift-Scan (CC-222-Pattern)

Reports only, keine STOPP-Blockade. Marker werden am Ende gesetzt. Einzelne Checks explizit aufrufbar via zusaetzlichem Argument: `phase-a-checks.py "$CACHE_FILE" freshness-num watch-review`.

**Scholly-Commands (Watch-Trigger via Telegram ODER Chat):**
- `watch-list` — aktuelle Watch-Trigger anzeigen
- `watch-activate WT-NNN` — manuell aktivieren (Trigger als positiv markieren)
- `unwatch WT-NNN: [Grund]` — Watch-Trigger verwerfen, zurueck ins Backlog

**Bei Aktivierung eines Watch-Triggers:**
1. Neues Backlog-Item im Zielprojekt (Roadmap-Tool via Supabase MCP + MD-Backlog)
2. Watch-Eintrag aus `watch-triggers.md` nach `archive/watch-triggers-archiv.md` mit Status "AKTIVIERT"
3. MD-Backlog-Markierung aktualisieren: `→ Watch-Trigger WT-NNN ✅ Aktiviert Sprint X`
4. Telegram-Push via `notify-scholly.sh watch-activated "WT-NNN: [Titel]"`

Bei Rueck-Migration (`unwatch WT-NNN: [Grund]`): 1-4 wie Aktivierung, aber Archiv-Status "VERWORFEN: [Grund]".

**Marker (alle drei setzen, auch bei Warnungen):**
```bash
echo done > $MARKERS_DIR/a-freshness
echo done > $MARKERS_DIR/a-watch-triggers
echo done > $MARKERS_DIR/a-plugin-cache
```


**4e) Scope + Deliverables + Ziel anzeigen (Regel 54+45, CC-69, CC-191):** Alles in EINEM Block:
```
### Sprint [Nr] — Scope + Deliverables
| # | Item | Backlog-ID | Effort | Prod-Touch | Was es fuer dich bedeutet |
|---|------|------------|--------|-----------|--------------------------|
| 1 | ... | ... | ... | ja/nein | [Kundensprache!] |

### Deliverables
| # | Deliverable | Beschreibung |
|---|-------------|--------------|
| D1 | [Kurztitel] | [Was genau geliefert wird] |

**Sprint-Ziel:** [Klares, messbares Ziel]
```

**CC-191 (Sprint 188): Spalte "Prod-Touch"** — Fuer jedes Item angeben, ob waehrend Phase D/E Production-Artefakte (Deploy, Env-Rotation, API-Cutover) beruehrt werden. `ja` = Scholly-Approval VOR Deploy im Scope-Block sichtbar, kein separates Nachfragen in Phase E. `nein` = reine Entwicklung/Prozess. Verhindert die CC-172-Pattern mit zwei getrennten Scholly-Approvals.

**CC-236 (Sprint 210): Prod-Touch-Heuristik — eindeutig entscheidbar.** Prod-Touch = **ja** wenn mindestens EINES zutrifft:
1. **Pfad-Heuristik:** Item beruehrt Dateien unter `~/projects/*` (alle Production-fähigen Projekte — Roadmap-Tool, Trainerbank, Kaderplaner, Trainingsplaner, Cookmark, Watchlist, KiHire, ClaudeBar, PhysioGPT, Koerperschule, Ghostwriting-Dashboard). Grep zur Verifikation: `grep -l "~/projects/<name>" memory/backlog-*.md`.
2. **Deploy-Heuristik:** `git push`, `vercel deploy`, Supabase-Migration, Edge-Function-Deploy, `launchctl bootstrap` eines neuen LaunchAgents, Env-Var-Rotation in Vercel/Supabase/Anthropic.
3. **Live-API-Heuristik:** Item aktualisiert produktiv laufende API-Endpoints oder Datenmodelle, die bereits Traffic sehen.

Prod-Touch = **nein** bei: Skill-/Hook-/Memory-/Prozess-Arbeit in `~/.claude/`, Experten-Persona-Updates, Backlog-Verdichtung, rein forensischen Items (Log-Analyse ohne Write), Runner-Scripts unter `~/Cowork/` solange sie lokal laufen ohne neuen `launchctl bootstrap`.

**Grauzone:** Roadmap-Tool (`~/projects/roadmap/`) ist Prod-Touch=ja weil Vercel-Deploy mit Push triggert. Case-Study Sprint 194: CC-212 wurde als `nein` gelabelt, war aber Roadmap-Code → nachtraegliche Scope-Block-Korrektur in Phase E. CC-236 eindeutig regelt: `~/projects/roadmap/` berührt → Prod-Touch=ja.

**Marker:** `echo done > $MARKERS_DIR/a-deliverables`

**4f) Offene Entscheidungen anzeigen (Regel 67, CC-73+CC-118: aus Cache):**

**CC-118 (Sprint 160):** Action-Labels (`Scholly: [digitale Aktion]`) sind KEINE Entscheidungen mit Optionen — das sind Claude-Todos. Als Entscheidung gilt NUR: Feld startet mit `BLOCKED:` ODER enthaelt Options-Pattern (`(A)`, `(B)`, `A)`, `B)`, `A ODER B`).

```bash
python3 -c "
import json, re
cache = json.load(open('$CACHE_FILE'))
def is_decision(abh):
    if not abh: return False
    if abh.strip().upper().startswith('BLOCKED:'): return True
    if re.search(r'\([A-C]\)|\b[A-C]\)\s', abh): return True
    if re.search(r'\b[A-C]\s+ODER\s+[A-C]\b', abh, re.IGNORECASE): return True
    return False
def is_action_label(abh):
    if not abh: return False
    return abh.strip().startswith('Scholly:') and not is_decision(abh)
decisions = [i for i in cache['items'] if is_decision(i.get('abhaengigkeit',''))]
actions   = [i for i in cache['items'] if is_action_label(i.get('abhaengigkeit',''))]
print('=== OFFENE ENTSCHEIDUNGEN (Scholly-Input) ===')
for i in decisions:
    print(f'{i[\"backlog_id\"]}: {i[\"abhaengigkeit\"]}')
if not decisions: print('(keine)')
print()
print('=== CLAUDE-TODOS (digitale Scholly-Actions, von Claude abzuarbeiten) ===')
for i in actions:
    print(f'{i[\"backlog_id\"]}: {i[\"abhaengigkeit\"]}')
if not actions: print('(keine)')
"
```
Entscheidungen: Scholly antwortet → 3-Schritt-Verarbeitung: (a) Abhaengigkeit-Feld bereinigen (`Entschieden [Datum]: [Ergebnis]`), (b) Notion Entscheidungen-Tabelle, (c) Backlog-Item.
Action-Labels: in den naechsten aktiven Sprint einplanen ODER sofort als Task erledigen — KEINE Scholly-Rueckfrage.

**4g) Fallback:** Kein Sprint vorgeplant → Scholly fragen. Ad-hoc-Thema → Sprint durchfuehren, Item in Phase G nachtragen.

**Nach Bestaetigung:** `.sprint-phases` aktualisieren — `project=` auf echten Projektnamen (Edit-Tool).

**SMI-49 current_sprint_goal Auto-Write (Sprint 219):** Das SMI-Portfolio-Widget (`schollmayer.info` Hero) liest die Spalte `roadmap_config.current_sprint_goal` auf der Row `key='global_sprint'` (Supabase project_id `xeygrtucelnlpliqhnub`). Nach Scholly-Bestaetigung des Sprint-Ziels Goal-String via Supabase MCP schreiben:
```sql
UPDATE roadmap_config
SET current_sprint_goal='<Sprint-Ziel als Text>',
    current_sprint_meta_updated_at=NOW()
WHERE key='global_sprint';
```
SQL-Apostrophe im Goal verdoppeln (`'` → `''`). `current_sprint_goal` ist eine Text-Spalte (NICHT jsonb — nur `value` ist jsonb). Ohne Auto-Write zeigt das Widget den Fallback "Sprint startet gerade". Verify-API (`/api/verify`) liest den Wert fuer getSiteStats().

**Prozess-Sprint-Flag (CC-219, Sprint 193):** Bei reinen Prozess-/Memory-/Hook-/Skill-Sprints (kein Code-Projekt-Touch, kein Deploy) zusaetzlich `SPRINT_TYPE=prozess` in `.sprint-phases` eintragen. `phase-gate.sh` uebersteuert damit die Build/Testing/Deploy-Marker-Checks in Phase E (auto-akzeptieren). Kunden-Abnahme + Doku+Backup bleiben unveraendert PFLICHT. Bei Code-Sprints (Feature/Bugfix mit Production-Touch) Flag weglassen — Gates normal aktiv.

### Schritt 5: Experten-Team zusammenstellen

Framework: `memory/experten-team-framework.md` Kapitel 3.

**Pflicht-Aktivierung (Regel 13):**
- JEDER Sprint → **DevOps + Knowledge Manager** PFLICHT
- Daten-Operationen → Daten-Engineer
- Code-Deploy → QA-Engineer
- Prozess-/Config-Aenderungen → Infrastruktur-Experte
- Ghostwriting → Content-Stratege + Content/Copy + Infografik-Designer
- Visuelle Arbeit → UX/UI + Visual Designer

**Knowledge Manager Sprint-Aufgaben:** A: Index+Formatierung. E: Notion+Hub. F: Regel-Konsistenz. G: Recovery-Note+Archiv.

**Freshness + Weiterbildung (Regel 51 + 53):** Fuer JEDEN aktivierten Experten:
1. `sprint_count` + `last_updated` pruefen — >5 Sprints ohne Update → Warnung
2. `next_research_due` (Integer) pruefen — <= globaler Sprint → Weiterbildung **JETZT** (Regel 53 3-Schritt)
3. Kein `next_research_due` → auf aktuellen Sprint setzen (SOFORT faellig)
4. Paar-Weiterbildung (Regel 52): 2+ Experten faellig → gemeinsam

**Marker:** `echo done > $MARKERS_DIR/a-experten`

### Schritt 5b: Research-Validierung (Regel 53) — PFLICHT
```bash
bash memory/validate-research.sh $(cat ~/Cowork/.sprint-global)
```
**Exit 1 = STOPP.** Typische Fehler: Datum statt Sprint-Nummer, due erhoeht ohne Research.

### Schritt 5b2: Weiterbildungs-Status (CC-77, Sprint 173 — entkoppelt via LaunchAgent)

**Seit Sprint 173:** Experten-Weiterbildung ist vom Sprint-Start-Kritischen-Pfad ENTKOPPELT. Der LaunchAgent `com.cowork.experten-research` (nightly 04:15) zieht pro Lauf EINEN faelligen Experten und fuehrt Research autonom durch. Sprint-Start blockiert NICHT mehr synchron.

**Aktion in Phase A:** NUR pruefen + loggen, NICHT synchron nachziehen.
1. `validate-research.sh` lief bereits in Schritt 5b. Output beachten.
2. Bei Warnungen (faellige Experten): Im Chat kurz nennen — "[N] Experten ueberfaellig, LaunchAgent zieht sie nightly nach."
3. Bei Batch-Ueberfaelligkeit (≥5): `launchctl kickstart gui/$(id -u)/com.cowork.experten-research` — Runner manuell anstossen (laeuft im Hintergrund).

```bash
echo done > $MARKERS_DIR/a-research-completed
```
Marker IMMER setzen (auch bei Warnungen) — blockiert nur noch bei komplett fehlendem Pruefschritt.

### Schritt 5b3: Rolling Research-Slot — DEPRECATED durch CC-77 (Sprint 173)

Rolling-Slot-Logik vollstaendig in `com.cowork.experten-research` ausgelagert. Sprint-Start zieht KEINEN Experten mehr synchron.

**Marker:** `echo done > $MARKERS_DIR/a-rolling-research` (Semantik: "entkoppelt, LaunchAgent uebernimmt").

### Schritt 5c: Cross-Experten-Briefing (Regel 52) — PFLICHT bei 2+ Experten
Format: `[Experte A] → an [B, C]: "Was ich weiss, das fuer EUCH relevant ist: [3 Saetze]"`

### Schritt 6: Agent-Teams-Check + Modus-Empfehlung (Regel 42) — PFLICHT-Output

```
### Agent-Teams-Check (Regel 42)
| Kriterium | Ja/Nein | Begruendung |
|-----------|---------|-------------|
| 3+ Experten lateral | ? | [Grund] |
| Cross-App | ? | [Grund] |
| Parallele Hypothesen | ? | [Grund] |
**Ergebnis:** [Kein Agent Team / Agent Team mit X Teammates]
```

**Empfohlener Modus pro Phase (T4.1, Sprint 116):**
| Phase | Modus | Wann anders? |
|-------|-------|-------------|
| A (Sprint-Start) | Sequentiell | — |
| B (Ideation) | Sequentiell/Agent Team | 3+ Hypothesen parallel → Agent Team |
| C (Planning) | Sequentiell | — |
| D (Execution) | Subagents/Agent Team | Multi-App/Multi-Experte → Agent Team |
| E (Review) | 2 Subagents parallel | Build/Lint + Testing gleichzeitig |
| F (Retro) | Sequentiell | — |
| G (Uebergabe) | Sequentiell | — |

**CC-91 Auto Mode fuer Explore-Agents:** Read-only Research → `Agent(subagent_type: "Explore", mode: "auto")`. NICHT fuer Subagents die Code schreiben.

**Marker:** `echo done > $MARKERS_DIR/a-agent-teams`

### Schritt 7: Claude Intelligence Check
**Details in `~/.claude/skills/sprint-start/intelligence.md` (per Read nachladen).**
Kurz: `claude --version` pruefen + `memory/reference-claude-intelligence.md` lesen (Dream Engine Morning befuellt).
**Marker:** `echo done > $MARKERS_DIR/a-version`

### Schritt 8: Periodische Checks (CC-100, Sprint 153 — konsolidiert auf 3 Zyklen)
**Details in `~/.claude/skills/sprint-start/checks.md` (per Read nachladen).** Enthaelt die 3 Zyklen:

| Zyklus | Modulo | Inhalt |
|--------|--------|--------|
| %1 | jeder Sprint | Retro-Rotation + Auto-Trigger-Findings + **Vercel Active CPU Quick-Check** (R42a, Sprint 226 SMI-64) |
| %3 | alle 3 Sprints | Memory Health + Quality Gate + Dream Engine Heartbeat |
| %13 | alle 13 Sprints | DevOps-Checkpoint + Meta-Review (Quartal) |

**Vercel Active CPU Quick-Check (R42a, jeder Sprint):**
1. Vercel Dashboard → Team `escholly-ship-its-projects` → Usage → Active CPU pruefen.
2. Bei <50% Auslastung: Marker setzen, weiter.
3. Bei 50-75%: Polling-Quellen pruefen (`grep -rE "setInterval|refreshInterval" ~/projects/*/src` — Frequenzen ≥300_000ms?).
4. Bei ≥75%: Sprint-Item fuer Polling-Reduktion oder Hosting-Trennung. Hobby-Tier (4h Active CPU/Monat) wird beim Erreichen von 100% ALLE Team-Projekte pausieren — Code-Stop fuer alle 11 Apps inkl. Kunden-Projekte.

**Marker `a-devops` IMMER setzen** (auch wenn nicht faellig — Semantik: "geprueft/nicht faellig").
Gemergte Zyklen (CC-100): Dream Engine (ex-%5) → in %3 als Heartbeat-Check. Meta-Review (ex-%10) → in %13 als Teil des Quartals-Reviews.

## Kontext-Tier-System (COWORK-20)

### Tier 1 — IMMER laden
`CLAUDE.md` (auto), `MEMORY.md` (auto), aktives Projekt-Memory, aktives Projekt-Backlog.

### Tier 2 — Nur wenn Sprint-Ziel es erfordert
`memory/arbeitsregeln.md` (bei Prozess-Arbeit/neuen Regeln/`/sprint-start`), aktivierte Experten-Personas, Tool-Referenzen (Design/Infografik), `memory/retros.md` (in Phase F), `memory/audit-source-code-claude-code.md` (Infra/Prozess-Sprints).

### Tier 3 — On-Demand
Cross-Project-Learnings, archivierte Backlogs, abgeschlossene Einmal-Themen.

**Regel:** Nicht pauschal alles laden. Tier 2+3 nur wenn Sprint-Ziel es verlangt.

### Schritt 9: Modell + Effort intern bestimmen (KEIN Output hier — kommt in Schritt 10)

**Grundsatz (Sprint 217 v3 — korrigiert nach Scholly-Feedback):** Modell-Empfehlung erscheint im SELBEN Block wie das Sprint-Ziel zur Abnahme (Schritt 10). NICHT vorher. Grund: Scholly entscheidet Modell-Wechsel im Moment der Sprint-Ziel-Freigabe — beides ist EINE Aktion, kein zweistufiger Vorgang.

**In diesem Schritt:** Sprint-Typ klassifizieren + Modell + Effort intern festlegen. Kein Chat-Output. Werte werden in Schritt 10 ausgegeben.

**Sprint-Typ-Matrix (Heuristik — anwenden auf Scope aus Schritt 4e):**

| Sprint-Typ | Modell | Effort | Begruendung |
|-----------|--------|--------|-------------|
| Reine Doku/Memory/Backlog/Hygiene (kein Code-Touch) | Claude Sonnet 4.6 | Medium | Strukturierte Arbeit, kein Reasoning-Tiefenbedarf |
| Hook-/Skill-/Prozess-Aenderungen (lokal, kein Production-Touch) | Claude Sonnet 4.6 | High | Code-aehnlich aber abgegrenzt |
| Bugfix bekanntes Symptom (klare Ursache) | Claude Opus 4.7 | Medium | Code-Qualitaet zaehlt, aber kein Deep-Reasoning |
| Feature-Implementation Standard (Production-Touch) | Claude Opus 4.7 | High | Bauen + testen + verifizieren |
| Feature komplex / Architektur / Refactoring | Claude Opus 4.7 (1M) | xhigh | Mehrere Files, Trade-offs, Cross-Cutting |
| Deep Research / Security-Review / Forensik | Claude Opus 4.7 (1M) | xhigh | Tiefenanalyse mit vielen Quellen |
| Content/Ghostwriting/Infografik-Sprints | Claude Opus 4.7 | High | Qualitaet kritisch, Reasoning fuer Hook+Stoppregeln |
| Stuck nach 2 Versuchen (Wiederholungs-Sprint) | Claude Opus 4.7 (1M) | Max | Explizite Scholly-Freigabe noetig |

**Wichtig:**
- Das gewaehlte Modell laeuft fuer ALLE Phasen B-G durch. Kein zusaetzlicher Wechsel-Reminder in `sprint-review` / `sprint-retro` (entfernt in Sprint 217).
- `ultrathink`-Mechanismus loest einzelne schwierige Sub-Tasks one-off, ohne Modell-Wechsel.
- Phase E komplexes Debugging → `/ultrareview` aufrufen, kein Modell-Wechsel.

**LaunchAgents vs. Sprint:** Seit Sprint 217 modell-routed (CONTENT→Opus, ADMIN→Sonnet/Haiku). Unabhaengig von Sprint-Modell-Wahl.

### Schritt 10: Sprint-Ziel zur Abnahme + Modell-Wechsel-Empfehlung (Kunden-Vertrag) — PFLICHT als LETZTER Block Phase A

**Zweck (CC-177, Sprint 173 + Sprint 217 Korrektur):** Scholly sieht als allerletzten Block — direkt vor PAUSE — das Sprint-Ziel eindeutig zur Abnahme + die Modell+Effort-Empfehlung im SELBEN Block. Beides ist EINE Aktion: Ziel freigeben + Modell umstellen, dann Go.

**Output-Format (PFLICHT):**
```
### 🎯 Sprint-Ziel zur Abnahme

**Was am Ende des Sprints geliefert ist:**
[Ein einziger, klarer Satz — das Sprint-Ziel als Kunden-Vertrag]

**Abnahme-Kriterien (messbar):**
1. [Konkret nachweisbar — z.B. "Hook-Test laeuft ohne False-Positive-Block durch Phase-Gate"]
2. [Konkret nachweisbar — z.B. "memory-health.sh meldet Tier-1 < 2700 Zeilen"]
3. [Konkret nachweisbar — pro Deliverable ein Kriterium]

**Wie du es abnimmst:**
[1-2 Saetze: Wo/Wie Scholly das Ergebnis in Phase E sehen wird — Live-URL, Script-Output, Skill-Ausgabe, Screenshot, etc.]

---

### 🤖 Modell + Effort fuer diesen Sprint

**Sprint-Typ:** [Klassifikation aus Schritt 9, z.B. "Feature komplex / Architektur"]
**Aktuell aktiv:** [Modell + Effort das laut System-Frontmatter laeuft, z.B. "Claude Opus 4.7 (1M) Medium"]
**Empfehlung:** [Modell + Effort aus Schritt-9-Matrix, z.B. "Claude Opus 4.7 (1M) xhigh"]
**Begruendung:** [1-2 Saetze warum genau diese Kombination fuer diesen Sprint-Typ]

**Wechsel noetig?** [Ja / Nein — falls aktuell == empfohlen, dann "Nein, bereits korrekt"]

---

**Bestaetigung (3-Schritt):**
1. Sprint-Ziel: Annahme oder Nachjustieren?
2. Modell-Wechsel: Erledigt? (oder Empfehlung uebersteuern)
3. Sag "Go" → ich starte Phase B autonom
```

**Logik fuer "Aktuell aktiv":** Aus dem System-Prompt-Frontmatter ablesen ("You are powered by the model named ..."). Falls nicht eindeutig erkennbar, einfach schreiben "(bitte oben rechts in Desktop-App pruefen)".

**Logik fuer "Wechsel noetig?":** Wenn aktuelles Modell == empfohlenes Modell UND aktueller Effort == empfohlener Effort → "Nein, bereits korrekt". Sonst Ja.

**Telegram-Push (AUTO-10, Sprint 176):** Nach Anzeige des Sprint-Ziel-Blocks SOFORT Push senden:
```bash
bash ~/Cowork/scripts/notify-scholly.sh sprint-goal "Sprint $(cat ~/Cowork/.sprint-global) — Ziel bestaetigen (<Projekt>, <N> Items)"
```
So sieht Scholly auf Apple Watch dass Sprint-Start warten auf seine Abnahme.

**Regeln:**
- **Ziel-Satz** muss sich aus Scope-Tabelle + Deliverables ableiten (keine neuen Inhalte).
- **Abnahme-Kriterien** = 1 Kriterium pro Deliverable. Je Kriterium messbar (Zahl, Datei, Sichtbarkeit in einer bestimmten Ansicht).
- **"Wie du es abnimmst"** = konkreter Abnahme-Kanal, damit Scholly in Phase E nicht raten muss, wo geprueft wird.
- Dieser Block ist KEINE Wiederholung der Scope-Tabelle — er verdichtet sie zur Vertrags-Form.

## WEITER — Autonome Arbeit beginnt (Regel 22) — STRIKT AUTONOM

Phase A endet hier. Sprint-Ziel ist der Vertrag — Scholly hat bestaetigt.

**ERSTE AKTION nach Scholly-Go (CC-181, Sprint 181):** SOFORT Edit-Tool auf `$PHASES_FILE` aufrufen und `A=` durch `A=done` ersetzen. Damit sind Phase-A-Marker (a-*) UND State-File synchron — phase-gate.sh akzeptiert ab jetzt `B=done`/`C=done`/`D=in_progress`-Writes. Ohne diesen Edit bleibt Phase A im State-File offen, obwohl alle Marker gesetzt sind.
```
Edit($PHASES_FILE, old_string="A=", new_string="A=done")
```
Erst DANACH Phase B beginnen.

**ZWEITE AKTION — Upstream-Sprint-Goal in Supabase schreiben (SMI-49, Sprint 218):** Nach dem State-File-Edit AUTOMATISCH das aktuelle Sprint-Ziel (Kurzform aus Scope-Tabelle) in `roadmap_config` patchen, damit das schollmayer.info Hero-Widget es live anzeigen kann. phase-gate.sh triggert beim State-File-Edit den `current_phase`-Write; der Sprint-Goal-Text wird HIER explizit gesetzt:

```bash
TOKEN=$(cat ~/.roadmap-api-token)
curl -sS -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"current_sprint_goal":"<1-Zeilen-Zusammenfassung der Deliverables>"}' \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/config
```

Verifikation via `curl -s -H "Authorization: Bearer $TOKEN" .../api/verify | jq .currentSprintGoal`. Falls API nicht erreichbar: Skip + ein Hinweis-Satz, aber nicht blockieren.

**STRIKTE AUTONOMIE-REGEL (CC-94, Opus 4.7 literales Instruction-Following):**

Zwischen dieser Zeile und Phase E Schritt 6 (Kunden-Abnahme): **GENAU NULL** narrative Posts. Keine Ausnahmen.

**VERBOTEN:** "Phase X abgeschlossen", "Hier ist mein Plan", "Möchtest du A/B/C?", "Ich starte jetzt mit...", "Zwischenstand:", jede Status-Block-Narration ohne Scholly-Trigger, jede Rueckfrage die kein echter Blocker ist.

**ERLAUBT:** Tool-Calls, TodoWrite-Updates (UI, kein Chat-Spam), stille Ausfuehrung bis Phase E Schritt 6.

**AUSNAHME — echter Blocker (Regel 22):** Nur wenn NUR Scholly loesen kann (Credential, kostentreibende Scope-Entscheidung, Hardware). Dann 1 Satz + 1 Frage. Kein Kontext-Narrativ.

**Auto Mode (Sprint 150):** `settings.json` hat `"defaultMode": "auto"` — Permission-Prompts entfallen bei lokalen Ops. Gefaehrliche Aktionen (Push main, Production Deploy, rm -rf) bleiben blockiert.

**Recaps (v2.1.108+):** `ENABLE_AWAY_SUMMARY=1` aktiv. Bei Resume: automatischer Recap. Manuell: `/recap`.

### Phasen B+C (PFLICHT — CC-70, Sprint 147 / Anti-Silent-Pause haertung CC-382, Sprint 246)

Phase B (Planning) und C (Konzept) sind PFLICHT fuer JEDEN Sprint. **STRIKTE TOOL-CALL-PFLICHT** — Plan-Text alleine ist NICHT ausreichend, sonst ist die Phase silent uebersprungen (Sprint-246-Incident).

- **Phase B:** Konkreter Plan — Dateien, Reihenfolge, Risiken. Plan im Chat als Tool-Call-Output (TodoWrite ODER Edit/Write auf einer Plan-Datei) — NICHT nur als Text-Output. Direkt am Ende dieses SELBEN Turns:
  ```bash
  echo done > $MARKERS_DIR/b-ideation
  ```
  UND State-File patchen:
  ```
  Edit($PHASES_FILE, old_string="B=", new_string="B=done")
  ```
  Beides MUSS im selben Turn passieren wie der Plan, sonst ist Phase B silent gefailt.

- **Phase C:** Konzept/Design passend zum Sprint-Typ. **STRIKTE TOOL-CALL-PFLICHT** — gleiches Pattern wie Phase B.
  - Frontend → Claude Design (HTML-Export) Screen-Design
  - Backend → Architektur-Flow, Datenfluss-Diagramm
  - Prozess → Ablauf-Beschreibung, Sequenz-Diagramm
  - Infrastruktur → System-Diagramm, Integrations-Flow
  - Allgemein → mindestens textuelle Konzept-Beschreibung als Tool-Call (Write auf `~/Cowork/.sprint-konzept-<sprint>.md`)
  Direkt am Turn-Ende:
  ```bash
  echo done > $MARKERS_DIR/c-planning
  ```
  UND `Edit($PHASES_FILE, old_string="C=", new_string="C=done")`.

- **Skip NUR mit expliziter Scholly-Genehmigung** ("B und C koennen wir skippen")
- Visuelle Arbeit? → Phase C mit `/design-gate` PFLICHT.

**ANTI-SILENT-PAUSE-REGEL (CC-382, Sprint 246, korrigiert nach Scholly-Klarstellung):**

Nach jedem `<phase>=done` darf der naechste Turn **NICHT** mit reinem Text enden. **PFLICHT-SEQUENZ pro Phasen-Uebergang** (Cloud-Migration-tauglich, Skill enforced ohne Hook-Abhaengigkeit):

**Standard-Schritte (jede Phase):**
1. Plan/Konzept/Output als Tool-Call dokumentieren (TodoWrite/Write/Edit)
2. Marker-Bash `echo done > $MARKERS_DIR/<phase>-...`
3. State-File-Edit `Edit($PHASES_FILE, ...)` auf `<aktuelle_phase>=done`
4. Self-Validation: `bash ~/.claude/skills/sprint-start/validate-phase.sh <PHASE>` — gibt exit 1 wenn Pflicht-Schritte fehlen, Claude muss nachbessern
5. Direkt anschliessend nächster Phase-Tool-Call ODER Skill-Aufruf

**Telegram-Pushes — NUR an 3 Stellen pro Sprint** (Scholly-Klarstellung Sprint 246):

| Push-Punkt | Phase | Ziel |
|-----------|-------|------|
| Sprint-Goal | A → B | Scholly bestaetigt Sprint-Ziel + Modell-Wechsel |
| Kunden-Abnahme | E → F | Scholly nimmt Lieferung ab oder fordert Korrektur |
| Sprint-End | G → neue Session | Zusammenfassung + neue Session OK |

**Phasen B, C, D, F sind silent** — keine Telegram-Pushes. Skill-Chain laeuft autonom durch.

**Telegram-Message-Pflicht-Format:**
- **A:** "Sprint X — Ziel zur Bestaetigung: [1-Satz-Ziel] | <Anzahl> Items, <Effort>P. ANTWORTE: 'go' bei OK oder 'anpassen: ...'"
- **E:** "Sprint X — Abnahme: Lieferung in [Channel] verifizieren. ANTWORTE: 'OK' bei Abnahme oder 'Korrektur: ...'"
- **G:** "Sprint X fertig. Geliefert: [3-Bullet-Zusammenfassung]. Neue Session kann starten."

**AD-HOC-WARTEPUNKT-PFLICHT (CC-382, Sprint 247):**

ZUSAETZLICH zu den 3 geplanten Pushes T1/T2/T3 gibt es **ad-hoc Wartepunkte**, die jederzeit auftreten koennen — typisch in Phase A (Audit-Findings), aber auch in B/C/D wenn sich ein Item-Scope als unklar herausstellt:

- **Phase-A Audit-Finding** (z.B. heute: BetterStack/Substack-Verwechslung, CC-326-Effort-Frage, A11y-Splittung) → **bevor du wartest** PFLICHT-Tool-Call:
  ```bash
  bash ~/Cowork/scripts/notify-scholly.sh audit-finding "Sprint $(cat ~/Cowork/.sprint-global) — Audit: [1-2 Saetze was geprueft werden muss]"
  ```
- **Phase B/C/D Klaerung** (Item-Scope unklar, Architektur-Entscheidung) → PFLICHT-Tool-Call:
  ```bash
  bash ~/Cowork/scripts/notify-scholly.sh phase-wait "Sprint X Phase Y — brauche Entscheidung: [1 Satz worum es geht]"
  ```
- **Cloud-Mode (kein Bash):** Statt notify-scholly.sh wird der HTTP-Endpoint aufgerufen:
  ```
  POST https://roadmap-escholly-ship-its-projects.vercel.app/api/notify-scholly
  Authorization: Bearer <API_TOKEN>
  Body: {"type":"audit-finding"|"phase-wait","message":"...","sprint":<n>}
  ```
- **REGEL OHNE AUSNAHME:** Vor JEDEM "ich warte auf dich"-Moment im Chat MUSS ein Telegram-Push raus. Stille Pause = Skill-Verstoss. Heute wurde das verletzt (Sprint 247 Phase A) → strukturelle Haertung ist CC-382.

**KONKRETE PHASEN-TRANSITIONS (Cheatsheet):**

| Von Phase | Pflicht-Tool-Calls am Ende | Naechster Schritt |
|-----------|----------------------------|-------------------|
| A done | a-* marker + State-File A=done + `phase-transition-notify A "..."` + validate-phase A | Phase B Plan via TodoWrite |
| B done | b-ideation marker + State-File B=done + validate-phase B (kein Push) | Phase C Write Konzept |
| C done | c-planning marker + State-File C=done + validate-phase C (kein Push) | Phase D Code-Tool-Calls |
| D done | d-execution marker + State-File D=done + validate-phase D (kein Push) | **`/sprint-review` Skill aufrufen** |
| E done | e-* marker + Kunden-Abnahme-Push + validate-phase E | **`/sprint-retro` Skill aufrufen** |
| F done | f-* marker + State-File F=done + validate-phase F (kein Push) | Phase G via gleichem Skill |
| G done | g-* marker + Sprint-End-Push + validate-phase G | Sprint fertig, neue Session |

**MERKE:** Phase-Uebergang = mind. 4 Tool-Calls (Doku-Tool + Marker + State-Edit + Validate). Nur A/E/G zusaetzlich Telegram. Nach D MUSS `/sprint-review` aufgerufen werden, nach E `/sprint-retro`. Skill-Chain ist DETERMINISTISCH — keine Pause, keine Frage.

### Phasen-Entscheidung
- Phase B+C durchlaufen → Phase D. Marker am Ende: `echo done > $MARKERS_DIR/d-execution`
- Ergebnis fertig → Phase E (`/sprint-review`).
