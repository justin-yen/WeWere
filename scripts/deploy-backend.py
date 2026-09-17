#!/usr/bin/env python3
"""Deploy a reviewed backend checkout to its matching Railway environment."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ID = '909ea8c4-4945-4a4f-813e-41477c815b68'
TARGETS = {
    'staging': {
        'branch': 'staging',
        'environment': 'staging',
        'service': 'api-staging',
        'url': 'https://api-staging-staging-62e9.up.railway.app/',
    },
    'production': {
        'branch': 'main',
        'environment': 'production',
        'service': 'api',
        'url': 'https://api-production-77f0.up.railway.app/',
    },
}
RUNTIME_ROOT_FILES = {
    'Procfile', 'config.py', 'main.py', 'railway.json', 'requirements.txt', 'runtime.txt',
}
RUNTIME_DIRECTORIES = {'middleware', 'models', 'routers', 'services'}


def run(*args, capture=False, cwd=ROOT):
    return subprocess.run(
        args, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    ).stdout


def target():
    name = os.environ.get('DEPLOYMENT_ENVIRONMENT')
    if name not in TARGETS:
        raise RuntimeError('DEPLOYMENT_ENVIRONMENT must be staging or production.')
    config = TARGETS[name]
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_EVENT_NAME') != 'push'
            or os.environ.get('GITHUB_REF') != f"refs/heads/{config['branch']}"):
        raise RuntimeError(f"{name.title()} API deploys only from its release branch in CI.")
    if not os.environ.get('RAILWAY_TOKEN'):
        raise RuntimeError('Missing Railway deployment token.')
    return name, config


def package_backend(destination):
    copied = []
    backend = ROOT / 'backend'
    sources = [backend / name for name in RUNTIME_ROOT_FILES]
    for directory in RUNTIME_DIRECTORIES:
        sources.extend((backend / directory).rglob('*.py'))
    for source in sorted(sources):
        relative = source.relative_to(backend)
        if '__pycache__' in relative.parts:
            continue
        if not source.is_file():
            continue
        output = destination / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, output)
        copied.append(relative.as_posix())
    missing = RUNTIME_ROOT_FILES - set(copied)
    if missing:
        raise RuntimeError(f'Missing backend runtime files: {sorted(missing)}')
    return copied


def wait_for_health(url):
    last_error = None
    for _ in range(40):
        try:
            with urlopen(url, timeout=5) as response:
                if response.status == 200:
                    return
        except Exception as error:
            last_error = error
        time.sleep(3)
    raise RuntimeError(f'Railway health check did not recover: {last_error}')


def deploy():
    name, config = target()
    with tempfile.TemporaryDirectory() as directory:
        package = Path(directory)
        package_backend(package)
        message = f"{name} release {os.environ.get('GIT_SHA', 'unknown')}"
        # Railway project tokens can deploy to their environment with explicit
        # flags. `railway link` requires broader account permissions in CI.
        run(
            'railway', 'up', str(package), '--path-as-root', '--ci',
            '--project', PROJECT_ID, '--environment', config['environment'],
            '--service', config['service'], '--message', message, cwd=package,
        )
        # Attached --ci returns a failure exit code if deployment fails.
    wait_for_health(config['url'])


if __name__ == '__main__':
    deploy()
