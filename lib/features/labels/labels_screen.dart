import 'package:flutter/material.dart';
import '../../store/label_store.dart';
import '../../store/task_store.dart';
import '../../models/index.dart';
import '../../constants/theme.dart';
import '../../widgets/task_item.dart';
import '../../widgets/task_detail_sheet.dart';

class LabelsScreen extends StatelessWidget {
  const LabelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final labelStore = LabelStore();
    return AnimatedBuilder(
      animation: labelStore,
      builder: (context, _) {
        final labels = labelStore.labels;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Labels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateLabel(context, labelStore),
              ),
            ],
          ),
          body: labels.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_outline, size: 64, color: kTextMuted),
                      SizedBox(height: kSpace16),
                      Text('No labels yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: kSpace8),
                      Text('Labels help you group tasks across projects',
                          style: TextStyle(color: kTextMuted), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: labels.length,
                  itemBuilder: (ctx, i) {
                    final label = labels[i];
                    Color color;
                    try {
                      color = Color(int.parse(label.color.replaceAll('#', '0xFF')));
                    } catch (_) {
                      color = kP4Gray;
                    }
                    return ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      title: Text(label.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: kTextMuted),
                            onPressed: () => _showEditLabel(context, labelStore, label),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: kP1Red),
                            onPressed: () => _deleteLabel(context, labelStore, label),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LabelTasksScreen(label: label),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showCreateLabel(BuildContext context, LabelStore store) {
    _showLabelDialog(context, store, null);
  }

  void _showEditLabel(BuildContext context, LabelStore store, Label label) {
    _showLabelDialog(context, store, label);
  }

  void _showLabelDialog(BuildContext context, LabelStore store, Label? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedColor = existing?.color ?? '#8C8C8C';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setState) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(kSpace16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing == null ? 'New Label' : 'Edit Label',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  const SizedBox(height: kSpace16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Label name'),
                  ),
                  const SizedBox(height: kSpace16),
                  const Text('Color', style: TextStyle(color: kTextMuted, fontSize: 13)),
                  const SizedBox(height: kSpace8),
                  Wrap(
                    spacing: kSpace8,
                    children: [
                      '#DC4C3E', '#4073FF', '#058527', '#EB8909',
                      '#8C8C8C', '#7C3AED', '#DB2777', '#0891B2',
                    ].map((c) {
                      final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: Container(
                          width: 32, height: 32,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == c ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: selectedColor == c
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: kSpace16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        if (existing == null) {
                          await store.addLabel(name: name, color: selectedColor);
                        } else {
                          await store.updateLabel(existing.copyWith(
                            name: name, color: selectedColor,
                          ));
                        }
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
                      child: Text(existing == null ? 'Create' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteLabel(BuildContext context, LabelStore store, Label label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Delete "${label.name}"? It will be removed from all tasks that have it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kP1Red)),
          ),
        ],
      ),
    );
    if (confirm == true) await store.deleteLabel(label.id);
  }
}

class LabelTasksScreen extends StatelessWidget {
  final Label label;

  const LabelTasksScreen({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final taskStore = TaskStore();
    Color color;
    try {
      color = Color(int.parse(label.color.replaceAll('#', '0xFF')));
    } catch (_) {
      color = kP4Gray;
    }

    return AnimatedBuilder(
      animation: taskStore,
      builder: (context, _) {
        final tasks = taskStore.tasksForLabel(label.id).where((t) => !t.isCompleted).toList();
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: kSpace8),
                Text(label.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
          ),
          body: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_outline, size: 64, color: color.withValues(alpha: 0.5)),
                      const SizedBox(height: kSpace16),
                      Text('No tasks with "${label.name}"',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final task = tasks[i];
                    return TaskItem(
                      key: ValueKey(task.id),
                      task: task,
                      onTap: () => showTaskDetail(context, task),
                      onComplete: () => taskStore.completeTask(task.id),
                      onDelete: () => taskStore.deleteTask(task.id),
                    );
                  },
                ),
        );
      },
    );
  }
}
