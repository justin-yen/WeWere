import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'staging_deploy', Path(__file__).parents[1] / 'deploy-staging-migrations.py'
)
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

ENV = dict(
    GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='push',
    GITHUB_REF='refs/heads/staging', SUPABASE_ACCESS_TOKEN='test',
    SUPABASE_DB_PASSWORD='test', SUPABASE_PROJECT_ID='staging',
    EXPECTED_SUPABASE_PROJECT_ID='staging',
)


class StagingDeploymentTests(unittest.TestCase):
    def test_rejects_local_pr_and_other_branch_runs(self):
        for env in ({}, {**ENV, 'GITHUB_EVENT_NAME': 'pull_request'},
                    {**ENV, 'GITHUB_REF': 'refs/heads/feature'}):
            with self.subTest(env=env), patch.dict(os.environ, env, clear=True), \
                    patch.object(deploy, 'run') as run:
                with self.assertRaises(RuntimeError):
                    deploy.deploy()
                run.assert_not_called()

    def test_rejects_production_or_unreviewed_project(self):
        for project, expected in (
            ('wrong', 'staging'),
            (deploy.PRODUCTION_PROJECT_ID, deploy.PRODUCTION_PROJECT_ID),
        ):
            env = {**ENV, 'SUPABASE_PROJECT_ID': project,
                   'EXPECTED_SUPABASE_PROJECT_ID': expected}
            with self.subTest(project=project), patch.dict(os.environ, env, clear=True), \
                    patch.object(deploy, 'run') as run:
                with self.assertRaises(RuntimeError):
                    deploy.deploy()
                run.assert_not_called()

    def test_prefix_history_applies_only_pending_migrations(self):
        with patch.dict(os.environ, ENV, clear=True), \
                patch.object(deploy, 'local_versions', return_value=['1', '2']), \
                patch.object(deploy, 'query', side_effect=[
                    [{'history_exists': True}], [{'version': '1'}],
                ]), patch.object(deploy, 'run') as run:
            deploy.deploy()
        calls = [call.args for call in run.call_args_list]
        self.assertIn(('supabase', 'db', 'push', '--linked', '--dry-run'), calls)
        self.assertIn(('supabase', 'db', 'push', '--linked', '--yes'), calls)
        self.assertNotIn(('supabase', 'db', 'reset', '--linked', '--no-seed', '--yes'), calls)
        self.assertEqual(calls[-1], ('supabase', 'test', 'db', '--linked'))

    def test_missing_or_diverged_history_rebuilds_staging(self):
        cases = [
            ([{'history_exists': False}],),
            ([{'history_exists': True}], [{'version': '1'}, {'version': 'removed'}]),
        ]
        for query_results in cases:
            with self.subTest(query_results=query_results), \
                    patch.dict(os.environ, ENV, clear=True), \
                    patch.object(deploy, 'local_versions', return_value=['1', '2']), \
                    patch.object(deploy, 'query', side_effect=query_results), \
                    patch.object(deploy, 'run') as run:
                deploy.deploy()
            calls = [call.args for call in run.call_args_list]
            self.assertIn(
                ('supabase', 'db', 'reset', '--linked', '--no-seed', '--yes'), calls
            )
            self.assertFalse(any(call[1:3] == ('db', 'push') for call in calls))
            self.assertEqual(calls[-1], ('supabase', 'test', 'db', '--linked'))


if __name__ == '__main__':
    unittest.main()
