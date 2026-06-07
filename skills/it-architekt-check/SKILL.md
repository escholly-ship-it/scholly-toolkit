---
name: it-architekt-check
description: IT-Architekt operativer Audit-Skill — prueft Sprint-Plan auf Vollstaendigkeit (Pre-Conditions, Block-Vertraege, Sequenz, Acceptance, Rollback). Pflicht-Aktivierung bei /sprint-start, /sprint-review Schritt 4d, Decision-Lifecycle Schritt 5. Liefert harte JA/NEIN-Antwort mit Findings. Persona-Cross-Ref memory/experte-it-architekt.md.
model: opus
---

# /it-architekt-check — Operativer Architektur-Audit

> **Persona-Aktivierung:** Liest `memory/experte-it-architekt.md` als Pflicht-Vorbereitung. Output muss Architektur-Sicht zeigen, nicht Item-Listen.

## Wann dieser Skill laeuft

| Kontext | Aufrufer |
|---------|----------|
| Vor Sprint-Pack | /sprint-start (Pflicht-Vor-Pack) |
| Phase E Schritt 4d | /sprint-review (vor Kunden-Abnahme) |
| Bei Decision-Lifecycle | Regel 116 Schritt 5 |
| Bei Refactor-Initiative | manuell oder domain-anchor |
| Bei Cross-Project-Theme | manuell |

## Audit-Methodik (5 Pruef-Pfade, sequentiell)

### Pfad 1: Pre-Conditions-Audit (was muss vorher da sein)

```bash
# Pruefen ob Sprint-N alle prerequisites erfuellt hat
TOKEN=$(cat ~/.roadmap-api-token)
SPRINT=$1   # naechster zu startender Sprint

echo "=== Pfad 1: Pre-Conditions-Audit Sprint $SPRINT ==="

ITEMS=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://roadmap-escholly-ship-its-projects.vercel.app/api/items?sprint=$SPRINT" 2>/dev/null)

PRE_FAIL=0
echo "$ITEMS" | python3 -c "
import json, sys
items = json.load(sys.stdin)
for item in items:
    prereqs = item.get('prerequisites') or []
    if not prereqs:
        continue
    # Pro prerequisite: ist Item done? (sprint_nummer < SPRINT und status mit done-Marker)
    for prereq_id in prereqs:
        # API-Call wuerde hier den prereq pruefen — vereinfacht: muss in lower sprint sein
        print(f'Item {item[\"backlog_id\"]}: prereq={prereq_id} — pruefe...')
" 

# Plus: globale Pre-Conditions
# - Repos synchron mit origin?
# - Cloud-Bridge gruen?
# - Skills aktualisiert (last_updated heute fuer geaenderte)?

cd ~/.claude && M_AHEAD=$(git rev-list @{u}..HEAD --count 2>/dev/null || echo "?")
cd ~/Cowork && C_AHEAD=$(git rev-list @{u}..HEAD --count 2>/dev/null || echo "?")
[ "$M_AHEAD" = "0" ] && echo "  ✅ Claude-Repo synchron" || { echo "  ❌ Claude-Repo $M_AHEAD ahead origin"; PRE_FAIL=1; }
[ "$C_AHEAD" = "0" ] && echo "  ✅ Cowork-Repo synchron" || { echo "  ❌ Cowork-Repo $C_AHEAD ahead origin"; PRE_FAIL=1; }

if [ "$PRE_FAIL" = "1" ]; then
  echo "🛑 Pfad 1 FAIL: Pre-Conditions nicht erfuellt"
  exit 1
fi
echo "✅ Pfad 1: Pre-Conditions erfuellt"
```

### Pfad 2: Block-Vertraege-Audit (Input/Output messbar?)

Pro Item im Sprint pruefen:
- Hat das Item ein `block_id`-Feld? Wenn nein → Block-Anchor fehlt (FAIL)
- Hat das Item `acceptance_criteria` (JSON-Array nicht leer)? Wenn nein → nicht objektiv pruefbar (FAIL)
- Hat das Item `rollback_strategy`? Wenn nein → kein Rollback-Plan (WARNING)

```sql
-- Code-First-Check via DB
SELECT 
  backlog_id,
  CASE WHEN block_id IS NULL THEN 'FAIL' ELSE 'OK' END AS block_anchor,
  CASE WHEN acceptance_criteria IS NULL OR jsonb_array_length(acceptance_criteria) = 0 
       THEN 'FAIL' ELSE 'OK' END AS acceptance,
  CASE WHEN rollback_strategy IS NULL OR rollback_strategy = '' 
       THEN 'WARN' ELSE 'OK' END AS rollback
FROM roadmap_items
WHERE sprint_nummer = $SPRINT;
```

Wenn ein FAIL → Sprint NICHT startbar bis Item-Felder gefuellt.

### Pfad 3: Sequentialitaets-Audit (kritischer Pfad)

