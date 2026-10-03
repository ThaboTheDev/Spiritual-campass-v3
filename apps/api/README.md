# Dart Shelf API

## Local run

From the repository root, set the server-only environment variables (see `DEPLOYMENT.md`) and run:

```sh
flutter pub get
dart run apps/api/bin/server.dart
```

The API binds `0.0.0.0:$PORT` (default `8080`). Startup fails fast if a required secret or URL is missing/invalid. No server secret is compiled into the app or image.

## Routes

- `GET /healthz`
- `GET /api/me` — validated Supabase JWT; conflict-safe member creation; UTC entitlement.
- `GET /api/centres` — authenticated and access-gated; private ETag/cache response.
- `POST /api/payfast/checkout` — authenticated signed custom-integration fields.
- `POST /api/payfast/notify` — ordered ITN validation and idempotent Supabase RPC.
- `DELETE /api/account/delete` — delete the authenticated Supabase Auth user.

All routes use request-ID logging, exact PWA-origin CORS, JSON errors, request-body limits, and per-IP rate limiting. ITNs are exempt from the generic 429 window to honor PayFast's acknowledgement behavior; their payload size, signature, source IP, amount, merchant, and PayFast server validation are still checked.

The server currently requires Supabase HS256 JWT signing. If asymmetric signing is enabled, deploy JWKS validation before changing project settings.
