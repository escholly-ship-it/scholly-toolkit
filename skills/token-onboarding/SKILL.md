---
name: token-onboarding
description: Sicheres Onboarding neuer API-Tokens via macOS Keychain — keine Klartext-Tokens im Chat, keine Tokens in .env-Dateien, keine Tokens in Git.
---

# Token-Onboarding Skill (CC-263-TOKEN-ONBOARDING)

Wenn Scholly einen neuen Token (API-Key, Bearer-Token, OAuth-Secret, …) liefert,
**niemals** im Chat stehen lassen, **niemals** in eine `.env`/`.envrc`/`config.*`
schreiben, sondern in den **macOS Keychain** ablegen — dort liegen die
existierenden Tokens (ROADMAP_API_TOKEN, TELEGRAM_BOT_TOKEN, NOTION_TOKEN,
ANTHROPIC_API_KEY, …) ohnehin schon.

## Trigger

Aktiviere diesen Skill, sobald:
- Scholly schreibt: "hier ist mein Token", "neuer API-Key", "speicher das mal"
- Eine ENV-Variable mit `*_TOKEN`, `*_KEY`, `*_SECRET` neu auftaucht
- Ein Tool/Service zum ersten Mal authentifiziert werden soll

## Workflow

1. **Stoppe sofort.** Antworte: "Token nicht hier reinschreiben — ich lege ihn
   in die Keychain. Welcher Service/Tool-Name?" (Falls Scholly den Token schon
   eingefuegt hat: ihn als unsicher markieren und um Rotation bitten.)

2. **Service-Name festlegen.** Format: `scholly.<service>` — z.B.
   `scholly.openai`, `scholly.notion`, `scholly.linear`. Account-Name = ENV-Var,
   z.B. `OPENAI_API_KEY`.

3. **Helper aus `scripts/token-onboarding.sh` nutzen:**
   ```bash
   source ~/Cowork/scholly-toolkit/skills/token-onboarding/scripts/token-onboarding.sh
   keychain_set scholly.openai OPENAI_API_KEY
   # → liest Token von stdin (read -s), schreibt in Keychain, kein Echo
   ```

4. **Verifikation.** Sofort `keychain_get scholly.openai OPENAI_API_KEY | head -c 8`
   ausfuehren um zu zeigen dass der Token abrufbar ist (nur die ersten 8 Zeichen,
   der Rest bleibt geheim).

5. **Eintrag in `~/.cloud-bootstrap-env`** (falls Cloud-Sessions ihn brauchen):
   die Bootstrap-Skripte lesen Tokens aus Keychain und exportieren sie nur fuer
   die Dauer der Session.

6. **NIE in Git.** Pre-Commit-Hook `secrets-scan` prueft auf API-Keys — wenn er
   triggered, sofort History bereinigen + Token rotieren.

## Helper-Funktionen (bash)

| Funktion | Zweck |
|----------|-------|
| `keychain_set <service> <account>` | Token von stdin lesen (`read -s`), in Keychain ablegen. |
| `keychain_get <service> <account>` | Token aus Keychain holen, auf stdout. |
| `keychain_list` | Alle `scholly.*` Eintraege auflisten (nur Service+Account, keine Werte). |
| `keychain_delete <service> <account>` | Eintrag entfernen (z.B. nach Rotation). |

## Sicherheitsregeln

- **NIE** Tokens in Chat-Verlaeufen wiederholen oder zitieren.
- **NIE** Tokens als Bash-Argument uebergeben (`security add-generic-password -w "$TOKEN"`)
  — sie landen im History-File. Stattdessen `read -s` + heredoc/`-w -` mit stdin.
- **NIE** Tokens loggen — auch nicht "zur Verifikation". Nur die ersten 6-8
  Zeichen sind erlaubt fuer Sanity-Checks.
- **CLOUD-MODE.** Cloud-Sessions koennen `security` nicht aufrufen. Sie holen
  Tokens via Mac-Bridge aus dem Keychain und exportieren sie nur in den
  Session-Env. Dieser Skill ist deshalb primaer fuer Mac-CLI-Sessions —
  Cloud-Sessions sehen die Tokens schon ueber das Bootstrap.

## Cloud-Mode Bridge

