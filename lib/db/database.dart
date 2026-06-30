import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/index.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'todolist.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        project_id TEXT,
        parent_task_id TEXT,
        priority INTEGER DEFAULT 4,
        due_date TEXT,
        due_time TEXT,
        reminder_minutes INTEGER,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        is_recurring INTEGER DEFAULT 0,
        recurrence_rule TEXT,
        order_index INTEGER DEFAULT 0,
        section_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT,
        emoji TEXT,
        is_favorite INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE task_labels (
        task_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        PRIMARY KEY (task_id, label_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sections (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        name TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Seed Inbox project
    final now = DateTime.now().toIso8601String();
    await db.insert('projects', {
      'id': 'inbox',
      'name': 'Inbox',
      'color': '#DC4C3E',
      'emoji': '📥',
      'is_favorite': 0,
      'is_archived': 0,
      'order_index': 0,
      'created_at': now,
    });
  }

  // ─── Tasks ────────────────────────────────────────────────────────────────

  Future<List<Task>> getAllTasks({bool includeCompleted = true}) async {
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: includeCompleted ? null : 'is_completed = 0',
      orderBy: 'order_index ASC, created_at ASC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  /// Tasks that should show on the "Today" screen: anything overdue,
  /// anything due today, and anything with no due date at all (mirrors
  /// TaskStore.todayTasks, which is what the UI actually uses — this
  /// DB-level query exists for completeness/future use).
  Future<List<Task>> getTasksDueToday() async {
    final today = _dateStr(DateTime.now());
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: "is_completed = 0 AND (due_date IS NULL OR due_date <= ?)",
      whereArgs: [today],
      orderBy: 'priority ASC, order_index ASC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<List<Task>> getTasksForProject(String projectId) async {
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: 'project_id = ? AND parent_task_id IS NULL',
      whereArgs: [projectId],
      orderBy: 'order_index ASC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<List<Task>> getSubtasks(String parentId) async {
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: 'parent_task_id = ?',
      whereArgs: [parentId],
      orderBy: 'order_index ASC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<List<Task>> getTasksUpcoming(int days) async {
    final today = _dateStr(DateTime.now());
    final end = _dateStr(DateTime.now().add(Duration(days: days)));
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: 'due_date >= ? AND due_date <= ? AND is_completed = 0',
      whereArgs: [today, end],
      orderBy: 'due_date ASC, priority ASC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<List<Task>> searchTasks(String query) async {
    final database = await db;
    final q = '%${query.toLowerCase()}%';
    final rows = await database.rawQuery(
      "SELECT * FROM tasks WHERE LOWER(title) LIKE ? OR LOWER(description) LIKE ? ORDER BY created_at DESC",
      [q, q],
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<List<Task>> getCompletedTasks({String? fromDate, String? toDate}) async {
    final database = await db;
    String where = 'is_completed = 1';
    List<Object?> args = [];
    if (fromDate != null) {
      where += ' AND completed_at >= ?';
      args.add(fromDate);
    }
    if (toDate != null) {
      where += ' AND completed_at <= ?';
      args.add(toDate);
    }
    final rows = await database.query(
      'tasks',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'completed_at DESC',
    );
    return Future.wait(rows.map((r) async {
      final labels = await getTaskLabelIds(r['id'] as String);
      return Task.fromMap(r, labelIds: labels);
    }));
  }

  Future<Task?> getTask(String id) async {
    final database = await db;
    final rows = await database.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final labels = await getTaskLabelIds(id);
    return Task.fromMap(rows.first, labelIds: labels);
  }

  Future<void> insertTask(Task task) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await _syncTaskLabels(txn, task.id, task.labelIds);
    });
  }

  Future<void> updateTask(Task task) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
      await _syncTaskLabels(txn, task.id, task.labelIds);
    });
  }

  Future<void> deleteTask(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      await txn.delete('task_labels', where: 'task_id = ?', whereArgs: [id]);
      await txn.delete('comments', where: 'task_id = ?', whereArgs: [id]);
      // also delete subtasks
      await txn.delete('tasks', where: 'parent_task_id = ?', whereArgs: [id]);
    });
  }

  Future<void> clearCompletedTasks() async {
    final database = await db;
    await database.delete('tasks', where: 'is_completed = 1');
  }

  Future<void> _syncTaskLabels(Transaction txn, String taskId, List<String> labelIds) async {
    await txn.delete('task_labels', where: 'task_id = ?', whereArgs: [taskId]);
    for (final lid in labelIds) {
      await txn.insert('task_labels', {'task_id': taskId, 'label_id': lid},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<String>> getTaskLabelIds(String taskId) async {
    final database = await db;
    final rows = await database.query('task_labels', where: 'task_id = ?', whereArgs: [taskId]);
    return rows.map((r) => r['label_id'] as String).toList();
  }

  // ─── Projects ─────────────────────────────────────────────────────────────

  Future<List<Project>> getAllProjects({bool includeArchived = false}) async {
    final database = await db;
    final rows = await database.query(
      'projects',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'order_index ASC, created_at ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project?> getProject(String id) async {
    final database = await db;
    final rows = await database.query('projects', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Project.fromMap(rows.first);
  }

  Future<void> insertProject(Project project) async {
    final database = await db;
    await database.insert('projects', project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProject(Project project) async {
    final database = await db;
    await database.update('projects', project.toMap(), where: 'id = ?', whereArgs: [project.id]);
  }

  /// Deletes the project and reassigns any of its tasks to Inbox (the
  /// caller's confirmation dialog promises tasks "will remain in Inbox",
  /// so this must actually happen rather than leaving tasks pointing at a
  /// project_id that no longer exists, which would make them vanish from
  /// every screen).
  Future<void> deleteProject(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.update(
        'tasks',
        {'project_id': 'inbox'},
        where: 'project_id = ?',
        whereArgs: [id],
      );
      await txn.delete('sections', where: 'project_id = ?', whereArgs: [id]);
      await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> getProjectTaskCount(String projectId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM tasks WHERE project_id = ? AND is_completed = 0',
      [projectId],
    );
    return result.first['cnt'] as int;
  }

  Future<int> getProjectCompletedCount(String projectId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM tasks WHERE project_id = ? AND is_completed = 1',
      [projectId],
    );
    return result.first['cnt'] as int;
  }

  // ─── Labels ───────────────────────────────────────────────────────────────

  Future<List<Label>> getAllLabels() async {
    final database = await db;
    final rows = await database.query('labels', orderBy: 'name ASC');
    return rows.map(Label.fromMap).toList();
  }

  Future<void> insertLabel(Label label) async {
    final database = await db;
    await database.insert('labels', label.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLabel(Label label) async {
    final database = await db;
    await database.update('labels', label.toMap(), where: 'id = ?', whereArgs: [label.id]);
  }

  Future<void> deleteLabel(String id) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('labels', where: 'id = ?', whereArgs: [id]);
      await txn.delete('task_labels', where: 'label_id = ?', whereArgs: [id]);
    });
  }

  // ─── Sections ─────────────────────────────────────────────────────────────

  Future<List<Section>> getSectionsForProject(String projectId) async {
    final database = await db;
    final rows = await database.query(
      'sections',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'order_index ASC',
    );
    return rows.map(Section.fromMap).toList();
  }

  Future<void> insertSection(Section section) async {
    final database = await db;
    await database.insert('sections', section.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSection(Section section) async {
    final database = await db;
    await database.update('sections', section.toMap(), where: 'id = ?', whereArgs: [section.id]);
  }

  Future<void> deleteSection(String id) async {
    final database = await db;
    await database.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  Future<List<Comment>> getCommentsForTask(String taskId) async {
    final database = await db;
    final rows = await database.query(
      'comments',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Comment.fromMap).toList();
  }

  Future<void> insertComment(Comment comment) async {
    final database = await db;
    await database.insert('comments', comment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteComment(String id) async {
    final database = await db;
    await database.delete('comments', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<TaskStats> getStats() async {
    final database = await db;
    final today = _dateStr(DateTime.now());
    final weekStart = _dateStr(DateTime.now().subtract(const Duration(days: 7)));
    final monthStart = DateTime.now().copyWith(day: 1);
    final monthStartStr = _dateStr(monthStart);

    final todayResult = await database.rawQuery(
        "SELECT COUNT(*) as cnt FROM tasks WHERE is_completed = 1 AND DATE(completed_at) = ?", [today]);
    final weekResult = await database.rawQuery(
        "SELECT COUNT(*) as cnt FROM tasks WHERE is_completed = 1 AND completed_at >= ?", [weekStart]);
    final monthResult = await database.rawQuery(
        "SELECT COUNT(*) as cnt FROM tasks WHERE is_completed = 1 AND completed_at >= ?", [monthStartStr]);

    final completedToday = todayResult.first['cnt'] as int;
    final completedThisWeek = weekResult.first['cnt'] as int;
    final completedThisMonth = monthResult.first['cnt'] as int;

    // Compute streak. Previously this ran one sequential DB query per day
    // of streak (DATE(completed_at) = ? in a loop) — fine for a few days,
    // but for a long-time user with e.g. a 400-day streak that's 400
    // sequential awaited round-trips every time this screen loads. Instead,
    // fetch every distinct completion date once and walk backwards through
    // that set in memory.
    final completedDatesResult = await database.rawQuery(
        "SELECT DISTINCT DATE(completed_at) as d FROM tasks WHERE is_completed = 1 AND completed_at IS NOT NULL");
    final completedDates = completedDatesResult.map((r) => r['d'] as String).toSet();

    int streak = 0;
    DateTime check = DateTime.now();
    while (completedDates.contains(_dateStr(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }

    // Last 7 days chart
    final dayStats = <DayStats>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final ds = _dateStr(d);
      final comp = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM tasks WHERE is_completed = 1 AND DATE(completed_at) = ?", [ds]);
      final added = await database.rawQuery(
          "SELECT COUNT(*) as cnt FROM tasks WHERE DATE(created_at) = ?", [ds]);
      dayStats.add(DayStats(
        date: ds,
        completed: comp.first['cnt'] as int,
        added: added.first['cnt'] as int,
      ));
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
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
