// Conditional import: real notifications on mobile, no-op stub on web.
export 'notifications.dart'
    if (dart.library.html) 'stubs/notifications_stub.dart';
