# scholly-toolkit ⚠️ DEPRECATED

> **DEPRECATED ab 2026-05-06 (Sprint 265).**
> Dieser Repo ist nicht mehr der primaere Distributions-Pfad fuer Cloud-Sessions.

## Warum deprecated?

Nach dem Token-Leak-Postmortem (Sprint 261, 2026-05-01) wurde die Cloud-Architektur grundlegend umgebaut:

**Vorher (was dieser Repo bediente):**
- Cloud-Sessions installierten Plugin via `github:escholly-ship-it/scholly-toolkit` Marketplace
- Brauchte Push-Token + Sync-Mechanismus zwischen `~/Cowork/scholly-toolkit/` und diesem Repo
- Manuelle Pflege des Plugin-Marketplace-Repos

**Nachher (aktuelle Architektur, ab Sprint 259):**
- Cloud-Bootstrap-Setup-Script clont `escholly-ship-it/cowork` direkt via `CLOUDE_GITHUB_TOKEN` (Fine-grained PAT, **read-only**, 90 Tage Expiration)
- Cloud-Session sieht damit DIREKT `/workspace/cowork/scholly-toolkit/skills/` — alle Skills automatisch da
- Kein separates Marketplace-Repo noetig
- Schreib-Token bewusst nicht eingerichtet (Sicherheits-Haertung)

## Wo ist die echte Source?

**Source-of-Truth:** `~/Cowork/scholly-toolkit/skills/` (lokal) — gespiegelt nach `https://github.com/escholly-ship-it/cowork` Subtree `scholly-toolkit/`.

**Cloud-Pfad:** Bootstrap-Setup-Script (Memory: `sprint-259-cloud-bootstrap-prompt.md`) clont cowork → Skills sind nach `/workspace/cowork/scholly-toolkit/skills/` verfuegbar.

## Stand dieses Repos

Letzter Sync war Sprint 265 (2026-05-06) als die Architektur noch nicht final korrigiert war — entspricht damit teilweise dem Source-of-Truth-Stand vom 2026-05-06 (16 Skills + sprint-planning + plugin.json v1.1.0). Es gibt **keinen Auto-Sync mehr** — bei Bedarf manueller Push.

## Cross-Refs

- **Aktuelle Cloud-Architektur:** `escholly-ship-it/claude-config` Memory `sprint-259-cloud-bootstrap-prompt.md`
- **Token-Leak-Postmortem:** `escholly-ship-it/claude-config` Memory `incident-2026-05-01-token-leak-postmortem.md`
- **Sprint 265 Liefer-Doku:** `escholly-ship-it/claude-config` Memory `sprint-265-skills-cloud-distribution.md`

## Maintainer

Torsten Schollmayer · escholly@gmail.com · escholly-ship-it Org
