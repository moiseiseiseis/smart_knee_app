import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../../main.dart'; // bleProvider

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  List<DiscoveredDevice> _devices = [];
  bool _scanning = false;
  bool _connected = false;

  Future<void> _scan() async {
    final ble = ref.read(bleProvider);

    final ok = await ble.requestPermissions();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permisos BLE denegados")),
        );
      }
      return;
    }

    setState(() {
      _scanning = true;
    });

    final found = await ble.scanForSevidDevices();

    setState(() {
      _devices = found;
      _scanning = false;
    });
  }

  Future<void> _connect(DiscoveredDevice d) async {
    final ble = ref.read(bleProvider);
    try {
      await ble.connect(d);
      setState(() {
        _connected = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No es un dispositivo SEVID compatible.\n$e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ble.isConnected ? "Conectado" : "Conexión a rodillera"),
        actions: [
          // Acceso directo al historial desde cualquier estado
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            tooltip: "Sesión en vivo",
            onPressed: () => Navigator.pushNamed(context, '/live'),
          ),
        ],
      ),

      body: Column(
        children: [
          if (!ble.isConnected)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _scanning ? null : _scan,
                child: Text(_scanning ? "Buscando..." : "Buscar rodillera"),
              ),
            ),

          if (_devices.isEmpty && !_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No hay dispositivos SEVID-KNEE visibles."),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, i) {
                final d = _devices[i];
                return ListTile(
                  title: Text(
                    d.name.isEmpty ? "(sin nombre)" : d.name,
                  ),
                  subtitle: Text("id: ${d.id}\nRSSI: ${d.rssi} dBm"),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: ble.isConnected ? null : () => _connect(d),
                    child: const Text("Conectar"),
                  ),
                );
              },
            ),
          ),

          // Si ya "conectó", también dejamos el CTA grande, pero ya no dependemos de esto para navegar
          if (ble.isConnected || _connected)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Ir a Sesión en vivo"),
                onPressed: () => Navigator.pushNamed(context, '/live'),
              ),
            ),
        ],
      ),

      // Botón flotante abajo a la derecha para navegación manual
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Este menú rápido es solo UI; no bloquea nada.
          showModalBottomSheet(
            context: context,
            builder: (ctx) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.play_circle_fill),
                      title: const Text("Sesión en vivo"),
                      subtitle: const Text("Ver ángulo actual / ROM máx / cronómetro"),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/live');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text("Historial"),
                      subtitle: const Text("Sesiones guardadas en el dispositivo"),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/history');
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        icon: const Icon(Icons.menu),
        label: const Text("Menú"),
      ),
    );
  }
}
