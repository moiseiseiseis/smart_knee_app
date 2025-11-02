import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_manager.dart';
import '../data/session_repository.dart';

enum LiveStatus { stopped, running, paused }

class SessionState {
  final LiveStatus status;
  final double currentAngleDeg;
  final double romMaxDeg;
  final DateTime? startTime;
  final int elapsedSeconds;

  SessionState({
    required this.status,
    required this.currentAngleDeg,
    required this.romMaxDeg,
    required this.startTime,
    required this.elapsedSeconds,
  });

  SessionState copyWith({
    LiveStatus? status,
    double? currentAngleDeg,
    double? romMaxDeg,
    DateTime? startTime,
    int? elapsedSeconds,
  }) {
    return SessionState(
      status: status ?? this.status,
      currentAngleDeg: currentAngleDeg ?? this.currentAngleDeg,
      romMaxDeg: romMaxDeg ?? this.romMaxDeg,
      startTime: startTime ?? this.startTime,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  factory SessionState.initial() => SessionState(
        status: LiveStatus.stopped,
        currentAngleDeg: 0,
        romMaxDeg: 0,
        startTime: null,
        elapsedSeconds: 0,
      );
}

class SessionManager extends StateNotifier<SessionState> {
  final BleManager ble;
  final SessionRepository repo;

  Timer? _timer;
  StreamSubscription<double>? _angleSub;

  SessionManager({required this.ble, required this.repo})
      : super(SessionState.initial()) {
    // escuchar ángulo BLE
    _angleSub = ble.angleDegStream.listen(_onAngle);
  }

  // callback cada nueva muestra de ángulo
  void _onAngle(double angleDeg) {
    // actualizar ángulo actual y ROM max
    final newRomMax = angleDeg.abs() > state.romMaxDeg ? angleDeg.abs() : state.romMaxDeg;
    state = state.copyWith(
      currentAngleDeg: angleDeg,
      romMaxDeg: newRomMax,
    );
  }

  Future<void> start() async {
    final now = DateTime.now();
    state = SessionState(
      status: LiveStatus.running,
      currentAngleDeg: 0,
      romMaxDeg: 0,
      startTime: now,
      elapsedSeconds: 0,
    );

    // cronómetro local
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final secs = DateTime.now().difference(now).inSeconds;
      state = state.copyWith(elapsedSeconds: secs);
    });

    await ble.startSession(); // manda 0x01
  }

  Future<void> pause() async {
    state = state.copyWith(status: LiveStatus.paused);
    await ble.pauseSession(); // manda 0x02
    // no paramos el timer para que tengamos duración total real de la sesión; si prefieres congelar, aquí puedes _timer?.cancel()
  }

  Future<void> stop() async {
    await ble.stopSession(); // manda 0x03
    _timer?.cancel();

    final durationSecs = state.elapsedSeconds;
    final romMax = state.romMaxDeg;
    final deviationDummy = 0.0; // TODO: cuando calculemos varo/valgo

    // guardar resumen en SQLite
    await repo.saveSessionSummary(
      date: state.startTime ?? DateTime.now(),
      durationSeconds: durationSecs,
      romMaxDeg: romMax,
      deviationMaxDeg: deviationDummy,
      notes: null,
    );

    // reset estado
    state = SessionState.initial();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _angleSub?.cancel();
    super.dispose();
  }
}
