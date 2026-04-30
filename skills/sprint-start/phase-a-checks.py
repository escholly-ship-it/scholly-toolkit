#!/usr/bin/env python3
"""Phase A consolidated checks (CC-210, Sprint 192).

Ersetzt die 6 inline-Python-Bloecke in sprint-start/SKILL.md (Schritte 4d3-4d8).
Cache wird genau EINMAL geladen, alle Checks teilen sich das JSON.

Usage:
    phase-a-checks.py <cache_file> [check1 check2 ...]

Checks (default: alle):
    freshness-num    — 4d3 numerische Zielwerte stale
    freshness-notes  — 4d4 Notizen-Heuristik stale
    watch-review     — 4d5a Watch-Trigger Review-Faelligkeit
    watch-rescan     — 4d5b Watch-Trigger Re-Scan (Klassifikator)
    watch-consistency — 4d5c Konsistenz 3 Quellen
    hook-heavy       — 4d6 Hook-schwere-Sprint-Warnung
    perm-audit       — 4d7 Permission-Glob-Audit
    plugin-cache     — 4d8 Plugin-Cache-Scan

Exit-Code: 0 (keine Blocker, nur Reports).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
MEMORY_DIR = HOME / '.claude' / 'projects' / '-Users-scholly' / 'memory'


def load_cache(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def sprint_items(cache: dict, only_current: bool = False) -> list[dict]:
    items = [i for i in cache['items']
             if i.get('sprint_nummer') and not i.get('archived')]
    if only_current:
        try:
            current = int((HOME / 'Cowork' / '.sprint-global').read_text().strip())
            items = [i for i in items if i.get('sprint_nummer') == current]
        except Exception:
            pass
    return items


# ---------- 4d3: Freshness — numerische Zielwerte ----------

def check_freshness_num(cache: dict) -> None:
    health = subprocess.run(
        ['bash', str(MEMORY_DIR / 'memory-health.sh')],
        capture_output=True, text=True).stdout
    facts: dict[str, int] = {}
    m = re.search(r'Tier-1.*?:\s*(\d+)\s*Zeilen', health)
    if m:
        facts['tier1_zeilen'] = int(m.group(1))
    m = re.search(r'COMPOSITE QUALITY SCORE:\s*(\d+)%', health)
    if m:
        facts['composite_score'] = int(m.group(1))

    kw = re.compile(r'(zeilen|score|%|budget|tier-1)', re.IGNORECASE)
    num = re.compile(r'\b(\d{2,})\s*(?:>|→|->|ueber|over|>=)\s*(\d{2,})\b')

    stale = []
    for i in sprint_items(cache):
        text = (i.get('title', '') + ' ' + (i.get('notizen') or ''))
        if not kw.search(text):
            continue
        for match in num.finditer(text):
            ist_claim, ziel = int(match.group(1)), int(match.group(2))
            fact_key = None
            if re.search(r'tier-1|zeilen|budget', text, re.IGNORECASE):
                fact_key = 'tier1_zeilen'
            elif re.search(r'score|%', text, re.IGNORECASE):
                fact_key = 'composite_score'
            if fact_key and fact_key in facts:
                ist_real = facts[fact_key]
                if ist_claim > ziel and ist_real <= ziel:
                    stale.append((i['backlog_id'], i['title'][:50],
                                  f"{match.group(0)} → Ist-Real: {ist_real}"))

    if stale:
        print('⚠️  STALE NUMERISCHE ZIELE erkannt (Ziel bereits erreicht):')
        for bid, title, claim in stale:
            print(f'  {bid} | {title} | Claim: {claim}')
        print('→ Empfehlung: Notizen aktualisieren ODER Item als DONE markieren.')
    else:
        print('✅ Freshness-Check (num): Keine stale numerischen Ziele.')


# ---------- 4d4: Freshness — Notizen-Heuristik ----------

STALE_NOTE_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r'(?:^|\.\s)Subsumiert in\s+([A-Z]+-\d+)', re.IGNORECASE), 'Subsumiert'),
    (re.compile(r'(?:^|\.\s)Erledigt Sprint\s+(\d+)', re.IGNORECASE),       'Bereits erledigt'),
    (re.compile(r'(?:^|\.\s)bereits in\s+([A-Z]+-\d+)\s+(?:erledigt|adressiert|gefixt)', re.IGNORECASE), 'Duplikat-Referenz'),
    (re.compile(r'(?:^|\.\s)nicht reproduzierbar\b', re.IGNORECASE),        'Nicht reproduzierbar'),
    (re.compile(r'(?:^|\.\s)obsolet\b', re.IGNORECASE),                     'Obsolet'),
    (re.compile(r'\bRunner\s+(?:laeuft|läuft|lauft)\s+(?:seit\s+Sprint\s+\d+\s+)?(?:stabil|OK|stoerungsfrei|störungsfrei|fehlerfrei)', re.IGNORECASE), 'Runner stabil (CC-155)'),
    (re.compile(r'\bseit\s+Sprint\s+\d+\s+(?:stabil|OK|produktiv|in\s+Betrieb)', re.IGNORECASE), 'Seit Sprint X stabil (CC-155)'),
    (re.compile(r'(?:^|\.\s)(?:Monitoring|Check)\s+bestaetigt\s+.*(?:OK|stabil|laeuft)', re.IGNORECASE), 'Monitoring bestaetigt OK (CC-155)'),
    (re.compile(r'aus\s+Sprint\s+genommen', re.IGNORECASE),                 'AUS SPRINT GENOMMEN (CC-186)'),
]


def check_freshness_notes(cache: dict) -> None:
    stale_items = []
    for i in sprint_items(cache):
        notizen = i.get('notizen') or ''
        if not notizen:
            continue
        for pattern, label in STALE_NOTE_PATTERNS:
            m = pattern.search(notizen)
            if m:
                stale_items.append((i['backlog_id'], i['title'][:50], label,
                                    m.group(0).strip()[:60]))
                break
    if stale_items:
        print('⚠️  STALE NOTIZEN erkannt (Item verweist auf erledigte Arbeit):')
        for bid, title, label, match in stale_items:
            print(f'  {bid} | {title} | [{label}] → "{match}"')
        print('→ Empfehlung: Items mit PATCH archived=true auto-archivieren.')
    else:
        print('✅ Freshness-Check (notes): Keine stale Notizen.')


# ---------- 4d5a: Watch-Trigger Review ----------

def check_watch_review(_cache: dict) -> None:
    import datetime
    wt_file = MEMORY_DIR / 'watch-triggers.md'
    if not wt_file.exists():
        print('ℹ️  Watch-Triggers Datei fehlt — keine Pruefung.')
        return
    content = wt_file.read_text()
    entries = re.findall(r'### (WT-\d+) — (.+?)\n(.*?)(?=\n### |\Z)',
                         content, re.DOTALL)
    today = datetime.date.today()
    flagged = []
    for wid, title, body in entries:
        review = re.search(r'\*\*Review:\*\*\s*(\d{4}-\d{2}-\d{2})', body)
        if review:
            d = datetime.date.fromisoformat(review.group(1))
            if today >= d:
                flagged.append((wid, title.strip(), review.group(1)))
    if flagged:
        print('⚠️  Watch-Trigger mit Review-Bedarf:')
        for w, t, d in flagged:
            print(f'  {w} | {t[:50]} | REVIEW-FAELLIG (seit {d})')
    else:
        print(f'✅ Watch-Review: {len(entries)} aktive Trigger, keiner faellig.')


# ---------- 4d5b: Watch-Trigger Re-Scan ----------

def check_watch_rescan(cache: dict) -> None:
    classifier = MEMORY_DIR / 'watch-trigger-classifier.py'
    if not classifier.exists():
        print('ℹ️  Klassifikator fehlt — Re-Scan skip.')
        return
    candidates = []
    for item in cache['items']:
        if item.get('archived') or item.get('sprint_nummer'):
            continue
        payload = json.dumps({
            'title': item.get('title', ''),
            'notizen': item.get('notizen', '') or '',
            'horizont': item.get('horizont', '') or '',
            'abhaengigkeit': item.get('abhaengigkeit', '') or '',
            'status': '',
        })
        r = subprocess.run(['python3', str(classifier)],
                           input=payload, capture_output=True, text=True)
        try:
            data = json.loads(r.stdout)
            if data.get('category') == 'watch-trigger' and data.get('confidence', 0) >= 0.7:
                candidates.append((item['backlog_id'], item['title'][:50],
                                   data.get('score'),
                                   data.get('suggested_wt_bedingung', '')))
        except Exception:
            pass
    if candidates:
        print(f'⚠️  {len(candidates)} Watch-Trigger-Kandidaten in aktiven Backlogs:')
        for bid, t, s, b in candidates:
            print(f'  {bid} | {t} (score={s}) — Bedingung: {b}')
        print('→ Scholly fragen: migrieren oder im Backlog behalten?')
    else:
        print('✅ Watch-Rescan: Keine neuen Kandidaten.')


# ---------- 4d5c: Watch-Trigger Konsistenz ----------

def check_watch_consistency(_cache: dict) -> None:
    script = MEMORY_DIR / 'watch-trigger-consistency.py'
    if not script.exists():
        print('ℹ️  Konsistenz-Script fehlt.')
        return
    r = subprocess.run(['python3', str(script)], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)


# ---------- 4d6: Hook-schwere Sprint ----------

def check_hook_heavy(cache: dict) -> None:
    items = sprint_items(cache, only_current=True)
    key = re.compile(
        r'(?:^|\W)(hook|hooks|settings\.json|\.claude/hooks|phase-gate|PreToolUse|PostToolUse)(?:\W|$)',
        re.IGNORECASE)
    hits = []
    for i in items:
        text = (i.get('title', '') + ' ' + (i.get('notizen') or ''))
        matches = key.findall(text)
        if matches:
            hits.append((i['backlog_id'], i['title'][:50], len(matches)))
    if len(hits) >= 2:
        print(f'⚠️  HOOK-SCHWERER SPRINT: {len(hits)} Items erkannt.')
        for bid, t, n in hits:
            print(f'    {bid} | {t} ({n} Keyword-Treffer)')
        print('    → Empfehlung: defaultMode=acceptEdits, sonst Prompt-Flut in Phase D.')
    else:
        print(f'✅ Hook-Schwere: {len(hits)} Hook-Items im Scope.')


# ---------- 4d7: Permission-Glob-Audit ----------

def check_perm_audit(_cache: dict) -> None:
    import fnmatch
    settings_path = HOME / '.claude' / 'settings.json'
    try:
        settings = json.loads(settings_path.read_text())
    except FileNotFoundError:
        print('ℹ️  settings.json fehlt — Audit skip.')
        return
    allow = settings.get('permissions', {}).get('allow', [])
    globs = []
    for entry in allow:
        if isinstance(entry, str) and (entry.startswith('Edit(') or entry.startswith('Write(')) and entry.endswith(')'):
            globs.append(os.path.expanduser(entry.split('(', 1)[1][:-1]))

    scan = [HOME / 'Library' / 'LaunchAgents',
            HOME / 'projects',
            HOME / 'Cowork' / 'tasks',
            HOME / 'Cowork' / 'scripts']
    recent = []
    for d in scan:
        if not d.is_dir():
            continue
        r = subprocess.run(
            ['find', str(d), '-mtime', '-90', '-maxdepth', '3', '-type', 'f',
             '-not', '-path', '*/node_modules/*', '-not', '-path', '*/.next/*',
             '-not', '-path', '*/.git/*'],
            capture_output=True, text=True, timeout=10)
        recent.extend(l for l in r.stdout.strip().split('\n') if l)

    def matches(p: str, gs: list[str]) -> bool:
        for g in gs:
            if fnmatch.fnmatch(p, g) or fnmatch.fnmatch(p, g + '/*') or \
               (g.endswith('/**') and p.startswith(g[:-3])):
                return True
        return False

    uncov = [p for p in recent if not matches(p, globs)]
    if uncov:
        from collections import Counter
        print(f'ℹ️  Permission-Glob-Audit: {len(uncov)}/{len(recent)} Dateien in Dark-Spots ohne passendes allow-Glob.')
        dirs = Counter(os.path.dirname(p) for p in uncov)
        for d, c in dirs.most_common(8):
            print(f'    {c:3}x {d}')
        print('    → Nach Phase E: falls Prompts auftauchten, Globs via update-config ergaenzen.')
    else:
        print(f'✅ Permission-Glob-Audit: {len(recent)} recent Dateien, alle abgedeckt.')


# ---------- 4d8: Plugin-Cache-Scan ----------

def check_plugin_cache(_cache: dict) -> None:
    plugins_dir = HOME / '.claude' / 'plugins'
    installed_file = plugins_dir / 'installed_plugins.json'
    cache_dir = plugins_dir / 'cache'
    if not installed_file.exists() or not cache_dir.exists():
        print('ℹ️  Plugin-Cache-Scan: keine Plugin-Infrastruktur.')
        return

    installed = json.loads(installed_file.read_text())
    expected: set[str] = set()
    for _name, entries in installed.get('plugins', {}).items():
        for entry in entries:
            p = entry.get('installPath')
            if p:
                expected.add(os.path.realpath(p))

    actual: set[str] = set()
    for marketplace in cache_dir.iterdir():
        if not marketplace.is_dir():
            continue
        for plugin in marketplace.iterdir():
            if not plugin.is_dir():
                continue
            for version in plugin.iterdir():
                if not version.is_dir():
                    continue
                actual.add(os.path.realpath(str(version)))

    orphans = sorted(actual - expected)
    missing = sorted(expected - actual)

    drift = []
    cowork_scripts = HOME / 'Cowork' / 'scholly-toolkit' / 'scripts'
    if cowork_scripts.is_dir():
        for src in cowork_scripts.glob('*.sh'):
            for cp in actual:
                cached = Path(cp) / 'scripts' / src.name
                if cached.exists():
                    if src.read_bytes() != cached.read_bytes():
                        drift.append((src.name, str(cached)))

    if orphans:
        print(f'⚠️  {len(orphans)} Waisen-Cache-Verzeichnisse:')
        for p in orphans[:8]:
            print(f'    {p}')
    if missing:
        print(f'⚠️  {len(missing)} installed_plugins-Eintraege ohne Cache:')
        for p in missing[:8]:
            print(f'    {p}')
    if drift:
        print(f'⚠️  {len(drift)} Plugin-Cache-Drift-Faelle (CC-222-Pattern):')
        for name, path in drift:
            print(f'    {name}  ←  {path}')
        print('    → Fix: Plugin re-install ODER Cache-Datei manuell synchronisieren.')
    if not (orphans or missing or drift):
        print(f'✅ Plugin-Cache-Scan: {len(actual)} Caches, konsistent, keine Drift.')


# ---------- 4d9: Vercel CPU-Verteilung pro Projekt (CC-299) ----------

def check_vercel_cpu(_cache: dict) -> None:
    """Top-5 CPU-Verteilung pro Vercel-Projekt + HOT-Polling-Warnung.

    Datenquellen (in dieser Reihenfolge):
    1. ~/Cowork/.vercel-cpu-snapshot.json (manueller Monats-Snapshot, falls vorhanden)
    2. polling-audit.sh --json (Live-Indikator: HOT/WARM Polling-Treffer)

    Sprint-228-Lehre: Hobby-Tier-CPU verbrennt durch Polling, nicht Bandwidth.
    Bei >=1 Projekt mit HOT-Polling oder >20% CPU-Anteil → AUDIT-Item PFLICHT.
    """
    snapshot = HOME / 'Cowork' / '.vercel-cpu-snapshot.json'
    if snapshot.exists():
        try:
            data = json.loads(snapshot.read_text())
            projects = sorted(
                data.get('projects', []),
                key=lambda p: p.get('cpu_percent', 0),
                reverse=True,
            )
            if not projects:
                print('ℹ️  Vercel CPU: Snapshot leer.')
                return
            print(f'📊 Vercel CPU-Snapshot ({data.get("snapshot_date","?")}):')
            high = []
            for i, p in enumerate(projects[:5], 1):
                pct = p.get('cpu_percent', 0)
                marker = ' 🔴' if pct >= 20 else ('  ⚠️' if pct >= 10 else '')
                print(f'    {i}. {p["name"]}: {pct}%{marker}')
                if pct >= 20:
                    high.append(p['name'])
            if high:
                print(f'⚠️  {len(high)} Projekt(e) >20% CPU: {", ".join(high)}')
                print('    → AUDIT-Item PFLICHT im Sprint-Scope (Polling-Reduktion / Caching).')
            return
        except Exception as e:
            print(f'⚠️  Snapshot konnte nicht gelesen werden: {e}')

    # Fallback: Polling-Audit als Proxy
    audit_script = HOME / 'Cowork' / 'scripts' / 'polling-audit.sh'
    if not audit_script.exists():
        print('ℹ️  Vercel CPU: Kein Snapshot, kein polling-audit.sh.')
        return

    try:
        out = subprocess.run(
            ['bash', str(audit_script), '--json'],
            capture_output=True, text=True, timeout=30,
        )
        if out.returncode != 0:
            print(f'⚠️  polling-audit.sh fehlgeschlagen: {out.stderr[:200]}')
            return
        result = json.loads(out.stdout)
    except Exception as e:
        print(f'⚠️  polling-audit.sh nicht auswertbar: {e}')
        return

    summary = result.get('summary', {})
    items = result.get('items', [])

    by_project: dict[str, dict[str, int]] = {}
    for item in items:
        proj = item['project']
        bucket = by_project.setdefault(proj, {'HOT': 0, 'WARM': 0, 'OK': 0})
        bucket[item['class']] = bucket.get(item['class'], 0) + 1

    if not by_project:
        print('✅ Vercel CPU (Polling-Proxy): 11 Projekte, keine Polling-Treffer.')
        return

    ranked = sorted(
        by_project.items(),
        key=lambda kv: (kv[1].get('HOT', 0), kv[1].get('WARM', 0), kv[1].get('OK', 0)),
        reverse=True,
    )

    print(f'📊 Polling-Density pro Projekt (Proxy fuer CPU-Risiko, Total {summary.get("total",0)}):')
    high = []
    for proj, b in ranked[:5]:
        marker = ''
        if b.get('HOT', 0) > 0:
            marker = ' 🔴 HOT'
            high.append(proj)
        elif b.get('WARM', 0) > 0:
            marker = ' ⚠️ WARM'
        print(f'    {proj}: HOT={b.get("HOT",0)} WARM={b.get("WARM",0)} OK={b.get("OK",0)}{marker}')

    if high:
        print(f'⚠️  {len(high)} Projekt(e) mit HOT-Polling: {", ".join(high)}')
        print('    → AUDIT-Item PFLICHT im Sprint-Scope (Polling-Reduktion).')
        print('    Manueller CPU-Check via Vercel-Dashboard → Snapshot in ~/Cowork/.vercel-cpu-snapshot.json speichern.')
    else:
        print(f'✅ Polling-Density: {summary.get("hot",0)} HOT / {summary.get("warm",0)} WARM / {summary.get("ok",0)} OK')


# ---------- 4d11: Pro-Upgrade-Trigger (CC-387, Sprint 250) ----------

PRO_UPGRADE_THRESHOLD = 0.75
PRO_UPGRADE_QUOTAS = [
    ('vercel_active_cpu_percent',     'Vercel Active CPU',       'Hobby-Tier 4h/Monat'),
    ('vercel_bandwidth_percent',      'Vercel Bandwidth',        'Hobby-Tier 100GB/Monat'),
    ('vercel_function_invocations_percent', 'Vercel Function-Invocations', 'Hobby-Tier 100k/Tag'),
    ('supabase_db_size_percent',      'Supabase DB-Size',        'Free-Tier 500MB'),
    ('supabase_egress_percent',       'Supabase Egress',         'Free-Tier 5GB/Monat'),
    ('supabase_mau_percent',          'Supabase MAU',            'Free-Tier 50k/Monat'),
]


def check_pro_upgrade_trigger(_cache: dict) -> None:
    """Prueft Vercel/Supabase-Quota gegen 75%-Schwelle.

    Datenquelle: ~/Cowork/.vercel-cpu-snapshot.json (manueller Monats-Snapshot).
    Snapshot-Format wird um Quota-Felder erweitert (vercel_*_percent, supabase_*_percent).

    Bei 1+ Quote >= 75% → Block-Output mit Pro-Upgrade-Empfehlung. Reports only.
    """
    snapshot = HOME / 'Cowork' / '.vercel-cpu-snapshot.json'
    if not snapshot.exists():
        print('ℹ️  Pro-Upgrade-Trigger: Kein Vercel-Snapshot — DevOps-Checkpoint muss manuelle Werte einlesen.')
        return

    try:
        data = json.loads(snapshot.read_text())
    except Exception as e:
        print(f'⚠️  Snapshot konnte nicht gelesen werden: {e}')
        return

    triggers = []
    missing = []
    for key, label, quota_desc in PRO_UPGRADE_QUOTAS:
        if key in data:
            try:
                pct = float(data[key])
            except Exception:
                continue
            # Speichere als 0-1 oder 0-100? Snapshot speichert 0-100.
            normalized = pct / 100 if pct > 1 else pct
            if normalized >= PRO_UPGRADE_THRESHOLD:
                triggers.append((label, pct, quota_desc))
        else:
            missing.append(label)

    if missing:
        print(f'ℹ️  Pro-Upgrade-Trigger: {len(missing)}/{len(PRO_UPGRADE_QUOTAS)} Quotas im Snapshot fehlen ({", ".join(missing[:3])}{"..." if len(missing) > 3 else ""}).')

    if not triggers:
        if not missing:
            print('✅ Pro-Upgrade-Trigger: Alle Quotas <75%, keine Empfehlung.')
        return

    print(f'🔴 PRO-UPGRADE-TRIGGER: {len(triggers)} Quota(s) ueber {int(PRO_UPGRADE_THRESHOLD*100)}%:')
    for label, pct, quota_desc in triggers:
        print(f'    {label}: {pct}% ({quota_desc})')
    print('    → Pro-Upgrade nuetzlich, Zeit fuer Entscheidung jetzt.')
    print('    → Sprint-Scope sollte (a) Polling/Egress-Reduktion ODER (b) Pro-Upgrade-Item enthalten.')


# ---------- 4d10: Textuelle Dependencies (CC-379, Sprint 250) ----------

def check_textual_deps(cache: dict) -> None:
    """Prueft `abhaengigkeit`-Felder von Sprint-Items auf textuelle Vorgaenger-Verweise.

    Erkennt Pattern wie `depends:CC-355`, `Abhaengig von: CC-100`, `nach CC-XYZ`,
    `siehe CC-XYZ`. Verifiziert dass der referenzierte backlog_id existiert UND
    archived ODER in einem frueheren Sprint ist. Reports Treffer wo der Vorgaenger:
    - nicht existiert (Tippfehler / wurde geloescht)
    - im Backlog steht (sprint_nummer=NULL, kein Hard-Block-Tag)
    - in spaeterem Sprint sitzt
    Reports only, kein STOPP — komplementaer zum Hard-Gate (blocked_by_item_id)
    in SKILL.md Schritt 4c2.
    """
    items = cache['items']
    items_by_bid = {i['backlog_id']: i for i in items if i.get('backlog_id')}
    try:
        current = int((HOME / 'Cowork' / '.sprint-global').read_text().strip())
    except Exception:
        current = 0

    sprint_set = [i for i in items
                  if i.get('sprint_nummer') and not i.get('archived')]

    # Patterns: erfasst CC-NNN, KP-NN, TB-NN, GW-NNN etc. (Backlog-ID-Format)
    bid_re = re.compile(r'\b([A-Z]{2,8}-\d{1,4}[a-z]?)\b')
    keyword_re = re.compile(
        r'\b(depends|abhaengig\s+von|abhängig\s+von|nach|siehe|requires|needs|braucht|setzt\s+voraus)\b',
        re.IGNORECASE)

    findings = []
    for it in sprint_set:
        abh = (it.get('abhaengigkeit') or '').strip()
        if not abh:
            continue
        # BLOCKED-Items werden vom Hygiene-Gate erfasst, hier ueberspringen
        if abh.upper().startswith('BLOCKED:'):
            continue
        # Skip Action-Labels (`Scholly:`, `Christine:`, `Extern:`) — keine Item-Deps
        if re.match(r'^(Scholly|Christine|Extern|Zeitabhaengig):', abh, re.IGNORECASE):
            continue
        # Skip wenn blocked_by_item_id bereits gesetzt — Hard-Gate hat den Vorgaenger
        # bereits aufgeloest (auch fuer archived Items, die nicht im Cache sind).
        if it.get('blocked_by_item_id'):
            continue
        # Suche nach Backlog-ID-Verweisen
        bids_found = bid_re.findall(abh)
        if not bids_found:
            continue
        # Wenn Keyword-Heuristik auch trifft, ist es sehr wahrscheinlich ein Dep-Verweis
        has_keyword = bool(keyword_re.search(abh))
        for ref_bid in bids_found:
            # Selbstreferenz ueberspringen
            if ref_bid == it.get('backlog_id'):
                continue
            ref = items_by_bid.get(ref_bid)
            if ref is None:
                findings.append((it['backlog_id'], ref_bid, 'NICHT GEFUNDEN',
                                 abh[:60], has_keyword))
                continue
            if ref.get('archived'):
                continue  # Done, OK
            ref_sprint = ref.get('sprint_nummer')
            if ref_sprint is None:
                findings.append((it['backlog_id'], ref_bid, 'IM BACKLOG',
                                 abh[:60], has_keyword))
            elif current and ref_sprint >= current:
                findings.append((it['backlog_id'], ref_bid,
                                 f'SPRINT {ref_sprint} (>= aktuell)',
                                 abh[:60], has_keyword))

    if not findings:
        print('✅ Textuelle Dependencies: alle Vorgaenger erledigt oder in frueherem Sprint.')
        return

    print(f'⚠️  Textuelle Dependencies: {len(findings)} Verweise mit Problemen:')
    for bid, ref_bid, status, abh_excerpt, has_kw in findings:
        kw_marker = ' [Keyword]' if has_kw else ''
        print(f'  {bid:18} → {ref_bid:12} ({status}){kw_marker} | abh: "{abh_excerpt}"')
    print('→ Empfehlung: Verweis korrigieren, Item ins blocked_by_item_id-Feld migrieren (CC-374), '
          'oder abh-Feld klaeren. Komplementaer zu Hard-Gate in SKILL.md Schritt 4c2.')


# ---------- Dispatcher ----------

CHECKS = {
    'freshness-num': check_freshness_num,
    'freshness-notes': check_freshness_notes,
    'watch-review': check_watch_review,
    'watch-rescan': check_watch_rescan,
    'watch-consistency': check_watch_consistency,
    'hook-heavy': check_hook_heavy,
    'perm-audit': check_perm_audit,
    'plugin-cache': check_plugin_cache,
    'vercel-cpu': check_vercel_cpu,
    'textual-deps': check_textual_deps,
    'pro-upgrade-trigger': check_pro_upgrade_trigger,
}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cache_path = sys.argv[1]
    selected = sys.argv[2:] if len(sys.argv) > 2 else list(CHECKS.keys())
    cache = load_cache(cache_path)
    for name in selected:
        fn = CHECKS.get(name)
        if not fn:
            print(f'⚠️  Unbekannter Check: {name}', file=sys.stderr)
            continue
        print(f'── {name} ──')
        try:
            fn(cache)
        except Exception as e:
            print(f'❌ {name} failed: {e}')
        print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
