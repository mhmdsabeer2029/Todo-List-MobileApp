import 'package:flutter/material.dart';
import '../store/task_store.dart';
import '../widgets/task_item.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/reschedule_sheet.dart';
import '../widgets/empty_state.dart';
import '../constants/theme.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskStore = TaskStore();

    return AnimatedBuilder(
      animation: taskStore,
      builder: (context, _) {
        final tasks = taskStore.inboxTasks;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inbox',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
                Text('${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          body: tasks.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Inbox Zero! 🎉',
                  subtitle:
                      'Tasks without a project land here.\nStay organized!',
                  actionLabel: 'Add a task',
                  onAction: () => showQuickAdd(context, projectId: 'inbox'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) {
                    final task = tasks[i];
                    return TaskItem(
                      key: ValueKey(task.id),
                      task: task,
                      onTap: () => showTaskDetail(context, task),
                      onComplete: () => taskStore.completeTask(task.id),
                      onDelete: () => taskStore.deleteTask(task.id),
                      onSchedule: () => showRescheduleSheet(context, task),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showQuickAdd(context, projectId: 'inbox'),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
