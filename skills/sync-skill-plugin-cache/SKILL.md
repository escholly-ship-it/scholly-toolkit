---
name: sync-skill-plugin-cache
description: Plugin-Cache-Hygiene fuer ~/.claude/plugins/cache/. Identifiziert und entfernt verwaiste Plugin-Versionen (Verzeichnisse mit .orphaned_at-Marker). Default Dry-Run. Nutzen bei Plugin-Cache-Drift (siehe CC-242) oder wenn Phase-A-Checks Waisen melden.
---

# sync-skill-plugin-cache

Hygiene-Skill fuer den Claude-Plugin-Cache unter `~/.claude/plugins/cache/`.

## Warum

Claude Code laesst bei Plugin-Updates alte Versionen mit einem `.orphaned_at`-Marker liegen. Ueber Zeit sammeln sich dutzende verwaiste Verzeichnisse — Sprint 211 Phase-A hat 58 Stueck gemeldet. Dieser Skill liefert einen wiederholbaren Dry-Run + Execute-Flow, damit die Bereinigung reproduzierbar und sicher ist.

## Ausfuehren

```bash
# Dry-Run (Default) — listet Waisen, loescht nichts
bash ~/.claude/skills/sync-skill-plugin-cache/run.sh

# Tatsaechlich loeschen (nach Dry-Run-Review)
bash ~/.claude/skills/sync-skill-plugin-cache/run.sh --execute

# Nur aelter als N Tage (Default: 14)
bash ~/.claude/skills/sync-skill-plugin-cache/run.sh --min-age-days 7
```

## Wie erkannt wird

- Jede Plugin-Version liegt unter `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
- Eine Datei `.orphaned_at` mit Unix-Millisekunden-Timestamp markiert eine Waise.
- Der Skill listet alle Waisen mit Alter (Tage) + Groesse; `--execute` entfernt sie mit `rm -rf`.

## Sicherheit

- Default Dry-Run — keine Loeschung ohne `--execute`.
- Nur Verzeichnisse mit `.orphaned_at`-Marker kommen infrage (nie aktive Plugin-Versionen).
- `--min-age-days` (Default 14) verhindert Loeschen frisch verwaister Versionen.
- `--dry-run`-Ausgabe zeigt vollen Pfad + Alter + Groesse — vor `--execute` sichten.

## Einsatz-Matrix

| Projekt | Wann nutzen |
|---------|-------------|
| Claude Code Prozess | Phase-A-Check meldet Waisen (plugin-cache Report > 0) |
| Jedes andere Projekt | Niemals — rein Claude-Code-seitig |

## Trigger-Kriterien

- Phase-A `phase-a-checks.py plugin-cache` meldet > 20 Waisen
- Manueller `du -sh ~/.claude/plugins/cache/` > 2 GB
- Nach groesserem Plugin-Upgrade-Schub (mehrere Marketplaces neu gezogen)

## Anti-Patterns

- Kein Dry-Run vor `--execute`
- Waisen loeschen die aktuell noch genutzt werden (darf nicht vorkommen, weil `.orphaned_at` nur bei Release gesetzt wird — aber `--min-age-days` schuetzt zusaetzlich)
- Direktes `rm -rf ~/.claude/plugins/cache/` — dieser Skill existiert genau um das zu vermeiden

## Integration in Sprint-Zeremonien

- **Phase A:** `phase-a-checks.py plugin-cache` laeuft ohnehin. Bei Report > 0 diesen Skill als Todo aufnehmen.
- **Phase E/G:** Nach groesseren Plugin-Aenderungen einmal `--dry-run` zur Kontrolle.
