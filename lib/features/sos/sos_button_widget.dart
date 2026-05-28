import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sos_service.dart';

export 'sos_service.dart';

/// Reusable Press-&-Hold SOS button with:
///  • Circular progress ring filling over [holdDuration]
///  • Haptic feedback ticks every ~0.5 s during hold
///  • Ring resets if released early
///  • Calls [onSosTriggered] when hold completes
///
/// Drop-in replacement for the existing SOS button area in home_widget.dart.
class SosButtonWidget extends StatefulWidget {
  const SosButtonWidget({
    super.key,
    this.holdDuration = const Duration(seconds: 3),
    required this.onSosTriggered,
  });

  final Duration holdDuration;
  final VoidCallback onSosTriggered;

  @override
  State<SosButtonWidget> createState() => _SosButtonWidgetState();
}

class _SosButtonWidgetState extends State<SosButtonWidget>
    with TickerProviderStateMixin {
  // ── Progress controller (0.0 → 1.0 over holdDuration) ────────────────────
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  // ── Outer ring pulse (idle animation) ─────────────────────────────────────
  late AnimationController _pulseCtrl1;
  late AnimationController _pulseCtrl2;
  late Animation<double> _pulse1;
  late Animation<double> _pulse2;

  // ── Haptic tick timer ─────────────────────────────────────────────────────
  Timer? _hapticTimer;

  // ── State flags ────────────────────────────────────────────────────────────
  bool _holding = false;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();

    // Progress ring animation
    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_triggered) {
          _triggered = true;
          _hapticTimer?.cancel();
          HapticFeedback.heavyImpact();
          widget.onSosTriggered();
        }
      });
    _progressAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    // Idle pulse rings
    _pulseCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulse1 = Tween<double>(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseCtrl1, curve: Curves.easeInOut));
    _pulse2 = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl2, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 1000),
        () { if (mounted) _pulseCtrl2.reverse(); });
    _pulseCtrl1.addStatusListener((s) {
      if (s == AnimationStatus.completed) _pulseCtrl1.reverse();
      if (s == AnimationStatus.dismissed) _pulseCtrl1.forward();
    });
    _pulseCtrl2.addStatusListener((s) {
      if (s == AnimationStatus.completed) _pulseCtrl2.reverse();
      if (s == AnimationStatus.dismissed) _pulseCtrl2.forward();
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl1.dispose();
    _pulseCtrl2.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onPressDown() {
    if (_triggered) return;
    setState(() => _holding = true);

    // Light initial vibration
    HapticFeedback.mediumImpact();

    _progressCtrl.forward(from: 0);

    // Haptic ticks every 500ms while holding
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_holding) HapticFeedback.lightImpact();
    });
  }

  void _onPressUp() {
    if (_triggered) return;
    _hapticTimer?.cancel();

    // Reset if not complete
    if (_progressCtrl.value < 1.0) {
      _progressCtrl.reverse(from: _progressCtrl.value);
      HapticFeedback.selectionClick();
    }

    setState(() => _holding = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onPressDown(),
      onTapUp: (_) => _onPressUp(),
      onTapCancel: () => _onPressUp(),
      onLongPressStart: (_) => _onPressDown(),
      onLongPressEnd: (_) => _onPressUp(),
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Outer idle pulse ring 1 ─────────────────────────────────────
            AnimatedBuilder(
              animation: _pulse1,
              builder: (_, __) => _holding
                  ? const SizedBox.shrink()
                  : Transform.scale(
                      scale: _pulse1.value,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
            ),

            // ── Outer idle pulse ring 2 ─────────────────────────────────────
            AnimatedBuilder(
              animation: _pulse2,
              builder: (_, __) => _holding
                  ? const SizedBox.shrink()
                  : Transform.scale(
                      scale: _pulse2.value,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                        ),
                      ),
                    ),
            ),

            // ── Progress ring (shown while holding) ─────────────────────────
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) {
                if (!_holding && _progressCtrl.value == 0) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  size: const Size(220, 220),
                  painter: _ProgressRingPainter(
                    progress: _progressAnim.value,
                    color: const Color(0xFFEF4444),
                    strokeWidth: 6,
                  ),
                );
              },
            ),

            // ── Core SOS circle ─────────────────────────────────────────────
            AnimatedScale(
              scale: _holding ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                    center: Alignment(-0.3, -0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(
                          alpha: _holding ? 0.65 : 0.45),
                      blurRadius: _holding ? 40 : 28,
                      spreadRadius: _holding ? 8 : 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: _holding ? 0.05 : 0,
                      duration: const Duration(milliseconds: 100),
                      child: const Icon(
                        Icons.back_hand_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SOS',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedOpacity(
                      opacity: _holding ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        'PRESS & HOLD',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _holding ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (_, __) {
                          final remaining = widget.holdDuration.inMilliseconds *
                              (1 - _progressAnim.value);
                          final secs = (remaining / 1000).ceil();
                          return Text(
                            secs > 0 ? '$secs...' : 'SOS!',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress ring painter ─────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });
  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track (dim)
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.6), color],
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi * progress,
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}
