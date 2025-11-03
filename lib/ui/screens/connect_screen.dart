import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'package:smart_knee/main.dart'; // bleProvider
import 'package:smart_knee/ble/ble_manager.dart';

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

    setState(() => _scanning = true);
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
      setState(() => _connected = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conectado a ${d.name.isEmpty ? d.id : d.name}')),
        );
      }
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
                  title: Text(d.name.isEmpty ? "(sin nombre)" : d.name),
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

          // CTA para ir a la sesión en vivo si ya hay conexión
          if (ble.isConnected || _connected)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Ir a Sesión en vivo"),
                onPressed: () => Navigator.pushNamed(context, '/live'),
              ),
            ),

          // =======================
          // 🔧 BLOQUE DE TEST DEL LED
          // Se muestra SOLO cuando hay conexión BLE. Comentar si no se usa.
          if (ble.isConnected)
            const SizedBox(height: 8),
          if (ble.isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LedTestPanel(ble: ble),
            ),
          // =======================
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
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

/// Panel de pruebas para encender/apagar LED vía característica de control.
/// Requiere que BleManager tenga los métodos: ledOn() y ledOff(). Comentar toda la clase si no se usa.
class LedTestPanel extends StatelessWidget {
  final BleManager ble;
  const LedTestPanel({super.key, required this.ble});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: ble.isConnected ? () async {
            try {
              await ble.ledOn();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('LED encendido')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          } : null,
          child: const Text('Encender LED'),
        ),
        OutlinedButton(
          onPressed: ble.isConnected ? () async {
            try {
              await ble.ledOff();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('LED apagado')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          } : null,
          child: const Text('Apagar LED'),
        ),
      ],
    );
  }
}

