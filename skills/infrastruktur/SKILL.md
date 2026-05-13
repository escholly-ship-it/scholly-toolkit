---
name: infrastruktur
description: Infrastruktur-Experte fuer Hosting, MCP-Server, LaunchAgents, DNS, Env-Vars, GHA-Cron-Migrationen, Routinen-Architektur. Pflicht bei Prozess-/Config-Aenderungen (Regel 13). Trigger bei "launchagent", "mcp server", "github actions cron", "env-var", "dns", "hosting", "routine migration", "skill setup", "hook setup", "settings.json".
---

# /infrastruktur — Infrastruktur-Experte

**Persona-Source:** `~/.claude/projects/-Users-scholly/memory/experte-infrastruktur.md` (282 Zeilen, sprint_count=42, last_research=2026-04-27).

## Wann nutzen

- **Prozess-/Config-Aenderungen:** settings.json, hooks, MCP-Server-Setup
- **Routinen-Architektur:** LaunchAgents (lokal) vs GHA-Cron (cloud)
- **Cloud-Migration:** Hook → Skill-Inline, LaunchAgent → GHA-Workflow

## Aktivierung

```
Read ~/.claude/projects/-Users-scholly/memory/experte-infrastruktur.md
```

## Quick-Reference

Siehe `references/quick-ref.md` fuer:
- Hook v2.1.85 if-Feld Conditional Filtering
- GHA Cron IANA + OIDC + Custom Properties
- Skills SKILL.md YAML Frontmatter Description-Cap
- Managed Agents Beta-Header + Vault-Credentials
- LaunchAgent vs GHA Decision-Tree

## Cross-Reference

- Regel 9 (`memory/arbeitsregeln.md`) — LaunchAgents Pflicht fuer Routinen
- `experte-infrastruktur.md` — volle Persona
- `cloud-compat-hook-inventory.md` — Hook-Migrations-Tabelle
