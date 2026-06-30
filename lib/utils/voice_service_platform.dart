// Conditional import: real voice on mobile, no-op stub on web.
export 'voice_service.dart'
    if (dart.library.html) 'stubs/voice_stub.dart';
