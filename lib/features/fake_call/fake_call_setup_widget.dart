import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'fake_call_setup_model.dart';
import 'fake_call_service.dart';
import 'fake_call_screen_widget.dart';
import 'ai_call_screen_widget.dart';

export 'fake_call_setup_model.dart';

class FakeCallSetupWidget extends StatefulWidget {
  const FakeCallSetupWidget({super.key});

  static String routeName = 'FakeCallSetup';
  static String routePath = '/fake-call-setup';

  @override
  State<FakeCallSetupWidget> createState() => _FakeCallSetupWidgetState();
}

class _FakeCallSetupWidgetState extends State<FakeCallSetupWidget>
    with TickerProviderStateMixin {
  late FakeCallSetupModel _model;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FakeCallSetupModel());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Register callbacks
    FakeCallService.instance.onCountdownTick = (remaining) {
      if (mounted) {
        safeSetState(() => _model.countdownRemaining = remaining);
      }
    };

    FakeCallService.instance.onCallStarted = () {
      if (mounted) {
        safeSetState(() => _model.isCountingDown = false);
        if (_model.aiModeEnabled) {
          // ── AI mode: navigate to AI call screen ────────────────────────
          final char = _mapToAiCharacter(_model.selectedCallerName);
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  AiCallScreenWidget(character: char),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        } else {
          // ── Normal mode: navigate to pre-recorded fake call ────────────
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const FakeCallScreenWidget(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      }
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _model.dispose();
    super.dispose();
  }

  void _startFakeCall() {
    safeSetState(() {
      _model.isCountingDown = true;
      _model.countdownRemaining = _model.selectedTimerSeconds;
    });
    FakeCallService.instance.scheduleFakeCall(
      callerName: _model.selectedCallerName,
      delaySeconds: _model.selectedTimerSeconds,
    );
  }

  void _cancelFakeCall() {
    FakeCallService.instance.cancelScheduledCall();
    safeSetState(() => _model.isCountingDown = false);
  }

  /// Maps the selected caller name to an AiCharacter enum value.
  AiCharacter _mapToAiCharacter(String name) {
    switch (name.toLowerCase()) {
      case 'mummy': return AiCharacter.mummy;
      case 'papa':  return AiCharacter.papa;
      case 'police': return AiCharacter.police;
      default:       return AiCharacter.bhai; // Bhai / Friend
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: theme.primaryText, size: 20),
            onPressed: () {
              _cancelFakeCall();
              context.pop();
            },
          ),
          title: Text(
            'Fake Call',
            style: theme.titleMedium.override(
              font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              color: theme.primaryText,
              letterSpacing: 0,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Phone icon hero ──────────────────────────────────────
                _buildPhoneHero(theme),
                const SizedBox(height: 32),

                // ── Caller Name Selection ────────────────────────────────
                _buildSectionLabel(theme, 'Who is calling you?'),
                const SizedBox(height: 12),
                _buildCallerNameGrid(theme),
                const SizedBox(height: 24),

                // ── Custom name input ────────────────────────────────────
                _buildCustomNameInput(theme),
                const SizedBox(height: 28),

                // ── AI Mode Toggle ───────────────────────────────────────
                _buildAiModeToggle(theme),
                const SizedBox(height: 28),

                // ── Timer Selection ──────────────────────────────────────
                _buildSectionLabel(theme, 'Call arrives in...'),
                const SizedBox(height: 12),
                _buildTimerChips(theme),
                const SizedBox(height: 36),

                // ── CTA Button ───────────────────────────────────────────
                _buildCTAButton(theme),
                const SizedBox(height: 16),

                // ── Info note ────────────────────────────────────────────
                _buildInfoNote(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Section builders
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildPhoneHero(FlutterFlowTheme theme) {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                theme.secondary.withValues(alpha: 0.3),
                theme.primary.withValues(alpha: 0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.phone_callback_rounded,
            size: 52,
            color: theme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(FlutterFlowTheme theme, String label) {
    return Text(
      label,
      style: theme.titleSmall.override(
        font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        color: theme.primaryText,
        letterSpacing: 0,
      ),
    );
  }

  Widget _buildCallerNameGrid(FlutterFlowTheme theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: FakeCallSetupModel.presetCallers.map((name) {
        final isSelected = _model.selectedCallerName == name;
        return GestureDetector(
          onTap: () => safeSetState(() => _model.selectedCallerName = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primary : theme.secondaryBackground,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected ? theme.primary : theme.alternate,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForCaller(name),
                  size: 16,
                  color: isSelected ? Colors.white : theme.secondaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: theme.labelLarge.override(
                    font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600),
                    color: isSelected ? Colors.white : theme.primaryText,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForCaller(String name) {
    switch (name) {
      case 'Police': return Icons.local_police_rounded;
      case 'Mummy':  return Icons.favorite_rounded;
      case 'Papa':   return Icons.person_rounded;
      case 'Bhai':   return Icons.sports_kabaddi_rounded;
      default:       return Icons.group_rounded;
    }
  }

  Widget _buildCustomNameInput(FlutterFlowTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.alternate, width: 1),
      ),
      child: TextField(
        style: theme.bodyMedium.override(
          font: GoogleFonts.inter(),
          color: theme.primaryText,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: 'Or type a custom name…',
          hintStyle: theme.bodyMedium.override(
            font: GoogleFonts.inter(),
            color: theme.secondaryText,
            letterSpacing: 0,
          ),
          prefixIcon: Icon(Icons.edit_rounded, color: theme.primary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (val) {
          if (val.trim().isNotEmpty) {
            safeSetState(() => _model.selectedCallerName = val.trim());
          }
        },
      ),
    );
  }

  Widget _buildTimerChips(FlutterFlowTheme theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: FakeCallSetupModel.timerOptions.map((opt) {
        final val = opt['value'] as int;
        final label = opt['label'] as String;
        final isSelected = _model.selectedTimerSeconds == val;

        return GestureDetector(
          onTap: () => safeSetState(() => _model.selectedTimerSeconds = val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.tertiary.withValues(alpha: 0.15)
                  : theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.tertiary : theme.alternate,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 14,
                  color: isSelected ? theme.tertiary : theme.secondaryText,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.labelLarge.override(
                    font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600),
                    color: isSelected ? theme.tertiary : theme.secondaryText,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCTAButton(FlutterFlowTheme theme) {
    final isCountingDown = _model.isCountingDown;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isCountingDown
          ? _buildCountdownButton(theme)
          : _buildScheduleButton(theme),
    );
  }

  Widget _buildScheduleButton(FlutterFlowTheme theme) {
    final isAi = _model.aiModeEnabled;
    return GestureDetector(
      key: const ValueKey('schedule'),
      onTap: _startFakeCall,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAi
                ? [const Color(0xFF6366F1), const Color(0xFF3B82F6)]
                : [theme.primary, theme.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isAi ? const Color(0xFF6366F1) : theme.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAi ? Icons.auto_awesome_rounded : Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isAi ? 'Schedule AI Fake Call' : 'Schedule Fake Call',
              style: theme.titleSmall.override(
                font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownButton(FlutterFlowTheme theme) {
    return GestureDetector(
      key: const ValueKey('countdown'),
      onTap: _cancelFakeCall,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: theme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.error, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Countdown ring
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _model.countdownRemaining /
                        _model.selectedTimerSeconds,
                    strokeWidth: 3,
                    color: theme.error,
                    backgroundColor: theme.error.withValues(alpha: 0.2),
                  ),
                  Text(
                    '${_model.countdownRemaining}',
                    style: theme.labelSmall.override(
                      font: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900),
                      color: theme.error,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Call in ${_model.countdownRemaining}s — tap to cancel',
              style: theme.titleSmall.override(
                font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                color: theme.error,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModeToggle(FlutterFlowTheme theme) {
    final isAi = _model.aiModeEnabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAi
            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
            : theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAi
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : theme.alternate,
          width: isAi ? 2 : 1,
        ),
        boxShadow: isAi
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isAi
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                    )
                  : null,
              color: isAi ? null : theme.secondaryText.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isAi ? Colors.white : theme.secondaryText,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Conversation Mode',
                  style: theme.labelLarge.override(
                    font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700),
                    color: isAi
                        ? const Color(0xFF6366F1)
                        : theme.primaryText,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAi
                      ? 'Claude AI will respond in Hindi as ${_model.selectedCallerName}'
                      : 'Uses pre-recorded audio (no internet needed)',
                  style: theme.bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: isAi
                        ? const Color(0xFF6366F1).withValues(alpha: 0.8)
                        : theme.secondaryText,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isAi,
            onChanged: (v) =>
                safeSetState(() => _model.aiModeEnabled = v),
            activeThumbColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote(FlutterFlowTheme theme) {
    if (_model.aiModeEnabled) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF6366F1), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI mode uses Claude + ElevenLabs APIs. Requires internet. '  
                'Add your API keys in lib/constants/api_keys.dart',
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fake call bypasses silent mode using alarm volume — rings even on silent.',
              style: theme.bodySmall.override(
                font: GoogleFonts.inter(),
                color: theme.secondaryText,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
