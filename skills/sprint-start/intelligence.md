# Claude Intelligence Check fuer /sprint-start

Ausgelagert aus `SKILL.md` in Sprint 152 (CC-99). Wird per Read nachgeladen.

---

## 7a) Quick-Check (JEDER Sprint)

1. `claude --version` ausfuehren
2. Version mit letztem bekannten Stand vergleichen — bei Major-Aenderung WARNING

## 7b) Intelligence-Datei lesen (JEDER Sprint)

Die Dream Engine Morning (taeglich 06:30) prueft autonom:
- Threads @claudeai
- Anthropic Blog
- Changelog
- SDK-Versionen
- GitHub Issues
- Feature-Detection (AutoDream/Conway/Echo)

Ergebnisse stehen in `memory/reference-claude-intelligence.md`.

**Schritte:**
1. Datei lesen
2. "Aktuelle Findings" Tabelle anzeigen — nur Eintraege die NEU seit letztem Sprint sind
3. Zugehoerige Backlog-Items referenzieren
4. Offene Kategorie-C-Findings (Scholly-Entscheidung) hervorheben
5. Findings-Tracker (`memory/findings-tracker.md`) auf ueberfaellige Items pruefen

**Marker:** `echo done > $MARKERS_DIR/a-version`
