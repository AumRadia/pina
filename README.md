# Pina – Personalized Impact & News Assistant

Pina is a Flutter application that blends curated news, personalized widgets, and AI-powered impact analysis. Users can register or sign in (including Google OAuth), pick their interests, consume news, and trigger OpenAI-powered impact summaries. The “My AI” area lets users manage custom widgets sourced from a backend marketplace.

## Features

- **Authentication**
  - Email/password login & registration.
  - Google Sign-In (client/server IDs configured in `loginscreen.dart` & `registration.dart`).
  - Profile image upload during registration.
- **Interest Selection & Trial Feed**
  - Users choose topics; a trial/news feed displays articles fetched from NewsData.io (`Apiservice`).
  - Per-article “Show Impact” button calls OpenAI’s Chat Completions API and renders the result in `ImpactAnalysisScreen`.
- **My AI Widgets**
  - `MyAiScreen` pulls saved widgets for the logged-in user from the backend (`WidgetService.getUserWidgets`).
  - Users can browse marketplace widgets, add/remove them, and see contextual UIs (search/translate modules, etc.).
  - Drawer (`HamburgerMenu`) supports language selection and a contact dialog that forwards feedback via a Telegram-enabled endpoint.

## Project Structure (key folders)

```
lib/
  data/             # Static translations (English/Hindi)
  models/           # POJOs like `NewsArticle`, `MarketWidget`
  services/         # HTTP clients (news + widget marketplace)
  screens/          # Login, registration, interests, trial feed, My AI, etc.
  widgets/          # Shared UI pieces (hamburger drawer)
assets/icons/       # Social icons used on auth screens
```

## Environment & Configuration

| Concern            | Location / Notes                                                                 |
|--------------------|----------------------------------------------------------------------------------|
| API base URL       | Hard-coded as `http://10.11.161.23:4000` in several files; move to `lib/config`. |
| OpenAI API Key     | Placeholder `_apiKey` in `trial.dart`; replace via secure storage/env.           |
| NewsData API key   | Embedded in `Apiservice.baseurl`; consider env variable.                         |
| Google Sign-In IDs | Defined in `loginscreen.dart` & `registration.dart`; ensure they match GCP app.  |

For production, prefer `.env` + build-time injection instead of literals in source.

## Getting Started

1. **Dependencies**
   ```bash
   flutter pub get
   ```
2. **Platform setup**
   - Ensure Android/iOS tooling is installed (`flutter doctor`).
   - For Android builds, update `android/local.properties` with your SDK path.
3. **Backend requirements**
   - Auth, widget marketplace, and Telegram relay expect a Node/Express backend running at the configured base URL.
   - Update `baseUrl` constants to point at your environment.
4. **Running**
   ```bash
   flutter run -d <device_id>
   ```
5. **Assets**
   - `assets/icons` are already declared in `pubspec.yaml`. Add new assets there if needed.

## Testing & Quality

- **Static analysis**: `flutter analyze`
- **Widget tests**: Add under `test/` as the UI grows. Current project doesn’t include automated tests.
- **Manual checks**
  - Auth flows (email + Google) against your backend.
  - News loading/interest selection.
  - AI impact analysis (requires valid OpenAI key + backend proxy if used).
  - Widget marketplace interactions (add/remove widgets, drawer actions).

## Extending the App

- Extract API hosts and keys into a single config service for easier environment changes.
- Add persistence for selected interests and widget caching.
- Introduce bloc/cubit or Riverpod for complex state once the widgets and feeds expand.
- Harden networking with retries, better error surfaces, and offline caching.

## Support & Contact

- Feature requests or bug reports: open a GitHub issue.
- In-app feedback: use the “Contact Us” option in the hamburger menu (sends message via backend Telegram endpoint).

---
Happy building! Contributions and suggestions are welcome. If you build new widgets or data sources, document them here so others can enable them quickly. 
