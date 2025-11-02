import 'package:drift/drift.dart';
import 'database.dart';

class SessionRepository {
  final AppDatabase db;
  SessionRepository(this.db);

  Future<int> saveSessionSummary({
    required DateTime date,
    required int durationSeconds,
    required double romMaxDeg,
    required double deviationMaxDeg,
    String? notes,
  }) {
    return db.insertSession(
      SessionsCompanion.insert(
        date: date,
        duration: durationSeconds,
        romMax: romMaxDeg,
        deviationMax: Value(deviationMaxDeg),
        notes: Value(notes),
      ),
    );
  }

  Future<List<Session>> fetchSessions() async {
    return db.getAllSessions();
  }

  Future<Session?> fetchSession(int id) async {
    return db.getSessionById(id);
  }

  Future<void> removeSession(int id) async {
    await db.deleteSession(id);
  }
}
