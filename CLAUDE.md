# scholly-toolkit — Sub-Modul-CLAUDE.md

> Toolbox für projekt-spezifische Skills + Scripts + Helpers. Wird On-Demand geladen wenn Claude Files in diesem Subdir liest. Welt-V2-Adapt-Pattern (Anthropic-Native Sub-Directory-Loading).

## Was hier lebt

- `skills/` — projekt-spezifische Skills (claude-design-to-nextjs, deploy-verify, roadmap). Via Symlink in `Cowork/.claude/skills/` als Project-Scope sichtbar.
- `scripts/` — Toolkit-Bash-Helpers (NICHT zu verwechseln mit `Cowork/scripts/` = Cron-Runner).

## Konventionen

- **Sprache:** Python 3.10+ (stdlib only wo möglich, sonst `uv`/`uvx`). Bash für Hook-Wrapper.
- **Skills-Format:** SKILL.md mit YAML-Frontmatter (`name`, `description`, optional `argument-hint`). Mehr als 5k Zeichen → Splitten.
- **Naming:** kebab-case für Skill-Slugs.
- **Backlog-Sync:** Alle Backlog-Writes LLM-nativ via Read + Append-Edit der `claude-config/projects/-Users-scholly/wiki/projects/<slug>-backlog.md`-File (SV4 Cut-Over 2026-05-26 — kein Bash-Skript-Aufruf mehr, keine Roadmap-API). Auto-Fix-Modus für Backlog-Items mit `auto_fixable: true` via Sub-Command `/lane <name> auto-fix-all` (LLM-nativ ab SV4, max 5 Fixes/Run, confidence ≥ 0.7).

## Build/Test

- Keine Build-Step nötig (Skills sind Markdown).
- Tests: `bats Cowork/scripts/tests/*.bats` (vom Cowork-Root aufrufen), `uvx pytest Cowork/hooks/tests/`.

## Cross-Refs

- Cowork-Root-Anweisungen: `/Users/scholly/Cowork/CLAUDE.md`
- Globale Skills (universal): `/Users/scholly/.claude/skills/`
- Welt-V2 Wiki: `/Users/scholly/Cowork/wiki/`
