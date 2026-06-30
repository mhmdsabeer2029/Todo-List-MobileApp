import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/index.dart';
import 'task_store.dart';

// ─── Project Store ────────────────────────────────────────────────────────────

class ProjectStore extends ChangeNotifier {
  static final ProjectStore _instance = ProjectStore._internal();
  factory ProjectStore() => _instance;
  ProjectStore._internal();

  final AppDatabase _db = AppDatabase();
  final _uuid = const Uuid();

  List<Project> _projects = [];
  List<Project> get projects => _projects;
  List<Project> get activeProjects => _projects.where((p) => !p.isArchived).toList();
  List<Project> get favoriteProjects => _projects.where((p) => p.isFavorite && !p.isArchived).toList();

  Project? getById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAll() async {
    _projects = await _db.getAllProjects(includeArchived: true);
    notifyListeners();
  }

  Future<Project> addProject({
    required String name,
    String color = '#4073FF',
    String emoji = '📋',
  }) async {
    final now = DateTime.now().toIso8601String();
    final project = Project(
      id: _uuid.v4(),
      name: name,
      color: color,
      emoji: emoji,
      orderIndex: _projects.length,
      createdAt: now,
    );
    await _db.insertProject(project);
    _projects.add(project);
    notifyListeners();
    return project;
  }

  Future<void> updateProject(Project updated) async {
    await _db.updateProject(updated);
    final idx = _projects.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) _projects[idx] = updated;
    notifyListeners();
  }

  /// Deletes the project. Tasks that belonged to it are reassigned to
  /// Inbox at the database layer (see AppDatabase.deleteProject); we mirror
  /// that here in the in-memory TaskStore so open screens immediately show
  /// the tasks in Inbox instead of having them disappear until next reload.
  Future<void> deleteProject(String id) async {
    if (id == 'inbox') return; // Inbox is permanent
    _projects.removeWhere((p) => p.id == id);
    notifyListeners();
    await _db.deleteProject(id);
    TaskStore().reassignProjectTasksToInbox(id);
  }

  Future<void> archiveProject(String id) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = _projects[idx].copyWith(isArchived: true);
    await updateProject(updated);
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = _projects[idx];
    await updateProject(p.copyWith(isFavorite: !p.isFavorite));
  }

  Future<int> getTaskCount(String projectId) =>
      _db.getProjectTaskCount(projectId);

  Future<int> getCompletedCount(String projectId) =>
      _db.getProjectCompletedCount(projectId);
}

// ─── Label Store ──────────────────────────────────────────────────────────────

class LabelStore extends ChangeNotifier {
  static final LabelStore _instance = LabelStore._internal();
  factory LabelStore() => _instance;
  LabelStore._internal();

  final AppDatabase _db = AppDatabase();
  final _uuid = const Uuid();

  List<Label> _labels = [];
  List<Label> get labels => _labels;

  Label? getById(String id) {
    try {
      return _labels.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAll() async {
    _labels = await _db.getAllLabels();
    notifyListeners();
  }

  Future<Label> addLabel({required String name, String color = '#8C8C8C'}) async {
    final now = DateTime.now().toIso8601String();
    final label = Label(id: _uuid.v4(), name: name, color: color, createdAt: now);
    await _db.insertLabel(label);
    _labels.add(label);
    notifyListeners();
    return label;
  }

  Future<void> updateLabel(Label updated) async {
    await _db.updateLabel(updated);
    final idx = _labels.indexWhere((l) => l.id == updated.id);
    if (idx >= 0) _labels[idx] = updated;
    notifyListeners();
  }

  /// Deletes the label. The database layer also removes this label's
  /// task_labels rows (see AppDatabase.deleteLabel), so we mirror that here
  /// by stripping the label id from every in-memory task's labelIds too —
  /// otherwise tasks already loaded into TaskStore would keep reporting
  /// they have a label that no longer exists until the next full reload.
  Future<void> deleteLabel(String id) async {
    _labels.removeWhere((l) => l.id == id);
    notifyListeners();
    await _db.deleteLabel(id);
    TaskStore().removeLabelFromAllTasks(id);
  }
}
