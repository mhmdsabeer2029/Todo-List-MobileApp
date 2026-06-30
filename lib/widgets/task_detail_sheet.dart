import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../store/task_store.dart';
import '../store/project_store.dart';
import '../constants/theme.dart';
import '../db/app_database.dart';
import '../utils/groq_service.dart';
import 'package:uuid/uuid.dart';

class TaskDetailSheet extends StatefulWidget {
  final Task task;

  const TaskDetailSheet({super.key, required this.task});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _commentCtrl;

  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final AppDatabase _db = AppDatabase();
  final GroqService _groqService = GroqService();

  late Task _task;
  List<Comment> _comments = [];
  List<Task> _subtasks = [];
  bool _saving = false;
  bool _suggestingSubtasks = false;

  // Set right before this task is deleted so the PopScope handler below
  // (triggered by the explicit Navigator.pop(context) in the delete flow)
  // knows NOT to flush pending title/description edits — otherwise it
  // would call TaskStore.updateTask() on an id that was just deleted,
  // silently resurrecting the "deleted" task.
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleCtrl = TextEditingController(text: _task.title);
    _descCtrl = TextEditingController(text: _task.description);
    _commentCtrl = TextEditingController();
    _loadComments();
    _loadSubtasks();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final c = await _db.getCommentsForTask(_task.id);
    if (mounted) setState(() => _comments = c);
  }

  Future<void> _loadSubtasks() async {
    final s = await _db.getSubtasks(_task.id);
    if (mounted) setState(() => _subtasks = s);
  }

  /// Applies a field change to the in-memory task, updates the UI
  /// immediately, and persists the change via TaskStore (which writes to
  /// the database). Every field editor below must go through this so
  /// changes survive closing the sheet.
  Future<void> _applyUpdate(Task Function(Task current) update) async {
    final updated = update(_task).copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );
    setState(() => _task = updated);
    await _taskStore.updateTask(updated);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _task.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _taskStore.updateTask(updated);
    setState(() {
      _task = updated;
      _saving = false;
    });
  }

  /// Persists any unsaved title/description edits. Unlike [_save], this
  /// doesn't touch [_saving]/setState (it's meant to run as the sheet is
  /// closing, e.g. via swipe-to-dismiss or the back gesture, where the
  /// user never tapped "Save" or pressed enter in the title field — without
  /// this, those edits would be silently lost).
  Future<void> _flushPendingEdits() async {
    if (_deleted) return;
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    if (title == _task.title && description == _task.description) return;
    final updated = _task.copyWith(
      title: title,
      description: description,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _task = updated;
    await _taskStore.updateTask(updated);
  }

  Future<void> _pickDueDate() async {
    final initial = _task.dueDate != null
        ? DateTime.tryParse(_task.dueDate!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      await _applyUpdate((t) => t.copyWith(dueDate: DateFormat('yyyy-MM-dd').format(picked)));
    }
  }

  Future<void> _pickDueTime() async {
    final parts = (_task.dueTime ?? '09:00').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      await _applyUpdate((t) => t.copyWith(
        dueTime: '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}',
      ));
    }
  }

  Future<void> _addComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    final comment = Comment(
      id: const Uuid().v4(),
      taskId: _task.id,
      body: body,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.insertComment(comment);
    _commentCtrl.clear();
    await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _flushPendingEdits();
        if (mounted) Navigator.of(context).pop();
      },
      child: DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: isDark ? kDarkSurface : kLightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? kDarkBorder : kLightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace8),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () async {
                      if (_task.isCompleted) {
                        await _taskStore.uncompleteTask(_task.id);
                      } else {
                        await _taskStore.completeTask(_task.id);
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _task.isCompleted ? priorityColor(_task.priority) : Colors.transparent,
                        border: Border.all(color: priorityColor(_task.priority), width: 2),
                      ),
                      child: _task.isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                  const SizedBox(width: kSpace12),
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                      ),
                      style: theme.textTheme.titleMedium,
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  if (_saving)
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    TextButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: kSpace16),
                children: [
                  // Description
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add description…',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: kTextMuted),
                    ),
                    style: theme.textTheme.bodyMedium,
                    maxLines: null,
                    minLines: 2,
                  ),

                  const Divider(),

                  // Meta fields
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Due Date',
                    value: _task.dueDate != null
                        ? DateFormat('EEE, MMM d, y').format(DateTime.parse(_task.dueDate!))
                        : 'No date',
                    onTap: _pickDueDate,
                    trailing: _task.dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _applyUpdate((t) => t.copyWith(dueDate: null)),
                          )
                        : null,
                  ),

                  _DetailRow(
                    icon: Icons.access_time,
                    label: 'Due Time',
                    value: _task.dueTime ?? 'No time',
                    onTap: _pickDueTime,
                    trailing: _task.dueTime != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _applyUpdate((t) => t.copyWith(dueTime: null)),
                          )
                        : null,
                  ),

                  _DetailRow(
                    icon: Icons.flag_outlined,
                    label: 'Priority',
                    value: 'P${_task.priority}',
                    valueColor: priorityColor(_task.priority),
                    onTap: _pickPriority,
                  ),

                  _DetailRow(
                    icon: Icons.folder_outlined,
                    label: 'Project',
                    value: _projectStore.getById(_task.projectId ?? 'inbox')?.name ?? 'Inbox',
                    onTap: _pickProject,
                  ),

                  _DetailRow(
                    icon: Icons.notifications_none,
                    label: 'Reminder',
                    value: _task.reminderMinutes != null
                        ? '${_task.reminderMinutes} min before'
                        : 'No reminder',
                    onTap: _pickReminder,
                  ),

                  _DetailRow(
                    icon: Icons.repeat,
                    label: 'Recurrence',
                    value: _task.isRecurring ? (_task.recurrenceRule?.raw ?? 'Recurring') : 'None',
                    onTap: () {},
                  ),

                  const Divider(),

                  // Subtasks
                  _SectionHeader(title: 'Sub-tasks (${_subtasks.length})'),
                  ..._subtasks.map((st) => ListTile(
                    dense: true,
                    leading: Icon(
                      st.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: st.isCompleted ? kSuccess : kTextMuted,
                      size: 18,
                    ),
                    title: Text(
                      st.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: st.isCompleted ? TextDecoration.lineThrough : null,
                        color: st.isCompleted ? kTextMuted : null,
                      ),
                    ),
                    onTap: () async {
                      if (st.isCompleted) {
                        await _taskStore.uncompleteTask(st.id);
                      } else {
                        await _taskStore.completeTask(st.id);
                      }
                      await _loadSubtasks();
                    },
                  )),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add, size: 18, color: kPrimary),
                    title: const Text('Add sub-task', style: TextStyle(color: kPrimary)),
                    onTap: _addSubtask,
                  ),
                  ListTile(
                    dense: true,
                    leading: _suggestingSubtasks
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18, color: kP3Blue),
                    title: Text(
                      _suggestingSubtasks ? 'Asking AI…' : 'Suggest sub-tasks with AI',
                      style: const TextStyle(color: kP3Blue),
                    ),
                    onTap: _suggestingSubtasks ? null : _suggestSubtasksWithAi,
                  ),

                  const Divider(),

                  // Comments
                  _SectionHeader(title: 'Comments (${_comments.length})'),
                  ..._comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: kSpace8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.body, style: theme.textTheme.bodyMedium),
                        Text(
                          DateFormat('MMM d, HH:mm').format(DateTime.parse(c.createdAt)),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  )),

                  // Comment input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.bodyMedium,
                          onSubmitted: (_) => _addComment(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_outlined, size: 18, color: kPrimary),
                        onPressed: _addComment,
                      ),
                    ],
                  ),

                  const Divider(),

                  // Danger zone
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: kP1Red),
                    title: const Text('Delete Task', style: TextStyle(color: kP1Red)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: const Text('This will also delete all sub-tasks and comments.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: kP1Red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        _deleted = true;
                        await _taskStore.deleteTask(_task.id);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: kSpace48),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _pickPriority() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3, 4].map((p) => ListTile(
            leading: Icon(Icons.flag, color: priorityColor(p)),
            title: Text('Priority $p'),
            onTap: () {
              _applyUpdate((t) => t.copyWith(priority: p));
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _pickProject() {
    final projects = _projectStore.activeProjects;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: projects.map((p) => ListTile(
            leading: Text(p.emoji),
            title: Text(p.name),
            onTap: () {
              _applyUpdate((t) => t.copyWith(projectId: p.id));
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _pickReminder() {
    const options = [10, 30, 60, 120];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('No reminder'),
              onTap: () {
                _applyUpdate((t) => t.copyWith(reminderMinutes: null));
                Navigator.pop(ctx);
              },
            ),
            ...options.map((m) => ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(m < 60 ? '$m minutes before' : '${m ~/ 60} hour${m >= 120 ? 's' : ''} before'),
              onTap: () {
                _applyUpdate((t) => t.copyWith(reminderMinutes: m));
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _addSubtask() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Sub-task'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Sub-task title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added != null && added.isNotEmpty) {
      await _taskStore.addTask(
        title: added,
        projectId: _task.projectId,
        parentTaskId: _task.id,
      );
      await _loadSubtasks();
    }
  }

  /// Asks Groq to propose subtasks for the current task, then shows them
  /// as a checklist the user can pick from. Nothing is created until the
  /// user explicitly taps "Add selected" — suggestions are advisory only.
  Future<void> _suggestSubtasksWithAi() async {
    setState(() => _suggestingSubtasks = true);
    List<String> suggestions = [];
    String? error;
    try {
      suggestions = await _groqService.suggestSubtasks(
        title: _task.title,
        description: _task.description,
      );
      if (suggestions.isEmpty) error = 'AI had no suggestions for this task.';
    } catch (e) {
      error = 'AI suggestions unavailable right now.';
    } finally {
      if (mounted) setState(() => _suggestingSubtasks = false);
    }

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final selected = List<bool>.filled(suggestions.length, true);
    final accepted = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Suggested Sub-tasks'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (ctx, i) => CheckboxListTile(
                dense: true,
                value: selected[i],
                title: Text(suggestions[i]),
                onChanged: (v) => setDialogState(() => selected[i] = v ?? false),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(
                ctx,
                [for (var i = 0; i < suggestions.length; i++) if (selected[i]) suggestions[i]],
              ),
              child: const Text('Add selected'),
            ),
          ],
        ),
      ),
    );

    if (accepted != null && accepted.isNotEmpty) {
      for (final title in accepted) {
        await _taskStore.addTask(
          title: title,
          projectId: _task.projectId,
          parentTaskId: _task.id,
        );
      }
      await _loadSubtasks();
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: kTextMuted),
      title: Text(label, style: const TextStyle(color: kTextMuted, fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                color: valueColor ?? Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
              )),
          if (trailing != null) trailing!,
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace8),
      child: Text(title,
          style: const TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// Convenience
Future<void> showTaskDetail(BuildContext context, Task task) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TaskDetailSheet(task: task),
  );
}
