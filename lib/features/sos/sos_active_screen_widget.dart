import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sos_service.dart';

export 'sos_service.dart';

/// Full-screen SOS Active screen.
///
/// Shown immediately after SOS triggers. Features:
///  • Pulsing red background with animated beacon
///  • SOS active duration timer
///  • Live address updates every 30s
///  • Scrollable list of alerted contacts
///  • "I'M SAFE" green button → marks SOS resolved
class SosActiveScreenWidget extends StatefulWidget {
  const SosActiveScreenWidget({super.key, required this.alertData});

  final SosAlertData alertData;

  static String routeName = 'SosActiveScreen';
  static String routePath = '/sos-active';

  @override
  State<SosActiveScreenWidget> createState() =>
      _SosActiveScreenWidgetState();
}

class _SosActiveScreenWidgetState extends State<SosActiveScreenWidget>
    with TickerProviderStateMixin {
  final _svc = SosService.instance;

  // ── Beacon / pulse animations ──────────────────────────────────────────────
  late AnimationController _beaconCtrl;
  late AnimationController _textFlashCtrl;
  late Animation<double> _beaconScale;
  late Animation<double> _beaconOpacity;
  late Animation<double> _textOpacity;

  // ── Timer ──────────────────────────────────────────────────────────────────
  int _elapsedSeconds = 0;
  Timer? _durationTimer;

  // ── Mutable state ──────────────────────────────────────────────────────────
  late String _currentAddress;
  late List<_ContactStatus> _contactStatuses;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();

    _currentAddress = widget.alertData.address;
    _contactStatuses = widget.alertData.contacts
        .map((c) => _ContactStatus(contact: c, alerted: c.alerted))
        .toList();

    // Beacon ring pulse
    _beaconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _beaconScale = Tween<double>(begin: 1.0, end: 2.8)
        .animate(CurvedAnimation(parent: _beaconCtrl, curve: Curves.easeOut));
    _beaconOpacity = Tween<double>(begin: 0.6, end: 0.0)
        .animate(CurvedAnimation(parent: _beaconCtrl, curve: Curves.easeOut));

    // "SOS ACTIVE" text flash
    _textFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _textOpacity = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _textFlashCtrl, curve: Curves.easeInOut));

    // Duration timer
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() => _elapsedSeconds++); },
    );

    // Wire location updates
    _svc.onLocationUpdated = (lat, lng, addr) {
      if (mounted) setState(() => _currentAddress = addr);
    };

    // Wire contact alerts
    _svc.onContactAlerted = (name, success) {
      if (mounted) {
        setState(() {
          for (int i = 0; i < _contactStatuses.length; i++) {
            if (_contactStatuses[i].contact.name == name) {
              _contactStatuses[i] = _ContactStatus(
                contact: _contactStatuses[i].contact,
                alerted: success,
              );
            }
          }
        });
      }
    };
  }

  @override
  void dispose() {
    _beaconCtrl.dispose();
    _textFlashCtrl.dispose();
    _durationTimer?.cancel();
    _svc.onLocationUpdated = null;
    _svc.onContactAlerted = null;
    super.dispose();
  }

  // ── I'M SAFE ───────────────────────────────────────────────────────────────

  Future<void> _markSafe() async {
    if (_resolving) return;
    setState(() => _resolving = true);

    await _svc.markSafe();

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildBody()),
                _buildImSafeButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D0000),
            Color(0xFF1A0000),
            Color(0xFF0D0000),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  _fmtDuration(_elapsedSeconds),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Emergency indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'EMERGENCY',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Main body ──────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildBeacon(),
          const SizedBox(height: 28),
          _buildSosActiveText(),
          const SizedBox(height: 6),
          _buildHelpText(),
          const SizedBox(height: 28),
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildContactsList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Beacon ─────────────────────────────────────────────────────────────────

  Widget _buildBeacon() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: _beaconCtrl,
            builder: (_, __) => Transform.scale(
              scale: _beaconScale.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(
                    alpha: _beaconOpacity.value,
                  ),
                ),
              ),
            ),
          ),
          // Core circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFDC2626)],
                center: Alignment(-0.3, -0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.back_hand_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }

  // ── Text ───────────────────────────────────────────────────────────────────

  Widget _buildSosActiveText() {
    return AnimatedBuilder(
      animation: _textOpacity,
      builder: (_, __) => Opacity(
        opacity: _textOpacity.value,
        child: Text(
          'SOS ACTIVE',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEF4444),
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Text(
      'Aapke emergency contacts ko alert bhej diya gaya hai',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 13.5,
        height: 1.5,
      ),
    );
  }

  // ── Location card ──────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              Text(
                'Current Location',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF22C55E),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentAddress,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 4),
              Text(
                '${widget.alertData.latitude.toStringAsFixed(5)}, '
                '${widget.alertData.longitude.toStringAsFixed(5)}',
                style: GoogleFonts.robotoMono(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_rounded,
                      color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Google Maps link shared with contacts',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contacts list ──────────────────────────────────────────────────────────

  Widget _buildContactsList() {
    if (_contactStatuses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Koi emergency contact nahi mila. '
                'Profile mein contact add karein.',
                style: GoogleFonts.inter(
                  color: Colors.amber.shade300,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.people_rounded, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                'Alert bheja gaya (${_contactStatuses.length} contacts)',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...List.generate(_contactStatuses.length, (i) {
          final cs = _contactStatuses[i];
          return _buildContactTile(cs);
        }),
      ],
    );
  }

  Widget _buildContactTile(_ContactStatus cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.alerted
              ? const Color(0xFF22C55E).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.alerted
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: Center(
              child: Text(
                cs.contact.name.isNotEmpty
                    ? cs.contact.name[0].toUpperCase()
                    : '?',
                style: GoogleFonts.plusJakartaSans(
                  color: cs.alerted
                      ? const Color(0xFF22C55E)
                      : Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cs.contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cs.contact.relation.isNotEmpty
                      ? '${cs.contact.relation} · ${cs.contact.phone}'
                      : cs.contact.phone,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.alerted
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cs.alerted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  color: cs.alerted ? const Color(0xFF22C55E) : Colors.amber,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  cs.alerted ? 'Alerted' : 'Sending…',
                  style: GoogleFonts.inter(
                    color: cs.alerted ? const Color(0xFF22C55E) : Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── I'M SAFE button ────────────────────────────────────────────────────────

  Widget _buildImSafeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _resolving ? null : _markSafe,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 64,
          decoration: BoxDecoration(
            gradient: _resolving
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _resolving ? Colors.white12 : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _resolving
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _resolving
                ? [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Resolving…',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]
                : [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'मैं सुरक्षित हूँ  (I\'M SAFE)',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// ── Helper model ──────────────────────────────────────────────────────────────

class _ContactStatus {
  const _ContactStatus({required this.contact, required this.alerted});
  final EmergencyContact contact;
  final bool alerted;
}
