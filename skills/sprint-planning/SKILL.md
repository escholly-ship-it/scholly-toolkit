---
name: sprint-planning
description: Sprint-Zeremonie Phase 0 — strategische Planung VOR `/sprint-start`. Beantwortet "WAS bauen wir und WARUM?" als 1-Satz-Sprint-Ziel + Scope/Stretch/Risks-Tabelle. Trigger bei "plan den naechsten Sprint", "sprint planning", "was machen wir naechsten Sprint", "scope den sprint", "naechsten sprint vorbereiten", oder wenn Scholly nach Abschluss eines Sprints den naechsten ausrichten will, bevor er `/sprint-start` aufruft. Output wird in `/api/sprint-cache` persistiert und von `/sprint-start` gelesen.
---

# Phase 0 — Sprint Planning (vor `/sprint-start`)

**Zweck:** Strategische Vorklaerung *was* in den naechsten Sprint reinkommt, *warum* und *was nicht*. Beantwortet die Kunden-Frage bevor der operative Setup-Skill `/sprint-start` laeuft.

**Verantwortungs-Trennung:**
- `/sprint-planning` (dieser Skill): WAS + WARUM. Backlog-Auswahl, Scope, Stretch, Risks, 1-Satz-Sprint-Ziel.
- `/sprint-start`: WIE. State-Reset, Arbeitsregeln, Experten-Team, Modell-Empfehlung, autonomes Phase-B-Onset.

**Skip-Regel:** Wer direkt `/sprint-start` aufruft, bekommt seit jeher die Scope-Bloecke (4a-4f) inline — `/sprint-planning` ist *additiv*, nicht *substitutiv*. Es macht das Planning explizit, langsam, kunden-bestaetigbar — wertvoll wenn Scope unklar oder Sprint umfangreich/strategisch ist.

**Inspiration:** Anthropic `product-management:sprint-planning`-Template (Risks, Stretch, Capacity-Buffer 70-80%) — adaptiert an Solo-Sprint mit Roadmap-API + empirischer Capacity-Analyse.

---

## API-Auth (CC-54)
```bash
ROADMAP_TOKEN=$(cat ~/.roadmap-api-token 2>/dev/null)
```

## Cloud-Mode

Cloud-Sessions nutzen die gleichen API-Endpoints wie Lokal. Detection: wenn `Bash` nicht verfuegbar, ueber `WebFetch`/`mcp__d65e329f-...__execute_sql` ersetzen. Der Output landet im `/api/sprint-cache` — beide Modi schreiben dort hin, `/sprint-start` liest es ohne Mode-Wissen wieder ab.

---

## Schritt 1: Aktuellen Stand laden

**Globaler Sprint-Counter:** !`cat ~/Cowork/.sprint-global 2>/dev/null || echo "?"`
**Letzter Phase-G-Stand:** !`cat ~/Cowork/.sprint-phases-* 2>/dev/null | tail -10`

```bash
TOKEN=$(cat ~/.roadmap-api-token)
# Verify-Status holen
curl -s -H "Authorization: Bearer $TOKEN" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/verify \
  | python3 -m json.tool
# Aktuelle Items in der Pipeline (5-Sprint-Fenster)
curl -s -H "Authorization: Bearer $TOKEN" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/items > /tmp/sprint-planning-items.json
echo "Items geladen: $(python3 -c 'import json; print(len(json.load(open("/tmp/sprint-planning-items.json"))))') gesamt"
```

**Cloud-Mode:** Beide curls funktionieren in Cloud-Sessions; `/tmp/`-Path wird durch Cloud-Workspace-Path ersetzt (`mktemp` oder skill-internes Cache-Konzept).

## Schritt 2: Capacity-Richtwert + Backlog-Pulse

