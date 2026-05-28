// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// FakeCallService manages:
/// - countdown timer before a fake call triggers
/// - ringtone playback on STREAM_ALARM channel (bypasses silent mode)
/// - pre-recorded conversation audio when call is answered
/// - volume control via native MethodChannel
class FakeCallService {
  FakeCallService._();
  static final FakeCallService instance = FakeCallService._();

  // ── Native channel for Android AudioManager (STREAM_ALARM) ──────────────
  static const _channel = MethodChannel('com.rakshaapp.raksha/audio');

  // ── Audio players ────────────────────────────────────────────────────────
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  // ── State ────────────────────────────────────────────────────────────────
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isRinging = false;
  bool _isInCall = false;

  String _callerName = 'Police';

  // ── Callbacks ─────────────────────────────────────────────────────────────
  /// Called every second with the remaining countdown value.
  void Function(int)? onCountdownTick;

  /// Called when the fake call screen should appear (timer expired).
  void Function()? onCallStarted;

  /// Called when the call ends (declined or hang-up).
  void Function()? onCallEnded;

  // ── Public API ────────────────────────────────────────────────────────────

  String get callerName => _callerName;
  bool get isRinging => _isRinging;
  bool get isInCall => _isInCall;

  /// Configure and start the countdown.
  void scheduleFakeCall({
    required String callerName,
    required int delaySeconds,
  }) {
    _callerName = callerName;
    _remainingSeconds = delaySeconds;

    _countdownTimer?.cancel();

    if (delaySeconds == 0) {
      _startRinging();
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      onCountdownTick?.call(_remainingSeconds);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _startRinging();
      }
    });
  }

  /// Cancel a scheduled call before it triggers.
  void cancelScheduledCall() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remainingSeconds = 0;
  }

  /// Answer the call — stop ringtone, play voice audio.
  Future<void> answerCall() async {
    if (!_isRinging) return;
    _isRinging = false;
    _isInCall = true;

    await _ringtonePlayer.stop();
    await _restoreVolume();

    // Play pre-recorded conversation audio using STREAM_ALARM
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setAlarmStream');
    }
    await _voicePlayer.play(
      AssetSource('audios/fake_call_voice.mp3'),
    );
    _voicePlayer.onPlayerComplete.listen((_) => endCall());
  }

  /// Decline or hang up the call.
  Future<void> endCall() async {
    _isRinging = false;
    _isInCall = false;
    _countdownTimer?.cancel();

    await _ringtonePlayer.stop();
    await _voicePlayer.stop();
    await _restoreVolume();

    onCallEnded?.call();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _startRinging() async {
    _isRinging = true;

    // Force STREAM_ALARM volume to max (bypasses silent/DND)
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setAlarmStream');
      await _channel.invokeMethod('setMaxAlarmVolume');
    }

    await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    await _ringtonePlayer.play(
      AssetSource('audios/fake_call_ringtone.mp3'),
    );

    onCallStarted?.call();
  }

  Future<void> _restoreVolume() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('restoreVolume');
    }
  }

  void dispose() {
    _countdownTimer?.cancel();
    _ringtonePlayer.dispose();
    _voicePlayer.dispose();
  }
}
