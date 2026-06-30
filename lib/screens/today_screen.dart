import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../store/task_store.dart';
import '../store/project_store.dart';
import '../models/index.dart';
import '../widgets/task_item.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/empty_state.dart';
import '../constants/theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskStore = TaskStore();
    final projectStore = ProjectStore();

    return AnimatedBuilder(
      animation: Listenable.merge([taskStore, projectStore]),
      builder: (context, _) {
        final allDue = taskStore.todayTasks;

        final today = _dateStr(DateTime.now());
        final overdue = allDue.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.compareTo(today) < 0;
        }).toList();
        final todayOnly = allDue.where((t) {
          if (t.dueDate == null) return true; // no-date tasks in today
          return t.dueDate!.compareTo(today) >= 0;
        }).toList();

        // Build a flat list with header sentinel strings interspersed
        final items = <dynamic>[];
        if (overdue.isNotEmpty) {
          items.add('__overdue__');
          items.addAll(overdue);
        }
        items.add('__today__');
        items.addAll(todayOnly);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: const TextStyle(
                      color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          body: taskStore.loading
              ? const Center(child: CircularProgressIndicator())
              : allDue.isEmpty
                  ? EmptyState(
                      icon: Icons.wb_sunny_outlined,
                      title: "All clear! 🎉",
                      subtitle: "No tasks due today.\nEnjoy your day!",
                      actionLabel: 'Add a task',
                      onAction: () => showQuickAdd(context),
                      iconColor: kPrimary,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        if (item == '__overdue__') {
                          return _SectionHeader(
                            title: 'Overdue',
                            count: overdue.length,
                            color: kP1Red,
                          );
                        }
                        if (item == '__today__') {
                          return _SectionHeader(
                            title: DateFormat('EEE d MMM').format(DateTime.now()),
                            count: todayOnly.length,
                          );
                        }
                        final task = item as Task;
                        final project = projectStore.getById(task.projectId ?? 'inbox');
                        return TaskItem(
                          key: ValueKey(task.id),
                          task: task,
                          showProject: true,
                          projectName: project?.name,
                          projectColor: project?.color,
                          onTap: () => showTaskDetail(context, task),
                          onComplete: () => taskStore.completeTask(task.id),
                          onDelete: () => taskStore.deleteTask(task.id),
                          onSchedule: () => showRescheduleSheet(context, task),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showQuickAdd(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;

  const _SectionHeader({required this.title, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color ?? Theme.of(context).textTheme.titleMedium?.color)),
          const SizedBox(width: kSpace8),
          Text('$count', style: const TextStyle(color: kTextMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
