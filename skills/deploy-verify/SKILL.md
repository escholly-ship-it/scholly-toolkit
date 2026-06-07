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

## Frame-Check VOR jedem Deploy-Verify (Lehre 2026-05-23 Token-Trust-Architecture)

**Erste Frage im Plan-Akt:** Ist das Vorhaben ein **Doktrin-Refactor**, ein **Pipeline-Deploy** oder **beides**?
- Bei "Doktrin-Refactor": Konsistenz-Check der Source-Dateien reicht.
- Bei "Pipeline-Deploy": Live-Target-Verify pflicht.
- Bei "beides" (typisch fuer Pivots): BEIDE Verify-Pfade muessen vor Klick-Anker-2 (Abnahme) gelaufen sein.

**Zweite Frage:** Welche Deploy-Topologie hat die geaenderte Komponente?
- Code im Web-App-Repo → Auto-Deploy via Git-Push (Vercel)
- Config-File einer Cloud-Routine → **MANUELLER Routinen-UI-Sync** + Test-Trigger (siehe Cloud-Routinen-Tabelle unten)
- Supabase-Schema → Manueller Supabase-CLI-Apply
- LaunchAgent / MCP-Server / Hook → Lokaler Restart + Verify

**Anti-Annahme-Default:** Source-Edit ≠ Live-Deploy. Bei jedem Pivot Source-vs-Live-Sync explizit verifizieren.

## Pflicht nach JEDEM git push der Auto-Deploy triggert (Regel 16)

### Bekannte Cloud-Routinen-Live-Targets (Anthropic claude.ai/code/routines)

Cloud-Routinen-Prompts leben im **claude.ai/code/routines-UI**, NICHT in den lokalen `managed-agents/*.json`-Dateien. JSON-Edits erreichen die Routine NICHT automatisch — manueller UI-Sync ist pflicht.

| Routine | Live-UI-URL | Source-of-Truth (NIE eine als Legacy markierte JSON) | Verify-Pfad |
|---|---|---|---|
| LinkedIn-Draft (Ghostwriting **v9**) | `https://claude.ai/code/routines/trig_01CRGQsB4zciwSGFLQmrkc8U` | **Live-Prompt IST Source-of-Truth** + `~/Cowork/memory/canonical-ghostwriting.md` (v9-Doktrin). `managed-agents/ghostwriting-agent.json` ist **v8-LEGACY — NICHT zum Sync/Diff verwenden** (sonst wird der v8-Prompt faelschlich ueber die aktive v9-Routine kopiert) | `RemoteTrigger.get` (oder Chrome-MCP) → Live-Prompt-Content gegen v9-Doktrin pruefen (Vier-Bewegungen, SR-V9, story-first/kein-Namens-Vorspann) → `RemoteTrigger.run` Test → SR-V9-Output + `routine_outcomes` pruefen |
| (weitere Cloud-Routinen ergaenzen sobald deployed) | | | |

**Verify-Sequenz fuer Cloud-Routinen-Edits (PFLICHT bei jedem System-Prompt-Touch):**

1. **Vor Edit:** `get_page_text` der Routinen-Detail-Seite → Backup des aktuellen Live-Prompts (fuer Rollback)
2. **Edit:** Edit-Pencil oben rechts → Cmd+A + Delete im Instructions-Textarea → pbcopy Source → Cmd+V → Save
3. **Nach Edit Verify-Pass:** Routinen-Detail-Seite reload → Instructions-Header gegen die **Source-of-Truth-Spalte** diffen (NIE gegen eine als v8-Legacy markierte JSON — sonst wird ein veralteter Prompt ueber die aktive Routine kopiert), mindestens erste 3 Zeilen + letzte Lessons-Sektion
4. **Test-Trigger:** `Run now` Button → Live-Session in neuem Tab oeffnen
5. **Frueh-Diagnostik Stage 1.5:** Falls Pipeline mehrstufig — pruefen ob fruehe Stages der neuen Doktrin folgen (z.B. v8 Coin-Flip vs v7 Tier-Scan)
6. **Bei Schwellenbruch:** Rollback auf Live-Prompt-Backup, Forensik dokumentieren, ERST DANN re-iterieren

### Bekannte Production-URLs (Vercel)
| Projekt | URL | Health-Endpoint |
|---------|-----|-----------------|
| Trainerbank | trainerbank.vercel.app | /api/health |
| Kaderplaner | kaderplaner.vercel.app | /api/health |
| Co-Trainer | trainingsplaner-lyart.vercel.app | /api/health |
| Cookmark | (wenn deployed) | /api/health |
| Ghostwriting-Dashboard | ghostwriting-dashboard.vercel.app | /api/health |

