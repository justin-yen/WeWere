# WeWere staging backend

Railway project: `WeWere` (`909ea8c4-4945-4a4f-813e-41477c815b68`).

- Environment: `staging` (`2b0aab9f-6be8-4769-9f2e-298fc2950901`)
- Service: `api-staging` (`a9afd183-0c24-4bef-ac27-b86aac227c97`)
- API: https://api-staging-staging-62e9.up.railway.app
- Health endpoint: `/`
- Supabase: `WeWere Staging` (`rmehfwdzxyrsdpvwgozm`)

The service already existed when inspected September 16, 2026. Its anonymous and service-role keys were verified against staging Supabase without exposing their values. Test endpoints are enabled with `APP_ENV=development` and `ENABLE_TEST_ENDPOINTS=true`; these settings are for the isolated staging environment only. Twilio variables and an internal API secret are configured, but SMS delivery has not been tested.

## Deploying the backend

The normal path is the release workflow: a push to `staging` validates migrations,
synchronizes the staging database, then deploys `api-staging`. The command below is
for diagnosing or recovering CI, and should use the same reviewed commit.

Deploy only the backend directory, explicitly selecting the service/environment/project. Exclude `.env`, virtual environments, caches, local database files, and credentials from any deployment archive. The September 16 deployment used a clean temporary directory containing only application Python modules, `requirements.txt`, `runtime.txt`, `Procfile`, and `railway.json`.

```sh
railway up /path/to/clean-backend --path-as-root \
  --project 909ea8c4-4945-4a4f-813e-41477c815b68 \
  --environment staging --service api-staging --detach
```

The September 16 release fixes first-login failures: password/identity updates invalidate previously generated login links, so the backend now generates a fresh link after those updates. The local backend suite has 27 passing checks.

Deployment `f87d896e-442a-4cb6-b0cb-80f7eef3ba1e` reached SUCCESS. Live smoke checks passed for health, missing-auth rejection, internal push protection, first-time TEST916 login, existing TEST1/TEST2 login, staging token issuer, authenticated profiles/event lists, refresh, and sign-out isolation. Staging-only test identities TEST916 and stage1check0916 were created during validation; no production identities were changed.

## Simulator connection

The simulator must use this staging API URL **and** staging Supabase's URL and anonymous key. Do not embed the service-role key or internal API secret in the app. This backend setup does not change simulator configuration. Use separate app/session storage when switching environments to avoid carrying production tokens into staging.

Real SMS delivery and the remaining simulator journeys still require validation. Backend deployment does not deploy Supabase edge functions or change their scheduler/webhook configuration.
