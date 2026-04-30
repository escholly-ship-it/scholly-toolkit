---
name: go
description: End-of-task completion — E2E-Tests ausfuehren, /simplify aufrufen, Pull-Request erstellen. Nutzen wenn Scholly "go" oder "abschluss" sagt oder ein Sprint-Item technisch fertig ist und in eine PR muss. Default-Flow fuer Code-Projekte (Web-Apps, Skills, Scripts) mit Git-Backend.
---

# /go — End-of-Task Completion Pipeline

**Zweck:** Ein-Kommando-Abschluss fuer Code-Arbeit. Inspiriert von Boris Cherny's `/go` (Anthropic-intern, Threads DXM_ATcD8QP).

**3-stufiger Flow:**
1. **E2E** — Tests ausfuehren (Playwright CLI / project-specific)
2. **SIMPLIFY** — `/simplify` Skill aufrufen (Review + Auto-Fix)
3. **PR** — `gh pr create` mit Template

**Guardrails:** Nicht-destruktiv. Keine force-push. Keine --no-verify. Commits + Branches bleiben erhalten auch bei Fehler.

---

## Schritt 0 — Precheck (PFLICHT)

```bash
# 1. Working tree clean?
git status --porcelain | head -5
# Wenn nicht leer: STOPP, Scholly fragen ob Uncommitted Changes gewollt sind

# 2. Welcher Branch?
CURRENT_BRANCH=$(git branch --show-current)
# Wenn main/master: STOPP, Feature-Branch anlegen oder abbrechen

# 3. Tests verfuegbar?
if [ -f package.json ]; then
  TEST_CMD=$(node -pe "require('./package.json').scripts?.['test:e2e'] || require('./package.json').scripts?.test || ''")
  echo "Test-Command: $TEST_CMD"
fi

# 4. gh CLI authed?
gh auth status 2>&1 | head -1
```

Bei FAILURE: im Chat 1 Satz erklaeren, STOPP.

---

## Schritt 1 — E2E-Tests

**Projekt-spezifisch. Heuristik:**

```bash
# Next.js / Node.js Web-Apps
if [ -f package.json ]; then
  if grep -q '"test:e2e"' package.json; then
    npm run test:e2e
  elif grep -q '"test"' package.json; then
    npm test
  else
    # CC-324 (Sprint 234): STOPP statt silent skip bei fehlenden Tests
    # Skip-Pfad nur ueber explizite Override (--no-tests / --skip-tests / SPRINT_TYPE=prozess)
    if [ "${SPRINT_TYPE:-}" = "prozess" ] || [ "${SPRINT_TYPE:-}" = "memory-only" ] || [ "${GO_NO_TESTS:-}" = "1" ]; then
      echo "ℹ️  Keine Test-Scripts — Stage 1 auto-skip (Prozess-/Memory-Sprint oder --no-tests)"
    else
      echo ""
      echo "❌ STOPP: Keine Test-Scripts in package.json gefunden."
      echo "   /go gibt false sense of security wenn keine Tests laufen."
      echo "   Cross-Ref: CC-321 (Test-Setup-Backlog), CC-322 (Meta-Regel Test-Persistenz)."
      echo ""
      echo "   Optionen:"
      echo "   1. Test-Setup nachholen (siehe CC-321 / CC-334a Pilot-Pattern)"
      echo "   2. /go --no-tests (Doku-Only-Change, Override)"
      echo "   3. SPRINT_TYPE=prozess setzen (.sprint-phases-Datei)"
      exit 1
    fi
  fi

# Python Projekte
elif [ -f pyproject.toml ] || [ -f setup.py ]; then
  pytest || pytest-cov || python -m unittest discover
fi

# Skill/Hook/Config-Only (kein Test-Target)
# → Stage 1 skip, aber shellcheck/yaml-lint wenn verfuegbar
```

**CC-324 (Sprint 234) — STOPP statt silent skip:** Bei fehlenden Test-Scripts in `package.json` gibt `/go` einen STOPP aus statt stillschweigend zu überspringen. Override per `/go --no-tests` (Doku-Only) oder `SPRINT_TYPE=prozess` in `.sprint-phases`.

**Bei Failure:** Tests-Output zeigen, STOPP. User entscheidet: fix oder skip mit `/go --skip-tests`.

**Selector-Standard (2026):** `data-testid > role > text > CSS`. Wenn Tests auf CSS-Selector basieren → Folge-Item "Selector-Migration" anlegen.

**Playwright Agents** (planner/generator/healer) — wenn verfuegbar im Projekt, fuer dynamische Test-Generation nutzen. Nicht im MVP.

---

## Schritt 2 — /simplify

Aufruf via Skill-Tool:

```
Skill(skill="simplify")
```

`/simplify` reviewed die Diff zum main-branch (oder base-branch) und fixt/flagged:
- Unused imports/variables
- Dead code
- Over-engineering (unnecessary abstractions)
- Unnecessary error handling
- Comments die WHAT beschreiben statt WHY

