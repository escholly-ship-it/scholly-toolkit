# Infrastruktur Quick-Reference

Aus `experte-infrastruktur.md` (Sprint 262 CC-SKILL-EXPERTEN-TOP5).

## Hook v2.1.85+ if-Feld

```json
{
  "matcher": "Bash",
  "if": "tool_input.command contains 'rm -rf'",
  "command": "echo 'destructive' && exit 1"
}
```
Conditional-Filtering: Hook feuert nur wenn `if`-Bedingung true. Reduziert Hook-Rauschen.

## GHA Cron 2026

- **IANA Cron:** `cron: "0 6 * * *"` mit `TZ: Europe/Berlin` direkt im Step
- **OIDC:** `permissions: id-token: write` fuer Cloud-Deploys
- **Custom Properties:** Repo-Properties als Filter (`runs-on: properties[my-prop] == 'value'`)
- **Parallel Steps:** Job-Parallelisierung via `strategy: matrix:`

## SKILL.md YAML Frontmatter Description-Cap

- **Maximum 1024 Zeichen** in `description:` (Anthropic Eval-Pattern)
- Trigger-Worte explizit auflisten (verbessert Auto-Triggering)
- Skip-Cases ebenfalls dokumentieren wenn relevant

## Managed Agents Beta (managed-agents-2026-04-01)

- Endpoints: `agents`, `environments`, `sessions`
- Vault-Credentials: MCP-only, `vault_ids` per Session
- Scheduling: braucht Wrapper (Routines machen den Cron)

## LaunchAgent vs GHA-Cron Decision

| Kriterium | LaunchAgent (lokal) | GHA-Cron (cloud) |
|-----------|---------------------|------------------|
| Mac muss an sein | JA | NEIN |
| Sub-Sekunden-Latenz | gut | schlecht (bis 60s Verzug) |
| Mac-Permissions | volle TCC-Reichweite | nein (TCC-frei) |
| Anthropic Token | nutzt Mac-Login | braucht eigenen API-Key |
| Cost | gratis | gratis fuer public Repos |

**Sprint 248-258 Cloud-Migration:** A-rated → GHA, B-rated → Hybrid, C-rated → bleibt LaunchAgent.

## Sprint 262 Hook-Cleanup

Soft-Move statt Hard-Delete: `~/.claude/hooks/archive-cloud-sprint262/` (git-history bleibt). Nach 30d stabil → physisches Loeschen.
