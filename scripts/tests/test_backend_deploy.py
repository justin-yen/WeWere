import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'backend_deploy', Path(__file__).parents[1] / 'deploy-backend.py'
)
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class BackendDeploymentTests(unittest.TestCase):
    def env(self, name):
        config = deploy.TARGETS[name]
        return dict(
            DEPLOYMENT_ENVIRONMENT=name, GITHUB_ACTIONS='true',
            GITHUB_EVENT_NAME='push', GITHUB_REF=f"refs/heads/{config['branch']}",
            RAILWAY_TOKEN='test', GIT_SHA='abc123',
        )

    def test_environment_must_match_release_branch(self):
        for env in ({}, {**self.env('staging'), 'GITHUB_REF': 'refs/heads/main'},
                    {**self.env('production'), 'GITHUB_EVENT_NAME': 'pull_request'}):
            with self.subTest(env=env), patch.dict(os.environ, env, clear=True):
                with self.assertRaises(RuntimeError):
                    deploy.target()

    def test_package_contains_runtime_without_secrets_or_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            files = deploy.package_backend(Path(directory))
        self.assertIn('main.py', files)
        self.assertIn('routers/events.py', files)
        self.assertNotIn('.env', files)
        self.assertFalse(any(name.startswith('tests/') for name in files))

    def test_deploy_targets_matching_service_then_checks_health(self):
        for name in deploy.TARGETS:
            with self.subTest(name=name), patch.dict(os.environ, self.env(name), clear=True), \
                    patch.object(deploy, 'package_backend'), patch.object(deploy, 'run') as run, \
                    patch.object(deploy, 'wait_for_health') as health:
                deploy.deploy()
            up = run.call_args_list[-1].args
            self.assertEqual(up[0:2], ('railway', 'up'))
            self.assertEqual(up[up.index('--environment') + 1], name)
            self.assertEqual(up[up.index('--service') + 1], deploy.TARGETS[name]['service'])
            health.assert_called_once_with(deploy.TARGETS[name]['url'])


if __name__ == '__main__':
    unittest.main()
