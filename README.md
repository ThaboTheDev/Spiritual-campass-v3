# TSHK Compass: Subscription Edition

A Dart monorepo for a Flutter compass PWA/mobile client, a pure-Dart geospatial and subscription core, and a Dockerised Shelf API.

## Repository map

- `packages/core` — pure Dart geo math, WMM2025, heading/state models, and entitlement rules.
- `apps/app` — Flutter iOS, Android, and web PWA client.
- `apps/api` — Dart Shelf API, Supabase service-role repository, PayFast integration, and Docker build.
- `supabase` — schema migrations, RLS, transaction RPC, and verified-CSV import workflow.
- `ASSUMPTIONS.md` — all external data, sensor, PayFast, privacy, and store-policy assumptions.
- `DEPLOYMENT.md` — local setup and Cloud Run/Fly.io/Render/static PWA deployment.

The project uses a Dart Pub workspace (Dart 3.11+ / Flutter 3.41+). Dependency versions are exact in each package's `pubspec.yaml`.

## Checks

```sh
flutter pub get
cd packages/core && dart analyze && dart test
cd ../../apps/api && dart analyze && dart test
cd ../app && flutter analyze && flutter test
```

The build toolchain must be installed; this repository intentionally contains no Node.js or hand-authored JavaScript source. Flutter's normal web build emits its own JavaScript output.

## Required production data

The authoritative 88-centre data file and privacy contact were not provided. The seed workflow rejects a directory unless exactly 88 valid rows are supplied. See `ASSUMPTIONS.md` and `supabase/seed/README.md` before launch.
