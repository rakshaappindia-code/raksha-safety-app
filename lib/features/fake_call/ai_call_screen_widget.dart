import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ai_call_service.dart';

export 'ai_call_service.dart' show AiCharacter;

/// Full-screen AI-powered call UI.
///
/// Flow:
///   1. Shows incoming call screen (pulsing rings, slide-to-answer)
///   2. On answer → AiCallService.startCall() → opening line plays
///   3. Mic activates → user speaks → Claude → ElevenLabs → audio plays
///   4. Loop until End Call is tapped
class AiCallScreenWidget extends StatefulWidget {
  const AiCallScreenWidget({super.key, required this.character});

  final AiCharacter character;

  static String routeName = 'AiCallScreen';
  static String routePath = '/ai-call-screen';

  @override
  State<AiCallScreenWidget> createState() => _AiCallScreenWidgetState();
}

class _AiCallScreenWidgetState extends State<AiCallScreenWidget>
    with TickerProviderStateMixin {
  final _svc = AiCallService.instance;

  // ── Screen phase ──────────────────────────────────────────────────────────
  bool _answered = false;
  bool _callEnded = false;

  // ── Call state mirror ─────────────────────────────────────────────────────
  AiCallState _callState = AiCallState.idle;
  String _partialTranscript = '';
  final List<_ChatBubble> _bubbles = [];

  // ── Slide-to-answer ───────────────────────────────────────────────────────
  double _slideValue = 0.0;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _ringCtrl1;
  late AnimationController _ringCtrl2;
  late AnimationController _micWaveCtrl;
  late AnimationController _slideIn;

  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<Offset> _slideAnim;

  // ── Call duration ─────────────────────────────────────────────────────────
  int _callSeconds = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();

    // Ring pulse animations
    _ringCtrl1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _ringCtrl2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _ring1 = Tween<double>(begin: 1.0, end: 2.3)
        .animate(CurvedAnimation(parent: _ringCtrl1, curve: Curves.easeOut));
    _ring2 = Tween<double>(begin: 1.0, end: 2.7)
        .animate(CurvedAnimation(parent: _ringCtrl2, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) _ringCtrl2.forward(); });

    // Mic wave animation (runs continuously, opacity depends on state)
    _micWaveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();

    // Slide-in entrance
    _slideIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideIn, curve: Curves.easeOut));

    // Wire up service callbacks
    _svc.onStateChanged = (s) {
      if (mounted) setState(() => _callState = s);
    };
    _svc.onPartialTranscript = (t) {
      if (mounted) setState(() => _partialTranscript = t);
    };
    _svc.onMessageAdded = (text, isUser) {
      if (mounted) {
        setState(() {
          _partialTranscript = '';
          _bubbles.add(_ChatBubble(text: text, isUser: isUser));
          // Keep last 8 bubbles
          if (_bubbles.length > 8) _bubbles.removeAt(0);
        });
      }
    };
    _svc.onCallEnded = () {
      if (mounted) {
        _callTimer?.cancel();
        setState(() => _callEnded = true);
        Future.delayed(
          const Duration(milliseconds: 600),
          () { if (mounted) Navigator.of(context).pop(); },
        );
      }
    };
    _svc.onError = (msg) {
      if (mounted) setState(() => _callState = AiCallState.error);
    };
  }

  @override
  void dispose() {
    _ringCtrl1.dispose();
    _ringCtrl2.dispose();
    _micWaveCtrl.dispose();
    _slideIn.dispose();
    _callTimer?.cancel();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _answer() async {
    if (_answered) return;
    setState(() => _answered = true);

    _ringCtrl1.stop();
    _ringCtrl2.stop();

    _callTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() => _callSeconds++); },
    );

    await _svc.startCall(widget.character);
  }

  Future<void> _endCall() async {
    await _svc.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (!_answered) _buildPulsingRings(),
          SlideTransition(
            position: _slideAnim,
            child: SafeArea(
              child: _answered ? _buildInCallLayout() : _buildIncomingLayout(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Incoming call layout ──────────────────────────────────────────────────

  Widget _buildIncomingLayout() {
    return Column(
      children: [
        const SizedBox(height: 48),
        _buildCallerInfo(showDuration: false),
        const Spacer(),
        _buildAiBadge(),
        const SizedBox(height: 24),
        _buildSlideToAnswer(),
        const SizedBox(height: 28),
        _buildDeclineButton(),
        const SizedBox(height: 12),
        Text('Decline',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── In-call layout ────────────────────────────────────────────────────────

  Widget _buildInCallLayout() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildCallerInfo(showDuration: true),
        const SizedBox(height: 16),
        _buildAiBadge(),
        const SizedBox(height: 12),

        // Transcript feed
        Expanded(child: _buildTranscriptFeed()),

        // State indicator (mic wave / processing / speaking)
        _buildStateIndicator(),
        const SizedBox(height: 28),

        // End call
        _buildDeclineButton(),
        const SizedBox(height: 10),
        Text(
          _callEnded ? 'Call ended' : 'End Call',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _answered
              ? [
                  const Color(0xFF0A1628),
                  const Color(0xFF0D1E40),
                  const Color(0xFF050F20),
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
          AnimatedBuilder(
            animation: _ring2,
            builder: (_, __) => Transform.scale(
              scale: _ring2.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withValues(
                    alpha: (1 - _ring2.value / 2.7).clamp(0, 0.5),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ring1,
            builder: (_, __) => Transform.scale(
              scale: _ring1.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF60A5FA).withValues(
                    alpha: (1 - _ring1.value / 2.3).clamp(0, 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerInfo({required bool showDuration}) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.character.avatarEmoji,
              style: const TextStyle(fontSize: 38),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.character.displayName,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: showDuration
              ? Text(
                  _callEnded ? 'Call ended' : _fmtDuration(_callSeconds),
                  key: const ValueKey('dur'),
                  style: GoogleFonts.inter(
                      color: Colors.white60, fontSize: 15),
                )
              : Text(
                  'Incoming AI call…',
                  key: const ValueKey('incoming'),
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            'AI Powered Conversation',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Transcript feed ───────────────────────────────────────────────────────

  Widget _buildTranscriptFeed() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      reverse: true,
      itemCount:
          _bubbles.length + (_partialTranscript.isNotEmpty ? 1 : 0),
      itemBuilder: (_, i) {
        // Partial transcript shown at top (index 0 in reversed list)
        if (_partialTranscript.isNotEmpty && i == 0) {
          return _buildBubble(_ChatBubble(
            text: _partialTranscript,
            isUser: true,
            isPartial: true,
          ));
        }
        final offset = _partialTranscript.isNotEmpty ? 1 : 0;
        return _buildBubble(_bubbles[_bubbles.length - 1 - (i - offset)]);
      },
    );
  }

  Widget _buildBubble(_ChatBubble bubble) {
    final isUser = bubble.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
              ),
              child: Center(
                child: Text(
                  bubble.isPartial ? '…' : '🤖',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          Flexible(
            child: AnimatedOpacity(
              opacity: bubble.isPartial ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF1D4ED8).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: bubble.isPartial
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1)
                      : null,
                ),
                child: Text(
                  bubble.text,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                    height: 1.45,
                    fontStyle: bubble.isPartial
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ── State indicator area ──────────────────────────────────────────────────

  Widget _buildStateIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: _stateIndicatorFor(_callState),
    );
  }

  Widget _stateIndicatorFor(AiCallState state) {
    switch (state) {
      case AiCallState.listening:
        return _MicWaveWidget(
          key: const ValueKey('mic'),
          controller: _micWaveCtrl,
        );
      case AiCallState.processing:
        return _ThinkingDotsWidget(
          key: const ValueKey('dots'),
          characterName: widget.character.displayName,
        );
      case AiCallState.speaking:
      case AiCallState.playingOpening:
        return _SpeakerWaveWidget(
          key: const ValueKey('speaker'),
          controller: _micWaveCtrl,
        );
      case AiCallState.error:
        return Padding(
          key: const ValueKey('err'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No internet — using offline mode',
            style: GoogleFonts.inter(color: Colors.amber, fontSize: 13),
          ),
        );
      default:
        return const SizedBox(key: ValueKey('empty'), height: 48);
    }
  }

  // ── Slide to answer ───────────────────────────────────────────────────────

  Widget _buildSlideToAnswer() {
    return Container(
      width: 280,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Slide to answer',
                style: GoogleFonts.inter(
                    color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
          Positioned(
            left: 4 + _slideValue * (280 - 72 - 8),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                final nv = (_slideValue +
                        d.delta.dx / (280 - 72 - 8))
                    .clamp(0.0, 1.0);
                setState(() => _slideValue = nv);
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF22C55E).withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFEF4444),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.call_end_rounded,
            color: Colors.white, size: 30),
      ),
    );
  }
}

// ── Chat bubble data ──────────────────────────────────────────────────────────

class _ChatBubble {
  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.isPartial = false,
  });
  final String text;
  final bool isUser;
  final bool isPartial;
}

// ── Mic wave animation ────────────────────────────────────────────────────────

class _MicWaveWidget extends StatelessWidget {
  const _MicWaveWidget({super.key, required this.controller});
  final AnimationController controller;

  static const _barCount = 5;
  static const _phases = [0.0, 0.4, 0.8, 0.2, 0.6];
  static const _minH = 8.0;
  static const _maxH = 36.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = controller.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_barCount, (i) {
                final v =
                    (sin((t + _phases[i]) * 2 * pi) * 0.5 + 0.5);
                final h = _minH + v * (_maxH - _minH);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E)
                            .withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Boliye… (Speaking)',
          style: GoogleFonts.inter(
            color: const Color(0xFF22C55E),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Speaker wave animation ────────────────────────────────────────────────────

class _SpeakerWaveWidget extends StatelessWidget {
  const _SpeakerWaveWidget({super.key, required this.controller});
  final AnimationController controller;

  static const _barCount = 7;
  static const _phases = [0.0, 0.3, 0.6, 0.9, 0.5, 0.2, 0.7];
  static const _minH = 6.0;
  static const _maxH = 28.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = controller.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                final v =
                    (sin((t + _phases[i]) * 2 * pi) * 0.5 + 0.5);
                final h = _minH + v * (_maxH - _minH);
                return Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'AI bol rahi hai…',
          style: GoogleFonts.inter(
            color: const Color(0xFF3B82F6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Thinking dots ─────────────────────────────────────────────────────────────

class _ThinkingDotsWidget extends StatefulWidget {
  const _ThinkingDotsWidget(
      {super.key, required this.characterName});
  final String characterName;

  @override
  State<_ThinkingDotsWidget> createState() => _ThinkingDotsWidgetState();
}

class _ThinkingDotsWidgetState extends State<_ThinkingDotsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 10,
              height: i < _dotCount ? 10 : 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1)
                    .withValues(alpha: i < _dotCount ? 1.0 : 0.3),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Soch rahi hai ${widget.characterName}…',
          style: GoogleFonts.inter(
            color: const Color(0xFF6366F1),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
