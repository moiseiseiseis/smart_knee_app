import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../../data/database.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Session> _sessions = [];

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final data = await repo.fetchSessions();
    setState(() {
      _sessions = data;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial de sesiones")),
      body: ListView.separated(
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final s = _sessions[i];
          return ListTile(
            title: Text(
              "${s.date}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Duración: ${s.duration ~/ 60} min  |  ROM máx: ${s.romMax.toStringAsFixed(1)}°",
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(sessionId: s.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
