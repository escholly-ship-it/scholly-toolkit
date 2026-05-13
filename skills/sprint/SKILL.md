---
name: sprint
description: Der gesamte Sprint-Arc in EINEM Skill — Goal → Setup → Execution → Abnahme → Close → Sessionende. Drei vereinbarte Pings (Goal, Abnahme, Ende) plus Ad-hoc-Frage wenn ohne deine Antwort nicht weiter geht. Ersetzt /start, /close, /sprint-start, /sprint-review, /sprint-retro, /sprint-planning. Sprint 283 Refactor.
---

# /sprint — Einheitliches Sprint-Skill

## Bewusstseinsregeln (LESEN VOR JEDER PHASE)

**1. Klare User-Sprache in jeder Nachricht an Scholly.**
Tabellen mit Backlog-IDs (CC-XXX, KP-XXX) sind erlaubt. Narrative Status-Saetze in der Antwort an Scholly muessen in deutscher Alltagssprache sein. Keine "Phase X done"-Reports. Lies aktuelle Antwort wie ein Mensch — passt das in eine SMS? Wenn nicht, umformulieren.

**2. Drei vereinbarte Pings + Ad-hoc bei echtem Input-Bedarf. Mehr nicht.**
- **goal:** nach Sprint-Pack, vor Setup. Frage: "Sprint-Plan ok?"
- **abnahme:** nach Execution + Tests + Deploy. Frage: "Sprint-Ergebnis ok?"
- **ende:** nach Close. Information: "Sprint X zu, naechste Session ist Y."
- **frage:** ad-hoc wenn ohne Schollys Antwort kein Fortschritt moeglich (z.B. Vercel-Decide). NIEMALS fuer "ich bin in Phase X" oder "Item Y done" oder "soll ich weiter".

**3. Pausieren ist NICHT stehenbleiben.**
Wenn das Token-Fenster knapp wird mitten in Phase D: phase_state.current_item_id setzen + Item.status='in_progress' + sub_state in notizen schreiben. Naechster /sprint-Aufruf springt direkt zurueck. KEIN Ping, du wirst nicht gestoert.

**4. Anti-Annahme.** Was ich nicht weiss, validiere ich (DB-Read, grep, Curl). Was ich annehme, ist ein Bug-Kandidat.

## API-Auth (alle Curls)

```bash
TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null)
API="https://roadmap-escholly-ship-its-projects.vercel.app/api"
```

## notify()-Konvention (in JEDEM Stop und ad-hoc)

Sequenz pro Ping (in EXAKT dieser Reihenfolge):

```
1. Skill ruft Tool: PushNotification(message=<msg>, status='proactive')
2. Skill liest Return-Value:
   - Enthaelt "not sent" → Mobile-Push fehlgeschlagen → Schritt 3
   - "sent" oder kein "not sent" → fertig, weiter mit Stop-Logik
3. Skill ruft Bash: ~/Cowork/scripts/notify.sh <typ> "<msg>"
   typ ∈ {goal, abnahme, ende, frage}
4. Skill liest Exit-Code:
   - 0 → fertig
   - != 0 → HARD-ERROR im Chat: "Notify konnte Dich nicht erreichen — pruefe Telegram-Bot-Token + Mobile-App-Pairing. Skill stoppt." + Skill-Exit
5. Bei "goal", "abnahme", "frage": WARTE auf Schollys Antwort, kein Tool-Call dazwischen
   Bei "ende": kein Warten — Sessionende-Info, Skill terminiert
```

---

## Schritt 0 — Resume-Check (PFLICHT als erster Schritt)

Pruefe ob eine Pause aktiv ist. Wenn ja, springe direkt zu Phase D mit dem laufenden Item.

```bash
TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null)
SESSION_TAG=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null)
if [ -n "$SESSION_TAG" ]; then
  STATE=$(curl -sS -H "Authorization: Bearer $TOKEN" \
    "$API/phase-state?session=$SESSION_TAG")
  CURRENT_ITEM=$(echo "$STATE" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('current_item_id') or '')" 2>/dev/null)
  if [ -n "$CURRENT_ITEM" ]; then
    echo "RESUME: current_item_id=$CURRENT_ITEM"
    # → Springe zu Phase D mit diesem Item
  fi
fi
```

Wenn Resume aktiv: skip Phase 0a-A, lade Item-Daten, lies `sub_state` aus `notizen` (Marker `---SUB-STATE---`), mache da weiter. Sonst weiter mit Phase 0a.

