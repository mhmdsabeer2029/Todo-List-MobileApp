// Conditional import: automatically picks the right DB backend.
// On web (dart:html available): uses shared_preferences JSON storage.
// On mobile/desktop (dart:io available): uses sqflite.
export 'database_io.dart'
    if (dart.library.html) 'database_web.dart';
