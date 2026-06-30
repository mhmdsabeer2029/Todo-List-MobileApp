import 'package:intl/intl.dart';

/// Shared date helpers used throughout the app
class AppDateUtils {
  AppDateUtils._();

  static String toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String toIsoDateTime(DateTime d) => d.toIso8601String();

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool isToday(DateTime d) {
    final t = today();
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  static bool isTomorrow(DateTime d) {
    final t = today().add(const Duration(days: 1));
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  static bool isOverdue(DateTime d) => d.isBefore(today());

  /// Returns "Today", "Tomorrow", "Yesterday", "Mon 3 Jun", etc.
  static String friendlyDate(DateTime d) {
    if (isToday(d)) return 'Today';
    final tomorrow = today().add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'Tomorrow';
    }
    final yesterday = today().subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
      return 'Yesterday';
    }
    final diff = DateTime(d.year, d.month, d.day).difference(today()).inDays;
    if (diff.abs() < 7) return DateFormat('EEE d MMM').format(d);
    return DateFormat('d MMM y').format(d);
  }

  /// Short label for task chips: "Today", "Tue", "Jan 5"
  static String shortDate(DateTime d) {
    if (isToday(d)) return 'Today';
    if (isTomorrow(d)) return 'Tomorrow';
    final diff = DateTime(d.year, d.month, d.day).difference(today()).inDays;
    if (diff > 0 && diff < 7) return DateFormat('EEE').format(d);
    return DateFormat('MMM d').format(d);
  }

  /// Format a time string "HH:mm" to "9:30 AM"
  static String formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Parse "yyyy-MM-dd" safely, returns null on failure
  static DateTime? parseDate(String? s) {
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Number of days between today and the given date (-ve = past)
  static int daysUntil(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(today()).inDays;
}