---

## Phase 0a — Sprint-Nummer (forensisch)

```bash
VERIFY=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API/verify")
NEXT=$(echo "$VERIFY" | python3 -c "import json,sys;print(json.load(sys.stdin)['nextPlannableSprint'])")
GOAL=$(echo "$VERIFY" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('currentSprintGoal') or 'NULL')")
PHASE=$(echo "$VERIFY" | python3 -c "import json,sys;print(json.load(sys.stdin).get('currentPhase') or '')")
SPRINT_ITEMS=$(echo "$VERIFY" | python3 -c "import json,sys;print(json.load(sys.stdin).get('sprintItems',0))")
echo "Sprint $NEXT (Goal: $GOAL, Phase: $PHASE, Items: $SPRINT_ITEMS)"
```

Wenn `plannableStatus != PLANNABLE` → Hard-Stop + erklaere im Chat warum.

### Phase 0a-Cross-Check — Retro + Counter-Inkonsistenz (PFLICHT, Sprint 290 Inzident)

Drei Cross-Checks gegen Self-Widersprueche. JEDEN ausfuehren bevor Phase 0c/d.

```bash
RETROS=~/.claude/projects/-Users-scholly/memory/retros.md

# Check 1: Hat $NEXT bereits einen Retro-Block? → Counter klemmt, Sprint laeuft eigentlich auf $NEXT+1
RETRO_BUMP=$(python3 -c "
import re, pathlib
txt = pathlib.Path.home().joinpath('.claude/projects/-Users-scholly/memory/retros.md').read_text()
print('1' if re.search(r'^## Sprint $NEXT(?:\s|—|-)', txt, re.MULTILINE) else '0')")
[ "$RETRO_BUMP" = "1" ] && echo "WARN: Retro fuer Sprint $NEXT existiert. Counter haengt — Sprint geht auf $((NEXT+1))."

# Check 2: Phase=G aber sprintItems=0 → vorheriger Sprint nie sauber geschlossen
if [ "$PHASE" = "G" ] && [ "$SPRINT_ITEMS" -eq 0 ]; then
  echo "WARN: Phase=G + 0 Items = letzter Sprint nicht geschlossen. Cleanup: PATCH /api/config {current_phase: null}, dann POST /api/sync."
  PHASE_G_DRIFT=1
fi

# Check 3: Letzte 2 Retro-Bloecke auf "Folge-Items / Carry-Over" scannen, IDs extrahieren
python3 <<'PY'
import re, pathlib
txt = pathlib.Path.home().joinpath('.claude/projects/-Users-scholly/memory/retros.md').read_text()
blocks = re.findall(r'## Sprint (\d+).*?(?=\n## Sprint |\Z)', txt, re.DOTALL)
# Letzte 2 Sprint-Bloecke
last_two = sorted(blocks, key=lambda b: int(re.match(r'(\d+)', b).group(1)))[-2:]
print('\n--- Carry-Over / Folge-Items aus letzten 2 Retros ---')
for blk in last_two:
    sprint_n = re.match(r'(\d+)', blk).group(1)
    # Finde "Folge-Items", "Carry-Over", "Findings"-Abschnitte und IDs
    for m in re.finditer(r'(?:Folge-Items|Carry-Over|Findings|nach Sprint).*?(?=\n###|\Z)', blk, re.DOTALL | re.IGNORECASE):
        ids = re.findall(r'\b(?:CC|TA|KP|TB|CT|SL|INFRA|PG|GW|AUTO|DE|KS|CK|WL|SMI)-[A-Z0-9-]+', m.group(0))
        if ids:
            print(f'Sprint {sprint_n}: {sorted(set(ids))}')
PY
```

**Bei `RETRO_BUMP=1`:** Setze `NEXT=$((NEXT+1))` + setze in API `current_phase=done` fuer alten Sprint + inkrementiere `globalSprint`. KEIN Goal-Pack auf alter Nummer.

**Bei `PHASE_G_DRIFT=1`:** Hard-Stop bis Counter-Cleanup durch (PATCH `/api/config {current_phase: 'done'}` + `/api/sync`).

**Bei extrahierten Carry-Over-IDs:** Pflicht-Cross-Check in Phase 0d — jede ID muss entweder im neuen Sprint-Pack sein ODER explizit als "bewusst Backlog" begruendet. Sonst Drift.

## Phase 0c — Cloud-First Default