**Empirische Capacity (CC-262 Sprint 213):**
```bash
TARGET=$(cat ~/Cowork/.sprint-capacity-target 2>/dev/null || echo "8")
CAP_JSON=$(ls -t ~/Cowork/logs/capacity-*.json 2>/dev/null | head -1)
if [ -n "$CAP_JSON" ]; then
  python3 -c "
import json
d = json.load(open('$CAP_JSON'))
print(f\"📐 Capacity-Richtwert (Fenster {d['window']} Sprints S{d['first_sprint']}-{d['last_sprint']}):\")
print(f\"   Sweetspot: {d['sweetspot']}P | P50: {d['p50']}P | P75: {d['p75']}P | P95: {d['p95']}P\")
print(f\"   Letzte 5 Sprints: {d['sauber_count']} sauber, {d['neutral_count']} neutral, {d['hektik_count']} hektik\")
"
fi
```

**Pulse:** Hat der letzte Sprint einen Trend gesetzt? Mehrere Hektik-Sprints in Folge → P75 anpassen, Buffer einbauen. Mehrere Sauber-Sprints → ggf. Stretch-Item moeglich.

**Anthropic-Buffer-Regel uebernommen:** Plane auf **70-80% des P75** als Soll-Scope. Verbleibende 20-30% sind Puffer fuer Interrupts (Kunden-Feedback-Loops, ad-hoc Findings, externe Blocker).

## Schritt 3: Carry-Over ehrlich angucken

**Drei Quellen pruefen:**

1. **Letzter Sprint nicht-erledigt** (Roadmap-Sync hat in Phase G via `failed_sprint` zurueckgelegt):
   ```bash
   python3 -c "
   import json
   items = json.load(open('/tmp/sprint-planning-items.json'))
   gs_minus_1 = $(cat ~/Cowork/.sprint-global) - 1
   carryover = [i for i in items if 'GESCHEITERT' in (i.get('notizen') or '') or i.get('sprint_nummer') == gs_minus_1 + 1]
   print(f'Carry-over Kandidaten: {len(carryover)}')
   for i in carryover:
       print(f'  - {i[\"backlog_id\"]:25} | {i.get(\"effort\",\"?\"):3} | {i[\"title\"][:60]}')
   "
   ```

2. **NICHT-DE-SCOPABLE-Items** (Memory-Files `sprint-XXX-pflicht-*.md`):
   ```bash
   ls ~/.claude/projects/-Users-scholly/memory/sprint-*-pflicht-*.md 2>/dev/null
   ```
   Pro Pflicht-File: Welcher Sprint ist im Tag? Steht das Item noch im aktuellen Sprint?

3. **Initiative-Watcher** (CC-392, falls eingerichtet):
   ```bash
   curl -s -H "Authorization: Bearer $TOKEN" \
     https://roadmap-escholly-ship-its-projects.vercel.app/api/cross-project-overview
   ```

**Anthropic-Pattern: "Carry over honestly"** — Wenn ein Item zum 2. Mal carry-overt: WARUM ist es nicht fertig geworden? Scope zu gross? Blocker? Falsche Schnittebene? *Bevor* es wieder rein-committed wird, Frage beantworten.

## Schritt 4: Scope vorschlagen — Was kommt rein?

**Algorithmus:**

1. **Pflicht-Items zuerst** (NICHT-DE-SCOPABLE laut sprint-*-pflicht-*.md)
2. **Ehrliche Carry-overs** (mit Grund-Kommentar)
3. **Pack-Algo respektieren** (`/api/items?sprint=N` zeigt vorgepackten Plan)
4. **Single-Theme-Praeferenz** (Regel 79): Wenn moeglich, ein Sprint = ein Projekt-Thema. Misch-Sprints nur wenn 2 Pflicht-Items aus verschiedenen Projekten zusammenkommen.
5. **Effort-Summe gegen Capacity-Soll** (70-80% P75)

**Ausgabe-Format:**

