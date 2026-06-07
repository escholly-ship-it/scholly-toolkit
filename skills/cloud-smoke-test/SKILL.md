---
name: cloud-smoke-test
description: 6-Punkte-Verifikation einer Claude Cloud-Session — pruefen ob /sprint-start + Personal Skills + Roadmap-API + Memory-Read + Bootstrap-Skript + PushNotification durchgehen. Trigger nach jedem Cloud-Bootstrap, vor Remote-First-Sprint, oder bei Cloud-Failure-Forensik.
model: haiku
---

# /cloud-smoke-test — Cloud-Session Smoke-Test

**Bezug:** `memory/sprint-262-cloud-fallback-plan.md` (Schollys 1000-Prozent-Sicherheits-Kriterien Sprint 262).

**Wann nutzen:**
- Nach Cloud-Bootstrap (`bash /workspace/cowork/scripts/cloud-bootstrap.sh`) zum Verifizieren ob alles greift
- Vor Sprint-Start in einer Cloud-Session (Phase A muss alle 6 Checks bestanden haben)
- Bei Failure-Postmortem (welcher Check ist gerissen)

## Die 6 Pflicht-Pruefungen

Jede Pruefung produziert: `OK`/`FAIL` + Diagnose-Output + Recovery-Kommando.

### Check 1 — Skill-Verfuegbarkeit im Slash-Menu

**Erwartung:** `/sprint-start` oder `anthropic-skills:sprint-start` erscheint im Slash-Menu von claude.ai/code.

**Wie pruefen:**
- Tippe `/` im Chat-Input
- Suche `sprint-start` in der Liste

**OK:** Skill sichtbar.
**FAIL:** Skill nicht in Liste.
**Diagnose:** Personal-Skill-Upload nicht greifbar oder Account-Sync-Verzug.
**Recovery:** 2 Min warten + neue Session starten. Wenn weiter nicht: Re-Upload via `claude.ai/customize/skills` + Browser-Refresh.

### Check 2 — Cloud-Bootstrap-Skript laeuft (PAT-frei seit Sprint 263)

**Erwartung:** `bash /workspace/cowork/scripts/cloud-bootstrap.sh` exit 0 + Helper-Wrapper `~/.cloud-bootstrap-env` angelegt + /api/memory-read End-to-End-Test bestanden.

**Wie pruefen:**
```bash
bash /workspace/cowork/scripts/cloud-bootstrap.sh; echo "exit=$?"
test -f ~/.cloud-bootstrap-env && source ~/.cloud-bootstrap-env && memory_read MEMORY.md | head -3
```

**OK:** exit 0 + Helper-Funktion `memory_read` liefert Top-Block von MEMORY.md.
**FAIL:** exit non-zero ODER memory_read leer.
**Diagnose:** ROADMAP_API_TOKEN fehlt in Cloud-ENV ODER /api/memory-read down.
**Recovery:** Token in Cloud-Environment-Settings pruefen (Variable `ROADMAP_API_TOKEN`). Falls fehlt: in claude.ai → Code → Cloud-Environment-Settings einsetzen + Session restart.

**HINWEIS:** Seit Sprint 263 wird KEIN claude-config mehr geclont. Memory + Skills + Hooks kommen lazy via `/api/memory-read` HTTP-Bridge. CLOUDE_GITHUB_TOKEN wird NICHT mehr benoetigt.

### Check 3 — Roadmap-API erreichbar

**Erwartung:** `/api/verify` antwortet HTTP 200 mit `globalSprint`-Wert.

**Wie pruefen:**
```bash
curl -sS -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
  https://roadmap-escholly-ship-its-projects.vercel.app/api/verify | head -5
```

**OK:** 200 OK + `globalSprint` im JSON.
**FAIL:** 401/403 (Token falsch) ODER 503 (Vercel-Outage).
**Diagnose:** Token-Setup falsch ODER Vercel-Deployment-Issue.
**Recovery:** 401 → `ROADMAP_API_TOKEN` in Cloud-ENV setzen. 503 → 5 Min warten.

### Check 4 — Memory-Files lesbar via /api/memory-read

**Erwartung:** 3 kritische Files via API erreichbar (MEMORY.md, verhaltensregeln.md, skills/sprint-start/SKILL.md).

