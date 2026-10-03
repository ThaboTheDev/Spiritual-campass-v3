# Deployment and local operations

## Toolchain and workspace

Use Dart 3.11+ and Flutter 3.41+ (CI pins Flutter 3.41.0). Exact direct dependency versions are kept in these files:

- `pubspec.yaml` — Pub workspace root.
- `packages/core/pubspec.yaml` — pure Dart shared core.
- `apps/api/pubspec.yaml` — Shelf API and API tests.
- `apps/app/pubspec.yaml` — Flutter app and app tests.

From the repository root:

```sh
cd apps/app && flutter pub get
cd ../..
dart format --output=none --set-exit-if-changed packages/core/lib packages/core/test apps/api/lib apps/api/bin apps/api/test apps/app/lib apps/app/test
dart analyze packages/core
(cd packages/core && dart test)
dart analyze apps/api
(cd apps/api && dart test)
(cd apps/app && flutter analyze && flutter test)
```

Flutter, Dart, Supabase CLI, Docker, and platform SDK execution was not available during initial authoring; run these checks in CI before merging. `flutter pub get` creates the workspace lockfile and the generated native plugin registrants. Do not commit populated `.env` files or build outputs.

## Supabase

1. Create a Supabase project in a region appropriate for Lesotho/South Africa.
2. Apply `supabase/migrations/202610030001_core_schema.sql` with `supabase db push` (or the SQL editor after reviewing it).
3. Configure Supabase Auth email-confirmation behavior and redirect allowlists to match the app. Add the PWA callback origin and `tshkcompass://auth/callback` for native builds.
4. Supply an approved, authoritative 88-row centre CSV and import it using `supabase/seed/README.md`. Until supplied, the app intentionally shows an empty directory.
5. Verify account deletion and data-retention behavior with POPIA/South African accounting advice. Current foreign keys delete linked app payment rows with the account.

Keep the Supabase service-role key and HS256 project JWT secret in the backend secret store only. The Flutter app uses only the public anon key.

## Local API

Copy `apps/api/.env.example` to an untracked local environment file or export its values. Replace every placeholder. Use sandbox credentials and `APP_ENV=development` for local HTTP URLs.

```sh
cd apps/app && flutter pub get
cd ../..
dart run apps/api/bin/server.dart
```

The Shelf server listens on `0.0.0.0:$PORT` (default 8080). The local example PWA origin is `http://localhost:5000`; run the Flutter web app on that origin or update `PWA_ORIGIN`. CORS compares the exact configured origin. For PayFast ITN tests the notify endpoint must be publicly reachable and configured in the PayFast sandbox; never expose a development server without authentication/ingress controls.

Run the app from `apps/app` with public build-time configuration:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

Use `--dart-define=SUPPORT_EMAIL=...` only for a public monitored contact. For a store-policy review build, also set `--dart-define=STORE_BUILD=true`; that build deliberately disables PayFast presentation/checkout but still needs an approved native billing implementation before App Store/Play submission.

## Dart API container

Build from the repository root so the Docker build can see the shared Pub workspace:

```sh
docker build -f apps/api/Dockerfile -t tshk-compass-api:local .
```

The image compiles `apps/api/bin/server.dart` as a Dart AOT executable and runs as a non-root user. Inject all API secrets as runtime environment variables; do not use Docker build arguments for secrets. Required values are documented in `apps/api/.env.example`.

## Cloud Run — primary

Use Cloud Run in `africa-south1`. Prefer an external HTTPS load balancer with Cloud Armor, Cloud Run ingress set to `internal-and-cloud-load-balancing`, and direct `run.app` access disabled/blocked where supported. The API's ITN IP resolver trusts forwarded addresses only when the direct peer is in `TRUSTED_PROXY_CIDRS`; verify the actual request path and source addresses from Cloud Run logs before enabling PayFast.

```sh
# Build and publish from the repository root.
gcloud builds submit --tag "REGION-docker.pkg.dev/PROJECT_ID/compass/tshk-api:VERSION" \
  --project PROJECT_ID

gcloud run deploy tshk-compass-api \
  --image "REGION-docker.pkg.dev/PROJECT_ID/compass/tshk-api:VERSION" \
  --project PROJECT_ID \
  --region africa-south1 \
  --platform managed \
  --allow-unauthenticated \
  --ingress internal-and-cloud-load-balancing \
  --port 8080 \
  --min 0 --max 10 \
  --set-env-vars "APP_ENV=production,PORT=8080,SUPABASE_URL=https://YOUR_PROJECT.supabase.co,PWA_ORIGIN=https://YOUR_PWA_HOST,API_BASE_URL=https://YOUR_API_HOST,PAYFAST_MERCHANT_ID=YOUR_8_DIGIT_ID,PAYFAST_SANDBOX=false,MAX_BODY_BYTES=65536" \
  --set-secrets "SUPABASE_SERVICE_ROLE_KEY=supabase-service-role:latest,SUPABASE_JWT_SECRET=supabase-jwt-secret:latest,PAYFAST_MERCHANT_KEY=payfast-merchant-key:latest,PAYFAST_PASSPHRASE=payfast-passphrase:latest"
```

`REGION` in the Artifact Registry image reference is your registry region; the Cloud Run service region remains `africa-south1`. `--allow-unauthenticated` is needed for the PWA and PayFast notify route; application endpoints still require Supabase bearer tokens. Restrict ingress through the load balancer, apply Cloud Armor/rate limits, and test health, CORS, auth, and PayFast ITN behavior. Configure the exact `PAYFAST_ALLOWED_CIDRS` and `TRUSTED_PROXY_CIDRS` only after checking current PayFast and Google Cloud documentation for the selected path.

Use Secret Manager versions and a dedicated least-privilege runtime service account. Do not echo secrets in deployment logs. Configure Cloud Run concurrency, memory, min instances, and request timeout from observed traffic. Alert on health failures, ITN verification failures, repeated 5xx responses, and exhausted validation timeouts.

## Fly.io / Render alternatives

Both alternatives can run the same Docker AOT image. Set `PORT` to the platform-provided port and supply the same backend environment/secrets. Keep TLS enabled, restrict direct origin access where possible, configure forwarded-header trust narrowly, and test PayFast's source IP handling against the actual proxy chain before production. Use a managed Postgres/Supabase project separately; the container itself is stateless.

## Flutter Web PWA hosting

Build with public defines from `apps/app`:

```sh
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

Deploy `apps/app/build/web` (Flutter output is ignored by Git) to any HTTPS static host. Set SPA fallback/rewrite to `index.html`, serve `manifest.json` and `icons/` correctly, and permit the API origin through its exact CORS configuration. Vercel may host this static output only; do not add a Vercel backend/function configuration for the Dart API. The web sensor and geolocation interfaces require HTTPS.

## Release gates

- Run all commands in the workspace section and the GitHub Actions workflow.
- Verify NOAA WMM2025 vectors and a physical compass calibration on target devices.
- Perform real sandbox PayFast subscription and ITN tests, including zero trial, R100 renewal, cancellation, duplicate delivery, and failed validation.
- Confirm PayFast subscription cancellation/support operations and merchant key treatment.
- Supply the verified centre directory, monitored privacy/support contact, approved privacy notice, and legally reviewed deletion/retention policy.
- Implement and test StoreKit/Play Billing as required before any store submission. `STORE_BUILD=true` is a guardrail, not an approval or billing integration.
- Validate Android/iOS packaging on Android SDK and macOS/Xcode runners; no mobile build was executed during authoring.
