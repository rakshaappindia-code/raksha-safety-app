import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fake_call_service.dart';

/// Full-screen incoming call UI that mimics a native Android call screen.
/// Handles answer / decline gestures and plays back the pre-recorded voice.
class FakeCallScreenWidget extends StatefulWidget {
  const FakeCallScreenWidget({super.key});

  static String routeName = 'FakeCallScreen';
  static String routePath = '/fake-call-screen';

  @override
  State<FakeCallScreenWidget> createState() => _FakeCallScreenWidgetState();
}

class _FakeCallScreenWidgetState extends State<FakeCallScreenWidget>
    with TickerProviderStateMixin {
  final _svc = FakeCallService.instance;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _ringPulse1;
  late AnimationController _ringPulse2;
  late AnimationController _slideController;
  late Animation<double> _pulse1;
  late Animation<double> _pulse2;
  late Animation<Offset> _slideAnim;

  // ── Slide-to-answer state ─────────────────────────────────────────────────
  double _slideValue = 0.0;
  bool _answered = false;
  bool _callEnded = false;
  int _callDuration = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();

    // Pulsing rings
    _ringPulse1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _ringPulse2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulse1 = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ringPulse1, curve: Curves.easeOut),
    );
    _pulse2 = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _ringPulse2, curve: Curves.easeOut),
    );

    // Slight initial slide-in
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Delay ring pulse 2 by half cycle
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _ringPulse2.forward();
    });

    // When the call ends (voice audio done), pop this screen
    _svc.onCallEnded = () {
      if (mounted) {
        _callTimer?.cancel();
        setState(() => _callEnded = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    };
  }

  @override
  void dispose() {
    _ringPulse1.dispose();
    _ringPulse2.dispose();
    _slideController.dispose();
    _callTimer?.cancel();
    super.dispose();
  }

  // ── Call controls ─────────────────────────────────────────────────────────

  Future<void> _answer() async {
    if (_answered) return;
    setState(() => _answered = true);
    _ringPulse1.stop();
    _ringPulse2.stop();
    await _svc.answerCall();
    _startCallTimer();
  }

  Future<void> _decline() async {
    await _svc.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          _buildBackground(),

          // Pulsing rings (only when ringing)
          if (!_answered) _buildPulsingRings(),

          // Main content
          SlideTransition(
            position: _slideAnim,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildCallerInfo(),
                  const Spacer(),
                  _answered ? _buildInCallControls() : _buildAnswerDecline(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _answered
              ? [
                  const Color(0xFF0A1628),
                  const Color(0xFF0D2137),
                  const Color(0xFF071520),
                ]
              : [
                  const Color(0xFF1A0A35),
                  const Color(0xFF2D1654),
                  const Color(0xFF0D0520),
                ],
        ),
      ),
    );
  }

  Widget _buildPulsingRings() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          AnimatedBuilder(
            animation: _ringPulse2,
            builder: (_, __) => Transform.scale(
              scale: _pulse2.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C3BAA)
                      .withValues(alpha: (1 - _pulse2.value / 2.6).clamp(0, 1)),
                ),
              ),
            ),
          ),
          // Inner ring
          AnimatedBuilder(
            animation: _ringPulse1,
            builder: (_, __) => Transform.scale(
              scale: _pulse1.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9D66E5)
                      .withValues(alpha: (1 - _pulse1.value / 2.2).clamp(0, 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF9D66E5), Color(0xFF6C3BAA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9D66E5).withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _svc.callerName.isNotEmpty
                  ? _svc.callerName[0].toUpperCase()
                  : 'P',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Name
        Text(
          _svc.callerName,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Status
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _answered
              ? Text(
                  _callEnded
                      ? 'Call ended'
                      : _formatDuration(_callDuration),
                  key: const ValueKey('duration'),
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : _buildRingingDots(),
        ),
      ],
    );
  }

  Widget _buildRingingDots() {
    return Row(
      key: const ValueKey('ringing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Incoming call',
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ── Answer / Decline (swipe to answer + decline button) ───────────────────

  Widget _buildAnswerDecline() {
    return Column(
      children: [
        // Slide to answer
        _buildSlideToAnswer(),
        const SizedBox(height: 28),

        // Decline button
        GestureDetector(
          onTap: _decline,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4757),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4757).withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Decline',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSlideToAnswer() {
    return Container(
      width: 280,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track label
          Text(
            'Slide to answer',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          // Draggable green circle
          Positioned(
            left: 4 + _slideValue * (280 - 72 - 8),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newVal = (_slideValue +
                        details.delta.dx / (280 - 72 - 8))
                    .clamp(0.0, 1.0);
                setState(() => _slideValue = newVal);
                if (_slideValue >= 0.95) _answer();
              },
              onHorizontalDragEnd: (_) {
                if (_slideValue < 0.95) {
                  setState(() => _slideValue = 0);
                }
              },
              child: Container(
                width: 64,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF27AE60),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── In-call controls ──────────────────────────────────────────────────────

  Widget _buildInCallControls() {
    return Column(
      children: [
        // Control grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _callControl(Icons.mic_off_rounded, 'Mute', false, () {}),
              _callControl(Icons.volume_up_rounded, 'Speaker', false, () {}),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // End call
        GestureDetector(
          onTap: _decline,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4757),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4757).withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'End Call',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _callControl(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black87 : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
