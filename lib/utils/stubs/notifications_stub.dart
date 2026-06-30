/// Web stub for NotificationService.
/// flutter_local_notifications does not support web. All methods are no-ops.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {}
  Future<void> requestPermissions() async {}
  Future<void> scheduleTaskReminder(dynamic task) async {}
  Future<void> cancelTaskReminder(String taskId) async {}
  Future<void> scheduleDailyDigest(String time) async {}
  Future<void> cancelAll() async {}
}
