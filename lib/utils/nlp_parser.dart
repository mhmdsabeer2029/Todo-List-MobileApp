import '../models/index.dart';

/// Parses natural language task input like:
/// "Call Alex tomorrow at 3pm #work p1 @errands every week"
class NlpParser {
  static ParsedTask parse(String input) {
    String text = input.trim();
    String? dueDate;
    String? dueTime;
    String? projectName;
    List<String> labelNames = [];
    int priority = 4;
    bool isRecurring = false;
    RecurrenceRule? recurrenceRule;
    int? reminderMinutes;

    final now = DateTime.now();

    // ─── Priority ─────────────────────────────────────────────────────────
    final p1 = RegExp(r'\bp1\b|!!!', caseSensitive: false);
    final p2 = RegExp(r'\bp2\b|!!(?!!)', caseSensitive: false);
    final p3 = RegExp(r'\bp3\b|!(?!!)', caseSensitive: false);
    final p4 = RegExp(r'\bp4\b', caseSensitive: false);

    if (p1.hasMatch(text)) {
      priority = 1;
      text = text.replaceAll(p1, '').trim();
    } else if (p2.hasMatch(text)) {
      priority = 2;
      text = text.replaceAll(p2, '').trim();
    } else if (p3.hasMatch(text)) {
      priority = 3;
      text = text.replaceAll(p3, '').trim();
    } else if (p4.hasMatch(text)) {
      priority = 4;
      text = text.replaceAll(p4, '').trim();
    }

    // ─── Project Tag #name ────────────────────────────────────────────────
    final projectMatch = RegExp(r'#(\w+)').firstMatch(text);
    if (projectMatch != null) {
      projectName = projectMatch.group(1);
      text = text.replaceAll(projectMatch.group(0)!, '').trim();
    }

    // ─── Label Tags @name ─────────────────────────────────────────────────
    final labelMatches = RegExp(r'@(\w+)').allMatches(text).toList();
    for (final m in labelMatches) {
      labelNames.add(m.group(1)!);
      text = text.replaceAll(m.group(0)!, '').trim();
    }

    // ─── Recurrence ───────────────────────────────────────────────────────
    if (RegExp(r'\bevery\s+day\b|\bdaily\b', caseSensitive: false).hasMatch(text)) {
      isRecurring = true;
      recurrenceRule = const RecurrenceRule(frequency: 'daily', interval: 1, raw: 'DAILY;INTERVAL=1');
      text = text.replaceAll(RegExp(r'\bevery\s+day\b|\bdaily\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\bevery\s+week\b|\bweekly\b', caseSensitive: false).hasMatch(text)) {
      isRecurring = true;
      recurrenceRule = const RecurrenceRule(frequency: 'weekly', interval: 1, raw: 'WEEKLY;INTERVAL=1');
      text = text.replaceAll(RegExp(r'\bevery\s+week\b|\bweekly\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\bevery\s+month\b|\bmonthly\b', caseSensitive: false).hasMatch(text)) {
      isRecurring = true;
      recurrenceRule = const RecurrenceRule(frequency: 'monthly', interval: 1, raw: 'MONTHLY;INTERVAL=1');
      text = text.replaceAll(RegExp(r'\bevery\s+month\b|\bmonthly\b', caseSensitive: false), '').trim();
    } else {
      final everyNWeeks = RegExp(r'\bevery\s+(\d+)\s+weeks?\b', caseSensitive: false).firstMatch(text);
      final everyNDays = RegExp(r'\bevery\s+(\d+)\s+days?\b', caseSensitive: false).firstMatch(text);
      if (everyNWeeks != null) {
        final n = int.parse(everyNWeeks.group(1)!);
        isRecurring = true;
        recurrenceRule = RecurrenceRule(frequency: 'weekly', interval: n, raw: 'WEEKLY;INTERVAL=$n');
        text = text.replaceAll(everyNWeeks.group(0)!, '').trim();
      } else if (everyNDays != null) {
        final n = int.parse(everyNDays.group(1)!);
        isRecurring = true;
        recurrenceRule = RecurrenceRule(frequency: 'daily', interval: n, raw: 'DAILY;INTERVAL=$n');
        text = text.replaceAll(everyNDays.group(0)!, '').trim();
      }
    }

    // ─── Time ─────────────────────────────────────────────────────────────
    // "at 3pm", "at 14:30", "at 9am"
    final timeMatch = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b', caseSensitive: false)
        .firstMatch(text);
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final meridiem = timeMatch.group(3)?.toLowerCase();
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      dueTime = '${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')}';
      text = text.replaceAll(timeMatch.group(0)!, '').trim();
    }

