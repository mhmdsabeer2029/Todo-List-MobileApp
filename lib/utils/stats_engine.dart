import '../db/app_database.dart';
import '../models/index.dart';

/// Centralised stats / karma engine
class StatsEngine {
  static final StatsEngine _instance = StatsEngine._internal();
  factory StatsEngine() => _instance;
  StatsEngine._internal();

  final AppDatabase _db = AppDatabase();

  Future<TaskStats> compute() => _db.getStats();

  /// Returns a human-readable karma level label
  static String karmaLevel(int karma) {
    if (karma >= 500) return 'Grand Master 🏆';
    if (karma >= 200) return 'Expert ⭐';
    if (karma >= 100) return 'Intermediate 🌟';
    if (karma >= 30)  return 'Beginner 🌱';
    return 'Novice 🐣';
  }
}
