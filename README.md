<div align="center">

# ✓ TodoList

**An AI-powered task manager built with Flutter & Groq**

[![Live Demo](https://img.shields.io/badge/Live%20Demo-Try%20Now-4073FF?style=for-the-badge)](https://mhmdsabeer2029.github.io/Todo-List-MobileApp/)
[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Groq](https://img.shields.io/badge/Groq-LLaMA%203.3-orange?style=for-the-badge)](https://groq.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 🚀 Live Demo

👉 **[mhmdsabeer2029.github.io/Todo-List-MobileApp](https://mhmdsabeer2029.github.io/Todo-List-MobileApp/)**

Runs right in your browser — no install needed. Works on mobile too.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🧠 **AI Task Parsing** | Type naturally in Arabic or English — Groq extracts date, time, project, labels & priority |
| 🔍 **AI Search** | Ask *"overdue work tasks this week"* — structured smart filtering |
| ✨ **Subtask Suggestions** | Groq breaks any task into actionable sub-steps; you pick which to add |
| 🛠 **AI Maintenance** | Smart suggestions for duplicate projects, stale tasks, unused labels |
| 📅 **Today / Inbox / Upcoming** | Clean views for every context |
| 🗂 **Projects & Labels** | Full organization system with color & emoji |
| 🔄 **Recurring Tasks** | Daily / weekly / monthly with natural language setup |
| 🔔 **Reminders** | Scheduled push notifications (mobile) |
| 🌙 **Dark Mode** | Auto-follows system theme |
| 🇪🇬 **Arabic Support** | Full RTL + Egyptian Arabic colloquial understanding |

---

## 📱 Screenshots

> Add screenshots here after running the app

---

## 🛠 Setup

### Prerequisites
- Flutter 3.16+
- A free [Groq API key](https://console.groq.com)

### Run locally

```bash
git clone https://github.com/mhmdsabeer2029/Todo-List-MobileApp.git
cd Todo-List-MobileApp

# Put your Groq key in lib/utils/local_secrets.dart (already gitignored)
echo "const String kLocalGroqApiKey = 'YOUR_KEY_HERE';" > lib/utils/local_secrets.dart

flutter pub get
flutter run
```

### Run web demo locally

```bash
flutter run -d chrome --web-renderer canvaskit \
  --dart-define=GROQ_API_KEY=YOUR_KEY_HERE
```

### Build & deploy (automatic)

Push to `main` — GitHub Actions builds and deploys automatically.

First-time setup:
1. Go to repo **Settings → Secrets → Actions** → add `GROQ_API_KEY`
2. Go to repo **Settings → Pages** → Source: **GitHub Actions**
3. Push anything to `main` — the workflow handles the rest

---

## 🏗 Architecture

```
lib/
├── db/
│   ├── database.dart          # sqflite (mobile)
│   ├── database_web.dart      # shared_preferences JSON (web)
│   └── app_database.dart      # conditional export (auto-picks)
├── store/                     # ChangeNotifier state management
├── models/                    # Task, Project, Label, Section, Comment
├── screens/                   # Today, Inbox, Upcoming, Search, Settings
├── widgets/                   # TaskItem, QuickAdd, TaskDetail, etc.
├── features/                  # Auth, Projects, Labels, Maintenance
└── utils/
    ├── groq_service.dart       # All Groq AI calls (task parse, search, subtasks, maintenance)
    ├── nlp_parser.dart         # Local fallback NLP (no network needed)
    ├── notification_service.dart  # Conditional: real on mobile, stub on web
    └── voice_service_platform.dart # Conditional: real on mobile, stub on web
```

---

## 🤖 Groq Integration

All AI features go through `GroqService` with retry + exponential backoff:

- **`parseTaskIntent(input, {projects, labels})`** — NL→structured task, context-aware (reuses existing project/label names)
- **`parseSearchQuery(query, {projects, labels})`** — NL→filters (project, label, priority, time window, overdue)
- **`suggestSubtasks({title, description})`** — returns 3-5 subtask suggestions
- **`getMaintenanceSuggestions({projects, labels, staleTasks})`** — advisory hygiene report

Model: `llama-3.3-70b-versatile` · Falls back gracefully to local NLP if Groq is unavailable.

---

## 📄 License

MIT © [Mohammed Sabeer](https://github.com/mhmdsabeer2029)
