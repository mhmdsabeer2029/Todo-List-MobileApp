import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../store/task_store.dart';
import '../store/project_store.dart';
import '../store/label_store.dart';
import '../models/index.dart';
import '../widgets/task_item.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/empty_state.dart';
import '../constants/theme.dart';
import '../utils/groq_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TaskStore _taskStore = TaskStore();
  final ProjectStore _projectStore = ProjectStore();
  final LabelStore _labelStore = LabelStore();
  final GroqService _groqService = GroqService();
  final TextEditingController _queryCtrl = TextEditingController();
  List<Task> _results = [];
  bool _hasSearched = false;
  bool _aiSearching = false;
  String? _aiSearchError;
  String? _aiSummaryLabel;

  // Remembers the most recently applied AI filter (if any) so that when
  // results need refreshing after a task mutation (complete/delete), we
  // re-apply the same AI filter instead of silently reverting to plain
  // substring search and showing a different result set than the user
  // was just looking at.
  GroqSearchFilter? _activeAiFilter;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  /// Re-runs whichever search mode (AI filter or plain substring) produced
  /// the current results, used after a task is completed/deleted from the
  /// results list so the list stays consistent with what the user was
  /// actually looking at.
  void _refreshResults() {
    if (_activeAiFilter != null) {
      setState(() => _results = _applyAiFilter(_activeAiFilter!));
    } else {
      _search(_queryCtrl.text);
    }
  }

  void _search(String query) {
    setState(() {
      _hasSearched = true;
      _aiSummaryLabel = null;
      _aiSearchError = null;
      _activeAiFilter = null;
      _results = _taskStore.search(query);
    });
  }

  /// Runs the query through Groq to derive structured filters (project,
  /// label, priority, time window, overdue/completed) instead of plain
  /// substring matching, then applies those filters against the in-memory
  /// task list. Falls back silently to the plain substring search on any
  /// failure (no key configured, network error, etc.).
  Future<void> _searchWithAi(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _aiSearching = true;
      _aiSearchError = null;
      _hasSearched = true;
    });
    try {
      final filter = await _groqService.parseSearchQuery(
        query,
        existingProjects: _projectStore.activeProjects.map((p) => p.name).toList(),
        existingLabels: _labelStore.labels.map((l) => l.name).toList(),
      );

      final results = _applyAiFilter(filter);

      if (mounted) {
        setState(() {
          _activeAiFilter = filter;
          _results = results;
          _aiSearching = false;
          _aiSummaryLabel = _describeFilter(filter);
        });
      }
    } catch (e) {
      // Fall back to the plain substring search so the user still gets
      // something useful even if Groq is unavailable.
      if (mounted) {
        setState(() {
          _aiSearching = false;
          _aiSearchError = 'AI search unavailable, showing keyword matches instead.';
          _activeAiFilter = null;
          _results = _taskStore.search(query);
        });
      }
    }
  }

  /// Applies a previously-derived AI search filter to the current
  /// in-memory task list. Pulled out of [_searchWithAi] so [_refreshResults]
  /// can re-apply the same filter after a task mutation without re-calling
  /// Groq.
  List<Task> _applyAiFilter(GroqSearchFilter filter) {
    final projectId = filter.project != null
        ? _projectStore.activeProjects
            .where((p) => p.name.toLowerCase() == filter.project!.toLowerCase())
            .firstOrNull
            ?.id
        : null;
    final labelId = filter.label != null
        ? _labelStore.labels
            .where((l) => l.name.toLowerCase() == filter.label!.toLowerCase())
            .firstOrNull
            ?.id
        : null;
    final now = DateTime.now();
    final cutoff = filter.dueWithinDays != null
        ? DateTime(now.year, now.month, now.day).add(Duration(days: filter.dueWithinDays!))
        : null;

    return _taskStore.tasks.where((t) {
      if (filter.completedOnly && !t.isCompleted) return false;
      if (!filter.completedOnly && t.isCompleted) return false;
      if (projectId != null && t.projectId != projectId) return false;
      if (labelId != null && !t.labelIds.contains(labelId)) return false;
      if (filter.priority != null && t.priority != filter.priority) return false;

      if (filter.overdueOnly || cutoff != null) {
        if (t.dueDate == null) return false;
        final due = DateTime.tryParse(t.dueDate!);
        if (due == null) return false;
        final dueDay = DateTime(due.year, due.month, due.day);
        final today = DateTime(now.year, now.month, now.day);
        if (filter.overdueOnly && !dueDay.isBefore(today)) return false;
        if (cutoff != null && dueDay.isAfter(cutoff)) return false;
      }

      if (filter.keywords.isNotEmpty) {
        final haystack = '${t.title} ${t.description}'.toLowerCase();
        return filter.keywords.any((k) => haystack.contains(k.toLowerCase()));
      }
      return true;
    }).toList();
  }

  String _describeFilter(GroqSearchFilter f) {
    final parts = <String>[];
    if (f.overdueOnly) parts.add('overdue');
    if (f.completedOnly) parts.add('completed');
    if (f.project != null) parts.add('in "${f.project}"');
    if (f.label != null) parts.add('labeled "${f.label}"');
    if (f.priority != null) parts.add('P${f.priority}');
    if (f.dueWithinDays != null) parts.add('due within ${f.dueWithinDays}d');
    return parts.isEmpty ? 'AI search' : 'AI search: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26)),
      ),
      body: Column(
        children: [
          // ─── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, kSpace8),
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: 'Search, or try "overdue work tasks this week"…',
                prefixIcon: const Icon(Icons.search, color: kTextMuted),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_queryCtrl.text.isNotEmpty)
                      _aiSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.auto_awesome, color: kP3Blue, size: 20),
                              tooltip: 'Search with AI',
                              onPressed: () => _searchWithAi(_queryCtrl.text),
                            ),
                    if (_queryCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: kTextMuted),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                            _aiSummaryLabel = null;
                            _aiSearchError = null;
                          });
                        },
                      ),
                  ],
                ),
                filled: true,
                fillColor: isDark ? kDarkSurface : kLightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (v) => _searchWithAi(v.trim()),
              onChanged: (v) {
                if (v.trim().length > 1) {
                  _search(v.trim());
                } else {
                  setState(() {
                    _results = [];
                    _hasSearched = v.isNotEmpty;
                    _aiSummaryLabel = null;
                    _aiSearchError = null;
                  });
                }
              },
            ),
          ),

          if (_aiSummaryLabel != null || _aiSearchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, kSpace8),
              child: Text(
                _aiSearchError ?? _aiSummaryLabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: _aiSearchError != null ? kP1Red : kP3Blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // ─── Results ────────────────────────────────────────────────────
          Expanded(
            child: !_hasSearched
                ? _RecentTasks(taskStore: _taskStore)
                : _results.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No results found',
                        subtitle: 'Try different keywords, or tap ✨ to search with AI',
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final task = _results[i];
                          final project =
                              _projectStore.getById(task.projectId ?? 'inbox');
                          return TaskItem(
                            key: ValueKey(task.id),
                            task: task,
                            showProject: true,
                            projectName: project?.name,
                            projectColor: project?.color,
                            onTap: () => showTaskDetail(context, task),
                            onComplete: () {
                              _taskStore.completeTask(task.id);
                              _refreshResults();
                            },
                            onDelete: () {
                              _taskStore.deleteTask(task.id);
                              _refreshResults();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _RecentTasks extends StatelessWidget {
  final TaskStore taskStore;
  const _RecentTasks({required this.taskStore});

  @override
  Widget build(BuildContext context) {
    final recent = taskStore.tasks
        .where((t) => !t.isCompleted)
        .take(5)
        .toList();

    if (recent.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your tasks',
        subtitle: 'Find any task, project, or label instantly',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: kSpace16),
      children: [
        const SizedBox(height: kSpace16),
        const Text('Recent Tasks',
            style: TextStyle(
                color: kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: kSpace8),
        ...recent.map((t) => ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18, color: kTextMuted),
              title: Text(t.title),
              onTap: () => showTaskDetail(context, t),
            )),
      ],
    );
  }
}
