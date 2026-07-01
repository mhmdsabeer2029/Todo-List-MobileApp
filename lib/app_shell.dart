import 'package:flutter/material.dart';
import 'screens/today_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/upcoming_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/completed_screen.dart';
import 'features/projects/projects_list_screen.dart';
import 'features/projects/project_screen.dart';
import 'features/labels/labels_screen.dart';
import 'store/project_store.dart';
import 'store/task_store.dart';
import 'widgets/quick_add_sheet.dart';
import 'constants/theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    InboxScreen(),
    SearchScreen(),
    UpcomingScreen(),
    SettingsScreen(),
  ];

  void _goToTab(int index) {
    Navigator.pop(context);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(
        onNavigateToToday: () => _goToTab(0),
        onNavigateToInbox: () => _goToTab(1),
        onNavigateToUpcoming: () => _goToTab(3),
        onNavigateToProject: (id) {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProjectScreen(projectId: id)));
        },
        onNavigateToProjects: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProjectsListScreen()));
        },
        onNavigateToLabels: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LabelsScreen()));
        },
        onNavigateToCompleted: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CompletedScreen()));
        },
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Upcoming',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex != 4 && _selectedIndex != 2
          ? FloatingActionButton(
              onPressed: () => showQuickAdd(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── Side Drawer ─────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final VoidCallback onNavigateToToday;
  final VoidCallback onNavigateToInbox;
  final VoidCallback onNavigateToUpcoming;
  final Function(String) onNavigateToProject;
  final VoidCallback onNavigateToProjects;
  final VoidCallback onNavigateToLabels;
  final VoidCallback onNavigateToCompleted;

  const _AppDrawer({
    required this.onNavigateToToday,
    required this.onNavigateToInbox,
    required this.onNavigateToUpcoming,
    required this.onNavigateToProject,
    required this.onNavigateToProjects,
    required this.onNavigateToLabels,
    required this.onNavigateToCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final projectStore = ProjectStore();
    final taskStore = TaskStore();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([projectStore, taskStore]),
      builder: (context, _) {
        final favorites = projectStore.favoriteProjects;
        final allProjects = projectStore.activeProjects;
        final todayCount = taskStore.todayTasks.length;
        final inboxCount = taskStore.inboxTasks.length;
        final completedCount = taskStore.completedTasks.length;

        return Drawer(
          backgroundColor: isDark ? kDarkSurface : kLightSurface,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ─── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace16, kSpace24, kSpace16, kSpace16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('✓',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: kSpace12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TodoList',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          Text('Offline-first',
                              style: TextStyle(color: kTextMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),
                const SizedBox(height: kSpace8),

                // ─── Main Views ──────────────────────────────────────────────
                _DrawerItem(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Today',
                  badge: todayCount > 0 ? '$todayCount' : null,
                  badgeColor: kPrimary,
                  onTap: onNavigateToToday,
                ),
                _DrawerItem(
                  icon: Icons.inbox_outlined,
                  label: 'Inbox',
                  badge: inboxCount > 0 ? '$inboxCount' : null,
                  onTap: onNavigateToInbox,
                ),
                _DrawerItem(
                  icon: Icons.event_outlined,
                  label: 'Upcoming',
                  onTap: onNavigateToUpcoming,
                ),
                _DrawerItem(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  badge: completedCount > 0 ? '$completedCount' : null,
                  onTap: onNavigateToCompleted,
                ),

                const SizedBox(height: kSpace8),
                const Divider(height: 1),

                // ─── Favorites ───────────────────────────────────────────────
                if (favorites.isNotEmpty) ...[
                  const SizedBox(height: kSpace8),
                  _DrawerSectionLabel('FAVORITES'),
                  ...favorites.map((p) => _DrawerItem(
                        emoji: p.emoji,
                        emojiColor: _hexColor(p.color),
                        label: p.name,
                        onTap: () => onNavigateToProject(p.id),
                      )),
                  const Divider(height: 1),
                ],

                // ─── Projects ────────────────────────────────────────────────
                const SizedBox(height: kSpace8),
                Row(
                  children: [
                    Expanded(child: _DrawerSectionLabel('PROJECTS')),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: kTextMuted),
                      padding: const EdgeInsets.only(right: kSpace16),
                      onPressed: onNavigateToProjects,
                    ),
                  ],
                ),
                ...allProjects.take(7).map((p) {
                  final count = taskStore
                      .tasksForProject(p.id)
                      .where((t) => !t.isCompleted)
                      .length;
                  return _DrawerItem(
                    emoji: p.emoji,
                    emojiColor: _hexColor(p.color),
                    label: p.name,
                    badge: count > 0 ? '$count' : null,
                    onTap: () => onNavigateToProject(p.id),
                  );
                }),
                if (allProjects.length > 7)
                  _DrawerItem(
                    icon: Icons.more_horiz,
                    label: 'All projects (${allProjects.length})',
                    onTap: onNavigateToProjects,
                  ),

                const SizedBox(height: kSpace8),
                const Divider(height: 1),
                const SizedBox(height: kSpace8),

                // ─── Labels ──────────────────────────────────────────────────
                _DrawerItem(
                  icon: Icons.label_outline,
                  label: 'Labels',
                  onTap: onNavigateToLabels,
                ),

                const SizedBox(height: kSpace16),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return kP4Gray;
    }
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String text;
  const _DrawerSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace16, 4, kSpace16, 4),
      child: Text(text,
          style: const TextStyle(
              color: kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color? emojiColor;
  final String label;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _DrawerItem({
    this.icon,
    this.emoji,
    this.emojiColor,
    required this.label,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;
    if (emoji != null) {
      leadingWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (emojiColor ?? kTextMuted).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(child: Text(emoji!, style: const TextStyle(fontSize: 14))),
      );
    } else if (icon != null) {
      leadingWidget = Icon(icon, size: 20, color: kTextMuted);
    }

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: leadingWidget,
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? kTextMuted).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor ?? kTextMuted)),
            )
          : null,
      onTap: onTap,
    );
  }
}
