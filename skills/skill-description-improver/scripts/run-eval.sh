#!/bin/bash
# run-eval.sh — Stub fuer Skill-Description-Eval (Sprint 262 CC-SKILL-DESCRIPTION-IMPROVER)
# Ruft Anthropic skill-creator-Skill auf fuer den vollen Eval-Lauf.
#
# Usage: bash run-eval.sh <skill-name> [--prompt-set FILE]

SKILL="$1"
PROMPT_SET="${2:-default}"

if [ -z "$SKILL" ]; then
  echo "Usage: bash run-eval.sh <skill-name>"
  echo
  echo "Available 5 Sprint-Skills fuer Sprint-262-Pass:"
  echo "  - sprint-start"
  echo "  - sprint-review"
  echo "  - sprint-retro"
  echo "  - deploy-verify"
  echo "  - design-gate"
  exit 1
fi

SKILL_PATH="$HOME/.claude/skills/$SKILL/SKILL.md"
[ -f "$SKILL_PATH" ] || { echo "Skill $SKILL nicht gefunden ($SKILL_PATH)"; exit 1; }

echo "🧪 Skill-Description-Eval: $SKILL"
echo "Pfad: $SKILL_PATH"
echo
echo "Aktuelle Description:"
awk '/^description:/{flag=1} /^---$/{if(flag){flag=0}} flag{print}' "$SKILL_PATH" | head -5
echo
echo "Volle Eval-Pipeline ueber Anthropic skill-creator:"
echo "  In Claude-Session: 'Skill: anthropic-skills:skill-creator' aufrufen"
echo "  Dann: 'Eval the description for skill $SKILL'"
echo
echo "Output landet in: $HOME/.claude/skills/$SKILL/eval-results/"
