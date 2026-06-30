// ─── models/index.dart ────────────────────────────────────────────────────────

// Priority type: 1 (highest) to 4 (lowest)
typedef Priority = int;

// ─── RecurrenceRule ───────────────────────────────────────────────────────────

class RecurrenceRule {
  final String frequency; // 'daily' | 'weekly' | 'monthly' | 'custom'
  final int interval;
  final List<String>? byDay; // ['MO', 'WE', 'FR']
  final int? byMonthDay;
  final String? endDate;
  final int? count;
  final String raw;

  const RecurrenceRule({
    required this.frequency,
    required this.interval,
    this.byDay,
    this.byMonthDay,
    this.endDate,
    this.count,
    required this.raw,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
    frequency: json['frequency'] as String,
    interval: json['interval'] as int,
    byDay: json['byDay'] != null ? List<String>.from(json['byDay'] as List) : null,
    byMonthDay: json['byMonthDay'] as int?,
    endDate: json['endDate'] as String?,
    count: json['count'] as int?,
    raw: json['raw'] as String,
  );

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'interval': interval,
    if (byDay != null) 'byDay': byDay,
    if (byMonthDay != null) 'byMonthDay': byMonthDay,
    if (endDate != null) 'endDate': endDate,
    if (count != null) 'count': count,
    'raw': raw,
  };
}