**Wie pruefen:**
```bash
source ~/.cloud-bootstrap-env
memory_read MEMORY.md | head -3
memory_read verhaltensregeln.md | head -3
memory_read skills/sprint-start/SKILL.md | head -3
```
ODER direkt:
```bash
curl -sS -H "Authorization: Bearer $ROADMAP_API_TOKEN" \
  "$ROADMAP_API/api/memory-read?path=MEMORY.md" | head -3
```

**OK:** Alle 3 Files liefern Inhalt.
**FAIL:** 401 (Token falsch), 404 (Pfad falsch), 503 (Vercel-Outage).
**Diagnose:** Token oder Endpoint-Issue.
**Recovery:** ROADMAP_API_TOKEN ueberpruefen, Vercel-Status checken.

### Check 5 — `/sprint-start` Skill startet ohne Fehler

**Erwartung:** Skill durchlaeuft Phase A 1-7 (alle Phase-A-Marker).

**Wie pruefen:**
- Tippe `/sprint-start` in der Session
- Beobachte Skill-Output

**OK:** Skill laeuft Phase A komplett durch (Sprint-Ziel-Block am Ende).
**FAIL:** Permission-Error, Hook-Block, oder Timeout.
**Diagnose:** Hook-Migration nicht vollstaendig ODER Cloud-Skill-Bridge gerissen.
**Recovery:** Failure-Output kopieren + zu Mac-CLI wechseln (siehe `sprint-262-cloud-fallback-plan.md` Mac-CLI-Fallback-Pfad).

### Check 6 — PushNotification kommt durch

**Erwartung:** Sprint-Goal-Block-Push erscheint auf Mobile-App.

**Wie pruefen:**
- Sprint-Start-Block produziert PushNotification
- Mobile-App pruefen (Anthropic-App auf iOS/Android)

**OK:** Push erscheint.
**FAIL:** Kein Push nach 30 Sekunden.
**Diagnose:** Mobile-App-Token-Refresh oder Remote-Control-Pairing nicht aktiv.
**Recovery:** Mobile-App schliessen + neu oeffnen (Push-Token-Refresh). Falls weiter nichts: Sprint-Goal manuell im Chat sehen, Push-Verlust akzeptieren + AUTO-Item fuer Push-Diagnose.

## Output-Format

```
🧪 Cloud-Smoke-Test Sprint <N>
─────────────────────────────
Check 1: Skill-Slash-Menu       [OK / FAIL]
Check 2: Bootstrap-Skript       [OK / FAIL]
Check 3: Roadmap-API            [OK / FAIL]
Check 4: Memory-Files           [OK / FAIL]
Check 5: /sprint-start          [OK / FAIL]
Check 6: PushNotification       [OK / FAIL]
─────────────────────────────
Total: X/6 grun
```

**5/6 oder weniger:** Cloud-Sprint-Vehikel NICHT freigeben — Mac-CLI-Fallback bleibt Default.
**6/6 grun:** Eintrag in `cloud-smoke-test-results.md` (claude-config/memory/) mit Datum + Session-ID. Nach 3x 6/6 in unterschiedlichen Cloud-Sessions: Sprint N+1 darf REMOTE-FIRST starten.

## Helper-Skript

Lokal (Mac-CLI): `bash ~/Cowork/scholly-toolkit/skills/cloud-smoke-test/scripts/cloud-smoke-test.sh`
Cloud (claude.ai/code): `bash /workspace/cowork/scholly-toolkit/skills/cloud-smoke-test/scripts/cloud-smoke-test.sh`

Hinweis: Skript liegt im **cowork-Repo** (nicht claude-config), wird automatisch beim Anthropic-OAuth-Clone mitkopiert. Kein PAT noetig.

Das Skript fuehrt Checks 2-4 + 6 automatisch aus. Checks 1 + 5 sind interaktiv (User muss Slash-Menu sehen + Skill triggern).

## Cross-Reference

- `sprint-262-cloud-fallback-plan.md` — Schollys 7-Punkte-Sicherheitsliste
- `cloud-mode-skill-patterns.md` — 15 Cloud-Mode-Patterns fuer Skills
- `sprint-259-cloud-bootstrap.md` — Bootstrap-Skript-Doku
