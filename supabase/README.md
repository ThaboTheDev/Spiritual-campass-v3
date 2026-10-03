# Supabase

Apply `migrations/202610030001_core_schema.sql` with the Supabase CLI or the SQL editor. The migration enables RLS, creates the owner-only member read policy, leaves centres/payments inaccessible to client roles, and adds the service-role-only idempotent PayFast transaction RPC.

The auth-user trigger creates a seven-day trial member row, while `/api/me` also performs a conflict-safe lazy insert. Email confirmation is disabled locally in `config.toml`; hosted projects must also have **Authentication → Providers → Email → Confirm email** switched off in the dashboard.

Centre import instructions and the exact 88-row validation are in `seed/README.md`. An authoritative source CSV is still required.
