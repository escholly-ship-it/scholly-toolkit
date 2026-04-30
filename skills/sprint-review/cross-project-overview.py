#!/usr/bin/env python3
"""Cross-Projekt-Uebersicht (CC-NEW Sprint 250).

Aggregiert alle grossen Initiativen, Cross-Projekt- und Cross-Sprint-Funktionen
fuer den Phase-E-Abnahme-Block. Scholly-Forderung Sprint 250: "Am Sprintende
benoetige ich die Uebersicht ueber den Fortschritt aller grossen Initiativen."

Datenquellen:
- Roadmap-API: alle Items pro Master-Initiative
- Memory: Initiativen-Definition (Master-Items + Phase-Mappings)

Ausgabe: Markdown-Tabelle pro Initiative mit:
- Status (Phase X/Y)
- Aktuelle Sprints (in welchen Sprints aktive Items)
- Liefer-Bilanz (geliefert / total)
- Naechste Items
- Risiken/Blocker

Aufruf:
    python3 cross-project-overview.py
    python3 cross-project-overview.py --json   # fuer Skripting
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

HOME = Path.home()
TOKEN_FILE = HOME / '.roadmap-api-token'
ROADMAP_API = 'https://roadmap-escholly-ship-its-projects.vercel.app/api'

# Master-Initiativen — definieren welche Backlog-IDs zu welcher Initiative gehoeren.
# Ergaenzt sich automatisch durch projekt-Spalte im Item.
INITIATIVES = [
    {
        'name': 'Cloud-Migration (Mac muss nicht an sein)',
        'master_bid': 'CC-CLOUD-MIGRATION',
        'projekt': 'Cloud-Migration',
        'phases': [
            ('P1+P2', 'AUDIT + STRATEGIE', 'archived'),
            ('P3',    'Sessions + Memory-Migration',     '252'),
            ('P4',    'Skills + Hooks-Migration',        '253'),
            ('P5',    'Runners + LaunchAgents-Migration','251'),
            ('P6',    'Cutover + Lokal-Aufloesung',     '254'),
        ],
        'memory_ref': 'memory/backlog-cloud-migration.md',
    },
    {
        'name': 'Roadmap 2.0 (Astro+Supabase-Direct)',
        'master_bid': 'CC-301',
        'projekt': 'Claude Code',  # Roadmap 2.0 Items sind unter Claude Code projekt
        'phases': [
            ('alpha', 'UI-Konzept + Cards',                          'archived (245)'),
            ('beta',  'Login + Auth-Migration',                      'archived (246)'),
            ('gamma', 'Pack/Sync/Notion-Sync Edge Functions',        'archived (247)'),
            ('delta', 'Cutover + Vercel-Routes-Archive',             'aktiv (CC-313/314)'),
            ('epsilon','Drag-Drop + ArchiveSearch + PWA',           'Sprint 253 (CC-360/365/386)'),
        ],
        'memory_ref': 'Notion 34ed7cf9-fb32-8141-ae73-ec7a4f9d813c',
    },
    {
        'name': 'Testing-Initiative (CC-322 Regel 109)',
        'master_bid': 'CC-322',
        'projekt': 'Claude Code',
        'phases': [
            ('A11y-Audit',    'WCAG2A 5 Apps',                           'Sprint 250 ✅ (CC-335 e/f/g/h/i)'),
            ('Test-Setup',    'Vitest pro App + Lib-Test',               'Sprint 252 (CC-334g/h/i)'),
            ('Critical-Path', 'Critical-Path Lib-Tests',                 'Sprint 252 (CC-336)'),
            ('Memory-Sync',   '228 archived items im MD ~~strikethrough~~', 'Sprint 253 (CC-373)'),
        ],
        'memory_ref': 'memory/sprint-249-carry-over-pflicht.md + sprint-250-carry-over-pflicht.md',
    },
    {
        'name': 'Cookmark 2.0 (CT-35..42)',
        'master_bid': 'CT-35',
        'projekt': 'Cookmark',
        'phases': [
            ('Voraussetzung', 'CC-316 Spike + Roadmap 2.0 Lessons', 'aktiv (Spike done, Lessons aus α-γ)'),
            ('ROOF',          'Astro+Supabase Multi-User-Refactor', 'Sprint 252+ (CT-35 archived als Konzept)'),
            ('Pricing',       'Stripe-Integration + Tiers',          'Sprint 254+ (CT-45 BLOCKED Geschaeftsmodell)'),
        ],
        'memory_ref': 'memory/cookmark.md',
    },
    {
        'name': 'Hardening (heutiger Sprint 250 Trigger)',
        'master_bid': '(implizit)',
        'projekt': 'Claude Code',
        'phases': [
            ('Sprint-Start', 'textual-deps + capacity-aware + pro-upgrade', 'Sprint 250 ✅ (CC-379/381/387)'),
            ('Pre-Push',     'YAML-Lint + actionlint',                     'Sprint 250 ✅ (CC-378)'),
            ('Auth+Telegram','Preview-Doku + Reply-Bridge',                'Sprint 250 ✅ (CC-383/384)'),
            ('CLOUD-SVG',    'rsvg-convert SVG-Pfad',                      'Sprint 250 ✅ (CLOUD-SVG-MIG-IMPL)'),
        ],
        'memory_ref': 'memory/arbeitsregeln.md (Regel 109)',
    },
    {
        'name': 'SSV-Cluster Migration (Notion → Supabase, CC-316 Spike)',
        'master_bid': 'CC-316',
        'projekt': 'SSV Apps',
        'phases': [
            ('Spike',        'Konzeptpapier SSV-Apps + KiHire',            'archived (Sprint 230)'),
            ('Cluster-Setup','SSV-Cluster Schema + Routing-Logic',        'Sommer 2026 (Saisonpause)'),
            ('Cutover',      'Trainerbank/Kaderplaner/Trainingsplaner/SL', 'Sommer 2026'),
            ('TalentAgent',  'KiHire Migration auf neues Schema',         'Sommer 2026 nach SSV'),
        ],
        'memory_ref': 'memory/decision-cc316-notion-supabase-spike.md',
    },
    {
        'name': 'Routinen-Initiative (RI-MASTER, 11 Items S252-256)',
        'master_bid': 'ROUTINEN-INITIATIVE-MASTER',
        'projekt': 'Automatisierung',
        'phases': [
            ('Hot-Fix',      'R2 Substack-Public-Metrics zurueck',         'Sprint 252'),
            ('Entschlacken', 'R1 Morning + R5 Evening Daily-Connectors raus','Sprint 252'),
            ('Connector-Cut','GW-Connectors 14 → 5 reduzieren',            'Sprint 252'),
            ('Cloud-Trans',  'GW-Cloud-Routine Smoke + Cutover',           'Sprint 252-254'),
            ('Cleanup',      'Tote LaunchAgents bootout, Memory-Refs aktualisieren','Sprint 254-256'),
        ],
        'memory_ref': 'memory/backlog-automatisierung.md',
    },
]


def load_items() -> tuple[list, dict]:
    token = TOKEN_FILE.read_text().strip() if TOKEN_FILE.exists() else ''
    headers = {'Authorization': f'Bearer {token}'} if token else {}

    items = []
    for archived_flag in ('false', 'true'):
        req = urllib.request.Request(
            f'{ROADMAP_API}/items?archived={archived_flag}',
            headers=headers
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                items.extend(json.loads(r.read().decode()))
        except Exception as e:
            print(f'WARN: API-Fetch ({archived_flag}) fehlgeschlagen: {e}', file=sys.stderr)

    verify_req = urllib.request.Request(f'{ROADMAP_API}/verify', headers=headers)
    verify = {}
    try:
        with urllib.request.urlopen(verify_req, timeout=10) as r:
            verify = json.loads(r.read().decode())
    except Exception:
        pass

    return items, verify


def items_for_initiative(items: list, init: dict) -> list:
    proj = init.get('projekt')
    matches = [i for i in items if (i.get('projekt') or '') == proj]

    # Spezialfall: Cloud-Migration hat eigenes Projekt; Cookmark/Roadmap 2.0
    # fischen ueber master_bid + Notiz-Tags.
    if init['name'].startswith('Roadmap 2.0'):
        matches = [i for i in items
                   if 'Roadmap 2.0' in (i.get('title') or '')
                   or 'CC-30' in (i.get('backlog_id') or '')
                   or (i.get('backlog_id') or '').startswith('CC-3')
                   and i.get('projekt') == 'Claude Code']
    if init['name'].startswith('Cookmark 2.0'):
        matches = [i for i in items if (i.get('backlog_id') or '').startswith('CT-')
                   and ((i.get('backlog_id') or '') >= 'CT-35' or 'Cookmark 2.0' in (i.get('title') or ''))]
    if init['name'].startswith('Testing-Initiative'):
        matches = [i for i in items
                   if (i.get('backlog_id') or '').startswith(('CC-322','CC-323','CC-334','CC-335','CC-336','CC-373'))]
    if init['name'].startswith('Hardening'):
        matches = [i for i in items
                   if (i.get('backlog_id') or '') in ('CC-378','CC-379','CC-381','CC-387','CC-383','CC-384','CLOUD-SVG-MIGRATION-IMPL')]

    return matches


def render_initiative(init: dict, items: list, current_sprint: int) -> str:
    relevant = items_for_initiative(items, init)
    done = [i for i in relevant if i.get('archived')]
    in_sprint = [i for i in relevant if i.get('sprint_nummer') and not i.get('archived')]
    in_backlog = [i for i in relevant if i.get('sprint_nummer') is None and not i.get('archived')]

    sprints = sorted({i.get('sprint_nummer') for i in in_sprint if i.get('sprint_nummer')})
    sprint_str = ', '.join(f'Sprint {s}' for s in sprints) if sprints else '—'

    lines = [
        f"### {init['name']}",
        f"**Master:** `{init['master_bid']}` · **Projekt-Filter:** `{init['projekt']}`",
        f"**Liefer-Bilanz:** {len(done)} done / {len(relevant)} total · {len(in_sprint)} in Sprint(s) {sprint_str} · {len(in_backlog)} im Backlog",
        f"",
        f"| Phase | Beschreibung | Status |",
        f"|-------|--------------|--------|",
    ]
    for ph_id, ph_desc, ph_status in init['phases']:
        lines.append(f"| {ph_id} | {ph_desc} | {ph_status} |")

    if in_sprint:
        lines.append(f"")
        lines.append(f"**Aktive Items** (Sprints {sprint_str}):")
        for i in sorted(in_sprint, key=lambda x: (x.get('sprint_nummer', 999), x.get('backlog_id', ''))):
            sp = i.get('sprint_nummer')
            eff = i.get('effort') or '?'
            t = (i.get('title') or '')[:65]
            lines.append(f"  - `{i['backlog_id']}` (Sprint {sp}, {eff}): {t}")

    lines.append(f"")
    lines.append(f"**Memory:** {init['memory_ref']}")
    lines.append(f"")
    return '\n'.join(lines)


def main() -> int:
    json_mode = '--json' in sys.argv
    items, verify = load_items()
    current_sprint = verify.get('globalSprint') or 0

    if json_mode:
        out = []
        for init in INITIATIVES:
            relevant = items_for_initiative(items, init)
            out.append({
                'name': init['name'],
                'master': init['master_bid'],
                'phases': init['phases'],
                'done_count': sum(1 for i in relevant if i.get('archived')),
                'total_count': len(relevant),
                'active_sprints': sorted({i.get('sprint_nummer') for i in relevant
                                          if i.get('sprint_nummer') and not i.get('archived')}),
            })
        print(json.dumps(out, indent=2))
        return 0

    print(f"# Cross-Projekt-Uebersicht — Sprint {current_sprint}")
    print(f"")
    print(f"Stand am Sprint-Ende. Aggregat aus Roadmap-API + Memory-Files. "
          f"Pflicht-Block in Phase E (CC-NEW Sprint 250 Scholly-Forderung).")
    print(f"")
    for init in INITIATIVES:
        print(render_initiative(init, items, current_sprint))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