**Output:** Liste der Fixes. User kann approven oder einzelne rejecten.

---

## Schritt 3 — Pull Request

```bash
# Branch push
git push -u origin $CURRENT_BRANCH

# PR create
LAST_COMMIT=$(git log -1 --pretty=%s)
PR_URL=$(gh pr create --title "$LAST_COMMIT" --body "$(cat <<'EOF'
## Summary
<Auto-gefuellt aus git log seit base-branch — 1-3 Bullets>

## Test plan
- [ ] E2E-Tests gruen (via /go)
- [ ] /simplify Review passed
- [ ] Manueller Test: <Task-spezifisch>

🤖 Generated with [Claude Code](https://claude.com/claude-code) via /go
EOF
)")
PR_NUM=$(gh pr view --json number -q .number)
```

**Nie:**
- `--no-verify` (Hooks respektieren)
- `--force-push` (Kommitte statt rewrite)
- direkt auf `main` pushen

---

## Schritt 3b — AUTO-MERGE (Sprint 195 CC-238, PFLICHT)

**Regel 41 + feedback_pr_merge_selbst.md:** Nach `gh pr create` folgt IMMER sofort Merge — kein Scholly-Ask.

```bash
# Prechecks (technische Blocker, nicht Scholly-Delegation)
MERGE_STATUS=$(gh pr view $PR_NUM --json mergeStateStatus,mergeable -q '"\(.mergeStateStatus)/\(.mergeable)"')
# "CLEAN/MERGEABLE" → merge
# Sonst → Fehler mit konkreter Evidenz an User, NICHT "warte auf dein merged"

if [ "$MERGE_STATUS" = "CLEAN/MERGEABLE" ]; then
  gh pr merge $PR_NUM --squash --delete-branch
  git fetch origin
  git checkout main && git pull
  echo "✅ Merged + main aktualisiert"
else
  echo "⛔ Merge nicht automatisch moeglich: $MERGE_STATUS"
  # Hier konkrete Fehlerbehebung, NICHT Scholly fragen
fi
```

**Verboten in diesem Schritt:**
- "Warten auf Scholly-Merge"
- "Du musst reviewn und mergen"
- Merge-Ask an Scholly als Abnahme-Kriterium formulieren

**Nur echte Blocker eskalieren:**
- GitHub Branch-Protection mit Required-Reviews → `gh api repos/OWNER/REPO/branches/main/protection` zeigt Policy
- CI-Checks failing → Checks fixen, nicht delegieren
- Merge-Conflict → rebase + push, dann retry

---

## Schritt 4 — Production-Verifikation (neu Sprint 195)

**Standard-Pfad (git push → Vercel Auto-Deploy):**
```bash
sleep 60  # Vercel-Deploy-Wartezeit
# curl auf Production-URL mit erwartetem Ergebnis
# Screenshot / HTTP-Code / Response-Body als Evidenz
```

**Alternativ-Pfad (direkter Vercel-CLI-Deploy — Sprint 197 CC-228 Pre-Deploy-Gate):**
Wenn statt git push explizit `vercel deploy` genutzt wird (z.B. Prototyp ohne Git-Auto-Deploy), GILT der Pre-Deploy-Gate aus `/deploy-verify`:
```bash
vercel build --prod || { echo "⛔ vercel build failed — KEIN deploy"; exit 1; }
vercel deploy --prebuilt --prod
```
Nie `vercel deploy` ohne erfolgreichen `vercel build` davor — Sprint 191 Incident (Vercel-Error-Emails an Scholly).

---

## Schritt 5 — Report

Einzeiliger Status an User (Evidenz-basiert, kein Merge-Ask):
```
✅ /go done: Merged PR #<N> → Production live <URL> (E2E: 12/12 | Simplify: 3 fixes | Prod-curl: 200)
```

---

## Varianten

- `/go --skip-tests` — Stage 1 uebersprungen (z.B. Doku-Only-Change)
- `/go --skip-simplify` — Stage 2 uebersprungen
- `/go --no-pr` — Commit + Push aber keine PR (Draft-Modus)
- `/go --draft` — PR als Draft erstellt

---

## Projekt-Spezialisierungen (Future)

- **Trainerbank/Kaderplaner:** Playwright-Agents-Trio fuer dynamische Tests
- **Roadmap-Tool:** Supabase-Migrationen in Stage 2 validieren
- **Cookmark/Watchlist:** Lighthouse CI + a11y axe-core

Als Folge-Items bei Bedarf anlegen.

---

## Sources & References

- Boris Cherny Threads DXM_ATcD8QP (Anthropic) — /go-Pattern
- Playwright Agents: https://shipyard.build/blog/playwright-agents-claude-code/
- QA-Engineer Persona Weiterbildung Sprint 163 — Skills-Pipeline-Pattern
