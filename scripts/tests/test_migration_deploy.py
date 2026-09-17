import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('deploy', Path(__file__).parents[1] / 'deploy-migrations.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
ENV = dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='push', GITHUB_REF='refs/heads/main',
           PRODUCTION_BRANCH='main', SUPABASE_ACCESS_TOKEN='test', SUPABASE_DB_PASSWORD='test',
           SUPABASE_PROJECT_ID='production', EXPECTED_SUPABASE_PROJECT_ID='production')


class DeploymentTests(unittest.TestCase):
    def test_reject_local_and_pr_runs(self):
        for env in ({}, {**ENV, 'GITHUB_EVENT_NAME': 'pull_request'},
                    {**ENV, 'GITHUB_REF': 'refs/heads/feature'}):
            with patch.dict(os.environ, env, clear=True), patch.object(deploy, 'run') as run:
                with self.assertRaises(RuntimeError):
                    deploy.deploy()
                run.assert_not_called()

    def test_rejects_unreviewed_project(self):
        with patch.dict(os.environ, {**ENV, 'SUPABASE_PROJECT_ID': 'wrong'}, clear=True), \
                patch.object(deploy, 'run') as run:
            with self.assertRaises(RuntimeError):
                deploy.deploy()
            run.assert_not_called()

    def test_existing_baseline_only_pushes_pending(self):
        with patch.dict(os.environ, ENV, clear=True), patch.object(deploy, 'query', side_effect=[
                [{'history_exists': True}], [{'version': deploy.BASELINE}]]), patch.object(deploy, 'run') as run:
            deploy.deploy()
            self.assertFalse(any('repair' in call.args for call in run.call_args_list))
            self.assertEqual(run.call_args_list[-1].args, ('supabase', 'db', 'push', '--linked', '--yes'))

    def test_unexpected_history_stops(self):
        with patch.dict(os.environ, ENV, clear=True), patch.object(deploy, 'query', side_effect=[
                [{'history_exists': True}], [{'version': '001'}]]), patch.object(deploy, 'run') as run:
            with self.assertRaises(RuntimeError):
                deploy.deploy()
            self.assertFalse(any('push' in call.args for call in run.call_args_list))

    def test_first_deploy_checks_schema_before_repair(self):
        for matches in (False, True):
            def fake_run(*args, **kwargs):
                if 'dump' in args:
                    Path(args[-1]).write_text(deploy.BASELINE_FILE.read_text() if matches else 'CREATE TABLE unexpected();')
            with patch.dict(os.environ, ENV, clear=True), patch.object(deploy, 'query', return_value=[
                    {'history_exists': False}]), patch.object(deploy, 'run', side_effect=fake_run) as run:
                if matches:
                    deploy.deploy()
                else:
                    with self.assertRaises(RuntimeError):
                        deploy.deploy()
                self.assertEqual(any('repair' in call.args for call in run.call_args_list), matches)
                self.assertEqual(any('push' in call.args for call in run.call_args_list), matches)

    def test_normalizer_excludes_only_known_environment_webhook(self):
        self.assertEqual(deploy.normalize_schema('-- comment\nCREATE TABLE x();\n'), 'CREATE TABLE x();')
        self.assertEqual(deploy.normalize_schema('CREATE OR REPLACE TRIGGER "apply_retro_filter" dummy;\nCREATE TABLE x();'), 'CREATE TABLE x();')
        self.assertIn('other', deploy.normalize_schema('CREATE OR REPLACE TRIGGER "other" dummy;\n'))


if __name__ == '__main__':
    unittest.main()