```
### Sprint <N+1> — Vorschlag-Scope

**Sweetspot-Soll:** [70-80% von P75 = X-Y P]  
**Vorgeschlagene Effort-Summe:** [Z P]  
**Buffer:** [P75 - Z = N P fuer Interrupts]

| # | Backlog-ID | Titel | Effort | Verify-Loc | Pflicht? | Carry? |
|---|-----------|-------|--------|-----------|----------|--------|
| 1 | ... | ... | M (3P) | mac | NICHT-DE-SCOPABLE | nein |
| 2 | ... | ... | S (2P) | cloud | nein | 1x carryover (Grund: ...) |

**Stretch-Items (nur wenn Soll erfuellt + Buffer ueberschritten):**

| # | Backlog-ID | Titel | Effort | Wann opfern? |
|---|-----------|-------|--------|--------------|
| S1 | ... | ... | XS (1P) | bei jedem Hektik-Signal |
```

**Anthropic-Pattern: "Identify stretch items"** — Stretch ist nicht "tun wenn Zeit", sondern "konkretes Item das wir bewusst opfern bei jedem ersten Stress-Signal".

## Schritt 5: Risks aktiv suchen + dokumentieren

Anthropic-Template hat eine eigene Risks-Tabelle. Adaptiert auf unseren Kontext:

```
### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| [z.B. "Symlink-Migration triggert in Cloud anders als lokal"] | [Sprint-blockiert wenn Cloud-Session Migration nicht sieht] | [Konflikt-Test in beiden Modi VOR Phase D] |
| [z.B. "Neuer Skill ueberlappt mit Anthropic-Plugin-Skill"] | [Slash-Routing-Verwirrung] | [Namespace-Test in beiden Aufruf-Formen] |
```

**Mindestens 2 Risks suchen** — auch wenn Sprint einfach wirkt. Forcieren das mentale Ueberpruefen.

**Quellen fuer Risk-Identifikation:**
- Memory `incident-*-postmortem.md` — gibts ein vergleichbares Pattern?
- Memory `feedback_*.md` — gibts ein Feedback gegen genau diesen Move?
- Item-Notizen — steht "Vorsicht" oder "Race" oder "Cloud" drin?
- Cross-Sprint-Migrations-Survey aus sprint-review

## Schritt 6: Sprint-Ziel als 1-Satz-Vertrag

**Anthropic-Pattern: "If you can't state it in one sentence, the sprint is unfocused."** — uebernehmen.

**Format:**
```
### Sprint <N+1> — Sprint-Ziel

**Ein-Satz-Ziel:**
[Genau 1 Satz. Subject = was geliefert wird. Verb = aktiv. Wert-Aussage als Praeposition: "...damit Scholly..." oder "...sodass...".]

**Definition of Done (Anthropic-Template uebernommen + adaptiert):**
- [ ] Code reviewed (lokal oder via /ultrareview)
- [ ] Tests passing (Critical-Path-Test wo anwendbar — Regel 109)
- [ ] Doku aktualisiert (Memory + Backlog + ggf. Notion)
- [ ] Production deployed + verifiziert (wenn Prod-Touch=ja)
- [ ] Kunden-Abnahme erfolgt (Phase E Schritt 5)
```

## Schritt 7: Plan persistieren + an `/sprint-start` uebergeben

**Lokal:** Plan-Markdown unter `~/Cowork/.sprint-plan-<N+1>.md` ablegen (Sprint-N+1 = der zu startende Sprint).

