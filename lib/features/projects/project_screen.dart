import 'package:flutter/material.dart';
import '../../store/task_store.dart';
import '../../store/project_store.dart';
import '../../models/index.dart';
import '../../widgets/task_item.dart';
import '../../widgets/quick_add_sheet.dart';
import '../../widgets/task_detail_sheet.dart';
import '../../constants/theme.dart';
import '../../db/database.dart';
import 'package:uuid/uuid.dart';

class ProjectScreen extends StatefulWidget {
  final String projectId;

  const ProjectScreen({super.key, required this.projectId});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final AppDatabase _db = AppDatabase();

  List<Section> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final s = await _db.getSectionsForProject(widget.projectId);
    if (mounted) setState(() => _sections = s);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_taskStore, _projectStore]),
      builder: (context, _) {
        final project = _projectStore.getById(widget.projectId);
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        final tasks = _taskStore.tasksForProject(widget.projectId);
        final total = tasks.length;
        final done = tasks.where((t) => t.isCompleted).length;
        final progress = total == 0 ? 0.0 : done / total;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Group tasks by section
        final unsectioned = tasks.where((t) => t.sectionId == null && !t.isCompleted).toList();

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(project.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(project.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showProjectOptions(project),
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress bar
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$done / $total completed',
                          style: const TextStyle(color: kTextMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark ? kDarkBorder : kLightBorder,
                          color: kSuccess,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: kSpace8),
                    ],
                  ),
                ),

              // Task list
              Expanded(
                child: tasks.where((t) => !t.isCompleted).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(project.emoji, style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: kSpace16),
                            Text('No tasks in ${project.name}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: kSpace8),
                            OutlinedButton.icon(
                              onPressed: () => showQuickAdd(context, projectId: project.id),
                              icon: const Icon(Icons.add),
                              label: const Text('Add task'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 100),
                        children: [
                          // Unsectioned tasks
                          ...unsectioned.map((task) => TaskItem(
                            key: ValueKey(task.id),
                            task: task,
                            onTap: () => showTaskDetail(context, task),
                            onComplete: () => _taskStore.completeTask(task.id),
                            onDelete: () => _taskStore.deleteTask(task.id),
                          )),

                          // Sections
                          ..._sections.map((section) {
                            final sectionTasks = tasks
                                .where((t) => t.sectionId == section.id && !t.isCompleted)
                                .toList();
                            return _SectionGroup(
                              section: section,
                              tasks: sectionTasks,
                              onTaskTap: (t) => showTaskDetail(context, t),
                              onTaskComplete: (t) => _taskStore.completeTask(t.id),
                              onTaskDelete: (t) => _taskStore.deleteTask(t.id),
                              onAddTask: () => showQuickAdd(context, projectId: project.id),
                            );
                          }),

                          // Add section button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace8),
                            child: OutlinedButton.icon(
                              onPressed: _addSection,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Section'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kTextMuted,
                                side: const BorderSide(color: kTextMuted),
                              ),
                            ),
                          ),

                          // Completed tasks (collapsed)
                          if (done > 0)
                            _CompletedSection(
                              tasks: tasks.where((t) => t.isCompleted).toList(),
                              onUncomplete: (t) => _taskStore.uncompleteTask(t.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showQuickAdd(context, projectId: widget.projectId),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showProjectOptions(Project project) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(project.isFavorite ? Icons.star : Icons.star_border),
              title: Text(project.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                _projectStore.toggleFavorite(project.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Project'),
              onTap: () {
                _projectStore.archiveProject(project.id);
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
            if (project.id != 'inbox')
              ListTile(
                leading: const Icon(Icons.delete_outline, color: kP1Red),
                title: const Text('Delete Project', style: TextStyle(color: kP1Red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete Project'),
                      content: const Text('All tasks in this project will remain in Inbox.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Delete', style: TextStyle(color: kP1Red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await _projectStore.deleteProject(project.id);
                    Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSection() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Section name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final section = Section(
        id: const Uuid().v4(),
        projectId: widget.projectId,
        name: name,
        orderIndex: _sections.length,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _db.insertSection(section);
      await _loadSections();
    }
  }
}

class _SectionGroup extends StatefulWidget {
  final Section section;
  final List<Task> tasks;
  final Function(Task) onTaskTap;
  final Function(Task) onTaskComplete;
  final Function(Task) onTaskDelete;
  final VoidCallback onAddTask;

  const _SectionGroup({
    required this.section,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskComplete,
    required this.onTaskDelete,
    required this.onAddTask,
  });

  @override
  State<_SectionGroup> createState() => _SectionGroupState();
}

class _SectionGroupState extends State<_SectionGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpace16, kSpace12, kSpace16, kSpace4),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18, color: kTextMuted),
                const SizedBox(width: 4),
                Text(widget.section.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: kSpace8),
                Text('${widget.tasks.length}',
                    style: const TextStyle(color: kTextMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.tasks.map((t) => TaskItem(
            key: ValueKey(t.id),
            task: t,
            onTap: () => widget.onTaskTap(t),
            onComplete: () => widget.onTaskComplete(t),
            onDelete: () => widget.onTaskDelete(t),
          )),
      ],
    );
  }
}

class _CompletedSection extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onUncomplete;

  const _CompletedSection({required this.tasks, required this.onUncomplete});

  @override
  State<_CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<_CompletedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpace16, kSpace12, kSpace16, kSpace4),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18, color: kTextMuted),
                const SizedBox(width: 4),
                Text('Completed (${widget.tasks.length})',
                    style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.tasks.map((t) => ListTile(
            dense: true,
            leading: Icon(Icons.check_circle, color: kSuccess, size: 18),
            title: Text(
              t.title,
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: kTextMuted,
              ),
            ),
            onTap: () => widget.onUncomplete(t),
          )),
      ],
    );
  }
}
