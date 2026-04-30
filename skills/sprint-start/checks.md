# Periodische Checks fuer /sprint-start

Ausgelagert aus `SKILL.md` in Sprint 152 (CC-99). Konsolidiert auf 3 Zyklen in Sprint 153 (CC-100).
Wird per Read nachgeladen wenn faellig.

**Konsolidierungs-Historie (CC-100, Sprint 153):** 5 Zyklen (%1, %3, %5, %10, %13) → 3 Zyklen (%1, %3, %13).
- Dream Engine Status (ex-%5) in %3 als Heartbeat aufgegangen — Dream Engine laeuft ohnehin taeglich via LaunchAgent.
- Meta-Review (ex-%10) in %13 DevOps-Checkpoint integriert — beides sind Quartals-Artefakte.

---

## Zyklus 1: JEDEN Sprint (%1)

### 1a) Retro-Rotation (letzte 20 Sprints behalten)

```bash
cd ~/.claude/projects/-Users-scholly/memory && \
CURRENT=$(cat ~/Cowork/.sprint-global) && \
CUTOFF=$((CURRENT - 20)) && \
CUTOFF_LINE=$(grep -n "^## Sprint $CUTOFF " retros.md 2>/dev/null | head -1 | cut -d: -f1) && \
if [ -n "$CUTOFF_LINE" ] && [ "$CUTOFF_LINE" -gt 5 ]; then \
  ARCHIVE_FILE="archive/retros-before-sprint-$((CUTOFF+1)).md" && \
  sed -n "${CUTOFF_LINE},\$p" retros.md >> "$ARCHIVE_FILE" && \
  head -$((CUTOFF_LINE - 1)) retros.md > retros_tmp.md && \
  mv retros_tmp.md retros.md && \
  echo "✅ Retros rotiert: Sprints < $((CUTOFF+1)) archiviert ($(wc -l < "$ARCHIVE_FILE") Zeilen)"; \
else \
  echo "✅ Retros aktuell — keine Rotation noetig"; \
fi
```

### 1b) Routines Drift-Check (CC-173, Sprint 179)

```bash
bash ~/.claude/projects/-Users-scholly/memory/routines-drift-check.sh
```

Exit 1 → neuer Runner aktiv ohne Inventar-Eintrag ODER Inventar-Eintrag ohne Runner. Inventar (`memory/scheduled-tasks-inventar.md`) aktualisieren.
Fuer Kategorie 2 (Web-Routines) + Kategorie 3 (MCP-Tasks) zusaetzlich im MCP-Kontext (nicht aus Bash erreichbar): `RemoteTrigger(action:'list')` und `mcp__scheduled-tasks__list_scheduled_tasks`.

### 1c) Auto-Trigger-Findings pruefen (CC-9)

```bash
if [ -f ~/.claude/projects/-Users-scholly/memory/meta-review-findings.md ]; then
  echo "⚠️ META-REVIEW FINDINGS VORHANDEN — Lies memory/meta-review-findings.md und wandle kritische Findings in CC-Items um!"
  cat ~/.claude/projects/-Users-scholly/memory/meta-review-findings.md | head -20
else
  echo "✅ Keine offenen Meta-Review Findings"
fi
```

---

## Zyklus 2: Alle 3 Sprints (%3)

### 2a) Memory Health-Check

```bash
GLOBAL=$(cat ~/Cowork/.sprint-global)
if (( GLOBAL % 3 == 0 )); then
  echo "📊 Memory Health-Check FAELLIG (Sprint $GLOBAL)"
  bash ~/.claude/projects/-Users-scholly/memory/memory-health.sh 2>/dev/null || echo "⚠️ memory-health.sh nicht gefunden"
else
  echo "Memory Health: Baseline $(cat ~/Cowork/.quality-baseline 2>/dev/null || echo '?')% (letzter Check: Sprint $((GLOBAL - GLOBAL % 3)))"
fi
```

### 2b) Memory Quality Gate (Regel 51 — nur bei gelaufenem Health-Check)

Wenn `GLOBAL % 3 == 0`:

1. **ROT-Assets pruefen:** Aktiviert? → STOPP + verdichten. Nicht aktiviert? → Warning + Backlog-Item.
2. **GELB-Assets pruefen:** In diesem Sprint genutzt? → Verdichtung in Phase F.
3. **Composite Score gegen Baseline vergleichen** (aus `~/Cowork/.quality-baseline`):
   - Gesunken >5 Punkte? → Warning im Chat
   - Unter 75%? → Naechster Sprint MUSS Verdichtungs-Sprint sein
   - Unter 55%? → STOPP Feature-Arbeit
4. **Baseline-Datei wird automatisch vom Health-Check aktualisiert.**

### 2c) Claude Design API/MCP Release-Check (CC-150, seit Sprint 169)