    // "in 2 hours"
    final inHoursMatch = RegExp(r'\bin\s+(\d+)\s+hours?\b', caseSensitive: false).firstMatch(text);
    if (inHoursMatch != null && dueTime == null) {
      final h = int.parse(inHoursMatch.group(1)!);
      final target = now.add(Duration(hours: h));
      dueTime = '${target.hour.toString().padLeft(2,'0')}:${target.minute.toString().padLeft(2,'0')}';
      dueDate = _dateStr(target);
      text = text.replaceAll(inHoursMatch.group(0)!, '').trim();
    }

    // ─── Reminder ─────────────────────────────────────────────────────────
    // "remind me 30 minutes before", "remind 1 hour before", "reminder 15
    // minutes before". Without this, reminderMinutes was always left null
    // even though the field exists and the rest of the app (notifications,
    // task detail sheet) supports it.
    final reminderMatch = RegExp(
      r'\bremind(?:\s+me)?\s+(\d+)\s+(minutes?|mins?|hours?|hrs?)(?:\s+before)?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (reminderMatch != null) {
      final amount = int.parse(reminderMatch.group(1)!);
      final unit = reminderMatch.group(2)!.toLowerCase();
      reminderMinutes = unit.startsWith('h') ? amount * 60 : amount;
      text = text.replaceAll(reminderMatch.group(0)!, '').trim();
    }

    // ─── Date ─────────────────────────────────────────────────────────────
    if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(text) && dueDate == null) {
      dueDate = _dateStr(now);
      text = text.replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\btomorrow\b', caseSensitive: false).hasMatch(text) && dueDate == null) {
      dueDate = _dateStr(now.add(const Duration(days: 1)));
      text = text.replaceAll(RegExp(r'\btomorrow\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\bnext\s+week\b', caseSensitive: false).hasMatch(text) && dueDate == null) {
      dueDate = _dateStr(now.add(const Duration(days: 7)));
      text = text.replaceAll(RegExp(r'\bnext\s+week\b', caseSensitive: false), '').trim();
    } else {
      // "next Monday/Tuesday/..."
      final dayNames = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
      for (int i = 0; i < dayNames.length; i++) {
        final pattern = RegExp('\\bnext\\s+${dayNames[i]}\\b', caseSensitive: false);
        if (pattern.hasMatch(text) && dueDate == null) {
          int daysUntil = (i - now.weekday % 7 + 7) % 7;
          if (daysUntil == 0) daysUntil = 7;
          dueDate = _dateStr(now.add(Duration(days: daysUntil)));
          text = text.replaceAll(pattern, '').trim();
          break;
        }
      }
      // "on Monday" (next occurrence)
      for (int i = 0; i < dayNames.length; i++) {
        final pattern = RegExp('\\bon\\s+${dayNames[i]}\\b', caseSensitive: false);
        if (pattern.hasMatch(text) && dueDate == null) {
          int daysUntil = (i - now.weekday % 7 + 7) % 7;
          if (daysUntil == 0) daysUntil = 7;
          dueDate = _dateStr(now.add(Duration(days: daysUntil)));
          text = text.replaceAll(pattern, '').trim();
          break;
        }
      }
    }

    // Clean up double spaces
    final cleanTitle = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return ParsedTask(
      cleanTitle: cleanTitle,
      dueDate: dueDate,
      dueTime: dueTime,
      projectName: projectName,
      labelNames: labelNames,
      priority: priority,
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
      reminderMinutes: reminderMinutes,
    );
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
