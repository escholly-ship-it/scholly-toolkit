#!/usr/bin/env bash
# token-onboarding helpers — CC-263-TOKEN-ONBOARDING (Sprint 263)
#
# Sichere Bash-Helper fuer macOS Keychain.
# - Tokens NIE als Argument (landet in History) — nur via stdin (read -s).
# - Service-Naming-Konvention: scholly.<service>
# - Account-Name = ENV-Variablenname (z.B. OPENAI_API_KEY)
#
# Verwendung:
#   source ~/Cowork/scholly-toolkit/skills/token-onboarding/scripts/token-onboarding.sh
#   keychain_set scholly.openai OPENAI_API_KEY      # promptet (verdeckt) nach Token
#   TOKEN=$(keychain_get scholly.openai OPENAI_API_KEY)
#   keychain_list
#   keychain_delete scholly.alttool OLD_TOKEN

set -o pipefail

_keychain_require_macos() {
    if ! command -v security >/dev/null 2>&1; then
        echo "❌ macOS 'security' CLI nicht verfuegbar — vermutlich Cloud-Mode." >&2
        echo "   In Cloud-Sessions Tokens via Bootstrap-Env (Roadmap-API) holen." >&2
        return 1
    fi
}

# keychain_set <service> <account>
# Liest Token verdeckt von stdin und legt ihn in der Login-Keychain ab.
keychain_set() {
    local service="$1" account="$2"
    if [ -z "$service" ] || [ -z "$account" ]; then
        echo "Usage: keychain_set <service> <account>" >&2
        return 2
    fi
    _keychain_require_macos || return 1

    # Token verdeckt von stdin lesen — landet NICHT in Shell-History
    local token
    if [ -t 0 ]; then
        printf "Token fuer %s/%s (verdeckt): " "$service" "$account" >&2
        IFS= read -rs token
        echo "" >&2
    else
        # stdin ist Pipe: erste Zeile lesen
        IFS= read -r token
    fi

    if [ -z "$token" ]; then
        echo "❌ Leerer Token — abgebrochen." >&2
        return 3
    fi

    # -U: update wenn vorhanden, -w -: Passwort von stdin (vermeidet History)
    if printf '%s' "$token" | security add-generic-password \
        -U -s "$service" -a "$account" -w "$(cat)" 2>/dev/null; then
        echo "✅ Keychain: $service / $account gespeichert (${#token} Zeichen)." >&2
    else
        # Fallback: -w mit stdin via Prozess-Substitution geht nicht, also doch -w mit Variable
        # ABER: wir minimieren Exposition — Token nur in dieser Subshell sichtbar
        if security add-generic-password -U -s "$service" -a "$account" -w "$token"; then
            echo "✅ Keychain: $service / $account gespeichert (${#token} Zeichen)." >&2
        else
            echo "❌ Keychain-Schreiben fehlgeschlagen." >&2
            return 4
        fi
    fi

    # Token aus Variable loeschen
    unset token
}

# keychain_get <service> <account>
# Gibt Token auf stdout aus (zur Verwendung in Subshell-Aufrufen).
keychain_get() {
    local service="$1" account="$2"
    if [ -z "$service" ] || [ -z "$account" ]; then
        echo "Usage: keychain_get <service> <account>" >&2
        return 2
    fi
    _keychain_require_macos || return 1

    security find-generic-password -s "$service" -a "$account" -w 2>/dev/null
}

# keychain_list
# Listet alle scholly.*-Eintraege (nur Service+Account, keine Werte).
keychain_list() {
    _keychain_require_macos || return 1
    security dump-keychain 2>/dev/null \
        | awk '/"svce".*"scholly\./{svc=$0} /"acct"/{acct=$0; print svc" | "acct; svc=""; acct=""}' \
        | sed 's/"svce"<blob>="//; s/"acct"<blob>="//; s/"$//g' \
        | sort -u
}

# keychain_delete <service> <account>
keychain_delete() {
    local service="$1" account="$2"
    if [ -z "$service" ] || [ -z "$account" ]; then
        echo "Usage: keychain_delete <service> <account>" >&2
        return 2
    fi
    _keychain_require_macos || return 1
    security delete-generic-password -s "$service" -a "$account" >/dev/null 2>&1 \
        && echo "✅ Keychain-Eintrag $service / $account entfernt." >&2 \
        || { echo "❌ Eintrag nicht gefunden oder Loeschen fehlgeschlagen." >&2; return 4; }
}

# Convenience: load Token in ENV-Variable mit gleichem Namen wie account.
keychain_export() {
    local service="$1" account="$2"
    if [ -z "$service" ] || [ -z "$account" ]; then
        echo "Usage: keychain_export <service> <account>" >&2
        return 2
    fi
    local val
    val="$(keychain_get "$service" "$account")" || return $?
    if [ -z "$val" ]; then
        echo "❌ Kein Wert fuer $service / $account." >&2
        return 5
    fi
    export "$account=$val"
    echo "✅ Exportiert: $account (${#val} Zeichen)" >&2
    unset val
}
