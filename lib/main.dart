import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ble/ble_manager.dart';
import 'data/database.dart';
import 'data/session_repository.dart';
import 'logic/session_manager.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/live_session_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/session_detail_screen.dart';

// Proveedores globales
final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());
final repoProvider = Provider<SessionRepository>((ref) {
  final db = ref.watch(dbProvider);
  return SessionRepository(db);
});
final bleProvider = Provider<BleManager>((ref) => BleManager());
final sessionManagerProvider =
    StateNotifierProvider<SessionManager, SessionState>((ref) {
  final ble = ref.watch(bleProvider);
  final repo = ref.watch(repoProvider);
  return SessionManager(ble: ble, repo: repo);
});

void main() {
  runApp(const ProviderScope(child: SevidApp()));
}

class SevidApp extends StatelessWidget {
  const SevidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartKnee App 0.1',
      initialRoute: '/connect',
      routes: {
        '/connect': (_) => const ConnectScreen(),
        '/live': (_) => const LiveSessionScreen(),
        '/history': (_) => const HistoryScreen(),
        '/detail': (_) => const SessionDetailScreen(),
      },
    );
  }
}
