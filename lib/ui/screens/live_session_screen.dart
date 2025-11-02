import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../../logic/session_manager.dart';

class LiveSessionScreen extends ConsumerWidget {
  const LiveSessionScreen({super.key});

  String _statusLabel(LiveStatus s) {
    switch (s) {
      case LiveStatus.running:
        return "RUNNING";
      case LiveStatus.paused:
        return "PAUSED";
      case LiveStatus.stopped:
      default:
        return "STOPPED";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(sessionManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sesión en vivo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, "/history"),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Estado: ${_statusLabel(st.status)}",
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text("Ángulo actual: ${st.currentAngleDeg.toStringAsFixed(2)}°",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("ROM máx: ${st.romMaxDeg.toStringAsFixed(2)}°",
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text("Duración: ${st.elapsedSeconds}s",
                style: const TextStyle(fontSize: 16)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                    onPressed: () => ref.read(sessionManagerProvider.notifier).start(),
                    child: const Text("START")),
                ElevatedButton(
                    onPressed: () => ref.read(sessionManagerProvider.notifier).pause(),
                    child: const Text("PAUSE")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400),
                    onPressed: () async {
                      await ref.read(sessionManagerProvider.notifier).stop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sesión guardada.")),
                        );
                      }
                    },
                    child: const Text("STOP")),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
