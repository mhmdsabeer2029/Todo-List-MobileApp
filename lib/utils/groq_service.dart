import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/index.dart';
import 'local_secrets.dart';

/// Groq API key. Reads from lib/utils/local_secrets.dart (gitignored, never
/// committed) by default, so `flutter run` works with no extra flags. Can
/// also be overridden at build time via:
///   flutter run --dart-define=GROQ_API_KEY=your_key_here
const String kGroqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: kLocalGroqApiKey);

bool get isGroqConfigured => kGroqApiKey.isNotEmpty;

class GroqTaskIntent {
  final String title;
  final String? dueDate;
  final String? dueTime;
  final String? projectName;
  final List<String> labels;
  final int priority;
  final bool recurring;
  final String? recurrence;
  final int? reminderMinutes;

  const GroqTaskIntent({
    required this.title,
    this.dueDate,
    this.dueTime,
    this.projectName,
    this.labels = const [],
    this.priority = 4,
    this.recurring = false,
    this.recurrence,
    this.reminderMinutes,
  });

  factory GroqTaskIntent.fromJson(Map<String, dynamic> json) {
    final priorityValue = (json['priority'] ?? json['priorityLevel'] ?? 'p4').toString().toLowerCase();
    int priority = 4;
    if (priorityValue == 'p1' || priorityValue == '1' || priorityValue == 'urgent') {
      priority = 1;
    } else if (priorityValue == 'p2' || priorityValue == '2' || priorityValue == 'high') {
      priority = 2;
    } else if (priorityValue == 'p3' || priorityValue == '3' || priorityValue == 'medium') {
      priority = 3;
    }

    final labels = <String>[];
    final rawLabels = json['labels'];
    if (rawLabels is List) {
      for (final item in rawLabels) {
        final label = item.toString().trim();
        if (label.isNotEmpty) labels.add(label);
      }
    } else if (rawLabels is String && rawLabels.trim().isNotEmpty) {
      labels.addAll(rawLabels.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    // A task is recurring only if the model explicitly said so (recurring:
    // true) or gave an actual, non-null frequency string. A merely-absent
    // "recurrence" key must NOT be treated as recurring.
    final recurrenceStr = _stringOrNull(json['recurrence']);
    final isRecurring = json['recurring'] == true || recurrenceStr != null;

    return GroqTaskIntent(
      title: (json['title'] ?? json['task'] ?? '').toString().trim(),
      dueDate: _stringOrNull(json['dueDate']),
      dueTime: _stringOrNull(json['dueTime']),
      projectName: _stringOrNull(json['project'] ?? json['projectName']),
      labels: labels,
      priority: priority,
      recurring: isRecurring,
      recurrence: recurrenceStr,
      reminderMinutes: json['reminderMinutes'] is int
          ? json['reminderMinutes'] as int
          : int.tryParse(json['reminderMinutes']?.toString() ?? ''),
    );
  }

  ParsedTask toParsedTask() {
    final recurrenceText = recurrence?.toLowerCase();
    RecurrenceRule? recurrenceRule;
    if (recurrenceText == 'daily') {
      recurrenceRule = const RecurrenceRule(frequency: 'daily', interval: 1, raw: 'DAILY;INTERVAL=1');
    } else if (recurrenceText == 'weekly') {
      recurrenceRule = const RecurrenceRule(frequency: 'weekly', interval: 1, raw: 'WEEKLY;INTERVAL=1');
    } else if (recurrenceText == 'monthly') {
      recurrenceRule = const RecurrenceRule(frequency: 'monthly', interval: 1, raw: 'MONTHLY;INTERVAL=1');
    }

    return ParsedTask(
      cleanTitle: title,
      dueDate: dueDate,
      dueTime: dueTime,
      projectName: projectName,
      labelNames: labels,
      priority: priority,
      isRecurring: recurring,
      recurrenceRule: recurrenceRule,
      reminderMinutes: reminderMinutes,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class GroqService {
  /// Low-level call to the Groq chat completions endpoint with retry +
  /// exponential backoff for transient failures (timeouts, 5xx, network
  /// errors). Does NOT retry on 4xx (bad request / bad key) since retrying
  /// those just wastes calls on something that won't change.
  Future<String> _complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
    int maxRetries = 2,
  }) async {
    if (!isGroqConfigured) {
      throw StateError(
        'Groq is not configured. Set kLocalGroqApiKey in '
        'lib/utils/local_secrets.dart or pass --dart-define=GROQ_API_KEY=...',
      );
    }

    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Authorization': 'Bearer $kGroqApiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'llama-3.3-70b-versatile',
                'temperature': temperature,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userPrompt},
                ],
              }),
            )
            .timeout(const Duration(seconds: 20));

        // 4xx: don't retry, it won't succeed on retry (bad key, bad request).
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception('Groq request failed: ${response.statusCode} ${response.body}');
        }
        // 5xx / unexpected: worth retrying.
        if (response.statusCode >= 500) {
          throw Exception('Groq server error: ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        final message = choices?.firstOrNull?['message'];
        final content = message?['content'];
        if (content is List) {
          return content.map((e) => e['text']?.toString() ?? '').join();
        }
        return content?.toString() ?? '';
      } catch (e) {
        lastError = e;
        // Don't retry 4xx-style failures (StateError/bad-request Exception
        // text containing a 4xx code) — only retry on timeouts, network
        // errors, and 5xx.
        final isClientError = e is Exception && e.toString().contains('Groq request failed:');
        if (isClientError || attempt == maxRetries) break;
        await Future.delayed(Duration(milliseconds: 400 * (1 << attempt))); // 400ms, 800ms, ...
      }
    }
    throw lastError ?? Exception('Groq request failed for an unknown reason.');
  }

  Future<GroqTaskIntent> parseTaskIntent(
    String input, {
    List<String> existingProjects = const [],
    List<String> existingLabels = const [],
  }) async {
    final contextBlock = StringBuffer();
    if (existingProjects.isNotEmpty) {
      contextBlock.writeln(
        'Existing projects (reuse these exact names if the task matches one '
        'of them instead of inventing a new similar name): '
        '${existingProjects.join(", ")}',
      );
    }
    if (existingLabels.isNotEmpty) {
      contextBlock.writeln(
        'Existing labels (reuse these exact names if applicable instead of '
        'inventing new similar ones): ${existingLabels.join(", ")}',
      );
    }

    final prompt = '''
You are an expert task planner for a mobile productivity app.
Understand Egyptian Arabic slang, Egyptian colloquial phrases, and English.
Examples: "عايز أعمل", "أنا عايز", "بدي", "أيوه", "هعمل", "أضيف" all mean create a task.
Examples: "مفيش" or "مافيش" mean ignore or no-op.

$contextBlock
Return ONLY valid JSON with this shape:
{"title":"...","dueDate":"YYYY-MM-DD|null","dueTime":"HH:mm|null","project":"...","labels":["..."],"priority":"p1|p2|p3|p4","recurring":true|false,"recurrence":"daily|weekly|monthly|null","reminderMinutes":30}

Rules:
- If the user asks for a reminder, set reminderMinutes to 30 or another sensible number.
- If the task is clearly about a project or category, put it in project. Prefer matching an existing project name (case-insensitively) over creating a new one.
- If the user mentions labels, tags, categories, or contexts, put them in labels. Prefer matching existing label names over creating new ones.
- If the user says "بكرة" or "غدا" use tomorrow's date.
- If the user says "اليوم" use today's date.
- If the user says "النهاردة" use today's date.
- If the user says "الساعة 9" or "ساعه 9" use 09:00.
- If the user says "الساعة 3" and it's in the afternoon, use 15:00.
- If the request is vague or just greeting, create a simple task like "General task".
- If the input is not a task, return {"title":"General task"}.

Input: $input
''';

    final text = await _complete(
      systemPrompt: 'You are a strict JSON task parser. Reply with compact JSON only.',
      userPrompt: prompt,
      temperature: 0.2,
    );
    return GroqTaskIntent.fromJson(_extractJsonMap(text));
  }

  /// Translates a natural-language search query into structured filters
  /// over the user's existing tasks, instead of plain substring matching.
  /// Returns a [GroqSearchFilter] describing what to look for; the caller
  /// applies it against the in-memory task list.
  Future<GroqSearchFilter> parseSearchQuery(
    String query, {
    required List<String> existingProjects,
    required List<String> existingLabels,
  }) async {
    final prompt = '''
You are translating a natural-language search query into structured filters
for a to-do app, in English, Arabic, or Egyptian Arabic colloquial.

Existing projects: ${existingProjects.join(", ")}
Existing labels: ${existingLabels.join(", ")}

Return ONLY valid JSON with this shape:
{"keywords":["..."],"project":"...|null","label":"...|null","priority":"p1|p2|p3|p4|null","dueWithinDays":7|null,"overdueOnly":false,"completedOnly":false}

Rules:
- keywords: important words from the query to match against task titles/descriptions (excluding stop words and the project/label/time words you've already extracted).
- project/label: only set if it clearly maps to one of the existing names above (case-insensitive match), else null.
- dueWithinDays: set if the user implies a time window (e.g. "this week" → 7, "today" → 0, "this month" → 30), else null.
- overdueOnly: true only if the user explicitly asks for overdue/late tasks.
- completedOnly: true only if the user explicitly asks for completed/done tasks.

Query: $query
''';

    final text = await _complete(
      systemPrompt: 'You are a strict JSON search-query parser. Reply with compact JSON only.',
      userPrompt: prompt,
      temperature: 0.1,
    );
    return GroqSearchFilter.fromJson(_extractJsonMap(text));
  }

  /// Suggests 3-5 concrete subtasks for a given task title/description.
  /// Purely advisory — the caller shows these to the user to accept or
  /// reject individually; nothing is written automatically.
  Future<List<String>> suggestSubtasks({
    required String title,
    String description = '',
  }) async {
    final prompt = '''
Break the following task into 3 to 5 concrete, actionable subtasks. Keep
each subtask short (under 8 words). Respond in the same language as the
task (English or Arabic/Egyptian Arabic).

Task: $title
${description.isNotEmpty ? 'Details: $description' : ''}

Return ONLY a JSON array of strings, e.g. ["...", "...", "..."]. No prose.
''';

    final text = await _complete(
      systemPrompt: 'You are a precise task-breakdown assistant. Reply with a compact JSON array only.',
      userPrompt: prompt,
      temperature: 0.4,
    );
    final list = _extractJsonArray(text);
    return list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Analyses the user's current projects/labels/tasks and returns
  /// advisory maintenance suggestions (possible duplicate projects, stale
  /// tasks, underused labels, etc.). Every suggestion is something the user
  /// reviews and applies manually — this method never changes any data
  /// itself.
  Future<List<MaintenanceSuggestion>> getMaintenanceSuggestions({
    required List<String> projectNames,
    required List<String> labelNames,
    required List<Map<String, dynamic>> staleTasks, // {title, daysSinceCreated}
  }) async {
    final prompt = '''
You are reviewing a to-do app's data for housekeeping opportunities. You
NEVER take action yourself — you only propose suggestions for a human to
review and approve.

Projects: ${projectNames.join(", ")}
Labels: ${labelNames.join(", ")}
Tasks with no due date, sitting unfinished for a while (title — days old):
${staleTasks.map((t) => '- ${t['title']} — ${t['daysSinceCreated']} days').join('\n')}

Look for:
- Possible duplicate or near-duplicate project names (e.g. "Work" and "work stuff").
- Possible duplicate or near-duplicate label names.
- Tasks that have been sitting a long time (60+ days) with no due date that
  might be worth archiving, completing, or scheduling.
- Labels that don't appear meaningfully distinct from others.

Return ONLY a JSON array, each item shaped like:
{"type":"duplicate_project|duplicate_label|stale_task|other","title":"short headline","detail":"one sentence explanation","items":["...","..."]}

If nothing stands out, return [].
''';

    final text = await _complete(
      systemPrompt: 'You are a careful, conservative data-hygiene advisor. Reply with a compact JSON array only. Never recommend deleting data outright — only review/merge/archive suggestions.',
      userPrompt: prompt,
      temperature: 0.3,
    );
    final list = _extractJsonArray(text);
    return list
        .whereType<Map<String, dynamic>>()
        .map(MaintenanceSuggestion.fromJson)
        .toList();
  }

  Map<String, dynamic> _extractJsonMap(String text) {
    final trimmed = text.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final jsonText = trimmed.substring(start, end + 1);
      return jsonDecode(jsonText) as Map<String, dynamic>;
    }
    return <String, dynamic>{'title': 'General task'};
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

/// Structured filters derived from a natural-language search query.
class GroqSearchFilter {
  final List<String> keywords;
  final String? project;
  final String? label;
  final int? priority;
  final int? dueWithinDays;
  final bool overdueOnly;
  final bool completedOnly;

  const GroqSearchFilter({
    this.keywords = const [],
    this.project,
    this.label,
    this.priority,
    this.dueWithinDays,
    this.overdueOnly = false,
    this.completedOnly = false,
  });

  factory GroqSearchFilter.fromJson(Map<String, dynamic> json) {
    final keywords = <String>[];
    final rawKeywords = json['keywords'];
    if (rawKeywords is List) {
      keywords.addAll(rawKeywords.map((e) => e.toString().trim()).where((s) => s.isNotEmpty));
    }

    int? priority;
    final p = json['priority']?.toString().toLowerCase();
    if (p == 'p1') priority = 1;
    if (p == 'p2') priority = 2;
    if (p == 'p3') priority = 3;
    if (p == 'p4') priority = 4;

    return GroqSearchFilter(
      keywords: keywords,
      project: _orNull(json['project']),
      label: _orNull(json['label']),
      priority: priority,
      dueWithinDays: json['dueWithinDays'] is int ? json['dueWithinDays'] as int : null,
      overdueOnly: json['overdueOnly'] == true,
      completedOnly: json['completedOnly'] == true,
    );
  }

  static String? _orNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s.toLowerCase() == 'null') ? null : s;
  }
}

/// A single advisory maintenance suggestion. Never applied automatically —
/// always surfaced to the user to accept/dismiss.
class MaintenanceSuggestion {
  final String type;
  final String title;
  final String detail;
  final List<String> items;

  const MaintenanceSuggestion({
    required this.type,
    required this.title,
    required this.detail,
    this.items = const [],
  });

  factory MaintenanceSuggestion.fromJson(Map<String, dynamic> json) {
    final items = <String>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      items.addAll(rawItems.map((e) => e.toString()));
    }
    return MaintenanceSuggestion(
      type: (json['type'] ?? 'other').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      items: items,
    );
  }
}

extension _ListFirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
