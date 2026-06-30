/// Web-compatible replacement for database.dart.
///
/// sqflite does NOT run in a browser. This implementation stores everything
/// as JSON blobs in shared_preferences (which uses localStorage on web).
/// The public API is intentionally identical to AppDatabase in database.dart
/// so all stores and screens work without any changes.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/index.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Low-level JSON helpers ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final p = await _p;
    await p.setString(key, jsonEncode(items));
  }

  Future<void> _ensureSeeded() async {
    final projects = await _readList('projects');
    if (projects.any((p) => p['id'] == 'inbox')) return;
    final now = DateTime.now().toIso8601String();
    projects.insert(0, {
      'id': 'inbox',
      'name': 'Inbox',
      'color': '#DC4C3E',
      'emoji': '📥',
      'is_favorite': 0,
      'is_archived': 0,
      'order_index': 0,
      'created_at': now,
    });
    await _writeList('projects', projects);
  }

  // ─── Tasks ────────────────────────────────────────────────────────────────

  Future<List<Task>> getAllTasks({bool includeCompleted = true}) async {
    await _ensureSeeded();
    final rows = await _readList('tasks');
    final labels = await _readList('task_labels');
    final sorted = [...rows]
      ..sort((a, b) {
        final oi = (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0);
        if (oi != 0) return oi;
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });

    return sorted
        .where((r) => includeCompleted || (r['is_completed'] as int? ?? 0) == 0)
        .map((r) {
          final taskId = r['id'] as String;
          final taskLabelIds = labels
              .where((l) => l['task_id'] == taskId)
              .map((l) => l['label_id'] as String)
              .toList();
          return Task.fromMap(r, labelIds: taskLabelIds);
        })
        .toList();
  }

  Future<List<Task>> getTasksDueToday() async {
    final today = _dateStr(DateTime.now());
    final all = await getAllTasks(includeCompleted: false);
    return all
        .where((t) => t.dueDate == null || t.dueDate!.compareTo(today) <= 0)
        .toList();
  }

  Future<List<Task>> getTasksForProject(String projectId) async {
    final all = await getAllTasks();
    return all.where((t) => t.projectId == projectId && t.parentTaskId == null).toList();
  }

  Future<List<Task>> getSubtasks(String parentId) async {
    final all = await getAllTasks();
    return all.where((t) => t.parentTaskId == parentId).toList();
  }

  Future<List<Task>> getTasksUpcoming(int days) async {
    final today = _dateStr(DateTime.now());
    final end = _dateStr(DateTime.now().add(Duration(days: days)));
    final all = await getAllTasks(includeCompleted: false);
    return all
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.compareTo(today) >= 0 &&
            t.dueDate!.compareTo(end) <= 0)
        .toList();
  }

  Future<List<Task>> searchTasks(String query) async {
    final q = query.toLowerCase();
    final all = await getAllTasks();
    return all
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q))
        .toList();
  }

  Future<List<Task>> getCompletedTasks({String? fromDate, String? toDate}) async {
    final all = await getAllTasks(includeCompleted: true);
    return all.where((t) {
      if (!t.isCompleted) return false;
      if (fromDate != null && (t.completedAt == null || t.completedAt!.compareTo(fromDate) < 0)) return false;
      if (toDate != null && (t.completedAt == null || t.completedAt!.compareTo(toDate) > 0)) return false;
      return true;
    }).toList();
  }

  Future<Task?> getTask(String id) async {
    final all = await getAllTasks();
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertTask(Task task) async {
    final rows = await _readList('tasks');
    rows.removeWhere((r) => r['id'] == task.id);
    rows.add(task.toMap());
    await _writeList('tasks', rows);
    await _syncTaskLabels(task.id, task.labelIds);
  }

  Future<void> updateTask(Task task) async {
    final rows = await _readList('tasks');
    final idx = rows.indexWhere((r) => r['id'] == task.id);
    if (idx >= 0) {
      rows[idx] = task.toMap();
    } else {
      rows.add(task.toMap());
    }
    await _writeList('tasks', rows);
    await _syncTaskLabels(task.id, task.labelIds);
  }

  Future<void> deleteTask(String id) async {
    var rows = await _readList('tasks');
    rows.removeWhere((r) => r['id'] == id || r['parent_task_id'] == id);
    await _writeList('tasks', rows);

    var labels = await _readList('task_labels');
    labels.removeWhere((l) => l['task_id'] == id);
    await _writeList('task_labels', labels);

    var comments = await _readList('comments');
    comments.removeWhere((c) => c['task_id'] == id);
    await _writeList('comments', comments);
  }

  Future<void> clearCompletedTasks() async {
    var rows = await _readList('tasks');
    rows.removeWhere((r) => (r['is_completed'] as int? ?? 0) == 1);
    await _writeList('tasks', rows);
  }

  Future<void> _syncTaskLabels(String taskId, List<String> labelIds) async {
    var labels = await _readList('task_labels');
    labels.removeWhere((l) => l['task_id'] == taskId);
    for (final lid in labelIds) {
      labels.add({'task_id': taskId, 'label_id': lid});
    }
    await _writeList('task_labels', labels);
  }

  Future<List<String>> getTaskLabelIds(String taskId) async {
    final labels = await _readList('task_labels');
    return labels
        .where((l) => l['task_id'] == taskId)
        .map((l) => l['label_id'] as String)
        .toList();
  }

  // ─── Projects ─────────────────────────────────────────────────────────────

  Future<List<Project>> getAllProjects({bool includeArchived = false}) async {
    await _ensureSeeded();
    final rows = await _readList('projects');
    final sorted = [...rows]
      ..sort((a, b) {
        final oi = (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0);
        if (oi != 0) return oi;
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });
    return sorted
        .where((r) => includeArchived || (r['is_archived'] as int? ?? 0) == 0)
        .map(Project.fromMap)
        .toList();
  }

  Future<Project?> getProject(String id) async {
    final all = await getAllProjects(includeArchived: true);
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertProject(Project project) async {
    final rows = await _readList('projects');
    rows.removeWhere((r) => r['id'] == project.id);
    rows.add(project.toMap());
    await _writeList('projects', rows);
  }

  Future<void> updateProject(Project project) async {
    final rows = await _readList('projects');
    final idx = rows.indexWhere((r) => r['id'] == project.id);
    if (idx >= 0) {
      rows[idx] = project.toMap();
    } else {
      rows.add(project.toMap());
    }
    await _writeList('projects', rows);
  }

  Future<void> deleteProject(String id) async {
    // Reassign tasks to inbox
    final tasks = await _readList('tasks');
    for (final t in tasks) {
      if (t['project_id'] == id) t['project_id'] = 'inbox';
    }
    await _writeList('tasks', tasks);

    // Delete sections
    var sections = await _readList('sections');
    sections.removeWhere((s) => s['project_id'] == id);
    await _writeList('sections', sections);

    // Delete project
    var projects = await _readList('projects');
    projects.removeWhere((p) => p['id'] == id);
    await _writeList('projects', projects);
  }

  Future<int> getProjectTaskCount(String projectId) async {
    final all = await getAllTasks(includeCompleted: false);
    return all.where((t) => t.projectId == projectId).length;
  }

  Future<int> getProjectCompletedCount(String projectId) async {
    final all = await getAllTasks(includeCompleted: true);
    return all.where((t) => t.projectId == projectId && t.isCompleted).length;
  }

  // ─── Labels ───────────────────────────────────────────────────────────────

  Future<List<Label>> getAllLabels() async {
    final rows = await _readList('labels');
    rows.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return rows.map(Label.fromMap).toList();
  }

  Future<void> insertLabel(Label label) async {
    final rows = await _readList('labels');
    rows.removeWhere((r) => r['id'] == label.id);
    rows.add(label.toMap());
    await _writeList('labels', rows);
  }

  Future<void> updateLabel(Label label) async {
    final rows = await _readList('labels');
    final idx = rows.indexWhere((r) => r['id'] == label.id);
    if (idx >= 0) {
      rows[idx] = label.toMap();
    } else {
      rows.add(label.toMap());
    }
    await _writeList('labels', rows);
  }

  Future<void> deleteLabel(String id) async {
    var rows = await _readList('labels');
    rows.removeWhere((r) => r['id'] == id);
    await _writeList('labels', rows);

    var links = await _readList('task_labels');
    links.removeWhere((l) => l['label_id'] == id);
    await _writeList('task_labels', links);
  }

  // ─── Sections ─────────────────────────────────────────────────────────────

  Future<List<Section>> getSectionsForProject(String projectId) async {
    final rows = await _readList('sections');
    return rows
        .where((r) => r['project_id'] == projectId)
        .map(Section.fromMap)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  Future<void> insertSection(Section section) async {
    final rows = await _readList('sections');
    rows.removeWhere((r) => r['id'] == section.id);
    rows.add(section.toMap());
    await _writeList('sections', rows);
  }

  Future<void> updateSection(Section section) async {
    final rows = await _readList('sections');
    final idx = rows.indexWhere((r) => r['id'] == section.id);
    if (idx >= 0) rows[idx] = section.toMap(); else rows.add(section.toMap());
    await _writeList('sections', rows);
  }

  Future<void> deleteSection(String id) async {
    var rows = await _readList('sections');
    rows.removeWhere((r) => r['id'] == id);
    await _writeList('sections', rows);
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  Future<List<Comment>> getCommentsForTask(String taskId) async {
    final rows = await _readList('comments');
    return rows
        .where((r) => r['task_id'] == taskId)
        .map(Comment.fromMap)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> insertComment(Comment comment) async {
    final rows = await _readList('comments');
    rows.add(comment.toMap());
    await _writeList('comments', rows);
  }

  Future<void> deleteComment(String id) async {
    var rows = await _readList('comments');
    rows.removeWhere((r) => r['id'] == id);
    await _writeList('comments', rows);
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<TaskStats> getStats() async {
    final all = await getAllTasks(includeCompleted: true);
    final completed = all.where((t) => t.isCompleted).toList();

    final today = _dateStr(DateTime.now());
    final weekAgo = _dateStr(DateTime.now().subtract(const Duration(days: 7)));
    final monthStart = _dateStr(DateTime(DateTime.now().year, DateTime.now().month, 1));

    final completedToday = completed
        .where((t) => t.completedAt != null && t.completedAt!.startsWith(today))
        .length;
    final completedThisWeek = completed
        .where((t) => t.completedAt != null && t.completedAt!.compareTo(weekAgo) >= 0)
        .length;
    final completedThisMonth = completed
        .where((t) => t.completedAt != null && t.completedAt!.compareTo(monthStart) >= 0)
        .length;

    final completedDates = completed
        .where((t) => t.completedAt != null)
        .map((t) => t.completedAt!.substring(0, 10))
        .toSet();

    int streak = 0;
    DateTime check = DateTime.now();
    while (completedDates.contains(_dateStr(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }

    final dayStats = <DayStats>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final ds = _dateStr(d);
      final dayCompleted = completed
          .where((t) => t.completedAt != null && t.completedAt!.startsWith(ds))
          .length;
      final dayAdded = all.where((t) => t.createdAt.startsWith(ds)).length;
      dayStats.add(DayStats(date: ds, completed: dayCompleted, added: dayAdded));
    }

    return TaskStats(
      completedToday: completedToday,
      completedThisWeek: completedThisWeek,
      completedThisMonth: completedThisMonth,
      streak: streak,
      karma: completedThisMonth * 10 + streak * 5,
      lastSevenDays: dayStats,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
