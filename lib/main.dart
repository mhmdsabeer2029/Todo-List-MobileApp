import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/theme.dart';
import 'store/settings_store.dart';
import 'store/task_store.dart';
import 'store/project_store.dart';
import 'store/auth_store.dart';
import 'utils/notification_service.dart';
import 'app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock only on mobile — not supported/needed on web
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Notifications are no-ops on web (stub handles gracefully)
  await NotificationService().init();
  if (!kIsWeb) await NotificationService().requestPermissions();
  await SettingsStore().load();
  await AuthStore().load();

  // Load data
  await TaskStore().loadAll();
  await ProjectStore().loadAll();
  await LabelStore().loadAll();

  runApp(const TodoListApp());
}

class TodoListApp extends StatelessWidget {
  const TodoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore(),
      builder: (context, _) {
        return MaterialApp(
          title: 'TodoList',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: SettingsStore().flutterThemeMode,
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  static const _kSkippedSignInKey = 'skipped_sign_in';

  bool _showOnboarding = false;
  bool _signedIn = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final settings = SettingsStore().settings;
    // "Skipped" is persisted separately from AuthStore's sign-in state,
    // since skipping isn't the same as being signed in — without this,
    // tapping "Skip for now" only set in-memory state, so the LoginScreen
    // reappeared every time the app was restarted even though the user had
    // already chosen to use the app without an account.
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getBool(_kSkippedSignInKey) ?? false;
    setState(() {
      _signedIn = AuthStore().isSignedIn || skipped;
      _showOnboarding = !settings.hasCompletedOnboarding;
      _ready = true;
    });
  }

  Future<void> _handleSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSkippedSignInKey, true);
    if (mounted) setState(() => _signedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_signedIn) {
      return LoginScreen(
        onSignedIn: () => setState(() => _signedIn = true),
        // Skipping is allowed so the app remains fully usable without an
        // account; users can sign in later from Settings.
        onSkip: _handleSkip,
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }

    return const AppShell();
  }
}
