# ai_ats — Flutter frontend

The AI-powered applicant-ranking app's Flutter client (Material 3). Clean
architecture: `domain → data → controllers → screens`, with `navigation`,
`widgets`, and `theme` shared across screens. State management uses Riverpod
(hooks_riverpod) with get_it + injectable for DI.

## Features

- **Jobs** — list, create (paste JD text and/or upload a PDF/DOCX/TXT file),
  search, swipe-to-delete, and detail with structured requirements.
- **Candidates** — batch CV upload with live import progress, per-candidate
  detail, delete, and individual ranking.
- **Rankings** — best-match-first list with scores, buckets, and expandable
  reasoning (rules or LLM).
- **Search** — job search, candidate search, and a unified search screen that
  queries jobs and candidates at once.
- **Chat** — recruiter copilot with streaming (SSE) answers, source citations,
  and candidate result cards.
- **Settings** — light/dark theme, per-provider API-key configuration for the
  chat models, and a **Help & Guidance** center. Help is data-driven
  (`lib/help/`): categories expand in place to show guidance sections and
  FAQ answers, and a local search filters categories and FAQ entries live.

## Run

```bash
flutter pub get
flutter run
```

The app calls `http://127.0.0.1:8000/api` by default. Override with:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

Start the backend first — see [../docs/setup-and-testing.md](../docs/setup-and-testing.md).

## Build

```bash
../scripts/run_script.sh frontend/build_apk   # Android release APKs, split per ABI
../scripts/run_script.sh frontend/build_web   # Web release bundle → build/web
```

Both build scripts point the app at a backend API base URL. Pass
`--api-base <url>` (e.g. `--api-base https://recruitment-app-z4kg.onrender.com/api`)
to pick one explicitly, or let the script prompt from a menu of known backends
(Local, Android emulator, deployed Render instance).

## Test

```bash
flutter analyze
flutter test   # ~128 tests (use flutter test, not dart test)
```

## Structure

```
lib/
├── main.dart        # bootstrap: DI init, provider overrides, GoRouter
├── router.dart      # go_router route table (derived from AppRoute)
├── providers.dart   # Riverpod providers
├── di.dart / di.config.dart   # get_it + injectable wiring (generated)
├── domain/          # models, repository interfaces, use cases
├── data/            # dio ApiClient, API paths, data sources, repo impls
├── controllers/     # Riverpod controllers/notifiers per screen
├── navigation/      # AppRoute enum, AppNavigator interface, go_router impl
├── help/            # Help & Guidance: models, static content data, UI
├── screens/         # one file per screen
├── widgets/         # shared UI components
└── theme/           # Material 3 theme + theme-mode controller
```

See [../docs/04-folder-structure.md](../docs/04-folder-structure.md) for the
full tree.