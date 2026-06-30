import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../store/settings_store.dart';
import '../store/task_store.dart';
import '../store/auth_store.dart';
import '../models/index.dart';
import '../constants/theme.dart';
import '../utils/google_auth_service.dart';
import '../features/sheets_import/sheets_import_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/maintenance/maintenance_screen.dart';
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsStore _settingsStore = SettingsStore();
  final TaskStore _taskStore = TaskStore();
  TaskStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Stats are derived from tasks, so refresh whenever tasks change
    // elsewhere in the app (completed, deleted, cleared, etc.) rather than
    // only once when this screen first mounts.
    _taskStore.addListener(_loadStats);
  }

  @override
  void dispose() {
    _taskStore.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final s = await _taskStore.getStats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsStore,
      builder: (context, _) {
        final settings = _settingsStore.settings;
        return AnimatedBuilder(
          animation: AuthStore(),
          builder: (context, __) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
              ),
              body: ListView(
                children: [
                  // ─── Account ──────────────────────────────────────────────────
                  _SectionTitle('Account'),
                  _buildAccountTile(),
                  if (AuthStore().isSignedIn && AuthStore().account?.provider == AuthProvider.google)
                    _SettingsTile(
                      icon: Icons.grid_on,
                      title: 'Import from Google Sheets',
                      subtitle: 'Scan a sheet with Groq and add tasks',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SheetsImportScreen()),
                      ),
                    ),

                  // ─── Stats Card ───────────────────────────────────────────────
                  if (_stats != null) ...[
                    _SectionTitle('Productivity'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace8),
                      child: _StatsCard(stats: _stats!),
                    ),
                  ],

                  // ─── Appearance ───────────────────────────────────────────────
                  _SectionTitle('Appearance'),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: settings.themeMode[0].toUpperCase() + settings.themeMode.substring(1),
                    onTap: () => _pickTheme(settings),
                  ),

                  // ─── Notifications ────────────────────────────────────────────
                  _SectionTitle('Notifications'),
                  SwitchListTile(
                    secondary: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('Daily Digest'),
                    subtitle: Text(settings.dailyDigestEnabled
                        ? 'Sent at ${settings.dailyDigestTime}'
                        : 'Disabled'),
                    value: settings.dailyDigestEnabled,
                    onChanged: (v) {
                      _settingsStore.update(settings.copyWith(dailyDigestEnabled: v));
                    },
                  ),
                  if (settings.dailyDigestEnabled)
                    _SettingsTile(
                      icon: Icons.schedule,
                      title: 'Digest Time',
                      subtitle: settings.dailyDigestTime,
                      onTap: () => _pickDigestTime(settings),
                    ),
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Default Reminder',
                    subtitle: '${settings.defaultReminderMinutes} minutes before',
                    onTap: () => _pickDefaultReminder(settings),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.badge_outlined),
                    title: const Text('App Badge Count'),
                    value: settings.badgeCountEnabled,
                    onChanged: (v) {
                      _settingsStore.update(settings.copyWith(badgeCountEnabled: v));
                    },
                  ),

                  // ─── Preferences ──────────────────────────────────────────────
                  _SectionTitle('Preferences'),
                  _SettingsTile(
                    icon: Icons.date_range,
                    title: 'Week Starts On',
                    subtitle: settings.weekStartsOn == 'monday' ? 'Monday' : 'Sunday',
                    onTap: () => _pickWeekStart(settings),
                  ),

                  // ─── Data ─────────────────────────────────────────────────────
                  _SectionTitle('Data'),
                  _SettingsTile(
                    icon: Icons.auto_awesome,
                    title: 'AI Maintenance',
                    subtitle: 'Find duplicate projects, stale tasks, and more',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.download_outlined,
                    title: 'Export Data (JSON)',
                    subtitle: 'Copy all tasks to clipboard',
                    onTap: _exportData,
                  ),
                  _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Clear Completed Tasks',
                    titleColor: kP1Red,
                    onTap: _clearCompleted,
                  ),

                  // ─── About ────────────────────────────────────────────────────
                  _SectionTitle('About'),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    trailing: Text('1.0.0', style: TextStyle(color: kTextMuted)),
                  ),
                  const ListTile(
                    leading: Icon(Icons.code),
                    title: Text('Built with Flutter & Dart'),
                    subtitle: Text('SQLite • Offline-first'),
                  ),
                  const SizedBox(height: kSpace48),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountTile() {
    final account = AuthStore().account;
    if (account == null) {
      return _SettingsTile(
        icon: Icons.login,
        title: 'Sign In',
        subtitle: 'Connect a Google, Microsoft, or Apple account',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(onSignedIn: () => Navigator.pop(context)),
          ),
        ),
      );
    }
    return ListTile(
      leading: account.photoUrl != null
          ? CircleAvatar(backgroundImage: NetworkImage(account.photoUrl!))
          : const CircleAvatar(child: Icon(Icons.person)),
      title: Text(account.displayName),
      subtitle: Text('${account.email} • ${_providerLabel(account.provider)}'),
      trailing: TextButton(
        onPressed: _signOut,
        child: const Text('Sign Out', style: TextStyle(color: kP1Red)),
      ),
    );
  }

  String _providerLabel(AuthProvider p) {
    switch (p) {
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.microsoft:
        return 'Microsoft';
      case AuthProvider.apple:
        return 'Apple';
    }
  }

  Future<void> _signOut() async {
    if (AuthStore().account?.provider == AuthProvider.google) {
      await GoogleAuthService().signOut();
    }
    await AuthStore().signOut();
  }

  void _pickTheme(AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System'),
              trailing: settings.themeMode == 'system' ? const Icon(Icons.check, color: kPrimary) : null,
              onTap: () {
                _settingsStore.update(settings.copyWith(themeMode: 'system'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              trailing: settings.themeMode == 'light' ? const Icon(Icons.check, color: kPrimary) : null,
              onTap: () {
                _settingsStore.update(settings.copyWith(themeMode: 'light'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              trailing: settings.themeMode == 'dark' ? const Icon(Icons.check, color: kPrimary) : null,
              onTap: () {
                _settingsStore.update(settings.copyWith(themeMode: 'dark'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickDigestTime(AppSettings settings) async {
    final parts = settings.dailyDigestTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final t = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
      _settingsStore.update(settings.copyWith(dailyDigestTime: t));
    }
  }

  void _pickDefaultReminder(AppSettings settings) {
    const options = [5, 10, 15, 30, 60, 120];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((m) => ListTile(
            title: Text(m < 60 ? '$m minutes before' : '${m ~/ 60} hour${m >= 120 ? 's' : ''} before'),
            trailing: settings.defaultReminderMinutes == m
                ? const Icon(Icons.check, color: kPrimary)
                : null,
            onTap: () {
              _settingsStore.update(settings.copyWith(defaultReminderMinutes: m));
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _pickWeekStart(AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Sunday'),
              trailing: settings.weekStartsOn == 'sunday'
                  ? const Icon(Icons.check, color: kPrimary) : null,
              onTap: () {
                _settingsStore.update(settings.copyWith(weekStartsOn: 'sunday'));
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Monday'),
              trailing: settings.weekStartsOn == 'monday'
                  ? const Icon(Icons.check, color: kPrimary) : null,
              onTap: () {
                _settingsStore.update(settings.copyWith(weekStartsOn: 'monday'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final tasks = _taskStore.tasks;
    final data = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'tasksCount': tasks.length,
      'tasks': tasks.map((t) => t.toMap()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);

    // No file-sharing package (share_plus / path_provider) is wired up yet,
    // so the most honest thing we can do without one is copy the JSON to
    // the clipboard rather than silently discarding it and claiming a fake
    // "export" succeeded. Swap this for a real file share once share_plus
    // is added to pubspec.yaml.
    await Clipboard.setData(ClipboardData(text: json));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${tasks.length} tasks as JSON to clipboard'),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: const Text('This will permanently delete all completed tasks. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: kP1Red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _taskStore.clearCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completed tasks cleared'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

// ─── Stats Card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final TaskStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kLightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? kDarkBorder : kLightBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points + Streak row
          Row(
            children: [
              _StatBadge(value: '${stats.karma}', label: 'Points ⚡'),
              const SizedBox(width: kSpace16),
              _StatBadge(value: '${stats.streak}🔥', label: 'Day Streak'),
            ],
          ),
          const SizedBox(height: kSpace16),
          // Completion numbers
          Row(
            children: [
              _StatNumber(value: stats.completedToday, label: 'Today'),
              _StatNumber(value: stats.completedThisWeek, label: 'This Week'),
              _StatNumber(value: stats.completedThisMonth, label: 'This Month'),
            ],
          ),
          const SizedBox(height: kSpace16),
          // Bar chart
          if (stats.lastSevenDays.isNotEmpty) ...[
            Text('Last 7 Days',
                style: const TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: kSpace8),
            SizedBox(
              height: 80,
              child: BarChart(
                BarChartData(
                  maxY: (stats.lastSevenDays
                      .map((d) => d.completed)
                      .fold(0, (a, b) => a > b ? a : b)
                      .toDouble() + 1),
                  barGroups: stats.lastSevenDays.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.completed.toDouble(),
                          color: kPrimary,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final d = stats.lastSevenDays[v.toInt()];
                          final date = DateTime.tryParse(d.date);
                          if (date == null) return const SizedBox.shrink();
                          return Text(
                            ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][date.weekday % 7],
                            style: const TextStyle(fontSize: 9, color: kTextMuted),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  const _StatBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
      ],
    );
  }
}

class _StatNumber extends StatelessWidget {
  final int value;
  final String label;
  const _StatNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
        ],
      ),
    );
  }
}

// ─── Reusable Settings Widgets ───────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: kTextMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: titleColor != null ? TextStyle(color: titleColor) : null),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: kTextMuted)) : null,
      trailing: const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
      onTap: onTap,
    );
  }
}
