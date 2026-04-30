# scholly-toolkit

Schollys privater Plugin-Marketplace fuer Claude Code — Sprint-Zeremonien, Experten-Team, Enforcement-Hooks und Projekt-Management.

## Inhalt

- **Skills (10)** — `/sprint-start`, `/sprint-review`, `/sprint-retro`, `/deploy-verify`, `/design-gate`, `/roadmap`, `/go`, `/ghostwriting-pipeline`, `/claude-design-to-nextjs`, `/sync-skill-plugin-cache`
- **Agents (16)** — DevOps, Knowledge-Manager, Infrastruktur, Frontend-Dev, Backend-Dev, QA-Engineer, UX-Researcher, UX-UI, Visual-Designer, Content-Copy, Content-Stratege, Daten-Engineer, Datenanalyst, Infografik-Designer, Buchhaltung, Freelance-Business
- **Hooks** — Phase-Gate, Tech-Debt-Gate, Pre-Abnahme-Gate, Pre-Push-Vercel-Verify, Auto-Notification, etc.

## Installation

### Lokal (Verzeichnis-Marketplace)

```bash
# Plugin-Marketplace anlegen
claude plugin add-marketplace ~/Cowork/scholly-toolkit
claude plugin install scholly-toolkit
```

### Cloud (GitHub-Marketplace, Sprint 254 CLOUD-P4)

```bash
# Cloud-Sessions oder lokale Sessions
claude plugin add-marketplace github:escholly-ship-it/scholly-toolkit
claude plugin install scholly-toolkit
```

## Workflow-Modell — Sprint-Zeremonien

7 Phasen, strikt sequentiell:

A) `/sprint-start` → B) Ideation → C) Planning (+`/design-gate`) → D) Execution → E) `/sprint-review` (+`/deploy-verify`) → F+G) `/sprint-retro`

Details siehe SKILL.md pro Skill + Agent-Persona pro Experte.

## Cross-Ref

- **Sprint-Prozess-Doku:** `~/.claude/CLAUDE.md` (lokal) bzw. `escholly-ship-it/claude-config/CLAUDE.md`
- **Memory-Architektur:** `escholly-ship-it/claude-config` Repo
- **Cloud-Migration:** Sprint 254 (CC-CLOUD-MIGRATION + CLOUD-MASTER)

## Status

Sprint 254 (2026-04-30): Marketplace published von `~/Cowork/scholly-toolkit/` als eigenes GitHub-Repo. Ermoeglicht Cloud-Sessions auf claude.ai/code, das Toolkit als Plugin-Marketplace einzubinden ohne Filesystem-Source-Pfad.

## Maintainer

Torsten Schollmayer · escholly@gmail.com · escholly-ship-it Org

Lokales Repo (Source): siehe `~/Cowork/scholly-toolkit/` im cowork-Repo. GitHub-Repo (dieses) ist eine published-Spiegelung fuer Cloud-Marketplace-Use.
