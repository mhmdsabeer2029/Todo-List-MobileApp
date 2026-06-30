import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../constants/theme.dart';

class TaskItem extends StatefulWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback? onSchedule;
  final bool showProject;
  final String? projectName;
  final String? projectColor;

  const TaskItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
    this.onSchedule,
    this.showProject = false,
    this.projectName,
    this.projectColor,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    await _checkController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    widget.onComplete();
    // onComplete() typically removes this task from whatever list rendered
    // it (e.g. it disappears from Today/Inbox once completed), which can
    // dispose this widget before we get back here. Guard against using the
    // controller after dispose.
    if (!mounted) return;
    await _checkController.reverse();
  }

  Color get _priorityColor => priorityColor(widget.task.priority);

  bool get _isOverdue {
    if (widget.task.dueDate == null || widget.task.isCompleted) return false;
    final due = DateTime.tryParse(widget.task.dueDate!);
    if (due == null) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  String? get _dueDateLabel {
    if (widget.task.dueDate == null) return null;
    final due = DateTime.tryParse(widget.task.dueDate!);
    if (due == null) return widget.task.dueDate;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDate = DateTime(due.year, due.month, due.day);
    final diff = dueDate.difference(todayDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff}d overdue';
    if (diff < 7) return DateFormat('EEEE').format(due);
    return DateFormat('MMM d').format(due);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Slidable(
      key: ValueKey(widget.task.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              widget.onDelete();
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              widget.onSchedule?.call();
            },
            backgroundColor: kP3Blue,
            foregroundColor: Colors.white,
            icon: Icons.schedule,
            label: 'Reschedule',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _opacityAnim,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace12),
              decoration: BoxDecoration(
                color: isDark ? kDarkSurface : kLightSurface,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? kDarkBorder : kLightBorder,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Priority Circle Checkbox ──────────────────────────────
                  GestureDetector(
                    onTap: _handleComplete,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1, right: kSpace12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.task.isCompleted ? _priorityColor : Colors.transparent,
                        border: Border.all(
                          color: _priorityColor,
                          width: 2,
                        ),
                      ),
                      child: widget.task.isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ),

                  // ─── Task Content ──────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.task.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            decoration: widget.task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.task.isCompleted
                                ? kTextMuted
                                : (isDark ? kDarkTextPrimary : kLightTextPrimary),
                          ),
                        ),

                        // Description snippet
                        if (widget.task.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.task.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],

                        // Meta row: date, project, labels
                        if (_dueDateLabel != null ||
                            widget.showProject && widget.projectName != null ||
                            widget.task.isRecurring ||
                            widget.task.labelIds.isNotEmpty) ...[
                          const SizedBox(height: kSpace4),
                          Wrap(
                            spacing: kSpace8,
                            runSpacing: 2,
                            children: [
                              if (_dueDateLabel != null)
                                _MetaChip(
                                  icon: Icons.calendar_today_outlined,
                                  label: _dueDateLabel!,
                                  color: _isOverdue ? kP1Red : kTextMuted,
                                ),
                              if (widget.task.dueTime != null)
                                _MetaChip(
                                  icon: Icons.access_time,
                                  label: widget.task.dueTime!,
                                  color: kTextMuted,
                                ),
                              if (widget.task.isRecurring)
                                _MetaChip(
                                  icon: Icons.repeat,
                                  label: '',
                                  color: kP3Blue,
                                ),
                              if (widget.showProject && widget.projectName != null)
                                _MetaChip(
                                  icon: Icons.circle,
                                  iconSize: 8,
                                  label: widget.projectName!,
                                  color: _hexToColor(widget.projectColor ?? '#4073FF'),
                                ),
                              if (widget.task.reminderMinutes != null)
                                _MetaChip(
                                  icon: Icons.notifications_none,
                                  label: '',
                                  color: kTextMuted,
                                ),
                            ],
                          ),
                        ],
                      ],
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

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return kP4Gray;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ],
    );
  }
}
