---
name: update-check
description: Claude Code-Plattform-Updates scannen und gegen Welt-V2-Filter bewerten. Trigger bei "plattform update", "release notes check", "neue Claude-Features", "was hat Anthropic gerade rausgebracht", "cli changelog scan", "f24 check". Liest CLI-Changelog + Doku-Diff + Plugin-Marketplace-Updates, bewertet jede Änderung gegen 17 Filter, schreibt Output nach outputs/anthropic-update-reports/.
model: sonnet
effort: medium
---

# Update Check (F24)

> Wöchentliche Pflicht-Mechanik: Plattform veröffentlicht Updates → wir prüfen Relevanz für Welt-V2 + leiten Migrations-Items ab.

## Was du tust

1. **CLI-Version + Changelog holen:**
   ```bash
   claude --version
   curl -sL "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md" | head -200
   ```

2. **Doku-Diff prüfen:**
   ```bash
   curl -sL "https://docs.claude.com/en/release-notes/claude-code" 2>/dev/null
   curl -sL "https://code.claude.com/docs/en/sub-agents" 2>/dev/null | head -100
   ```

3. **Plugin-Marketplace-Updates:**
   ```bash
   ls -lt ~/.claude/plugins/marketplaces/*/CHANGELOG* 2>/dev/null
   ```

4. **Pro Änderung bewerten** gegen 17 Filter aus [.claude/rules/filters.md](../../../.claude/rules/filters.md):
   - Macht sie uns abhängig von einem Eigenbau, den Anthropic jetzt nativ macht?
   - Reduziert sie Token-Budget?
   - Verbessert sie Fehler-Oberfläche?
   - Anthropic-Native + Remote-First erfüllt?

5. **Lebende Page aktualisieren:**
   `wiki/references/anthropic-features.md` — neue Features in "Verfügbar, aber noch nicht genutzt"

6. **Migrations-Items ableiten** falls Eigenbau ersetzbar:
   - Eintrag in `wiki/references/anthropic-features.md` Tabelle "Eigenbau → Native Mapping"
   - Backlog-Item in `wiki/projects/claude-code-infra/backlog.md` (oder passendem Projekt)

7. **Report schreiben:**
   `outputs/anthropic-update-reports/[yyyy-mm-dd].md` mit:
   - Versions-Diff (alt → neu)
   - Filter-Bewertung pro relevante Änderung
   - Empfohlene Migrations-Items
   - Push-Notification bei Major-Findings

## Trigger-Phrasen

- "anthropic update check"
- "was hat Anthropic gerade rausgebracht"
- "neue Claude-Features"
- "F24 check"
- Cloud-Routine wöchentlich (Sonntag 06:00 UTC, geplant Phase G)

## Output-Format

```markdown
# Update Check — [datum]

## Versions-Diff
- CLI: 2.1.X → 2.1.Y
- Desktop-Bundle: X → Y

## Major-Findings
- [feature] — relevant für [f-nummer], ersetzt [eigenbau]
  - Filter-Bewertung: ...
  - Empfohlenes Migrations-Item: ...

## Minor-Findings
- ...

## Action-Items
- [ ] Migrations-Item X anlegen in claude-code-infra-Lane
- [ ] anthropic-features.md aktualisieren
- [ ] CUSTOMER-MANUAL.md prüfen wenn Workflow betroffen
```

## Cross-Refs

- Lebende Page: [wiki/references/anthropic-features.md](../../../projects/-Users-scholly/wiki/references/anthropic-features.md)
- 17 Filter: [.claude/rules/filters.md](../../../.claude/rules/filters.md)
- Workflow: [.claude/rules/workflow.md](../../../.claude/rules/workflow.md)
- CUSTOMER-MANUAL: [wiki/CUSTOMER-MANUAL.md](../../../projects/-Users-scholly/wiki/CUSTOMER-MANUAL.md)
