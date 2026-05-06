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
