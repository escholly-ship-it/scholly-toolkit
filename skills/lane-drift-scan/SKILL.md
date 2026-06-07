---
name: lane-drift-scan
description: Scannt alle wiki/projects/*-backlog.md Files nach Lane-Drift (status=done Items die NICHT in _archived-log.md sind). Output Drift-Report (detection-only ab SV4). Trigger bei "lane drift", "drift scan", "unarchivierte items", "cleanup pass".
---

# Lane-Drift-Scanner

> Cross-projekt Drift-Detection (detection-only ab SV4 2026-05-26). Lehre aus 2026-05-22 claude-code-infra: 6 done-Items hatten sich angesammelt ohne Archive. Mit 16 Projekt-Backlog-Files steigt das Risiko.

## Was es macht

1. Scan `~/Cowork/wiki/projects/*-backlog.md`
2. Pro File: finde Items mit `status: done` im YAML-Block
3. Pro done-Item: prüfe ob entsprechender Eintrag in `_archived-log.md` existiert (per `## YYYY-MM-DD — <backlog_id>`)
4. Output: Drift-Report nach Projekt mit Drift-Counts (detection-only)
5. **Archivierung**: SV4 2026-05-26 — Archivierung erfolgt LLM-nativ via `/lane <name> auto-fix-all` Sub-Command (Pattern `lane_drift_unarchived` in triage-pattern-library.md). Kein eigener `--archive-all`-Modus mehr.

## Usage

```bash
# Scan-only
bash scripts/scan.sh
```

Archivierung via Lane-Skill-Sub-Command:
```
/lane claude-code-infra auto-fix-all
```

## Auto-Trigger

Hausmeister Phase 6 Quelle 5 ruft `scan.sh` täglich (scan-only ab SV4 2026-05-26). Wenn `drift_total > 5`: AUTO-F-Backlog-Item mit `horizont=BALD` + `fix_pattern_id: lane_drift_unarchived` + `auto_fixable: true`. Customer kann dann `/lane <name> auto-fix-all` aufrufen für LLM-nativen Auto-Fix.

## Cross-Refs

- Lane-Skill: `.claude/skills/lane/SKILL.md` (Sub-Command `auto-fix-all` LLM-nativ ab SV4)
- Pattern-Library: `wiki/references/triage-pattern-library.md` (Pattern `lane_drift_unarchived`)
- SV4-Plan-Akt: `outputs/deliveries/2026-05-26-plan-lane-sv4-auto-fix-pattern.md`
