---
name: deploy-verify
description: Production-Deployment verifizieren (Phase E Schritt 5) — Health-Check + visueller Test
argument-hint: [projekt-name]
---

# Production-Deployment Verifikation

**Projekt:** $ARGUMENTS

## Cloud-Mode (Sprint 257, CC-CLOUD-MIGRATION)

Cloud-Sessions koennen die volle Verifikation per API durchfuehren statt mit lokalem `git log` + `curl`:

```
POST /api/deploy-verify {
  project: "<projekt-name>",
  url: "https://<projekt>.vercel.app",
  expected_sha?: "<sha von letzter commit>"
}
```

Antwort enthaelt `{ok, health, status_code, elapsed_ms, body_preview, sha_match}`. Wenn `sha_match=false` ist der Deploy noch nicht durch — kurz warten + wiederholen.

Lokal: bestehender Block laeuft.

**Git-Status (lokal):** !`git log --oneline -3 2>/dev/null || echo "Kein Git-Repo"`

## Pflicht nach JEDEM git push der Auto-Deploy triggert (Regel 16)

### Bekannte Production-URLs
| Projekt | URL | Health-Endpoint |
|---------|-----|-----------------|
| Trainerbank | trainerbank.vercel.app | /api/health |
| Kaderplaner | kaderplaner.vercel.app | /api/health |
| Co-Trainer | trainingsplaner-lyart.vercel.app | /api/health |
| Cookmark | (wenn deployed) | /api/health |

### Verifikations-Schritte
1. **Warten** bis Vercel-Deployment abgeschlossen ist
2. **Health-Endpoint pruefen:** Production-URL + `/api/health` aufrufen → muss `status: ok` zurueckgeben
3. **Betroffene Seiten visuell pruefen:** WebFetch oder Browser, Mobile-Viewport (375x812)
4. **Bei Fehler:** SOFORT fixen, nicht auf naechste Session verschieben

### Branch-Alias-Lookup via vercel-mcp (CC-320, Sprint 242)

**Wenn der Push auf einen NICHT-main-Branch erfolgte, ist die Production-URL falsch — Vercel erstellt eine Branch-Preview-URL mit Alias.**

Statt zu raten oder zu warten:

```python
# Via mcp__0ff676dd-...__list_deployments oder get_deployment:
# 1. Letzte Deployment fuer das Projekt holen
# 2. Aus dem Deployment-Object 'aliases' und 'url' extrahieren
# 3. Den vom Branch generierten Alias bevorzugen (Format: <projekt>-git-<branch>-<team>.vercel.app)
```

**Bash-Fallback (ohne MCP):**

```bash
# vercel-CLI Alias-Lookup
PROJECT_NAME="<projekt>"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Vercel rendert Branch-Alias als: <project>-git-<branch>-<team>.vercel.app
# Slashes/Special-Chars in Branch-Name werden zu Bindestrichen normalisiert
SLUG=$(echo "$BRANCH" | sed 's|[/_]|-|g; s|[^a-zA-Z0-9-]||g' | tr '[:upper:]' '[:lower:]')
TEAM_SLUG="escholly-ship-its-projects"
ALIAS_URL="https://${PROJECT_NAME}-git-${SLUG}-${TEAM_SLUG}.vercel.app"
echo "Branch-Alias erwartet: $ALIAS_URL"

# Verifizieren via vercel CLI:
vercel ls "$PROJECT_NAME" --meta gitBranch="$BRANCH" 2>/dev/null | head -5
```

**Skill-Verhalten:**
- Bei main/master-Push → kanonische Production-URL aus Tabelle nutzen.
- Bei Branch-Push → Branch-Alias-Lookup via MCP oder Bash-Fallback, dann Health-Check gegen den Alias.
- Wenn der Alias `404` liefert → Deploy noch nicht durch, max 60s warten und retry (3x).
- Bei `403` (Vercel Team Protection): Cookie/Bypass-Token mitschicken oder Scholly-Bypass-Step.

### Wenn Deployment fehlschlaegt
- Vercel-Dashboard pruefen (Build-Logs)
- Scholly NUR informieren wenn der Fix nicht autonom moeglich ist
- DevOps-Experte ist verantwortlich fuer diesen gesamten Schritt

**Gilt fuer ALLE Projekte mit Auto-Deploy. Kein Sprint ist fertig ohne diesen Schritt.**

---

## Pre-Deploy-Gate: `vercel build` MUSS vor `vercel deploy` (Sprint 197 CC-228)

**Wenn Deployment via Vercel CLI direkt ausgefuehrt wird (nicht via git push → Auto-Deploy):**

```bash
# STOPP wenn vercel build lokal fehlschlaegt — kein deploy!
vercel build --prod && vercel deploy --prebuilt --prod
# Alternativ (explizite Build-Output-Pruefung):
vercel build --prod
BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
  echo "⛔ vercel build failed — KEIN vercel deploy."
  exit 1
fi
vercel deploy --prebuilt --prod
```

**Warum:** `vercel deploy` ohne vorherigen lokalen Build laedt broken Code in Vercel hoch → failed Deployment → Vercel-Error-Email an Scholly. Sprint 191 Incident.

**Verboten:**
- `vercel deploy` OHNE vorherigen erfolgreichen `vercel build`.
- Deploy-Retry ohne Build-Fehler-Diagnose.

**Ausnahme:** Bei git push → Vercel Auto-Deploy greift Vercel's eigener Build-Pipeline, keine lokale Pre-Build noetig. Der Gate gilt nur fuer direkte CLI-Deploys.

---

## Polling-Audit-Gate (Sprint 226 SMI-64-Incident)

**Wenn der Sprint Code in `src/components/` oder `src/hooks/` mit Polling-Patterns aendert (`setInterval`, SWR `refreshInterval`, EventSource), MUSS vor dem Deploy folgendes gepruft werden:**

```bash
# 1. Alle neuen Polling-Quellen finden
git diff main..HEAD -- 'src/' | grep -E "^\+.*setInterval|^\+.*refreshInterval"

# 2. Pro Pattern Frequenz pruefen
# Verbot im Hobby-Tier: alles unter 300_000ms (5min)
# Erlaubt: setTimeout(fn, 2_000) als Initial-Fetch (1x)

# 3. Cache-Header der getroffenen API-Routen pruefen
# Verbot: cache-control: no-store (default)
# Pflicht: s-maxage >= 300

# 4. CPU-Budget-Schaetzung
# Pro offenem Tab: <Frequenz_ms>/86400000 × Calls_per_Tick × 30 Tage
# Hobby-Quota: 4h Active CPU/Monat = 14.400 sek/Monat → bei 200ms/Call = 72.000 Calls/Monat
```

**Bei Verstoss STOPP:** Polling-Frequenz erhoehen, Cache-Header setzen, oder Architektur umstellen (Build-Time-Snapshot, ISR, Supabase Realtime). Erst dann Deploy.

**Cross-Tier-Trennung:** Kundenprojekte mit Polling MUESSEN in eigenes Vercel-Konto/Pro-Plan, nicht in Hobby-Mischpott (siehe Lehre Koerperschule KS-17).

**Faktum:** Vercel Hobby = 4h Active CPU/Monat fuer das gesamte Team. Bei 100% werden ALLE Projekte pausiert.
