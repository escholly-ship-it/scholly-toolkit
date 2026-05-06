# DevOps Quick-Reference

Aus `experte-devops.md` extrahiert (Sprint 262 CC-SKILL-EXPERTEN-TOP5). Volle Details in der Persona.

## Health-Endpoint-Pattern

```typescript
// /api/health route
export async function GET() {
  return Response.json({
    status: "ok",
    sha: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7),
    deployedAt: process.env.VERCEL_DEPLOYMENT_AT,
  });
}
```

Pflicht in jedem Production-Projekt. Verifikation nach Push: `curl <prod>/api/health | jq .sha` muss neuen SHA zeigen.

## Better Stack Monitor

- 3-Min-Interval-Pings auf `/api/health`
- Bei 3× Fehlversuch: Incident
- Sprint 262 Update: Telegram-Push aus Bash-Scripts entfernt — Better Stack Heartbeat-Outage ist primaerer Alert-Pfad

## Vercel Hobby-Tier

- **Quota:** 4h Active CPU pro Monat (alle Projekte teilen sich die Quota)
- **Bei 75% Auslastung:** Polling-Quellen pruefen (`grep setInterval` mit <300_000ms)
- **SMI-64-Lehre (Sprint 226):** Static-Polling auf Roadmap/Trainerbank/Kaderplaner verbrennt CPU. Loesung: ISR + Manual-Refresh + 5min-CDN-Cache.

## Supabase Cutover-Pattern

- Edge Functions Cutover Pattern (CC-313 Sprint 247): 7-Tage Vercel-Routes als Safety-Net (CC-314)
- Migration: alte API behalten + parallel laufen lassen + Verify in Prod + Old-API archivieren

## GHA-Workflow-Pattern (Sprint 248-258 Cloud-Migration)

- **IANA Cron:** `cron: "0 6 * * *"` mit `TZ: Europe/Berlin` direkt im Step
- **OIDC:** `permissions: id-token: write` fuer Cloud-Deploys
- **Custom Properties:** Repo-Properties als Filter
- **Skip via Issue Comment:** `if: !contains(github.event.issue.labels.*.name, 'skip-ci')`

## Sprint 262 Production-Touch-Heuristik (CC-236)

Prod-Touch = ja wenn:
- Item beruehrt `~/projects/*`-Files
- `git push`, `vercel deploy`, Supabase-Migration, `launchctl bootstrap`, Env-Var-Rotation
- Live-API-Endpoint-Aenderung mit Traffic

Prod-Touch = nein bei:
- Skill-/Hook-/Memory-/Prozess-Arbeit in `~/.claude/`
- Backlog-Verdichtung, forensische Items
