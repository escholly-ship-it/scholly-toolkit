#!/bin/bash
# sync-skill-plugin-cache (CC-242, Sprint 211)
# Identifiziert und entfernt verwaiste Plugin-Versionen unter ~/.claude/plugins/cache/.
# Default: Dry-Run. Loescht nur bei --execute.

set -u

CACHE_ROOT="$HOME/.claude/plugins/cache"
EXECUTE=0
MIN_AGE_DAYS=14

while [ $# -gt 0 ]; do
  case "$1" in
    --execute) EXECUTE=1 ;;
    --dry-run) EXECUTE=0 ;;
    --min-age-days) MIN_AGE_DAYS="$2"; shift ;;
    -h|--help)
      echo "Usage: $0 [--execute] [--min-age-days N]"
      echo "  Default: Dry-Run, listet Waisen aelter als $MIN_AGE_DAYS Tage."
      exit 0
      ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -d "$CACHE_ROOT" ]; then
  echo "Cache-Verzeichnis nicht gefunden: $CACHE_ROOT"
  exit 0
fi

NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
MIN_AGE_MS=$(( MIN_AGE_DAYS * 86400 * 1000 ))

MODE_LABEL="DRY-RUN"
[ "$EXECUTE" = "1" ] && MODE_LABEL="EXECUTE"
echo "Modus: $MODE_LABEL | Min-Age: ${MIN_AGE_DAYS}d | Cache: $CACHE_ROOT"
echo ""

FOUND=0
REMOVED=0
SKIPPED_YOUNG=0
TOTAL_BYTES=0

while IFS= read -r marker; do
  dir=$(dirname "$marker")
  ts=$(cat "$marker" 2>/dev/null | tr -d '[:space:]')
  if [ -z "$ts" ] || ! [[ "$ts" =~ ^[0-9]+$ ]]; then
    ts=0
  fi
  age_ms=$(( NOW_MS - ts ))
  age_days=$(( age_ms / 86400000 ))
  size_bytes=$(du -sk "$dir" 2>/dev/null | awk '{print $1*1024}')
  [ -z "$size_bytes" ] && size_bytes=0
  size_mb=$(python3 -c "print(f'{$size_bytes/1048576:.1f}')")
  FOUND=$(( FOUND + 1 ))
  TOTAL_BYTES=$(( TOTAL_BYTES + size_bytes ))

  if [ "$age_ms" -lt "$MIN_AGE_MS" ]; then
    printf "  SKIP (zu jung %dd < %dd) %6sMB  %s\n" "$age_days" "$MIN_AGE_DAYS" "$size_mb" "$dir"
    SKIPPED_YOUNG=$(( SKIPPED_YOUNG + 1 ))
    continue
  fi

  printf "  %s  age=%dd  %6sMB  %s\n" "$MODE_LABEL" "$age_days" "$size_mb" "$dir"
  if [ "$EXECUTE" = "1" ]; then
    rm -rf "$dir"
    REMOVED=$(( REMOVED + 1 ))
  fi
done < <(find "$CACHE_ROOT" -maxdepth 5 -name ".orphaned_at" -type f 2>/dev/null)

TOTAL_MB=$(python3 -c "print(f'{$TOTAL_BYTES/1048576:.1f}')")
echo ""
echo "Gefunden:   $FOUND Waisen (${TOTAL_MB} MB)"
echo "Skipped:    $SKIPPED_YOUNG (juenger als ${MIN_AGE_DAYS}d)"
if [ "$EXECUTE" = "1" ]; then
  echo "Entfernt:   $REMOVED Verzeichnisse"
else
  ELIGIBLE=$(( FOUND - SKIPPED_YOUNG ))
  echo "Wuerde entfernen: $ELIGIBLE Verzeichnisse (mit --execute)"
fi
