# Working on the Nash Family app

This repo is a Rails 6.1 app (Ruby 3.2.11, Postgres) with several sections.
**You only work on the Family App** (`/family`, titled "Nash Family"). The rest of
the app (property management, accounting, bookings, portfolio, design, users and
logins) is off limits. Don't read it in order to change it, and don't edit it.

A check on every pull request (`bin/family-guard`) rejects any change outside these
paths, so keep to them:

- `app/models/family.rb`, `app/models/family/`
- `app/controllers/family/`, `app/controllers/concerns/family_*.rb`
- `app/views/family/`, `app/views/layouts/family.html.erb`
- `app/services/family/`, `app/helpers/family/`
- `config/routes/family.rb`, `config/initializers/family_*.rb`, `lib/tasks/family_*.rake`
- `test/{controllers,models,services,helpers,fixtures}/family/`
- New migrations in `db/migrate/` whose file name contains `family`, plus the
  matching `db/schema.rb` update

If a request needs anything else (the `users` table, a new gem, `Gemfile`, shared
layouts or `app/views/application/`, `public/`, CSS or JS outside the family views,
config), **stop and say so in your summary**: "This needs Austin to change X."
Don't work around it.

## Database changes

- Only through migrations. Every family table is prefixed `family_`. The `Family`
  module sets `table_name_prefix`, so `Family::Thing` maps to `family_things`.
- A migration may only touch `family_` tables. It can add a foreign key *to*
  `users` (see the existing family migrations), but must never change `users` or
  any other table.
- No `execute`, raw SQL, `update_all`, `delete_all` or `destroy_all` in
  migrations, and no models other than `Family::` ones.
- Never edit or delete an existing migration. Add a new one.
- After writing a migration, run `bin/rails db:migrate` and commit the
  `db/schema.rb` change with it.
- Production data is changed through the app itself, never by migration or script.

## How the Family App works

- Auth is deny by default. Every family controller inherits from
  `Family::BaseController`, which is the only thing that lets family-role accounts
  in. New controllers go in `app/controllers/family/` and inherit from it.
- The app runs in UTC. For "today" in the family section, use `Family.today`
  (Pacific), never `Date.current` or `Date.today`.
- Navigation for a feature: a card on the family home (`family/dashboard`) →
  an overview of the ways in → the filtered content. New features follow that
  shape.
- Reuse what's there: `family/shared/_dialog` for pop-up forms,
  `family/shared/_notify_checkbox` plus `notify_others_about` (from `FamilyNotifies`)
  for the "Notify Christina" option on create forms. Andie (`andie_entries`) and
  Rae (`rae_entries`) are good small examples to copy.
- Section constants (categories, sections, kinds) live in `app/models/family.rb`.
- Styling matches the rest of the site: Playfair Display SC titles, Open Sans,
  #fafafa on white, blue buttons. Keep pages simple.
- No paid or third-party API calls. There is no email sending in this app.
- To-do tasks deliberately have no due dates. Don't add them back.

## Testing

Run the family tests before you finish:

```bash
bin/rails test $(ls -d test/*/family)
```

If Postgres isn't running, start it with `service postgresql start`. Add or update
tests in `test/controllers/family/` (see `events_controller_test.rb` for the
sign-in pattern) for anything you change.

## Shipping

Open a pull request against `main`. When `family-guard` and `family-tests` pass,
it can be merged. Heroku then deploys `main` and runs the migrations
automatically, so nothing else needs to happen to deploy.

## Standing authorization for future chats

When the user asks for a Family App code change, proceed with the scoped edits,
local development/test database setup, Family migrations, checks, branch creation,
commits, pushes, and pull requests needed to complete it. When the user requests
shipping/deployment, merge after required checks pass and verify the resulting
Heroku deployment. Do not ask for the same routine authorization again within
that scope. Respect requests for review-only or no deployment.

