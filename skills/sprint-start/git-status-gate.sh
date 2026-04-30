#!/bin/bash
# CC-237 (Sprint 208) + CC-259 (Sprint 211): Phase-A git-status-Gate mit AUTO-COMMIT.
#
# Sprint 211 Refactor: 3-Optionen-Frage an Scholly entfernt. Bei dirty Code-Repos
# wird AUTOMATISCH committet + gepusht (Regel 22/34/41, feedback_pr_merge_selbst).
# Exit 0 = clean ODER auto-commit erfolgreich. Exit 1 nur bei echten Git-Fehlern.
#
# Scope:
#   - ~/projects/*        — alle Projekt-Repos (strict)
#   - ~/.claude/          — nur Code-Pfade (hooks, skills, agents, settings, CLAUDE.md, memory)
#   - ~/Cowork/           — nur Code-Pfade (scripts, agents, tasks, mcp-servers)
# Runtime-Drift (cache/, logs/, heartbeat, pid-files) wird IGNORIERT.

set -u

SPRINT_GLOBAL=$(cat ~/Cowork/.sprint-global 2>/dev/null || echo "?")
COMMIT_MSG="Sprint ${SPRINT_GLOBAL} Phase A auto-commit: pending code+memory sync

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

CODE_PATHS_CLAUDE='^(hooks/|skills/|agents/|commands/|CLAUDE.md|settings.json|plugins/config.json|projects/-Users-scholly/memory/)'
CODE_PATHS_COWORK='^(scripts/|agents/|tasks/|mcp-servers/|content/linkedin/[^q].*|README.md|CLAUDE.md)'

AUTO_COMMITTED=()
GIT_ERRORS=()

auto_commit_strict() {
  # ~/projects/*: alles adden
  local repo="$1"
  [ -d "$repo/.git" ] || return 0
  local porcelain
  porcelain=$(cd "$repo" && git status --porcelain 2>/dev/null)
  [ -z "$porcelain" ] && return 0

  local count
  count=$(echo "$porcelain" | wc -l | tr -d ' ')
  local push_output
  if ! push_output=$(cd "$repo" && git add -A && git commit -m "$COMMIT_MSG" 2>&1 && git push 2>&1); then
    GIT_ERRORS+=("$repo|$push_output")
    return 1
  fi
  AUTO_COMMITTED+=("$repo|$count")
}

auto_commit_filtered() {
  # ~/.claude, ~/Cowork: nur Code-Pfade adden
  local repo="$1"
  local pattern="$2"
  [ -d "$repo/.git" ] || return 0
  local files
  files=$(cd "$repo" && git status --porcelain 2>/dev/null | awk '{print substr($0,4)}' | grep -E "$pattern" || true)
  [ -z "$files" ] && return 0

  local count
  count=$(echo "$files" | wc -l | tr -d ' ')
  # Files zeilenweise an `git add` uebergeben
  local push_output
  if ! push_output=$(cd "$repo" && echo "$files" | xargs -I{} git add "{}" 2>&1 && git commit -m "$COMMIT_MSG" 2>&1 && git push 2>&1); then
    GIT_ERRORS+=("$repo|$push_output")
    return 1
  fi
  AUTO_COMMITTED+=("$repo|$count")
}

# 1) ~/projects/* (strict)
if [ -d "$HOME/projects" ]; then
  for project in "$HOME/projects"/*/; do
    auto_commit_strict "${project%/}"
  done
fi

# 2) ~/.claude/ (filtered)
auto_commit_filtered "$HOME/.claude" "$CODE_PATHS_CLAUDE"

# 3) ~/Cowork/ (filtered)
auto_commit_filtered "$HOME/Cowork" "$CODE_PATHS_COWORK"

if [ ${#GIT_ERRORS[@]} -gt 0 ]; then
  echo "🛑 GIT-STATUS-GATE: Git-Fehler in ${#GIT_ERRORS[@]} Repo(s) — Root-Cause fixen:"
  for entry in "${GIT_ERRORS[@]}"; do
    repo="${entry%%|*}"
    msg="${entry#*|}"
    echo "  → $repo"
    echo "$msg" | sed 's/^/      /' | head -10
  done
  exit 1
fi

if [ ${#AUTO_COMMITTED[@]} -eq 0 ]; then
  echo "✅ Git-Status-Gate: alle Code-Repos clean."
  exit 0
fi

echo "✅ Git-Status-Gate: Auto-Commit+Push in ${#AUTO_COMMITTED[@]} Repo(s):"
for entry in "${AUTO_COMMITTED[@]}"; do
  repo="${entry%%|*}"
  count="${entry#*|}"
  echo "  → $repo ($count Datei(en) committed + gepusht)"
done
exit 0