// ─── Task ─────────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String title;
  final String description;
  final String? projectId;
  final String? parentTaskId;
  final int priority;
  final String? dueDate;
  final String? dueTime;
  final int? reminderMinutes;
  final bool isCompleted;
  final String? completedAt;
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final int orderIndex;
  final String? sectionId;
  final List<String> labelIds;
  final String createdAt;
  final String updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.projectId,
    this.parentTaskId,
    this.priority = 4,
    this.dueDate,
    this.dueTime,
    this.reminderMinutes,
    this.isCompleted = false,
    this.completedAt,
    this.isRecurring = false,
    this.recurrenceRule,
    this.orderIndex = 0,
    this.sectionId,
    this.labelIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    Object? projectId = _sentinel,
    Object? parentTaskId = _sentinel,
    int? priority,
    Object? dueDate = _sentinel,
    Object? dueTime = _sentinel,
    Object? reminderMinutes = _sentinel,
    bool? isCompleted,
    Object? completedAt = _sentinel,
    bool? isRecurring,
    Object? recurrenceRule = _sentinel,
    int? orderIndex,
    Object? sectionId = _sentinel,
    List<String>? labelIds,
    String? createdAt,
    String? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      projectId: projectId == _sentinel ? this.projectId : projectId as String?,
      parentTaskId: parentTaskId == _sentinel ? this.parentTaskId : parentTaskId as String?,
      priority: priority ?? this.priority,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as String?,
      dueTime: dueTime == _sentinel ? this.dueTime : dueTime as String?,
      reminderMinutes: reminderMinutes == _sentinel ? this.reminderMinutes : reminderMinutes as int?,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt == _sentinel ? this.completedAt : completedAt as String?,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule == _sentinel ? this.recurrenceRule : recurrenceRule as RecurrenceRule?,
      orderIndex: orderIndex ?? this.orderIndex,
      sectionId: sectionId == _sentinel ? this.sectionId : sectionId as String?,
      labelIds: labelIds ?? this.labelIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Task.fromMap(Map<String, dynamic> m, {List<String> labelIds = const []}) {
    return Task(
      id: m['id'] as String,
      title: m['title'] as String,
      description: m['description'] as String? ?? '',
      projectId: m['project_id'] as String?,
      parentTaskId: m['parent_task_id'] as String?,
      priority: m['priority'] as int? ?? 4,
      dueDate: m['due_date'] as String?,
      dueTime: m['due_time'] as String?,
      reminderMinutes: m['reminder_minutes'] as int?,
      isCompleted: (m['is_completed'] as int? ?? 0) == 1,
      completedAt: m['completed_at'] as String?,
      isRecurring: (m['is_recurring'] as int? ?? 0) == 1,
      recurrenceRule: m['recurrence_rule'] != null
          ? _parseRecurrenceRule(m['recurrence_rule'] as String)
          : null,
      orderIndex: m['order_index'] as int? ?? 0,
      sectionId: m['section_id'] as String?,
      labelIds: labelIds,
      createdAt: m['created_at'] as String,
      updatedAt: m['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'project_id': projectId,
    'parent_task_id': parentTaskId,
    'priority': priority,
    'due_date': dueDate,
    'due_time': dueTime,
    'reminder_minutes': reminderMinutes,
    'is_completed': isCompleted ? 1 : 0,
    'completed_at': completedAt,
    'is_recurring': isRecurring ? 1 : 0,
    'recurrence_rule': recurrenceRule?.raw,
    'order_index': orderIndex,
    'section_id': sectionId,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static RecurrenceRule? _parseRecurrenceRule(String raw) {
    try {
      final parts = raw.split(';');
      final freq = parts.first;
      int interval = 1;
      List<String>? byDay;
      for (final part in parts.skip(1)) {
        if (part.startsWith('INTERVAL=')) {
          interval = int.tryParse(part.split('=').last) ?? 1;
        }
        if (part.startsWith('BYDAY=')) {
          byDay = part.split('=').last.split(',');
        }
      }
      return RecurrenceRule(
        frequency: freq.toLowerCase(),
        interval: interval,
        byDay: byDay,
        raw: raw,
      );
    } catch (_) {
      return null;
    }
  }
}

// Sentinel for copyWith nullability
const Object _sentinel = Object();

// ─── Project ──────────────────────────────────────────────────────────────────

class Project {
  final String id;
  final String name;
  final String color;
  final String emoji;
  final bool isFavorite;
  final bool isArchived;
  final int orderIndex;
  final String createdAt;

  const Project({
    required this.id,
    required this.name,
    this.color = '#4073FF',
    this.emoji = '📋',
    this.isFavorite = false,
    this.isArchived = false,
    this.orderIndex = 0,
    required this.createdAt,
  });

  Project copyWith({
    String? name,
    String? color,
    String? emoji,
    bool? isFavorite,
    bool? isArchived,
    int? orderIndex,
  }) => Project(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    emoji: emoji ?? this.emoji,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt,
  );

  factory Project.fromMap(Map<String, dynamic> m) => Project(
    id: m['id'] as String,
    name: m['name'] as String,
    color: m['color'] as String? ?? '#4073FF',
    emoji: m['emoji'] as String? ?? '📋',
    isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
    isArchived: (m['is_archived'] as int? ?? 0) == 1,
    orderIndex: m['order_index'] as int? ?? 0,
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'emoji': emoji,
    'is_favorite': isFavorite ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
    'order_index': orderIndex,
    'created_at': createdAt,
  };
}

// ─── Label ────────────────────────────────────────────────────────────────────

class Label {
  final String id;
  final String name;
  final String color;
  final String createdAt;

  const Label({
    required this.id,
    required this.name,
    this.color = '#8C8C8C',
    required this.createdAt,
  });

  Label copyWith({String? name, String? color}) => Label(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    createdAt: createdAt,
  );

  factory Label.fromMap(Map<String, dynamic> m) => Label(
    id: m['id'] as String,
    name: m['name'] as String,
    color: m['color'] as String? ?? '#8C8C8C',
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => ({
    'id': id,
    'name': name,
    'color': color,
    'created_at': createdAt,
  });
}

// ─── Section ──────────────────────────────────────────────────────────────────

class Section {
  final String id;
  final String projectId;
  final String name;
  final int orderIndex;
  final String createdAt;

  const Section({
    required this.id,
    required this.projectId,
    required this.name,
    this.orderIndex = 0,
    required this.createdAt,
  });

  factory Section.fromMap(Map<String, dynamic> m) => Section(
    id: m['id'] as String,
    projectId: m['project_id'] as String,
    name: m['name'] as String,
    orderIndex: m['order_index'] as int? ?? 0,
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'name': name,
    'order_index': orderIndex,
    'created_at': createdAt,
  };
}

// ─── Comment ──────────────────────────────────────────────────────────────────

class Comment {
  final String id;
  final String taskId;
  final String body;
  final String createdAt;

  const Comment({
    required this.id,
    required this.taskId,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> m) => Comment(
    id: m['id'] as String,
    taskId: m['task_id'] as String,
    body: m['body'] as String,
    createdAt: m['created_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'body': body,
    'created_at': createdAt,
  };
}

// ─── AppSettings ──────────────────────────────────────────────────────────────

class AppSettings {
  final String themeMode; // 'light' | 'dark' | 'system'
  final int defaultReminderMinutes;
  final bool dailyDigestEnabled;
  final String dailyDigestTime;
  final String weekStartsOn; // 'sunday' | 'monday'
  final bool badgeCountEnabled;
  final bool hasCompletedOnboarding;
  final String? lastBackupAt;

  const AppSettings({
    this.themeMode = 'system',
    this.defaultReminderMinutes = 30,
    this.dailyDigestEnabled = true,
    this.dailyDigestTime = '09:00',
    this.weekStartsOn = 'sunday',
    this.badgeCountEnabled = true,
    this.hasCompletedOnboarding = false,
    this.lastBackupAt,
  });

  AppSettings copyWith({
    String? themeMode,
    int? defaultReminderMinutes,
    bool? dailyDigestEnabled,
    String? dailyDigestTime,
    String? weekStartsOn,
    bool? badgeCountEnabled,
    bool? hasCompletedOnboarding,
    Object? lastBackupAt = _sentinel,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
    dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
    dailyDigestTime: dailyDigestTime ?? this.dailyDigestTime,
    weekStartsOn: weekStartsOn ?? this.weekStartsOn,
    badgeCountEnabled: badgeCountEnabled ?? this.badgeCountEnabled,
    hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    lastBackupAt: lastBackupAt == _sentinel ? this.lastBackupAt : lastBackupAt as String?,
  );
}

// ─── NLP Parsed Task ─────────────────────────────────────────────────────────

class ParsedTask {
  final String cleanTitle;
  final String? dueDate;
  final String? dueTime;
  final String? projectName;
  final List<String> labelNames;
  final int priority;
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final int? reminderMinutes;

  const ParsedTask({
    required this.cleanTitle,
    this.dueDate,
    this.dueTime,
    this.projectName,
    this.labelNames = const [],
    this.priority = 4,
    this.isRecurring = false,
    this.recurrenceRule,
    this.reminderMinutes,
  });
}

// ─── Stats ────────────────────────────────────────────────────────────────────

class DayStats {
  final String date;
  final int completed;
  final int added;

  const DayStats({required this.date, required this.completed, required this.added});
}

class TaskStats {
  final int completedToday;
  final int completedThisWeek;
  final int completedThisMonth;
  final int streak;
  final int karma;
  final List<DayStats> lastSevenDays;

  const TaskStats({
    this.completedToday = 0,
    this.completedThisWeek = 0,
    this.completedThisMonth = 0,
    this.streak = 0,
    this.karma = 0,
    this.lastSevenDays = const [],
  });
}