This records workflow authorization; it cannot grant GitHub roles, override branch
protection or sandbox approvals, inject credentials, or configure future cloud
environments. Preserve the Family App boundaries above. Production data changes
still go through the app; database access does not authorize unrelated reads,
data exports, destructive operations, or changing non-family tables.

## Start each managed cloud session

Use this repository's saved cloud environment when starting a new chat. Read this
file and inspect git status before editing. Refresh origin/main before branching;
keep existing user changes. Check the environment's current access/credential
readiness rather than assuming a previous session's grants still apply.

When the preinstalled workspace tools exist, activate them in each shell that
needs Ruby, Rails, Postgres or Node:

```bash
source /workspace/.cloud-tools/activate
```

This sets PATH, LD_LIBRARY_PATH, PGHOST, BUNDLE_PATH, BUNDLE_FROZEN,
DISABLE_SPRING, PARALLEL_WORKERS and the package/cache/build settings. Do not copy
secret values into this file. If the activation script is absent, use the saved
environment setup to provision Ruby 3.2.11, the locked bundle and Postgres.

Check local Postgres with `pg_isready`. For the workspace cluster, if it is not
running, start it with:

```bash
pg_ctl -D /workspace/.cloud-tools/pgdata \
  -l /workspace/.cloud-tools/postgresql.log \
  -o '-k /workspace/.cloud-tools' start
```

Use the local development/test databases for Rails checks. A production
DATABASE_URL must never be used for tests, db:prepare, db:reset, or schema loads.
With a new local database, run the required Rails database preparation in the
appropriate local environment, then the Family tests above. Do not delete a
cluster or remove lock files merely because startup fails; diagnose it first.

## Persistent access setup (environment settings, not repository secrets)

A maintainer must save credentials and network access in the cloud environment
configuration used by new chats. Session approvals are not permanent grants.

- GitHub: connect an identity with repository read/write, pull-request creation
  and merge permissions for `austinnash80/property_mamagement_app`. Permit
  `github.com` and `api.github.com`. Use the injected GitHub authentication;
  verify with a harmless repository API request. A proxy placeholder can make
  `gh auth status` misleading, so diagnose the actual API result.
- Standard Heroku deployment: GitHub integration deploys `main` after CI and
  runs release migrations. No local HEROKU_API_KEY or production database URL is
  needed for this route. App: `nash-property-management-app`.
- Optional direct Heroku diagnostics: provision the Heroku CLI and bind
  HEROKU_API_KEY as an environment secret for an identity allowed to access this
  app. Set the nonsecret HEROKU_APP_NAME to `nash-property-management-app` and
  pass the app explicitly to commands. Permit `api.heroku.com`; permit the app
  hostname for HTTP verification. Inspect the required endpoints for additional
  features before requesting further network access.
- Optional production database diagnostics: a maintainer must provision a
  database role limited to the Family tables and bind its connection string as
  FAMILY_READONLY_DATABASE_URL in environment secrets. Require TLS and grant
  TCP access only to the actual database hostname/port (or the configured VPN).
  Do not invent a hostname, use broad wildcard grants, or substitute the app's
  full-access DATABASE_URL. This variable is for explicit diagnostic commands,
  not a global Rails environment setting. Local tests need no production access.
- Never commit or print API keys, connection strings, passwords, `.env` files,
  full process environments, or Heroku config dumps. If a credential or grant is
  missing, report its name and where it must be configured; do not claim access
  was installed by editing this document.

## Verify shipping

Repository: `austinnash80/property_mamagement_app`.
Family URL: https://nash-property-management-app.herokuapp.com/family

Open the PR against main and wait for `family-guard` and `family-tests` before
merging. Heroku also waits for main's CI. After merge, query GitHub deployments
for the exact merge SHA, then its deployment statuses. Wait for success or report
the failure/pending state accurately; a merge alone does not verify deployment.

The Family guard rejects AGENTS.md changes from Family contributors. This setup
document was explicitly requested by the user, but that does not bypass the
server-side check: Austin must land this documentation change through the
repository's owner workflow. Do not change or disable the guard to land it.
