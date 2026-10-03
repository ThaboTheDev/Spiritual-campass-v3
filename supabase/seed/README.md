# Centre seed import

The source directory was not included with the product brief. `centres.csv` is a header-only template by design; do not fill it with guessed data. Obtain the approved directory of exactly 88 centres, then replace the template while retaining the exact columns and CSV header:

`name,region,address,phone,latitude,longitude`

From the repository root, with the target Supabase database already migrated:

```sh
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/seed/seed_centres.sql
```

The SQL script uses PostgreSQL `\copy`, runs in a transaction, and aborts unless it imports exactly 88 records. It truncates/replaces the directory; run it only with the approved complete source CSV. Coordinates are checked by the database. `centres` has no `anon` or `authenticated` RLS policy; clients must use the authenticated Dart API.

For a local Supabase project, apply migrations with `supabase db reset` and then run the import command. Confirmation emails are disabled in `supabase/config.toml`; also switch them off in the hosted dashboard as noted there.
