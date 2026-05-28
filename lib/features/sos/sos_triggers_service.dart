// lib/features/sos/sos_triggers_service.dart
//
// Background SOS Trigger Service
// Handles: Shake-to-SOS · Voice Trigger · Power Button (3×)
//
// Usage:
//   await SosTriggerService.instance.init(context);
//   SosTriggerService.instance.dispose(); // in app dispose

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'sos_service.dart';

// ── SOS Trigger Service ───────────────────────────────────────────────────────

/// Listens for alternative SOS triggers:
///  1. Shake-to-SOS — shake phone vigorously 3× in quick succession
///  2. Voice trigger — say "RAKSHA HELP" (or "Help" for testing)
///  3. Power button — 3 presses within 2 s (via platform channel)
class SosTriggerService {
  SosTriggerService._();
  static final SosTriggerService instance = SosTriggerService._();

  // ── Config ────────────────────────────────────────────────────────────────
  /// Acceleration magnitude threshold to count as a shake (m/s²)
  static const double _shakeThreshold = 18.0;
  /// Minimum ms between two shake events
  static const int _shakeCooldownMs = 400;
  /// Number of shakes required to trigger SOS
  static const int _shakesRequired = 3;
  /// Window in ms in which [_shakesRequired] shakes must occur
  static const int _shakeWindowMs = 2500;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  /// Called with trigger source name when SOS should fire.
  void Function(String triggerSource)? onSosTriggered;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _running = false;
  bool _sosInProgress = false;

  // Shake
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final List<int> _shakeTimes = [];
  int _lastShakeMs = 0;

  // Voice
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  Timer? _voiceRestartTimer;

  // Power button platform channel
  static const _channel = MethodChannel('com.rakshaapp.raksha/triggers');

  // ── Init & dispose ────────────────────────────────────────────────────────

  /// Call once after Firebase init, ideally in [main] or [_AppState.initState].
  Future<void> init() async {
    if (_running) return;
    _running = true;

    _initShakeDetection();
    await _initVoiceTrigger();
    _initPowerButtonListener();
  }

  void dispose() {
    _running = false;
    _accelSub?.cancel();
    _voiceRestartTimer?.cancel();
    _stt.cancel();
  }

  // ── Shake detection ───────────────────────────────────────────────────────

  void _initShakeDetection() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~50 Hz
    ).listen(_onAccelEvent, onError: (_) {});
  }

  void _onAccelEvent(AccelerometerEvent e) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastShakeMs < _shakeCooldownMs) return;

    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _shakeThreshold) return;

    _lastShakeMs = now;
    _shakeTimes.add(now);

    // Remove events older than the window
    _shakeTimes.removeWhere((t) => now - t > _shakeWindowMs);

    if (_shakeTimes.length >= _shakesRequired) {
      _shakeTimes.clear();
      _triggerSos('shake');
    }
  }

  // ── Voice trigger ─────────────────────────────────────────────────────────

  static const _triggerWords = [
    'raksha help',
    'raksha',
    'help me',
    'bachao',    // Hindi: save me
    'madad karo', // Hindi: help me
  ];

  Future<void> _initVoiceTrigger() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (_) => _scheduleVoiceRestart(),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _scheduleVoiceRestart();
          }
        },
      );
      if (_sttAvailable) _startVoiceListening();
    } catch (_) {}
  }

  void _startVoiceListening() {
    if (!_sttAvailable || !_running) return;
    try {
      _stt.listen(
        onResult: (result) {
          if (result.finalResult) {
            _checkVoiceTrigger(result.recognizedWords.toLowerCase());
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'hi_IN', // Hindi India — falls back to en-US if unavailable
        cancelOnError: false,
        partialResults: false,
      );
    } catch (_) {
      _scheduleVoiceRestart();
    }
  }

  void _checkVoiceTrigger(String spoken) {
    for (final trigger in _triggerWords) {
      if (spoken.contains(trigger)) {
        _triggerSos('voice');
        return;
      }
    }
    // Restart listening after result
    _scheduleVoiceRestart(delay: const Duration(milliseconds: 500));
  }

  void _scheduleVoiceRestart({Duration delay = const Duration(seconds: 2)}) {
    _voiceRestartTimer?.cancel();
    _voiceRestartTimer = Timer(delay, () {
      if (_running && _sttAvailable) _startVoiceListening();
    });
  }

  // ── Power button (Platform channel) ───────────────────────────────────────

  void _initPowerButtonListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'powerButtonTripleTap') {
        _triggerSos('powerButton');
      }
    });
  }

  // ── SOS fire ──────────────────────────────────────────────────────────────

  void _triggerSos(String source) {
    if (_sosInProgress) return;
    if (SosService.instance.isActive) return;
    _sosInProgress = true;

    // Haptic feedback burst
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 100),
      () => HapticFeedback.heavyImpact(),
    );
    Future.delayed(
      const Duration(milliseconds: 200),
      () => HapticFeedback.heavyImpact(),
    );

    onSosTriggered?.call(source);

    // Fire and forget — actual SOS triggered by caller
    Future.delayed(const Duration(seconds: 15), () {
      _sosInProgress = false;
    });
  }
}