Items defaulten auf `verify_location='cloud'`. Lokal nur wenn Sprint Mac-Tier-Code beruehrt (launchctl, osascript, Apple Notes, iMessage, Bambu-MCP, Wispr Flow, Computer-Use, Papierkram-Inbox).

## Phase 0c-Audit — Sprint-Pack Sanity (CC-INITIATIVE-RETRO-AUDIT, Sprint 285)

Bevor Goal-Abnahme: pruefe alle Items im aktuellen `targetSprint` auf zwei Klassen von Drift. Hard-Stop bei Befund + Vorschlag im Chat.

```bash
curl -sS -H "Authorization: Bearer $TOKEN" "$API/items?sprint=$NEXT" > /tmp/audit-items.json
ALL=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API/items?archived=true")
echo "$ALL" > /tmp/audit-all.json

python3 <<'PY'
import json
items_sprint = json.load(open('/tmp/audit-items.json'))
items_all = json.load(open('/tmp/audit-all.json'))
if isinstance(items_sprint, dict): items_sprint = items_sprint.get('items', [])
if isinstance(items_all, dict): items_all = items_all.get('items', [])
done_archived_ids = {i['backlog_id'] for i in items_all if i.get('status')=='done' and i.get('archived')}

zombies = []
missing_init = []
currency_flag = []
for i in items_sprint:
    bid = i.get('backlog_id')
    if bid in done_archived_ids:
        zombies.append(bid)
    if not i.get('initiative_id'):
        missing_init.append(bid)
    nz = (i.get('notizen') or '').lower()
    if 'currency-audit' in nz and ('done-marker' in nz or 'bereits abgeschlossen' in nz):
        currency_flag.append(bid)

print(f'ZOMBIES: {zombies}')
print(f'NO_INITIATIVE: {missing_init}')
print(f'CURRENCY_FLAGGED: {currency_flag}')
PY
```

**Bei Befund:**
- Zombies → Items aus Sprint droppen (PATCH `sprint_nummer=null`), im Chat erklaeren.
- Currency-flagged → manuell verifizieren ob bereits done; wenn ja, droppen.
- No-initiative → IT-Architekt-Persona schlaegt Initiative-Mapping vor; manuell zuordnen oder als Standalone akzeptieren.

Erst danach Phase 0d.

## Phase 0d — Now / Next / Later

```bash
curl -sS -H "Authorization: Bearer $TOKEN" "$API/items?sprint=$NEXT" > /tmp/now-items.json
curl -sS -H "Authorization: Bearer $TOKEN" "$API/pack/suggest?sprint=$((NEXT+1))" > /tmp/next-suggest.json
```

Generiere Markdown-Tabelle:

```markdown
| Aspekt | 🟢 Now Sprint $NEXT | 🟡 Next Sprint $((NEXT+1)) | 🔵 Later |
|--------|---------------------|----------------------------|----------|
| Items | <count + effort-sum> | <suggest top 3-5> | <backlog count> |
| Goal | <1-Satz user-sprache> | tbd nach Now-Abnahme | — |
```

**Capacity-Hint:** Sum Effort (XS=1, S=2, M=5, L=10, XL=20) vs Sweetspot 30P. Status `under` (<70%) / `ok` / `over` (>120%). Bei `under` mit Suggestions Vorschlag posten. Bei `over` Item-Verschiebung empfehlen.

## Phase 0e — GOAL-ABNAHME (STOP #1)

Sende `notify('goal', "Sprint $NEXT Plan: <user-sprache>. <N> Items, <P>P. ok?")`. Folge notify()-Konvention oben. **Warte auf Schollys Antwort.** Bei "ok" weiter Phase A. Bei Korrektur: Pack anpassen, neu notify.

---

## Phase A — Setup

```bash
SESSION_TAG=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "$SESSION_TAG" > ~/Cowork/.current-sprint-tag

# Phase-state init
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$SESSION_TAG\",\"sprint\":$NEXT,\"project\":\"multi\"}" \
  "$API/phase-state" > /dev/null

# Goal in config setzen
curl -sS -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"current_phase\":\"A\",\"current_sprint_goal\":\"<goal>\"}" "$API/config" > /dev/null
```

**Memory-Tier-Loading (Token-effizient):**
- IMMER: CLAUDE.md (auto), MEMORY.md (auto), verhaltensregeln.md (auto)
- NACH Goal: arbeitsregeln.md, IT-Architekt-Persona, evtl. weitere Personas (siehe unten)

