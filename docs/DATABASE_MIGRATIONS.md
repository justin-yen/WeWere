# Database migrations

The executable migration directory is `supabase/migrations` at the repository root.
Use Supabase CLI **2.84.2**, Docker, and PostgreSQL 17 (matching production).

## Local development

```bash
supabase start
supabase migration new describe_the_change
# Edit supabase/migrations/<timestamp>_describe_the_change.sql
supabase migration up --local
supabase test db --local
```

Use `supabase db start` instead of `supabase start` when only testing PostgreSQL.
Use local Supabase credentials for the development backend; the existing backend
example configuration points at production and must be overridden. Database tests
here use fake fixtures and never copy production user data.

Run the same validation as CI:

```bash
bash scripts/test-migrations.sh
```

This **clears local database data**. It tests a clean rebuild, then recreates the
baseline, inserts an existing host/event fixture, applies pending migrations, and
verifies existing data survives. Every database target is explicitly local.
Add pgTAP tests to `supabase/tests` for future schema behavior. Add representative
upgrade fixtures and assertions under `scripts/migration-fixtures` for data changes.

Migrations have unique timestamp prefixes. Once merged, do not modify, rename, or
delete them: write another migration. CI checks this against the base revision.

## CI release flow

`.github/workflows/database.yml` runs the local clean-install and upgrade suite on
every branch push and pull request. Feature branches never receive remote database
credentials and cannot change staging or production.

A push to `staging`, after successful validation, synchronizes the shared staging
Supabase project:

1. If the remote migration history is a prefix of the release candidate, CI applies
   only pending migrations and preserves staging data.
2. If a previously applied candidate migration was removed or reordered, CI rebuilds
   the disposable staging public database from the branch's migration history. This
   is the automated staging rollback path; it intentionally clears staging app data.
3. CI runs the pgTAP database tests against the hosted staging database.

A push to `main`, after successful validation, applies pending migrations to
production. Production is never reset and has no automatic down migration. After
each environment's database job passes, CI packages only the backend runtime files,
deploys them to the matching Railway service, and verifies its health endpoint.

Use `staging` as the integration/release-candidate branch. Merge only completed
feature branches into it. During release validation, accept only release fixes.
After validation, merge the exact staging commit into `main`.

Candidate migrations may be removed from `staging` while deciding the release.
Migrations already present on `main` are immutable, including when validating a PR
whose base is `staging`.

## GitHub environments

Create protected GitHub environments named `staging` and `production`. Configure
the same secret names in each environment, using that environment's Supabase values:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID`
- `SUPABASE_DB_PASSWORD`
- `RAILWAY_TOKEN`: a token authorized to deploy the existing WeWere project.

Restrict `staging` deployments to the `staging` branch and `production` deployments
to `main`. The workflow also compares each secret project ID with the reviewed
non-secret project ID in the workflow and refuses a mismatch. It explicitly refuses
to use the production project from the staging job.

Make `validate` a required check on both branches. Deployment jobs serialize per
environment and do not cancel an in-progress database operation.

### Production configuration

The production job uses a GitHub `production` environment restricted to the `main`
branch. Configure these environment secrets in GitHub Settings → Environments →
production:

- `SUPABASE_PROJECT_ID`: `xsvscfqnzybdxptijmqs`.
- `SUPABASE_ACCESS_TOKEN`: a Supabase access token with access to this project.
- `SUPABASE_DB_PASSWORD`: the production database password, not an API/service key.

Do not paste credentials into source files, PRs, chat, or SQL migrations. A failed
validation blocks deployment; a failed migration fails the workflow. Diagnose and
rerun or ship a corrective migration. The production CLI checks migration history
and applies only pending migrations.

The workflow deploys the database before the API so new code never starts against
an older schema. Prefer additive changes compatible with the previously deployed
backend and older iOS clients because the old API can continue serving traffic while
the migration and new Railway deployment run. For destructive changes, use an
expand/migrate/contract sequence across separate releases.

## One-time baseline transition

Read-only inspection on 2026-09-12 found no production migration-history table and
schema changes absent from the original numbered SQL. The new timestamped baseline
captures the actual production public schema, including its existing policies and
constraints; it is not a redesign of those policies. Old scripts are retained in
`supabase/legacy-migrations` for reference only. The location-coordinate migration
formerly under `backend/supabase/migrations` is already represented in the baseline.

The optional-event-end-time change is a separate pending migration. It has not been
applied to production by this setup.

On the first deployment from main, `scripts/deploy-migrations.py`:

1. Checks that it is running on a production-branch push in GitHub Actions.
2. Checks production migration history.
3. If history is empty, exports the current public schema to a temporary file and
   compares it against the reviewed baseline. It does not log the schema dump.
4. If they match, records **only the baseline** as applied. It does not replay the
   baseline DDL on production. If they differ, it stops before modifying history.
5. Runs a dry run, then applies the pending migrations.

Existing unexpected migration history also stops deployment. Never blindly repair
all versions as applied. The baseline comparison intentionally excludes the
existing `apply_retro_filter` webhook, which contains environment-specific
credentials. That webhook is not committed or recreated locally. Storage buckets,
Realtime publication membership, cron jobs, auth settings, and Edge Function
configuration are outside this public-schema baseline and remain separately
managed. Local database tests do not exercise those integrations.

## Rollback and recovery

There is **no automatic, data-preserving production undo** in this workflow.
Supabase's `migration down` is a reset/rebuild operation, not a safe inverse SQL
migration for a live database. `migration repair --status reverted` only changes
history; it does not undo SQL. Never use remote reset as production rollback.

For a deployed change, create a new corrective migration:

```bash
supabase migration new correct_previous_change
# Write explicit corrective SQL and any necessary data handling.
bash scripts/test-migrations.sh
# Commit, open a PR, merge to main after checks pass.
```

A Git revert alone does not revert the database. For the optional end-time change,
setting `NOT NULL` again would fail once open-ended events exist; a correction must
first deliberately resolve those rows. Do not invent end times automatically.

Reversing a DROP or destructive data update cannot recover deleted data. Use
Supabase backups/PITR where enabled and a reviewed restore plan for those incidents.
This setup does not purchase or enable PITR. Keep production changes small and
prefer an additive compatibility window so reverting application code remains safe.

Staging behaves differently because its app data is disposable. Reverting a feature
from the `staging` branch removes its candidate migration; the next push detects that
the hosted history is no longer a prefix and rebuilds staging. Supabase Auth users,
Storage objects, Edge Function configuration, cron jobs, and other objects outside
the migrated public schema are not recreated by this workflow. Revalidate any of
those integrations after a staging rebuild. Do not store unique test evidence only
in staging.

References:
- https://supabase.com/docs/guides/deployment/managing-environments
- https://supabase.com/docs/guides/deployment/database-migrations
- https://supabase.com/docs/guides/local-development/declarative-database-schemas
