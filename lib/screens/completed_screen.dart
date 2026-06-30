import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../store/task_store.dart';
import '../models/index.dart';
import '../widgets/task_item.dart';
import '../widgets/task_detail_sheet.dart';
import '../constants/theme.dart';

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  final TaskStore _taskStore = TaskStore();
  String _filter = 'all'; // 'today' | 'week' | 'month' | 'all'

  List<Task> get _filtered {
    final all = _taskStore.completedTasks
      ..sort((a, b) => (b.completedAt ?? '').compareTo(a.completedAt ?? ''));
    final now = DateTime.now();
    switch (_filter) {
      case 'today':
        final today = DateFormat('yyyy-MM-dd').format(now);
        return all.where((t) => (t.completedAt ?? '').startsWith(today)).toList();
      case 'week':
        final since = now.subtract(const Duration(days: 7));
        return all.where((t) {
          final completedAt = DateTime.tryParse(t.completedAt ?? '');
          return completedAt != null && !completedAt.isBefore(since);
        }).toList();
      case 'month':
        final since = now.subtract(const Duration(days: 30));
        return all.where((t) {
          final completedAt = DateTime.tryParse(t.completedAt ?? '');
          return completedAt != null && !completedAt.isBefore(since);
        }).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _taskStore,
      builder: (context, _) {
        final tasks = _filtered;
        return Scaffold(
          appBar: AppBar(
            title: Text('Completed (${tasks.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
          ),
          body: Column(
            children: [
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, kSpace8),
                child: Row(
                  children: [
                    _FilterChip(label: 'All', value: 'all', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'Today', value: 'today', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'This Week', value: 'week', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'This Month', value: 'month', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  ],
                ),
              ),
              // List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 64, color: kTextMuted),
                            const SizedBox(height: kSpace16),
                            const Text('Nothing completed yet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: kSpace8),
                            Text('Complete tasks to see them here',
                                style: const TextStyle(color: kTextMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: tasks.length,
                        itemBuilder: (ctx, i) {
                          final task = tasks[i];
                          return TaskItem(
                            key: ValueKey(task.id),
                            task: task,
                            onTap: () => showTaskDetail(context, task),
                            onComplete: () => _taskStore.uncompleteTask(task.id),
                            onDelete: () => _taskStore.deleteTask(task.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: kSpace8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.transparent,
          border: Border.all(color: isSelected ? kPrimary : kTextMuted),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : kTextMuted,
          ),
        ),
      ),
    );
  }
}
