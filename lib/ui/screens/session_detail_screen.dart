import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../../data/database.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final int? sessionId;
  const SessionDetailScreen({super.key, this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Session? _session;

  Future<void> _load() async {
    if (widget.sessionId == null) return;
    final repo = ref.read(repoProvider);
    final data = await repo.fetchSession(widget.sessionId!);
    setState(() {
      _session = data;
    });
  }

  Future<void> _delete() async {
    if (_session == null) return;
    final repo = ref.read(repoProvider);
    await repo.removeSession(_session!.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de sesión"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _delete,
          )
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Fecha: ${s.date}",
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Duración: ${s.duration} s"),
                  Text("ROM máx: ${s.romMax.toStringAsFixed(2)}°"),
                  Text("Desviación máx: ${s.deviationMax.toStringAsFixed(2)}°"),
                  const SizedBox(height: 12),
                  Text("Notas: ${s.notes ?? '-'}"),
                  const Spacer(),
                  // FUTURO: botón "Subir a nube"
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Subir a nube (futuro)"),
                  ),
                ],
              ),
            ),
    );
  }
}
