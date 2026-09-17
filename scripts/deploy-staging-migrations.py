#!/usr/bin/env python3
"""Synchronize the disposable staging database with the staging branch."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_PROJECT_ID = 'xsvscfqnzybdxptijmqs'


def run(*args, capture=False):
    return subprocess.run(
        args, cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    ).stdout


def query(sql):
    result = json.loads(run(
        'supabase', 'db', 'query', '--linked', '--agent=no', '-o', 'json', sql,
        capture=True,
    ))
    return result if isinstance(result, list) else result['rows']


def local_versions():
    return [path.name.split('_', 1)[0] for path in sorted(
        (ROOT / 'supabase/migrations').glob('*.sql')
    )]


def guard():
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_EVENT_NAME') != 'push'
            or os.environ.get('GITHUB_REF') != 'refs/heads/staging'):
        raise RuntimeError('Staging migrations run only in CI on a staging-branch push.')
    for key in ('SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
                'SUPABASE_PROJECT_ID', 'EXPECTED_SUPABASE_PROJECT_ID'):
        if not os.environ.get(key):
            raise RuntimeError(f'Missing staging environment secret or setting: {key}')
    project = os.environ['SUPABASE_PROJECT_ID']
    if project != os.environ['EXPECTED_SUPABASE_PROJECT_ID']:
        raise RuntimeError('Staging Supabase project does not match the reviewed project ID.')
    if project == PRODUCTION_PROJECT_ID:
        raise RuntimeError('Refusing to use the production Supabase project for staging.')


def deploy():
    guard()
    run('supabase', 'link', '--project-ref', os.environ['SUPABASE_PROJECT_ID'])
    exists = query(
        "select to_regclass('supabase_migrations.schema_migrations') "
        "is not null as history_exists;"
    )[0]['history_exists']
    remote = [str(row['version']) for row in query(
        'select version from supabase_migrations.schema_migrations order by version;'
    )] if exists else []
    local = local_versions()

    # Preserve staging data while its applied history remains an exact prefix of
    # the release candidate. If a candidate migration is removed or reordered,
    # rebuild this disposable environment instead of pretending to undo SQL.
    if remote and remote == local[:len(remote)]:
        run('supabase', 'db', 'push', '--linked', '--dry-run')
        run('supabase', 'db', 'push', '--linked', '--yes')
    else:
        run('supabase', 'db', 'reset', '--linked', '--no-seed', '--yes')

    run('supabase', 'test', 'db', '--linked')


if __name__ == '__main__':
    deploy()
