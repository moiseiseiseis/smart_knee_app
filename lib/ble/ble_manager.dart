import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleManager {
  FlutterReactiveBle? _ble; // ahora nullable

  static final Uuid serviceUuid = Uuid.parse("8b8a0001-3b8f-4b2d-9b4f-6a9d0f001001");
  static final Uuid notifyUuid  = Uuid.parse("8b8a0002-3b8f-4b2d-9b4f-6a9d0f001002");
  static final Uuid ctrlUuid    = Uuid.parse("8b8a0003-3b8f-4b2d-9b4f-6a9d0f001003");

  DiscoveredDevice? _device;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  QualifiedCharacteristic? _notifyChar;
  QualifiedCharacteristic? _ctrlChar;

  late final StreamController<double> _angleDegController;

  BleManager() {
    _angleDegController = StreamController<double>.broadcast();

    // Solo creamos FlutterReactiveBle en plataformas soportadas
    if (!kIsWeb) {
      _ble = FlutterReactiveBle();
    } else {
      _ble = null;
    }
  }

  Stream<double> get angleDegStream => _angleDegController.stream;

  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      // En web no pedimos permisos BLE nativos
      return true;
    }

    final scan = await Permission.bluetoothScan.request();
    final conn = await Permission.bluetoothConnect.request();
    final loc = await Permission.locationWhenInUse.request();
    return scan.isGranted && conn.isGranted && loc.isGranted;
  }

  Future<List<DiscoveredDevice>> scanForSevidDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    // Si estamos en web: devolver lista vacía simulada
    if (kIsWeb || _ble == null) {
      return [];
    }

    final found = <DiscoveredDevice>[];

    _scanSub = _ble!.scanForDevices(
      withServices: const [], // modo debug
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final already = found.any((d) => d.id == device.id);
      if (!already) {
        found.add(device);
      }
    });

    await Future.delayed(timeout);
    await _scanSub?.cancel();
    return found;
  }

  Future<void> connect(DiscoveredDevice device) async {
    if (kIsWeb || _ble == null) {
      // En web simplemente marcamos "conectado" lógico, no real
      _device = device;
      return;
    }

    _device = device;

    await _ble!
        .connectToDevice(id: device.id)
        .firstWhere((update) => update.connectionState == DeviceConnectionState.connected);

    _notifyChar = QualifiedCharacteristic(
      deviceId: device.id,
      serviceId: serviceUuid,
      characteristicId: notifyUuid,
    );

    _ctrlChar = QualifiedCharacteristic(
      deviceId: device.id,
      serviceId: serviceUuid,
      characteristicId: ctrlUuid,
    );

    _notifySub = _ble!.subscribeToCharacteristic(_notifyChar!).listen((data) {
      _handleTelemetryPacket(data);
    });
  }

  bool get isConnected => _device != null;

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _device = null;
  }

  Future<void> sendCommand(int cmdByte) async {
    if (kIsWeb || _ble == null) {
      // en web/no-BLE no mandamos nada
      return;
    }
    if (_ctrlChar == null) return;
    await _ble!.writeCharacteristicWithResponse(
      _ctrlChar!,
      value: [cmdByte],
    );
  }

  void _handleTelemetryPacket(List<int> rawData) {
    // Igual que antes:
    final bytes = Uint8List.fromList(rawData);
    if (bytes.length < 2) return;

    final bd = ByteData.sublistView(bytes);
    final rawAngleCentiDeg = bd.getInt16(0, Endian.little); // ej 4532 = 45.32°
    final angleDeg = rawAngleCentiDeg / 100.0;

    _angleDegController.add(angleDeg);
  }

  Future<void> startSession() => sendCommand(0x01);
  Future<void> pauseSession() => sendCommand(0x02);
  Future<void> stopSession() => sendCommand(0x03);
}
