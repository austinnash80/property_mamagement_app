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
