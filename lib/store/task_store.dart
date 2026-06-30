import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../models/index.dart';
import '../utils/notification_service.dart';

class TaskStore extends ChangeNotifier {
  static final TaskStore _instance = TaskStore._internal();
  factory TaskStore() => _instance;
  TaskStore._internal();

  final AppDatabase _db = AppDatabase();
  final _uuid = const Uuid();

  List<Task> _tasks = [];
  bool _loading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;

  List<Task> get todayTasks {
    final today = _dateStr(DateTime.now());
    return _tasks.where((t) =>
      !t.isCompleted &&
      (t.dueDate == null || t.dueDate!.compareTo(today) <= 0)
    ).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<Task> get inboxTasks => _tasks
      .where((t) => (t.projectId == null || t.projectId == 'inbox') && !t.isCompleted)
      .toList();

  List<Task> upcomingTasks(int days) {
    final today = _dateStr(DateTime.now());
    final end = _dateStr(DateTime.now().add(Duration(days: days)));
    return _tasks.where((t) =>
      !t.isCompleted &&
      t.dueDate != null &&
      t.dueDate!.compareTo(today) >= 0 &&
      t.dueDate!.compareTo(end) <= 0
    ).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  List<Task> tasksForProject(String projectId) =>
      _tasks.where((t) => t.projectId == projectId && t.parentTaskId == null).toList();

  List<Task> tasksForLabel(String labelId) =>
      _tasks.where((t) => t.labelIds.contains(labelId)).toList();

  List<Task> subtasksFor(String parentId) =>
      _tasks.where((t) => t.parentTaskId == parentId).toList();

  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  List<Task> search(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _tasks.where((t) =>
      t.title.toLowerCase().contains(q) ||
      t.description.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _tasks = await _db.getAllTasks();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Task> addTask({
    required String title,
    String description = '',
    String? projectId,
    String? parentTaskId,
    int priority = 4,
    String? dueDate,
    String? dueTime,
    int? reminderMinutes,
    bool isRecurring = false,
    RecurrenceRule? recurrenceRule,
    String? sectionId,
    List<String> labelIds = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final nextOrderIndex = _tasks.isEmpty
        ? 0
        : _tasks.map((t) => t.orderIndex).reduce((a, b) => a > b ? a : b) + 1;
    final task = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      projectId: projectId ?? 'inbox',
      parentTaskId: parentTaskId,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      reminderMinutes: reminderMinutes,
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
      orderIndex: nextOrderIndex,
      sectionId: sectionId,
      labelIds: labelIds,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertTask(task);
    _tasks.add(task);
    notifyListeners();

    if (task.reminderMinutes != null && task.dueDate != null) {
      await NotificationService().scheduleTaskReminder(task);
    }

    return task;
  }

  Future<void> updateTask(Task updated) async {
    final now = DateTime.now().toIso8601String();
    final task = updated.copyWith(updatedAt: now);
    await _db.updateTask(task);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    notifyListeners();

    await NotificationService().cancelTaskReminder(task.id);
    if (task.reminderMinutes != null && task.dueDate != null && !task.isCompleted) {
      await NotificationService().scheduleTaskReminder(task);
    }
  }

  Future<void> completeTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final task = _tasks[idx];
    final now = DateTime.now().toIso8601String();
    final updated = task.copyWith(
      isCompleted: true,
      completedAt: now,
      updatedAt: now,
    );
    _tasks[idx] = updated;
    notifyListeners();

    await _db.updateTask(updated);
    await NotificationService().cancelTaskReminder(id);

    // Handle recurring: create next occurrence
    if (task.isRecurring && task.recurrenceRule != null && task.dueDate != null) {
      await _createNextRecurrence(task);
    }
  }

  Future<void> uncompleteTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final task = _tasks[idx];
    final updated = task.copyWith(
      isCompleted: false,
      completedAt: null,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _tasks[idx] = updated;
    notifyListeners();
    await _db.updateTask(updated);
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id || t.parentTaskId == id);
    notifyListeners();
    await _db.deleteTask(id);
    await NotificationService().cancelTaskReminder(id);
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
    await _db.clearCompletedTasks();
  }

  /// Reorders a task within whatever filtered/visible list the UI is
  /// currently showing (e.g. just today's tasks, or just one project's
  /// tasks) and persists the new order.
  ///
  /// [visibleTasks] is a subset of all tasks, not the full list — it must
  /// NOT be renumbered with local 0..N-1 indices, since order_index is a
  /// single global ordering shared by every view. Re-using 0..N-1 here
  /// would collide with the order_index values already used by tasks in
  /// every *other* filtered view, scrambling order everywhere else.
  /// Instead we redistribute the *existing* order_index values already
  /// held by this subset (sorted ascending) across the new arrangement, so
  /// only the relative order within this subset changes and every task
  /// outside it is left completely alone.
  Future<void> reorderTask(int oldIndex, int newIndex, List<Task> visibleTasks) async {
    final orderedSlots = visibleTasks.map((t) => t.orderIndex).toList()..sort();

    final reordered = List<Task>.from(visibleTasks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i].copyWith(orderIndex: orderedSlots[i]);
      reordered[i] = updated;
      final globalIdx = _tasks.indexWhere((t) => t.id == updated.id);
      if (globalIdx >= 0) _tasks[globalIdx] = updated;
    }
    notifyListeners();

    for (final t in reordered) {
      await _db.updateTask(t);
    }
  }

  Future<void> _createNextRecurrence(Task original) async {
    final rule = original.recurrenceRule!;
    final dueParts = original.dueDate!.split('-');
    final due = DateTime(
      int.parse(dueParts[0]),
      int.parse(dueParts[1]),
      int.parse(dueParts[2]),
    );

    DateTime nextDue;
    switch (rule.frequency) {
      case 'daily':
        nextDue = due.add(Duration(days: rule.interval));
        break;
      case 'weekly':
        nextDue = due.add(Duration(days: 7 * rule.interval));
        break;
      case 'monthly':
        nextDue = _addMonthsClamped(due, rule.interval);
        break;
      default:
        nextDue = due.add(Duration(days: rule.interval));
    }

    await addTask(
      title: original.title,
      description: original.description,
      projectId: original.projectId,
      priority: original.priority,
      dueDate: _dateStr(nextDue),
      dueTime: original.dueTime,
      reminderMinutes: original.reminderMinutes,
      isRecurring: true,
      recurrenceRule: original.recurrenceRule,
      sectionId: original.sectionId,
      labelIds: original.labelIds,
    );
  }

  /// Called by ProjectStore after a project is deleted. The database layer
  /// already reassigns those tasks' project_id to 'inbox'; this mirrors
  /// that in the in-memory list so they don't appear to vanish until the
  /// next full reload.
  void reassignProjectTasksToInbox(String deletedProjectId) {
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].projectId == deletedProjectId) {
        _tasks[i] = _tasks[i].copyWith(projectId: 'inbox');
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Called by LabelStore after a label is deleted, to keep in-memory tasks
  /// consistent with the database (which already dropped the association).
  void removeLabelFromAllTasks(String labelId) {
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].labelIds.contains(labelId)) {
        final newLabelIds = _tasks[i].labelIds.where((l) => l != labelId).toList();
        _tasks[i] = _tasks[i].copyWith(labelIds: newLabelIds);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Adds [months] calendar months to [date], clamping the day-of-month to
  /// the last valid day of the target month instead of letting it silently
  /// roll over into the following month. Plain `DateTime(year, month + n,
  /// day)` rolls Jan 31 + 1 month into early March (since February doesn't
  /// have 31 days) rather than landing on Feb 28/29 as a user would expect
  /// for a "monthly" recurrence.
  DateTime _addMonthsClamped(DateTime date, int months) {
    final totalMonths = date.year * 12 + (date.month - 1) + months;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
    return DateTime(year, month, day);
  }

  Future<TaskStats> getStats() => _db.getStats();

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