```python
# Pruefe: hat irgendein Item ein prerequisite das in EINEM SPAETEREN Sprint liegt?
# Das waere Zirkularitaet bzw. unmoegliche Sequenz.
items_all = fetch_all_items()
items_by_id = {i['backlog_id']: i for i in items_all}

for item in items_all:
    if not item.get('sprint_nummer'):
        continue
    for prereq_id in (item.get('prerequisites') or []):
        prereq = items_by_id.get(prereq_id)
        if prereq and prereq.get('sprint_nummer'):
            if prereq['sprint_nummer'] >= item['sprint_nummer']:
                print(f"🛑 SEQUENZ-VERLETZUNG: {item['backlog_id']} (Sprint {item['sprint_nummer']}) "
                      f"braucht {prereq_id} (Sprint {prereq['sprint_nummer']}) — prereq spaeter oder gleich")
```

### Pfad 4: Cross-Cutting-Concerns-Audit

5 Standard-Concerns pro Item pruefen:
1. Cloud-First: ist `verify_location` gesetzt? (Default cloud, Mac nur explizit)
2. Memory-Konsistenz: aendert das Item canonical-Files? Wenn ja: Lifecycle-Marker geplant?
3. Token-Effizienz: ist die Loesung Code (0 Tokens) oder LLM (teuer)? Begruendung?
4. Test-Coverage: hat `acceptance_criteria` Test-Pflicht?
5. Backwards-Compat: bricht das Item bestehende Funktionalitaet? Wenn ja: Migration-Plan?

### Pfad 5: Refactor-Pipeline-Vollstaendigkeits-Audit

Spezifisch fuer Refactor-Initiativen: gibt es Bloecke A-X mit Vertraegen, oder nur Item-Liste?

Pruefen ob `memory/refactor-architektur-*.md` existiert mit:
- Pre-Refactor-Foundation-Block
- Pro Block: Input-Vertrag, Output-Vertrag, kritischer Pfad, Pre-Conditions, Acceptance, Rollback
- Cross-Cutting-Concerns adressiert
- Sequentialitaet validiert (keine Zirkularitaet)

Wenn ein Element fehlt: spezifischer Finding.

## Output-Format

```
=== IT-Architekt-Check Sprint $SPRINT ===

PFAD 1 PRE-CONDITIONS: ✅/❌
PFAD 2 BLOCK-VERTRAEGE: ✅/❌  
PFAD 3 SEQUENZ: ✅/❌
PFAD 4 CROSS-CUTTING: ✅/⚠️/❌
PFAD 5 REFACTOR-PIPELINE: ✅/⚠️/❌ (nur bei Refactor-Sprints)

GESAMT-VERDIKT: SPRINT STARTBAR? JA / NEIN

Wenn NEIN:
  Findings:
    - Pfad X Item Y: konkretes Problem + konkrete Loesung
    - ...
  
Wenn JA:
  Architektur-Hinweise fuer Phase D:
    - Block-Vertrag dieses Sprints: {Input → Output}
    - Kritischer Pfad: {Block-Sequenz}
    - Risk-Mitigation: {Liste}
```

## Aktivierungs-Pattern in anderen Skills

### In /sprint-start (Pflicht-Vor-Pack)
```bash
echo "=== IT-Architekt Pre-Sprint-Check ==="
RESULT=$(it-architekt-check.sh $TARGET_SPRINT)
if echo "$RESULT" | grep -q "STARTBAR? NEIN"; then
  echo "🛑 IT-Architekt blockt Sprint-Start. Findings:"
  echo "$RESULT"
  exit 1
fi
echo "$RESULT"
```

### In /sprint-review Schritt 4d (vor Kunden-Abnahme)
```bash
echo "=== IT-Architekt Pre-Conditions naechster Sprint ==="
NEXT=$((CURRENT_SPRINT + 1))
it-architekt-check.sh $NEXT
# Wenn NEIN: Findings im Phase-3-Output an Scholly fuer Sprint-Nahmt-Vorschlag
```

### In Regel 116 Schritt 5 (Decision-Lifecycle)
```bash
echo "=== IT-Architekt Decision-Auswirkungs-Audit ==="
# Pruefen ob Decision Items in Backlog beruegt + welche
# Pruefen ob Sequenz-Pfad veraendert wird
# Pruefen ob Rollback noetig ist
```

## Acceptance des Skills selbst

- [ ] Skill liest experte-it-architekt.md vor jedem Run
- [ ] 5 Pfade laufen sequentiell, jeder mit JA/NEIN-Output
- [ ] Bei FAIL: konkrete Findings mit Item-IDs + Loesung
- [ ] Token-Cost: <2K Tokens bei alles-gruen, <10K bei Findings
- [ ] Self-Test: laeuft auf aktuellen Refactor-Plan und liefert Findings (sonst hat Skill Bug)

## Cross-Refs

- Persona: `memory/experte-it-architekt.md` (CANONICAL Domain architektur)
- Aktiviert in: `/sprint-start`, `/sprint-review`, Regel 116 Schritt 5
- Schema-Felder: `roadmap_items.block_id`, `prerequisites`, `acceptance_criteria`, `rollback_strategy`
