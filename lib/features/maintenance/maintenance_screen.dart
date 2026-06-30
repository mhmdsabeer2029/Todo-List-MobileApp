import 'package:flutter/material.dart';
import '../../store/task_store.dart';
import '../../store/project_store.dart';
import '../../store/label_store.dart';
import '../../constants/theme.dart';
import '../../utils/groq_service.dart';
import '../projects/projects_list_screen.dart';
import '../labels/labels_screen.dart';
import '../../widgets/task_detail_sheet.dart';

/// AI-assisted housekeeping. Groq looks at the current projects, labels,
/// and old/stale tasks and proposes things worth a look — possible
/// duplicate projects or labels, tasks that have been sitting untouched
/// for a long time, etc.
///
/// IMPORTANT: this screen is advisory only. Nothing here is ever applied
/// automatically. Every suggestion routes the user to the existing
/// projects/labels/task-detail screens to review and act for themselves.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final LabelStore _labelStore = LabelStore();
  final GroqService _groqService = GroqService();

  bool _loading = true;
  String? _error;
  List<MaintenanceSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final staleTasks = _taskStore.tasks
        .where((t) => !t.isCompleted && t.dueDate == null)
        .map((t) {
          final created = DateTime.tryParse(t.createdAt);
          final days = created == null ? 0 : now.difference(created).inDays;
          return {'title': t.title, 'daysSinceCreated': days, 'id': t.id};
        })
        .where((t) => (t['daysSinceCreated'] as int) >= 60)
        .toList();

    try {
      final results = await _groqService.getMaintenanceSuggestions(
        projectNames: _projectStore.activeProjects.map((p) => p.name).toList(),
        labelNames: _labelStore.labels.map((l) => l.name).toList(),
        staleTasks: staleTasks,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'AI maintenance check unavailable right now.';
          _loading = false;
        });
      }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'duplicate_project':
        return Icons.folder_copy_outlined;
      case 'duplicate_label':
        return Icons.label_outline;
      case 'stale_task':
        return Icons.hourglass_empty;
      default:
        return Icons.tips_and_updates_outlined;
    }
  }

  void _handleTap(MaintenanceSuggestion s) {
    switch (s.type) {
      case 'duplicate_project':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsListScreen()));
        break;
      case 'duplicate_label':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LabelsScreen()));
        break;
      case 'stale_task':
        if (s.items.isNotEmpty) {
          final match = _taskStore.tasks.where((t) => t.title == s.items.first).firstOrNullSafe();
          if (match != null) {
            showTaskDetail(context, match);
            return;
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Maintenance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _run,
            tooltip: 'Re-check',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(kSpace24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: kP1Red),
                        const SizedBox(height: kSpace16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: kSpace16),
                        FilledButton(onPressed: _run, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _suggestions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(kSpace24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, size: 56, color: kSuccess),
                            SizedBox(height: kSpace16),
                            Text('Nothing stands out',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                            SizedBox(height: kSpace8),
                            Text(
                              'Your projects, labels, and tasks look tidy. '
                              'Run this again any time from Settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kTextMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: kSpace8),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(kSpace16, kSpace8, kSpace16, kSpace16),
                            child: Text(
                              'These are suggestions only — nothing is changed '
                              'automatically. Tap one to review and decide for yourself.',
                              style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.4),
                            ),
                          ),
                          ..._suggestions.map((s) => Card(
                                margin: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace4),
                                child: ListTile(
                                  leading: Icon(_iconFor(s.type), color: kP3Blue),
                                  title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (s.detail.isNotEmpty) Text(s.detail),
                                      if (s.items.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            s.items.join(' • '),
                                            style: const TextStyle(fontSize: 12, color: kTextMuted),
                                          ),
                                        ),
                                    ],
                                  ),
                                  isThreeLine: s.detail.isNotEmpty && s.items.isNotEmpty,
                                  trailing: const Icon(Icons.chevron_right, color: kTextMuted),
                                  onTap: () => _handleTap(s),
                                ),
                              )),
                          const SizedBox(height: kSpace24),
                        ],
                      ),
      ),
    );
  }
}

extension _FirstOrNullSafe<T> on Iterable<T> {
  T? firstOrNullSafe() => isEmpty ? null : first;
}
