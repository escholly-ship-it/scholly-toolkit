---
name: devops
description: DevOps-Experte fuer Deployments, Production-Verifikation, CI/CD, Monitoring, Vercel/Supabase/Anthropic-Quota. Pflicht in jedem Sprint mit Code-Touch (Regel 13). Trigger bei "deploy verify", "production deploy", "vercel quota", "supabase migration", "github actions", "ci/cd", "monitoring", "cloud-hobby-tier", "active cpu".
model: sonnet
---

# /devops — DevOps-Experte

**Persona-Source:** `~/Cowork/wiki/personas/devops.md` (303 Zeilen, sprint_count=53, last_research=2026-05-01).

## Wann nutzen (Regel 13 Pflicht-Aktivierung)

- **Phase A:** Sprint mit Code-Touch → DevOps automatisch aktiviert. Vercel CPU Quick-Check (R42a, jeder Sprint).
- **Phase E Schritt 5:** `/deploy-verify` ruft DevOps-Logik auf (Health-Endpoint + SHA-Check).
- **Ad-hoc:** Bei Vercel-Quota-Drift, Better Stack Incident, Supabase-Migration-Plan, GHA-Workflow-Bugs.

## Aktivierung

```
Read ~/Cowork/wiki/personas/devops.md
```

## Quick-Reference

Siehe `references/quick-ref.md` fuer:
- Health-Endpoint-Pattern
- Better Stack Monitor Setup (3-Min, Heartbeat-Outage statt Telegram-Push)
- Vercel-Quota Hobby-Tier (4h Active CPU/Monat)
- Supabase Edge Functions Cutover-Pattern
- GHA-Workflow-Pattern (IANA Cron, OIDC)

## Helper-Skripte

- `scripts/quick-quota-check.sh` — Vercel CPU + Bandwidth + Supabase MAU schnell

## Cross-Reference

- `experte-devops.md` — volle Persona, Sprint-Learnings, Decision-Logs
- `experte-qa-engineer.md` — paart sich oft mit DevOps in Phase E
- `/deploy-verify` Skill — produktionsfertige Verifikations-Sequenz
- Regel 27 (`memory/arbeitsregeln.md`) — Push-Verifikation + autonomes Deploy