In Cloud-Sessions ist `security` nicht verfuegbar. Tokens werden ueber den
Roadmap-API-Endpoint `/api/keychain-bridge` (geplant CLOUD-P3) bzw.
ueber das Bootstrap-Skript geliefert. Dieser Skill triggert in Cloud-Mode
die folgende Anweisung an Scholly: **"Token in Mac-CLI-Session via
`keychain_set` ablegen — Cloud-Sessions koennen erst nach naechstem Bootstrap
darauf zugreifen."**

---

## 🔍 4c-Action-Verify-Matrix (Sprint 270 Block B — Anti-Annahme-Pattern)

**PFLICHT bei JEDER Scholly-Action im Token-Lifecycle.** Wenn der Skill Scholly um eine manuelle Aktion bittet (Token via Keychain, BotFather, Vercel-Env, GitHub-Secret), darf er NICHT annehmen dass die Aktion fehlerlos ausgefuehrt wurde. Maschinelle Verifikation pflicht.

### Action-Verify-Matrix (token-relevante Actions)

| Scholly-Action mit Token | Maschinelle Verifikation | Loop-Verhalten |
|--------------------------|--------------------------|----------------|
| **Token in macOS Keychain abgelegt** | `security find-generic-password -s scholly.<service> -a <ACCOUNT>` → exit 0 | One-shot, max 1 Retry |
| **Token von BotFather neu geholt (Telegram)** | curl `https://api.telegram.org/bot<TOKEN>/getMe` → 200 mit `{"ok":true,"result":{"username":...}}` | Loop bis 200, max 5x |
| **Token in Vercel Env-Var (Production)** | `vercel env ls --scope=<team> -t <api-token>` → grep <var-name> in Production | Loop bis vorhanden |
| **Token in GitHub Repo-Secret** | `gh secret list --repo <org>/<repo>` → grep <var-name> | One-shot |
| **Token in GitHub Org-Secret** | `gh api orgs/<org>/actions/secrets` → grep | One-shot |
| **Token in `~/.cloud-bootstrap-env`** | `grep -q "^export <VAR>=" ~/.cloud-bootstrap-env && [ -n "$(eval "echo \\$$VAR")" ]` | One-shot |
| **Token gegen Vendor-Endpoint testen** | curl Endpoint mit `Authorization: Bearer <token>` → 200 vs 401/403 differenzieren | Loop bis 200, max 3x |
| **Token rotiert (alt soll nicht mehr funktionieren)** | curl Endpoint mit ALTEM Token → 401 erwartet (NICHT 200) | One-shot, fail wenn 200 |

### Generischer Loop-Pattern (analog deploy-verify Skill)

```bash
verify_token_action() {
  local DESC="$1"      # z.B. "Telegram-Bot-Token via BotFather"
  local CMD="$2"       # z.B. "curl -sS https://api.telegram.org/bot$TG/getMe"
  local EXPECT="$3"    # z.B. '"ok":true'
  local MAX_TRIES="${4:-5}"
  local SLEEP="${5:-5}"

  for i in $(seq 1 $MAX_TRIES); do
    OUTPUT=$(eval "$CMD" 2>&1)
    if echo "$OUTPUT" | grep -q "$EXPECT"; then
      echo "  ✅ $DESC verifiziert (Versuch $i)"
      return 0
    fi
    [ "$i" = "$MAX_TRIES" ] && break
    echo "  ⏳ $DESC noch nicht verifiziert (Versuch $i/$MAX_TRIES), warte ${SLEEP}s..."
    sleep "$SLEEP"
  done

  echo "  ❌ $DESC NICHT verifiziert nach $MAX_TRIES Versuchen — Scholly fragen oder Gap dokumentieren"
  return 1
}
```

### Anti-Annahme-Prinzip

- Jede Token-Onboarding-Aktion endet mit einer Verifikation gegen den Vendor-Endpoint (200 mit Bearer-Token).
- "Scholly hat es eingetragen" reicht NICHT — der Endpoint muss antworten.
- Bei Token-Rotation: alter Token MUSS 401 liefern (Negativ-Verify), sonst ist die Rotation nicht durch.
- Wenn Verify-Methode fehlt → Scholly fragen + Gap im Onboarding-Output dokumentieren.

### Cross-Ref

- Master-Doc: `memory/refactor-architektur-sprint-refactor-1.md` (Block B Action-Verify-Matrix kanonisch)
- Deploy-Verify Skill nutzt gleiche Matrix-Struktur (deploy-relevante Actions)
- Beispiel Token-Leak-Postmortem 2026-05-01: `incident-2026-05-01-token-leak-postmortem.md`
