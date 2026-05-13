# Sprint 262 — Eval-Prompts fuer 5 Sprint-Skills (CC-SKILL-DESCRIPTION-IMPROVER)

Test-Set fuer Description-Improver-Loop. Jeweils 5 Trigger + 3 Skip Prompts.

## sprint-start

**Trigger-Prompts (sollte ausloesen):**
1. "starte einen neuen sprint"
2. "/sprint-start"
3. "sprint zeremonie phase a"
4. "ich starte sprint 263"
5. "wir machen sprint-start"

**Skip-Prompts (sollte NICHT ausloesen):**
1. "wie geht es dir heute"
2. "lies die backlog-claude-code.md"
3. "zeig mir den sprint-status" (ist Read, nicht Skill)

## sprint-review

**Trigger:**
1. "phase E starten"
2. "/sprint-review"
3. "sprint review zeremonie"
4. "qualitaetssicherung phase e"
5. "kunden-abnahme erteilen"

**Skip:**
1. "review this code"
2. "design review"
3. "die letzte commit-message reviewen"

## sprint-retro

**Trigger:**
1. "/sprint-retro"
2. "uebergabe machen"
3. "phase f und g"
4. "gute nacht"
5. "wir hoeren auf"

**Skip:**
1. "retrospektive aus dem buch xy"
2. "rueckblick auf 2025"
3. "memory aufraeumen" (-> KM-Skill)

## deploy-verify

**Trigger:**
1. "/deploy-verify"
2. "verify production deploy"
3. "deploy ist drauf, pruef nach"
4. "phase e schritt 5"
5. "production verifikation"

**Skip:**
1. "deploy einrichten" (-> /devops)
2. "lokal verifizieren"
3. "git push"

## design-gate

**Trigger:**
1. "/design-gate"
2. "design tool gate"
3. "phase c visual prep"
4. "claude design needed?"
5. "stitch oder claude design?"

**Skip:**
1. "wie sieht das aus" (UI-Frage)
2. "design system review" (-> design:design-system)
3. "screenshot machen"

## Eval-Ausfuehrung

```bash
# Pro Skill:
bash ~/.claude/skills/skill-description-improver/scripts/run-eval.sh <skill-name>
# Volle Pipeline via Anthropic skill-creator:
Skill: anthropic-skills:skill-creator
> Eval the description for <skill-name> using ~/.claude/skills/skill-description-improver/references/sprint-262-eval-prompts.md
```

Sprint-262-Ergebnis: 5 Hit-Rate-Reports in `eval-results/<skill>/2026-05-04-baseline.md`. Description-Patches als PR.