**Experten-Team-Empfehlung (durch IT-Architekt-Persona, NICHT pauschal):**
- Standard Code-Sprint: backend-dev + frontend-dev + qa + devops
- Refactor-Sprint: + IT-Architekt + knowledge-manager
- Content-Sprint: content-stratege + content-copy + visual-designer
- Kunden-Projekt: + ux-researcher + ux-ui + freelance-business

**Modell-Empfehlung:** Opus 4.7 (1M) high fuer Refactor/Architektur, medium fuer normale Code-Sprints, Sonnet 4.6 fuer kleine Items.

**Phase-0-Artifact persistieren:**

```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"sprint_nummer\":$NEXT,\"phase_id\":0,\"output_json\":{
       \"goal\":\"<user-sprache>\",
       \"items\":[...backlog_ids],
       \"team\":[...personas],
       \"risks\":[...]
     }}" "$API/sprint-artifacts" > /dev/null
```

---

## Phase B — Per-Item-Plan (PFLICHT, nicht ueberspringen)

Pro Sprint-Item, der Reihe nach:

1. **Lies** `acceptance_criteria`, `notizen`, `prerequisites`, `user_story`. Wenn `acceptance_criteria` leer ist → ROTER PFEIL: in Phase B definieren bevor weiter, nicht spaeter mid-coding.
2. **Files-Liste**: welche konkreten Pfade werden angefasst? Existieren sie? (1 Tool-Roundtrip Verifikation pro nicht-trivialem Pfad.)
3. **Annahmen-Verifikation**: jede Annahme, die nicht aus AC/Notizen folgt, hier listen + verifizieren. Beispiele:
   - "pg_cron aktiv?" → `select extname from pg_extension`
   - "Edge-Function-Pattern existiert?" → `ls supabase/functions/`
   - "Library-Version aktuell?" → `npm view <paket> version`
   - **"Skill-Edit ist in Cloud-Sessions sichtbar?"** → Skill-File-Edit alleine reicht NICHT. Pflicht: ZIP rebuild + manueller Upload zu claude.ai/customize/skills (Anthropic Skills-API ist read-only, siehe CC-PERSONAL-SKILLS-AUTOUPLOAD). Sprint-285-Inzident dokumentiert.
   - "Routine-Trigger zieht aktuellen Code?" → Check `sources` im RemoteTrigger gegen tatsaechlichen Repo-Branch.

   1 Roundtrip jeder. Mid-Coding-Discovery ist hier zu finden, nicht in Phase D.
4. **Tests-Skizze**: welche Tests sind kritisch? Filter-Logik isoliert? Integration? Spec der negativen Pfade (409, 401, leer).
5. **Risks-Liste**: was kann scheitern? Welche Edge-Cases? Bypass-Mechaniken (allow_resurrect etc.) — JETZT durchdenken, nicht mid-coding.

**Phase-1-Artifact persistieren** mit dem per_item_plan-Array:

```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"sprint_nummer\":$NEXT,\"phase_id\":1,\"output_json\":{
       \"per_item_plan\":[
         {\"backlog_id\":\"...\",\"files\":[...],\"assumptions_verified\":[...],
          \"tests\":[...],\"risks\":[...],\"bypass_mechanics\":[...]}
       ]
     }}" "$API/sprint-artifacts" > /dev/null
```

**Nicht ueberspringen-Vertrag:** Wenn Phase B fehlt, kostet Re-Work in Phase D mehr Token als Phase B selbst. Dokumentierter Inzident: Sprint 285 token-health pg_cron-Migration wegen fehlender Annahmen-Verifikation tot committed. Konsolidieren heisst kuerzer, nicht ueberspringen.

---

## Phase C — Loesungs-Design (PFLICHT, nicht ueberspringen)

**Aufgabe:** ueber alle Phase-B-Skizzen einen kohaerenten Loesungs-Entwurf legen, BEVOR Code geschrieben wird.

1. **Pattern-Konsistenz**: wenn mehrere Items aehnliches Pattern haben (z.B. 4 Routinen-Creates) → 1 Template definieren, dann Instanzen. Nicht 4x leicht anders ad-hoc.
2. **Architektur-Konsistenz**: greifen die Items auf gemeinsame Module/APIs? Migrations-Reihenfolge? Defense-in-Depth-Layer (z.B. pack.ts UND items POST muessen beide guarden)?
3. **Flow-Graph (mental oder Markdown)**: pro Item Abhaengigkeits-Reihenfolge zwischen Items. Welches Item ist Pre-Condition fuer welches? (Beispiel Sprint 285: Zombie-Guard MUSS vor Routinen-Items live sein, damit Folge-Sprints sauber packen.)
4. **Edge-Cases-Konsolidierung**: alle Bypass-Mechaniken und negativen Pfade aus Phase B kreuz-pruefen — gibt es Konflikte?

