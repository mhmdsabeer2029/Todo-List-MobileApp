import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../store/task_store.dart';
import '../constants/theme.dart';
import '../utils/date_utils.dart' as du;

Future<void> showRescheduleSheet(BuildContext context, Task task) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _RescheduleSheet(task: task),
  );
}

class _RescheduleSheet extends StatelessWidget {
  final Task task;
  const _RescheduleSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = TaskStore();
    final now = DateTime.now();

    Future<void> pick(DateTime date) async {
      final updated = task.copyWith(
        dueDate: du.AppDateUtils.toIsoDate(date),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await store.updateTask(updated);
      if (context.mounted) Navigator.pop(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkSurface : kLightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? kDarkBorder : kLightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace16, kSpace8, kSpace16, kSpace4),
              child: Text('Reschedule',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            _Option(
              icon: Icons.wb_sunny_outlined,
              label: 'Today',
              sublabel: DateFormat('EEE, MMM d').format(now),
              onTap: () => pick(now),
            ),
            _Option(
              icon: Icons.wb_twighlight,
              label: 'Tomorrow',
              sublabel: DateFormat('EEE, MMM d').format(now.add(const Duration(days: 1))),
              onTap: () => pick(now.add(const Duration(days: 1))),
            ),
            _Option(
              icon: Icons.next_week_outlined,
              label: 'Next Week',
              sublabel: DateFormat('EEE, MMM d').format(now.add(const Duration(days: 7))),
              onTap: () => pick(now.add(const Duration(days: 7))),
            ),
            _Option(
              icon: Icons.calendar_month_outlined,
              label: 'Pick a Date',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) await pick(picked);
              },
            ),
            if (task.dueDate != null)
              _Option(
                icon: Icons.event_busy_outlined,
                label: 'Remove Date',
                color: kP1Red,
                onTap: () async {
                  final updated = task.copyWith(
                    dueDate: null,
                    updatedAt: DateTime.now().toIso8601String(),
                  );
                  await store.updateTask(updated);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            const SizedBox(height: kSpace8),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Color? color;

  const _Option({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).textTheme.bodyMedium?.color;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      trailing: sublabel != null
          ? Text(sublabel!, style: const TextStyle(color: kTextMuted, fontSize: 13))
          : null,
      onTap: onTap,
    );
  }
}