```bash
if (( $(cat ~/Cowork/.sprint-global) % 3 == 0 )); then
  echo "🔎 Claude Design Release-Check (CC-150)"
  # Feature-Detection: API-Endpoint erreichbar? MCP-Paket publiziert?
  API_STATUS=$(curl -sfo /dev/null -w "%{http_code}" -m 5 https://api.anthropic.com/v1/design 2>/dev/null || echo "000")
  MCP_PKG=$(npm view @anthropic-ai/claude-design-mcp version 2>/dev/null | head -1)
  if [ "$API_STATUS" != "000" ] && [ "$API_STATUS" != "404" ]; then
    echo "🚨 Claude Design API antwortet ($API_STATUS) — CC-150 ausloesen: Ghostwriting-Runner + INFRA-API-WATCH entbloecken."
  elif [ -n "$MCP_PKG" ]; then
    echo "🚨 Claude Design MCP verfuegbar (v$MCP_PKG) — CC-150 ausloesen: MCP in ~/Cowork/mcp-servers/ installieren, Ghostwriting-Runner migrieren."
  else
    echo "✅ Claude Design noch Web-UI-only — next check in 3 Sprints."
  fi
fi
```

Bei Release-Signal: Scholly sofort informieren + CC-150 in Phase G auf Done, neue Item-Kette fuer Migration anlegen (Ghostwriting-Runner, INFRA-API-WATCH, Persona-Update).

### 2d) Dream Engine Heartbeat (ex-%5, merged Sprint 153 — CC-100)

```bash
if (( $(cat ~/Cowork/.sprint-global) % 3 == 0 )); then
  # Dream Engine laeuft taeglich als LaunchAgent (com.cowork.dream-engine).
  # Hier nur Heartbeat: Hat der LaunchAgent in den letzten 48h geloggt? Kein Status-Replay — nur Alive-Check.
  DREAM_LOG="/tmp/cowork-dream-engine.log"
  if [ -f "$DREAM_LOG" ]; then
    AGE_H=$(( ($(date +%s) - $(stat -f %m "$DREAM_LOG")) / 3600 ))
    if [ $AGE_H -gt 48 ]; then
      echo "⚠️ Dream Engine letzter Log-Write $AGE_H Stunden alt — LaunchAgent pruefen (launchctl list | grep dream-engine)"
    else
      echo "✅ Dream Engine Heartbeat OK (letzter Log-Write vor $AGE_H h)"
    fi
  else
    echo "⚠️ Kein Dream Engine Log gefunden ($DREAM_LOG) — LaunchAgent pruefen"
  fi
fi
```

---

## Zyklus 3: Alle 13 Sprints (%13) — Quartal

### 3a) DevOps Sprint-Start-Checkpoint

```bash
GLOBAL=$(cat ~/Cowork/.sprint-global)
if (( GLOBAL % 13 == 0 )); then
  echo "📋 DevOps-Checkpoint FAELLIG (Sprint $GLOBAL, quartalsweise)"
  # Vollstaendiger Checkpoint:
  # - [ ] Notion-Zeilen SSV Apps: noch <5.000?
  # - [ ] Cookmark-Nutzer: noch <100?
  # - [ ] Vercel Bandwidth: noch <70 GB/mo?
  # - [ ] Axiom Datasets: noch <2 belegt?
  # - [ ] Supabase Free aktiv?
  # - [ ] Offene INFRA-Items mit hoeherer Prio?
  # - [ ] Sicherheits-Updates noetig?
else
  echo "DevOps-Checkpoint nicht faellig (naechster: Sprint $((GLOBAL + 13 - GLOBAL % 13)))"
fi
```

**Marker IMMER setzen** — Semantik: "geprueft/nicht faellig", nicht "durchgefuehrt":
```bash
echo done > $MARKERS_DIR/a-devops
```

### 3b) Meta-Review (ex-%10, merged Sprint 153 — CC-100)

Wenn `GLOBAL % 13 == 0`:
```bash
bash ~/.claude/projects/-Users-scholly/memory/meta-review.sh --auto-trigger
```
Ergebnis im Chat zeigen. Bei CRITICAL Findings → Scholly informieren + Backlog-Items erzeugen.
Bei Nicht-13-Sprints: OPTIONAL (wenn Teamleiter Bedarf sieht).

**Begruendung fuer Merge von %10 in %13 (CC-100):** Meta-Review und DevOps-Checkpoint sind beide Quartals-Reviews mit Langzeitperspektive. Getrennte Zyklen (10 vs 13) erzeugten asynchrone Quartale. Gekoppelt auf %13 ergibt klare Quartals-Kadenz (Sprint 13, 26, 39, ...) — ein gemeinsamer Langzeit-Puls.
