#!/usr/bin/env python3
"""Validate migration names and reject editing previously versioned migrations."""
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'supabase/migrations'
files = sorted(folder.glob('*.sql'))
versions = set()
for path in files:
    match = re.fullmatch(r'(\d{14})_[a-z0-9_]+\.sql', path.name)
    if not match or match[1] in versions:
        sys.exit(f'Invalid or duplicate migration version: {path.name}')
    versions.add(match[1])
    if re.search(r'Bearer\s+\S+|eyJ[A-Za-z0-9_-]{20,}', path.read_text()):
        sys.exit(f'Possible embedded credential: {path.name}')
if not files:
    sys.exit('No migrations found')
if (root / 'backend/supabase/migrations').exists():
    sys.exit('Keep all executable migrations in root supabase/migrations')
if len(sys.argv) > 1:
    base = sys.argv[1]
    previous = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', base,
                                        '--', 'supabase/migrations'], cwd=root, text=True)
    # The one-time legacy consolidation predates this baseline. Once the
    # baseline is merged, every migration in the base revision is immutable.
    if '20260912000000_production_baseline.sql' in previous:
        for name in previous.splitlines():
            path = root / name
            original = subprocess.check_output(['git', 'show', f'{base}:{name}'], cwd=root)
            if not path.exists() or path.read_bytes() != original:
                sys.exit(f'Applied migrations are immutable; add a new migration instead: {name}')
print(f'Validated {len(files)} migration filenames and history')