**Output:** Append an Phase-1-Artifact (`output_json.solution_design`):

```bash
curl -sS -X PATCH ... -d "{...output_json.solution_design:{
  \"shared_patterns\":[...], \"item_dependencies\":[...],
  \"edge_case_conflicts\":[...], \"execution_order\":[...]
}}"
```

**Vor-Phase-D-Stopp**: wenn solution_design Konflikte enthaelt, NICHT in D einsteigen — Phase B fuer betroffene Items wiederholen.

**Konsolidierungs-Hinweis:** Phase C ist Pflicht, nicht weil "Concept-Modell wichtig ist", sondern weil sie ad-hoc-Drift in Phase D verhindert. Sprint 285 hatte 5 leicht inkonsistente Routinen-Prompts statt 1 Template — exakt das Phase-C-Lueck-Symptom.

---

## Phase D — Execution

**Pro Item-Loop:**

```
For ITEM in execution_order:
  1. Setze phase_state.current_item_id = ITEM.id (PATCH /api/phase-state)
  2. PATCH /api/items {id: ITEM.id, status: 'in_progress'}
  3. Arbeite an Item bis AC erfuellt:
     - Lies AC + notizen
     - Editiere/erstelle Files
     - Schreibe Tests (Pattern: src/lib/__tests__/*.test.ts oder Bash-Test)
     - Run Tests bis gruen
  4. PATCH /api/items {id: ITEM.id, status: 'done', notizen: '<delivery-bilanz>'}

  Pause-Bedingung (Token-Fenster knapp):
    - phase_state.current_item_id BLEIBT gesetzt
    - Item.status BLEIBT 'in_progress'
    - notizen += '\n---SUB-STATE---\n<wo stehe ich genau>'
    - KEIN notify() — silent stop
    - Naechste Session: Schritt 0 Resume-Check greift, springt zurueck
```

