# Flutter client

`apps/app` contains the iOS/Android/Web client. It talks to Supabase Auth with the public anon key and to the Dart API with the current Supabase access token. No service-role key, JWT signing secret, or PayFast passphrase belongs in this package.

## Configuration

Run from `apps/app` after resolving the Pub workspace:

```sh
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST \
  --dart-define=SUPPORT_EMAIL=privacy@example.org
```

`SUPPORT_EMAIL` is optional and public. The app checks required values and shows a configuration screen if any are missing. Add web redirect URLs and `tshkcompass://auth/callback` to the Supabase Auth redirect allowlist. Configure the email provider to match whether email confirmation is enabled.

For App Store / Play Store policy-review builds, use `--dart-define=STORE_BUILD=true`. This removes access to the PayFast checkout route and all PayFast price/purchase text. It does not implement StoreKit or Play Billing; see the release blocker in `../../ASSUMPTIONS.md`.

## Platform behavior

- Native compass: `flutter_compass` plus orientation correction; no background location or motion permission is requested.
- Web compass: conditional `package:web`/`dart:js_interop` adapter; an iOS permission request is made only by the user's tap. Web motion and geolocation require HTTPS.
- GPS course is a fallback only; location permission is while-in-use. Manual decimal-degree coordinates are validated and stored in local preferences; device backup behavior follows the OS settings.
- PayFast custom checkout uses a native WebView on iOS/Android and a browser form on web. The browser-visible merchant key is required by PayFast's documented custom form; passphrase and server credentials remain API-only.
- Five tabs: Compass, Centres, Membership, Profile, and Settings. Unavailable centre data is shown as an honest empty state.

## Tests and build

```sh
flutter analyze
flutter test
flutter build web --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST
```

Add `--dart-define=STORE_BUILD=true` for store-policy builds. The PWA manifest and icons live in `web/`; deploy the contents of `build/web` with HTTPS and SPA fallback to `index.html`. Native builds require Android SDK/Gradle or macOS/Xcode/CocoaPods. Validate them on those toolchains before release.
