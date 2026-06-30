import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/index.dart';

class SettingsStore extends ChangeNotifier {
  static final SettingsStore _instance = SettingsStore._internal();
  factory SettingsStore() => _instance;
  SettingsStore._internal();

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      themeMode: prefs.getString('themeMode') ?? 'system',
      defaultReminderMinutes: prefs.getInt('defaultReminderMinutes') ?? 30,
      dailyDigestEnabled: prefs.getBool('dailyDigestEnabled') ?? true,
      dailyDigestTime: prefs.getString('dailyDigestTime') ?? '09:00',
      weekStartsOn: prefs.getString('weekStartsOn') ?? 'sunday',
      badgeCountEnabled: prefs.getBool('badgeCountEnabled') ?? true,
      hasCompletedOnboarding: prefs.getBool('hasCompletedOnboarding') ?? false,
      lastBackupAt: prefs.getString('lastBackupAt'),
    );
    notifyListeners();
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', updated.themeMode);
    await prefs.setInt('defaultReminderMinutes', updated.defaultReminderMinutes);
    await prefs.setBool('dailyDigestEnabled', updated.dailyDigestEnabled);
    await prefs.setString('dailyDigestTime', updated.dailyDigestTime);
    await prefs.setString('weekStartsOn', updated.weekStartsOn);
    await prefs.setBool('badgeCountEnabled', updated.badgeCountEnabled);
    await prefs.setBool('hasCompletedOnboarding', updated.hasCompletedOnboarding);
    if (updated.lastBackupAt != null) {
      await prefs.setString('lastBackupAt', updated.lastBackupAt!);
    } else {
      await prefs.remove('lastBackupAt');
    }
  }

  ThemeMode get flutterThemeMode {
    switch (_settings.themeMode) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default: return ThemeMode.system;
    }
  }
}
