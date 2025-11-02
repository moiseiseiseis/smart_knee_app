import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

// ---------- Tabla de sesiones ----------
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();           // inicio de sesión
  IntColumn get duration => integer()();             // duración en segundos
  RealColumn get romMax => real()();                 // ROM máximo
  RealColumn get deviationMax =>
      real().withDefault(const Constant(0.0))();     // desviación máx
  TextColumn get notes => text().nullable()();       // opcional
}

// ---------- DB principal ----------
@DriftDatabase(tables: [Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertSession(SessionsCompanion entry) {
    return into(sessions).insert(entry);
  }

  Future<List<Session>> getAllSessions() {
    return (select(sessions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<Session?> getSessionById(int id) async {
    final query = select(sessions)..where((tbl) => tbl.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> deleteSession(int id) {
    return (delete(sessions)..where((tbl) => tbl.id.equals(id))).go();
  }
}

// ---------- conexión SQLite ----------
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'smart_knee.sqlite');
    return SqfliteQueryExecutor(
      path: dbPath,
      logStatements: true,
    );
  });
}
