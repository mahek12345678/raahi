# Raahi - App Scaffold

This folder contains a minimal Flutter scaffold that implements the Raahi UI blueprint:

- Five main screens: Home, Find Ride, Create Ride, My Rides, Profile.
- Theme switching with a Women-only mode (animated color shift).
- LLM service stub (uses `PPLX_API_KEY` env var if set).
- SOS bottom sheet and Notifications UI as placeholders.

NOTES & NEXT STEPS
- This scaffold is a starting point. You must integrate Firebase (Auth, Firestore, Storage), FCM, geospatial queries, AWS Lambda endpoints, and a production LLM endpoint to complete the full product.
- Do NOT commit your API keys to source control. Use environment variables or a secure secrets manager.

Environment
- Install Flutter SDK (stable channel)
- From `app/` run:

```bash
flutter pub get
flutter run
```

To enable the real LLM flow (Namaste Raahi), set an environment variable named `PPLX_API_KEY` before launching the app. Example (Linux/macOS):

```bash
export PPLX_API_KEY="pplx-REPLACE_WITH_YOUR_KEY"
export OPENAI_API_KEY="your_openai_key_here"
 # For STT (microphone) enable platform permissions as follows:
 # Android: ensure android/app/src/main/AndroidManifest.xml contains RECORD_AUDIO permission.
 # iOS: ensure ios/Runner/Info.plist contains NSMicrophoneUsageDescription.
flutter run
```

This scaffold reads `PPLX_API_KEY` via `Platform.environment`. In production you should integrate with a secure runtime config and not rely on plain environment variables.

Files of interest:
- `lib/main.dart` — app entry, theme/women-only provider, bottom nav
- `lib/screens/*` — the 5 main screens
- `lib/services/llm_service.dart` — LLM abstraction and mock behavior
- `BLUEPRINT.md` — full blueprint and next steps
