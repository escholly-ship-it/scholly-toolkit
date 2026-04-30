---
name: roadmap
description: "Inkrementelles Sprint-Roadmap-Management. FIFO-Queue mit Kaskade. Kommandos: init, verify."
---

# `/roadmap` — Sprint-Roadmap-Management (CC-46)

**API:** `https://roadmap-escholly-ship-its-projects.vercel.app/api/`
**Web-UI:** `https://roadmap-escholly-ship-its-projects.vercel.app`
**Auth:** Bearer Token aus `~/.roadmap-api-token`

```bash
ROADMAP_TOKEN=$(cat ~/.roadmap-api-token)
ROADMAP_URL="https://roadmap-escholly-ship-its-projects.vercel.app/api"
```

---

## Grundprinzip

FIFO-Queue mit 5 Sprints. Pro Sprint 1 Projekt. Sprint N aktuell, N+4 am weitesten geplant.

---

## Endpoints

| Endpoint | Methode | Zweck |
|----------|---------|-------|
| `/items` | GET | Items lesen (`?archived=true&projekt=X&sprint=N`) |
| `/items` | POST/PATCH/DELETE | Item erstellen / aktualisieren / archivieren |
| `/verify` | GET | Board-Integritaet (5 Checks) |
| `/pack` | POST | Sprint packen (`{targetSprint}`) |
| `/sync` | POST | Sprint-Ende Lifecycle |
| `/health` | GET | Monitoring (offen) |
| `/auth` | POST | Login (offen, `{password}`) |

---

## Kommandos

**`init`** — Bei `/sprint-start` Phase A (automatisch):
```bash
curl -s -H "Authorization: Bearer $ROADMAP_TOKEN" $ROADMAP_URL/verify | python3 -m json.tool
```
Bei Findings → SOFORT via PATCH bereinigen.

**`verify`** — Jederzeit (read-only): Gleicher Call wie oben. 5 Checks: Zombies, Misch-Sprints, max 5 Sprints, BLOCKED in Sprints, Zukunfts-Fristen in Sprints.

---

## Was "blockiert" bedeutet (EINZIGE Definition)

1. Abhaengigkeit-Feld beginnt mit `BLOCKED` (Format: `BLOCKED: [Grund]`)
2. Frist-Feld hat Datum in der Zukunft

Alles andere ist planbar. Horizont/Urgency blockieren NICHT.

---

## Sprint-Flow

```
/sprint-start Phase A  → GET /verify + GET /items
        │
     Execution (B–E)
        │
/sprint-retro Phase G  → POST /sync {current_sprint, done_ids, new_items, failed_sprint}
        │
        └→ Done-Items archiviert, nicht-erledigte sprint_nummer=null,
           neue Items ins Backlog, Counter inkrementiert.
```

---

## Verbote

- KEIN Full-Repack (nie alle Items anfassen)
- KEIN Reassign aller Items (nur bewegen was sich aendert)
- KEINE Loeschung — Done-Items = archived=true + status=done
