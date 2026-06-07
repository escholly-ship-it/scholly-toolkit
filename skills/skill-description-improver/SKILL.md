---
name: skill-description-improver
description: Eval-Pipeline fuer Skill-YAML-Frontmatter-Description. Optimiert Auto-Triggering durch LLM-getestete Description-Iteration. Trigger bei "skill description verbessern", "trigger optimieren", "skill eval", "frontmatter pass", "auto-triggering tunen". Sub-Skill von skill-creator (Anthropic Marketplace).
---

# /skill-description-improver — Skill-Description-Verbesserer

**Bezug:** Anthropic skill-creator (Marketplace) hat eingebauten Description-Improver. Sprint 262 (CC-SKILL-DESCRIPTION-IMPROVER): Anwendung auf 5 lokale Sprint-Skills (sprint-start, sprint-review, sprint-retro, deploy-verify, design-gate).

## Wann nutzen

- **Nach Skill-Creation:** initial Trigger-Description schreibt sich oft holprig
- **Bei Trigger-Drift:** Skill loest nicht aus obwohl User das passende Schluesselwort verwendet
- **Quartals-Pass:** Eval-Suite gegen 5-10 Test-Prompts

## Pipeline (5 Schritte)

### Step 1 — Eval-Test-Set anlegen

Pro Skill 5-10 Test-Prompts. Mix aus:
- **Trigger-Prompts** (sollten den Skill ausloesen) — z.B. fuer /sprint-start: "starte einen neuen sprint", "sprint zeremonie A", "ich starte sprint 262"
- **Skip-Prompts** (sollten den Skill NICHT ausloesen) — z.B. "wie geht es dir", "lies die backlog-datei"

### Step 2 — Baseline messen

LLM (claude --bare) gegen jedes Test-Prompt mit `Skill`-Tool sichtbar. Messen: Trigger-Hit-Rate (sollte 90%+ bei Trigger-Prompts und <10% bei Skip-Prompts).

### Step 3 — Description-Improver-Loop

LLM bekommt aktuelle Description + Eval-Failures. Generiert verbesserte Description. Re-Eval. Iteration bis Hit-Rate-Improvement <2% (Konvergenz).

### Step 4 — Output

Vorher/Nachher-Diff in `~/.claude/skills/[skill]/eval-results/<date>.md`. Frontmatter-Patch via Edit-Tool.

### Step 5 — Persist

PR mit Diff in claude-config-Repo, Commit-Message: "Skill description tuning [skill]: [hit-rate-before]→[hit-rate-after]".

## Sprint 262 Anwendung

5 Sprint-Skills:
1. `sprint-start` — Trigger-Prompts: "sprint zeremonie A", "starte sprint", "/sprint-start"
2. `sprint-review` — "sprint zeremonie E", "starte review", "/sprint-review"
3. `sprint-retro` — "sprint zeremonie F", "uebergabe", "/sprint-retro"
4. `deploy-verify` — "verify production deploy", "deploy ist drauf", "/deploy-verify"
5. `design-gate` — "design tool gate", "phase C visual", "/design-gate"

Jeweils 5 Trigger + 3 Skip-Prompts → Hit-Rate-Baseline + Improver-Loop.

## Helper-Skript (Stub)

`scripts/run-eval.sh` — Stub fuer manuell ausfuehrbaren Eval-Lauf. Volle Implementation via Anthropic skill-creator-Skill (siehe `Skill: anthropic-skills:skill-creator`).

## Cross-Reference

- `anthropic-skills:skill-creator` — Master-Tool fuer Eval+Description-Tuning
- Description-Cap 1024 Zeichen (siehe `~/.claude/skills/infrastruktur/references/quick-ref.md`)
