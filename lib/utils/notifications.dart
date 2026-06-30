import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/index.dart' as models;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation handled via global navigator key in main app
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTaskReminder(models.Task task) async {
    if (task.dueDate == null) return;
    if (task.reminderMinutes == null) return;

    await cancelTaskReminder(task.id);

    final parts = task.dueDate!.split('-');
    final timeParts = (task.dueTime ?? '09:00').split(':');
    final due = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
    final remind = due.subtract(Duration(minutes: task.reminderMinutes!));
    if (remind.isBefore(DateTime.now())) return;

    final id = _notificationIdFor(task.id);
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Reminders for upcoming tasks',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      'Task Due Soon',
      task.title,
      tz.TZDateTime.from(remind, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    final id = _notificationIdFor(taskId);
    await _plugin.cancel(id);
  }

  /// Derives a stable per-task notification ID. Android notification IDs
  /// are 32-bit ints, so we use the full positive range (instead of a
  /// narrow slice like `% 100000`) to keep collisions between different
  /// tasks' reminders very unlikely — a collision would otherwise silently
  /// cancel/overwrite one task's reminder with another's.
  int _notificationIdFor(String taskId) => taskId.hashCode & 0x7FFFFFFF;

  Future<void> scheduleDailyDigest(String time) async {
    await _plugin.cancel(999999);
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        'daily_digest',
        'Daily Digest',
        channelDescription: 'Daily task summary',
        importance: Importance.defaultImportance,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      999999,
      'Good morning! ☀️',
      'Check your tasks for today',
      tz.TZDateTime.from(target, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