**Anti-Pattern verboten:**
- ❌ `status='done'` ohne erfuellte AC
- ❌ `archived=true` in Phase D (Archive ist Phase G's Job, sonst verschwinden Items aus dem Review)
- ❌ Stop und auf Scholly warten ("soll ich weiter") — Phase D ist autonom

---

## Phase E — Tests + Deploy + Liefer-Bilanz

```bash
# 1. Tests
cd <repo> && npm test || (echo "Tests rot — Hard-Stop" && exit 1)

# 2. Build (wenn relevant)
npm run build

# 3. Deploy-Verify (wenn deploy passiert ist)
curl -sS https://<deployed-url>/api/health | grep -q '"ok":true' || HALT
```

**Liefer-Bilanz-Tabelle (Pflicht):**

```markdown
| Item | Plan-Effort | Status | Diff |
|------|-------------|--------|------|
| CC-XXX | S | done | — |
| CC-YYY | M | blocked | <reason> |
| (neu) CC-ZZZ | XS | done | nachgepackt |
```

**Phase-2-Artifact persistieren:**

```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"sprint_nummer\":$NEXT,\"phase_id\":2,\"output_json\":{
       \"delivered\":[...],
       \"tests_passed\":true,
       \"deploy_verified\":true
     }}" "$API/sprint-artifacts" > /dev/null
```

## E-Stop — SPRINT-ABNAHME (STOP #2)

Sende `notify('abnahme', "Sprint $NEXT fertig: <X>/<Y> Items done. Ergebnis ok?")` mit Liefer-Bilanz. **Warte auf Schollys Antwort.** Bei "ok" weiter Phase F. Bei Korrektur-Wunsch: zurueck in Phase D fuer das betroffene Item.

---

## Phase F — Retro

1. Experten-Personas aktualisieren (Files unter `~/.claude/projects/-Users-scholly/memory/experte-*.md`) — neue Erkenntnisse pro Persona.
2. Memory-Quality-Delta-Check: wieviele MEMORY.md-Entries wurden tatsaechlich gelesen? (Heuristik, kein Hardgate)
3. **Initiative-Audit (CC-INITIATIVE-RETRO-AUDIT, Sprint 285):** Scanne alle Sprint-Items auf `initiative_id IS NULL`. Pro flagged Item: IT-Architekt-Persona schlaegt passende Initiative vor (Pattern-Match auf Titel/Notizen). Liste in retros.md als "Initiative-Drift Sprint $NEXT".
4. Retro reflektieren in `~/.claude/projects/-Users-scholly/memory/retros.md` — was lief gut, was nicht, eine Erkenntnis.

## Phase G — Uebergabe

```bash
# 1. Sprint-Phase F=done, G=in_progress
curl -sS -X PATCH ...

# 2. Items archivieren (NACH Retro, Phase 2 darf das NICHT)
python3 ...  # PATCH archived=true, sprint_nummer BEHALTEN (J5-Fix)

# 3. Backlog-Sync via /api/sync
curl -sS -X POST -H "Authorization: Bearer $TOKEN" "$API/sync"

# 4. Sprint-Counter inkrementieren (Regel 87, 90)
# 5. Next-Sprint-Suggest fuer naechste Session
curl -sS -H "Authorization: Bearer $TOKEN" "$API/pack/suggest?sprint=$((NEXT+1))&capacity=30" > /tmp/next-suggest.json

# 6. Liefer-Tabelle inline aus DB-Items generieren (CC-CHAT-LIEFER-VIEW)
curl -sS -H "Authorization: Bearer $TOKEN" "$API/items?sprint=$NEXT" | python3 -c "
import json,sys
items = json.load(sys.stdin)
if isinstance(items, dict): items = items.get('items', [])
print('| Item | Plan-Effort | Status | Diff |')
print('|------|-------------|--------|------|')
for i in items:
    bid = i.get('backlog_id', '?')
    eff = i.get('effort', '?')
    st = i.get('status', '?')
    diff = ''
    if st == 'blocked':
        notes = (i.get('notizen', '') or '')[:80]
        diff = notes
    elif st == 'done':
        diff = '—'
    print(f'| {bid} | {eff} | {st} | {diff} |')
"
```

Die Tabelle erscheint inline im Chat-Output UND als gekuerzte Form (top-5-Zeilen) im notify('ende', ...)-Body.

**Phase-4-Artifact persistieren:**

```bash
curl -sS -X POST ... -d "{...,\"phase_id\":4,\"output_json\":{
  \"retro_findings\":[...],
  \"backlog_updates\":[...],
  \"next_sprint_proposal\":[...]
}}" "$API/sprint-artifacts"
```

## G-Stop — SESSIONENDE (STOP #3)

Sende `notify('ende', "Sprint $NEXT zu. Naechste Session $((NEXT+1)) wartet auf <NEU-Top>. Bis bald.")` — kein Warten, kein weiteres Tool-Call. Skill terminiert.

---

## Backwards-Compat Trigger

Diese Trigger-Worte starten /sprint:
- "start" / "sprint start" / "sprint planen" → Phase 0a
- "go" / "weiter" → Resume-Check, dann Phase D
- "abschluss" / "uebergabe" / "mach schluss" → Phase E/F/G

Alte Skills `/start`, `/close`, `/sprint-start`, `/sprint-review`, `/sprint-retro`, `/sprint-planning` bleiben als Stubs bis Sprint 284 K2 (Loeschung).

## Anti-Pattern (verboten, dokumentiert aus Sprint 272/277/282)

- ❌ Status-Stop nach Phase-Marker ohne Folge-Tool-Call (Regel 118)
- ❌ Linter-Bash-Skript als externe Validierung — Bewusstseinsregel im Skill-Header reicht
- ❌ 7-Schritt-Pack-Dialog als Default — ein OK reicht
- ❌ Initiative-Discovery-Scan — Initiativen entstehen explizit via Tool
- ❌ Phase-3-UI-Stop im Roadmap-Tool — Abnahme ist Chat
- ❌ `archived=true` in Phase D
- ❌ `sprint_nummer=null` beim Archivieren (J5-Bug)
- ❌ Telegram-Push ohne PushNotification-Versuch
- ❌ Ping bei jeder Phase — nur die 3 vereinbarten plus Ad-hoc

## Cross-Refs

- Persona: `memory/experte-it-architekt.md` (Anti-Overengineering-Default)
- Refactor-Master: `memory/refactor-architektur-sprint-refactor-1.md`
- DB-Constraints: `roadmap_items.block_id NOT NULL` (J1)
- Notify: `~/Cowork/scripts/notify.sh` (J2)
- Pause-Resume: `phase_state.current_item_id` (J3)
- Sync-Fix: `/api/sync` `sprint_nummer` behaelt bei done+archived (J5)
