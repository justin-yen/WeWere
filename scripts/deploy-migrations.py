#!/usr/bin/env python3
"""Production deployment entry point, called only by the protected push workflow."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASELINE = '20260912000000'
BASELINE_FILE = ROOT / 'supabase/migrations/20260912000000_production_baseline.sql'


def run(*args, capture=False):
    return subprocess.run(args, cwd=ROOT, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def query(sql):
    result = json.loads(run('supabase', 'db', 'query', '--linked', '--agent=no',
                            '-o', 'json', sql, capture=True))
    return result if isinstance(result, list) else result['rows']


def normalize_schema(sql):
    # This existing webhook contains environment-specific credentials. It is not
    # managed by the public-schema baseline and must never enter Git or logs.
    sql = re.sub(r'^CREATE OR REPLACE TRIGGER "apply_retro_filter" .*;\n', '', sql,
                 flags=re.MULTILINE)
    return '\n'.join(line.rstrip() for line in sql.splitlines()
                     if line.strip() and not line.lstrip().startswith('--')
                     and not line.startswith(('\\restrict ', '\\unrestrict ')))


def deploy():
    branch = os.environ.get('PRODUCTION_BRANCH')
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_EVENT_NAME') != 'push'
            or not branch
            or os.environ.get('GITHUB_REF') != f'refs/heads/{branch}'):
        raise RuntimeError('Production migrations run only in CI on a production-branch push.')
    for key in ('SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
                'SUPABASE_PROJECT_ID', 'EXPECTED_SUPABASE_PROJECT_ID'):
        if not os.environ.get(key):
            raise RuntimeError(f'Missing production environment secret: {key}')
    if os.environ['SUPABASE_PROJECT_ID'] != os.environ['EXPECTED_SUPABASE_PROJECT_ID']:
        raise RuntimeError('Production Supabase project does not match the reviewed project ID.')
    run('supabase', 'link', '--project-ref', os.environ['SUPABASE_PROJECT_ID'])
    exists = query("select to_regclass('supabase_migrations.schema_migrations') is not null as history_exists;")[0]['history_exists']
    history = query('select version from supabase_migrations.schema_migrations order by version;') if exists else []
    if not history:
        # First deployment only: verify the existing schema before recording it
        # as applied. No DDL from the baseline runs on the existing production DB.
        with tempfile.TemporaryDirectory() as directory:
            dump = Path(directory) / 'schema.sql'
            run('supabase', 'db', 'dump', '--linked', '--schema', 'public', '--file', str(dump))
            if normalize_schema(dump.read_text()) != normalize_schema(BASELINE_FILE.read_text()):
                raise RuntimeError('Production schema differs from the reviewed baseline. Reconcile before deploying; no migration history was changed.')
        run('supabase', 'migration', 'repair', BASELINE, '--status', 'applied', '--linked')
    elif BASELINE not in {row['version'] for row in history}:
        raise RuntimeError('Unexpected migration history: baseline missing. Reconcile before deploying.')
    run('supabase', 'db', 'push', '--linked', '--dry-run')
    run('supabase', 'db', 'push', '--linked', '--yes')


if __name__ == '__main__':
    deploy()
