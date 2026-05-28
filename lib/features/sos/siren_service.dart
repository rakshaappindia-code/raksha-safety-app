// lib/features/sos/siren_service.dart
//
// Siren / Personal Alert Tone Service
//
// Plays a loud alarm sound that bypasses silent mode via STREAM_ALARM,
// using the audioplayers package. Includes a looping mode and a UI widget
// to use from the Home screen action grid.

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Siren Service ─────────────────────────────────────────────────────────────

class SirenService {
  SirenService._();
  static final SirenService instance = SirenService._();

  static const _audioChannel = MethodChannel('com.rakshaapp.raksha/audio');

  final _player = AudioPlayer();
  bool _playing = false;
  int _volume = 100; // 0–100

  bool get isPlaying => _playing;
  int get volume => _volume;

  // Callbacks
  void Function(bool playing)? onStateChanged;

  /// Plays the alarm sound in a loop, bypassing silent mode.
  Future<void> start({int volume = 100}) async {
    if (_playing) return;
    _volume = volume;

    try {
      // Set STREAM_ALARM via platform channel to bypass silent mode
      await _audioChannel.invokeMethod('setStreamAlarm');
    } catch (_) {}

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume / 100.0);

    // Use a bundled siren asset.
    // ⚠️ ACTION REQUIRED: Add a siren.mp3 file to assets/audios/ directory.
    //    Free siren sounds: https://pixabay.com/sound-effects/search/siren/
    try {
      await _player.play(AssetSource('audios/siren.mp3'));
    } catch (_) {
      // Audio file missing — vibration-only mode works as fallback
    }

    _playing = true;
    onStateChanged?.call(true);

    // Vibration bursts while playing
    _startVibration();
  }

  /// Stops the siren.
  Future<void> stop() async {
    if (!_playing) return;
    await _player.stop();
    _playing = false;
    onStateChanged?.call(false);
    _vibrationTimer?.cancel();

    try {
      await _audioChannel.invokeMethod('setStreamMedia');
    } catch (_) {}
  }

  void setVolume(int vol) {
    _volume = vol.clamp(0, 100);
    _player.setVolume(_volume / 100.0);
  }

  // ── Vibration while siren plays ────────────────────────────────────────────

  Timer? _vibrationTimer;

  void _startVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_playing) {
        HapticFeedback.heavyImpact();
      } else {
        _vibrationTimer?.cancel();
      }
    });
  }

  void dispose() {
    _player.dispose();
    _vibrationTimer?.cancel();
  }
}

// ── Siren Button Widget ───────────────────────────────────────────────────────

/// Animated siren button for the Home screen.
/// Tapping once starts the siren; tapping again stops it.
class SirenButtonWidget extends StatefulWidget {
  const SirenButtonWidget({super.key});

  @override
  State<SirenButtonWidget> createState() => _SirenButtonWidgetState();
}

class _SirenButtonWidgetState extends State<SirenButtonWidget>
    with SingleTickerProviderStateMixin {
  final _svc = SirenService.instance;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _svc.onStateChanged = (playing) {
      if (!mounted) return;
      setState(() {});
      if (playing) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    };
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _svc.onStateChanged = null;
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_svc.isPlaying) {
      await _svc.stop();
    } else {
      await _svc.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _svc.isPlaying;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) {
          final pulse = 1.0 + (playing ? _pulseCtrl.value * 0.06 : 0);
          return Transform.scale(scale: pulse, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: playing
                ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: playing
                  ? const Color(0xFFFF6B6B)
                  : Theme.of(context).colorScheme.outline,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: playing
                    ? const Color(0xFFFF6B6B)
                    : Theme.of(context).colorScheme.onSurface,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                playing ? 'STOP' : 'Siren',
                style: GoogleFonts.plusJakartaSans(
                  color: playing
                      ? const Color(0xFFFF6B6B)
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full Siren Screen ─────────────────────────────────────────────────────────

/// Full-screen siren control panel with volume slider.
class SirenScreenWidget extends StatefulWidget {
  const SirenScreenWidget({super.key});

  static String routeName = 'SirenScreen';
  static String routePath = '/siren';

  @override
  State<SirenScreenWidget> createState() => _SirenScreenWidgetState();
}

class _SirenScreenWidgetState extends State<SirenScreenWidget>
    with SingleTickerProviderStateMixin {
  final _svc = SirenService.instance;
  late AnimationController _beaconCtrl;
  double _volume = 100;

  @override
  void initState() {
    super.initState();
    _beaconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _svc.onStateChanged = (playing) {
      if (!mounted) return;
      setState(() {});
      if (playing) {
        _beaconCtrl.repeat(reverse: true);
      } else {
        _beaconCtrl.stop();
        _beaconCtrl.reset();
      }
    };
  }

  @override
  void dispose() {
    _beaconCtrl.dispose();
    _svc.onStateChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _svc.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () async {
            if (playing) await _svc.stop();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        title: Text(
          'Personal Siren',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const Spacer(),
          // ── Beacon animation ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _beaconCtrl,
            builder: (_, __) {
              final scale = playing ? 1.0 + _beaconCtrl.value * 0.15 : 1.0;
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: playing ? _svc.stop : () => _svc.start(volume: _volume.round()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: playing
                            ? [const Color(0xFFFF6B6B), const Color(0xFFEF4444)]
                            : [const Color(0xFF374151), const Color(0xFF1F2937)],
                        center: const Alignment(-0.3, -0.3),
                      ),
                      boxShadow: playing
                          ? [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          playing ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playing ? 'TAP TO STOP' : 'TAP TO START',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            playing ? '🚨 Siren Chal Raha Hai' : 'Siren Shuru Karein',
            style: GoogleFonts.plusJakartaSans(
              color: playing ? const Color(0xFFEF4444) : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aawaz door tak sunai degi — khatra bhagao',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 40),
          // ── Volume slider ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_mute_rounded,
                        color: Colors.white38, size: 20),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFEF4444),
                          thumbColor: const Color(0xFFEF4444),
                          inactiveTrackColor: Colors.white12,
                          overlayColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: _volume,
                          min: 10,
                          max: 100,
                          divisions: 9,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            if (playing) _svc.setVolume(v.round());
                          },
                        ),
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded,
                        color: Colors.white54, size: 20),
                  ],
                ),
                Center(
                  child: Text(
                    'Volume: ${_volume.round()}%',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ── Disclaimer ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: Text(
              '⚠️ Sirf asli khatra hone par use karein.\n'
              'Galat use karna dusron ko pareshan kar sakta hai.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