**Anti-Pattern (Codex-Review-Lehre 2026-05-23, PR #113):** **POST-Endpoints mit Side-Effects sind KEINE Health-Endpoints.** Beispiel `ghostwriting-dashboard/api/draft-insert` — POST-only, schreibt in Supabase. GET dagegen scheitert (falsches Negativ), POST gegen Production wuerde bei jedem Health-Check einen Draft einfuegen. Health-Endpoint-Auswahl-Kriterien: **idempotent + GET + statusless + ohne DB-Writes.** Wenn der einzige existierende API-Endpoint mutierend ist, einen `/api/health` dedizierten GET-Endpoint nachruesten statt den mutierenden zu missbrauchen. Cross-Ref: persona devops "Erlerntes Wissen" 2026-05-23.

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

---

## 🔍 4c-Action-Verify-Matrix (Sprint 270 Block B — Anti-Annahme-Pattern)

**PFLICHT bei JEDER Scholly-Action im Deploy-Workflow.** Wenn der Skill Scholly um eine manuelle Aktion bittet, darf er NICHT annehmen dass die Aktion fehlerlos ausgefuehrt wurde. Maschinelle Verifikation pflicht.

### Action-Verify-Matrix (deploy-relevante Actions)

| Scholly-Action im Deploy | Maschinelle Verifikation | Loop-Verhalten |
|--------------------------|--------------------------|----------------|
| **Vercel-Env-Var setzen** | `vercel env ls --scope=<team>` ODER curl gegen Endpoint der Var nutzt → Response 200 mit erwartetem Body | Loop bis 200, max 5 Versuche je 10s |
| **Vercel Team-Protection-Bypass** | curl mit `?_vercel_share=<token>` → 200 vs 401 | Bei 401: Bypass-Token von Scholly anfordern |
| **Vercel Custom-Domain DNS** | `dig +short <domain>` → Vercel-IP/CNAME erscheint | Loop bis DNS-Propagation, max 60s |
| **GitHub-Secret/Setting** | `gh secret list --repo <org/repo>` ODER `gh api repos/<org>/<repo>/environments/<env>` | One-shot, kein Loop |
| **Branch-Protection-Rule** | `gh api repos/<org>/<repo>/branches/<br>/protection` → erwartete Required-Status-Checks | One-shot |
| **Health-Endpoint live nach Deploy** | curl /api/health → status:ok | Loop bis 200 oder 60s Timeout |
| **App-Settings auf Mac (z.B. Vercel CLI Login)** | `vercel whoami` → User korrekt | One-shot |
| **iPhone-Notification (Deploy-Failure-Alert)** | PushNotification proaktiv senden + Telegram-Antwort abwarten | Loop bis Antwort, max 2 Min |

### Generischer Loop-Pattern

```bash
verify_action() {
  local DESC="$1"      # z.B. "Vercel-Env-Var TELEGRAM_BOT_TOKEN"
  local CMD="$2"       # z.B. "vercel env ls | grep TELEGRAM_BOT_TOKEN"
  local EXPECT="$3"    # z.B. "Production"
  local MAX_TRIES="${4:-5}"
  local SLEEP="${5:-10}"

  for i in $(seq 1 $MAX_TRIES); do
    OUTPUT=$(eval "$CMD" 2>&1)
    if echo "$OUTPUT" | grep -q "$EXPECT"; then
      echo "  ✅ $DESC verifiziert (Versuch $i)"
      return 0
    fi
    [ "$i" = "$MAX_TRIES" ] && break
    echo "  ⏳ $DESC noch nicht verifiziert (Versuch $i/$MAX_TRIES), warte ${SLEEP}s..."
    sleep "$SLEEP"
  done

  echo "  ❌ $DESC NICHT verifiziert nach $MAX_TRIES Versuchen — Scholly fragen oder Gap dokumentieren"
  return 1
}
```

### Anti-Annahme-Prinzip

- Wenn Verify-Methode existiert → IMMER ausfuehren, nie vertrauen.
- Wenn Verify-Methode fehlt → Scholly fragen + Gap im Deploy-Verify-Output dokumentieren.
- KEIN Skill-Skript darf "Scholly hat es gemacht" annehmen ohne Verify-Bestaetigung.

### UI-Text-Verify — DOM-Volltext statt accessibility tree (Sprint 294)

**Pflicht-Pfad fuer "ist Text/Heading/Marker auf Seite":**

```js
// Browser-MCP evaluate (Playwright/Chrome) — primaer
document.body.innerText.match(/<pattern>/g)?.length >= <erwartete_anzahl>
```

**Fallback nur bei JS-Blockade** (CSP, OAuth-Wall, iframe-cross-origin):
- `find(text=...)` / `snapshot()` / `get_page_text()` — und WARUM-Begruendung in Verify-Output.

**Grund:** `find()` arbeitet auf accessibility tree. Custom-Components droppen ARIA-roles + Tree-Provider capped bei >500 Nodes → falsch-negativ trotz vorhandenem DOM-Inhalt. `innerText` liest gerenderten DOM-Text, unabhaengig von Rolle/Cap.

**Inzident-Quelle:** Sprint 270 Phase 3 (2026-05-07 16:50) — `find()` not-found fuer ZIP-Verify-Loop heading, `innerText.match` 4 Matches. Methodik-Praezisierung statt Anti-Pattern-Repeat.

### Cross-Ref

- Master-Doc: `memory/refactor-architektur-sprint-refactor-1.md` (Block B Action-Verify-Matrix kanonisch)
- Generischer Pattern in /close Schritt 4c (Pre-Gate verifiziert Phase-3-Artifact)
- Token-Onboarding Skill nutzt gleiche Matrix fuer Token-Aktionen
