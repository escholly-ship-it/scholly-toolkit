---
name: sprint-retro
description: Sprint-Zeremonie Phase F+G — Retro reflektieren, Experten-Personas aktualisieren, Backlog aktualisieren, Entscheidungen persistieren
---

<!-- Modell-Switch-Signal entfernt (Sprint 217 Korrektur):
     Mid-Sprint-Wechsel widerspricht Schollys Workflow ("nur 1 Modell-Wahl
     beim Sprint-Start, ab da autonom"). Retro laeuft im am Sprint-Start
     gewaehlten Modell durch. -->

## Cloud-Mode (Sprint 257, CC-CLOUD-MIGRATION)

Cloud-Sessions nutzen `cloud-mode-skill-patterns.md`:
- Phase-State-Marker (`skill-retro-invoked`, `g-*`, `f-*`) via `PATCH /api/phase-state`
- Memory-Updates via `POST /api/hook-relay {type: "git-commit", repo: "escholly-ship-it/claude-config", files: [...]}`
- Cowork-Memory via `POST /api/hook-relay {type: "git-commit", repo: "escholly-ship-it/cowork", files: [...]}`
- Telegram-Push am Sprint-Ende via `POST /api/notify-scholly {type: "sprint-end"}`
- Sprint-Counter-Inkrement bleibt zentral via `POST /api/sync` (existiert seit Sprint 138)

Lokale Bash-Schritte bleiben Default. Detection beim ersten Bash-Block-Versuch.

---

## ⚠️ FREIHAND-VERBOT (Regel 95, Sprint 176 Incident — CC-185)

Phase F und Phase G laufen **AUSSCHLIESSLICH** via diesen Skill. Bash-Freihand ist verboten, auch in Auto Mode.

**Verboten:**
- `echo done > $MARKERS_DIR/g-counter`, `g-backup`, `g-notion`, `g-backlog`, `g-e2e-verified` ohne dass der Skill vorher via Skill-Tool geladen wurde
- Manuelles Inkrementieren von `~/Cowork/.sprint-global`
- Manuelles Aufrufen von `verify-sprint-end.sh` als Ersatz fuer Phase G
- `G=done` in `.sprint-phases` schreiben ohne `skill-retro-invoked`-Marker (blockiert seit CC-185 durch phase-gate.sh)

**Warum:** Sprint 176 hatte einen Counter-Double-Increment weil Phase G per Freihand lief. Der Skill hat die Schutz-Logik (Sync vor Counter, Notion-Sync, Backlog-Write, GitHub-Backup in strikter Reihenfolge) — Freihand umgeht das.

**Korrekt:** Scholly sagt "Uebergabe" / "mach schluss" / "abschluss" / "wir hoeren auf" → SOFORT `Skill(sprint-retro)` invoken. Nie `echo done > ...g-*` direkt.

---

## Schritt 0: Skill-Invocation-Marker (Regel 95, Sprint 176)

**PFLICHT — als erstes in diesem Skill:** Marker setzen, damit phase-gate.sh weiss dass der Skill wirklich aufgerufen wurde (nicht nur Bash-Freihand). Ohne diesen Marker blockiert Phase-Gate bei F=done.

```bash
SPRINT_TAG=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null | tr -d '[:space:]')
MARKERS_DIR="$HOME/Cowork/.phase-markers/$SPRINT_TAG"
PHASES_FILE="$HOME/Cowork/.sprint-phases-$SPRINT_TAG"
SESSION_ID="$SPRINT_TAG"
mkdir -p "$MARKERS_DIR"
# CC-247 (Sprint 212): Auto-Migrate wenn Mid-Session Tag-Rotation passierte.
source ~/.claude/hooks/lib/auto-migrate-tag.sh && auto_migrate_tag_if_needed
echo "invoked at $(date +%s) via Skill-Tool" > "$MARKERS_DIR/skill-retro-invoked"
# CC-325 (Sprint 234): TTL-Refresh aller Phase-Marker — verhindert Stretch-Sprint-Block (>6h)
find "$MARKERS_DIR" -type f -name "[abcdef]-*" -exec touch {} + 2>/dev/null || true
```

## API-Auth (CC-54, Sprint 139)
**Alle Roadmap-API-Aufrufe brauchen den Bearer Token:**
```bash
ROADMAP_TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null)
```
Danach bei jedem curl: `-H "Authorization: Bearer $ROADMAP_TOKEN"`

# Phase F — Retro (Rueckblick)

**SMI-49 Phase-Auto-Write (Sprint 219):** SOFORT am Start von Phase F:
```sql
UPDATE roadmap_config SET current_phase='F', current_sprint_meta_updated_at=NOW() WHERE key='global_sprint';
```
Via Supabase MCP. Danach Empty-Commit + Push im schollmayer-info Repo fuer Redeploy. Phase G analog unten am Anfang von Phase G auf `current_phase='G'`.

**ZWINGENDE REIHENFOLGE — kein Schritt darf uebersprungen oder umgestellt werden.**

## F.1: Experten-Personas aktualisieren (VOR retros.md!)

**Delta-Append-Pattern (CC-211, Sprint 192) — Pflicht-Ablauf:**

Traditionell wurde jede Persona-Datei voll gelesen, Lernzyklus gegen Gesamtinhalt laufen, dann Multi-Edit. Neuer Ablauf nutzt die **Phase-D-TodoWrite-Notes als Primaerquelle** und haengt den neuen Sprint-Block per Single-Edit **ohne Full-Read** an:

1. **Aus Phase D liegen vor:** Konkrete Erkenntnisse pro Experte in der TodoWrite-Liste + dieser Retro-Session (Scope + Deliverables + Findings).
2. **Persona-Delta-Block schreiben** (nicht aus der Datei zurueckuebersetzen):
   ```
   ### Sprint {N} — {1-Satz-Titel}
   **Was neu:** [2-3 Saetze]
   **Verlernt/Ersetzt:** [wenn anwendbar: `~~DEPRECATED (Sprint {N}): ...~~`]
   **Cross-Projekt:** [wenn anwendbar]
   ```
3. **Single-Edit (kein Full-Read):** Finde den ersten existierenden `### Sprint ` Header in `experte-*.md` (via Grep `-n "^### Sprint " experte-<name>.md | head -1`), prepende den neuen Block davor. ODER: Falls die Persona eine `## Lessons` Sektion hat, appende als erstes Item darunter.
4. **Verlernen-Check (Regel 51):** Wurde bestehendes Wissen WIDERLEGT/ERSETZT? → Grep nach dem konkreten Begriff in der Persona, Edit-Tool zum Markieren mit `~~DEPRECATED (Sprint {N}): [Grund]~~`. Kein Full-Read noetig.
5. **Pruning-Scan (Regel 51):** `wc -l experte-*.md` — >400 Zeilen? → Aelteste `### Sprint X` Bloecke (>20 Sprints zurueck) per Grep-Line-Range identifizieren und in `archive/experte-<name>-archiv.md` verschieben.
6. **Batch-Modus bei ≥3 aktivierten Experten:** Sammel alle Delta-Bloecke + alle DEPRECATED-Marks in einem Tool-Call-Block — parallele Edit-Calls moeglich weil sie unterschiedliche Dateien treffen.
7. Skill-Progression + `next_research_due` pruefen (aus Frontmatter via Grep).
8. Neue Rollen noetig? → `memory/experten-team-framework.md` Kapitel 5.

**Lernzyklus (Regel 25):** Identifizieren (aus Phase D) → Abgleichen (Grep statt Read) → Aktualisieren (Delta-Append + DEPRECATED-Mark) → Vernetzen (in Retro-Block dokumentiert).

**Wenn KEINE Experten aktiv waren:**
```bash
echo 'Keine Experten in Sprint [Nr]' > ~/.claude/hooks/.skip-regel25
```

**DIESEN SCHRITT NIEMALS UEBERSPRINGEN. Er muss VOR F.2 abgeschlossen sein.**
**Marker:** `mkdir -p ~/Cowork/.phase-markers && echo done > ~/Cowork/.phase-markers/f-experten`

## F.2: Memory Quality Delta-Check (Regel 51, Sprint 78)
**PFLICHT — nach Experten-Update, vor Retro-Reflexion.**

**CC-211 Optimierung (Sprint 192):** Phase A hat den Composite-Score in `~/Cowork/.quality-baseline` geschrieben. Wenn in dieser Session KEINE Persona- oder Regel-Dateien veraendert wurden (Grep `git diff --stat` gegen Cowork + .claude), kann der zweite `memory-health.sh` Lauf entfallen — Delta ist 0. Nur bei tatsaechlicher Aenderung den vollen Re-Lauf.

1. `bash memory/memory-health.sh` erneut ausfuehren (Metrik 10) — **skip wenn keine Memory-Diffs**
2. Composite Score mit Phase-A-Baseline vergleichen (aus `~/Cowork/.quality-baseline`)
3. **Ergebnis im Chat dokumentieren:**
   ```
   ### Quality Delta (Sprint X)
   Phase A: [X]% → Phase F: [Y]% (Delta: [+/-Z])
   ROT: [N] | GELB: [N]
   ```
4. **Actions bei Verschlechterung:**
   - Delta > -5 → "⚠️ Qualitaet verschlechtert — GELB-Assets JETZT verdichten"
   - Composite < 75% → Backlog-Item: "Naechster Sprint = Verdichtungs-Sprint"
   - Composite < 55% → STOPP Feature-Arbeit bis Qualitaet wiederhergestellt
5. **GELB-Assets aus Phase A:** Jetzt verdichten (Sprint-Refs entfernen, Narrative → Patterns)
6. Baseline wird automatisch vom Health-Check aktualisiert.
**Marker:** `echo done > ~/Cowork/.phase-markers/f-quality`

## F.3: Retro reflektieren und in retros.md persistieren

Reflektiere ehrlich:
- **Was lief gut?** — Methoden/Entscheidungen die wir beibehalten sollen
- **Was lief schlecht?** — Fehler, falsche Annahmen, Zeitfresser
- **Was aendern wir?** — Konkrete Massnahmen: neue Arbeitsregel, Prozess-Anpassung, Backlog-Item

**Pflicht-Frage (Regel 99, Sprint 189 Kunden-Abnahme-Incident):**
- **Habe ich in diesem Sprint Arbeit an Scholly delegiert, die eigentlich digital loesbar war?**
  - Scan des Phase-E-Abnahme-Blocks + aller Ausgaben der Session auf Patterns `Scholly.Action|Scholly.Klick|Scholly.muss|Dashboard-Klick|Scholly.Follow.?Up|manuell.von.Scholly`
  - JA → Root Cause dokumentieren (welche Regel umgangen? Hook-Block fehlinterpretiert? Persona-Dogma ungefragt uebernommen?) + Praeventions-Massnahme in retros.md
  - NEIN → explizit festhalten ("Regel-99-Scan clean")
  - Trainiert den Reflex, semantische Umetikettierung ("Scholly-Action" statt "kann nicht") zu erkennen.

Regeln:
- Erkenntnisse werden SOFORT umgesetzt: Neue Regel → `memory/arbeitsregeln.md`, neues Item → Backlog
- Nicht nur "war gut/schlecht" — immer eine Aktion ableiten
- **PFLICHT:** Retro in `memory/retros.md` persistieren — Session-Nr, Datum, Erkenntnisse + abgeleitete Aktionen

**Marker:** `echo done > ~/Cowork/.phase-markers/f-retro`

---

# Phase G — Uebergabe (letzter Schritt)

**SMI-49 Phase-Auto-Write (Sprint 219):** SOFORT am Start von Phase G:
```sql
UPDATE roadmap_config SET current_phase='G', current_sprint_meta_updated_at=NOW() WHERE key='global_sprint';
```
Via Supabase MCP. Empty-Commit + Push im schollmayer-info Repo. Der bestehende Phase-G-Step-6 Reset-Block setzt die Phase spaeter wieder auf 'A' (naechster Sprint).

**G.1 bis G.8, linear. Counter-Hoheit liegt bei der API — lokale Datei ist Mirror (Sprint 145, konsolidiert Sprint 151 CC-104).**

## G.1: Sprint-Phase-State F=done setzen

## G.1b: Sprint-Kapazitaet auto-kalibrieren VOR /api/sync (CC-264-EXT, Sprint 217)

**Reihenfolge-kritisch:** MUSS vor G.2 (/api/sync → auto-pack) laufen.  
Sonst packt der Auto-Pack mit dem ALTEN capacity_target; der neue Wert greift erst im uebernaechsten Sprint.

**Zweck:** `capacity_target` passt sich nach JEDEM Sprint-Ende an die tatsaechlich gelieferte Effort-Summe der letzten 5 abgeschlossenen Sprints an (Moving-Average). Pack-Algo (`src/lib/pack.ts`) nutzt diesen Target sofort fuer den naechstgepackten Sprint.

```bash
python3 ~/Cowork/scripts/capacity-analysis.py --auto-sprint-end
```

- **Window = 5 Sprints** (Fenster fuer Moving-Avg)
- **Alert-Delta = 2P** (bei Delta >= 2P zwischen altem und neuem Target → Telegram-Push via `notify-scholly.sh drift`)
- Script schreibt lokal `~/Cowork/.sprint-capacity-target` und synct nach Supabase `roadmap_config.capacity_target`
- Retros.md ist zum Zeitpunkt dieses Aufrufs bereits mit dem frisch abgeschlossenen Sprint befuellt (F.3)

**Ohne diesen Schritt** veraltet der Pack-Algo-Richtwert — Sprints werden gegen einen stalen Durchschnitt geplant.


Nutze das **Edit-Tool** um in `~/Cowork/.sprint-phases` die Zeile `F=` auf `F=done` zu aendern.
**KEIN Bash/sed** — das loest eine Berechtigungsabfrage aus weil `~/.claude/` geschuetzt ist.

## G.2: Roadmap-Sync + Counter (Regel 87, 90 — API ist Single Source of Truth)

**⚠️ VORAUSSETZUNG (Regel 90): Sync darf NUR laufen wenn ein ECHTER Sprint stattfand.**
Pruefe: Wurde `/sprint-start` in dieser Session aufgerufen?
- **JA** (Marker `a-arbeitsregeln` gesetzt, `.sprint-phases` zeigt echten Sprint): → Sync ausfuehren.
- **NEIN** (Ad-hoc-Session, Quick Fix, Research ohne `/sprint-start`): → **G.2 komplett UEBERSPRINGEN.** Im Chat: "Kein formaler Sprint — kein Sync, Counter bleibt bei [N]."

**Architektur-Regel (Sprint 145):** Der Sprint-Counter wird AUSSCHLIESSLICH von `/api/sync` inkrementiert.
Die lokale Datei `~/.sprint-global` ist ein Mirror — sie wird NACH dem API-Call aus dem Response aktualisiert.
**NIEMALS den Counter lokal hochzaehlen BEVOR der Sync-Call laeuft.** Das erzeugt Double-Increment.

**Schritt-fuer-Schritt:**

1. **Lokalen Counter lesen (NOCH NICHT inkrementieren!):**
   ```bash
   CURRENT=$(cat ~/Cowork/.sprint-global)
   ```
   Dieser Wert ist der Sprint der gerade ENDET (z.B. 145).

2. **Sync-Call ausfuehren** (CC-313 Sprint 247 Cutover-aktiviert: Edge sync+pack auf Supabase, notion-sync delegiert weiterhin an Vercel):
   ```bash
   RESULT=$(curl -s -X POST -H "Authorization: Bearer $ROADMAP_TOKEN" \
     https://xeygrtucelnlpliqhnub.supabase.co/functions/v1/sync \
     -H "Content-Type: application/json" \
     -d '{
       "current_sprint": '$CURRENT',
       "done_ids": ["BACKLOG-ID-1", "BACKLOG-ID-2"],
       "new_items": [],
       "failed_sprint": null
     }')
   # Fallback bei Edge-Ausfall:
   # https://roadmap-escholly-ship-its-projects.vercel.app/api/sync
   echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d,indent=2))"
   ```
   **Was der Sync-Call macht (atomar, in der API):**
   - Erledigte Items → `status=done`, `archived=true`, `notizen="Erledigt Sprint X"`
   - Nicht-erledigte Items → zurueck ins Backlog (`sprint_nummer=null`)
   - Gescheiterter Sprint → Item in naechsten Sprint, Notizen "GESCHEITERT"
   - Neue Items → ins Backlog eintragen
   - **Counter inkrementieren** (in `roadmap_config`, einziger Schreiber)
   - Auto-Pack auf 5 Sprints

3. **Neuen Counter aus API-Response lesen und lokal spiegeln:**
   ```bash
   NEW_COUNTER=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['newCounter'])")
   ```
   Dann mit **Write-Tool** `~/Cowork/.sprint-global` auf den neuen Wert setzen.

4. **Verify (Regel 87):**
   ```bash
   cat ~/Cowork/.sprint-global
   ```
   Ergebnis MUSS `$NEW_COUNTER` sein (z.B. 146).
   Im Chat bestaetigen: "Counter: [CURRENT] → [NEW_COUNTER] (API=SSOT, lokal gespiegelt)"

5. **Review-Trigger pruefen:** Wenn NEW_COUNTER durch 10 teilbar → "Ebene-2-Review faellig". Wenn durch 25 → "Ebene-3-Audit faellig".

6. **Upstream-Phase-Reset fuer neuen Sprint (SMI-49, Sprint 218):** Nach Counter-Inkrement wird `roadmap_config.current_phase` auf `'A'` und `current_sprint_goal` auf `NULL` gesetzt. Ohne diesen Reset haengt das schollmayer.info Hero-Widget auf der Phase des ALTEN Sprints (Bug seit Sprint 216 Phase G bis 2026-04-24 gefixt):
   ```bash
   curl -sS -X PATCH \
     -H "Authorization: Bearer $ROADMAP_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"current_phase":"A","current_sprint_goal":null}' \
     https://roadmap-escholly-ship-its-projects.vercel.app/api/config
   ```
   Das naechste `/sprint-start` Schritt 10 setzt `current_sprint_goal` beim Scholly-Go auf den neuen Sprint-Ziel-Text. Verifikation: `curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" .../api/verify | jq '.currentPhase,.currentSprintGoal'` → `"A"`, `null`.

**De-Scoping-Check (Regel 80):** Teilweise erledigte Items → Folge-Item via `/api/items` POST anlegen, Sprint zuweisen.
**Markdown-Backlogs aktualisieren:** Erledigte Items in den jeweiligen `backlog-*.md` als `~~erledigt~~` markieren.

### Notion-Dokumentation (ex G.3, jetzt Teil von G.2)

**Notion wird automatisch vom Sync-Call aktualisiert** (der Endpoint ruft `/api/notion-sync` intern auf).
Im Chat pruefen ob der Sync-Response `NOTION:` enthaelt → bestaetigen.

Falls Notion-Sync fehlgeschlagen oder unvollstaendig:
1. Projektseite manuell fetchen (ID aus MEMORY.md) + pruefen
2. Hub-Seite pruefen (`31fd7cf9-fb32-81fb-a900-fb2bc0407e20`)

**Marker:** `echo done > ~/Cowork/.phase-markers/g-notion`

## G.3: Sprint-Ende-Audit (Regel 89 — STOPP-Pflicht)
**3 Fragen systematisch pruefen — Sprint darf NICHT enden ohne explizite Antworten im Chat.**

1. **Findings:** Wurden Probleme, Bugs, Prozess-Luecken entdeckt die KEIN Backlog-Item haben?
   → Fuer JEDES Finding: Backlog-Item anlegen (Titel + Herkunft + Prio + Horizont)
2. **Unerledigte Items:** Gibt es Teile der Sprint-Items die nicht fertig wurden?
   → De-Scoping-Items anlegen (Regel 80): Neues Item + Sprint zuweisen + Original-Notizen
3. **Neue Ideen:** Wurden Features, Technologien oder Verbesserungen erkannt die in zukuenftige Sprints gehoeren?
   → Items anlegen + via POST `/api/items` im Roadmap-Tool + Sprint zuweisen

**Sichtbare Tabelle im Chat PFLICHT:**
```
### Sprint-Ende-Audit (Regel 89)
| Kategorie | Anzahl | Items |
|-----------|--------|-------|
| Neue Findings → Backlog | X | [IDs] |
| Unerledigte → De-Scoped | X | [IDs] |
| Neue Ideen → Geplant | X | [IDs] |
```
**Marker:** `echo done > ~/Cowork/.phase-markers/g-findings`
**Ohne diesen Marker blockiert Phase G.** Auch wenn alle 3 Kategorien "0" sind — Tabelle trotzdem ausgeben.

## G.4: Backlog qualitativ aktualisieren + Hygiene-Verify (Regel 47 + 88 — NACH Kunden-Abnahme + Retro + Audit)

Das Backlog wird JETZT aktualisiert — nachdem der Kunde sein Feedback gegeben hat (Phase E), die Retro gelaufen ist (Phase F) UND der Sprint-Ende-Audit abgeschlossen ist (G.3). So fliesst ALLES ein.

- Erledigte Items RAUS (verifizieren ob wirklich erledigt!)
- Neue Items aus Kunden-Feedback eintragen (Kritik, Aenderungswuensche, Ideen)
- Neue Items aus Retro-Erkenntnissen eintragen (technische Schulden, Prozess-Verbesserungen)
- Neue Items aus Sprint-Ende-Audit eintragen (Findings, De-Scoped, neue Ideen)
- Prio-Reihenfolge pruefen — nicht einfach unten anhaengen
- Backlog muss so formuliert sein, dass die naechste Session damit direkt starten kann

### Roadmap-Tool Sync pruefen
**Sync wurde bereits in G.2 durchgefuehrt.** Hier nur pruefen:
1. Alle neuen Items aus G.4 (Kunden-Feedback, Retro-Erkenntnisse) auch via POST `/api/items` im Roadmap-Tool?
2. Wenn NEIN → Fehlende Items jetzt via POST eintragen.

### Markdown-Backlog-Sync-Check (Regel 66, Sprint 186 CC-198) — STOPP-Pflicht

**Regel 66 sagt: Markdown-Backlogs sind Detail-Wahrheit (WIE). Muessen mit Roadmap-Tool konsistent sein.**

**Problem (Sprint 182 Finding):** `backlog-claude-code.md` enthielt CC-185/186/187/195 nicht, obwohl sie in Supabase im Sprint 182 waren. Roadmap-Sync ersetzt MD-Sync NICHT.

**Check-Script (pro Projekt, das Items im gerade abgeschlossenen Sprint hatte):**
```bash
# Projekt-Mapping: Roadmap "projekt"-Feld -> Markdown-Backlog-Datei
python3 << 'PYEOF'
import json, subprocess, os, re
token = open(os.path.expanduser('~/.roadmap-api-token')).read().strip()
base = 'https://roadmap-escholly-ship-its-projects.vercel.app'
items = subprocess.run(['curl','-s','-H',f'Authorization: Bearer {token}',f'{base}/api/items'], capture_output=True, text=True).stdout
items = json.loads(items)

# Projekt -> MD-Backlog-Datei Mapping
MAPPING = {
    'Claude Code': 'backlog-claude-code.md',
    'Automatisierung': 'backlog-automatisierung.md',
    'Ghostwriting': 'backlog-ghostwriting.md',
    'Papierkram': 'backlog-papierkram.md',
    'Dream Engine': 'backlog-dream-engine.md',
    'Cookmark': 'backlog-cookmark.md',
    'Watchlist': 'backlog-watchlist.md',
    'KiHire': 'backlog-talentagent.md',
    'PhysioGPT': 'backlog-physiogpt.md',
    'ClaudeBar': 'backlog-claudebar.md',
    'Koerperschule': 'backlog-koerperschule.md',
    'Solaranlage': 'backlog-solaranlage.md',
    '3D-Drucker': 'backlog-3d-drucker.md',
}
# SSV nutzt eigenes Schema (Regel CC-175) — skip
SKIP_PROJEKTE = {'SSV'}

mem = os.path.expanduser('~/.claude/projects/-Users-scholly/memory/')
missing_by_project = {}
for i in items:
    p = i.get('projekt')
    if not p or p in SKIP_PROJEKTE or i.get('archived'): continue
    bid = i.get('backlog_id')
    if not bid: continue
    md = MAPPING.get(p)
    if not md: continue
    md_path = os.path.join(mem, md)
    if not os.path.exists(md_path): continue
    content = open(md_path).read()
    # Suche nach Backlog-ID in MD (als ### Header oder Inline-Referenz)
    if not re.search(rf'\b{re.escape(bid)}\b', content):
        missing_by_project.setdefault(p, []).append((bid, i.get('title','')[:50]))

if not missing_by_project:
    print('✅ MD-Backlog-Sync: Alle Items haben Eintrag im jeweiligen Markdown-Backlog.')
else:
    print('⚠️  MD-Backlog-Sync: Items fehlen in MD-Backlogs!')
    for p, rows in missing_by_project.items():
        print(f'  {p} → {MAPPING[p]}:')
        for bid, title in rows:
            print(f'    - {bid}: {title}')
    print('→ Nachtragen: Fuer jedes fehlende Item einen `### {bid}` Block im entsprechenden MD-Backlog anlegen.')
PYEOF
```

**Bei Treffern:** Fehlende Items JETZT im jeweiligen Markdown-Backlog nachtragen (kurz-Block `### <BID>: <Titel>` + Notizen/Effort falls bekannt).
**Marker erst setzen wenn:** Output zeigt `✅ MD-Backlog-Sync` ODER alle Treffer nachgetragen und zweiter Lauf ist sauber.

### Finaler Hygiene-Verify (Regel 88, Sprint 151 CC-104)
Nach Kuration: `/api/verify` Call — Board muss `healthy` sein, sonst Marker nicht setzen.
```bash
curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" https://roadmap-escholly-ship-its-projects.vercel.app/api/verify | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'Status: {d[\"status\"]}')
for k, v in d['checks'].items():
    print(f'  {\"✅\" if v else \"❌\"} {k}')
for f in d.get('findings', []):
    print(f'  ⚠️ {f}')
sys.exit(0 if d['status'] == 'healthy' else 1)
"
```
**Findings vorhanden** → SOFORT via PATCH `/api/items` bereinigen (Zombies → `sprint_nummer=null`, BLOCKED in Sprints → `sprint_nummer=null`, Misch-Sprints trennen, leere Sprints korrigieren). Dann erneut verify.

**CC-212 (Sprint 194): Bei 2+ PATCHes nutze `/api/items/batch`** statt N einzelner Calls:
```bash
curl -s -X POST -H "Authorization: Bearer $ROADMAP_TOKEN" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/items/batch \
  -H "Content-Type: application/json" \
  -d '{"updates":[{"id":"uuid1","sprint_nummer":null},{"id":"uuid2","sprint_nummer":null}]}'
```
Response: `{results: [{id,ok,...}], successCount, errorCount}`. HTTP 200 bei 0 Fehlern, 207 bei teilweisem Erfolg.

**Marker NUR bei healthy Board:** `echo done > ~/Cowork/.phase-markers/g-backlog`
Im Chat bestaetigen: "Roadmap-Tool + Markdown-Backlogs synchronisiert UND Hygiene healthy"

> **Hinweis (Scholly-Entscheidung Sprint 182):** Kein Meeting-Schritt mehr im Sprint-Retro. Projekt-Prioritaeten pflegt Scholly eigenstaendig ueber die Web-UI `roadmap-escholly-ship-its-projects.vercel.app/prio` (CC-195). Wenn du hier Anpassungen brauchst: einfach dort setzen, der Pack-Algorithmus liest beim naechsten Sprint-Start.

## G.5: Offene Entscheidungen persistieren (Regel 67)
Wenn in diesem Sprint offene Entscheidungen fuer Scholly entstanden sind:
1. Betroffenes Item im Roadmap-Tool finden (via GET `/api/items`)
2. Abhaengigkeit-Feld setzen via PATCH: `Scholly: [Frage mit vorbereiteten Optionen]`
3. **Keine offenen Fragen** — IMMER Optionen vorbereiten
4. Im Chat bestaetigen: "Offene Entscheidungen im Roadmap-Tool persistiert: [Liste]" ODER "Keine offenen Entscheidungen"
Offene Entscheidungen werden beim naechsten `/sprint-start` automatisch angezeigt.

## G.6: Sprint-Dateien aktualisieren
- **Projekt-Sprint:** Nutze das **Write-Tool** um `.sprint` im Projektverzeichnis mit der naechsten Projekt-Sprint-Nummer zu ueberschreiben.
- **Globaler Sprint:** Bereits in G.2 aus API-Response gespiegelt. Hier nur verifizieren: `cat ~/Cowork/.sprint-global` muss den naechsten Sprint zeigen.
**KEIN `echo >` via Bash** — gleicher Grund.

## G.7: GitHub-Backup pruefen (Regel 26)

**CC-212 (Sprint 194): Beide Repos parallel pushen — spart ~50% Zeit gegenueber sequentiellem Push.**

### Lokal-Mode (Default)

```bash
# Commits vorbereiten (sequenziell, kein Race auf staging)
cd ~/.claude && git add -A projects/-Users-scholly/memory/ CLAUDE.md settings.json hooks/ skills/ && git commit -m "Backup nach [Projekt] Sprint [Nr]" 2>&1 | tail -2 || echo "(keine Memory-Aenderungen)"
cd ~/Cowork && git add -A && git commit -m "Backup nach [Kontext]" 2>&1 | tail -2 || echo "(keine Cowork-Aenderungen)"

# Pushes parallel (CC-212)
(cd ~/.claude && git push &) ; (cd ~/Cowork && git push &) ; wait
echo "✅ Beide Repos gepusht"
```

### Cloud-Mode (CLOUD-P4-Sub-3, Sprint 256)

In Cloud-Sessions ist `git push` nicht moeglich — kein Filesystem-Zugriff auf `~/.claude/` und `~/Cowork/`. Stattdessen: Memory-Updates wurden waehrend der Session **direkt** ueber Write-/Edit-Tools auf dem virtuellen Workspace gemacht; der Backup-Pfad nutzt den `git-commit`-Hook-Relay-Endpoint, der per GitHub-API committet.

Pflicht-Sequenz:
1. Skill-Tool **diff sammeln** — alle waehrend der Session geschriebenen Memory-/Cowork-Files identifizieren (TodoWrite + Edit-Tool-Audit-Log).
2. Pro Datei `content_base64` erzeugen (im Tool-Call inline).
3. Aufruf:
   ```
   POST https://roadmap-escholly-ship-its-projects.vercel.app/api/hook-relay
   Authorization: Bearer <ROADMAP_API_TOKEN>
   Body:
   {
     "type": "git-commit",
     "repo": "escholly-ship-it/cowork",
     "branch": "main",
     "files": [{"path": "memory/...", "content_base64": "..."}],
     "commit_message": "Backup nach [Projekt] Sprint [Nr] (Cloud-Retro)"
   }
   ```
4. Erwartete Antwort: `{ ok: true, commits: [...], errors: [] }`. Bei `503` mit `GITHUB_TOKEN not configured` → Setup-Aufgabe vorhanden, im Telegram-Push erwaehnen (kein Hard-Fail).
5. Zweiter Aufruf fuer `escholly-ship-it/claude-config` (= `~/.claude/`-Repo).

Whitelisted Repos: `escholly-ship-it/cowork`, `escholly-ship-it/claude-config`. Pfade duerfen nicht mit `/` beginnen oder `..` enthalten.

**Nach Backup:**
```bash
mkdir -p ~/Cowork/.phase-markers && echo done > ~/Cowork/.phase-markers/g-backup
```
(CC-121 Sprint 157: separater `g-uebergabe`-Marker entfernt — redundant zu `g-backup`. `/sprint-start` der naechsten Session liest Counter/Backlog/Roadmap selbst; keine Prompt-Ausgabe hier noetig.)

## G.8: Board-Verifikation + G=done setzen (ALLERLETZTER SCHRITT)
**Board-Integritaet pruefen UND G=done in einem Schritt.**

```bash
VERIFY=$(curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" https://roadmap-escholly-ship-its-projects.vercel.app/api/verify)
STATUS=$(echo "$VERIFY" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
if [ "$STATUS" = "healthy" ]; then
  echo done > ~/Cowork/.phase-markers/g-e2e-verified
  echo "✅ Board-Integritaet verifiziert"
else
  echo "❌ Findings:"
  echo "$VERIFY" | python3 -c "import json,sys; [print(f) for f in json.load(sys.stdin).get('findings',[])]"
  echo "Bitte Findings beheben und erneut pruefen."
fi
```

6 Checks (via `/api/verify`):
1. Keine Zombies in vergangenen Sprints
2. Keine Misch-Sprints (1 Projekt pro Sprint)
3. Genau 5 aktive Sprints
4. **Keine leeren Sprint-Spalten** (Gap-Detection, Sprint 145)
5. Keine BLOCKED-Items in Sprints
6. Keine Items mit Zukunfts-Frist in Sprints

**g-e2e-verified gesetzt** → G=done setzen:
Nutze das **Edit-Tool** um in `~/Cowork/.sprint-phases` die Zeile `G=` auf `G=done` zu aendern.
**KEIN Bash/sed** — Berechtigungsschutz von `~/.claude/`.
**Ohne diesen Schritt blockiert das Phase-Gate die Session-Beendigung.**

**Findings** → Beheben via PATCH `/api/items`, dann erneut pruefen.

**Mobile-Push (Sprint 261 PushNotification-Migration):** Nach G=done:
```
PushNotification(status: 'proactive', message: 'Sprint <N> fertig. Geliefert: <3-Bullet-Kurz>. Neue Session kann starten.')
```

Anthropic-natives Tool — pingt direkt auf Mobile-App. KEIN notify-scholly mehr (Bash + HTTP-Endpoint sind Noop seit Sprint 261).

**INHALT (Regel 110, menschliche Sprache):** Sprint-End-Push ist KEIN Status-Geplapper — er enthaelt eine 3-Bullet-Zusammenfassung was geliefert wurde + 1-Satz-Aufforderung "neue Session starten". Beispiel: "Sprint 246 fertig. Geliefert: (1) Roadmap 2.0 Phase γ live, (2) Anti-Silent-Pause Hook, (3) Cookmark-Pre-Check. Du kannst eine neue Session starten."

## PFLICHT-FINAL-OUTPUT: Lokal-vs-Remote-Empfehlung naechster Sprint (Sprint 261 Scholly-Forderung 2026-05-04)

**Bevor der Skill endet, MUSS dieser Block ausgegeben werden — keine Ausnahme.**

```
### Naechster Sprint (Sprint <N+1>) — Lokal oder Remote?

**Verifikations-Status (was ist nötig fuer Cloud-Sessions):**
| Pruefung | Status | Wo geprueft |
|---|---|---|
| Personal Skills hochgeladen (claude.ai/customize/skills) | ✅/❌ | Chrome MCP claude.ai/customize/skills |
| GitHub PAT R+W + alle Repos | ✅/❌ | github.com/settings/personal-access-tokens |
| Mobile-Push aktiv (R4 oder andere Routine hat heute Push gesendet) | ✅/❌ | Findings-Tracker letzte 24h |
| Cloud-Smoke-Test in der Vergangenheit gruen | ✅/❌ | letzter erfolgreicher /sprint-start in Cloud-Session |

**Empfehlung:** [REMOTE-FIRST | LOKAL-DEFAULT-CLOUD-SMOKE-TEST-PARALLEL | LOKAL-NUR]

**Begruendung:** [1-Satz warum]

**Default ab Sprint-261-Entscheidung 2026-05-04:** LOKAL bis alle 7 Sicherheits-Kriterien aus `sprint-262-cloud-fallback-plan.md` grun sind. Cloud-Smoke-Test laeuft parallel zu Mac-CLI-Sprint, NICHT als Sprint-Vehikel.

**Cloud-Migration-Status-Tracker (mind. 7 Kriterien dokumentieren):**
1. Skill-Slash-Menu Cloud-Session [3x verifiziert?]
2. Bootstrap-Skript exit 0 [3x?]
3. /api/verify + /api/memory-read 200 [3x?]
4. PushNotification Mobile [3x?]
5. /api/memory-write Sprint-Retro [3x?]
6. Voller Sprint-A-bis-G Cloud [1x?]
7. Mac-aus-24h-Zyklus [1x?]

Erst wenn ALLE 7 grun sind: REMOTE-FIRST erlaubt.
```

**Skill-Sync-Reminder:** Wenn dieser Skill seit der letzten Phase-G-Ausgabe geaendert wurde (lokal `~/.claude/skills/sprint-retro/SKILL.md`), MUSS der Sync-Pfad ausgegeben werden:
1. Lokal aktualisiert: ✅ automatisch (Edit-Tool)
2. scholly-toolkit Repo aktualisiert: pflicht `rsync + commit + push escholly-ship-it/scholly-toolkit`
3. claude.ai Personal Skill: **MANUELLER RE-UPLOAD von ZIP noetig** — auf Desktop-Ordner ablegen + PushNotification an Scholly mit "Re-Upload nötig"

Sprint-262-Item CC-SKILL-PERSONAL-SYNC-AUTO loest dieses Manuell-Friction-Problem.
