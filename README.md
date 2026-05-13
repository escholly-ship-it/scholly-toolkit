# scholly-toolkit

Schollys Claude Code Marketplace — Sprint-Zeremonien (start/review/retro/sprint), Experten-Team als Agents, Enforcement-Hooks und Projekt-Tools.

## Nutzung in Cloud-Sessions (Sprint 291+)

Auto-Release via GitHub Actions. Bei jedem Push zu main wird `scholly-toolkit.zip` an die `latest`-Release angehaengt.

```bash
claude --plugin-url https://github.com/escholly-ship-it/scholly-toolkit/releases/latest/download/scholly-toolkit.zip
```

Cloud-Sessions ziehen damit automatisch die aktuelle Skill-Version. Kein manueller ZIP-Upload zu claude.ai/customize/skills mehr noetig.

## Lokal (Mac-Sessions)

Source-of-Truth ist `~/Cowork/scholly-toolkit/` (privates Cowork-Repo). Lokal sichtbar via `~/.claude/skills/<name>` Symlinks. Aenderungen werden per local-mirror-hook nach Cowork synced + per Push hier hin gespiegelt.

## Struktur

- `agents/` — Experten-Personas (backend-dev, content-stratege, devops, etc.)
- `hooks/` — Enforcement-Hooks fuer Sprint-Phasen
- `scripts/` — Plugin-Helper-Scripts
- `skills/` — Slash-Commands (sprint, start, deploy-verify, etc.)
- `.claude-plugin/` — Marketplace + Plugin-Manifests

## Status

Aktiv. Sprint 291 (2026-05-13) re-aktiviert nach Sprint-265-Deprecation. Auto-Release-Loop loest die manuelle ZIP-Upload-Last.