**Cloud-Mirror via `/api/sprint-cache`:**
```bash
NEXT_SPRINT=$(($(cat ~/Cowork/.sprint-global) + 1))
SESSION=$(cat ~/Cowork/.current-sprint-tag 2>/dev/null | tr -d '[:space:]')
PLAN_JSON=$(python3 -c "
import json, sys
plan = {
    'sprint_target': $NEXT_SPRINT,
    'goal_one_liner': '<Ein-Satz-Ziel hier>',
    'scope': [{'backlog_id': 'CC-XXX', 'effort': 'M', 'verify_location': 'cloud'}],
    'stretch': [{'backlog_id': 'CC-YYY', 'effort': 'XS'}],
    'risks': [{'risk': '...', 'impact': '...', 'mitigation': '...'}],
    'capacity_soll': 8,
    'effort_sum': 6,
    'buffer': 2
}
print(json.dumps(plan))
")
curl -sS -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$SESSION\",\"plan\":$PLAN_JSON}" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/sprint-cache
```

**`/sprint-start` Pickup:** Der Skill liest `/api/sprint-cache?session=...` und uebernimmt das `plan`-Feld als Vorlage fuer Schritt 4 (Scope+Deliverables). Ohne Plan-Eintrag laeuft `/sprint-start` wie bisher (Selbst-Scope).

## Schritt 8: Push + Stop fuer Scholly-Bestaetigung

**Anthropic-natives Push (Sprint 261):**
```
PushNotification(status: 'proactive', message: 'Sprint <N+1> Plan zur Bestaetigung: <1-Satz-Ziel> | <X> Items, <Y>P. ANTWORTE: "go" + /sprint-start ODER "anpassen: ...".')
```

**Stop-Erwartung:** Nach Push wartet der Skill auf Scholly-Antwort. Bei "go" → Scholly invoked `/sprint-start` als naechsten Schritt. Bei "anpassen: X" → Skill nimmt Korrektur-Input + ueberarbeitet Scope/Risks/Goal, dann erneuter Push.

**STILLE PAUSE = SKILL-VERSTOSS** (Regel 22 + Sprint-246-Anti-Silent). Push MUSS raus.

---

## Was dieser Skill NICHT tut (klare Abgrenzung)

- **Keine** State-File-Initialisierung (`~/Cowork/.sprint-phases-<id>`) — das ist `/sprint-start` Schritt 0.
- **Keine** Arbeitsregeln-Lesung — `/sprint-start` Schritt 1.
- **Kein** Experten-Team — `/sprint-start` Schritt 5.
- **Keine** Modell-Empfehlung — `/sprint-start` Schritt 9-10.
- **Keine** Phase-Marker — der Skill ist Phase-0, nicht Phase-A. Er setzt KEIN `a-*`-Marker.

Der Skill produziert **NUR** den Plan. Operatives Setup ist und bleibt `/sprint-start`-Job.

---

## Skip-Pfade

- **Ad-hoc-Sprint** (kein vorgeplanter Scope, einzelne Item-Korrektur): Kein Planning noetig — direkt `/sprint-start`.
- **Pflicht-Sprint mit Single-Theme + 2 Items + 100% klar** (z.B. Sprint 265 Symlink-Migration heute): Kein Planning noetig — direkt `/sprint-start` oder ad-hoc.
- **Strategischer Sprint, neue Initiative, viele moegliche Items, unklare Prioritaet**: Hier zahlt sich der Skill aus.

Faustregel: Wenn die Frage "was machen wir naechsten Sprint?" mehr als 30 Sekunden Nachdenken kostet → `/sprint-planning`. Sonst direkt `/sprint-start`.

---

## Selbst-Test

Den Skill manuell triggern und pruefen:
1. Schritt 1-3 liefern Daten (Verify, Items, Capacity, Carry-over)
2. Schritt 4-6 produzieren die 4 Bloecke (Scope, Stretch, Risks, Goal)
3. Schritt 7 schreibt `~/Cowork/.sprint-plan-<N+1>.md` UND `/api/sprint-cache` Eintrag
4. `curl /api/sprint-cache?session=$SESSION | jq .plan` zeigt das gespeicherte Plan-JSON
5. `/sprint-start` (in selber Session) pickt es auf — sichtbar in Phase-A-Output Schritt 4 mit Hinweis "Plan aus /sprint-planning uebernommen".
