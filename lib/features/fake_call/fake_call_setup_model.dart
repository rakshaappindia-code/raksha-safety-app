import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'fake_call_setup_widget.dart';

class FakeCallSetupModel extends FlutterFlowModel<FakeCallSetupWidget> {
  // ── Form state ────────────────────────────────────────────────────────────
  String selectedCallerName = 'Police';
  int selectedTimerSeconds = 5;
  bool isCountingDown = false;
  int countdownRemaining = 0;
  bool aiModeEnabled = false; // ← AI Conversation Mode toggle

  // ── Preset caller options ─────────────────────────────────────────────────
  static const List<String> presetCallers = [
    'Police',
    'Mummy',
    'Papa',
    'Bhai',
  ];

  static const List<Map<String, dynamic>> timerOptions = [
    {'label': '5 sec', 'value': 5},
    {'label': '10 sec', 'value': 10},
    {'label': '30 sec', 'value': 30},
    {'label': '1 min', 'value': 60},
    {'label': '2 min', 'value': 120},
  ];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
