# TaskFlow — Offline-First Task Manager

[![Flutter](https://img.shields.io/badge/Flutter-3.16%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-offline--first-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](#license)

A production-grade, offline-first mobile task manager built from scratch in **Flutter + Dart**. Inspired by Todoist's interaction model, extended with natural-language input, an LLM-powered search/parsing layer, voice capture, and bulk import from Google Sheets — all on top of a fully local SQLite data layer with zero backend dependency.

~9,000 lines of Dart across 40 files, organized into a clean store/database/UI separation with `ChangeNotifier`-based state management.

---

## Why this exists

Most "todo app" portfolio projects are CRUD wrappers around a single table. This one isn't — it's an exercise in handling the problems that actually show up once an app has real users: filtered-list reordering that has to stay consistent with a global ordering, recurring tasks that have to survive month-end date math correctly, project/label deletion that has to cascade without orphaning data, notification scheduling that has to avoid ID collisions, and a natural-language parser that has to degrade gracefully when an external AI service isn't available.

---

## ✨ Features

| Category | What it does |
|---|---|
| **Natural language input** | Type `"Call Alex tomorrow at 3pm #work @calls p1"` and it's parsed into a due date, time, project, label, and priority — live preview chips show the parse as you type. |
| **AI-powered search** | Plug in a Groq API key and search becomes semantic: `"overdue work stuff"` or `"things due this week tagged urgent"` resolve to structured filters instead of plain substring matching. Falls back to keyword search automatically if the AI call fails or no key is set. |
| **Voice capture** | On-device speech-to-text feeds straight into the quick-add parser. |
| **Recurring tasks** | Daily / weekly / monthly recurrence with correct calendar math — monthly recurrence clamps to the target month's actual last day instead of silently overflowing into the wrong month. |
| **Sub-tasks & comments** | Tasks can have nested sub-tasks and a threaded comment log. |
| **Projects & sections** | Custom emoji + color, sections within a project, progress bars, archiving, favorites. |
| **Labels** | Custom-colored tags, filterable across every project and view. |
| **Bulk import** | Pull tasks straight from a Google Sheet, preview them, and selectively import — including resolving/creating matching projects and labels automatically. |
| **Smart views** | Today (overdue + due today), Inbox, Upcoming (7-day), Search, Completed, per-Project, per-Label. |
| **Reminders & notifications** | Per-task reminders scheduled relative to due time, plus a configurable daily digest. |
| **Stats & gamification** | Completion streaks, a karma score, and a 7-day activity chart — computed with a single aggregate query, not N sequential round-trips. |
| **Multi-provider auth** | Google Sign-In wired end-to-end; Microsoft/Apple auth scaffolding included for extension. |
| **Theming** | Dark / Light / System, with a full Todoist-inspired design token system. |
| **Fully offline** | SQLite via `sqflite`. No backend, no account required to use the core app — auth is optional. |

---

## 🏗 Architecture

```
lib/
├── main.dart                       # Entry point, app bootstrap, sign-in/onboarding gate
├── app_shell.dart                  # Bottom nav + side drawer shell
│
├── constants/
│   └── theme.dart                  # Design tokens: colors, spacing, ThemeData
│
├── models/
│   └── index.dart                  # Task, Project, Label, Section, Comment, Settings
│
├── db/
│   └── database.dart               # SQLite schema, migrations, all queries (AppDatabase)
│
├── store/                          # ChangeNotifier-based state, one source of truth per domain
│   ├── task_store.dart             # Tasks, recurrence engine, reordering
│   ├── project_store.dart          # Projects + LabelStore
│   ├── label_store.dart            # Re-exports LabelStore (see project_store.dart)
│   ├── settings_store.dart         # SharedPreferences-backed app settings
│   └── auth_store.dart             # Sign-in state persistence
│
├── utils/
│   ├── nlp_parser.dart             # Local regex-based natural-language parser
│   ├── groq_service.dart           # Groq LLM integration: AI search + AI task parsing
│   ├── voice_service.dart          # Speech-to-text wrapper
│   ├── notifications.dart          # Local push notification scheduling
│   ├── google_auth_service.dart    # Google Sign-In flow
│   ├── other_auth_services.dart    # Microsoft / Apple auth scaffolding
│   ├── sheets_import_service.dart  # Google Sheets fetch + candidate parsing
│   ├── date_utils.dart             # Date formatting helpers (AppDateUtils)
│   ├── stats_engine.dart           # Karma / streak computation
│   └── local_secrets.dart          # Gitignored — local-only API key (never committed)
│
├── widgets/
│   ├── task_item.dart              # Swipeable task row
│   ├── quick_add_sheet.dart        # NLP quick-add bottom sheet w/ live parse preview
│   ├── task_detail_sheet.dart      # Full task editor (draggable sheet)
│   ├── reschedule_sheet.dart       # Reschedule quick-picker
│   ├── empty_state.dart            # Generic empty state
│   └── priority_badge.dart         # P1–P4 flag chip
│
├── screens/
│   ├── today_screen.dart
│   ├── inbox_screen.dart
│   ├── upcoming_screen.dart
│   ├── search_screen.dart          # Plain + AI search, unified result refresh
│   ├── settings_screen.dart
│   └── completed_screen.dart
│
└── features/
    ├── projects/                   # List, detail, create
    ├── labels/                     # Label management
    ├── auth/                       # Login screen
    ├── onboarding/                 # First-run flow
    ├── maintenance/                # Data maintenance utilities
    └── sheets_import/              # Google Sheets bulk import flow
```

**Design principles this codebase follows:**

- **Single source of truth per domain.** `TaskStore`, `ProjectStore`, and `SettingsStore` are singletons extending `ChangeNotifier`; screens listen, never duplicate state.
- **Database is the only place that knows SQL.** `AppDatabase` is the sole owner of the `sqflite` instance and schema; stores never construct raw queries.
- **Global invariants stay global.** Task ordering (`order_index`) is a single ordering shared across every filtered view — reordering within a filtered list redistributes that list's *existing* slots rather than overwriting them with local indices, so reordering "Today" can't silently scramble order in "Upcoming."
- **Cascades are explicit.** Deleting a project reassigns its tasks to Inbox inside a transaction (matching what the confirmation dialog promises the user); deleting a label strips itself from every task's label set, both at the DB layer and in already-loaded in-memory state.
- **Graceful AI degradation.** Every Groq-backed feature (search, NLP parsing) has a deterministic local fallback and never blocks core functionality if the API is unreachable or unconfigured.

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.16+ | Bundles Dart 3.2+ |
| Android Studio | latest | For Android SDK, platform tools, and an emulator |
| JDK | 17 | Usually bundled with Android Studio's JBR |

### 1. Clone and install dependencies

```bash
git clone <your-repo-url>
cd todolist
flutter pub get
```

### 2. (Optional) Configure the Groq API key for AI search/parsing

AI features degrade gracefully if skipped — the app works fully without this step.

```bash
flutter run --dart-define=GROQ_API_KEY=your_key_here
```

Alternatively, for local development convenience, set `kLocalGroqApiKey` in `lib/utils/local_secrets.dart` (already gitignored). **Never commit a real key** — see [Security](#-security-notes) below.

### 3. Run

```bash
flutter devices
flutter run -d <device-id>
```

### 4. Build a release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

For Google Play distribution, build an App Bundle instead:

```bash
flutter build appbundle --release
```

---

## 🗄 Database

SQLite via `sqflite`, created automatically on first launch.

**Tables:** `tasks`, `projects`, `labels`, `task_labels`, `sections`, `comments`

An `Inbox` project (`id = 'inbox'`) is seeded on first run and can never be deleted — every task that loses its parent project (e.g. via project deletion) is reassigned here, never silently orphaned.

---

## 🧠 Natural Language Parsing

Two layers, used depending on configuration:

**Local parser** (`nlp_parser.dart`) — always available, zero network dependency, regex-based:

| Input | Parsed as |
|---|---|
| `Call Alex tomorrow at 3pm` | dueDate: tomorrow, dueTime: 15:00 |
| `Buy groceries #shopping @errands` | project: shopping, label: errands |
| `Finish report p1 !!!` | priority: 1 |
| `Team standup every week` | recurring: WEEKLY;INTERVAL=1 |
| `Submit proposal next Monday` | dueDate: next Monday |
| `Fix bug in 2 hours` | dueTime: now + 2h |
| `Remind me 30 minutes before` | reminderMinutes: 30 |

**AI parser** (`groq_service.dart`) — used for AI search queries and richer task parsing when a Groq key is configured; handles loose, conversational phrasing the regex parser can't.

---

## 🔔 Notifications

- Per-task reminders scheduled at `dueDate/dueTime − reminderMinutes`.
- Configurable daily digest (default 9:00 AM).
- Notification IDs are derived from a 32-bit hash of the task UUID, keeping collision risk between unrelated tasks' reminders negligible.
- Reminders automatically reschedule when a task's due date/time changes, and cancel when the task is deleted or completed.

---

## 🎨 Design System

| Token | Value |
|---|---|
| Primary | `#DC4C3E` |
| Dark BG / Surface | `#1F1F1F` / `#282828` |
| Light BG / Surface | `#FAFAFA` / `#FFFFFF` |
| P1 / P2 / P3 / P4 | `#D1453B` / `#EB8909` / `#4073FF` / `#8C8C8C` |
| Success | `#058527` |

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `sqflite` | Local SQLite database |
| `shared_preferences` | Settings & auth-state persistence |
| `flutter_local_notifications` + `timezone` | Scheduled, timezone-aware reminders |
| `flutter_slidable` | Swipe-to-act task rows |
| `fl_chart` | Stats activity chart |
| `speech_to_text` | Voice-to-text capture |
| `google_sign_in` | Google authentication |
| `http` | Groq API + Sheets API calls |
| `uuid` | Stable entity IDs |
| `intl` | Date/time formatting |
| `permission_handler` | Runtime permission requests (mic, notifications) |
| `url_launcher` | OAuth flow handoff |

---

## 🔒 Security Notes

- `lib/utils/local_secrets.dart` is gitignored and must **never** contain a real API key in any file you intend to zip, back up, or share — gitignore only stops `git add`, it does nothing to stop the file going out in an archive.
- Production builds should inject secrets via `--dart-define`, not hardcoded constants.
- Release signing keystores (`*.jks`, `*.keystore`) and `android/key.properties` are gitignored — set those up locally per the [Android signing docs](https://docs.flutter.dev/deployment/android#signing-the-app).

---

## 🧪 Testing

```bash
flutter test
flutter analyze
```

---

## 🔧 Troubleshooting

| Issue | Fix |
|---|---|
| `MissingPluginException` for sqflite | This is a mobile-only app — run on an Android emulator/device, not desktop. |
| Notifications silent on Android 12+ | Grant `SCHEDULE_EXACT_ALARM` under device Settings → Apps → TaskFlow → Permissions. |
| `pub get` fails | Confirm `flutter --version` reports 3.16+. |
| AI search always falls back to keyword search | Confirm a Groq key was passed via `--dart-define=GROQ_API_KEY=...` at run/build time. |

---

## 📋 Roadmap

- [ ] Cloud sync (Firebase / Supabase) for cross-device state
- [ ] Shared/collaborative projects
- [ ] Calendar integration
- [ ] iOS App Store release build
- [ ] Home-screen widget
- [ ] Apple/Microsoft sign-in completion (scaffolding already in place)

---

## License

MIT © 2026 Mohamed Saber — free to use, modify, and distribute. See [LICENSE](./LICENSE) for full terms.
