import 'dart:convert';
import 'package:http/http.dart' as http;
import 'groq_service.dart' show kGroqApiKey, isGroqConfigured;

/// A single task candidate extracted from a spreadsheet row by Groq.
class SheetTaskCandidate {
  final String title;
  final String? dueDate; // YYYY-MM-DD
  final String? priority; // p1..p4
  final String? project;
  final List<String> labels;
  final String? notes;
  final int sourceRow;
  bool selected;

  SheetTaskCandidate({
    required this.title,
    required this.sourceRow,
    this.dueDate,
    this.priority,
    this.project,
    this.labels = const [],
    this.notes,
    this.selected = true,
  });

  factory SheetTaskCandidate.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final labels = <String>[];
    if (rawLabels is List) {
      labels.addAll(rawLabels.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
    }
    return SheetTaskCandidate(
      title: (json['title'] ?? '').toString().trim(),
      dueDate: _orNull(json['dueDate']),
      priority: _orNull(json['priority']),
      project: _orNull(json['project']),
      labels: labels,
      notes: _orNull(json['notes']),
      sourceRow: json['row'] is int ? json['row'] as int : int.tryParse('${json['row']}') ?? -1,
    );
  }

  static String? _orNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }
}

/// Converts raw spreadsheet grids into precise task candidates using Groq.
///
/// The model is given the *entire* grid (header row + data rows, per tab)
/// and asked to identify which rows look like actionable tasks, mapping
/// whatever columns exist (Task/Title/Name, Due/Date, Priority, Project,
/// Status, Notes, etc., in any language or column order) onto a strict
/// schema. Rows that are clearly already completed/done are excluded by
/// default unless `includeCompleted` is true.
class SheetsImportService {
  Future<List<SheetTaskCandidate>> extractTasks(
    Map<String, List<List<String>>> sheetData, {
    bool includeCompleted = false,
  }) async {
    if (!isGroqConfigured) {
      throw StateError(
        'Groq is not configured. Pass --dart-define=GROQ_API_KEY=... when '
        'building/running the app to enable sheet import.',
      );
    }
    final candidates = <SheetTaskCandidate>[];

    for (final entry in sheetData.entries) {
      final tabName = entry.key;
      final rows = entry.value;
      if (rows.isEmpty) continue;

      // Groq context windows are large but we still chunk very large tabs
      // to keep extraction accurate and avoid truncation.
      const chunkSize = 80;
      for (var start = 0; start < rows.length; start += chunkSize) {
        final chunk = rows.sublist(start, (start + chunkSize).clamp(0, rows.length));
        final extracted = await _extractChunk(
          tabName: tabName,
          rows: chunk,
          rowOffset: start,
          includeCompleted: includeCompleted,
        );
        candidates.addAll(extracted);
      }
    }

    return candidates;
  }

  Future<List<SheetTaskCandidate>> _extractChunk({
    required String tabName,
    required List<List<String>> rows,
    required int rowOffset,
    required bool includeCompleted,
  }) async {
    // Render the grid as a compact, row-numbered CSV-like block so Groq can
    // precisely reference which row each task came from.
    final buffer = StringBuffer();
    for (var i = 0; i < rows.length; i++) {
      final rowNum = rowOffset + i + 1; // 1-indexed, matches sheet row numbers
      buffer.writeln('Row $rowNum: ${rows[i].join(" | ")}');
    }

    final prompt = '''
You are scanning a Google Sheets tab named "$tabName" to find actionable
to-do tasks. The grid below may use any column layout, any language
(including Arabic/Egyptian Arabic), and may include a header row.

Grid:
${buffer.toString()}

Instructions:
- Treat any row that names a concrete, actionable item as a task candidate
  (e.g. a "Task", "Item", "Action", "To-Do" column, or a row that simply
  reads like one thing to do).
- Skip rows that are clearly just headers, totals, blank, or notes-only
  with no actionable item.
${includeCompleted ? '' : '- Skip rows that are clearly marked as done/complete/✓/finished in a status column.'}
- Map whatever date-like column exists to dueDate in YYYY-MM-DD format
  (use null if no date or it's ambiguous - do not guess a date that isn't
  there).
- Map any priority/urgency indicator to "p1" (urgent), "p2" (high),
  "p3" (medium), or "p4" (default/none).
- Map any category/project/list column to "project".
- Map any tags/labels column to a "labels" array.
- Put any extra descriptive column content into "notes".
- "row" must be the exact Row number shown in the grid for that item.

Return ONLY a JSON array, no prose, shaped like:
[{"title":"...","dueDate":"YYYY-MM-DD|null","priority":"p1|p2|p3|p4|null","project":"...|null","labels":["..."],"notes":"...|null","row":12}]

If there are no actionable tasks in this grid, return [].
''';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $kGroqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'temperature': 0.1,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a precise spreadsheet-to-tasks extraction engine. '
                'Reply with a compact JSON array only, never prose, never markdown fences.',
          },
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('Groq request failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    final content = (choices?.isNotEmpty == true ? choices!.first['message']?['content'] : null);
    final text = content?.toString() ?? '[]';
    final jsonArray = _extractJsonArray(text);

    return jsonArray
        .whereType<Map<String, dynamic>>()
        .map(SheetTaskCandidate.fromJson)
        .where((c) => c.title.isNotEmpty)
        .toList();
  }

  List<dynamic> _extractJsonArray(String text) {
    final trimmed = text.trim();
    final start = trimmed.indexOf('[');
    final end = trimmed.lastIndexOf(']');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(trimmed.substring(start, end + 1));
        if (decoded is List) return decoded;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }
}
