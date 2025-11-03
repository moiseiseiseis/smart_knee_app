import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleManager {
  FlutterReactiveBle? _ble;

  // UUIDs (ajústalos si cambiaste en firmware)
  static final Uuid serviceUuid = Uuid.parse("8b8a0001-3b8f-4b2d-9b4f-6a9d0f001001");
  static final Uuid notifyUuid  = Uuid.parse("8b8a0002-3b8f-4b2d-9b4f-6a9d0f001002");
  static final Uuid ctrlUuid    = Uuid.parse("8b8a0003-3b8f-4b2d-9b4f-6a9d0f001003");

  DiscoveredDevice? _device;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;

  QualifiedCharacteristic? _notifyChar;
  QualifiedCharacteristic? _ctrlChar;

  bool _connecting = false;

  late final StreamController<double> _angleDegController;

  BleManager() {
    _angleDegController = StreamController<double>.broadcast();
    _ble = kIsWeb ? null : FlutterReactiveBle();
  }

  // ======= Public getters =======
  Stream<double> get angleDegStream => _angleDegController.stream;
  /// Consideramos "conectado" cuando el servicio/char ya están listos:
  bool get isConnected => _ctrlChar != null;
  bool get canSendCtrl => _ctrlChar != null;

  // ======= Permisos Android 12+ =======
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    final scan = await Permission.bluetoothScan.request();
    final conn = await Permission.bluetoothConnect.request();
    final loc  = await Permission.locationWhenInUse.request();
    return scan.isGranted && conn.isGranted && loc.isGranted;
  }

  // ======= Scan =======
  Future<List<DiscoveredDevice>> scanForSevidDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (kIsWeb || _ble == null) return [];

    // Cancela escaneo previo si lo hay
    await _scanSub?.cancel();
    final found = <DiscoveredDevice>[];

    _scanSub = _ble!.scanForDevices(
      withServices: const [], // sin filtro para debug
      scanMode: ScanMode.lowLatency,
    ).listen((d) {
      if (!found.any((x) => x.id == d.id)) {
        found.add(d);
      }
    });

    await Future.delayed(timeout);
    await _scanSub?.cancel();
    _scanSub = null;
    return found;
  }

  // ======= Connect (idempotente) =======
  Future<void> connect(DiscoveredDevice device) async {
    if (kIsWeb || _ble == null) {
      _device = device;
      return;
    }

    // Si ya está listo para enviar al mismo id, no hagas nada
    if (_device?.id == device.id && _ctrlChar != null) return;
    if (_connecting) return;

    _connecting = true;

    // Limpia estado previo
    await _scanSub?.cancel();           _scanSub = null;
    await _notifySub?.cancel();         _notifySub = null;
    await _connSub?.cancel();           _connSub = null;
    _ctrlChar = null; _notifyChar = null;

    _device = device;

    // Usamos un Completer para esperar a "connected" SIN llamar connectToDevice dos veces
    final connected = Completer<void>();

    _connSub = _ble!
        .connectToDevice(
          id: device.id,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen((update) async {
      // print("BLE state: ${update.connectionState}"); // útil para depurar

      if (update.connectionState == DeviceConnectionState.connected) {
        // Inicializa características una sola vez
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

        // Suscríbete a notify si tu firmware lo emite (puedes quitar si no lo usas)
        await _notifySub?.cancel();
        _notifySub = _ble!.subscribeToCharacteristic(_notifyChar!).listen(
          _handleTelemetryPacket,
          onError: (_) {}, // evita romper por cortes intermitentes
        );

        if (!connected.isCompleted) connected.complete();
      }

      if (update.connectionState == DeviceConnectionState.disconnected) {
        // Limpieza total al desconectar
        await _notifySub?.cancel(); _notifySub = null;
        _ctrlChar = null; _notifyChar = null;
        if (!connected.isCompleted) {
          connected.completeError(Exception("Disconnected before ready"));
        }
      }
    }, onError: (e) {
      _ctrlChar = null; _notifyChar = null; _notifySub = null;
      if (!connected.isCompleted) connected.completeError(e);
    });

    try {
      await connected.future;
      // ignore: avoid_print
      print('✅ Conectado a ${device.id}');
    } finally {
      _connecting = false;
    }
  }

  // ======= Disconnect (limpieza real) =======
Future<void> disconnect() async {
  // Detén cualquier escaneo activo
  await _scanSub?.cancel();   _scanSub = null;

  // Cancela notificaciones y la conexión
  await _notifySub?.cancel(); _notifySub = null;
  await _connSub?.cancel();   _connSub = null;

  // Limpia características y referencia al device
  _ctrlChar  = null;
  _notifyChar = null;
  _device = null;
}


  // ======= Envío de comandos (con reintento suave) =======
  Future<void> sendCommand(int cmdByte) async {
    if (kIsWeb || _ble == null) return;
    if (_ctrlChar == null) {
      throw Exception("BLE no listo aún (servicios no inicializados).");
    }

    try {
      await _ble!.writeCharacteristicWithResponse(_ctrlChar!, value: [cmdByte]);
    } on Object catch (e) {
      final msg = e.toString();
      // Si el SO cree que está conectado pero falló el discovery (estado “zombie”),
      // re-inicializa las características y reintenta una vez.
      if (_device != null &&
          (msg.contains('service_discovery_failed') || msg.contains('Already connected'))) {
        _ctrlChar = QualifiedCharacteristic(
          deviceId: _device!.id,
          serviceId: serviceUuid,
          characteristicId: ctrlUuid,
        );
        await _ble!.writeCharacteristicWithResponse(_ctrlChar!, value: [cmdByte]);
      } else {
        rethrow;
      }
    }
  }

  // ======= Telemetría entrante =======
  void _handleTelemetryPacket(List<int> rawData) {
    final bytes = Uint8List.fromList(rawData);
    if (bytes.length < 2) return;
    final bd = ByteData.sublistView(bytes);
    final rawAngleCentiDeg = bd.getInt16(0, Endian.little); // ej 4532 = 45.32°
    final angleDeg = rawAngleCentiDeg / 100.0;
    _angleDegController.add(angleDeg);
  }

  // ======= Atajos de sesión/LED =======
  Future<void> startSession() => sendCommand(0x01);
  Future<void> pauseSession() => sendCommand(0x02);
  Future<void> stopSession()  => sendCommand(0x03);

  // Test LED (ASCII '1' / '0' según firmware de ejemplo)
  Future<void> ledOn()  => sendCommand(0x31);  //comentar para desactivar
  Future<void> ledOff() => sendCommand(0x30);  //comentar para desactivar

  // ======= Ciclo de vida =======
  Future<void> dispose() async {
    await _angleDegController.close();
    await disconnect();
  }
}
