import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../store/task_store.dart';
import '../store/project_store.dart';
import '../models/index.dart';
import '../widgets/task_item.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/empty_state.dart';
import '../constants/theme.dart';

class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskStore = TaskStore();
    final projectStore = ProjectStore();

    return AnimatedBuilder(
      animation: Listenable.merge([taskStore, projectStore]),
      builder: (context, _) {
        final tasks = taskStore.upcomingTasks(7);
        final grouped = groupBy<Task, String>(tasks, (t) => t.dueDate ?? '');

        final dates = List.generate(7, (i) {
          final d = DateTime.now().add(Duration(days: i));
          return '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('Upcoming',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
          ),
          body: tasks.isEmpty
              ? EmptyState(
                  icon: Icons.event_outlined,
                  title: 'Nothing scheduled',
                  subtitle: 'Tasks with due dates in the next 7 days appear here.',
                  actionLabel: 'Add a task',
                  onAction: () => showQuickAdd(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: dates.length,
                  itemBuilder: (ctx, di) {
                    final date = dates[di];
                    final dayTasks = grouped[date] ?? [];
                    if (dayTasks.isEmpty) return const SizedBox.shrink();

                    final dateTime = DateTime.parse(date);
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final diff = DateTime(dateTime.year, dateTime.month, dateTime.day)
                        .difference(today)
                        .inDays;

                    String dayLabel;
                    if (diff == 0) {
                      dayLabel = 'Today · ${DateFormat('MMM d').format(dateTime)}';
                    } else if (diff == 1) {
                      dayLabel = 'Tomorrow · ${DateFormat('MMM d').format(dateTime)}';
                    } else {
                      dayLabel = DateFormat('EEEE · MMM d').format(dateTime);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              kSpace16, kSpace16, kSpace16, kSpace4),
                          child: Row(
                            children: [
                              Text(dayLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: kSpace8),
                              Text('${dayTasks.length}',
                                  style: const TextStyle(
                                      color: kTextMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                        ...dayTasks.map((task) {
                          final project =
                              projectStore.getById(task.projectId ?? 'inbox');
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
                        }),
                      ],
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
}
